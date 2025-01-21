defmodule Exray.Color do
  @moduledoc """
    Apply RGB color operations to vectors
  """

  defstruct [:r, :g, :b]

  def new(r, g, b), do: %Exray.Color{r: r, g: g, b: b}

  def black, do: %Exray.Color{r: 0.0, g: 0.0, b: 0.0}
  def white, do: %Exray.Color{r: 1.0, g: 1.0, b: 1.0}
  def red, do: %Exray.Color{r: 1.0, g: 0.0, b: 0.0}
  def green, do: %Exray.Color{r: 0.0, g: 1.0, b: 0.0}
  def blue, do: %Exray.Color{r: 0.0, g: 0.0, b: 1.0}
end

defimpl String.Chars, for: Exray.Color do
  @max 255.999
  def to_string(%{r: r, g: g, b: b}) do
    [r, g, b]
    |> Enum.map(&round(&1 * @max))
    |> Enum.join(" ")
  end
end
