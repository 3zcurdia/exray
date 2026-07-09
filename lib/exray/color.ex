defmodule Exray.Color do
  @moduledoc """
    Apply RGB color operations to vectors.

    `r`, `g`, `b` are linear `0.0..1.0` floats. PPM conversion applies gamma 2
    correction (`sqrt`) so the on-disk values are display-encoded.
  """

  defstruct [:r, :g, :b]

  @type t :: %__MODULE__{r: number, g: number, b: number}

  @max_int 255.999

  @spec new(number(), number(), number()) :: t()
  def new(r, g, b), do: %__MODULE__{r: r, g: g, b: b}

  @spec new(Exray.Vector.t()) :: t()
  def new(%Exray.Vector{x: r, y: g, z: b}), do: %__MODULE__{r: r, g: g, b: b}

  def black, do: %__MODULE__{r: 0.0, g: 0.0, b: 0.0}
  def white, do: %__MODULE__{r: 1.0, g: 1.0, b: 1.0}
  def red, do: %__MODULE__{r: 1.0, g: 0.0, b: 0.0}
  def green, do: %__MODULE__{r: 0.0, g: 1.0, b: 0.0}
  def blue, do: %__MODULE__{r: 0.0, g: 0.0, b: 1.0}

  @doc """
    Component-wise color addition.

    ## Examples

        iex> Exray.Color.add(Exray.Color.red(), Exray.Color.green())
        %Exray.Color{r: 1.0, g: 1.0, b: 0.0}
  """
  @spec add(t(), t()) :: t()
  def add(a, b), do: %__MODULE__{r: a.r + b.r, g: a.g + b.g, b: a.b + b.b}

  @doc """
    Multiplies a color by a scalar or another color (component-wise).

    ## Examples

        iex> Exray.Color.multiply(Exray.Color.red(), 0.5)
        %Exray.Color{r: 0.5, g: 0.0, b: 0.0}

        iex> Exray.Color.multiply(Exray.Color.white(), Exray.Color.red())
        %Exray.Color{r: 1.0, g: 0.0, b: 0.0}
  """
  @spec multiply(t(), number() | t()) :: t()
  def multiply(a, b) when is_number(b), do: %__MODULE__{r: a.r * b, g: a.g * b, b: a.b * b}

  def multiply(a, %__MODULE__{r: r, g: g, b: b}), do: %__MODULE__{r: a.r * r, g: a.g * g, b: a.b * b}

  @doc """
    Random color with components in `[0.0, 1.0)`.
  """
  @spec random() :: t()
  def random, do: random(0.0, 1.0)

  @doc """
    Random color with components in `[min, max)`.
  """
  @spec random(number(), number()) :: t()
  def random(min, max) do
    scale = max - min

    %__MODULE__{
      r: min + :rand.uniform() * scale,
      g: min + :rand.uniform() * scale,
      b: min + :rand.uniform() * scale
    }
  end

  @doc """
    Encode an accumulated color as a PPM color triple, applying per-sample
    averaging and gamma 2 correction.

    ## Examples

        iex> Exray.Color.to_ppm_string(Exray.Color.white(), 1)
        "255 255 255"
        iex> Exray.Color.to_ppm_string(Exray.Color.black(), 100)
        "0 0 0"
  """
  @spec to_ppm_string(t(), pos_integer()) :: String.t()
  def to_ppm_string(%__MODULE__{r: r, g: g, b: b}, samples_per_pixel) do
    scale = 1.0 / samples_per_pixel
    ri = encode(r * scale)
    gi = encode(g * scale)
    bi = encode(b * scale)
    "#{ri} #{gi} #{bi}"
  end

  @gamma_clamp_max 0.999
  @int_max 255
  defp encode(value) do
    value
    |> max(0.0)
    |> :math.sqrt()
    |> Exray.Utils.clamp(0.0, @gamma_clamp_max)
    |> Kernel.*(@max_int)
    |> Float.round()
    |> trunc()
    |> Exray.Utils.clamp(0, @int_max)
  end
end
