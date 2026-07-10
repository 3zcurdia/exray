defmodule Exray.HittableList do
  @moduledoc """
    An ordered collection of hittable objects. Implements `Exray.Hittable`,
    reporting the nearest hit among all members within `[t_min, t_max]`.

    The list is internally accelerated by an `Exray.BVHNode` built from
    `objects` on construction (and rebuilt on each `add/2` and `clear/1`),
    so hit tests run in roughly `O(log N)` instead of `O(N)`.

    Used by `Exray.Camera` / `Exray.render` as the scene (`World` in the
    original Ruby implementation).
  """

  alias Exray.BVHNode

  defstruct objects: [], bvh: nil

  @type t :: %__MODULE__{objects: [Exray.Hittable.t()], bvh: BVHNode.t()}

  @spec new([Exray.Hittable.t()]) :: t()
  def new(objects \\ []) do
    %__MODULE__{objects: objects, bvh: BVHNode.build(objects)}
  end

  @spec add(t(), Exray.Hittable.t()) :: t()
  def add(%__MODULE__{objects: objects}, object) do
    new(objects ++ [object])
  end

  @spec clear(t()) :: t()
  def clear(_list), do: new([])
end

defimpl Exray.Hittable, for: Exray.HittableList do
  alias Exray.AABB
  alias Exray.Hittable

  @spec hit(Exray.HittableList.t(), Exray.Ray.t(), number(), number()) ::
          {:ok, Exray.HitRecord.t()} | :miss
  def hit(%Exray.HittableList{bvh: bvh}, ray, t_min, t_max) do
    Hittable.hit(bvh, ray, t_min, t_max)
  end

  @spec bounding_box(Exray.HittableList.t()) :: AABB.t()
  def bounding_box(%Exray.HittableList{bvh: bvh}), do: Hittable.bounding_box(bvh)
end
