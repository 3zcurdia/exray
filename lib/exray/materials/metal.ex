defmodule Exray.Materials.Metal do
  @moduledoc """
    Specular metal material. Reflects rays around the surface normal, with
    optional `fuzz` (in `[0.0, 1.0]`) that perturbs the reflected direction by
    a random vector inside the unit sphere.
  """

  defstruct [:albedo, fuzz: 0.0]

  @type t :: %__MODULE__{albedo: Exray.Color.t(), fuzz: number()}

  @spec new(Exray.Color.t(), number()) :: t()
  def new(albedo, fuzz \\ 0.0),
    do: %__MODULE__{albedo: albedo, fuzz: Exray.Utils.clamp(fuzz, 0.0, 1.0)}
end

defimpl Exray.Material, for: Exray.Materials.Metal do
  alias Exray.{Ray, Vector, HitRecord, Material.Helpers}

  @spec scatter(Exray.Materials.Metal.t(), Ray.t(), HitRecord.t()) ::
          {:ok, Ray.t(), Exray.Color.t()} | :absorbed
  def scatter(%Exray.Materials.Metal{albedo: albedo, fuzz: fuzz}, ray_in, %HitRecord{
        point: point,
        normal: normal
      }) do
    reflected = Helpers.reflect(Ray.unit_vector(ray_in), normal)

    scattered =
      Ray.new(point, Vector.add(reflected, Vector.multiply(Vector.random_in_unit_sphere(), fuzz)))

    if Vector.dot(scattered.direction, normal) > 0.0,
      do: {:ok, scattered, albedo},
      else: :absorbed
  end
end
