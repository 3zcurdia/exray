defmodule Exray.HittableList do
  @moduledoc """
    An ordered collection of hittable objects. Implements `Exray.Hittable`,
    reporting the nearest hit among all members within `[t_min, t_max]`.

    Used by `Exray.Camera` / `Exray.render` as the scene (`World` in the
    original Ruby implementation).
  """

  defstruct objects: []

  @type t :: %__MODULE__{objects: [Exray.Hittable.t()]}

  @spec new([Exray.Hittable.t()]) :: t()
  def new(objects \\ []), do: %__MODULE__{objects: objects}

  @spec add(t(), Exray.Hittable.t()) :: t()
  def add(%__MODULE__{objects: objects} = list, object), do: %{list | objects: objects ++ [object]}

  @spec clear(t()) :: t()
  def clear(list), do: %{list | objects: []}
end

defimpl Exray.Hittable, for: Exray.HittableList do
  alias Exray.HitRecord
  alias Exray.Hittable

  @spec hit(Exray.HittableList.t(), Exray.Ray.t(), number(), number()) ::
          {:ok, HitRecord.t()} | :miss
  def hit(%Exray.HittableList{objects: objects}, ray, t_min, t_max) do
    closest =
      Enum.reduce_while(objects, nil, fn object, record ->
        closest = if record, do: record.t, else: t_max

        case Hittable.hit(object, ray, t_min, closest) do
          {:ok, new_record} -> {:cont, new_record}
          :miss -> {:cont, record}
        end
      end)

    if closest, do: {:ok, closest}, else: :miss
  end
end
