# Exray

A tiny Elixir ray-tracer, implemented as a port of Peter Shirley's
[_Ray Tracing in One Weekend_](https://raytracing.github.io/books/RayTracingInOneWeekend.html)
book series. It renders PPM images using a recursive path tracer with
multi-sample antialiasing, gamma-2 output correction, and support for
Lambertian, metal, and dielectric materials.

## Installation

```bash
mix deps.get
```

The only dependency is [`dialyxir`](https://github.com/jeremyjh/dialyxir),
used for dev/test type checking.

## Usage

The project ships with an executable script, `render.exs`, that builds a
sample scene (a ground plane, a few large spheres, and a scatter of small
random ones) and writes the output to `hello.ppm`:

```bash
mix run render.exs
```

To render your own scene, build an `Exray.HittableList` of `Exray.Sphere`s
and an `Exray.Camera`, then call `Exray.render/4`:

```elixir
alias Exray.{Color, Camera, HittableList, Materials, Sphere, Vector}

world =
  HittableList.new([
    Sphere.new(
      {0.0, 0.0, -1.0},
      0.5,
      Materials.Lambertian.new(Color.new(0.1, 0.2, 0.5))
    ),
    Sphere.new(
      {0.0, -100.5, -1.0},
      100.0,
      Materials.Lambertian.new(Color.new(0.8, 0.8, 0.0))
    )
  ])

camera =
  Camera.new(
    Vector.new(0.0, 0.0, 0.0),
    Vector.new(0.0, 0.0, -1.0),
    aspect_ratio: 16.0 / 9.0,
    vertical_fov: 90.0
  )

Exray.render(camera, world, "out.ppm", image_width: 400)
```

### `Exray.render/4` options

| Option              | Default | Description                                  |
| ------------------- | ------- | -------------------------------------------- |
| `:image_width`      | `400`   | Output width in px; height follows aspect.   |
| `:samples_per_pixel`| `100`   | Antialiasing samples per pixel.              |
| `:max_depth`        | `50`    | Maximum ray-bounce depth.                    |

The output is a plain PPM file. Tools like
[`magick`](https://imagemagick.org/) or
[`pnmtojpeg`](https://netpbm.sourceforge.net/) can convert it to a more
common image format, e.g.:

```bash
magick hello.ppm hello.png
```

## Development

```bash
mix test                    # run doctests
mix test path/to_test.exs   # run a single test file
mix format --check-formatted
mix dialyzer                # type checking
```

## Reference

The book that guided this implementation:
[Ray Tracing in One Weekend](https://raytracing.github.io/books/RayTracingInOneWeekend.html).

## License

See `mix.exs` for package metadata.
