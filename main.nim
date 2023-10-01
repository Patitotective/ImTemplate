import std/[strutils, os]

import imstyle
import openurl
import tinydialogs
import kdl, kdl/prefs
import nimgl/[opengl, glfw]
import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]

import src/[settingsmodal, utils, types, icons]
when defined(release):
  import resources

# TODO make configuration or at least settings inside the code and nto in the configuration file
# TODO be able to reset single preferences to their default value

# const configPath {.strdefine.} = "config.kdl"

proc getConfigDir(app: App): string =
  getConfigDir() / app.config.name

proc drawAboutModal(app: App) =
  var center: ImVec2
  getCenterNonUDT(center.addr, igGetMainViewport())
  igSetNextWindowPos(center, Always, igVec2(0.5f, 0.5f))

  let unusedOpen = true # Passing this parameter creates a close button
  if igBeginPopupModal(cstring "About " & app.config.name & "###about", unusedOpen.unsafeAddr, flags = makeFlags(ImGuiWindowFlags.NoResize)):
    # Display icon image
    var texture: GLuint
    var image = app.res(app.config.iconPath).readImageFromMemory()

    image.loadTextureFromData(texture)

    igImage(cast[ptr ImTextureID](texture), igVec2(64, 64)) # Or igVec2(image.width.float32, image.height.float32)
    if igIsItemHovered() and app.config.website.len > 0:
      igSetTooltip(cstring app.config.website & " " & FA_ExternalLink)

      if igIsMouseClicked(ImGuiMouseButton.Left):
        app.config.website.openURL()

    igSameLine()

    igPushTextWrapPos(250)
    igTextWrapped(cstring app.config.comment)
    igPopTextWrapPos()

    igSpacing()

    # To make it not clickable
    igPushItemFlag(ImGuiItemFlags.Disabled, true)
    igSelectable("Credits", true, makeFlags(ImGuiSelectableFlags.DontClosePopups))
    igPopItemFlag()

    if igBeginChild("##credits", igVec2(0, 75)):
      for (author, url) in app.config.authors:
        if igSelectable(cstring author) and url.len > 0:
          url.openURL()
        if igIsItemHovered() and url.len > 0:
          igSetTooltip(cstring url & " " & FA_ExternalLink)

      igEndChild()

    igSpacing()

    igText(cstring app.config.version)

    igEndPopup()

proc drawMainMenuBar(app: var App) =
  var openAbout, openPrefs = false

  if igBeginMainMenuBar():
    if igBeginMenu("File"):
      igMenuItem("Settings " & FA_Cog, "Ctrl+P", openPrefs.addr)
      if igMenuItem("Quit " & FA_Times, "Ctrl+Q"):
        app.win.setWindowShouldClose(true)
      igEndMenu()

    if igBeginMenu("Edit"):
      if igMenuItem("Hello"):
        echo "Hello"

      igEndMenu()

    if igBeginMenu("About"):
      if igMenuItem("Website " & FA_ExternalLink, enabled = app.config.website.len > 0):
        app.config.website.openurl()

      igMenuItem(cstring "About " & app.config.name, shortcut = nil, p_selected = openAbout.addr)

      igEndMenu()

    igEndMainMenuBar()

  # See https://github.com/ocornut/imgui/issues/331#issuecomment-751372071
  if openPrefs:
    app.settingsmodal.cache = app.prefs[settings]
    igOpenPopup("Settings")
  if openAbout:
    igOpenPopup("###about")

  # These modals will only get drawn when igOpenPopup(name) are called, respectly
  app.drawAboutModal()
  app.drawSettingsmodal()

proc drawMain(app: var App) = # Draw the main window
  let viewport = igGetMainViewport()

  app.drawMainMenuBar()
  # Work area is the entire viewport minus main menu bar, task bars, etc.
  igSetNextWindowPos(viewport.workPos)
  igSetNextWindowSize(viewport.workSize)

  if igBegin(cstring app.config.name, flags = makeFlags(ImGuiWindowFlags.NoResize, NoDecoration, NoMove)):
    igText(FA_Info & " Application average %.3f ms/frame (%.1f FPS)", 1000f / igGetIO().framerate, igGetIO().framerate)

    if igButton("Click me"):
      notifyPopup(app.config.name, "Do not do that again", IconType.Warning)

    app.fonts[1].igPushFont()
    igText("Unicode fonts (NotoSansJP-Regular.otf)")
    igText("日本語がいいですね。 " & FA_SmileO)
    igPopFont()

  igEnd()

proc render(app: var App) = # Called in the main loop
  # Poll and handle events (inputs, window resize, etc.)
  glfwPollEvents() # Use glfwWaitEvents() to only draw on events (more efficient)

  # Start Dear ImGui Frame
  igOpenGL3NewFrame()
  igGlfwNewFrame()
  igNewFrame()

  # Draw application
  app.drawMain()

  # Render
  igRender()

  var displayW, displayH: int32
  let bgColor = igColorConvertU32ToFloat4(uint32 WindowBg)

  app.win.getFramebufferSize(displayW.addr, displayH.addr)
  glViewport(0, 0, displayW, displayH)
  glClearColor(bgColor.x, bgColor.y, bgColor.z, bgColor.w)
  glClear(GL_COLOR_BUFFER_BIT)

  igOpenGL3RenderDrawData(igGetDrawData())

  app.win.makeContextCurrent()
  app.win.swapBuffers()

