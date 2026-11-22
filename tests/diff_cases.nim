# Shared differential-test inputs and types.
# Runners compare the frozen reference against the current implementation
# for each label/input pair, including values, errors, defects, and crashes.
import std/[json, options, tables, sets]

type
  ObjSmall* = object
    a*: int
    b*: string
    c*: bool
  ObjOpt* = object
    x*: Option[int]
    y*: Option[string]
  ObjNested* = object
    id*: int
    inner*: ObjSmall
  ObjSeq* = object
    nums*: seq[int]
    strs*: seq[string]
  ObjSnake* = object
    colorBlend*: string
  Arr3* = array[3, int]
  Tup3* = tuple[x: int, y: string, z: float64]
  TblStrInt* = Table[string, int]
  SetInt* = HashSet[int]

  NodeNumKind* = enum
    nkInt, nkFloat
  RefNode* = ref object
    active*: bool
    case kind*: NodeNumKind
    of nkInt: intVal*: int
    of nkFloat: floatVal*: float
  ValNode* = object
    active*: bool
    case kind*: NodeNumKind
    of nkInt: intVal*: int
    of nkFloat: floatVal*: float

  HookObj* = object
    size*: int
    originalSize*: int
  NewHookObj* = object
    visible*: string
    id*: string
  RenNode* = ref object
    kind*: string
  ColorE* = enum
    cRed, cBlue, cGreen
  ColorHook* = enum
    hRed, hBlue, hGreen

proc postHook*(v: var HookObj) =
  v.originalSize = v.size

proc newHook*(v: var NewHookObj) =
  v.visible = "yes"

