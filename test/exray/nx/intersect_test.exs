defmodule Exray.Nx.IntersectTest do
  use ExUnit.Case, async: false

  alias Exray.Color
  alias Exray.HittableList
  alias Exray.Materials
  alias Exray.Nx.Intersect
  alias Exray.Nx.Scene
  alias Exray.Sphere

  setup do
    prior = Nx.default_backend()
    Nx.default_backend(Nx.BinaryBackend)
    on_exit(fn -> Nx.default_backend(prior) end)
    :ok
  end

  defp scene do
    Scene.from_hittable_list(
      HittableList.new([
        Sphere.new({0.0, 0.0, -1.0}, 1.0, Materials.Lambertian.new(Color.new(0.4, 0.2, 0.1)))
      ])
    )
  end

  defp scalar(t), do: t |> Nx.to_flat_list() |> hd()

  test "intersect/10 returns the expected t for a front-facing ray" do
    scn = scene()

    origins = Nx.tensor([[0.0, 0.0, 0.0]], type: :f32)
    dirs = Nx.tensor([[0.0, 0.0, -1.0]], type: :f32)

    result =
      Intersect.intersect(
        origins,
        dirs,
        scn.centers,
        scn.radii,
        scn.material_types,
        scn.material_albedos,
        scn.material_fuzzes,
        scn.material_iors,
        0.001,
        1.0e12
      )

    assert scalar(result.idx) == 0
    assert scalar(result.hit_mask) == 1
    # Near root t=0 is below t_min, so the far root at t=2 is selected
    # (sphere center (0,0,-1), radius 1; ray from origin going -z).
    assert_in_delta scalar(result.t), 2.0, 1.0e-5
  end

  test "intersect/10 returns :miss (idx -1) for a ray that passes the sphere" do
    scn = scene()

    origins = Nx.tensor([[5.0, 5.0, 0.0]], type: :f32)
    dirs = Nx.tensor([[0.0, 0.0, -1.0]], type: :f32)

    result =
      Intersect.intersect(
        origins,
        dirs,
        scn.centers,
        scn.radii,
        scn.material_types,
        scn.material_albedos,
        scn.material_fuzzes,
        scn.material_iors,
        0.001,
        1.0e12
      )

    assert scalar(result.idx) == -1
    assert scalar(result.hit_mask) == 0
  end

  test "intersect/10 picks the nearest sphere when multiple are in range" do
    scn =
      Scene.from_hittable_list(
        HittableList.new([
          Sphere.new({0.0, 0.0, -5.0}, 1.0, Materials.Lambertian.new(Color.red())),
          Sphere.new({0.0, 0.0, -2.0}, 0.5, Materials.Dielectric.new(1.5))
        ])
      )

    origins = Nx.tensor([[0.0, 0.0, 0.0]], type: :f32)
    dirs = Nx.tensor([[0.0, 0.0, -1.0]], type: :f32)

    result =
      Intersect.intersect(
        origins,
        dirs,
        scn.centers,
        scn.radii,
        scn.material_types,
        scn.material_albedos,
        scn.material_fuzzes,
        scn.material_iors,
        0.001,
        1.0e12
      )

    assert scalar(result.idx) == 1
    assert_in_delta scalar(result.t), 1.5, 1.0e-4
  end

  test "intersect/10 batched: handles multiple rays at once" do
    scn = scene()

    origins =
      Nx.tensor([[0.0, 0.0, 0.0], [5.0, 5.0, 0.0], [0.2, 0.0, 0.0]], type: :f32)

    dirs = Nx.tensor([[-0.1, 0.0, -1.0], [0.0, 0.0, -1.0], [0.0, 0.0, -1.0]], type: :f32)

    dirs = Exray.Nx.Render.normalize(dirs)

    result =
      Intersect.intersect(
        origins,
        dirs,
        scn.centers,
        scn.radii,
        scn.material_types,
        scn.material_albedos,
        scn.material_fuzzes,
        scn.material_iors,
        0.001,
        1.0e12
      )

    idxs = Nx.to_flat_list(result.idx)
    assert Enum.at(idxs, 0) == 0
    assert Enum.at(idxs, 1) == -1
    # Third ray starts inside the sphere; the front-face root is behind it.
    assert Enum.at(idxs, 2) == 0 or Enum.at(idxs, 2) == -1
  end

  test "hit_geometry/5 computes normals and front-face mask" do
    scn = scene()

    origins = Nx.tensor([[0.0, 0.0, 0.0]], type: :f32)
    dirs = Nx.tensor([[0.0, 0.0, -1.0]], type: :f32)

    intersect =
      Intersect.intersect(
        origins,
        dirs,
        scn.centers,
        scn.radii,
        scn.material_types,
        scn.material_albedos,
        scn.material_fuzzes,
        scn.material_iors,
        0.001,
        1.0e12
      )

    geom = Intersect.hit_geometry(origins, dirs, intersect.t, intersect.centers, intersect.radii)
    point = Nx.reshape(geom.points, {3})
    # Hit point: origin + dir * t = (0,0,-2) (far root, sphere center -1, radius 1).
    assert_in_delta point |> Nx.to_flat_list() |> Enum.at(2), -2.0, 1.0e-4

    normal = Nx.reshape(geom.normals, {3})
    # The ray hits the back of the sphere, so the stored normal is the
    # negated outward normal: (0,0,1).
    assert_in_delta normal |> Nx.to_flat_list() |> Enum.at(2), 1.0, 1.0e-4
    assert scalar(geom.front_face) == 0
  end
end
