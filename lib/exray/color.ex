defmodule Exray.Color do
  @moduledoc """
    Apply RGB color operations to vectors
  """

  defstruct [:r, :g, :b]
  @type t :: %__MODULE__{r: number, g: number, b: number}

  def new(r, g, b), do: %Exray.Color{r: r, g: g, b: b}
  def new(%Exray.Vector{x: r, y: g, z: b}), do: %Exray.Color{r: r, g: g, b: b}

  def black, do: %Exray.Color{r: 0.0, g: 0.0, b: 0.0}
  def white, do: %Exray.Color{r: 1.0, g: 1.0, b: 1.0}
  def red, do: %Exray.Color{r: 1.0, g: 0.0, b: 0.0}
  def green, do: %Exray.Color{r: 0.0, g: 1.0, b: 0.0}
  def blue, do: %Exray.Color{r: 0.0, g: 0.0, b: 1.0}
end

defimpl String.Chars, for: Exray.Color do
  @max 255.999
  def to_string(%{r: r, g: g, b: b}) do
    "#{Exray.Utils.clamp(round(r * @max), 0, 255)} #{Exray.Utils.clamp(round(g * @max), 0, 255)} #{Exray.Utils.clamp(round(b * @max), 0, 255)}"
  end
end
