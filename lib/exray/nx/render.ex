defmodule Exray.Nx.Render do
  @moduledoc """
    Nx + EXLA accelerated render path.

    The pipeline:

      1. The `Exray.HittableList` scene is flattened once into per-sphere
         tensors by `Exray.Nx.Scene`.
      2. The image is split into square tiles (same `tile_size` strategy
         as `Exray.render/4`); tiles run in parallel via `Task.async_stream`.
      3. Within a tile, primary rays for a sample batch (`sample_batch`
         samples per pixel, default 16) are built as a single `{N, 3}`
         tensor where `N = tile_pixels * sample_batch`.
      4. BEAM-recursion over `max_depth` bounces calls two compiled
         `defn` kernels per bounce: `Exray.Nx.Intersect.intersect/10`
         (ray-sphere scan with per-hit parameter gather) and
         `Exray.Nx.Shade.scatter/10` (per-material scatter).
      5. Active rays that miss or are absorbed add their weighted
         background / black contribution to a color accumulator and are
         deactivated; the rest propagate to the next bounce with a new
         direction, attenuation, and origin.
      6. After all sample batches, accumulated per-pixel color is
         averaged across `samples_per_pixel`, gamma-2 encoded, and
         written via the existing `Exray.PPM` module.

    Memory for the `{N, M}` per-bounce intersection matrix is bounded by
    `sample_batch`: each tile processes at most `tile_pixels *
    sample_batch * sphere_count * 4` bytes. For a 64Ã—64 tile with 16
    samples and ~500 spheres that is ~800 MB peak, which is why the
    sample batch size is configurable.
  """

  import Nx.Defn

  alias Exray.Nx.Intersect
  alias Exray.Nx.Shade
  alias Exray.PPM

  @samples_per_pixel 100
  @max_depth 50
  @image_width 400
  @tile_size 64
  @sample_batch 16

  @doc """
  Render `world` as seen through `camera`, writing `filename`.

  Same option keys as `Exray.render/4`, plus:

    * `:sample_batch` (default #{inspect(@sample_batch)}) â€“ number of
      samples processed per tensor batch per tile. Smaller batches
      keep peak memory low.
  """
  @spec render(Exray.Camera.t(), Exray.HittableList.t(), String.t(), keyword()) :: :ok
  def render(camera, world, filename \\ "hello.ppm", opts \\ []) do
    Application.ensure_all_started(:exla)

    spp = Keyword.get(opts, :samples_per_pixel, @samples_per_pixel)
    max_depth = Keyword.get(opts, :max_depth, @max_depth)
    image_width = Keyword.get(opts, :image_width, @image_width)
    tile_size = Keyword.get(opts, :tile_size, @tile_size)
    sample_batch = Keyword.get(opts, :sample_batch, @sample_batch)

    scene = Exray.Nx.Scene.from_hittable_list(world)
    {width, height} = Exray.Camera.image_dimensions(camera, image_width)
    ppm = PPM.new(width, height)

    cam = camera_to_tensors(camera, width, height)

    tiles = tiles(width, height, tile_size)
    total = length(tiles)

    IO.puts(
      :stderr,
      "Rendering (Nx) #{width}Ã—#{height}, #{spp} spp (batch #{sample_batch}), " <>
        "max depth #{max_depth}, scene #{scene.count} spheres, " <>
        "#{total} tiles of #{tile_size}Ã—#{tile_size}"
    )

    pixels =
      tiles
      |> Task.async_stream(
        fn tile ->
          Nx.default_backend({EXLA.Backend, []})
          Nx.Defn.default_options(compiler: EXLA)
          render_tile(cam, scene, width, height, spp, sample_batch, max_depth, tile)
        end,
        ordered: false,
        timeout: :infinity,
        max_demand: System.schedulers_online()
      )
      |> Enum.reduce({0, :array.new(size: width * height, default: nil, fixed: true)}, fn
        {:ok, entries}, {done, buf} ->
          buf = Enum.reduce(entries, buf, fn {idx, str}, acc -> :array.set(idx, str, acc) end)
          done = done + 1
          IO.write(:stderr, "\rTiles: #{done}/#{total} ")
          {done, buf}
      end)
      |> elem(1)
      |> :array.to_list()

    IO.puts(:stderr, "\rDone (Nx)")

    PPM.write(%{ppm | pixels: pixels}, filename)
  end

  defp tiles(width, height, tile_size) do
    for y0 <- 0..(height - 1)//tile_size,
        x0 <- 0..(width - 1)//tile_size do
      x1 = min(x0 + tile_size, width)
      y1 = min(y0 + tile_size, height)
      {x0, y0, x1, y1}
    end
  end

  defp camera_to_tensors(%Exray.Camera{} = cam, _w, _h) do
    %{
      origin: vec3(cam.origin),
      lower_left: vec3(cam.lower_left),
      horizontal: vec3(cam.horizontal),
      vertical: vec3(cam.vertical),
      u: vec3(cam.u),
      v: vec3(cam.v),
      lens_radius: Nx.tensor(cam.lens_radius, type: {:f, 32})
    }
  end

  defp vec3(%Exray.Vector{x: x, y: y, z: z}), do: Nx.tensor([x, y, z], type: {:f, 32})

  # Per-tile render ---------------------------------------------------------

  defp render_tile(cam, scene, width, height, spp, sample_batch, max_depth, {x0, y0, x1, y1}) do
    tw = x1 - x0
    th = y1 - y0
    tile_pixels = tw * th

    # Pixel-index tensors used to build primary rays batch.
    for_result =
      for _j <- 0..(th - 1), i <- 0..(tw - 1), into: [] do
        x0 + i
      end

    pixel_i_starts = Nx.tensor(for_result, type: {:f, 32})

    for_result =
      for j <- 0..(th - 1), _i <- 0..(tw - 1), into: [] do
        y0 + j
      end

    pixel_j_starts = Nx.tensor(for_result, type: {:f, 32})

    # Sum color across all sample batches. Each batch contributes an
    # {tile_pixels, 3} linear-color tensor. Division is at the end.
    color_acc =
      Enum.reduce(1..ceil(spp / sample_batch), Nx.broadcast(Nx.tensor(0.0), {tile_pixels, 3}), fn
        batch, acc when batch * sample_batch <= spp ->
          key = Nx.Random.key(:rand.uniform(2_147_483_647))

          Nx.add(
            acc,
            render_sample_batch(
              cam,
              scene,
              width,
              height,
              tile_pixels,
              sample_batch,
              max_depth,
              pixel_i_starts,
              pixel_j_starts,
              key
            )
          )

        batch, acc ->
          this_batch = spp - (batch - 1) * sample_batch
          key = Nx.Random.key(:rand.uniform(2_147_483_647))

          Nx.add(
            acc,
            render_sample_batch(
              cam,
              scene,
              width,
              height,
              tile_pixels,
              this_batch,
              max_depth,
              pixel_i_starts,
              pixel_j_starts,
              key
            )
          )
      end)

    color_mean = Nx.divide(color_acc, spp)
    gamma = Shade.gamma_encode(color_mean)

    # Locations in the row-major PPM buffer where this tile's pixels land.
    # idx = (height - 1 - j_global) * width + i_global
    for_result =
      for j <- 0..(th - 1), i <- 0..(tw - 1), into: [] do
        (height - 1 - (y0 + j)) * width + (x0 + i)
      end

    pixel_indices = Nx.tensor(for_result, type: {:s, 32})

    # `gamma` is {tile_pixels, 3} u8. Flatten into list of "r g b" strings.
    rgb_integers =
      gamma
      |> Nx.reshape({tile_pixels * 3})
      |> Nx.as_type({:s, 32})
      |> Nx.to_flat_list()

    bytes =
      rgb_integers
      |> Enum.chunk_every(3)
      |> Enum.map(fn [r, g, b] -> "#{r} #{g} #{b}\n" end)

    pixel_indices_list = Nx.to_flat_list(pixel_indices)

    Enum.zip(pixel_indices_list, bytes)
  end

  # One sample-batch --------------------------------------------------------

  defp render_sample_batch(
         cam,
         scene,
         width,
         height,
         tile_pixels,
         sample_batch,
         max_depth,
         pixel_i_starts,
         pixel_j_starts,
         key
       ) do
    n = tile_pixels * sample_batch

    # Broadcast pixel coords across the sample axis, with a per-sample
    # jitter in [0, 1).  The N rays are ordered: pixel-major, sample-minor.
    pi = Nx.broadcast(Nx.reshape(pixel_i_starts, {tile_pixels, 1}), {tile_pixels, sample_batch})
    pj = Nx.broadcast(Nx.reshape(pixel_j_starts, {tile_pixels, 1}), {tile_pixels, sample_batch})

    {jitter_u, key} = Nx.Random.uniform(key, shape: {tile_pixels, sample_batch}, type: {:f, 32})
    {jitter_v, key} = Nx.Random.uniform(key, shape: {tile_pixels, sample_batch}, type: {:f, 32})
    {rd_x, key} = Nx.Random.uniform(key, -1.0, 1.0, shape: {tile_pixels, sample_batch}, type: {:f, 32})
    {rd_y, key} = Nx.Random.uniform(key, -1.0, 1.0, shape: {tile_pixels, sample_batch}, type: {:f, 32})

    s = Nx.divide(Nx.add(pi, jitter_u), width - 1)
    t = Nx.divide(Nx.add(pj, jitter_v), height - 1)

    s = Nx.reshape(s, {n})
    t = Nx.reshape(t, {n})
    rd_x = Nx.reshape(rd_x, {n})
    rd_y = Nx.reshape(rd_y, {n})

    {origins, dirs} =
      primary_rays(
        cam.origin,
        cam.lower_left,
        cam.horizontal,
        cam.vertical,
        cam.u,
        cam.v,
        cam.lens_radius,
        s,
        t,
        rd_x,
        rd_y
      )

    # Bounce loop.
    color_acc = Nx.broadcast(Nx.tensor(0.0), {n, 3})

    attenuation =
      Nx.broadcast(Nx.tensor([1.0, 1.0, 1.0], type: {:f, 32}), {n, 3})

    active = Nx.broadcast(Nx.tensor(true, type: {:u, 8}), {n})

    {color_acc, _att, _active, _origin, _dir, _key} =
      Enum.reduce(0..(max_depth - 1), {color_acc, attenuation, active, origins, dirs, key}, fn
        _depth, {col, att, act, o, d, k} ->
          step_bounce(scene, n, col, att, act, o, d, k)
      end)

    # Row-major: collapse the sample axis by summing across samples within
    # each pixel. We divide by the total `samples_per_pixel` later in
    # `render_tile`. Using the *sum* (rather than the mean) here lets the
    # final leftover batch (which may contain fewer than `sample_batch`
    # samples) contribute proportionally without a per-batch weighting.
    color_acc
    |> Nx.reshape({tile_pixels, sample_batch, 3})
    |> Nx.sum(axes: [1])
  end

  defp step_bounce(scene, n, color_acc, attenuation, active, origins, dirs, key) do
    intersect =
      Intersect.intersect(
        origins,
        dirs,
        scene.centers,
        scene.radii,
        scene.material_types,
        scene.material_albedos,
        scene.material_fuzzes,
        scene.material_iors,
        0.001,
        1.0e12
      )

    %{
      t: t,
      hit_mask: hit_mask,
      centers: hit_centers,
      radii: hit_radii,
      material_types: hit_material_types,
      albedos: hit_albedos,
      fuzzes: hit_fuzzes,
      iors: hit_iors
    } = intersect

    geometry = Intersect.hit_geometry(origins, dirs, t, hit_centers, hit_radii)
    %{points: points, normals: normals, front_face: front_face} = geometry

    # Background contribution for newly-missed rays. `background` uses the
    # normalized direction (matches scalar renderer's `Ray.unit_vector`).
    unit_dirs_bounce = normalize(dirs)
    bg = Shade.background(unit_dirs_bounce)
    miss_contribution = Nx.multiply(attenuation, bg)

    # `just_missed`: this ray was active AND missed this bounce.
    just_missed = Nx.logical_and(active, Nx.logical_not(hit_mask))

    # For just_missed, add background; leave color_acc unchanged elsewhere.
    add_mask = just_missed |> Nx.as_type({:u, 8}) |> Nx.reshape({n, 1}) |> Nx.broadcast({n, 3})
    zeros = Nx.broadcast(Nx.tensor(0.0), {n, 3})
    color_acc = Nx.add(color_acc, Nx.select(add_mask, miss_contribution, zeros))

    # Per-bounce random tensors.
    {rand_unit, key} = Nx.Random.normal(key, shape: {n, 3}, type: {:f, 32})
    rand_unit = normalize(rand_unit)

    {rand_in_sphere, key} = Nx.Random.normal(key, shape: {n, 3}, type: {:f, 32})

    {rand_u, key} = Nx.Random.uniform(key, shape: {n}, type: {:f, 32})

    # Normalize current dirs for Metal / Dielectric scatter (`unit_dirs`).
    unit_dirs = normalize(dirs)

    scatter =
      Shade.scatter(
        unit_dirs,
        normals,
        hit_material_types,
        hit_albedos,
        hit_fuzzes,
        hit_iors,
        front_face,
        rand_unit,
        rand_in_sphere,
        rand_u
      )

    %{direction: new_dir, attenuation: new_att, absorbed: absorbed} = scatter

    # Newly active rays for the next bounce: those that hit AND were active
    # AND were not absorbed.
    still_active = Nx.logical_and(active, Nx.logical_and(hit_mask, Nx.logical_not(absorbed)))

    sa_mask = still_active |> Nx.as_type({:u, 8}) |> Nx.reshape({n, 1}) |> Nx.broadcast({n, 3})

    # Update origins and directions for active rays; freeze inactive
    # ones by carrying through their prior values (won't be used since
    # they're no longer active).
    next_origins = Nx.select(sa_mask, points, origins)
    next_dirs = Nx.select(sa_mask, new_dir, dirs)
    next_att = Nx.select(sa_mask, Nx.multiply(attenuation, new_att), attenuation)

    {color_acc, next_att, still_active, next_origins, next_dirs, key}
  end

  defn primary_rays(origin, lower_left, horizontal, vertical, u, v, lens_radius, s, t, rd_x, rd_y) do
    n = Nx.axis_size(s, 0)

    # Lens offset (in unit disk scaled by lens_radius).
    offset =
      (Nx.reshape(rd_x, {n, 1}) * Nx.reshape(u, {1, 3}) +
         Nx.reshape(rd_y, {n, 1}) * Nx.reshape(v, {1, 3})) * lens_radius

    s_b = Nx.reshape(s, {n, 1})
    t_b = Nx.reshape(t, {n, 1})

    horizontal_b = Nx.reshape(horizontal, {1, 3})
    vertical_b = Nx.reshape(vertical, {1, 3})
    ll_b = Nx.reshape(lower_left, {1, 3})
    origin_b = Nx.reshape(origin, {1, 3})

    direction = ll_b + horizontal_b * s_b + vertical_b * t_b - origin_b - offset
    ray_origin = Nx.broadcast(origin_b, {n, 3}) + offset

    {ray_origin, direction}
  end

  defn normalize(dirs) do
    n = Nx.axis_size(dirs, 0)
    mag2 = Nx.sum(dirs * dirs, axes: [-1])
    safe = Nx.max(mag2, 1.0e-20)
    dirs / Nx.reshape(Nx.sqrt(safe), {n, 1})
  end
end
