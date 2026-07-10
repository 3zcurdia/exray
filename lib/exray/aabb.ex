defmodule Exray.AABB do
  @moduledoc """
    Axis-aligned bounding box used to prune ray tests in the BVH.

    A box is the half-open region `[min, max]` along each axis. `min` and
    `max` may be any real vectors; the box is empty when `min` has any
    component greater than `max` (see `empty?/1`).
  """

  alias Exray.Ray
  alias Exray.Vector

  defstruct [:min, :max]

  @type t :: %__MODULE__{min: Vector.t(), max: Vector.t()}

  @doc """
    Build an AABB from two corner vectors.

    ## Examples

        iex> Exray.AABB.new(Exray.Vector.zero(), Exray.Vector.new(1.0, 1.0, 1.0))
        %Exray.AABB{min: %Exray.Vector{x: 0.0, y: 0.0, z: 0.0}, max: %Exray.Vector{x: 1.0, y: 1.0, z: 1.0}}
  """
  @spec new(Vector.t(), Vector.t()) :: t()
  def new(%Vector{} = min, %Vector{} = max), do: %__MODULE__{min: min, max: max}

  @infinity 1.0e30

  @doc """
    An empty AABB that contains no points. Used as the identity for `union/2`.
  """
  @spec empty() :: t()
  def empty,
    do: %__MODULE__{
      min: %Vector{x: @infinity, y: @infinity, z: @infinity},
      max: %Vector{x: -@infinity, y: -@infinity, z: -@infinity}
    }

  @doc """
    True if the box contains no points (its `min` exceeds its `max` along
    some axis).
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{min: min, max: max}) do
    min.x > max.x or min.y > max.y or min.z > max.z
  end

  @doc """
    Geometric center of the box. For an empty box the components are NaN.
  """
  @spec center(t()) :: Vector.t()
  def center(%__MODULE__{min: min, max: max}) do
    %Vector{x: (min.x + max.x) / 2.0, y: (min.y + max.y) / 2.0, z: (min.z + max.z) / 2.0}
  end

  @doc """
    Bounding box that contains both inputs.
  """
  @spec union(t(), t()) :: t()
  def union(%__MODULE__{min: a_min, max: a_max}, %__MODULE__{min: b_min, max: b_max}) do
    %__MODULE__{
      min: %Vector{x: Kernel.min(a_min.x, b_min.x), y: Kernel.min(a_min.y, b_min.y), z: Kernel.min(a_min.z, b_min.z)},
      max: %Vector{x: Kernel.max(a_max.x, b_max.x), y: Kernel.max(a_max.y, b_max.y), z: Kernel.max(a_max.z, b_max.z)}
    }
  end

  @doc """
    The axis (`x`, `y`, or `z`) along which the box has the largest extent.
    Used by the BVH to choose a split plane.
  """
  @spec longest_axis(t()) :: :x | :y | :z
  def longest_axis(%__MODULE__{min: min, max: max}) do
    dx = max.x - min.x
    dy = max.y - min.y
    dz = max.z - min.z

    cond do
      dx >= dy and dx >= dz -> :x
      dy >= dz -> :y
      true -> :z
    end
  end

  @doc """
    Slab-method ray vs. AABB intersection. Returns `true` iff `ray` hits
    the box for some `t` inside `[t_min, t_max]`. Direction components of
    zero are handled (a ray parallel to a slab either is always inside
    that slab or never enters it).
  """
  @spec hit?(t(), Ray.t(), number(), number()) :: boolean()
  def hit?(%__MODULE__{min: min, max: max}, %Ray{origin: origin, direction: direction}, t_min, t_max) do
    case slab(min.x, max.x, origin.x, direction.x, t_min, t_max) do
      :miss ->
        false

      {t_min, t_max} ->
        case slab(min.y, max.y, origin.y, direction.y, t_min, t_max) do
          :miss -> false
          {t_min, t_max} -> hit_z(min, max, origin, direction, t_min, t_max)
        end
    end
  end

  defp hit_z(min, max, origin, direction, t_min, t_max) do
    case slab(min.z, max.z, origin.z, direction.z, t_min, t_max) do
      :miss -> false
      {t_min, t_max} -> t_max > t_min
    end
  end

  defp slab(min, max, origin, 0, t_min, t_max) do
    if origin < min or origin > max, do: :miss, else: {t_min, t_max}
  end

  defp slab(min, max, origin, direction, t_min, t_max) do
    inv_d = 1.0 / direction
    t0 = (min - origin) * inv_d
    t1 = (max - origin) * inv_d
    {t0, t1} = if t0 > t1, do: {t1, t0}, else: {t0, t1}
    t_min = Kernel.max(t_min, t0)
    t_max = Kernel.min(t_max, t1)

    if t_max <= t_min, do: :miss, else: {t_min, t_max}
  end
end
