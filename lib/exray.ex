defmodule Exray do
  @moduledoc """
  Documentation for `Exray`.
  """

  alias Exray.PPM
  alias Exray.Color

  def render(width \\ 256, height \\ 256) do
    ppm = PPM.new(width, height)

    ppm
    |> render_pixels()
    |> PPM.write("hello.ppm")
  end

  defp render_pixels(%PPM{width: width, height: height} = ppm) do
    pixels =
      for j <- 0..(height - 1), i <- 0..(width - 1), into: [] do
        IO.write(:stderr, "\rScanlines remaining: #{height - j} ")
        "#{Color.new(i / (width - 1), j / (height - 1), 0.0)}\n"
      end

    %PPM{ppm | pixels: pixels}
  end

  # Experimental, concurrent rendering
  # def render_concurrent(width \\ 256, height \\ 256) do
  #   ppm = PPM.new(width, height)

  #   ppm
  #   |> render_pixels_concurrent()
  #   |> PPM.write("hello_concurrent.ppm")
  # end

  # defp render_pixels_concurrent(%PPM{width: width, height: height} = ppm) do
  #   max_workers = System.schedulers_online() - 1
  #   rows = height - 1

  #   pixels =
  #     0..(rows - 1)
  #     |> Task.async_stream(
  #       fn j ->
  #         row =
  #           for i <- 0..(width - 1), into: [] do
  #             "#{Color.new(i / (width - 1), j / (height - 1), 0.0)}\n"
  #           end

  #         {j, row}
  #       end,
  #       max_concurrency: max_workers
  #     )
  #     |> Enum.sort_by(fn {:ok, {index, _data}} -> index end)
  #     |> Enum.map(fn {:ok, {_index, chunk}} -> chunk end)

  #   %PPM{ppm | pixels: pixels}
  # end
end
