defmodule Exray.Nx.RenderTest do
  use ExUnit.Case, async: false

  alias Exray.Camera
  alias Exray.Color
  alias Exray.HittableList
  alias Exray.Materials
  alias Exray.Sphere
  alias Exray.Vector

  @fixtures_dir "test/fixtures"

  setup_all do
    File.mkdir_p!(@fixtures_dir)
    :ok
  end

  setup do
    # These tests exercise the full render pipeline through EXLA, which
    # is a process-local setting; keep them serial.
    Application.ensure_all_started(:exla)
    :ok
  end

  defp simple_world do
    HittableList.new([
      Sphere.new({0.0, 0.0, -1.0}, 0.5, Materials.Lambertian.new(Color.new(0.7, 0.3, 0.3))),
      Sphere.new({0.0, -100.5, -1.0}, 100.0, Materials.Lambertian.new(Color.new(0.8, 0.8, 0.0)))
    ])
  end

  defp downward_camera(width, height) do
    Camera.new(
      Vector.new(0.0, 0.0, 0.0),
      Vector.new(0.0, 0.0, -1.0),
      aspect_ratio: width / height,
      vertical_fov: 90.0,
      aperture: 0.0,
      focus_dist: 1.0
    )
  end

  test "render/4 with nx: true writes a valid PPM file" do
    out = Path.join(@fixtures_dir, "nx_smoke.ppm")
    File.rm(out)

    camera = downward_camera(32, 32)

    Exray.render(camera, simple_world(), out,
      image_width: 32,
      samples_per_pixel: 4,
      max_depth: 4,
      tile_size: 32,
      sample_batch: 4,
      nx: true
    )

    assert File.exists?(out)
    [header0, header1, header2 | pixels] = out |> File.read!() |> String.split("\n", trim: true)
    assert header0 == "P3"
    assert header1 == "32 32"
    assert header2 == "255"
    assert length(pixels) == 32 * 32

    for line <- pixels do
      [r, g, b] = line |> String.split(" ") |> Enum.map(&String.to_integer/1)
      assert r in 0..255
      assert g in 0..255
      assert b in 0..255
    end

    File.rm(out)
  end

  test "render/4 with nx: true and the background-only scene produces sky colors" do
    out = Path.join(@fixtures_dir, "nx_bg.ppm")
    File.rm(out)

    # No hittables -> every ray reaches the sky background.
    camera = downward_camera(16, 16)

    Exray.render(camera, HittableList.new([]), out,
      image_width: 16,
      samples_per_pixel: 1,
      max_depth: 1,
      tile_size: 16,
      sample_batch: 1,
      nx: true
    )

    [_h0, _h1, _h2 | pixels] = out |> File.read!() |> String.split("\n", trim: true)

    for line <- pixels do
      [r, g, b] = line |> String.split(" ") |> Enum.map(&String.to_integer/1)
      assert b >= g and g >= r, "expected b >= g >= r for sky pixels, got #{line}"
    end

    File.rm(out)
  end

  test "render/4 Nx output is numerically close to the scalar renderer" do
    nx_out = Path.join(@fixtures_dir, "nx_parity.ppm")
    scalar_out = Path.join(@fixtures_dir, "scalar_parity.ppm")
    File.rm(nx_out)
    File.rm(scalar_out)

    opts = [image_width: 40, samples_per_pixel: 8, max_depth: 6, tile_size: 40]
    camera = downward_camera(40, 40)

    Exray.render(camera, simple_world(), scalar_out, opts)
    Exray.render(camera, simple_world(), nx_out, Keyword.put(opts, :nx, true))

    [_, _, _ | nx_pixels] = nx_out |> File.read!() |> String.split("\n", trim: true)
    [_, _, _ | sc_pixels] = scalar_out |> File.read!() |> String.split("\n", trim: true)

    assert length(nx_pixels) == length(sc_pixels)

    {sum_diff, count} =
      nx_pixels
      |> Enum.zip(sc_pixels)
      |> Enum.reduce({0, 0}, fn {nx_line, sc_line}, {acc, n} ->
        [nr, ng, nb] = nx_line |> String.split(" ") |> Enum.map(&String.to_integer/1)
        [sr, sg, sb] = sc_line |> String.split(" ") |> Enum.map(&String.to_integer/1)
        diff = abs(nr - sr) + abs(ng - sg) + abs(nb - sb)
        {acc + diff, n + 1}
      end)

    mean_per_channel = sum_diff / (count * 3)
    # Random samplers differ, but the image structure should be close.
    assert mean_per_channel < 25,
           "Nx vs scalar mean per-channel diff too large: #{mean_per_channel}"

    File.rm(nx_out)
    File.rm(scalar_out)
  end
end
