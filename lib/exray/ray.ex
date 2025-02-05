defmodule Exray.Ray do
  @moduledoc """
    A ray in space
  """
  defstruct [:origin, :direction]

  alias Exray.Vector

  @type t :: %__MODULE__{origin: Vector.t(), direction: Vector.t()}

  @spec new(Vector.t(), Vector.t()) :: t()
  def new(origin, direction) do
    %Exray.Ray{origin: origin, direction: direction}
  end

  @spec at(t(), number()) :: Vector.t()
  def at(%Exray.Ray{origin: origin, direction: direction}, t) do
    origin
    |> Vector.add(Vector.multiply(direction, t))
  end

  @spec unit_vector(t()) :: Vector.t()
  def unit_vector(%Exray.Ray{direction: direction}) do
    Vector.unit(direction)
  end
end
