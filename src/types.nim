import std/[tables]

import nimgl/[imgui, glfw]
import constructor/defaults
import kdl, kdl/types

type
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

  RGB* = object
    r*, g*, b*: range[0f..1f]

  RGBA* = object
    r*, g*, b*, a*: range[0f..1f]

  Empty* = object # https://forum.nim-lang.org/t/10565

  # Because branches cannot have shared and additional fields right now (https://github.com/nim-lang/RFCs/issues/368)
  # There are some weird field names in the object below
  # S is the object for a section
  Setting*[T: object or enum or bool] = object
    display*: string
    help*: string
    case kind*: SettingType
    of stInput:
      inputVal*, inputDefault*, inputCache*: string
      inputFlags*: seq[ImGuiInputTextFlags]
      limits*: HSlice[uint, Option[uint]]
      hint*: string
    of stCombo:
      comboVal*, comboDefault*, comboCache*: T
      comboFlags*: seq[ImGuiComboFlags]
      comboIncludeOnly*: seq[T]
    of stRadio:
      radioVal*, radioDefault*, radioCache*: T
      radioIncludeOnly*: seq[T]
    of stSection:
      content*: T
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

proc inputSetting(display, help, default, hint = "", limits = 0u..uint.none, flags = newSeq[ImGuiInputTextFlags]()): Setting[Empty] =
  Setting[Empty](display: display, help: help, kind: stInput, inputDefault: default, hint: hint, limits: limits, inputFlags: flags)

proc checkSetting(display, help = "", default: bool): Setting[Empty] =
  Setting[Empty](display: display, help: help, kind: stCheck, checkDefault: default)

proc comboSetting[T: enum](display, help = "", default: T, includeOnly = newSeq[T](), flags = newSeq[ImGuiComboFlags]()): Setting[T] =
  Setting[T](display: display, help: help, kind: stCombo, comboincludeOnly: includeOnly, comboDefault: default, comboFlags: flags)

proc radioSetting[T: enum](display, help = "", default: T, includeOnly = newSeq[T]()): Setting[T] =
  Setting[T](display: display, help: help, kind: stRadio, radioincludeOnly: includeOnly, radioDefault: default)

proc sectionSetting[T: object](display, help = "", content: T, flags = newSeq[ImGuiTreeNodeFlags]()): Setting[T] =
  Setting[T](display: display, help: help, kind: stSection, content: content, sectionFlags: flags)

proc sliderSetting(display, help = "", default = 0i32, range: Slice[int32], format = "%d", flags = newSeq[ImGuiSliderFlags]()): Setting[Empty] =
  Setting[Empty](display: display, help: help, kind: stSlider, sliderDefault: default, sliderRange: range, sliderFormat: format, sliderFlags: flags)

proc fsliderSetting(display, help = "", default = 0f, range: Slice[float32], format = "%.2f", flags = newSeq[ImGuiSliderFlags]()): Setting[Empty] =
  Setting[Empty](display: display, help: help, kind: stFSlider, fsliderDefault: default, fsliderRange: range, fsliderFormat: format, fsliderFlags: flags)

proc spinSetting(display, help = "", default = 0i32, range: Slice[int32], step = 1i32, stepFast = 10i32, flags = newSeq[ImGuiInputTextFlags]()): Setting[Empty] =
  Setting[Empty](display: display, help: help, kind: stSpin, spinDefault: default, spinRange: range, step: step, stepFast: stepFast, spinFlags: flags)

proc fspinSetting(display, help = "", default = 0f, range: Slice[float32], step = 0.1f, stepFast = 1f, format = "%.2f", flags = newSeq[ImGuiInputTextFlags]()): Setting[Empty] =
  Setting[Empty](display: display, help: help, kind: stFSpin, fspinDefault: default, fspinRange: range, fstep: step, fstepFast: stepFast, fspinFormat: format, fspinFlags: flags)

proc fileSetting(display, help, default = "", filterPatterns = newSeq[string](), singleFilterDescription = ""): Setting[Empty] =
  Setting[Empty](display: display, help: help, kind: stFile, fileDefault: default, fileFilterPatterns: filterPatterns, fileSingleFilterDescription: singleFilterDescription)

proc filesSetting(display, help = "", default = newSeq[string](), filterPatterns = newSeq[string](), singleFilterDescription = ""): Setting[Empty] =
  Setting[Empty](display: display, help: help, kind: stFiles, filesDefault: default, filesFilterPatterns: filterPatterns, filesSingleFilterDescription: singleFilterDescription)

