import std/[strutils, strformat, typetraits, enumutils, macros, times, os]
import chroma
import niprefs
import stb_image/read as stbi
import nimgl/[imgui, glfw, opengl]

import icons

export enumutils

type
  Element* = enum
    Fire, Earth, Air, Water

  ActionKind* = enum
    Resize, Create

  Circle* = object
    pos*: ImVec2
    radius*: float32
    hovered*: bool


  Action* = ref object
    pos*: ImVec2
    case kind*: ActionKind
    of Resize:
      prevRadius*: float32
    else: discard

  App* = ref object
    win*: GLFWWindow
    font*: ptr ImFont
    prefs*: Prefs
    cache*: PObjectType # Settings cache
    config*: PObjectType # Prefs table

    # Variables
    
    # Counter
    counter*: int
    # Temperature Converter
    celsius*, fahrenheit*: string
    # Flight Booker
    currentFlight*: int
    startDate*, returnDate*: string
    # Timer
    duration*, startTime*, curTime*: float32
    # CRUD
    filterBuf*, nameBuf*, surnameBuf*: string
    currentName*: int
    namesData*: seq[tuple[name, surname: string]]
    # Circle Drawer
    actionsStack*: seq[Action]
    diameter*: int32
    currentCirc*, currentAction*: int
    circlesList*: seq[Circle]

    # Basic tab variables
    num*: int32
    elem*: Element
    checked*: bool
    angle*: float32
    double*: float64
    sliderInt*: int32
    basicCounter*, clicked*: int
    dragInt*, dragInt2*: int32
    color3*: array[3, float32]
    color4*: array[4, float32]
    float3*: array[3, float32]
    buffer*, hintBuffer*: string
    floatNum*, scientFloat*: float32
    dragFloat*, dragFloat2*: float32
    sliderFloat*, sliderFloat2*: float32
    radioCurrent*, comboCurrent*, listCurrent*: int32

  SettingTypes* = enum
    Input # Input text
    Check # Checkbox
    Slider # Int slider
    FSlider # Float slider
    Spin # Int spin
    FSpin # Float spin
    Combo
    Radio # Radio button
    Color3 # Color edit RGB
    Color4 # Color edit RGBA
    Section

  ImageData* = tuple[image: seq[byte], width, height: int]

proc newCircle*(pos: ImVec2, radius: float32): Circle = 
  Circle(pos: pos, radius: radius)

proc newResizeAction*(pos: ImVec2, prevRadius: float32): Action = 
  Action(pos: pos, kind: Resize, prevRadius: prevRadius)

proc newCreateAction*(pos: ImVec2): Action = 
  Action(pos: pos, kind: Create)

# To be able to print large holey enums
macro enumFullRange*(a: typed): untyped =
  newNimNode(nnkBracket).add(a.getType[1][1..^1])

iterator items*(T: typedesc[HoleyEnum]): T =
  for x in T.enumFullRange:
    yield x

proc getEnumValues*[T: enum](): seq[string] = 
  for i in T:
    result.add $i

proc parseEnum*[T: enum](node: PrefsNode): T = 
  case node.kind:
  of PInt:
    result = T(node.getInt())
  of PString:
    try:
      result = parseEnum[T](node.getString().capitalizeAscii())
    except:
      raise newException(ValueError, &"Invalid enum value {node.getString()} for {$T}. Valid values are {$getEnumValues[T]()}")
  else:
    raise newException(ValueError, &"Invalid kind {node.kind} for an enum. Valid kinds are PInt or PString")

proc makeFlags*[T: enum](flags: varargs[T]): T =
  ## Mix multiple flags of a specific enum
  var res = 0
  for x in flags:
    res = res or int(x)

  result = T res

proc getFlags*[T: enum](node: PrefsNode): T = 
  ## Similar to parseEnum but this one mixes multiple enum values if node.kind == PSeq
  case node.kind:
  of PString, PInt:
    result = parseEnum[T](node)
  of PSeq:
    var flags: seq[T]
    for i in node.getSeq():
      flags.add parseEnum[T](i)

    result = makeFlags(flags)
  else:
    raise newException(ValueError, "Invalid kind {node.kind} for {$T} enum. Valid kinds are PInt, PString or PSeq") 

