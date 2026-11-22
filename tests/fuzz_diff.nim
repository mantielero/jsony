import std/[random, os, osproc, strutils, strformat]

# Differential fuzzer: generate/mutate JSON-ish inputs and compare
# tests/diff_runner_orig vs tests/diff_runner_new per-case.
# Saves first discrepancies to tests/regressions/.
#
# Hardening: write+flush each input before execution and run each case with a
# per-process timeout. A timeout is treated as a discrepancy (hang) — especially
# "new hangs, orig ok" which indicates a fast-path progress bug.

let tmp = getTempDir() / "jsony_fuzz_diff"
createDir(tmp)
createDir("tests/regressions")
let origBin = tmp / "diff_runner_orig"
let newBin = tmp / "diff_runner_new"
let curCasePath = tmp / "cur_case.txt"

proc compileRunner(src, outp: string) =
  let cmd = "nim c --hints:off --warnings:off --stackTrace:off --lineTrace:off -o:" & quoteShell(outp) & " " & quoteShell(src)
  let res = execCmdEx(cmd)
  if res.exitCode != 0:
    echo res.output
    quit("failed to compile " & src)

compileRunner("tests/diff_runner_orig.nim", origBin)
compileRunner("tests/diff_runner_new.nim", newBin)

var timeoutSec = "2"
if paramCount() >= 3:
  timeoutSec = paramStr(3)

proc runCase(bin, label, input: string): (int, string) =
  # timeout returns 124 on timeout (GNU coreutils); treat as hang
  let cmd = "timeout " & timeoutSec & "s " & quoteShell(bin) & " " & quoteShell(label) & " " & quoteShell(input)
  let res = execCmdEx(cmd)
  if res.exitCode == 124:
    (124, "TIMEOUT")
  else:
    (res.exitCode, res.output.strip())

var seed = 123456789'i64
if paramCount() >= 1:
  try: seed = parseBiggestInt(paramStr(1)) except: discard
var iters = 2000
if paramCount() >= 2:
  try: iters = parseInt(paramStr(2)) except: discard

randomize(seed)

const labels = ["int", "int64", "uint64", "float64", "string", "bool", "seq[int]",
  "ObjSmall", "ObjOpt", "ObjNested", "ObjSeq", "ObjSnake", "Arr3", "Tup3", "char",
  "TblStrInt", "SetInt", "ColorE", "ColorHook", "HookObj", "NewHookObj", "RenNode",
  "RefNode", "ValNode", "JsonNode"]

proc randStr(maxLen=12): string =
  let n = rand(maxLen)
  result = newStringOfCap(n)
  for i in 0..<n:
    let r = rand(40)
    case r
    of 0..9: result.add char(ord('0') + r)
    of 10..19: result.add char(ord('a') + r - 10)
    of 20: result.add '"'
    of 21: result.add '\\'
    of 22: result.add '\n'
    of 23: result.add '{'
    of 24: result.add '}'
    of 25: result.add '['
    of 26: result.add ']'
    of 27: result.add ':'
    of 28: result.add ','
    of 29: result.add '-'
    of 30: result.add 'e'
    of 31: result.add '.'
    of 32: result.add ' '
    of 33: result.add '\t'
    else: result.add char(rand(127))

proc genJson(depth=0): string =
  if depth > 3:
    case rand(5)
    of 0: return $rand(1000)
    of 1: return (if rand(1)==0: "true" else: "false")
    of 2: return "null"
    of 3: return "\"" & randStr(6) & "\""
    else: return "[]"
  case rand(6)
  of 0:
    return $rand(10000) & (if rand(1)==0: "" else: "." & $rand(100))
  of 1:
    return (if rand(1)==0: "true" else: "false")
  of 2:
    return "null"
  of 3:
    return "\"" & randStr(10) & "\""
  of 4:
    var s = "["
    let n = rand(4)
    for i in 0..<n:
      if i > 0: s.add ","
      s.add genJson(depth+1)
    s.add "]"
    return s
  else:
    var s = "{"
    let n = rand(4)
    for i in 0..<n:
      if i > 0: s.add ","
      s.add "\"" & randStr(5) & "\":" & genJson(depth+1)
    s.add "}"
    return s

proc mutate(s: string): string =
  if s.len == 0: return randStr()
  var r = s
  case rand(5)
  of 0: # delete
    let i = rand(r.high); r.delete(i..i)
  of 1: # duplicate
    let i = rand(r.high); r.insert($r[i], i)
  of 2: # replace
    let i = rand(r.high); r[i] = char(rand(127))
  of 3: # truncate
    r = r[0..<rand(r.len)]
  else: # append junk
    r.add randStr(3)
  r

proc writeCurCase(label, input: string, iter: int) =
  let f = open(curCasePath, fmWrite)
  f.write("iter=" & $iter & "\nseed=" & $seed & "\nlabel=" & label & "\ninput=" & input.escape & "\n")
  f.flushFile()
  f.close()

var diffs = 0
for i in 0..<iters:
  let label = labels[rand(labels.high)]
  var inp = if rand(1)==0: genJson() else: mutate(genJson())
  # Persist current case before execution so hangs/timeouts can be reproduced.
  writeCurCase(label, inp, i)
  let (c1,o1) = runCase(origBin, label, inp)
  let (c2,o2) = runCase(newBin, label, inp)
  if c1 != c2 or o1 != o2:
    inc diffs
    let fname = "tests/regressions/fuzz_" & $seed & "_" & $i & ".txt"
    let f = open(fname, fmWrite)
    f.write("label=" & label & "\ninput=" & inp.escape & "\norig_code=" & $c1 & "\norig=" & o1 & "\nnew_code=" & $c2 & "\nnew=" & o2 & "\n")
    f.flushFile()
    f.close()
    if c2 == 124 and c1 != 124:
      echo "HANG (new) saved ", fname
    else:
      echo "DIFF saved ", fname
    if diffs >= 10:
      echo "too many diffs, stopping"
      quit(1)

echo "fuzz_diff: OK seed=", seed, " iters=", iters, " diffs=", diffs, " timeout_s=", timeoutSec
