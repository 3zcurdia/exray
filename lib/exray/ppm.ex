defmodule Exray.PPM do
  @moduledoc """
    A PPM image
  """

  defstruct [:width, :height, :pixels]

  @doc """
  It buils a ppm structure

  ## Examples

      iex> Exray.PPM.new(100, 100)
      %Exray.PPM{height: 100, width: 100, pixels: []}
  """
  def new(width, height) do
    %Exray.PPM{width: width, height: height, pixels: []}
  end

  def write(ppm, filename) do
    File.write(filename, to_string(ppm))
  end
end

defimpl String.Chars, for: Exray.PPM do
  def to_string(%{width: width, height: height, pixels: pixels}) do
    ["P3\n", "#{width} #{height}\n", "255\n" | pixels]
  end
end
