defmodule Exray.ColorTest do
  use ExUnit.Case, async: true

  alias Exray.{Color, Vector}

  doctest Exray.Color

  describe "new/3 and new/1" do
    test "builds a color from three components" do
      assert %Color{r: 0.1, g: 0.2, b: 0.3} = Color.new(0.1, 0.2, 0.3)
    end

    test "builds a color from a vector" do
      assert %Color{r: 1.0, g: 2.0, b: 3.0} = Color.new(Vector.new(1.0, 2.0, 3.0))
    end
  end

  describe "preset colors" do
    test "black is (0, 0, 0)" do
      assert Color.black() == %Color{r: 0.0, g: 0.0, b: 0.0}
    end

    test "white is (1, 1, 1)" do
      assert Color.white() == %Color{r: 1.0, g: 1.0, b: 1.0}
    end

    test "red, green and blue are axis colors" do
      assert Color.red() == %Color{r: 1.0, g: 0.0, b: 0.0}
      assert Color.green() == %Color{r: 0.0, g: 1.0, b: 0.0}
      assert Color.blue() == %Color{r: 0.0, g: 0.0, b: 1.0}
    end
  end

  describe "multiply/2" do
    test "scales a color by a scalar" do
      assert Color.multiply(Color.red(), 0.5) == %Color{r: 0.5, g: 0.0, b: 0.0}
    end

    test "multiplies component-wise by another color" do
      assert Color.multiply(Color.white(), Color.red()) == %Color{r: 1.0, g: 0.0, b: 0.0}
    end
  end

  describe "random/0 and random/2" do
    test "random/0 produces components in [0, 1)" do
      %Color{r: r, g: g, b: b} = Color.random()
      assert r >= 0.0 and r < 1.0
      assert g >= 0.0 and g < 1.0
      assert b >= 0.0 and b < 1.0
    end

    test "random/2 produces components in [min, max)" do
      %Color{r: r, g: g, b: b} = Color.random(0.25, 0.5)

      assert Enum.all?([r, g, b], &(&1 >= 0.25 and &1 < 0.5))
    end
  end

  describe "to_ppm_string/2" do
    test "encodes black at any sample count as '0 0 0'" do
      assert "0 0 0" = Color.to_ppm_string(Color.black(), 100)
    end

    test "applies gamma correction and per-sample scaling" do
      assert "128 128 128" = Color.to_ppm_string(Color.new(0.25, 0.25, 0.25), 1)
    end
  end
end
