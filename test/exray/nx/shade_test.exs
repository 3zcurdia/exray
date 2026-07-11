defmodule Exray.Nx.ShadeTest do
  use ExUnit.Case, async: false

  alias Exray.Nx.Shade

  setup do
    prior = Nx.default_backend()
    Nx.default_backend(Nx.BinaryBackend)
    on_exit(fn -> Nx.default_backend(prior) end)
    :ok
  end

  test "background/1 returns the sky gradient (cyan at top, white at bottom)" do
    dirs = Nx.tensor([[0.0, 1.0, 0.0], [0.0, -1.0, 0.0]], type: :f32)
    bg = dirs |> Shade.background() |> Nx.reshape({2, 3}) |> Nx.to_flat_list()

    # Ray shooting up (y=1) -> mostly cyan
    assert_in_delta Enum.at(bg, 0), 0.5, 1.0e-5
    assert_in_delta Enum.at(bg, 1), 0.7, 1.0e-5
    assert_in_delta Enum.at(bg, 2), 1.0, 1.0e-5

    # Ray shooting down (y=-1) -> mostly white
    assert_in_delta Enum.at(bg, 3), 1.0, 1.0e-5
    assert_in_delta Enum.at(bg, 4), 1.0, 1.0e-5
    assert_in_delta Enum.at(bg, 5), 1.0, 1.0e-5
  end

  test "gamma_encode/1 clips negatives and saturates near 1.0" do
    colors =
      Nx.tensor(
        [
          [-1.0, 0.5, 1.5]
        ],
        type: :f32
      )

    encoded = colors |> Shade.gamma_encode() |> Nx.reshape({3}) |> Nx.to_flat_list()

    assert Enum.at(encoded, 0) == 0
    assert_in_delta Enum.at(encoded, 1), :math.sqrt(0.5) * 255.999, 1.0
    # 1.5 -> sqrt clipped to 0.999 -> 0.999 * 255.999 -> round -> 255.
    assert Enum.at(encoded, 2) == 255
  end

  test "scatter/10 produces unit-ish directions for Lambertian hits" do
    n = 4
    normals = Nx.broadcast(Nx.tensor([0.0, 1.0, 0.0], type: :f32), {n, 3})
    unit_dirs = Nx.broadcast(Nx.tensor([0.0, -1.0, 0.0], type: :f32), {n, 3})
    material_types = Nx.broadcast(Nx.tensor(0, type: :s32), {n})
    albedos = Nx.broadcast(Nx.tensor([0.5, 0.5, 0.5], type: :f32), {n, 3})
    fuzzes = Nx.broadcast(Nx.tensor(0.0, type: :f32), {n})
    iors = Nx.broadcast(Nx.tensor(1.0, type: :f32), {n})
    front_face = Nx.broadcast(Nx.tensor(1, type: :u8), {n})
    rand_unit = Nx.broadcast(Nx.tensor([1.0, 0.0, 0.0], type: :f32), {n, 3})
    rand_in_sphere = Nx.broadcast(Nx.tensor([0.0, 0.0, 0.0], type: :f32), {n, 3})
    rand_u = Nx.broadcast(Nx.tensor(0.5, type: :f32), {n})

    result =
      Shade.scatter(
        unit_dirs,
        normals,
        material_types,
        albedos,
        fuzzes,
        iors,
        front_face,
        rand_unit,
        rand_in_sphere,
        rand_u
      )

    dirs = result.direction |> Nx.reshape({n, 3}) |> Nx.to_flat_list()

    # Scatter dir = normal + [1,0,0] = [1,1,0]
    assert_in_delta Enum.at(dirs, 0), 1.0, 1.0e-4
    assert_in_delta Enum.at(dirs, 1), 1.0, 1.0e-4
    assert_in_delta Enum.at(dirs, 2), 0.0, 1.0e-4

    # No metal hits -> no absorption
    assert Enum.all?(Nx.to_flat_list(result.absorbed), &(&1 == 0))
  end
end
