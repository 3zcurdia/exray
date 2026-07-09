defmodule Exray.RayTest do
  use ExUnit.Case, async: true

  alias Exray.Ray
  alias Exray.Vector

  doctest Ray

  describe "new/2" do
    test "builds a ray with origin and direction" do
      origin = Vector.new(0, 0, 0)
      direction = Vector.new(1, 0, 0)

      assert %Ray{origin: ^origin, direction: ^direction} = Ray.new(origin, direction)
    end
  end

  describe "at/2" do
    test "returns the origin when t = 0" do
      ray = Ray.new(Vector.new(1, 2, 3), Vector.new(1, 0, 0))

      assert Vector.new(1, 2, 3) == Ray.at(ray, 0)
    end

    test "translates along the direction by t" do
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(1, 0, 0))

      assert Vector.new(5, 0, 0) == Ray.at(ray, 5)
    end
  end

  describe "unit_vector/1" do
    test "returns a unit-length version of the direction" do
      ray = Ray.new(Vector.zero(), Vector.new(3, 0, 0))

      assert Vector.new(1, 0, 0) == Ray.unit_vector(ray)
    end
  end
end
