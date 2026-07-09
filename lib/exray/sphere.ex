defmodule Exray.Sphere do
  @moduledoc """
    A sphere with a center, radius, and surface material.

    Implements `Exray.Hittable`. Defaults to a Lambertian material when one is
    not provided.
  """

  alias Exray.Materials.Lambertian
  alias Exray.Vector

  defstruct [:center, :material, radius: 0.0]

  @type t :: %__MODULE__{
          center: Vector.t(),
          radius: number(),
          material: term()
        }

  @spec new(Vector.t() | {number(), number(), number()}, number(), term()) :: t()
  def new(center, radius, material \\ Lambertian.new())

  def new(%Vector{} = center, radius, material), do: %__MODULE__{center: center, radius: radius, material: material}

  def new({x, y, z}, radius, material), do: %__MODULE__{center: Vector.new(x, y, z), radius: radius, material: material}
end

defimpl Exray.Hittable, for: Exray.Sphere do
  alias Exray.HitRecord
  alias Exray.Ray
  alias Exray.Vector

  @spec hit(Exray.Sphere.t(), Ray.t(), number(), number()) :: {:ok, HitRecord.t()} | :miss
  def hit(%Exray.Sphere{} = sphere, %Ray{} = ray, t_min, t_max) do
    solve_quadratic(sphere, ray, t_min, t_max)
  end

  defp solve_quadratic(%{center: center, radius: radius, material: material}, ray, t_min, t_max) do
    oc = Vector.subtract(ray.origin, center)
    a = Vector.mod_sqr(ray.direction)
    half_b = Vector.dot(oc, ray.direction)
    c = Vector.mod_sqr(oc) - radius * radius
    discriminant = half_b * half_b - a * c

    if discriminant < 0.0 do
      :miss
    else
      sqrt_d = :math.sqrt(discriminant)
      root = (-half_b - sqrt_d) / a

      if ray_in_bounds?(root, t_min, t_max) do
        build_record(root, ray, center, radius, material)
      else
        root = (-half_b + sqrt_d) / a

        if ray_in_bounds?(root, t_min, t_max),
          do: build_record(root, ray, center, radius, material),
          else: :miss
      end
    end
  end

  defp ray_in_bounds?(root, t_min, t_max), do: root >= t_min and root <= t_max

  defp build_record(root, ray, center, radius, material) do
    point = Ray.at(ray, root)
    outward_normal = Vector.divide(Vector.subtract(point, center), radius)

    record =
      [point: point, t: root, material: material]
      |> HitRecord.new()
      |> HitRecord.set_face_normal(ray, outward_normal)

    {:ok, record}
  end
end
