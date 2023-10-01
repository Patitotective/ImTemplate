import std/[typetraits, strutils, tables]
import kdl, kdl/prefs
import stb_image/read as stbi
import nimgl/[imgui, glfw, opengl]

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

proc newString*(length: int, default: string): string =
  result = newString(length)
  result.pushString(default)

proc cleanString*(str: string): string =
  if '\0' in str:
    str[0..<str.find('\0')].strip()
  else:
    str.strip()

proc updatePrefs*(app: var App) =
  # Update the values depending on the preferences here
  echo "Updating preferences..."

proc res*(app: App, path: string): string =
  when defined(release):
    app.resources[path]
  else:
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

# ImGui

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

template settingBefore() =
  igText(id); igSameLine(0, 0)
  igDummy(igVec2(maxLabelWidth - igCalcTextSize(id).x, 0))
  igSameLine(0, 0)

proc inputText(id: string, value: var string, flags = 0.ImGuiInputTextFlags) =
  let maxbuf = buffer.len + 1
  let buffer = newString(maxbuf, value)

  if igInputText(cstring id, cstring buffer, flags):
    value = buffer.cleanString()

