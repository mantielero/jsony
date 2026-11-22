#!/usr/bin/env bash
set -euo pipefail
# Usage: scripts/bench_ir.sh <label> <dataset> [iters]
# dataset: canada|citm_catalog|twitter|strings_big|ints_big|floats_big
# Builds a small driver and runs callgrind (Ir). Outputs Ir total.
# Env: NIMFLAGS extra flags (e.g. --path:. for current src), OUTDIR
label="${1:?label}"; dataset="${2:?dataset}"; iters="${3:-3}"
root="$(cd "$(dirname "$0")/.." && pwd)"
outdir="${OUTDIR:-/tmp/jsony_ir}"
mkdir -p "$outdir"
driver="$outdir/driver_${dataset}.nim"
bin="$outdir/prof_${label}_${dataset}"
cg="$outdir/cg_${label}_${dataset}.out"
nimflags=${NIMFLAGS:-"--path:$root"}
case "$dataset" in
  canada) type=Canada; file=bench/data/canada.json ;;
  citm_catalog) type=CitmCatalog; file=bench/data/citm_catalog.json ;;
  twitter) type=Twitter; file=bench/data/twitter.json ;;
  floats_big) type="seq[float64]"; file=bench/data/floats_big.json ;;
  strings_big) type="seq[string]"; file=bench/data/strings_big.json ;;
  ints_big) type="seq[int64]"; file=bench/data/ints_big.json ;;
  *) echo "unknown dataset $dataset" >&2; exit 2 ;;
esac
cat > "$driver" <<NIM
import src/jsony
import bench/types
import std/os
let data = readFile("$root/$file")
var sink: $type
for i in 0..<1: sink = fromJson(data, $type)
for i in 0..<$iters: sink = fromJson(data, $type)
discard sink
NIM
nim c -d:release --mm:orc --opt:speed --debuginfo:on --lineDir:on $nimflags -o:"$bin" "$driver" >/tmp/ir_build_${label}_${dataset}.log 2>&1
valgrind --tool=callgrind --callgrind-out-file="$cg" "$bin" >/tmp/ir_run_${label}_${dataset}.log 2>&1
ir=$(grep -oP 'Collected : \K[0-9,]+' /tmp/ir_run_${label}_${dataset}.log | tr -d ',')
if [ -z "$ir" ]; then ir=$(callgrind_annotate "$cg" 2>/dev/null | awk '/PROGRAM TOTALS/{gsub(/,/,"",$1); print $1; exit}'); fi
echo "$label $dataset Ir=$ir"
