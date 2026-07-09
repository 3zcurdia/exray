defmodule Exray.Materials.Dielectric do
  @moduledoc """
    Transparent refractive material (e.g. glass) with index of refraction
    `index_of_refraction`. Attenuation is unity (no absorption); rays either
    refract or reflect based on Snell's law and Schlick's reflectance estimate.
  """

  defstruct [:index_of_refraction]

  @type t :: %__MODULE__{index_of_refraction: number()}

  @spec new(number()) :: t()
  def new(index_of_refraction \\ 1.5), do: %__MODULE__{index_of_refraction: index_of_refraction}
end

defimpl Exray.Material, for: Exray.Materials.Dielectric do
  alias Exray.Color
  alias Exray.HitRecord
  alias Exray.Material.Helpers
  alias Exray.Materials.Dielectric
  alias Exray.Ray
  alias Exray.Vector

  @spec scatter(Dielectric.t(), Ray.t(), HitRecord.t()) ::
          {:ok, Ray.t(), Color.t()} | :absorbed
  def scatter(%Dielectric{index_of_refraction: ior}, ray_in, %HitRecord{
        point: point,
        normal: normal,
        front_face: front_face
      }) do
    refraction_ratio = if(front_face, do: 1.0 / ior, else: ior)

    unit_direction = Ray.unit_vector(ray_in)
    cos_theta = min(-Vector.dot(unit_direction, normal), 1.0)
    sin_theta = :math.sqrt(1.0 - cos_theta * cos_theta)

    cannot_refract = refraction_ratio * sin_theta > 1.0
    random_reflect = Helpers.reflectance(cos_theta, refraction_ratio) > :rand.uniform()

    direction =
      if cannot_refract or random_reflect,
        do: Helpers.reflect(unit_direction, normal),
        else: Helpers.refract(unit_direction, normal, refraction_ratio)

    {:ok, Ray.new(point, direction), Color.white()}
  end
end
