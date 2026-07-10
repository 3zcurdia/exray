defmodule Exray.BVHNode do
  @moduledoc """
    Bounding Volume Hierarchy node.

    Built by recursively splitting a list of hittables along the longest
    axis of their combined bounding box. The leaf `left` slot stores the
    hittable itself; internal nodes have both `left` and `right` set to
    child `BVHNode`s. Hit tests prune subtrees by first testing the
    precomputed `bbox`.
  """

  alias Exray.AABB
  alias Exray.Hittable

  defstruct [:left, :right, :bbox]

  @type t :: %__MODULE__{
          left: Hittable.t() | nil,
          right: Hittable.t() | nil,
          bbox: AABB.t()
        }

  @doc """
    Build a BVH from a list of hittables. Returns a node with an empty
    `bbox` for an empty list; such a node never reports a hit.
  """
  @spec build([Hittable.t()]) :: t()
  def build([]), do: %__MODULE__{left: nil, right: nil, bbox: AABB.empty()}

  def build([single]) do
    %__MODULE__{left: single, right: nil, bbox: Hittable.bounding_box(single)}
  end

  def build([_ | _] = objects) do
    bbox =
      Enum.reduce(objects, AABB.empty(), fn object, acc ->
        AABB.union(acc, Hittable.bounding_box(object))
      end)

    axis = AABB.longest_axis(bbox)

    sorted =
      Enum.sort_by(objects, fn object ->
        object |> Hittable.bounding_box() |> AABB.center() |> component(axis)
      end)

    {left_objs, right_objs} = Enum.split(sorted, div(length(sorted), 2))

    new(build(left_objs), build(right_objs))
  end

  @doc """
    Wrap two children in an internal node, computing the union of their
    bounding boxes.
  """
  @spec new(t(), t()) :: t()
  def new(%__MODULE__{} = left, %__MODULE__{} = right) do
    %__MODULE__{
      left: left,
      right: right,
      bbox: AABB.union(left.bbox, right.bbox)
    }
  end

  defp component(%{x: v}, :x), do: v
  defp component(%{y: v}, :y), do: v
  defp component(%{z: v}, :z), do: v
end

defimpl Exray.Hittable, for: Exray.BVHNode do
  alias Exray.AABB
  alias Exray.HitRecord
  alias Exray.Hittable
  alias Exray.Ray

  @spec hit(Exray.BVHNode.t(), Ray.t(), number(), number()) ::
          {:ok, HitRecord.t()} | :miss
  def hit(%Exray.BVHNode{bbox: bbox, left: left, right: right}, %Ray{} = ray, t_min, t_max) do
    if AABB.hit?(bbox, ray, t_min, t_max) do
      hit_children(left, right, ray, t_min, t_max)
    else
      :miss
    end
  end

  defp hit_children(left, nil, ray, t_min, t_max) do
    Hittable.hit(left, ray, t_min, t_max)
  end

  defp hit_children(left, right, ray, t_min, t_max) do
    case Hittable.hit(left, ray, t_min, t_max) do
      :miss ->
        Hittable.hit(right, ray, t_min, t_max)

      {:ok, left_record} ->
        case Hittable.hit(right, ray, t_min, left_record.t) do
          :miss -> {:ok, left_record}
          {:ok, right_record} -> {:ok, closest(left_record, right_record)}
        end
    end
  end

  defp closest(%HitRecord{t: ta} = a, %HitRecord{t: tb} = b) do
    if ta <= tb, do: a, else: b
  end

  @spec bounding_box(Exray.BVHNode.t()) :: AABB.t()
  def bounding_box(%Exray.BVHNode{bbox: bbox}), do: bbox
end
