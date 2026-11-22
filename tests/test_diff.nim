# Differential correctness test harness.
# Compiles frozen-reference and current runners once, then compares per-case
# output including values, JsonError messages/offsets, defects, and crashes.
import std/[os, osproc, strutils, strformat]
import ./diff_cases

proc compileRunner(src, outp: string) =
  let cmd = "nim c --hints:off --warnings:off --stackTrace:off --lineTrace:off -o:" & quoteShell(outp) & " " & quoteShell(src)
  let res = execCmdEx(cmd)
  if res.exitCode != 0:
    echo res.output
    quit("failed to compile " & src)

let tmp = getTempDir() / "jsony_diff"
createDir(tmp)
let origBin = tmp / "diff_runner_orig"
let newBin = tmp / "diff_runner_new"
compileRunner("tests/diff_runner_orig.nim", origBin)
compileRunner("tests/diff_runner_new.nim", newBin)

proc runCase(bin, label, input: string): (int, string) =
  let res = execCmdEx(bin & " " & quoteShell(label) & " " & quoteShell(input))
  (res.exitCode, res.output)

var total = 0
template check(label: string, input: string) =
  inc total
  let (c1, o1) = runCase(origBin, label, input)
  let (c2, o2) = runCase(newBin, label, input)
  if c1 != c2 or o1.strip() != o2.strip():
    echo "DIFF ", label, " input=", input.escape
    echo "  ORIG code=", c1, " out=", o1.strip().replace("\n","\\n")
    echo "  NEW  code=", c2, " out=", o2.strip().replace("\n","\\n")
    quit(1)

for s in intInputs: check("int", s)
for s in int64Inputs: check("int64", s)
for s in uint64Inputs: check("uint64", s)
for s in floatInputs: check("float64", s)
for s in strInputs: check("string", s)
for s in boolInputs: check("bool", s)
for s in seqIntInputs: check("seq[int]", s)
for s in objSmallInputs: check("ObjSmall", s)
for s in objOptInputs: check("ObjOpt", s)
for s in objNestedInputs: check("ObjNested", s)
for s in objSeqInputs: check("ObjSeq", s)
for s in objSnakeInputs: check("ObjSnake", s)
for s in arrInputs: check("Arr3", s)
for s in tupInputs: check("Tup3", s)
for s in charInputs: check("char", s)
for s in tableInputs: check("TblStrInt", s)
for s in setInputs: check("SetInt", s)
for s in enumInputs: check("ColorE", s)
for s in enumHookInputs: check("ColorHook", s)
for s in hookObjInputs: check("HookObj", s)
for s in newHookInputs: check("NewHookObj", s)
for s in renNodeInputs: check("RenNode", s)
for s in refNodeInputs: check("RefNode", s)
for s in valNodeInputs: check("ValNode", s)
for s in rawWrapInputs: check("RawWrap", s)
for s in jsonNodeInputs: check("JsonNode", s)

# Fuzz-found malformed/error-parity cases (seed 123456789, 2026-11-15)
check("RenNode", fuzzRenNode452)
check("HookObj", fuzzHookObj473)
check("RenNode", fuzzRenNode591)
check("ObjSnake", fuzzObjSnake754)
check("ObjSmall", fuzzObjSmall815)
check("ObjSmall", fuzzObjSmall1123)

for s in truncSamples:
  for n in 0..s.len:
    check("JsonNode:" & $n, s[0..<n])

echo "test_diff: PASS (", total, " cases)"
