defmodule Exray do
  @moduledoc """
    A tiny ray-tracing library that renders PPM images.

    `Exray.render/4` drives a recursive path tracer over a scene
    (an `Exray.HittableList`) from a given `Exray.Camera`, accumulating
    multi-sample color with gamma-2 output correction.

    Rendering is parallelized across square tiles (`:tile_size` side,
    default 64 px). Each tile is processed independently and its pixel
    results are reassembled into the row-major PPM output via an
    index-addressed Erlang `:array` buffer, so task completion order
    does not affect the final image.
  """

  alias Exray.Camera
  alias Exray.Color
  alias Exray.Hittable
  alias Exray.Material
  alias Exray.PPM
  alias Exray.Ray
  alias Exray.Vector

  @samples_per_pixel 100
  @max_depth 50
  @image_width 400
  @tile_size 64

  @doc """
    Render `world` as seen through `camera`, writing the PPM file at `filename`.

    Options:

      * `:samples_per_pixel` (default #{inspect(@samples_per_pixel)}) – antialiasing
        samples per pixel.
      * `:max_depth` (default #{inspect(@max_depth)}) – ray bounce limit.
      * `:image_width` (default #{inspect(@image_width)}) – output width in px;
        height is derived from the camera's aspect ratio.
      * `:tile_size` (default #{inspect(@tile_size)}) – side length in px of the
        square tiles used for parallelization. Smaller tiles balance load better
        on many cores; larger tiles reduce per-task overhead.
  """
  @spec render(Camera.t(), Hittable.t(), String.t(), keyword()) :: :ok
  def render(camera, world, filename \\ "hello.ppm", opts \\ []) do
    spp = Keyword.get(opts, :samples_per_pixel, @samples_per_pixel)
    max_depth = Keyword.get(opts, :max_depth, @max_depth)
    image_width = Keyword.get(opts, :image_width, @image_width)
    tile_size = Keyword.get(opts, :tile_size, @tile_size)

    {width, height} = Camera.image_dimensions(camera, image_width)
    ppm = PPM.new(width, height)

    tiles = tiles(width, height, tile_size)
    total = length(tiles)

    IO.puts(
      :stderr,
      "Rendering #{width}x#{height}, #{spp} spp, max depth #{max_depth}, " <>
        "#{total} tiles of #{tile_size}x#{tile_size}"
    )

    pixels =
      tiles
      |> Task.async_stream(
        &render_tile(camera, world, width, height, spp, max_depth, &1),
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

    IO.puts(:stderr, "\rDone")

    PPM.write(%{ppm | pixels: pixels}, filename)
  end

  @spec tiles(pos_integer(), pos_integer(), pos_integer()) ::
          [{non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}]
  defp tiles(width, height, tile_size) do
    for y0 <- 0..(height - 1)//tile_size,
        x0 <- 0..(width - 1)//tile_size do
      x1 = min(x0 + tile_size, width)
      y1 = min(y0 + tile_size, height)
      {x0, y0, x1, y1}
    end
  end

  @spec render_tile(
          Camera.t(),
          Hittable.t(),
          pos_integer(),
          pos_integer(),
          pos_integer(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
        ) :: [{non_neg_integer(), String.t()}]
  defp render_tile(camera, world, width, height, spp, max_depth, {x0, y0, x1, y1}) do
    for j <- y0..(y1 - 1), i <- x0..(x1 - 1) do
      idx = (height - 1 - j) * width + i
      str = render_pixel(camera, world, i, j, width, height, spp, max_depth)
      {idx, str}
    end
  end

  @spec render_pixel(
          Camera.t(),
          Hittable.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          pos_integer(),
          non_neg_integer()
        ) :: String.t()
  defp render_pixel(camera, world, i, j, width, height, spp, max_depth) do
    color =
      Enum.reduce(1..spp, Color.black(), fn _, acc ->
        u = (i + :rand.uniform()) / (width - 1)
        v = (j + :rand.uniform()) / (height - 1)
        ray = Camera.get_ray(camera, u, v)
        Color.add(acc, ray_color(ray, world, max_depth))
      end)

    "#{Color.to_ppm_string(color, spp)}\n"
  end

  @spec ray_color(Ray.t(), Hittable.t(), non_neg_integer()) :: Color.t()
  defp ray_color(_ray, _world, 0), do: Color.black()

  defp ray_color(ray, world, depth) do
    case Hittable.hit(world, ray, 0.001, 1.0e12) do
      {:ok, record} ->
        case Material.scatter(record.material, ray, record) do
          {:ok, scattered, attenuation} ->
            Color.multiply(ray_color(scattered, world, depth - 1), attenuation)

          :absorbed ->
            Color.black()
        end

      :miss ->
        background(ray)
    end
  end

  defp background(%Ray{} = ray) do
    %Vector{y: y} = Ray.unit_vector(ray)
    t = 0.5 * (y + 1.0)

    Color.white()
    |> Color.multiply(1.0 - t)
    |> Color.add(Color.multiply(Color.new(0.5, 0.7, 1.0), t))
  end
end
