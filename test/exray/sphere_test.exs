defmodule Exray.SphereTest do
  use ExUnit.Case, async: true

  alias Exray.Color
  alias Exray.HitRecord
  alias Exray.Hittable
  alias Exray.Materials.Lambertian
  alias Exray.Ray
  alias Exray.Sphere
  alias Exray.Vector

  doctest Sphere

  describe "new/2 and new/3" do
    test "builds a sphere from a vector center" do
      assert %Sphere{center: %Vector{}, radius: 1.0} = Sphere.new(Vector.new(0, 0, 0), 1.0)
    end

    test "builds a sphere from a tuple center" do
      assert %Sphere{center: %Vector{x: 1, y: 2, z: 3}, radius: 2.5} = Sphere.new({1, 2, 3}, 2.5)
    end

    test "defaults to a Lambertian material" do
      sphere = Sphere.new(Vector.new(0, 0, 0), 1.0)

      assert %Lambertian{} = sphere.material
    end

    test "honors a custom material" do
      mat = Lambertian.new(Color.red())
      assert %Sphere{material: ^mat} = Sphere.new(Vector.new(0, 0, 0), 1.0, mat)
    end
  end

  describe "Hittable protocol implementation" do
    test "returns :miss when the ray is far from the sphere" do
      sphere = Sphere.new(Vector.new(0, 0, 0), 1.0)
      ray = Ray.new(Vector.new(0, 0, 5), Vector.new(1, 0, 0))

      assert :miss = Hittable.hit(sphere, ray, 0.001, 1.0e12)
    end

    test "returns a hit record with a front-face normal for a head-on hit" do
      sphere = Sphere.new(Vector.new(0, 0, -2), 1.0)
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(0, 0, -1))

      assert {:ok, %HitRecord{front_face: true, normal: %Vector{} = n, t: t}} =
               Hittable.hit(sphere, ray, 0.001, 1.0e12)

      assert_in_delta t, 1.0, 1.0e-9
      assert_in_delta n.x, 0.0, 1.0e-9
      assert_in_delta n.y, 0.0, 1.0e-9
      assert_in_delta n.z, 1.0, 1.0e-9
    end

    test "flips the normal when the ray hits the back face" do
      sphere = Sphere.new(Vector.new(0, 0, 0), 1.0)
      ray = Ray.new(Vector.zero(), Vector.new(0, 0, 1))

      assert {:ok, %HitRecord{front_face: false, normal: %Vector{z: z}}} =
               Hittable.hit(sphere, ray, 0.001, 1.0e12)

      assert_in_delta z, -1.0, 1.0e-9
    end

    test "carries the sphere's material into the hit record" do
      mat = Lambertian.new(Color.red())
      sphere = Sphere.new(Vector.new(0, 0, -2), 1.0, mat)
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(0, 0, -1))

      assert {:ok, %HitRecord{material: ^mat}} = Hittable.hit(sphere, ray, 0.001, 1.0e12)
    end

    test "respects the t_min bound" do
      sphere = Sphere.new(Vector.new(0, 0, -2), 1.0)
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(0, 0, -1))

      assert :miss = Hittable.hit(sphere, ray, 2.0, 2.9)
    end

    test "uses the farther root when the nearer root is below t_min" do
      sphere = Sphere.new(Vector.new(0, 0, 0), 1.0)
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(0, 0, 1))

      assert {:ok, %HitRecord{t: t, front_face: false, normal: %Vector{z: z}}} =
               Hittable.hit(sphere, ray, 0.001, 1.0e12)

      assert_in_delta t, 1.0, 1.0e-9
      assert_in_delta z, -1.0, 1.0e-9
    end
  end
end
