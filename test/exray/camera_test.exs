defmodule Exray.CameraTest do
  use ExUnit.Case, async: true

  alias Exray.Camera
  alias Exray.Ray
  alias Exray.Vector

  doctest Camera

  describe "new/3" do
    test "builds a camera from a default look_from/look_at pair" do
      cam = Camera.new(Vector.new(0, 0, 0), Vector.new(0, 0, -1))

      assert %Camera{} = cam
      assert cam.origin == Vector.new(0, 0, 0)
      assert cam.lens_radius == 0.0
      assert cam.aspect_ratio == 16.0 / 9.0
    end

    test "honors custom aspect ratio and focus distance" do
      cam = Camera.new(Vector.zero(), Vector.new(0, 0, -1), aspect_ratio: 1.0, focus_dist: 2.0)

      assert cam.aspect_ratio == 1.0
      assert cam.lens_radius == 0.0
    end

    test "sets lens_radius from aperture option" do
      cam = Camera.new(Vector.zero(), Vector.new(0, 0, -1), aperture: 0.5)

      assert cam.lens_radius == 0.25
    end
  end

  describe "image_dimensions/2" do
    test "derives height from aspect ratio" do
      cam = Camera.new(Vector.zero(), Vector.new(0, 0, -1))
      assert {400, 225} = Camera.image_dimensions(cam, 400)
    end

    test "clamps height to at least 1" do
      cam = Camera.new(Vector.zero(), Vector.new(0, 0, -1), aspect_ratio: 100.0)
      assert {_width, 1} = Camera.image_dimensions(cam, 100)
    end
  end

  describe "get_ray/3" do
    test "returns a ray at the center of the viewport" do
      cam = Camera.new(Vector.zero(), Vector.new(0, 0, -1))

      assert %Ray{} = ray = Camera.get_ray(cam, 0.5, 0.5)
      assert Vector.mod(ray.direction) > 0.0
    end

    test "returns a ray at the corners" do
      cam = Camera.new(Vector.zero(), Vector.new(0, 0, -1))

      assert %Ray{} = Camera.get_ray(cam, 0.0, 0.0)
      assert %Ray{} = Camera.get_ray(cam, 1.0, 1.0)
    end
  end
end