proc initWindow(app: var App) =
  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE)
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWResizable, GLFW_TRUE)
  if app.prefs[maximized]:
    glfwWindowHint(GLFWMaximized, GLFW_TRUE)

  app.win = glfwCreateWindow(
    app.prefs[winsize].x,
    app.prefs[winsize].y,
    cstring app.config.name,
    icon = false # Do not use default icon
  )

  if app.win == nil:
    quit(-1)

  # Set the window icon
  var icon = initGLFWImage(app.res(app.config.iconPath).readImageFromMemory())
  app.win.setWindowIcon(1, icon.addr)

  if app.config.minSize.isSome:
    app.win.setWindowSizeLimits(app.config.minSize.get.x, app.config.minSize.get.y, GLFW_DONT_CARE, GLFW_DONT_CARE) # minWidth, minHeight, maxWidth, maxHeight

  # If negative pos, center the window in the first monitor
  if app.prefs[winpos].x < 0 or app.prefs[winpos].y < 0:
    var monitorX, monitorY, count, width, height: int32
    let monitors = glfwGetMonitors(count.addr)
    let videoMode = monitors[0].getVideoMode()

    monitors[0].getMonitorPos(monitorX.addr, monitorY.addr)
    app.win.getWindowSize(width.addr, height.addr)
    app.win.setWindowPos(
      monitorX + int32((videoMode.width - width) / 2),
      monitorY + int32((videoMode.height - height) / 2)
    )
  else:
    app.win.setWindowPos(app.prefs[winpos].x, app.prefs[winpos].y)

proc initPrefs(app: var App) =
  app.prefs = initKPrefs(
    path = (app.getConfigDir() / "prefs").changeFileExt("kdl"),
    default = Prefs(
      maximized: false,
      winpos: (-1i32, -1i32), # Negative numbers center the window
      winsize: (600i32, 650i32),
      settings: Settings(
        input: "Hello World",
        hintInput: "",
        checkbox: true,
        combo: Abc.C,
        radio: Abc.A,
        numbers: Numbers(
          slider: 4,
          floatSlider: 2.5,
          spin: 4,
          floatSpin: 3.14,
        ),
        colors: Colors(
          rgb: (1.0f, 0.0f, 0.2f),
          rgba: (0.4f, 0.7f, 0.0f, 0.5f),
        ),
      )
    )
  )

proc checkSettings(app: App) =
  for name, field in app.settingsmodal.cache.fieldPairs:
    var found = false
    for key, _ in app.config.settings:
      if key.eqIdent name:
        found = true
        break

    if not found:
      raise newException(KeyError, name & " is not in defined in the config file")

proc initApp(): App =
  when defined(release):
    result.resources = readResources()

  result.checkSettings()

  result.initPrefs()

template initFonts(app: var App) =
  # Merge ForkAwesome icon font
  let config = utils.newImFontConfig(mergeMode = true)
  let ranges = [uint16 FA_Min, uint16 FA_Max]

  for e, (path, size) in app.config.fonts.fonts:
    let glyph_ranges =
      case e
      of 1: io.fonts.getGlyphRangesJapanese()
      else: nil

    app.fonts[e] = io.fonts.igAddFontFromMemoryTTF(app.res(path), size, glyph_ranges = glyph_ranges)
    if app.config.fonts.iconFontPath.len > 0:
      io.fonts.igAddFontFromMemoryTTF(app.res(app.config.fonts.iconFontPath), size, config.unsafeAddr, ranges[0].unsafeAddr)

proc terminate(app: var App) =
  var x, y, width, height: int32

  app.win.getWindowPos(x.addr, y.addr)
  app.win.getWindowSize(width.addr, height.addr)

  app.prefs[winpos] = (x, y)
  app.prefs[winsize] = (width, height)
  app.prefs[maximized] = app.win.getWindowAttrib(GLFWMaximized) == GLFW_TRUE

  app.prefs.save()

proc main() =
  var app = initApp()

  # Setup Window
  doAssert glfwInit()
  app.initWindow()

  app.win.makeContextCurrent()
  glfwSwapInterval(1) # Enable vsync

  doAssert glInit()

  # Setup Dear ImGui context
  igCreateContext()
  let io = igGetIO()
  io.iniFilename = nil # Disable .ini config file

  # Setup Dear ImGui style using ImStyle
  app.res(app.config.stylePath).parseKdl().loadStyle().setCurrent()

  # Setup Platform/Renderer backends
  doAssert igGlfwInitForOpenGL(app.win, true)
  doAssert igOpenGL3Init()

  app.initFonts()

  # Main loop
  while not app.win.windowShouldClose:
    app.render()

  # Cleanup
  igOpenGL3Shutdown()
  igGlfwShutdown()

  igDestroyContext()

  app.terminate()
  app.win.destroyWindow()
  glfwTerminate()

when isMainModule:
  main()
