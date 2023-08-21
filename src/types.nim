import std/[strformat, strutils, tables]

import kdl, kdl/types
import nimgl/[imgui, glfw]

type # Config
  SettingType* = enum
    stInput # Input text
    stCheck # Checkbox
    stSlider # Int slider
    stFSlider # Float slider
    stSpin # Int spin
    stFSpin # Float spin
    stCombo
    stRadio # Radio button
    stRGB # Color edit RGB
    stRGBA # Color edit RGBA
    stSection
    stFile # File picker
    stFiles # Multiple files picker
    stFolder # Folder picker

  Setting* = object
    display*: string
    flags*: seq[string]
    help*: string
    format*: Option[string] # Only applies to stSlider, stFSlider, stSpin and stFSpin but https://github.com/nim-lang/RFCs/issues/368
    case kind*: SettingType
    of stInput:
      maxbuf*: uint
      hint*: Option[string]
    of stCombo, stRadio:
      items*: seq[string]
    of stSection:
      content*: OrderedTable[string, Setting]
    of stSlider, stFSlider, stSpin, stFSpin: # Only stSpin and stFSpin actually use step and stepfast but ^^#368^^
      min*, max*: Option[float32]
      step*, stepfast*: float32
    of stFile, stFiles:
      filterPatterns*: seq[string]
      singleFilterDescription*: string
    else: discard

  Fonts* = object
    iconFontPath*: string
    fonts*: seq[tuple[path: string, size: float32]]

  Config* = object
    name*: string
    comment*: string
    version*: string
    website*: string
    authors*: seq[tuple[name: string, url: string]]
    categories*: seq[string]
    ghRepo*: Option[(string, string)]
    appstreamPath*: Option[string]
    stylePath*: string
    iconPath*: string
    svgIconPath*: string
    fonts*: Fonts
    minSize*: Option[tuple[x, y: int32]]
    settings*: OrderedTable[string, Setting]

type
  Numbers* = object
    slider*, spin*: int32
    floatSlider*, floatSpin*: float32

  Colors* = object
    rgb*: tuple[r, g, b: float32]
    rgba*: tuple[r, g, b, a: float32]

  Abc* = enum
    A = "a", B = "b", C = "c"

  Os* = object
    file*, folder*: string
    files*: seq[string]    

  Settings* = object
    input*, hintInput*: string
    checkbox*: bool
    combo*, radio*: Abc
    os*: Os
    numbers*: Numbers
    colors*: Colors

  Prefs* = object
    maximized*: bool
    winpos*: tuple[x, y: int32]
    winsize*: tuple[x, y: int32]
    settings*: Settings

  SettingsModal* = object
    cache*: Settings
    maxLabelWidth*: float32

  App* = object
    win*: GLFWWindow
    config*: Config
    prefs*: KdlPrefs[Prefs]
    fonts*: array[2, ptr ImFont]
    settingsmodal*: SettingsModal
    resources*: Table[string, string]

  ImageData* = tuple[image: seq[byte], width, height: int]

proc renameHook*(_: typedesc[Setting], fieldName: var string) = 
  fieldName = 
    case fieldName
    of "type":
      "kind"
    else:
      fieldName

proc enumHook*(a: string, v: var SettingType) = 
  try:
    v = parseEnum[SettingType]("st" & a)
  except ValueError:
    raise newException(ValueError, &"invalid enum value {a} for {$typeof(v)}")

proc decodeHook*(a: KdlNode, v: var Fonts) = 
  if "iconFontPath" in a.props:
    v.iconFontPath = a["iconFontPath"].getString()

  for child in a.children:
    assert child.args.len == 2
    v.fonts.add (child.args[0].getString(), child.args[1].get(float32))

proc decodeHook*(a: KdlNode, v: var (ImVec2 or tuple[x, y: int32])) = 
  assert a.args.len == 2
  when v is ImVec2:
    v.x = a.args[0].get(float32)
    v.y = a.args[1].get(float32)
  else:
    v.x = a.args[0].get(int32)
    v.y = a.args[1].get(int32)

proc decodeHook*(a: KdlNode, v: var tuple[name, url: string]) = 
  assert a.args.len in 1..2
  v.name = a.args[0].getString()
  if a.args.len > 1:
    v.url = a.args[1].getString()

proc decodeHook*(a: KdlNode, v: var tuple[r, g, b: float32]) = 
  assert a.args.len == 3
  v.r = a.args[0].get(float32)
  v.g = a.args[1].get(float32)
  v.b = a.args[2].get(float32)

proc decodeHook*(a: KdlNode, v: var tuple[r, g, b, a: float32]) = 
  assert a.args.len == 4
  v.r = a.args[0].get(float32)
  v.g = a.args[1].get(float32)
  v.b = a.args[2].get(float32)
  v.a = a.args[3].get(float32)

proc encodeHook*(a: tuple[r, g, b: float32], v: var KdlNode, name: string) = 
  v = initKNode(name, args = toKdlArgs(a.r, a.g, a.b))

proc encodeHook*(a: tuple[r, g, b, a: float32], v: var KdlNode, name: string) = 
  v = initKNode(name, args = toKdlArgs(a.r, a.g, a.b, a.a))

proc encodeHook*(a: ImVec2 or tuple[x, y: int32], v: var KdlNode, name: string) = 
  v = initKNode(name, args = toKdlArgs(a.x, a.y))
