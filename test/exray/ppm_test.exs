defmodule Exray.PPMTest do
  use ExUnit.Case, async: true

  alias Exray.PPM

  doctest PPM

  describe "write/2" do
    test "writes the PPM header followed by the pixel rows" do
      ppm = %PPM{width: 2, height: 2, pixels: ["1 2 3\n", "4 5 6\n", "7 8 9\n", "10 11 12\n"]}

      path =
        Path.join(System.tmp_dir!(), "exray_ppm_test_#{System.unique_integer([:positive])}.ppm")

      try do
        assert :ok = PPM.write(ppm, path)
        assert File.read!(path) == "P3\n2 2\n255\n1 2 3\n4 5 6\n7 8 9\n10 11 12\n"
      after
        File.rm(path)
      end
    end
  end

  describe "String.Chars protocol" do
    test "encodes a PPM as the P3 header and pixel rows" do
      ppm = %PPM{width: 1, height: 1, pixels: ["0 0 0\n"]}

      assert to_string(ppm) == "P3\n1 1\n255\n0 0 0\n"
    end
  end
end