proc parseColor3*(node: PrefsNode): array[3, float32] = 
  case node.kind
  of PString:
    let color = node.getString().parseHtmlColor()
    result[0] = color.r
    result[1] = color.g
    result[2] = color.b 
  of PSeq:
    result[0] = node[0].getFloat()
    result[1] = node[1].getFloat()
    result[2] = node[2].getFloat()
  else:
    raise newException(ValueError, &"Invalid color RGB {node}")

proc parseColor4*(node: PrefsNode): array[4, float32] = 
  case node.kind
  of PString:
    let color = node.getString().replace("#").parseHexAlpha()
    result[0] = color.r
    result[1] = color.g
    result[2] = color.b 
    result[3] = color.a
  of PSeq:
    result[0] = node[0].getFloat()
    result[1] = node[1].getFloat()
    result[2] = node[2].getFloat()
    result[3] = node[3].getFloat()
  else:
    raise newException(ValueError, &"Invalid color RGBA {node}")

proc igVec2*(x, y: float32): ImVec2 = ImVec2(x: x, y: y)

proc igVec4*(x, y, z, w: float32): ImVec4 = ImVec4(x: x, y: y, z: z, w: w)

proc igVec4*(color: Color): ImVec4 = ImVec4(x: color.r, y: color.g, z: color.b, w: color.a)

proc igHSV*(h, s, v: float32, a: float32 = 1f): ImColor = 
  result.addr.hSVNonUDT(h, s, v, a)

proc igGetContentRegionAvail*(): ImVec2 = 
  igGetContentRegionAvailNonUDT(result.addr)

proc igGetWindowContentRegionMax*(): ImVec2 = 
  igGetWindowContentRegionMaxNonUDT(result.addr)

proc igGetWindowPos*(): ImVec2 = 
  igGetWindowPosNonUDT(result.addr)

proc igGetItemRectMin*(): ImVec2 = 
  igGetItemRectMinNonUDT(result.addr)

proc igGetItemRectMax*(): ImVec2 = 
  igGetItemRectMaxNonUDT(result.addr)

proc igCalcTextSize*(text: cstring, text_end: cstring = nil, hide_text_after_double_hash: bool = false, wrap_width: float32 = -1.0'f32): ImVec2 = 
  igCalcTextSizeNonUDT(result.addr, text, text_end, hide_text_after_double_hash, wrap_width)

proc getCenter*(self: ptr ImGuiViewport): ImVec2 = 
  getCenterNonUDT(result.addr, self)

proc centerCursorX*(width: float32, align: float = 0.5f, availWidth: float32 = igGetContentRegionAvail().x) = 
  # let style = igGetStyle()
  
  # size.x += style.framePadding.x * 2

  let off = (availWidth - width) * align
  
  if off > 0:
    igSetCursorPosX(igGetCursorPosX() + off)


proc initGLFWImage*(data: ImageData): GLFWImage = 
  result = GLFWImage(pixels: cast[ptr cuchar](data.image[0].unsafeAddr), width: int32 data.width, height: int32 data.height)

proc readImageFromMemory*(data: string): ImageData = 
  var channels: int
  result.image = stbi.loadFromMemory(cast[seq[byte]](data), result.width, result.height, channels, stbi.Default)

proc loadTextureFromData*(data: var ImageData, outTexture: var GLuint) =
    # Create a OpenGL texture identifier
    glGenTextures(1, outTexture.addr)
    glBindTexture(GL_TEXTURE_2D, outTexture)

    # Setup filtering parameters for display
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR.GLint)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE.GLint) # This is required on WebGL for non power-of-two textures
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE.GLint) # Same

    # Upload pixels into texture
    # if defined(GL_UNPACK_ROW_LENGTH) && !defined(__EMSCRIPTEN__)
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0)

    glTexImage2D(GL_TEXTURE_2D, GLint 0, GL_RGBA.GLint, GLsizei data.width, GLsizei data.height, GLint 0, GL_RGBA, GL_UNSIGNED_BYTE, data.image[0].addr)

