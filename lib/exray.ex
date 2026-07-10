defmodule Exray do
  @moduledoc """
    A tiny ray-tracing library that renders PPM images.

    `Exray.render/2..3` drives a recursive path tracer over a scene
    (an `Exray.HittableList`) from a given `Exray.Camera`, accumulating
    multi-sample color with gamma-2 output correction.
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

  @doc """
    Render `world` as seen through `camera`, writing the PPM file at `filename`.

    Options:

      * `:samples_per_pixel` (default #{inspect(@samples_per_pixel)}) – antialiasing
        samples per pixel.
      * `:max_depth` (default #{inspect(@max_depth)}) – ray bounce limit.
      * `:image_width` (default #{inspect(@image_width)}) – output width in px;
        height is derived from the camera's aspect ratio.
  """
  @spec render(Camera.t(), Hittable.t(), String.t(), keyword()) :: :ok
  def render(camera, world, filename \\ "hello.ppm", opts \\ []) do
    spp = Keyword.get(opts, :samples_per_pixel, @samples_per_pixel)
    max_depth = Keyword.get(opts, :max_depth, @max_depth)
    image_width = Keyword.get(opts, :image_width, @image_width)

    {width, height} = Camera.image_dimensions(camera, image_width)
    ppm = PPM.new(width, height)

    IO.puts(:stderr, "Rendering #{width}x#{height}, #{spp} spp, max depth #{max_depth}")

    pixels =
      (height - 1)..0//-1
      |> Task.async_stream(
        &render_line(camera, world, width, height, spp, max_depth, &1),
        ordered: true,
        timeout: :infinity
      )
      |> Enum.with_index()
      |> Enum.flat_map(fn {{:ok, line}, idx} ->
        IO.write(:stderr, "\rScanlines remaining: #{height - idx - 1} ")
        line
      end)

    IO.puts(:stderr, "\rDone")

    PPM.write(%{ppm | pixels: pixels}, filename)
  end

  defp render_line(camera, world, width, height, spp, max_depth, j) do
    for i <- 0..(width - 1) do
      render_pixel(camera, world, i, j, width, height, spp, max_depth)
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
