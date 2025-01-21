defmodule Exray.Utils do
  @moduledoc """
  Utility functions
  """

  @doc """
  Converts degree to radians

  ## Examples

      iex> Exray.Utils.degree_to_radian(90)
      1.5707963267948966
      iex> Exray.Utils.degree_to_radian(180)
      3.141592653589793
      iex> Exray.Utils.degree_to_radian(360)
      6.283185307179586
  """
  @spec degree_to_radian(number) :: number
  def degree_to_radian(degree) do
    degree * :math.pi() / 180.0
  end

  @doc """
  Clamp a value between a min and max

  ## Examples

      iex> Exray.Utils.clamp(1, 0, 2)
      1

      iex> Exray.Utils.clamp(3, 0, 2)
      2

      iex> Exray.Utils.clamp(-1, 0, 2)
      0
  """
  @spec clamp(number, number, number) :: number
  def clamp(value, min, max) do
    cond do
      value < min -> min
      value > max -> max
      true -> value
    end
  end
end
