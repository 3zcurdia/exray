defmodule Exray.Nx.Shade do
  @moduledoc """
    Batched material scatter, background, and gamma-encode kernels.

    All kernels are `defn`s. Random vectors are generated **outside**
    these kernels (in `Exray.Nx.Render`) and passed in, so the kernels
    themselves remain pure functions of their tensor inputs. This also
    lets us vary the PRNG state per sample/bounce without re-compiling.
  """

  import Nx.Defn

  @lambertian 0
  @metal 1

  @doc """
    Sky background: a `0.5*(y + 1)` linear blend from white (top) to
    `(0.5, 0.7, 1.0)` (bottom). Vectorized across `{N, 3}` ray dirs.
  """
  defn background(directions) do
    # `directions` is `{N, 3}`. Take the y-component (axis 1, index 1).
    n = Nx.axis_size(directions, 0)
    y = directions |> Nx.slice_along_axis(1, 1, axis: 1) |> Nx.reshape({n})
    t = 0.5 * (y + 1.0)
    t_b = Nx.reshape(t, {n, 1})

    top_const = [1.0, 1.0, 1.0] |> Nx.tensor() |> Nx.reshape({1, 3})
    bottom_const = [0.5, 0.7, 1.0] |> Nx.tensor() |> Nx.reshape({1, 3})

    # (1 - t) * white + t * cyan, broadcast across the 3-component axis.
    top_color = (Nx.tensor(1.0) - t_b) * top_const
    bottom_color = bottom_const * t_b

    top_color + bottom_color
  end

  @doc """
    Lambertian scatter: `direction = normal + random_unit_vector`,
    falling back to `normal` when the result is near-zero. Attenuation
    is the per-hit sphere albedo.
  """
  defn scatter_lambertian(normals, rand_unit) do
    r = Nx.axis_size(normals, 0)
    scatter_dir = normals + rand_unit
    # near_zero? -> use normal. Use the squared-magnitude test threshold 1.0e-16.
    mag2 = Nx.sum(scatter_dir * scatter_dir, axes: [-1])
    near_zero = Nx.broadcast(Nx.reshape(mag2 < 1.0e-16, {r, 1}), {r, 3})
    scatter_dir = Nx.select(near_zero, normals, scatter_dir)
    scatter_dir
  end

  @doc """
    Metal scatter: `reflected = reflect(unit_dir, normal) + fuzz * rand`.
    Returns the new direction; caller masks out rays where
    `dot(direction, normal) <= 0` (absorbed).
  """
  defn scatter_metal(unit_dirs, normals, fuzzes, rand_in_unit_sphere) do
    r = Nx.axis_size(unit_dirs, 0)
    reflected = reflect(unit_dirs, normals)
    fuzz_b = Nx.reshape(fuzzes, {r, 1})
    reflected + fuzz_b * rand_in_unit_sphere
  end

  @doc """
    Dielectric scatter: choose reflect or refract per ray based on the
    Schlick reflectance approximation and the Snell cannot-refract test.

    Returns `{direction}`. The attenuation for dielectric is always
    white (handled by the caller via `albedos` from the scene –
    dielectric albedo is pre-packed as white in `Exray.Nx.Scene`).
  """
  defn scatter_dielectric(
         unit_dirs,
         normals,
         front_face_mask,
         iors,
         rand_u
       ) do
    r = Nx.axis_size(unit_dirs, 0)

    refraction_ratio =
      Nx.select(front_face_mask, 1.0 / iors, iors)

    cos_theta = Nx.min(Nx.negate(dot(unit_dirs, normals)), 1.0)
    sin_theta = Nx.sqrt(1.0 - cos_theta * cos_theta)

    cannot_refract = refraction_ratio * sin_theta > 1.0
    reflectance_val = reflectance(cos_theta, refraction_ratio)
    random_reflect = reflectance_val > rand_u

    do_reflect = Nx.logical_or(cannot_refract, random_reflect)
    do_reflect_b = Nx.broadcast(Nx.reshape(do_reflect, {r, 1}), {r, 3})

    reflected = reflect(unit_dirs, normals)
    refracted = refract(unit_dirs, normals, refraction_ratio)

    direction = Nx.select(do_reflect_b, reflected, refracted)

    direction
  end

  @doc """
  Combined scatter for a ray batch: dispatch on per-hit material type
  to choose the appropriate scatter formula, producing a new
  direction tensor `{N, 3}` and a per-ray `absorbed` mask `{N}`.

  For miss rays (`hit_mask` false) the scatter is irrelevant; the
  render loop ignores the produced direction.

  Inputs are pre-gathered and pre-passed:
    * `rand_unit`        – `{N, 3}` unit-random vectors (for Lambertian)
    * `rand_in_sphere`   – `{N, 3}` random-in-unit-sphere vectors (for Metal)
    * `rand_u`           – `{N}` uniform random (for Dielectric reflectance)
  """
  defn scatter(
         unit_dirs,
         normals,
         material_types,
         albedos,
         fuzzes,
         iors,
         front_face_mask,
         rand_unit,
         rand_in_sphere,
         rand_u
       ) do
    r = Nx.axis_size(unit_dirs, 0)

    # Compute all three scattering formulas. Wastes ~3x compute vs.
    # splitting the batch, but avoids Elixir-side grouping per bounce.
    lambertian_dir = scatter_lambertian(normals, rand_unit)
    metal_dir = scatter_metal(unit_dirs, normals, fuzzes, rand_in_sphere)
    dielectric_dir = scatter_dielectric(unit_dirs, normals, front_face_mask, iors, rand_u)

    # Select on material type. `Nx.select` requires the predicate's shape
    # to match the branches' shape, so broadcast the per-ray masks.
    is_lamb = Nx.broadcast(Nx.reshape(material_types == @lambertian, {r, 1}), {r, 3})
    is_metal = Nx.broadcast(Nx.reshape(material_types == @metal, {r, 1}), {r, 3})

    direction =
      Nx.select(is_lamb, lambertian_dir, Nx.select(is_metal, metal_dir, dielectric_dir))

    # Metal absorption: dot(direction, normal) <= 0.
    dot_dn = sum_dot(direction, normals)
    metal_absorbed = Nx.logical_and(material_types == @metal, dot_dn <= 0.0)
    # Lambertian near-zero fallback ensures dot >= 0; not absorbed by construction.
    absorbed = metal_absorbed

    %{direction: direction, attenuation: albedos, absorbed: absorbed}
  end

  @doc """
    Gamma-2 + 8-bit clamp the accumulated linear color buffer.

    `colors :: {N, 3}` already weighted by `1 / samples_per_pixel`.
    Output `{N, 3} u8` in `[0, 255]`.
  """
  defn gamma_encode(colors) do
    clamped = Nx.max(colors, 0.0)
    gamma = Nx.sqrt(clamped)
    clipped = Nx.min(gamma, Nx.tensor(0.999))
    scaled = clipped * 255.999
    rounded = Nx.round(scaled)
    # Clamp into the legal 0..255 range BEFORE the as_type, so backends
    # that saturate-on-overflow cannot turn a 255 into a 0.
    within = Nx.min(Nx.max(rounded, Nx.tensor(0.0)), Nx.tensor(255.0))
    Nx.as_type(within, {:s, 32})
  end

  # Helpers ------------------------------------------------------------------

  defn reflect(v, n) do
    r = Nx.axis_size(v, 0)
    dn = dot(v, n)
    v - n * Nx.reshape(2.0 * dn, {r, 1})
  end

  defn refract(uv, n, etai_over_etat) do
    r = Nx.axis_size(uv, 0)
    cos_theta = Nx.min(Nx.negate(dot(uv, n)), 1.0)
    cos_b = Nx.reshape(cos_theta, {r, 1})
    eta_b = Nx.reshape(etai_over_etat, {r, 1})
    r_out_perp = eta_b * (uv + n * cos_b)
    r_out_parallel = n * Nx.reshape(-Nx.sqrt(Nx.abs(1.0 - sum_sq(r_out_perp))), {r, 1})
    r_out_perp + r_out_parallel
  end

  defn reflectance(cosine, refractive_index) do
    r0 = Nx.pow((1.0 - refractive_index) / (1.0 + refractive_index), 2)
    r0 + (1.0 - r0) * Nx.pow(1.0 - cosine, 5)
  end

  defnp(dot(a, b), do: Nx.sum(a * b, axes: [-1]))
  defnp(sum_dot(a, b), do: Nx.sum(a * b, axes: [-1]))
  defnp(sum_sq(a), do: Nx.sum(a * a, axes: [-1]))
end
