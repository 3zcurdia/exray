defmodule Exray.Nx.SceneTest do
  use ExUnit.Case, async: false

  alias Exray.Color
  alias Exray.HittableList
  alias Exray.Materials
  alias Exray.Nx.Scene
  alias Exray.Sphere

  setup do
    prior = Nx.default_backend()
    Nx.default_backend(Nx.BinaryBackend)
    on_exit(fn -> Nx.default_backend(prior) end)
    :ok
  end

  test "from_hittable_list/1 unpacks spheres and their materials" do
    list =
      HittableList.new([
        Sphere.new({0.0, 0.0, -1.0}, 1.0, Materials.Lambertian.new(Color.new(0.4, 0.2, 0.1))),
        Sphere.new({1.0, 2.0, 3.0}, 0.5, Materials.Dielectric.new(1.5))
      ])

    scene = Scene.from_hittable_list(list)
    assert scene.count == 2

    assert Nx.shape(scene.centers) == {2, 3}
    assert Nx.shape(scene.radii) == {2}
    assert Nx.shape(scene.material_types) == {2}
    assert Nx.shape(scene.material_albedos) == {2, 3}
    assert Nx.shape(scene.material_fuzzes) == {2}
    assert Nx.shape(scene.material_iors) == {2}

    assert Nx.to_flat_list(scene.material_types) == [0, 2]

    assert Nx.to_flat_list(scene.centers) == [0.0, 0.0, -1.0, 1.0, 2.0, 3.0]
    assert Nx.to_flat_list(scene.radii) == [1.0, 0.5]

    assert Nx.to_flat_list(scene.material_albedos) ==
             [0.4000000059604645, 0.20000000298023224, 0.10000000149011612, 1.0, 1.0, 1.0]

    assert Nx.to_flat_list(scene.material_iors) == [1.0, 1.5]
  end

  test "from_hittable_list/1 returns an empty scene for a world with no spheres" do
    scene = Scene.from_hittable_list(HittableList.new([]))
    assert scene.count == 0
    # Empty is encoded via a single dummy sphere far away; shape still
    # non-zero because Nx rejects zero-size dimensions.
    assert Nx.shape(scene.centers) == {1, 3}
  end
end
