# Agent Notes for Exray

A tiny Elixir ray-tracing library that renders PPM images. There is no CI, no task runner, and almost no runtime dependencies.

## Project structure

- Single Mix app (`app: :exray`, Elixir `~> 1.18`).
- Main API: `lib/exray.ex`.
- Domain modules under `lib/exray/`: `Color`, `PPM`, `Ray`, `Sphere`, `Utils`, `Vector`.
- `render.exs` is the executable entrypoint: it calls `Exray.render/2` and writes `hello.ppm`.

## Setup

```bash
mix deps.get
```

Only dependency: `dialyxir` (dev/test only).

## Verification

```bash
mix test                    # all tests (mostly doctests)
mix test path/to_test.exs   # single test file
mix format --check-formatted
mix dialyzer
```

Tests are cheap and safe to run in parallel. No external services required.

## Rendering

```bash
mix run render.exs
```

This writes `hello.ppm` (256×256 by default). `*.ppm` files are gitignored. The default dimensions are hard-coded in `lib/exray.ex` via `width`/`height` parameters to `render/2`, but the actual image dimensions inside `render_pixels/1` are fixed at 400×225 for the viewport math.

## Style / conventions

- Standard Elixir formatting via `.formatter.exs`.
- Doctests are the primary test coverage for math modules.
- Dialyzer is enabled; keep `@spec` annotations on public functions.

## Known gotchas

- `lib/exray.ex` aliases `Supervisor.Spec` but does not use it (produces a compile warning).
- `README.md` is still the default Hex package template and does not describe the project.
