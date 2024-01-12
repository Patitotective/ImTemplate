import std/[typetraits, threadpool, strutils, tables, macros, os]
import kdl, kdl/prefs
import stb_image/read as stbi
import nimgl/[imgui, glfw, opengl]
import tinydialogs

import types

proc makeFlags*[T: enum](flags: varargs[T]): T =
  ## Mix multiple flags of a specific enum
  var res = 0
  for x in flags:
    res = res or int(x)

  result = T res

proc parseMakeFlags*[T: enum](flags: seq[string]): T =
  var res = 0
  for x in flags:
    res = res or int parseEnum[T](x)

  result = T res

proc pushString*(str: var string, val: string) =
  if val.len < str.len:
    str[0..val.len] = val & '\0'
  else:
    str[0..str.high] = val[0..str.high]

proc newString*(length: Natural, default: string): string =
  result = newString(length)
  result.pushString(default)

proc cleanString*(str: string): string =
  for e, c in str:
    if c == '\0':
      return str[0..<e].strip()

  str.strip()

proc updatePrefs*(app: var App) =
  # Update values depending on the preferences here
  # This procedure is also called at the start of the app
  echo "Updating preferences..."

proc res*(app: App, path: string): string =
  when defined(release):
    app.resources[path]
  else:
    assert path.fileExists(), path
    readFile(path)

proc cmpIgnoreStyle(a, b: openarray[char], ignoreChars = {'_', '-'}): int =
  let aLen = a.len
  let bLen = b.len
  var i = 0
  var j = 0

  while true:
    while i < aLen and a[i] in ignoreChars: inc i
    while j < bLen and b[j] in ignoreChars: inc j
    let aa = if i < aLen: toLowerAscii(a[i]) else: '\0'
    let bb = if j < bLen: toLowerAscii(b[j]) else: '\0'
    result = ord(aa) - ord(bb)
    if result != 0: return result
    # the characters are identical:
    if i >= aLen:
      # both cursors at the end:
      if j >= bLen: return 0
      # not yet at the end of 'b':
      return -1
    elif j >= bLen:
      return 1
    inc i
    inc j

proc eqIdent*(v, a: openarray[char], ignoreChars = {'_', '-'}): bool = cmpIgnoreStyle(v, a, ignoreChars) == 0

proc `+`*(vec1, vec2: ImVec2): ImVec2 =
  ImVec2(x: vec1.x + vec2.x, y: vec1.y + vec2.y)

proc `-`*(vec1, vec2: ImVec2): ImVec2 =
  ImVec2(x: vec1.x - vec2.x, y: vec1.y - vec2.y)

proc `*`*(vec1, vec2: ImVec2): ImVec2 =
  ImVec2(x: vec1.x * vec2.x, y: vec1.y * vec2.y)

proc `/`*(vec1, vec2: ImVec2): ImVec2 =
  ImVec2(x: vec1.x / vec2.x, y: vec1.y / vec2.y)

proc `+`*(vec: ImVec2, val: float32): ImVec2 =
  ImVec2(x: vec.x + val, y: vec.y + val)

proc `-`*(vec: ImVec2, val: float32): ImVec2 =
  ImVec2(x: vec.x - val, y: vec.y - val)

proc `*`*(vec: ImVec2, val: float32): ImVec2 =
  ImVec2(x: vec.x * val, y: vec.y * val)

proc `/`*(vec: ImVec2, val: float32): ImVec2 =
  ImVec2(x: vec.x / val, y: vec.y / val)

proc `+=`*(vec1: var ImVec2, vec2: ImVec2) =
  vec1.x += vec2.x
  vec1.y += vec2.y

proc `-=`*(vec1: var ImVec2, vec2: ImVec2) =
  vec1.x -= vec2.x
  vec1.y -= vec2.y

proc `*=`*(vec1: var ImVec2, vec2: ImVec2) =
  vec1.x *= vec2.x
  vec1.y *= vec2.y

proc `/=`*(vec1: var ImVec2, vec2: ImVec2) =
  vec1.x /= vec2.x
  vec1.y /= vec2.y

proc igVec2*(x, y: float32): ImVec2 = ImVec2(x: x, y: y)

proc igVec4*(x, y, z, w: float32): ImVec4 = ImVec4(x: x, y: y, z: z, w: w)

