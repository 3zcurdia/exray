defmodule Exray do
  @moduledoc """
  Documentation for `Exray`.
  """

  alias Exray.PPM
  alias Exray.Color

  def render(width \\ 256, height \\ 256)

  def render(width, height) do
    ppm = PPM.new(width, height)

    ppm
    |> render_pixels()
    |> PPM.write("hello.ppm")
  end

  defp render_pixels(%PPM{width: width, height: height} = ppm) do
    pixels =
      for j <- 0..(height - 1), i <- 0..(width - 1), into: [] do
        "#{Color.new(i / (width - 1), j / (height - 1), 0.0)}\n"
      end

    %PPM{ppm | pixels: pixels}
  end
end
