defmodule Exray.Materials.Lambertian do
  @moduledoc """
    Ideally diffuse (matte) material. Scatters rays uniformly into the
    hemisphere around the surface normal, with linear `albedo` attenuation.
  """

  defstruct [:albedo]

  @type t :: %__MODULE__{albedo: Exray.Color.t()}

  @spec new(Exray.Color.t()) :: t()
  def new(albedo \\ Exray.Color.black()), do: %__MODULE__{albedo: albedo}
end

defimpl Exray.Material, for: Exray.Materials.Lambertian do
  alias Exray.Materials.Lambertian
  alias Exray.Ray
  alias Exray.Vector

  @spec scatter(Lambertian.t(), Ray.t(), Exray.HitRecord.t()) ::
          {:ok, Ray.t(), Exray.Color.t()} | :absorbed
  def scatter(%Lambertian{albedo: albedo}, _ray_in, %Exray.HitRecord{point: point, normal: normal}) do
    scatter_direction = Vector.add(normal, Vector.random_unit_vector())

    scatter_direction =
      if Vector.near_zero?(scatter_direction), do: normal, else: scatter_direction

    {:ok, Ray.new(point, scatter_direction), albedo}
  end
end
