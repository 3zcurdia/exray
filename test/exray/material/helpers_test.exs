defmodule Exray.Material.HelpersTest do
  use ExUnit.Case, async: true

  alias Exray.{Material.Helpers, Vector}

  describe "reflect/2" do
    test "reflects a vector across a unit normal" do
      v = Vector.new(1, -1, 0)
      n = Vector.new(0, 1, 0)

      assert Vector.new(1, 1, 0) == Helpers.reflect(v, n)
    end

    test "a vector parallel to the normal reflects back" do
      v = Vector.new(0, -1, 0)
      n = Vector.new(0, 1, 0)

      assert Vector.new(0, 1, 0) == Helpers.reflect(v, n)
    end
  end

  describe "refract/3" do
    test "refracts a ray that enters glass head-on" do
      uv = Vector.new(0, -1, 0)
      n = Vector.new(0, 1, 0)
      etai_over_etat = 1.0 / 1.5

      refracted = Helpers.refract(uv, n, etai_over_etat)

      assert_in_delta refracted.x, 0.0, 1.0e-9
      assert_in_delta refracted.y, -1.0, 1.0e-9
      assert_in_delta refracted.z, 0.0, 1.0e-9
    end
  end

  describe "reflectance/2" do
    test "returns the Schlick approximation for normal incidence" do
      r0 = :math.pow((1.0 - 1.5) / (1.0 + 1.5), 2)

      assert_in_delta r0, Helpers.reflectance(1.0, 1.5), 1.0e-9
    end

    test "approaches 1 as the angle of incidence approaches grazing" do
      assert_in_delta 1.0, Helpers.reflectance(0.0, 1.5), 0.05
    end
  end
end