proc folderSetting(display, help, default = ""): Setting[Empty] =
  Setting[Empty](display: display, help: help, kind: stFolder, folderDefault: default)

proc rgbSetting(display, help = "", default: RGB, flags = newSeq[ImGuiColorEditFlags]()): Setting[Empty] =
  Setting[Empty](display: display, help: help, kind: stRGB, rgbDefault: default, rgbFlags: flags)

proc rgbaSetting(display, help = "", default: RGBA, flags = newSeq[ImGuiColorEditFlags]()): Setting[Empty] =
  Setting[Empty](display: display, help: help, kind: stRGBA, rgbaDefault: default, rgbaFlags: flags)

proc rgb*(r, g, b: float32): RGB = RGB(r: r, g: g, b: b)
proc rgba*(r, g, b, a: float32): RGBA = RGBA(r: r, g: g, b: b, a: a)

type
  Os* {.defaults: {}.} = object
    file* = fileSetting(display = "Text File", filterPatterns = @["*.txt", "*.nim", "*.kdl", "*.json"])
    files* = filesSetting(display = "Multiple files", singleFilterDescription = "Anything")
    folder* = folderSetting(display = "Folder")

  Numbers* {.defaults: {}.} = object
    spin* = spinSetting(display = "Int Spinner", default = 4, range = 0i32..10i32)
    fspin* = fspinSetting(display = "Float Spinner", default = 3.14, range = 0f..10f)
    slider* = sliderSetting(display = "Int Slider", default = 40, range = -100i32..100i32)
    fslider* = fsliderSetting(display = "Float Slider", default = -2.5, range = -10f..10f)

  Colors* {.defaults: {}.} = object
    rgb* = rgbSetting(default = rgb(1, 0, 0.2))
    rgba* = rgbaSetting(default = rgba(0.4, 0.7, 0, 0.5), flags = @[AlphaBar, AlphaPreviewHalf])

  Sizes* = enum
    None, Huge, Big, Medium, Small, Mini

  Settings* {.defaults: {}.} = object
    input* = inputSetting(display = "Input", default = "Hello World")
    input2* = inputSetting(display = "Custom Input", help = "Has a hint, 1 character minimum and 10 characters maximum and only accepts on return", hint = "Type...", limits = 1u..10u.some, flags = @[ImGuiInputTextFlags.EnterReturnsTrue])
    check* = checkSetting(display = "Checkbox", default = true)
    combo* = comboSetting[Sizes](display = "Combo box", default = None)
    radio* = radioSetting[Sizes](display = "Radio button", includeOnly = @[Big, Medium, Small], default = Medium)
    os* = sectionSetting(display = "File dialogs", content = initOs())
    numbers* = sectionSetting(display = "Spinners and sliders", content = initNumbers())
    colors* = sectionSetting(display = "Color pickers", content = initColors())

  GlyphRanges* = enum
    Default, ChineseFull, ChineseSimplified, Cyrillic, Japanese, Korean, Thai, Vietnamese

  Font* = object
    path*: string
    size*: float32
    glyphRanges*: GlyphRanges

proc font*(path: string, size: float32, glyphRanges = GlyphRanges.Default): Font =
  Font(path: path, size: size, glyphRanges: glyphRanges)

type
  Config* {.defaults: {defExported}.} = object
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
    fonts* = [
      font("assets/ProggyVector Regular.ttf", 16f), # Other options are Roboto-Regular.ttf, Cousine-Regular.ttf or Karla-Regular.ttf
      font("assets/NotoSansJP-Regular.otf", 16f, GlyphRanges.Japanese),
    ]

    # AppImage
    ghRepo* = ["Patitotective", "ImTemplate"] # [username, repository]

    # Window
    minSize* = (w: 200i32, h: 200i32) # < 0: don't care

  Prefs* {.defaults: {defExported}.} = object
    maximized* = false
    winpos* = (x: -1i32, y: -1i32) # < 0: center the window
    winsize* = (w: 600i32, h: 650i32)
    settings* = initSettings()

  App* = object
    win*: GLFWWindow
    config*: Config
    prefs*: KdlPrefs[Prefs] # These are the values that will be saved in the config file
    fonts*: array[Config.fonts.len, ptr ImFont]
    resources*: Table[string, string]

    maxLabelWidth*: float32 # For the settings modal

  ImageData* = tuple[image: seq[byte], width, height: int]

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

