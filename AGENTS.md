# Agent Notes for Exray

A tiny Elixir ray-tracing library that renders PPM images. There is no CI, no task runner, and almost no runtime dependencies other than the optional Nx path.

## Project structure

- Single Mix app (`app: :exray`, Elixir `~> 1.18`).
- Main API: `lib/exray.ex`. Public entrypoint `render/4` dispatches to either the scalar path (default) or the accelerated `Exray.Nx.Render.render/4` when `nx: true` is passed.
- Scalar (default) domain modules under `lib/exray/`: `Color`, `PPM`, `Ray`, `Sphere`, `Utils`, `Vector`, plus `Camera`, `AABB`, `BVHNode`, `HitRecord`, `Hittable` (protocol), `HittableList`, `Material` (protocol), `Material/Helpers`, `Materials/{Lambertian,Metal,Dielectric}`.
- Nx accelerated path under `lib/exray/nx/`:
  - `Scene` – flattens a `HittableList` into per-sphere tensors (centers, radii, material types, albedos, fuzzes, iors).
  - `Intersect` – `defn` kernels for batched ray-sphere scan + per-hit geometry gather.
  - `Shade` – `defn` kernels for the background gradient, per-material scatter, and gamma-2 + 8-bit encode.
  - `Render` – tiles + sample-batches + bounce recursion that drives the kernels; mirrors the scalar path's PPM I/O so output is byte-compatible.
- `render.exs` is the executable entrypoint: it calls `Exray.render/4` and writes `hello.ppm`. Pass `--nx` to use the accelerated path.

## Setup

```bash
mix deps.get
```

Dev/test deps: `dialyxir`, `credo`, `styler`.
Optional accelerated-path deps: `nx`, `exla`. EXLA downloads a prebuilt XLA archive and compiles a small native C++ extension on first `mix compile`. The default scalar path remains runnable even if EXLA fails to build, but the modules under `lib/exray/nx/` use `defn`, so they will not compile without `:nx` and `:exla` available.

## Verification

```bash
mix test                    # all tests (doctests + scalar + Nx suites)
mix test test/exray/nx/      # Nx-only tests (uses EXLA via defn)
mix test path/to_test.exs   # single test file
mix format --check-formatted
mix dialyzer
```

Tests are cheap and safe to run in parallel. No external services required. Nx tests set `Nx.default_backend(Nx.BinaryBackend)` so they can run without an EXLA-compiled binary, except for `Exray.Nx.RenderTest` which exercises the full render pipeline through EXLA and runs serial.

## Rendering

```bash
mix run render.exs               # scalar renderer (default)
mix run render.exs --nx          # Nx + EXLA accelerated renderer
mix run render.exs --nx --width 800 --samples-per-pixel 64 --max-depth 32
```

This writes `hello.ppm`. `*.ppm` files are gitignored. Default dimensions: `image_width: 400`, height derived from the camera's aspect ratio.

## Style / conventions

- Standard Elixir formatting via `.formatter.exs` (uses `Styler` plugin).
- Doctests are the primary test coverage for the math modules; the Nx path uses `assert_in_delta` against known values.
- `defn` kernels live in dedicated modules (`Exray.Nx.Intersect`, `Exray.Nx.Shade`) and only call other `defn`s or `Nx` functions. Per-bounce random tensors are generated **outside** the `defn`s via `Nx.Random` so the kernels remain pure functions of their tensor inputs (otherwise captured tensors force recompilation per call).
- Dialyzer is enabled; keep `@spec` annotations on public functions.

## Known gotchas

- The Nx path generates random numbers via `Nx.Random` (threefry PRNG keyed per sample batch), so images produced with `--nx` will differ in noise detail from the scalar renderer's `:rand.uniform` output despite being numerically close (see the parity test in `test/exray/nx/render_test.exs`).
- Per-tile EXLA recompiles once per `Task.async_stream` task because the EXLA backend is set process-locally. This is a perf hit only on the first sample batch of each tile; cached thereafter.
- `:nx` and `:exla` are non-optional dependencies at compile time because the `defn` modules must compile. They are only *invoked* at runtime when `nx: true` is passed.
- Memory peak for the Nx path is bounded by `tile_pixels * sample_batch * sphere_count * 4` bytes per tile. The 16-sample default on a 64×64 tile with ~500 spheres is ~800 MB. Tune `:sample_batch` down if running out of memory.
- Nx rejects zero-size tensor dimensions (`{0, 3}`); an empty `HittableList` is represented by a single dummy sphere far enough away that no reasonable ray reaches it (`Exray.Nx.Scene.empty/0`). The `count` field is reported as 0 for emptiness checks.