proc igHSV*(h, s, v: float32, a: float32 = 1f): ImColor =
  result.addr.hSVNonUDT(h, s, v, a)

proc igGetContentRegionAvail*(): ImVec2 =
  igGetContentRegionAvailNonUDT(result.addr)

proc igGetWindowPos*(): ImVec2 =
  igGetWindowPosNonUDT(result.addr)

proc igCalcTextSize*(text: cstring, text_end: cstring = nil, hide_text_after_double_hash: bool = false, wrap_width: float32 = -1.0'f32): ImVec2 =
  igCalcTextSizeNonUDT(result.addr, text, text_end, hide_text_after_double_hash, wrap_width)

proc igCalcFrameSize*(text: string): ImVec2 =
  igCalcTextSize(cstring text) + (igGetStyle().framePadding * 2)

proc igColorConvertU32ToFloat4*(color: uint32): ImVec4 =
  igColorConvertU32ToFloat4NonUDT(result.addr, color)

proc getCenter*(self: ptr ImGuiViewport): ImVec2 =
  getCenterNonUDT(result.addr, self)

proc igCenterCursorX*(width: float32, align: float = 0.5f, avail = igGetContentRegionAvail().x) =
  let off = (avail - width) * align

  if off > 0:
    igSetCursorPosX(igGetCursorPosX() + off)

proc igCenterCursorY*(height: float32, align: float = 0.5f, avail = igGetContentRegionAvail().y) =
  let off = (avail - height) * align

  if off > 0:
    igSetCursorPosY(igGetCursorPosY() + off)

proc igCenterCursor*(size: ImVec2, alignX: float = 0.5f, alignY: float = 0.5f, avail = igGetContentRegionAvail()) =
  igCenterCursorX(size.x, alignX, avail.x)
  igCenterCursorY(size.y, alignY, avail.y)

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
  let igFontStr = cast[cstring](igMemAlloc(uint data.len))
  igFontStr[0].unsafeAddr.copyMem(data[0].unsafeAddr, data.len)
  result = self.addFontFromMemoryTTF(igFontStr, int32 data.len, sizePixels, font_cfg, glyph_ranges)

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

macro checkFlowVarsReady*(app: App, fields: varargs[untyped]): bool =
  # This macro just converts app.checkFlowVarsReady(field1, field2) to
  # (app.field1.isNil or app.field1.isReady) and (app.field2.isNil or app.field2.isReady)
  for field in fields:
    let cond = quote do:
      (`app`.`field`.isNil or `app`.`field`.isReady)

    if result.kind == nnkEmpty:
      result = cond
    else:
      result = infix(result, "and", cond)

proc checkSettingsFlowVarsReadyImpl(obj: object): bool =
  # This macro just converts app.checkFlowVarsReady(field1, field2) to
  # (app.field1.isNil or app.field1.isReady) and (app.field2.isNil or app.field2.isReady)
  result = true
  for fieldName, field in obj.fieldPairs:
    case field.kind
    of stFile:
      if not field.fileCache.flowvar.isNil and not field.fileCache.flowvar.isReady:
        return false
    of stFiles:
      if not field.filesCache.flowvar.isNil and not field.filesCache.flowvar.isReady:
        return false
    of stFolder:
      if not field.folderCache.flowvar.isNil and not field.folderCache.flowvar.isReady:
        return false
    of stSection:
      when field.content is object:
        if not checkSettingsFlowVarsReadyImpl(field.content):
          return false
      else:
        raise newException(ValueError, $fieldName & " must be an object, got " & $typeof(field.content))
    else: discard

proc checkFlowVarsReady*(s: Settings): bool =
  # Converts app.checkFlowVarsReady(field1, field2) to
  # (app.field1.isNil or app.field1.isReady) and (app.field2.isNil or app.field2.isReady)
  checkSettingsFlowVarsReadyImpl(s)

proc initCacheSettingsObj(a: var object)
proc saveSettingsObj(a: var object)

proc valToCache*(s: var Setting) =
  case s.kind
  of stInput:
    s.inputCache = s.inputVal
  of stCombo:
    s.comboCache = s.comboVal
  of stCheck:
    s.checkCache = s.checkVal
  of stSlider:
    s.sliderCache = s.sliderVal
  of stFSlider:
    s.fsliderCache = s.fsliderVal
  of stSpin:
    s.spinCache = s.spinVal
  of stFSpin:
    s.fspinCache = s.fspinVal
  of stRadio:
    s.radioCache = s.radioVal
  of stSection:
    when s.content is object:
      initCacheSettingsObj(s.content)
    else:
      raise newException(ValueError, $s & " must be an object, got " & $typeof(s.content))
  of stRGB:
    s.rgbCache = s.rgbVal
  of stRGBA:
    s.rgbaCache = s.rgbaVal
  of stFile:
    s.fileCache.val = s.fileVal
  of stFiles:
    s.filesCache.val = s.filesVal
  of stFolder:
    s.folderCache.val = s.folderVal

proc cacheToVal*(s: var Setting) =
  case s.kind
  of stInput:
    s.inputVal = s.inputCache
  of stCombo:
    s.comboVal = s.comboCache
  of stCheck:
    s.checkVal = s.checkCache
  of stSlider:
    s.sliderVal = s.sliderCache
  of stFSlider:
    s.fsliderVal = s.fsliderCache
  of stSpin:
    s.spinVal = s.spinCache
  of stFSpin:
    s.fspinVal = s.fspinCache
  of stRadio:
    s.radioVal = s.radioCache
  of stSection:
    when s.content is object:
      saveSettingsObj(s.content)
    else:
      raise newException(ValueError, $s & " must be an object, got " & $typeof(s.content))
  of stRGB:
    s.rgbVal = s.rgbCache
  of stRGBA:
    s.rgbaVal = s.rgbaCache
  of stFile:
    s.fileVal = s.fileCache.val
  of stFiles:
    s.filesVal = s.filesCache.val
  of stFolder:
    s.folderVal = s.folderCache.val

proc cacheToDefault*(s: var Setting) =
  case s.kind
  of stInput:
    s.inputCache = s.inputDefault
  of stCombo:
    s.comboCache = s.comboDefault
  of stCheck:
    s.checkCache = s.checkDefault
  of stSlider:
    s.sliderCache = s.sliderDefault
  of stFSlider:
    s.fsliderCache = s.fsliderDefault
  of stSpin:
    s.spinCache = s.spinDefault
  of stFSpin:
    s.fspinCache = s.fspinDefault
  of stRadio:
    s.radioCache = s.radioDefault
  of stSection:
    when s.content is object:
      initCacheSettingsObj(s.content)
    else:
      raise newException(ValueError, $s & " must be an object, got " & $typeof(s.content))
  of stRGB:
    s.rgbCache = s.rgbDefault
  of stRGBA:
    s.rgbaCache = s.rgbaDefault
  of stFile:
    s.fileCache.val = s.fileDefault
  of stFiles:
    s.filesCache.val = s.filesDefault
  of stFolder:
    s.folderCache.val = s.folderDefault

proc saveSettingsObj(a: var object) =
  for field in a.fields:
    field.cacheToVal()

proc initCacheSettingsObj(a: var object) =
  for field in a.fields:
    field.valToCache()

proc initCache*(a: var Settings) =
  ## Sets all a's cache values to the current values (`inputCache = inputVal`)
  initCacheSettingsObj(a)

proc save*(a: var Settings) =
  ## Sets all a's current values to the cache values (`inputVal = inputCache`)
  saveSettingsObj(a)

proc areThreadsFinished*(app: App): bool =
  app.checkFlowVarsReady(messageBoxResult) and app.prefs[settings].checkFlowVarsReady()

proc drawBlockDialogModal*(app: App) =
  ## This modal is meant to block the app until all the FlowVar(s) are nil or ready
  var center: ImVec2
  getCenterNonUDT(center.addr, igGetMainViewport())
  igSetNextWindowPos(center, Always, igVec2(0.5f, 0.5f))

  if igBeginPopupModal(cstring "External Dialog###blockdialog", flags = makeFlags(ImGuiWindowFlags.NoResize)):
    igText("An external dialog is open, \nclose it to continue using the app.")

    # If all spawned threads are finished we can close this popup
    if app.areThreadsFinished():
      igCloseCurrentPopup()
    else: # Do not allow the window to be closed unless the threads are finished
      if app.win.windowShouldClose():
        app.win.setWindowShouldClose(false)
        spawn notifyPopup(app.config.name, "Close the external dialogs before closing the app", IconType.Error)

    igEndPopup()


