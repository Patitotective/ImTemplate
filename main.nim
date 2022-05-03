import std/[strutils, os]

when defined(release):
  import assets
import imstyle
import niprefs
import nimgl/[opengl, glfw]
import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]

import src/[utils, prefsmodal, icons]

const configPath = "config.niprefs"

proc getCacheDir(app: App): string = 
  getCacheDir(app.config["name"].getString())

proc getData(path: string): string = 
  when defined(release):
    path.getAsset()
  else:
    path.readFile()

proc getData(node: PrefsNode): string = 
  node.getString().getData()

proc drawAboutModal(app: App) = 
  let
    style = igGetStyle()
    drawList = igGetWindowDrawList()
  var center: ImVec2
  getCenterNonUDT(center.addr, igGetMainViewport())
  igSetNextWindowPos(center, Always, igVec2(0.5f, 0.5f))

  let unusedOpen = true
  if igBeginPopupModal("About " & app.config["name"].getString(), unusedOpen.unsafeAddr, flags = makeFlags(ImGuiWindowFlags.NoResize)):

    # Display icon image
    var
      texture: GLuint
      image = app.config["iconPath"].getData().readImageFromMemory()

    image.loadTextureFromData(texture)

    igImage(cast[ptr ImTextureID](texture), igVec2(64, 64)) # Or igVec2(image.width.float32, image.height.float32)
    if igIsItemHovered():
      if igIsMouseClicked(ImGuiMouseButton.Left):
        app.config["website"].getString().openURL()

      igSetTooltip(app.config["website"].getString() & " " & FA_ExternalLink)

    igSameLine()
    
    igPushTextWrapPos(250)
    igTextWrapped(app.config["comment"].getString())
    igPopTextWrapPos()

    igSpacing()

    igSelectable("Credits", true, makeFlags(ImGuiSelectableFlags.DontClosePopups))
    if igBeginChild("##credits", igVec2(0, 75)):
      for author in app.config["authors"]:
        let (name, url) = block: 
          let (name,  url) = author.getString().removeInside('<', '>')
          (name.strip(),  url.strip())

        if igSelectable(name) and url.len > 0:
            url.openURL()
        if igIsItemHovered() and url.len > 0:
          igSetTooltip(url & " " & FA_ExternalLink)
      igEndChild()

    igText(app.config["version"].getString())

    igEndPopup()

proc drawMenuBar(app: var App) =
  var openAbout, openPrefs = false

  if igBeginMenuBar():
    if igBeginMenu("File"):
      igMenuItem("Preferences " & FA_Cog, "Ctrl+P", openPrefs.addr)
      if igMenuItem("Quit " & FA_Times, "Ctrl+Q"):
        app.win.setWindowShouldClose(true)
      igEndMenu()

    if igBeginMenu("Edit"):
      if igMenuItem("Reset Counter " & FA_Refresh, "Ctrl+R"):
        app.counter = 0
      if igMenuItem("Paste " & FA_Clipboard, "Ctrl+V"):
        echo "paste"

      igEndMenu()

    if igBeginMenu("About"):
      if igMenuItem("Website " & FA_ExternalLink):
        app.config["website"].getString().openURL()

      igMenuItem("About " & app.config["name"].getString(), shortcut = nil, p_selected = openAbout.addr)

      igEndMenu() 

    igEndMenuBar()

  # See https://github.com/ocornut/imgui/issues/331#issuecomment-751372071
  if openPrefs:
    igOpenPopup("Preferences")
  if openAbout:
    igOpenPopup("About " & app.config["name"].getString())

  # These modals will only get drawn when igOpenPopup(name) are called, respectly
  app.drawAboutModal()
  app.drawPrefsModal()

