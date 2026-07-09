defmodule Exray.HitRecordTest do
  use ExUnit.Case, async: true

  alias Exray.{HitRecord, Ray, Vector, Materials.Lambertian}

  describe "new/1" do
    test "builds a record with the given fields" do
      point = Vector.new(1, 2, 3)
      mat = Lambertian.new()

      record = HitRecord.new(point: point, normal: Vector.new(0, 1, 0), t: 1.5, material: mat)

      assert record.point == point
      assert record.normal == Vector.new(0, 1, 0)
      assert record.t == 1.5
      assert record.material == mat
      assert record.front_face == false
    end

    test "defaults to nil fields and front_face false" do
      assert %HitRecord{point: nil, normal: nil, t: nil, material: nil, front_face: false} =
               HitRecord.new()
    end
  end

  describe "set_face_normal/3" do
    test "keeps the outward normal when ray hits the front face" do
      record = HitRecord.new()
      ray = Ray.new(Vector.zero(), Vector.new(0, 0, -1))
      outward = Vector.new(0, 0, 1)

      updated = HitRecord.set_face_normal(record, ray, outward)

      assert updated.front_face == true
      assert updated.normal == outward
    end

    test "flips the normal when ray hits the back face" do
      record = HitRecord.new()
      ray = Ray.new(Vector.zero(), Vector.new(0, 0, 1))
      outward = Vector.new(0, 0, 1)

      updated = HitRecord.set_face_normal(record, ray, outward)

      assert updated.front_face == false
      assert updated.normal == Vector.new(0, 0, -1)
    end
  end
end
