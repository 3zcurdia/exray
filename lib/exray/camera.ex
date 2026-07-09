defmodule Exray.Camera do
  @moduledoc """
    Pinhole camera with optional defocus blur (depth of field).

    Builds a right-handed coordinate basis from `look_from` -> `look_at`
    with `v_up` as world up, and precomputes the viewport frame for ray
    generation. `aperture > 0` enables sampling within a lens disk of
    radius `aperture / 2` at the focus plane (`focus_dist`).
  """

  alias Exray.{Vector, Ray, Utils}

  defstruct [
    :origin,
    :lower_left,
    :horizontal,
    :vertical,
    :u,
    :v,
    :w,
    aspect_ratio: 16.0 / 9.0,
    lens_radius: 0.0
  ]

  @type t :: %__MODULE__{
          origin: Exray.Vector.t(),
          lower_left: Exray.Vector.t(),
          horizontal: Exray.Vector.t(),
          vertical: Exray.Vector.t(),
          u: Exray.Vector.t(),
          v: Exray.Vector.t(),
          w: Exray.Vector.t(),
          aspect_ratio: number(),
          lens_radius: number()
        }

  @default_options [
    v_up: {0, 1, 0},
    vertical_fov: 90.0,
    aspect_ratio: 16.0 / 9.0,
    aperture: 0.0,
    focus_dist: 1.0
  ]

  @spec new(Exray.Vector.t(), Exray.Vector.t(), keyword()) :: t()
  def new(look_from, look_at, opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    v_up = into_vector(Keyword.fetch!(opts, :v_up))
    vertical_fov = Keyword.fetch!(opts, :vertical_fov)
    aspect_ratio = Keyword.fetch!(opts, :aspect_ratio)
    aperture = Keyword.fetch!(opts, :aperture)
    focus_dist = Keyword.fetch!(opts, :focus_dist)

    theta = Utils.degree_to_radian(vertical_fov)
    height = 2.0 * :math.tan(theta / 2.0)
    width = aspect_ratio * height

    w = Vector.unit(Vector.subtract(look_from, look_at))
    u = Vector.unit(Vector.cross(v_up, w))
    v = Vector.cross(w, u)

    horizontal = Vector.multiply(u, width * focus_dist)
    vertical = Vector.multiply(v, height * focus_dist)

    lower_left =
      look_from
      |> Vector.subtract(Vector.divide(horizontal, 2.0))
      |> Vector.subtract(Vector.divide(vertical, 2.0))
      |> Vector.subtract(Vector.multiply(w, focus_dist))

    %__MODULE__{
      origin: look_from,
      lower_left: lower_left,
      horizontal: horizontal,
      vertical: vertical,
      u: u,
      v: v,
      w: w,
      aspect_ratio: aspect_ratio,
      lens_radius: aperture / 2.0
    }
  end

  @doc """
    `(image_width, image_height)` derived from `n / aspect_ratio`.
  """
  @spec image_dimensions(t(), pos_integer()) :: {pos_integer(), pos_integer()}
  def image_dimensions(%__MODULE__{aspect_ratio: aspect_ratio}, image_width) do
    height = max(1, round(image_width / aspect_ratio))
    {image_width, height}
  end

  @doc """
    Generate a primary ray for raster coordinate `(s, t)` in `[0, 1]`.
    When defocus blur is on, the ray origin is shifted within the lens disk.
  """
  @spec get_ray(t(), number(), number()) :: Exray.Ray.t()
  def get_ray(%__MODULE__{} = cam, s, t) do
    offset = lens_offset(cam)

    direction =
      cam.lower_left
      |> Vector.add(Vector.multiply(cam.horizontal, s))
      |> Vector.add(Vector.multiply(cam.vertical, t))
      |> Vector.subtract(cam.origin)
      |> Vector.subtract(offset)

    Ray.new(Vector.add(cam.origin, offset), direction)
  end

  defp lens_offset(%__MODULE__{lens_radius: r}) when r == 0.0, do: Vector.zero()

  defp lens_offset(%__MODULE__{lens_radius: r, u: u, v: v}) do
    rd = Vector.multiply(Vector.random_in_unit_disk(), r)
    Vector.add(Vector.multiply(u, rd.x), Vector.multiply(v, rd.y))
  end

  defp into_vector(%Vector{} = v), do: v
  defp into_vector({x, y, z}), do: Vector.new(x, y, z)
end
