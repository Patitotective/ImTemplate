import std/[tables]

import nimgl/[imgui, glfw]
import tinydialogs
import kdl, kdl/[types, utils]
import constructor/defaults
import weave

import configtype, settingstypes

export configtype

proc toSeq[T: enum](_: typedesc[T]): seq[T] =
  for i in T:
    result.add i

type
  Os* {.defaults: {}.} = object
    file* = fileSetting(display = "Text File", filterPatterns = @["*.txt", "*.nim", "*.kdl", "*.json"])
    files* = filesSetting(display = "Multiple files", singleFilterDescription = "Anything", default = @[".bashrc", ".profile"])
    folder* = folderSetting(display = "Folder")

  Numbers* {.defaults: {}.} = object
    spin* = spinSetting(display = "Int Spinner", default = 4, range = 0i32..10i32)
    fspin* = fspinSetting(display = "Float Spinner", default = 3.14, range = 0f..10f)
    slider* = sliderSetting(display = "Int Slider", default = 40, range = -100i32..100i32)
    fslider* = fsliderSetting(display = "Float Slider", default = -2.5, range = -10f..10f)

  Colors* {.defaults: {}.} = object
    rgb* = rgbSetting(default = [1f, 0f, 0.2f])
    rgba* = rgbaSetting(default = [0.4f, 0.7f, 0f, 0.5f], flags = @[AlphaBar, AlphaPreviewHalf])

  Sizes* = enum
    None, Huge, Big, Medium, Small, Mini

  Settings* {.defaults: {}.} = object
    input* = inputSetting(display = "Input", default = "Hello World")
    input2* = inputSetting(
      display = "Custom Input", hint = "Type...",
      help = "Has a hint, 10 characters maximum and only accepts on return",
      limits = 0..10, flags = @[ImGuiInputTextFlags.EnterReturnsTrue]
    )
    check* = checkSetting(display = "Checkbox", default = true)
    combo* = comboSetting(display = "Combo box", items = Sizes.toSeq, default = None)
    radio* = radioSetting(display = "Radio button", items = @[Big, Medium, Small], default = Medium)
    os* = sectionSetting(display = "File dialogs", help = "Single file, multiple files and folder pickers", content = initOs())
    numbers* = sectionSetting(display = "Spinners and sliders", content = initNumbers())
    colors* = sectionSetting(display = "Color pickers", content = initColors())

# For encoding/decoding the settings to/from the preferences file

proc decodeSettingsObj(a: KdlNode, v: var object) =
  for fieldName, field in v.fieldPairs:
    for child in a.children:
      if child.name.eqIdent fieldName:
        case field.kind
        of stInput:
          field.inputVal = decodeKdl(child, typeof(field.inputVal))
        of stCombo:
          when field.comboVal is enum:
            field.comboVal = decodeKdl(child, typeof(field.comboVal))
          else:
            raise newException(ValueError, $fieldName & " must be an enum, got " & $typeof(field.comboVal))
        of stCheck:
          field.checkVal = decodeKdl(child, typeof(field.checkVal))
        of stSlider:
          field.sliderVal = decodeKdl(child, typeof(field.sliderVal))
        of stFSlider:
          field.fsliderVal = decodeKdl(child, typeof(field.fsliderVal))
        of stSpin:
          field.spinVal = decodeKdl(child, typeof(field.spinVal))
        of stFSpin:
          field.fspinVal = decodeKdl(child, typeof(field.fspinVal))
        of stRadio:
          when field.radioVal is enum:
            field.radioVal = decodeKdl(child, typeof(field.radioVal))
          else:
            raise newException(ValueError, $fieldName & " must be an enum, got " & $typeof(field.radioVal))
        of stSection:
          when field.content is object:
            decodeSettingsObj(child, field.content)
          else:
            raise newException(ValueError, $fieldName & " must be an object, got " & $typeof(field.content))
        of stRGB:
          field.rgbVal = decodeKdl(child, typeof(field.rgbVal))
        of stRGBA:
          field.rgbaVal = decodeKdl(child, typeof(field.rgbaVal))
        of stFile:
          field.fileVal = decodeKdl(child, typeof(field.fileVal))
        of stFiles:
          field.filesVal = decodeKdl(child, typeof(field.filesVal))
        of stFolder:
          field.folderVal = decodeKdl(child, typeof(field.folderVal))

