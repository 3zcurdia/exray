defmodule Exray.Materials.DielectricTest do
  use ExUnit.Case, async: true

  alias Exray.Materials.Dielectric

  doctest Exray.Materials.Dielectric

  describe "new/1" do
    test "defaults the index of refraction to 1.5" do
      assert %Dielectric{index_of_refraction: 1.5} = Dielectric.new()
    end

    test "honors a custom index of refraction" do
      assert %Dielectric{index_of_refraction: 2.4} = Dielectric.new(2.4)
    end
  end

  describe "Material protocol implementation" do
    test "always returns white attenuation on a hit" do
      mat = Dielectric.new()
      ray_in = %Exray.Ray{origin: nil, direction: Exray.Vector.new(0, 0, -1)}

      record = %Exray.HitRecord{
        point: Exray.Vector.new(0, 0, 0),
        normal: Exray.Vector.new(0, 0, 1),
        t: 1.0,
        front_face: true
      }

      assert {:ok, %Exray.Ray{}, %Exray.Color{r: 1.0, g: 1.0, b: 1.0}} =
               Exray.Material.scatter(mat, ray_in, record)
    end
  end
end
