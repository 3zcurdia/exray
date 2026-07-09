defmodule Exray.Sphere do
  @moduledoc false
  alias Exray.Vector

  defstruct [:center, :radius]

  @type t :: %__MODULE__{center: Vector.t(), radius: number()}

  def new(%Vector{} = center, radius) do
    %__MODULE__{center: center, radius: radius}
  end

  def new({x, y, z}, radius) do
    %__MODULE__{center: Vector.new(x, y, z), radius: radius}
  end

  def hit?(%__MODULE__{center: center, radius: radius}, ray) do
    oc = Vector.subtract(center, ray.origin)
    a = Vector.dot(ray.direction, ray.direction)
    b = Vector.dot(ray.direction, oc) * -2.0
    c = Vector.dot(oc, oc) - radius * radius
    discriminant = b * b - 4 * a * c
    discriminant >= 0
  end
end
