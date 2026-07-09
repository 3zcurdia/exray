defmodule Exray.Vector do
  @moduledoc """
  A vector in 3D space.
  """

  defstruct [:x, :y, :z]

  @type t :: %__MODULE__{x: number, y: number, z: number}

  @doc """
    Zero vector

    ## Example

        iex> Exray.Vector.zero()
        %Exray.Vector{x: 0.0, y: 0.0, z: 0.0}
  """
  @spec zero() :: t()
  def zero, do: %Exray.Vector{x: 0.0, y: 0.0, z: 0.0}

  @doc """
    Helper function to initialize the vector struct

    ## Example

        iex> Exray.Vector.new(1, 2, 3)
        %Exray.Vector{x: 1, y: 2, z: 3}
  """
  @spec new(number(), number(), number()) :: t()
  def new(x, y, z), do: %Exray.Vector{x: x, y: y, z: z}

  @doc """
    It adds two vectors

    ## Examples

        iex> Exray.Vector.add(%Exray.Vector{x: 1, y: 2, z: 3}, %Exray.Vector{x: 6, y: 5, z: 4})
        %Exray.Vector{x: 7, y: 7, z: 7}
  """
  @spec add(t(), t()) :: t()
  def add(a, b) do
    %Exray.Vector{x: a.x + b.x, y: a.y + b.y, z: a.z + b.z}
  end

  @doc """
    It subtracts two vectors

    ## Examples

        iex> Exray.Vector.subtract(%Exray.Vector{x: 6, y: 5, z: 4}, %Exray.Vector{x: 1, y: 2, z: 3})
        %Exray.Vector{x: 5, y: 3, z: 1}
  """
  @spec subtract(t(), t()) :: t()
  def subtract(a, b) do
    %Exray.Vector{x: a.x - b.x, y: a.y - b.y, z: a.z - b.z}
  end

  @doc """
    It multiplies a vector by a scalar

    ## Examples

        iex> Exray.Vector.multiply(%Exray.Vector{x: 1, y: 2, z: 3}, 2)
        %Exray.Vector{x: 2, y: 4, z: 6}
  """
  @spec multiply(t(), number()) :: t()
  def multiply(a, b) when is_number(b) do
    %Exray.Vector{x: a.x * b, y: a.y * b, z: a.z * b}
  end

  @doc """
    It divides a vector by a scalar

    ## Examples

        iex> Exray.Vector.divide(%Exray.Vector{x: 2, y: 4, z: 6}, 2)
        %Exray.Vector{x: 1.0, y: 2.0, z: 3.0}
  """
  @spec divide(t(), number()) :: t()
  def divide(a, b) when is_number(b) do
    %Exray.Vector{x: a.x / b, y: a.y / b, z: a.z / b}
  end

  @doc """
    It multiplies a vector by another vector using cross product

    ## Examples

        iex> axis_x = %Exray.Vector{x: 1, y: 0, z: 0}
        iex> axis_y = %Exray.Vector{x: 0, y: 1, z: 0}
        iex> axis_z = %Exray.Vector{x: 0, y: 0, z: 1}
        iex> Exray.Vector.cross(axis_x, axis_y)
        %Exray.Vector{x: 0, y: 0, z: 1}
        iex> Exray.Vector.cross(axis_z, axis_x)
        %Exray.Vector{x: 0, y: 1, z: 0}
        iex> Exray.Vector.cross(axis_y, axis_z)
        %Exray.Vector{x: 1, y: 0, z: 0}
  """
  @spec cross(t(), t()) :: t()
  def cross(a, b) do
    %Exray.Vector{x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x}
  end

  @doc """
    It returns the dot product of two vectors

    ## Examples

        iex> Exray.Vector.dot(%Exray.Vector{x: 1, y: 2, z: 3}, %Exray.Vector{x: 6, y: 5, z: 4})
        28
  """
  @spec dot(t(), t()) :: number()
  def dot(a, b) do
    a.x * b.x + a.y * b.y + a.z * b.z
  end

  @doc """
    It returns the normalized vector

    ## Examples

        iex> Exray.Vector.normalize(%Exray.Vector{x: 1, y: 2, z: 3})
        %Exray.Vector{x: 0.2672612419124244, y: 0.5345224838248488, z: 0.8017837257372732}
  """
  @spec normalize(t()) :: t()
  def normalize(%Exray.Vector{x: 0, y: 0, z: 0}), do: raise(ArithmeticError, message: "Cannot normalize a zero vector")

  def normalize(a) do
    %Exray.Vector{x: a.x / mod(a), y: a.y / mod(a), z: a.z / mod(a)}
  end

  @doc """
  Alias for normalize()
  """
  def unit(vector), do: normalize(vector)

  @doc """
    It returns the module(length) of a vector

    ## Examples

        iex> Exray.Vector.mod(%Exray.Vector{x: 1, y: 2, z: 3})
        3.7416573867739413
  """
  @spec mod(t()) :: number()
  def mod(a) do
    a |> mod_sqr() |> :math.sqrt()
  end

  @doc """
    It returns the module squared of a vector

    ## Examples

        iex> Exray.Vector.mod_sqr(%Exray.Vector{x: 1, y: 2, z: 3})
        14
  """
  @spec mod_sqr(t()) :: number()
  def mod_sqr(a) do
    a.x * a.x + a.y * a.y + a.z * a.z
  end

  @epsilon 1.0e-8
  @doc """
    It returns true if the vector is near zero

    ## Examples

        iex> Exray.Vector.near_zero?(%Exray.Vector{x: 1, y: 2, z: 3})
        false
        iex> Exray.Vector.near_zero?(%Exray.Vector{x: 0, y: 0, z: 0})
        true
        iex> Exray.Vector.near_zero?(%Exray.Vector{x: 0.000000009, y: 0.000000009, z: 0.000000009})
        true
  """
  @spec near_zero?(t()) :: boolean()
  def near_zero?(a) do
    abs(a.x) < @epsilon and abs(a.y) < @epsilon and abs(a.z) < @epsilon
  end
end
