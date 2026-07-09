defmodule Render do
  @moduledoc false
  alias Exray.Color
  alias Exray.HittableList
  alias Exray.Materials
  alias Exray.Sphere
  alias Exray.Vector

  def run do
    IO.puts("Rendering...")

    world = random_scene()

    camera =
      Exray.Camera.new(
        Vector.new(13.0, 3.0, 2.0),
        Vector.new(0.0, 0.0, 0.0),
        aspect_ratio: 3.0 / 2.0,
        vertical_fov: 20.0,
        aperture: 0.1,
        focus_dist: 10.0
      )

    Exray.render(camera, world, "hello.ppm",
      image_width: 400,
      samples_per_pixel: 50,
      max_depth: 50
    )

    IO.puts("\nDone.")
  end

  defp random_scene do
    # Three large spheres of each material.
    list =
      HittableList.new([
        Sphere.new({-4.0, 1.0, 0.0}, 1.0, Materials.Lambertian.new(Color.new(0.4, 0.2, 0.1))),
        Sphere.new({0.0, 1.0, 0.0}, 1.0, Materials.Dielectric.new(1.5)),
        Sphere.new({4.0, 1.0, 0.0}, 1.0, Materials.Metal.new(Color.new(0.7, 0.6, 0.5), 0.0))
      ])

    # Random small spheres scattered across the ground plane.
    guard = Vector.new(4, 0.2, 0)

    list =
      for a <- -11..11, b <- -11..11, reduce: list do
        acc ->
          center = Vector.new(a + 0.9 * :rand.uniform(), 0.2, b + 0.9 * :rand.uniform())

          if Vector.mod(Vector.subtract(center, guard)) > 0.9 do
            material =
              case :rand.uniform() do
                p when p < 0.8 ->
                  Materials.Lambertian.new(Color.multiply(Color.random(), Color.random()))

                p when p < 0.95 ->
                  Materials.Metal.new(Color.random(0.5, 1.0), :rand.uniform() * 0.5)

                _ ->
                  Materials.Dielectric.new(1.5)
              end

            HittableList.add(acc, Sphere.new(center, 0.2, material))
          else
            acc
          end
      end

    # Ground sphere.
    HittableList.add(
      list,
      Sphere.new(
        {0.0, -1000.0, 0.0},
        1000.0,
        Materials.Lambertian.new(Color.multiply(Color.white(), 0.5))
      )
    )
  end
end

Render.run()
