defmodule Exray do
  @moduledoc """
  Documentation for `Exray`.
  """

  # alias Supervisor.Spec
  alias Exray.PPM
  alias Exray.Color
  alias Exray.Vector
  alias Exray.Ray
  alias Exray.Sphere

  def render(width \\ 256, height \\ 256) do
    ppm = PPM.new(width, height)

    ppm
    |> render_pixels()
    |> PPM.write("hello.ppm")
  end

  defp render_pixels(%PPM{width: width, height: height} = ppm) do
    # Image dimensions
    aspect_ratio = 16.0 / 9.0
    image_width = 400
    image_height = round(image_width / aspect_ratio)
    image_height = if image_height < 1, do: 1, else: image_height

    # Camera
    focal_length = 1.0
    viewport_height = 2.0
    viewport_width = viewport_height * (image_width / image_height)
    camera_center = Vector.zero()

    # Calculate the vectors across the horizontal and down the vertical viewport edges.
    viewport_u = Vector.new(viewport_width, 0, 0)
    viewport_v = Vector.new(0, -viewport_height, 0)

    # Calculate the horizontal and vertical delta vectors from pixel to pixel.
    pixel_delta_u = Vector.divide(viewport_u, image_width)
    pixel_delta_v = Vector.divide(viewport_v, image_height)

    # Calculate the location of the upper left pixel
    viewport_upper_left =
      camera_center
      |> Vector.subtract(Vector.new(0, 0, focal_length))
      |> Vector.subtract(Vector.divide(pixel_delta_u, 2))
      |> Vector.subtract(Vector.divide(pixel_delta_v, 2))

    pixel00_loc =
      viewport_upper_left
      |> Vector.add(Vector.divide(Vector.add(pixel_delta_u, pixel_delta_v), 2))

    pixels =
      for j <- 0..(height - 1), i <- 0..(width - 1), into: [] do
        IO.write(:stderr, "\rScanlines remaining: #{height - j} ")

        pixel_center =
          pixel00_loc
          |> Vector.add(Vector.multiply(pixel_delta_u, i))
          |> Vector.add(Vector.multiply(pixel_delta_v, j))

        ray_direction = Vector.subtract(pixel_center, camera_center)
        ray = Ray.new(camera_center, ray_direction)

        "#{ray_color(ray)}\n"
      end

    %PPM{ppm | pixels: pixels}
  end

  def ray_color(ray) do
    if Sphere.hit?(Sphere.new({0.0, 0.0, -1.0}, 0.5), ray) do
      Vector.new(1, 0, 0) |> Color.new()
    else
      %{y: y} = Ray.unit_vector(ray)
      a = 0.5 * (y + 1.0)

      Vector.new(1.0, 1.0, 1.0)
      |> Vector.multiply(1.0 - a)
      |> Vector.add(Vector.multiply(Vector.new(0.5, 0.7, 1.0), a))
      |> Color.new()
    end
  end

  # Experimental, concurrent rendering
  # def render_concurrent(width \\ 256, height \\ 256) do
  #   ppm = PPM.new(width, height)

  #   ppm
  #   |> render_pixels_concurrent()
  #   |> PPM.write("hello_concurrent.ppm")
  # end

  # defp render_pixels_concurrent(%PPM{width: width, height: height} = ppm) do
  #   max_workers = System.schedulers_online() - 1
  #   rows = height - 1

  #   pixels =
  #     0..(rows - 1)
  #     |> Task.async_stream(
  #       fn j ->
  #         row =
  #           for i <- 0..(width - 1), into: [] do
  #             "#{Color.new(i / (width - 1), j / (height - 1), 0.0)}\n"
  #           end

  #         {j, row}
  #       end,
  #       max_concurrency: max_workers
  #     )
  #     |> Enum.sort_by(fn {:ok, {index, _data}} -> index end)
  #     |> Enum.map(fn {:ok, {_index, chunk}} -> chunk end)

  #   %PPM{ppm | pixels: pixels}
  # end
end
