defmodule Exray.Ray do
  @moduledoc """
    A ray in space
  """
  defstruct [:origin, :direction]

  alias Exray.Vector

  def at(%Exray.Ray{origin: origin, direction: direction}, t) do
    Vector.add(origin, Vector.multiply(direction, t))
  end

  def unit_vector(%Exray.Ray{direction: direction}) do
    Vector.unit(direction)
  end
end