proc decodeKdl*(a: KdlNode, v: var Settings) =
  v = initSettings()
  decodeSettingsObj(a, v)

proc encodeKdl*[T](a: FlowVar[T], v: var KdlVal) =
  if not a.isSpawned or not a.isReady:
    v = initKNull()
  else:
    v = encodeKdlVal(sync a)

proc encodeKdl*(a: Empty, v: var KdlVal) =
  v = initKNull()

proc encodeKdl*(a: seq[string], b: var KdlNode, name: string) =
  b = initKNode(name)
  for i in a:
    b.args.add initKString(i)

proc encodeKdl*[T: Ordinal](a: array[T, float32], b: var KdlNode, name: string) =
  b = initKNode(name)
  for i in a:
    b.args.add initKFloat(i)

proc encodeSettingsObj(a: object): KdlDoc =
  for fieldName, field in a.fieldPairs:
    let node =
      case field.kind
      of stInput:
        encodeKdlNode(field.inputVal, $fieldName)
      of stCombo:
        when field.comboVal is enum:
          encodeKdlNode(field.comboVal, $fieldName)
        else:
          raise newException(ValueError, $fieldName & " must be an enum, got " & $typeof(field.comboVal))
      of stCheck:
        encodeKdlNode(field.checkVal, $fieldName)
      of stSlider:
        encodeKdlNode(field.sliderVal, $fieldName)
      of stFSlider:
        encodeKdlNode(field.fsliderVal, $fieldName)
      of stSpin:
        encodeKdlNode(field.spinVal, $fieldName)
      of stFSpin:
        encodeKdlNode(field.fspinVal, $fieldName)
      of stRadio:
        when field.comboVal is enum:
          encodeKdlNode(field.radioVal, $fieldName)
        else:
          raise newException(ValueError, $fieldName & " must be an enum, got " & $typeof(field.radioVal))
      of stSection:
        when field.content is object:
          initKNode($fieldName, children = encodeSettingsObj(field.content))
        else:
          raise newException(ValueError, $fieldName & " must be an object, got " & $typeof(field.content))
      of stRGB:
        encodeKdlNode(field.rgbVal, $fieldName)
      of stRGBA:
        encodeKdlNode(field.rgbaVal, $fieldName)
      of stFile:
        encodeKdlNode(field.fileVal, $fieldName)
      of stFiles:
        encodeKdlNode(field.filesVal, $fieldName)
      of stFolder:
        encodeKdlNode(field.folderVal, $fieldName)

    result.add node

proc encodeKdl*(a: Settings, v: var KdlNode, name: string) =
  v = initKNode(name, children = encodeSettingsObj(a))

type
  Prefs* {.defaults: {defExported}.} = object
    maximized* = false
    winpos* = (x: -1i32, y: -1i32) # < 0: center the window
    winsize* = (w: 600i32, h: 650i32)
    settings* = initSettings()

  App* = object
    win*: GLFWWindow
    config*: Config
    prefs*: KdlPrefs[Prefs] # These are the values that will be saved in the prefs file
    fonts*: array[Config.fonts.len, ptr ImFont]
    resources*: Table[string, string]

    maxLabelWidth*: float32 # For the settings modal
    messageBoxResult*: FlowVar[Button]

  ImageData* = tuple[image: seq[byte], width, height: int]

  OpenFileDialogArgs* = tuple[title, defaultPath: string, filterPatterns: seq[string], singleFilterDescription: string]
