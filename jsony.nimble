version     = "1.1.6"
author      = "Andre von Houck"
description = "A loose direct to object json parser with hooks."
license     = "MIT"

srcDir = "src"

requires "nim >= 1.4.0"

# Differential correctness gate against the frozen reference implementation.
task difftest, "Run differential tests vs frozen reference":
  exec "nim c -r --hints:off --warnings:off tests/test_diff.nim"

# Differential fuzzing gate (args: seed iters timeout_s).
task fuzzdiff, "Run differential fuzzer (seed iters timeout_s)":
  exec "nim c -r --hints:off --warnings:off tests/fuzz_diff.nim"

# Local parse benchmark (not used for deterministic IR decisions).
task benchparse, "Run parse benchmark":
  exec "nim c -r -d:release --mm:orc --opt:speed bench/bench_parse.nim"
