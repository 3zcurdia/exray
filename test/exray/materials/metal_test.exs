defmodule Exray.Materials.MetalTest do
  use ExUnit.Case, async: true

  alias Exray.Materials.Metal
  alias Exray.{Color, Ray, Vector, HitRecord, Material}

  doctest Exray.Materials.Metal

  describe "new/2" do
    test "defaults fuzz to 0.0" do
      assert %Metal{albedo: albedo, fuzz: fuzz} = Metal.new(Color.red())
      assert albedo == Color.red()
      assert fuzz == 0.0
    end

    test "clamps fuzz to [0.0, 1.0]" do
      assert %Metal{fuzz: fuzz} = Metal.new(Color.red(), 5.0)
      assert fuzz == 1.0

      assert %Metal{fuzz: fuzz} = Metal.new(Color.red(), -1.0)
      assert fuzz == 0.0
    end
  end

  describe "Material protocol implementation" do
    test "reflects a ray around the normal" do
      mat = Metal.new(Color.new(0.7, 0.7, 0.7), 0.0)
      ray_in = Ray.new(Vector.new(0, 0, -1), Vector.new(0, 0, -1))

      record = %HitRecord{
        point: Vector.zero(),
        normal: Vector.new(0, 0, 1),
        t: 1.0,
        front_face: true
      }

      assert {:ok, %Ray{}, %Color{r: 0.7}} = Material.scatter(mat, ray_in, record)
    end
  end
end
