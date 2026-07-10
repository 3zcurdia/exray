# Elapsed times
## Machine

CPU: Apple M4 Pro (8+4) @ 4.51 GHz
GPU: Apple M4 Pro (16) @ 1.58 GHz [Integrated]
Memory: 24.00 GiB

## Ruby version

```
ruby main.rb  6421.98s user 31.50s system 99% cpu 1:47:36.91 total
```
## Single core

```
mix run render.exs  2562.20s user 78.88s system 103% cpu 42:38.08 total
```

## MultiCore

### Parallel per line
```
mix run render.exs  1810.21s user 48.72s system 1054% cpu 2:56.24 total
```

### Parallel per line + BVH
```
mix run render.exs  91.81s user 3.04s system 1028% cpu 9.221 total
```

HittableList now wraps its objects in a Bounding Volume Hierarchy at
construction, so every ray walks the scene in roughly O(log N) instead of
O(N). For the ~500-sphere random scene in `render.exs`, this turns each
hit test from a full linear scan into a few AABB-vs-ray slab tests plus
the handful of sphere intersections the BVH actually opens, which is
why the parallel per-line render drops from ~3 minutes to ~9 seconds
(~19x).

### Parallel per tile (default 64x64)

```
mix run render.exs  90.83s user 2.58s system 892% cpu 10.466 total
```

Tile sizes are dimension-independent, so the scheduler keeps an
even load until the very last tiles at every image size, unlike
per-line tasks which leave cores idle once the last few long rows
finish. Compared with parallel per line + BVH, the wall clock is
unchanged (~9–10s) on this 500-sphere scene, but CPU usage drops
notably (1028% → 892%): the same work gets done with ~13% less
scheduler pressure. The gain is primarily better efficiency, not
raw speed — the real payoff shows on large or non-square renders
where per-line tail effects would otherwise leave cores idle.
