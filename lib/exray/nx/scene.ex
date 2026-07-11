defmodule Exray.Nx.Scene do
  @moduledoc """
    Flattens an `Exray.HittableList` into per-sphere tensors for the
    batched Nx render path.

    Only `%Exray.Sphere{}` objects are supported – they are the only
    hittables produced by `render.exs`'s `random_scene/0`. The BVH built
    by `HittableList` is intentionally ignored: the Nx path does a
    linear batched scan of every active ray against every sphere in a
    single tensor op, which is asymptotically worse than the BVH but
    far cheaper once vectorized through EXLA for scenes of a few
    hundred spheres.

    Each per-sphere material is also unpacked into aligned tensors so
    the scatter step can dispatch on `material_types` via `Nx.select`
    without any Elixir-level branching per ray:

      * `material_types`  – `0` Lambertian, `1` Metal, `2` Dielectric
      * `material_albedos` – RGB albedo (white for Dielectric, unused)
      * `material_fuzzes`  – fuzz factor (0.0 for non-metals, unused)
      * `material_iors`    – index of refraction (1.0 for non-dielectrics,
        unused)
  """

  alias Exray.HittableList
  alias Exray.Materials
  alias Exray.Sphere

  defstruct [
    :centers,
    :radii,
    :material_types,
    :material_albedos,
    :material_fuzzes,
    :material_iors,
    count: 0
  ]

  @type t :: %__MODULE__{
          centers: Nx.Tensor.t(),
          radii: Nx.Tensor.t(),
          material_types: Nx.Tensor.t(),
          material_albedos: Nx.Tensor.t(),
          material_fuzzes: Nx.Tensor.t(),
          material_iors: Nx.Tensor.t(),
          count: non_neg_integer()
        }

  @lambertian 0
  @metal 1
  @dielectric 2

  @spec from_hittable_list(HittableList.t()) :: t()
  def from_hittable_list(%HittableList{objects: objects}) do
    spheres = Enum.filter(objects, &sphere?/1)

    if spheres == [] do
      empty()
    else
      rows =
        Enum.map(spheres, fn %Sphere{center: c, radius: r, material: mat} ->
          {type, albedo, fuzz, ior} = unpack_material(mat)
          {[c.x, c.y, c.z, r], type, albedo, fuzz, ior}
        end)

      {centers_radii, types, albedos, fuzzes, iors} = unzip6(rows)

      %__MODULE__{
        centers:
          centers_radii |> Nx.tensor(type: {:f, 32}) |> Nx.reshape({:auto, 4}) |> Nx.slice_along_axis(0, 3, axis: 1),
        radii:
          centers_radii
          |> Nx.tensor(type: {:f, 32})
          |> Nx.reshape({:auto, 4})
          |> Nx.slice_along_axis(3, 1, axis: 1)
          |> Nx.squeeze(axes: [1]),
        material_types: Nx.tensor(types, type: {:s, 32}),
        material_albedos: Nx.tensor(albedos, type: {:f, 32}),
        material_fuzzes: Nx.tensor(fuzzes, type: {:f, 32}),
        material_iors: Nx.tensor(iors, type: {:f, 32}),
        count: length(spheres)
      }
    end
  end

  defp sphere?(%Sphere{}), do: true
  defp sphere?(_), do: false

  defp unzip6(rows) do
    rows
    |> Enum.reduce({[], [], [], [], []}, fn {cr, t, a, f, i}, {crs, ts, as, fs, is} ->
      {[cr | crs], [t | ts], [a | as], [f | fs], [i | is]}
    end)
    |> then(fn {crs, ts, as, fs, is} ->
      {Enum.reverse(crs), Enum.reverse(ts), Enum.reverse(as), Enum.reverse(fs), Enum.reverse(is)}
    end)
  end

  defp unpack_material(%Materials.Lambertian{albedo: %{r: r, g: g, b: b}}), do: {@lambertian, [r, g, b], 0.0, 1.0}

  defp unpack_material(%Materials.Metal{albedo: %{r: r, g: g, b: b}, fuzz: fuzz}), do: {@metal, [r, g, b], fuzz, 1.0}

  defp unpack_material(%Materials.Dielectric{index_of_refraction: ior}), do: {@dielectric, [1.0, 1.0, 1.0], 0.0, ior}

  defp empty,
    do: %__MODULE__{
      centers: Nx.tensor([[1.0e30, 1.0e30, 1.0e30]], type: {:f, 32}),
      radii: Nx.tensor([1.0e-30], type: {:f, 32}),
      material_types: Nx.tensor([0], type: {:s, 32}),
      material_albedos: Nx.tensor([[0.0, 0.0, 0.0]], type: {:f, 32}),
      material_fuzzes: Nx.tensor([0.0], type: {:f, 32}),
      material_iors: Nx.tensor([1.0], type: {:f, 32}),
      count: 0
    }

  # Nx rejects zero-size dimensions (`{0, 3}` etc.), so an empty world
  # is represented by a single dummy sphere placed astronomically far
  # away with a vanishing radius. No reasonable ray can reach it; the
  # `count` field stays 0 so render code can still check for emptiness.
end
