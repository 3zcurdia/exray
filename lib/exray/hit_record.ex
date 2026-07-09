defmodule Exray.HitRecord do
  @moduledoc """
    Snapshot of a ray hitting a surface.

    Carries the hit point, the outward-pointing normal already oriented against
    the incoming ray (`set_face_normal/3`), the ray parameter `t`, and the
    material at the hit point.
  """

  defstruct [:point, :normal, :t, :material, front_face: false]

  alias Exray.{Vector, Ray}

  @type t :: %__MODULE__{
          point: Exray.Vector.t() | nil,
          normal: Exray.Vector.t() | nil,
          t: number() | nil,
          material: term() | nil,
          front_face: boolean()
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []), do: struct(__MODULE__, opts)

  @doc """
    Orient the stored normal against the incoming ray and record whether the
    ray struck the front face of the surface.
  """
  @spec set_face_normal(t(), Ray.t(), Vector.t()) :: t()
  def set_face_normal(record, %Ray{direction: direction}, outward_normal) do
    front_face = Vector.dot(direction, outward_normal) < 0.0
    normal = if front_face, do: outward_normal, else: Vector.negate(outward_normal)
    %{record | front_face: front_face, normal: normal}
  end
end
