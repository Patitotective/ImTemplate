import std/[strformat, strutils, tables]

import constructor/defaults
import nimgl/[imgui, glfw]
import kdl, kdl/types

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

  RGB* = tuple[r, g, b: range[0f..1f]]
  RGBA* = tuple[r, g, b, a: range[0f..1f]]

  # Because branches cannot have shared and additional fields right now (https://github.com/nim-lang/RFCs/issues/368)
  # There are some weird field names in the object below
  # S is the object for a section
  Setting*[S: object or void] = object
    display*: string
    help*: string
    case kind*: SettingType
    of stInput:
      inputVal*, inputDefault*, inputCache*: string
      inputFlags*: seq[ImGuiInputTextFlags]
      maxLength*: Option[uint]
      hint*: string
    of stCombo, stRadio:
      comboRadioVal*, comboRadioDefault*, comboRadioCache*: string
      comboFlags*: seq[ImGuiComboFlags]
      items*: seq[string]
    of stSection:
      content*: S
      sectionFlags*: seq[ImGuiTreeNodeFlags]
    of stSlider:
      sliderVal*, sliderDefault*, sliderCache*: int32
      sliderFormat*: string
      sliderRange*: Slice[int32]
      sliderFlags*: seq[ImGuiSliderFlags]
    of stFSlider:
      fsliderVal*, fsliderDefault*, fsliderCache*: float32
      fsliderFormat*: string
      fsliderRange*: Slice[float32]
      fsliderFlags*: seq[ImGuiSliderFlags]
    of stSpin:
      spinVal*, spinDefault*, spinCache*: int32
      spinRange*: Slice[int32]
      spinFlags*: seq[ImGuiInputTextFlags]
      step*, stepFast*: int32
    of stFSpin:
      fspinVal*, fspinDefault*, fspinCache*: float32
      fspinFormat*: string
      fspinRange*: Slice[float32]
      fspinFlags*: seq[ImGuiInputTextFlags]
      fstep*, fstepFast*: float32
    of stFile:
      fileVal*, fileDefault*, fileCache*: string
      fileFilterPatterns*: seq[string]
      fileSingleFilterDescription*: string
    of stFiles:
      filesVal*, filesDefault*, filesCache*: seq[string]
      filesFilterPatterns*: seq[string]
      filesSingleFilterDescription*: string
    of stFolder:
      folderVal*, folderDefault*, folderCache*: string
    of stCheck:
      checkVal*, checkDefault*, checkCache*: bool
    of stRGB:
      rgbVal*, rgbDefault*, rgbCache*: RGB
      rgbFlags*: seq[ImGuiColorEditFlags]
    of stRGBA:
      rgbaVal*, rgbaDefault*, rgbaCache*: RGBA
      rgbaFlags*: seq[ImGuiColorEditFlags]

proc inputSetting(display, help = "", default = "", hint = "", maxLength = uint.none, flags = newSeq[ImGuiInputTextFlags]()): Setting[void] =
  ## If maxLength is none, the buffer size will be increased if the buffer also increases.
  Setting[void](display: display, help: help, kind: stInput, inputDefault: default, hint: hint, maxLength: maxLength, inputFlags: flags)

proc checkSetting(display, help = "", default: bool): Setting[void] =
  Setting[void](display: display, help: help, kind: stCheck, checkDefault: default)

proc comboSetting(display, help = "", items: seq[string], default: string, flags = newSeq[ImGuiComboFlags]()): Setting[void] =
  Setting[void](display: display, help: help, kind: stCombo, items: items, comboRadioDefault: default, comboFlags: flags)

type
  Settings* {.defaults.} = object
    a* = inputSetting(display = "Text Input")
    b* = inputSetting(display = "Text Input With Hint", help = "Maximum 10 characters", hint = "type something", maxLength = 10u.some)
    c* = checkSetting(display = "Checkbox", default = false)
    d* = comboSetting(display = "Combo", items = @["a", "b", "c"], default = "a")

implDefaults(Settings)

