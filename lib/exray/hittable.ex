defprotocol Exray.Hittable do
  @moduledoc """
    Polymorphic ray-hit query.

    Implementations return `{:ok, %Exray.HitRecord{}}` for the nearest hit
    within `[t_min, t_max]`, or `:miss` when no intersection exists.

    `bounding_box/1` returns an `Exray.AABB` that encloses the object and
    is used by the BVH to prune ray tests.
  """

  alias Exray.AABB
  alias Exray.HitRecord
  alias Exray.Ray

  @spec hit(t(), Ray.t(), number(), number()) :: {:ok, HitRecord.t()} | :miss
  def hit(hittable, ray, t_min, t_max)

  @spec bounding_box(t()) :: AABB.t()
  def bounding_box(hittable)
end
