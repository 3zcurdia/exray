defmodule Exray.Materials.LambertianTest do
  use ExUnit.Case, async: true

  alias Exray.Materials.Lambertian
  alias Exray.{Color, Ray, Vector, HitRecord, Material}

  doctest Exray.Materials.Lambertian

  describe "new/1" do
    test "defaults to a black albedo" do
      assert %Lambertian{albedo: albedo} = Lambertian.new()
      assert albedo == Color.black()
    end

    test "accepts a custom albedo" do
      albedo = Color.new(0.2, 0.3, 0.4)

      assert %Lambertian{albedo: ^albedo} = Lambertian.new(albedo)
    end
  end

  describe "Material protocol implementation" do
    test "returns a scattered ray and the albedo" do
      mat = Lambertian.new(Color.new(0.5, 0.5, 0.5))
      ray_in = Ray.new(Vector.zero(), Vector.new(0, 0, -1))

      record = %HitRecord{
        point: Vector.new(0, 0, 0),
        normal: Vector.new(0, 1, 0),
        t: 1.0
      }

      assert {:ok, %Ray{origin: origin}, %Color{} = attenuation} =
               Material.scatter(mat, ray_in, record)

      assert origin == Vector.new(0, 0, 0)
      assert attenuation == Color.new(0.5, 0.5, 0.5)
    end
  end
end
