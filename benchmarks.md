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