proc renameHook*(v: var RenNode, fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"

proc enumHook*(s: string, v: var ColorHook) =
  case s
  of "RED": v = hRed
  of "BLUE": v = hBlue
  of "GREEN": v = hGreen
  else: v = hRed

# variant rename hook cases (discriminator rename)
proc renameHook*(v: var RefNode|ValNode, fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"

const
  intInputs* = ["0", "-0", "1", "-1", "42", "2147483647", "-2147483648", "", "-", "+", "1.0", "1e3", "01", "007", " 1 ", "9223372036854775808", "   5", "5   x"]
  int64Inputs* = ["0", "9223372036854775807", "-9223372036854775808"]
  uint64Inputs* = ["0", "1", "18446744073709551615", "-1", "18446744073709551616"]
  floatInputs* = ["0", "0.0", "-0.0", "0.1", "1e0", "1E5", "1e+5", "1e-5",
    "123.456", "3.141592653589793", "0.30000000000000004", "9007199254740993",
    "1e400", "-1e400", "1e-400", "5e-324", "2.2250738585072014e-308",
    ".5", "5.", "1e", "--1", "+1.0", "nan", "NaN", "Infinity", "-Infinity", "  1.5  "]
  strInputs* = ["\"\"", "\"hello\"", "\"a\\nb\"", "\"\\\"\\\\\\/\\b\\f\\n\\r\\t\"",
    "\"\\u0041\"", "\"\\u00e9\"", "\"\\ud83d\\ude00\"", "\"\\u00E9\"",
    "\"unterminated", "\"\\uD800\"", "\"\\x41\"", "null",
    "\"simple ascii 123\"", "\"tab\\tand\\rcarriage\"", "\"solidus\\/\"", "\"backspace\\bform\\f\"",
    "\"\\u0000\"", "\"mixed \\ud83d\\udd12\""]
  boolInputs* = ["true", "false", "TRUE", "1", "null", "", " true "]
  seqIntInputs* = ["[]", "[1]", "[1,2,3]", "[ 1 , 2 , 3 ]", "[1,]", "truncated", "[[1],[2,3]]"]
  objSmallInputs* = ["""{"a":1,"b":"hi","c":true}""",
    """{"a":1,"b":"hi","c":true,"extra":99}""",
    """{"b":"hi","c":false}""",
    """{"a":1,"b":"hi"}""",
    """ { "a" : 2 , "b" : "x" , "c" : false } """,
    """{"a":1,"b":"hi","c":true} extra"""]
  objOptInputs* = ["""{"x":1,"y":"z"}""", """{"x":null,"y":null}""", """{}""", """{"x":0}"""]
  objNestedInputs* = ["""{"id":7,"inner":{"a":2,"b":"x","c":true}}""",
    """{"id":7,"inner":{"b":"x","c":true},"extra":{"deep":[1,2]}}"""]
  objSeqInputs* = ["""{"nums":[1,2,3],"strs":["a","b"]}""", """{"nums":[],"strs":[]}"""]
  objSnakeInputs* = ["""{"colorBlend":"red"}""", """{"color_blend":"red"}"""]
  arrInputs* = ["[1,2,3]", "[1,2]", "[1,2,3,4]", "[]", "null"]
  tupInputs* = ["[1,\"hi\",3.5]", "{\"x\":1,\"y\":\"hi\",\"z\":3.5}", "[1,\"hi\"]"]
  charInputs* = ["\"a\"", "\"ab\"", "\"\"", "1"]
  tableInputs* = ["""{"a":1,"b":2}""", """{}""", """{"x":-5}"""]
  setInputs* = ["[1,2,3]", "[]", "[1,1,2]"]
  enumInputs* = ["\"cRed\"", "\"cBlue\"", "\"cGreen\"", "0", "1", "2", "\"nope\"", "3"]
  enumHookInputs* = ["\"RED\"", "\"BLUE\"", "\"GREEN\"", "\"OTHER\"", "0"]
  hookObjInputs* = ["""{"size":10}""", """{"size":0}"""]
  newHookInputs* = ["""{"id":"1"}""", """{"id":"1","visible":"no"}"""]
  renNodeInputs* = ["""{"type":"root"}""", """{"kind":"root"}""", """{"type":"root","x":1}"""]
  rawWrapInputs* = ["""{"id":1,"data":{"a":1,"b":[2,3]}}""", """{"id":2,"data":null}""", """{"id":3,"data":[1,2]}""", """{"id":4,"data":"x"}"""]
  refNodeInputs* = [
    """{"active":true,"kind":"nkFloat","floatVal":3.14}""",
    """{"floatVal":3.14,"active":true,"kind":"nkFloat"}""",
    """{"kind":"nkInt","intVal":42,"active":false}""",
    """{"active":true,"intVal":7}""",
    """{"active":true,"type":"nkFloat","floatVal":1.5}""",
    """{"type":"nkFloat","floatVal":3.14,"type":"nkInt"}""",
    "null"
  ]
  valNodeInputs* = [
    """{"active":true,"kind":"nkFloat","floatVal":3.14}""",
    """{"floatVal":3.14,"active":true,"kind":"nkFloat"}""",
    """{"kind":"nkInt","intVal":42,"active":false}""",
    """{"active":true,"intVal":7}""",
    """{"active":true,"type":"nkFloat","floatVal":1.5}""",
    """{"type":"nkFloat","floatVal":3.14,"type":"nkInt"}"""
  ]
  jsonNodeInputs* = [
    "null", "true", "false", "0", "1.5", "\"hi\"", "[]", "[1,2]", "{}", "{\"a\":1}",
    "{\"a\":[1,{\"b\":null}]}"
  ]
  truncSamples* = ["""{"a":1,"b":"hello","c":true}""", """[1,2,3,4,5]""", "\"hello\\nworld\"", """{"x":null,"y":[1,2]}"""]

  # Fuzz-found malformed/error-parity cases (seed 123456789, 2026-11-15)
  fuzzRenNode452* = "{\"8\":\"8,\"e\t5}\":2745}"
  fuzzHookObj473* = "{\"\n[-\":6048.77,\"\":\"g0\"ie5\",\"79i\":3375.36}"
  fuzzRenNode591* = "{\"}a\":{\":\":null,\"leg\":true},\"\t,i\":\"\"fj\"}"
  fuzzObjSnake754* = "{\"\":\"-8\\\",\"\":\"\nd-7452 b-\"}"
  fuzzObjSmall815* = "{\" :1f7\":null,\"w\":\"g52\":867c8\",\"\":\"4f]af{\",\"8efN\x18\":{\"26efh\":null,\"N{[:\":2589.96,\"6[\":{},\"\t\":true}}"
  fuzzObjSmall1123* = "{\"i\":null,\"\":{\"\":{\"\":true,\"g1\":[269,null,false,199],\"f\":false,\"8b\x0C\":null},\".f5\x1Eg\":null,\"j4\x0A\":[5262]},\"\":\"\"\"}"