proc drawMain(app: var App) = # Draw the main window
  let viewport = igGetMainViewport()
  igSetNextWindowPos(viewport.pos)
  igSetNextWindowSize(viewport.size)

  igBegin(app.config["name"].getString(), flags = makeFlags(ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoSavedSettings, NoMove, NoDecoration, MenuBar))

  app.drawMenuBar()

  igText(app.prefs["input"].getString())

  igSliderFloat("float", app.somefloat.addr, 0.0f, 1.0f)

  if igButton("Button " & FA_HandPointerO):
    inc app.counter
  igSameLine()
  igText("counter = %d", app.counter)

  igText(FA_Info & " Application average %.3f ms/frame (%.1f FPS)", 1000.0f / igGetIO().framerate, igGetIO().framerate)

  igEnd()

proc display(app: var App) = # Called in the main loop
  glfwPollEvents()

  igOpenGL3NewFrame()
  igGlfwNewFrame()
  igNewFrame()

  app.drawMain()

  igRender()

  let bgColor = igGetStyle().colors[WindowBg.ord]
  glClearColor(bgColor.x, bgColor.y, bgColor.z, bgColor.w)
  glClear(GL_COLOR_BUFFER_BIT)

  igOpenGL3RenderDrawData(igGetDrawData())  

proc initWindow(app: var App) = 
  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE)
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWResizable, GLFW_TRUE)
  
  app.win = glfwCreateWindow(
    app.prefs["win/width"].getInt().int32, 
    app.prefs["win/height"].getInt().int32, 
    app.config["name"].getString(), 
    icon = false # Do not use default icon
  )

  if app.win == nil:
    quit(-1)

  # Set the window icon
  var icon = initGLFWImage(app.config["iconPath"].getData().readImageFromMemory())
  app.win.setWindowIcon(1, icon.addr)

  app.win.setWindowSizeLimits(app.config["minSize"][0].getInt().int32, app.config["minSize"][1].getInt().int32, GLFW_DONT_CARE, GLFW_DONT_CARE) # minWidth, minHeight, maxWidth, maxHeight
  app.win.setWindowPos(app.prefs["win/x"].getInt().int32, app.prefs["win/y"].getInt().int32)

  app.win.makeContextCurrent()

proc initPrefs(app: var App) = 
  app.prefs = toPrefs({
    win: {
      x: 0,
      y: 0,
      width: 500,
      height: 500
    }
  }).initPrefs((app.getCacheDir() / app.config["name"].getString()).changeFileExt("niprefs"))

proc initconfig(app: var App, settings: PrefsNode, parent: string = "") = 
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

proc initApp(config: PObjectType): App = 
  result = App(config: config, somefloat: 0.5f, counter: 2)
  result.initPrefs()
  result.initConfig(result.config["settings"])

proc terminate(app: var App) = 
  var x, y, width, height: int32

  app.win.getWindowPos(x.addr, y.addr)
  app.win.getWindowSize(width.addr, height.addr)
  
  app.prefs["win/x"] = x
  app.prefs["win/y"] = y
  app.prefs["win/width"] = width
  app.prefs["win/height"] = height

  app.win.destroyWindow()

proc main() =
  var app = initApp(configPath.getData().parsePrefs())

  doAssert glfwInit()

  app.initWindow()

  doAssert glInit()

  let context = igCreateContext()
  let io = igGetIO()
  io.iniFilename = nil # Disable ini file

  app.font = io.fonts.igAddFontFromMemoryTTF(app.config["fontPath"].getData(), app.config["fontSize"].getFloat())

  # Add ForkAwesome icon font
  var
    config = utils.newImFontConfig(mergeMode = true)
    ranges = [FA_Min.uint16,  FA_Max.uint16]

  io.fonts.igAddFontFromMemoryTTF(app.config["iconFontPath"].getData(), app.config["fontSize"].getFloat(), config.addr, ranges[0].addr)

  doAssert igGlfwInitForOpenGL(app.win, true)
  doAssert igOpenGL3Init()

  setIgStyle(app.config["stylePath"].getData().parsePrefs()) # Load application style

  while not app.win.windowShouldClose:
    app.display()
    app.win.swapBuffers()

  igOpenGL3Shutdown()
  igGlfwShutdown()
  context.igDestroyContext()

  app.terminate()
  
  glfwTerminate()

when isMainModule:
  main()
