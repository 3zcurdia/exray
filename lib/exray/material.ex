defprotocol Exray.Material do
  @moduledoc """
    Polymorphic surface model.

    Implementations decide how a ray scatters off the surface at `record` and
    return `{:ok, scattered_ray, attenuation}` (where attenuation is an
    `Exray.Color.t()` per-channel multiplier) or `:absorbed` to terminate the
    ray path.
  """

  alias Exray.Color
  alias Exray.HitRecord
  alias Exray.Ray

  @spec scatter(t(), Ray.t(), HitRecord.t()) ::
          {:ok, Ray.t(), Color.t()} | :absorbed
  def scatter(material, ray_in, record)
end