type
  Config* {.defaults.} = object
    name* = "ImExample"
    comment* = "ImExample is a simple Dear ImGui application example"
    version* = "2.0.0"
    website* = "https://github.com/Patitotective/ImTemplate"
    authors* = [ # [name, url]
      ("Patitotective", "https://github.com/Patitotective"),
      ("Cristobal", "mailto:cristobalriaga@gmail.com"),
      ("Omar Cornut", "https://github.com/ocornut"),
      ("Beef, Yard, Rika", ""),
      ("and the Nim community :]", ""),
      ("Inu147", ""),
    ]
    categories* = "Utility"

    stylePath* = "assets/style.kdl"
    iconPath* = "assets/icon.png"
    svgIconPath* = "assets/icon.svg"

    iconFontPath* = "assets/forkawesome-webfont.ttf"
    fonts* = [ # [path, size]
      (path: "assets/ProggyVector Regular.ttf", size: 16f), # Other options are Roboto-Regular.ttf, Cousine-Regular.ttf or Karla-Regular.ttf
      ("assets/NotoSansJP-Regular.otf", 16f),
    ]

    # AppImage
    ghRepo* = ["Patitotective", "ImTemplate"] # [username, repository]

    # Window
    minSize* = [200, 200] # [width, height]

type
  Prefs* = object
    maximized*: bool
    winpos*: tuple[x, y: int32]
    winsize*: tuple[x, y: int32]
    settings*: Settings

  SettingsModal* = object
    maxLabelWidth*: float32

  App* = object
    win*: GLFWWindow
    config*: Config
    prefs*: KdlPrefs[Prefs] # These are the values that will be saved in the config file
    fonts*: array[2, ptr ImFont]
    settingsmodal*: SettingsModal
    resources*: Table[string, string]

  ImageData* = tuple[image: seq[byte], width, height: int]

implDefaults(Config, {DefaultFlag.defExported})

# proc renameHook*(_: typedesc[Setting], fieldName: var string) =
#   fieldName =
#     case fieldName
#     of "type":
#       "kind"
#     else:
#       fieldName

# proc enumHook*(a: string, v: var SettingType) =
#   try:
#     v = parseEnum[SettingType]("st" & a)
#   except ValueError:
#     raise newException(ValueError, &"invalid enum value {a} for {$typeof(v)}")

# proc decodeHook*(a: KdlNode, v: var Fonts) =
#   if "iconFontPath" in a.props:
#     v.iconFontPath = a["iconFontPath"].getString()

#   for child in a.children:
#     assert child.args.len == 2
#     v.fonts.add (child.args[0].getString(), child.args[1].get(float32))

# proc decodeHook*(a: KdlNode, v: var (ImVec2 or tuple[x, y: int32])) =
#   assert a.args.len == 2
#   when v is ImVec2:
#     v.x = a.args[0].get(float32)
#     v.y = a.args[1].get(float32)
#   else:
#     v.x = a.args[0].get(int32)
#     v.y = a.args[1].get(int32)

# proc decodeHook*(a: KdlNode, v: var tuple[name, url: string]) =
#   assert a.args.len in 1..2
#   v.name = a.args[0].getString()
#   if a.args.len > 1:
#     v.url = a.args[1].getString()

# proc decodeHook*(a: KdlNode, v: var tuple[r, g, b: float32]) =
#   assert a.args.len == 3
#   v.r = a.args[0].get(float32)
#   v.g = a.args[1].get(float32)
#   v.b = a.args[2].get(float32)

# proc decodeHook*(a: KdlNode, v: var tuple[r, g, b, a: float32]) =
#   assert a.args.len == 4
#   v.r = a.args[0].get(float32)
#   v.g = a.args[1].get(float32)
#   v.b = a.args[2].get(float32)
#   v.a = a.args[3].get(float32)

# proc encodeHook*(a: tuple[r, g, b: float32], v: var KdlNode, name: string) =
#   v = initKNode(name, args = toKdlArgs(a.r, a.g, a.b))

# proc encodeHook*(a: tuple[r, g, b, a: float32], v: var KdlNode, name: string) =
#   v = initKNode(name, args = toKdlArgs(a.r, a.g, a.b, a.a))

# proc encodeHook*(a: ImVec2 or tuple[x, y: int32], v: var KdlNode, name: string) =
#   v = initKNode(name, args = toKdlArgs(a.x, a.y))

