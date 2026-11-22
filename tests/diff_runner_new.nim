# Differential runner for the current implementation under test.
# Emits the same stable format as diff_runner_orig for strict comparison.
import std/[strutils, json as stdjson, os, options, tables, sets, algorithm]
import ../src/jsony
import ./diff_cases

type RawWrapLocal = object
  id: int
  data: RawJson

proc tableToStr(v: Table[string, int]): string =
  var ps: seq[(string, int)]
  for k, val in pairs(v):
    ps.add((k, val))
  ps.sort(proc(a, b: (string, int)): int = cmp(a[0], b[0]))
  $ps

proc setToStr(v: HashSet[int]): string =
  var xs: seq[int]
  for x in v.items:
    xs.add(x)
  xs.sort()
  $xs

proc emit[T](label: string, input: string, t: typedesc[T]) =
  var v: T
  try:
    v = fromJson(input, T)
    when T is float32 | float64:
      echo label, "|OK|", cast[uint64](float64(v)), "|", $v
    elif T is string:
      echo label, "|OK|", escape(v)
    elif T is stdjson.JsonNode:
      echo label, "|OK|", $v
    elif T is Table[string, int]:
      echo label, "|OK|", tableToStr(v)
    elif T is HashSet[int]:
      echo label, "|OK|", setToStr(v)
    elif T is RawWrapLocal:
      echo label, "|OK|", v.id, "|", escape(string(v.data))
    elif T is ref:
      if v.isNil:
        echo label, "|OK|null"
      else:
        echo label, "|OK|ref:", $v[]
    else:
      echo label, "|OK|", $v
  except jsony.JsonError as e:
    echo label, "|ERR|JsonError|", e.msg
  except CatchableError as e:
    echo label, "|ERR|", $e.name, "|", e.msg
  except Defect as e:
    echo label, "|DEFECT|", $e.name, "|", e.msg

proc runOne(label, input: string) =
  case label
  of "int": emit("int", input, int)
  of "int64": emit("int64", input, int64)
  of "uint64": emit("uint64", input, uint64)
  of "float64": emit("float64", input, float64)
  of "string": emit("string", input, string)
  of "bool": emit("bool", input, bool)
  of "seq[int]": emit("seq[int]", input, seq[int])
  of "ObjSmall": emit("ObjSmall", input, ObjSmall)
  of "ObjOpt": emit("ObjOpt", input, ObjOpt)
  of "ObjNested": emit("ObjNested", input, ObjNested)
  of "ObjSeq": emit("ObjSeq", input, ObjSeq)
  of "ObjSnake": emit("ObjSnake", input, ObjSnake)
  of "Arr3": emit("Arr3", input, Arr3)
  of "Tup3": emit("Tup3", input, Tup3)
  of "char": emit("char", input, char)
  of "TblStrInt": emit("TblStrInt", input, TblStrInt)
  of "SetInt": emit("SetInt", input, SetInt)
  of "ColorE": emit("ColorE", input, ColorE)
  of "ColorHook": emit("ColorHook", input, ColorHook)
  of "HookObj": emit("HookObj", input, HookObj)
  of "NewHookObj": emit("NewHookObj", input, NewHookObj)
  of "RenNode": emit("RenNode", input, RenNode)
  of "RefNode": emit("RefNode", input, RefNode)
  of "ValNode": emit("ValNode", input, ValNode)
  of "RawWrap": emit("RawWrap", input, RawWrapLocal)
  elif label.startsWith("JsonNode:") or label == "JsonNode":
    emit(label, input, stdjson.JsonNode)
  else:
    echo "UNKNOWN|", label

when isMainModule:
  if paramCount() >= 2:
    runOne(paramStr(1), paramStr(2))
  else:
    for s in intInputs: runOne("int", s)
    for s in int64Inputs: runOne("int64", s)
    for s in uint64Inputs: runOne("uint64", s)
    for s in floatInputs: runOne("float64", s)
    for s in strInputs: runOne("string", s)
    for s in boolInputs: runOne("bool", s)
    for s in seqIntInputs: runOne("seq[int]", s)
    for s in objSmallInputs: runOne("ObjSmall", s)
    for s in objOptInputs: runOne("ObjOpt", s)
    for s in objNestedInputs: runOne("ObjNested", s)
    for s in objSeqInputs: runOne("ObjSeq", s)
    for s in objSnakeInputs: runOne("ObjSnake", s)
    for s in arrInputs: runOne("Arr3", s)
    for s in tupInputs: runOne("Tup3", s)
    for s in charInputs: runOne("char", s)
    for s in tableInputs: runOne("TblStrInt", s)
    for s in setInputs: runOne("SetInt", s)
    for s in enumInputs: runOne("ColorE", s)
    for s in enumHookInputs: runOne("ColorHook", s)
    for s in hookObjInputs: runOne("HookObj", s)
    for s in newHookInputs: runOne("NewHookObj", s)
    for s in renNodeInputs: runOne("RenNode", s)
    for s in refNodeInputs: runOne("RefNode", s)
    for s in valNodeInputs: runOne("ValNode", s)
    for s in rawWrapInputs: runOne("RawWrap", s)
    for s in jsonNodeInputs: runOne("JsonNode", s)
    for s in truncSamples:
      for n in 0..s.len:
        runOne("JsonNode:" & $n, s[0..<n])
