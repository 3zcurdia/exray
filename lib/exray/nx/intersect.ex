defmodule Exray.Nx.Intersect do
  @moduledoc """
    Batched ray-sphere intersection kernel.

    All kernels are `defn`s: they run on whichever backend is the current
    Nx default (EXLA CPU when `Exray.Nx.Render` is driving a render).

    `intersect/6` returns everything the render loop needs for the next
    bounce in a single compiled kernel, including the per-hit sphere
    parameters gathered via `Nx.take_along_axis`, so we avoid a
    Elixir↔backend round trip per bounce.
  """

  import Nx.Defn

  @infinity 1.0e30
  @eps 1.0e-12

  @doc """
    Intersect `R` rays against `S` spheres in a single tensor batch.

    `origins` and `dirs` are `{R, 3}`; `centers` is `{S, 3}`, `radii`
    is `{S}`. `t_min`/`t_max` are scalar bounds. `dirs` need not be
    normalized: the optimized quadratic uses `a = |d|Â²`.

    Returns a map of `{R}` / `{R, 3}` tensors:

      * `:t`             – smallest valid hit distance per ray, `#{@infinity}` on miss
      * `:idx`           – index of the nearest sphere, `-1` on miss
      * `:hit_mask`      – boolean, `true` when the ray hit any sphere
      * `:centers`       – `{R, 3}` hit-sphere centers (zeros on miss)
      * `:radii`         – `{R}` hit-sphere radii (zeros on miss)
      * `:material_types`– `{R}` hit material type (0 Lambertian, 1 Metal, 2 Dielectric)
      * `:albedos`       – `{R, 3}` hit albedo (zeros on miss)
      * `:fuzzes`        – `{R}` hit fuzz (zeros on miss)
      * `:iors`          – `{R}` hit IOR (zeros on miss)
  """
  defn intersect(
         origins,
         dirs,
         centers,
         radii,
         material_types,
         albedos,
         fuzzes,
         iors,
         t_min,
         t_max
       ) do
    r = Nx.axis_size(origins, 0)
    s = Nx.axis_size(centers, 0)

    # Broadcast: rays -> {R, 1, 3}, spheres -> {1, S, 3}.
    origins_b = Nx.reshape(origins, {r, 1, 3})
    dirs_b = Nx.reshape(dirs, {r, 1, 3})
    centers_b = Nx.reshape(centers, {1, s, 3})

    oc = origins_b - centers_b

    a = Nx.sum(dirs_b * dirs_b, axes: [-1])
    half_b = Nx.sum(oc * dirs_b, axes: [-1])
    c = Nx.sum(oc * oc, axes: [-1]) - radii * radii

    disc = half_b * half_b - a * c
    a_safe = Nx.max(a, @eps)
    sqrt_d = Nx.sqrt(Nx.max(disc, 0.0))

    near = (-half_b - sqrt_d) / a_safe
    far = (-half_b + sqrt_d) / a_safe

    near_in = Nx.logical_and(near >= t_min, near <= t_max)
    far_in = Nx.logical_and(far >= t_min, far <= t_max)
    valid_disc = disc >= 0.0

    # Per (ray, sphere): prefer near root, fall back to far root, else infinity. Mask misses.
    t_pair =
      Nx.select(near_in, near, Nx.select(far_in, far, @infinity))

    t_pair =
      Nx.select(valid_disc, t_pair, @infinity)

    # Nearest sphere per ray along axis 1.
    min_t = Nx.reduce_min(t_pair, axes: [1])
    idx = Nx.argmin(t_pair, axis: 1, tie_break: :low)
    hit_mask = min_t < @infinity

    # Replace -1 (miss) with 0 for safe gather; we mask the result anyway.
    safe_idx = Nx.select(hit_mask, idx, 0)

    # 2-D per-sphere tensors are gathered along axis 0 with an index
    # broadcast across component axes. 1-D tensors are gathered with a
    # same-rank index tensor.
    idx_2d = Nx.broadcast(Nx.reshape(safe_idx, {r, 1}), {r, 3})

    hit_centers = Nx.take_along_axis(centers, idx_2d, axis: 0)
    hit_albedos = Nx.take_along_axis(albedos, idx_2d, axis: 0)
    hit_radii = Nx.take_along_axis(radii, safe_idx, axis: 0)
    hit_material_types = Nx.take_along_axis(material_types, safe_idx, axis: 0)
    hit_fuzzes = Nx.take_along_axis(fuzzes, safe_idx, axis: 0)
    hit_iors = Nx.take_along_axis(iors, safe_idx, axis: 0)

    idx_out = Nx.select(hit_mask, idx, -1)

    %{
      t: min_t,
      idx: idx_out,
      hit_mask: hit_mask,
      centers: hit_centers,
      radii: hit_radii,
      material_types: hit_material_types,
      albedos: hit_albedos,
      fuzzes: hit_fuzzes,
      iors: hit_iors
    }
  end

  @doc """
  Per-hit geometry: hit point, outward normal (un-normalized before
  front-face determination), and front-face mask.

  `points = origins + dirs * t`
  `outward_normal = (point - center) / radius`
  `front_face = dot(dir, outward_normal) < 0`
  """
  defn hit_geometry(origins, dirs, t, hit_centers, hit_radii) do
    r = Nx.axis_size(origins, 0)
    t_b = Nx.reshape(t, {r, 1})

    points = origins + dirs * t_b

    outward_normals = (points - hit_centers) / Nx.reshape(hit_radii, {r, 1})
    dot_dn = Nx.sum(dirs * outward_normals, axes: [-1])
    front_face = dot_dn < 0.0
    ff_b = Nx.broadcast(Nx.reshape(front_face, {r, 1}), {r, 3})
    normals = Nx.select(ff_b, outward_normals, Nx.negate(outward_normals))

    %{points: points, normals: normals, outward_normals: outward_normals, front_face: front_face}
  end
end
