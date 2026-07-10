defmodule Exray.AABBTest do
  use ExUnit.Case, async: true

  alias Exray.AABB
  alias Exray.Ray
  alias Exray.Vector

  doctest AABB

  describe "new/2" do
    test "stores the given min and max vectors" do
      min = Vector.zero()
      max = Vector.new(1, 1, 1)

      assert %AABB{min: ^min, max: ^max} = AABB.new(min, max)
    end
  end

  describe "empty/0" do
    test "returns a box where min exceeds max on every axis" do
      box = AABB.empty()

      assert AABB.empty?(box)
    end
  end

  describe "empty?/1" do
    test "is false for a non-empty box" do
      box = AABB.new(Vector.zero(), Vector.new(1, 1, 1))

      refute AABB.empty?(box)
    end

    test "is true when min exceeds max on x" do
      box = AABB.new(Vector.new(2, 0, 0), Vector.new(1, 1, 1))

      assert AABB.empty?(box)
    end

    test "is true when min exceeds max on y" do
      box = AABB.new(Vector.new(0, 2, 0), Vector.new(1, 1, 1))

      assert AABB.empty?(box)
    end

    test "is true when min exceeds max on z" do
      box = AABB.new(Vector.new(0, 0, 2), Vector.new(1, 1, 1))

      assert AABB.empty?(box)
    end
  end

  describe "center/1" do
    test "returns the midpoint of the box" do
      box = AABB.new(Vector.new(-2, -4, -6), Vector.new(2, 4, 6))

      assert Vector.new(0, 0, 0) == AABB.center(box)
    end
  end

  describe "union/2" do
    test "returns the smallest box that contains both inputs" do
      a = AABB.new(Vector.new(0.0, 0.0, 0.0), Vector.new(1.0, 1.0, 1.0))
      b = AABB.new(Vector.new(0.5, -1.0, 2.0), Vector.new(2.0, 0.5, 3.0))

      result = AABB.union(a, b)

      assert_in_delta result.min.x, 0.0, 1.0e-9
      assert_in_delta result.min.y, -1.0, 1.0e-9
      assert_in_delta result.min.z, 0.0, 1.0e-9
      assert_in_delta result.max.x, 2.0, 1.0e-9
      assert_in_delta result.max.y, 1.0, 1.0e-9
      assert_in_delta result.max.z, 3.0, 1.0e-9
    end
  end

  describe "longest_axis/1" do
    test "returns :x when the box is widest along x" do
      box = AABB.new(Vector.zero(), Vector.new(10, 1, 1))
      assert :x = AABB.longest_axis(box)
    end

    test "returns :y when the box is tallest along y" do
      box = AABB.new(Vector.zero(), Vector.new(1, 10, 1))
      assert :y = AABB.longest_axis(box)
    end

    test "returns :z when the box is deepest along z" do
      box = AABB.new(Vector.zero(), Vector.new(1, 1, 10))
      assert :z = AABB.longest_axis(box)
    end

    test "breaks ties in favor of x over y and z" do
      box = AABB.new(Vector.zero(), Vector.new(1, 1, 1))
      assert :x = AABB.longest_axis(box)
    end
  end

  describe "hit?/4" do
    test "returns true for a ray that pierces the box head-on" do
      box = AABB.new(Vector.new(-1, -1, -1), Vector.new(1, 1, 1))
      ray = Ray.new(Vector.new(0, 0, -5), Vector.new(0, 0, 1))

      assert AABB.hit?(box, ray, 0.001, 1.0e12)
    end

    test "returns false for a ray that misses the box" do
      box = AABB.new(Vector.new(-1, -1, -1), Vector.new(1, 1, 1))
      ray = Ray.new(Vector.new(5, 0, 0), Vector.new(1, 0, 0))

      refute AABB.hit?(box, ray, 0.001, 1.0e12)
    end

    test "returns false when the only hit lies outside [t_min, t_max]" do
      box = AABB.new(Vector.new(-1, -1, -1), Vector.new(1, 1, 1))
      ray = Ray.new(Vector.new(0, 0, 5), Vector.new(0, 0, 1))

      refute AABB.hit?(box, ray, 0.001, 1.0)
    end

    test "returns true for a ray that starts inside the box" do
      box = AABB.new(Vector.new(-1, -1, -1), Vector.new(1, 1, 1))
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(0, 0, 1))

      assert AABB.hit?(box, ray, 0.001, 1.0e12)
    end

    test "handles rays whose direction is zero along an axis" do
      box = AABB.new(Vector.new(-1, -1, -1), Vector.new(1, 1, 1))

      # Ray parallel to the y axis, origin inside the slab in y, sweeping x.
      inside = Ray.new(Vector.new(0, 0, 0), Vector.new(1, 0, 0))
      assert AABB.hit?(box, inside, 0.001, 1.0e12)

      # Ray parallel to the y axis, origin outside the slab in y, sweeping x.
      outside = Ray.new(Vector.new(0, 5, 0), Vector.new(1, 0, 0))
      refute AABB.hit?(box, outside, 0.001, 1.0e12)
    end

    test "always returns false for an empty box" do
      ray = Ray.new(Vector.new(0, 0, -5), Vector.new(0, 0, 1))

      refute AABB.hit?(AABB.empty(), ray, 0.001, 1.0e12)
    end
  end
end