proc igHelpMarker*(text: string) = 
  igTextDisabled("(?)")
  if igIsItemHovered():
    igBeginTooltip()
    igPushTextWrapPos(igGetFontSize() * 35.0)
    igTextUnformatted(text)
    igPopTextWrapPos()
    igEndTooltip()

proc newImFontConfig*(mergeMode = false): ImFontConfig =
  result.fontDataOwnedByAtlas = true
  result.fontNo = 0
  result.oversampleH = 3
  result.oversampleV = 1
  result.pixelSnapH = true
  result.glyphMaxAdvanceX = float.high
  result.rasterizerMultiply = 1.0
  result.mergeMode = mergeMode

proc igAddFontFromMemoryTTF*(self: ptr ImFontAtlas, data: string, size_pixels: float32, font_cfg: ptr ImFontConfig = nil, glyph_ranges: ptr ImWchar = nil): ptr ImFont {.discardable.} = 
  let igFontStr = cast[cstring](igMemAlloc(data.len.uint))
  igFontStr[0].unsafeAddr.copyMem(data[0].unsafeAddr, data.len)
  result = self.addFontFromMemoryTTF(igFontStr, data.len.int32, sizePixels, font_cfg, glyph_ranges)

proc openURL*(url: string) = 
  when defined(MacOS) or defined(MacOSX):
    discard execShellCmd("open " & url)
  elif defined(Windows):
    discard execShellCmd("start " & url)
  else:
    discard execShellCmd("xdg-open " & url)

proc igAddUnderLine*(col: uint32) = 
  var 
    min = igGetItemRectMin()
    max = igGetItemRectMax()

  min.y = max.y
  igGetWindowDrawList().addLine(min, max, col, 1f)

proc igTextURL*(name: string, url: string, sameLineBefore, sameLineAfter: bool = true) = 
  let style = igGetStyle()
  if sameLineBefore: igSameLine(0f, style.itemInnerSpacing.x)

  igPushStyleColor(ImGuiCol.Text, igGetColorU32(CheckMark))
  igText(name)
  igPopStyleColor()

  if igIsItemHovered():
    if igIsMouseClicked(ImGuiMouseButton.Left):
      url.openURL()

    igAddUnderLine(igGetColorU32(CheckMark))
    igSetTooltip(url & " " & FA_ExternalLink)

  if sameLineAfter: igSameLine(0f, style.itemInnerSpacing.x)

proc removeInside*(text: string, open, close: char): tuple[text: string, inside: string] = 
  ## Remove the characters inside open..close from text, return text and the removed characters
  runnableExamples:
    assert "Hello<World>".removeInside('<', '>') == ("Hello", "World")
  var inside = false
  for i in text:
    if i == open:
      inside = true
      continue

    if not inside:
      result.text.add i

    if i == close:
      inside = false

    if inside:
      result.inside.add i

proc initconfig*(app: var App, settings: PrefsNode, parent: string = "") = 
  # Add the preferences with the values defined in config["settings"]
  for name, data in settings: 
    let settingType = parseEnum[SettingTypes](data["type"])
    if settingType == Section:
      app.initConfig(data["content"], parent = name)  
    elif parent.len > 0:
      if not app.prefs.hasPath(parent, name):
        app.prefs[parent, name] = data["default"]
    else:
      if name notin app.prefs:
        app.prefs[name] = data["default"]

proc validateDate*(input, format: string): tuple[success: bool, date: DateTime] = 
  try:
    result.date = input.parse(format)
    result.success = true
  except TimeParseError:
    result.success = false

proc newString*(lenght: int, default: string): string = 
  result = newString(lenght)
  result[0..default.high] = default

proc cleanString*(str: string): string = 
  if '\0' in str:
    str[0..<str.find('\0')].strip()
  else:
    str.strip()

proc igPushDisabled*() = 
  igPushItemFlag(ImGuiItemFlags.Disabled, true)
  igPushStyleVar(ImGuiStyleVar.Alpha, igGetStyle().alpha * 0.6)

proc igPopDisabled*() = 
  igPopItemFlag()
  igPopStyleVar()
