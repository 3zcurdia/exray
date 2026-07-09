defmodule Exray.Material.Helpers do
  @moduledoc """
    Shared optics helpers used by the material protocol implementations.
  """

  alias Exray.Vector

  @doc "Mirror-reflection of `v` about unit normal `n`."
  @spec reflect(Vector.t(), Vector.t()) :: Vector.t()
  def reflect(v, n) do
    Vector.subtract(v, Vector.multiply(n, 2.0 * Vector.dot(v, n)))
  end

  @doc "Snell-law refraction of `v` crossing `n` with index ratio `etai_over_etat`."
  @spec refract(Vector.t(), Vector.t(), number()) :: Vector.t()
  def refract(uv, n, etai_over_etat) do
    cos_theta = min(-Vector.dot(uv, n), 1.0)
    r_out_perp = Vector.multiply(Vector.add(Vector.multiply(n, cos_theta), uv), etai_over_etat)
    r_out_parallel = Vector.multiply(n, -:math.sqrt(abs(1.0 - Vector.mod_sqr(r_out_perp))))
    Vector.add(r_out_perp, r_out_parallel)
  end

  @doc "Schlick's approximation for the reflectance of a dielectric interface."
  @spec reflectance(number(), number()) :: number()
  def reflectance(cosine, refractive_index) do
    r0 = :math.pow((1.0 - refractive_index) / (1.0 + refractive_index), 2)
    r0 + (1.0 - r0) * :math.pow(1.0 - cosine, 5)
  end
end
