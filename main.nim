import std/[strutils, browsers]

import chroma
import imstyle
import niprefs
import nimgl/[opengl, glfw]
import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]

import src/[common, prefsmodal]

const
  configPath = "src/config.niprefs"
  bgColor = "#21232B".parseHtmlColor() # Background color of the GLFW window, same color as the ImGui window background so it looks more natural

proc drawAboutModal(app: var App) = 
  var center: ImVec2
  getCenterNonUDT(center.addr, igGetMainViewport())
  igSetNextWindowPos(center, Always, igVec2(0.5f, 0.5f))

  if igBeginPopupModal("About " & app.config["name"].getString(), flags = makeFlags(AlwaysAutoResize)):
    # Display icon image
    var
      texture: GLuint
      image = app.config["iconPath"].getString().readImage()
    image.loadTextureFromData(texture)
    
    igImage(cast[ptr ImTextureID](texture), igVec2(float32 image.width, float32 image.height))
    
    igSameLine()
    
    igBeginGroup()
    igText(app.config["name"].getString())
    igText(app.config["version"].getString())
    igEndGroup()

    var credits: seq[string]
    for i in app.config["authors"].getSeq():
      credits.add i.getString() # Add them as actual strings and not PString so they don't have quotes
    
    igTextWrapped("Credits: " & credits.join(", "))

    if igButton("Ok"):
      igCloseCurrentPopup()

    igEndPopup()

proc drawMenuBar(app: var App) =
  var openAbout, openPrefs = false

  if igBeginMenuBar():
    if igBeginMenu("File"):
      igMenuItem("Preferences", "Ctrl+P", openPrefs.addr)
      if igMenuItem("Quit", "Ctrl+Q"):
        app.win.setWindowShouldClose(true)
      igEndMenu()

    if igBeginMenu("Edit"):
      if igMenuItem("Reset Counter", "Ctrl+R"):
        app.counter = 0
      if igMenuItem("Paste", "Ctrl+V"):
        echo "paste"

      igEndMenu()

    if igBeginMenu("About"):
      if igMenuItem("Website"):
        app.config["website"].getString().openDefaultBrowser()

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
  igBegin(app.config["name"].getString(), flags = makeFlags(ImGuiWindowFlags.NoResize, NoMove, NoTitleBar, NoCollapse, MenuBar))
  igSetWindowPos(igVec2(0, 0), Always)

  app.drawMenuBar()

  igText("This is some useful text.")

  igSliderFloat("float", app.somefloat.addr, 0.0f, 1.0f)

  if igButton("Button"):
    inc app.counter
  igSameLine()
  igText("counter = %d", app.counter)

  igText("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / igGetIO().framerate, igGetIO().framerate)
  
  # Update ImGUi window size to fit GLFW window size
  var width, height: int32
  app.win.getWindowSize(width.addr, height.addr)
  igSetWindowSize(igVec2(width.float32, height.float32), Always)

  igEnd()

proc display(app: var App) = # Called in the main loop
  glfwPollEvents()

  igOpenGL3NewFrame()
  igGlfwNewFrame()
  igNewFrame()

  app.drawMain()

  igRender()

  glClearColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
  glClear(GL_COLOR_BUFFER_BIT)

  igOpenGL3RenderDrawData(igGetDrawData())  

proc initWindow(app: var App) = 
  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE)
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWResizable, GLFW_TRUE)
  
  app.win = glfwCreateWindow(
    500, 
    500, 
    app.config["name"].getString(), 
    icon = false # Do not use default icon
  )

  if app.win == nil:
    quit(-1)

  # Set the window icon
  var icon = initGLFWImage(app.config["iconPath"].getString().readImage())
  app.win.setWindowIcon(1, icon.addr)

  app.win.makeContextCurrent()

  app.win.setWindowSizeLimits(app.config["minSize"][0].getInt().int32, app.config["minSize"][1].getInt().int32, GLFW_DONT_CARE, GLFW_DONT_CARE) # minWidth, minHeight, maxWidth, maxHeight

proc initPrefs(app: var App) = 
  app.prefs = toPrefs({
    win: {
      x: 0,
      y: 0,
      width: 500,
      height: 500
    }
  }).initPrefs(app.config["prefsPath"].getString())

proc main() =
  var app = App(config: configPath.readPrefs())
  app.initPrefs()

  doAssert glfwInit()

  app.initWindow()

  doAssert glInit()

  let context = igCreateContext()
  let io = igGetIO()
  app.font = io.fonts.addFontFromFileTTF(app.config["fontPath"].getString(), app.config["fontSize"].getFloat())

  io.iniFilename = nil # Disable ini file

  doAssert igGlfwInitForOpenGL(app.win, true)
  doAssert igOpenGL3Init()

  setIgStyle(app.config["stylePath"].getString()) # Load application style
  # igStyleColorsCherry()
  # igStyleColorsClassic()
  # igStyleColorsLight()
  # igStyleColorsDark()

  while not app.win.windowShouldClose:
    app.display()
    app.win.swapBuffers()

  igOpenGL3Shutdown()
  igGlfwShutdown()
  context.igDestroyContext()

  app.win.destroyWindow()
  glfwTerminate()

when isMainModule:
  main()
