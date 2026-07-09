defprotocol Exray.Hittable do
  @moduledoc """
    Polymorphic ray-hit query.

    Implementations return `{:ok, %Exray.HitRecord{}}` for the nearest hit
    within `[t_min, t_max]`, or `:miss` when no intersection exists.
  """

  alias Exray.HitRecord
  alias Exray.Ray

  @spec hit(t(), Ray.t(), number(), number()) :: {:ok, HitRecord.t()} | :miss
  def hit(hittable, ray, t_min, t_max)
end
