defmodule Exray.HittableListTest do
  use ExUnit.Case, async: true

  alias Exray.HitRecord
  alias Exray.Hittable
  alias Exray.HittableList
  alias Exray.Ray
  alias Exray.Sphere
  alias Exray.Vector

  describe "new/1" do
    test "builds an empty list by default" do
      assert %HittableList{objects: []} = HittableList.new()
    end

    test "builds a list with the given objects" do
      sphere = Sphere.new(Vector.new(0, 0, 0), 1.0)

      assert %HittableList{objects: [^sphere]} = HittableList.new([sphere])
    end
  end

  describe "add/2" do
    test "appends an object to the list" do
      list = HittableList.new()
      sphere = Sphere.new(Vector.new(0, 0, 0), 1.0)

      updated = HittableList.add(list, sphere)

      assert updated.objects == [sphere]
    end

    test "preserves existing objects" do
      a = Sphere.new(Vector.new(0, 0, 0), 1.0)
      b = Sphere.new(Vector.new(2, 0, 0), 1.0)

      updated =
        [a]
        |> HittableList.new()
        |> HittableList.add(b)

      assert updated.objects == [a, b]
    end
  end

  describe "clear/1" do
    test "removes all objects from the list" do
      list = HittableList.new([Sphere.new(Vector.new(0, 0, 0), 1.0)])

      assert %HittableList{objects: []} = HittableList.clear(list)
    end
  end

  describe "Hittable protocol implementation" do
    test "reports :miss for an empty list" do
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(0, 0, -1))

      assert :miss = Hittable.hit(HittableList.new(), ray, 0.001, 1.0e12)
    end

    test "returns the closest hit among all objects" do
      near = Sphere.new(Vector.new(0, 0, -2), 0.5)
      far = Sphere.new(Vector.new(0, 0, -5), 1.0)
      list = HittableList.new([far, near])
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(0, 0, -1))

      assert {:ok, %HitRecord{t: t}} = Hittable.hit(list, ray, 0.001, 1.0e12)
      assert_in_delta t, 1.5, 1.0e-9
    end

    test "returns :miss when the ray misses every object" do
      list = HittableList.new([Sphere.new(Vector.new(0, 0, -2), 0.5)])
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(1, 0, 0))

      assert :miss = Hittable.hit(list, ray, 0.001, 1.0e12)
    end
  end
end
