defmodule Exray.BVHNodeTest do
  use ExUnit.Case, async: true

  alias Exray.BVHNode
  alias Exray.HitRecord
  alias Exray.Hittable
  alias Exray.Ray
  alias Exray.Sphere
  alias Exray.Vector

  describe "build/1" do
    test "returns an empty node for an empty list" do
      node = BVHNode.build([])

      assert %BVHNode{left: nil, right: nil} = node
    end

    test "wraps a single object as a leaf" do
      sphere = Sphere.new(Vector.new(0, 0, -2), 0.5)
      node = BVHNode.build([sphere])

      assert ^sphere = node.left
      assert is_nil(node.right)
    end

    test "wraps two objects in an internal node" do
      a = Sphere.new(Vector.new(0, 0, -2), 0.5)
      b = Sphere.new(Vector.new(0, 0, -5), 1.0)
      node = BVHNode.build([a, b])

      assert %BVHNode{left: %BVHNode{}, right: %BVHNode{}} = node
    end
  end

  describe "Hittable protocol implementation" do
    test "returns :miss for an empty BVH" do
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(0, 0, -1))

      assert :miss = Hittable.hit(BVHNode.build([]), ray, 0.001, 1.0e12)
    end

    test "returns the only hit for a single-object BVH" do
      sphere = Sphere.new(Vector.new(0, 0, -2), 0.5)
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(0, 0, -1))

      assert {:ok, %HitRecord{t: t}} = Hittable.hit(BVHNode.build([sphere]), ray, 0.001, 1.0e12)
      assert_in_delta t, 1.5, 1.0e-9
    end

    test "returns the closest hit among many objects" do
      near = Sphere.new(Vector.new(0, 0, -2), 0.5)
      far = Sphere.new(Vector.new(0, 0, -5), 1.0)
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(0, 0, -1))

      assert {:ok, %HitRecord{t: t}} = Hittable.hit(BVHNode.build([far, near]), ray, 0.001, 1.0e12)
      assert_in_delta t, 1.5, 1.0e-9
    end

    test "returns :miss when no object is hit" do
      sphere = Sphere.new(Vector.new(0, 0, -2), 0.5)
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(1, 0, 0))

      assert :miss = Hittable.hit(BVHNode.build([sphere]), ray, 0.001, 1.0e12)
    end

    test "scales to a large scene without losing the closest hit" do
      spheres =
        for x <- -5..5, y <- 1..5 do
          Sphere.new(Vector.new(x * 2.0, 0.0, y * 4.0), 0.1)
        end

      target = Sphere.new(Vector.new(0, 0, -2), 0.5)
      ray = Ray.new(Vector.new(0, 0, 0), Vector.new(0, 0, -1))

      assert {:ok, %HitRecord{t: t, material: mat}} =
               Hittable.hit(BVHNode.build([target | spheres]), ray, 0.001, 1.0e12)

      assert_in_delta t, 1.5, 1.0e-9
      assert mat == target.material
    end
  end

  describe "bounding_box/1" do
    test "returns the precomputed bbox of an internal node" do
      a = Sphere.new(Vector.new(0, 0, -2), 0.5)
      b = Sphere.new(Vector.new(0, 0, -5), 1.0)
      node = BVHNode.build([a, b])

      bbox = Hittable.bounding_box(node)

      assert %Exray.AABB{} = bbox
      assert bbox.min.z <= -1.5
      assert bbox.max.z >= -4.0
    end
  end
end
