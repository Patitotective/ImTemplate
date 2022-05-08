import std/[strutils, strformat, strscans, times, os]

when defined(release):
  import assets
import chroma
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

proc drawCounter(app: var App) = 
  igText($app.counter)
  igSameLine()

  if igButton("Count " & FA_HandPointerO):
    inc app.counter

proc drawTempConverter(app: var App) = 
  if igInputText("Celsius", app.celsius, 32):
    if (let (valid, val) = scanTuple(app.celsius.cleanString(), "$i$."); valid):
      let fahr = $(val.float * (9 / 5) + 32)
      app.fahrenheit[0..app.fahrenheit.high] = fahr
  
  if igInputText("Fahrenheit", app.fahrenheit, 32):
    if (let (valid, val) = scanTuple(app.fahrenheit.cleanString(), "$i$."); valid):
      let cels = $((val - 32).float * (5 / 9))
      app.celsius[0..app.celsius.high] = cels

proc drawFlightBooker(app: var App) = 
  const flights = ["one-way flight", "return flight"]
  if igBeginCombo("##flight", flights[app.currentFlight]):
    for e, item in flights:
      if igSelectable(item, app.currentFlight == e):
        app.currentFlight = e
    igEndCombo()

  var startDateRed, returnDateRed, bookDisabled = false

  if not app.startDate.cleanString().validateDate("dd'.'mm'.'yyyy").success:
    startDateRed = true
    igPushStyleColor(FrameBg, "#A8232D".parseHtmlColor().igVec4())
  igInputText("Departure date", app.startDate, 32)
  if startDateRed:
    igPopStyleColor()

  if app.currentFlight == 0: # Meaning one-way flight
    igPushItemFlag(ImGuiItemFlags.Disabled, true)
    igPushStyleVar(ImGuiStyleVar.Alpha, igGetStyle().alpha * 0.6)

  if not app.returnDate.cleanString().validateDate("dd'.'mm'.'yyyy").success:
    returnDateRed = true
    igPushStyleColor(FrameBg, "#A8232D".parseHtmlColor().igVec4())
  igInputText("Return date", app.returnDate, 32)
  if returnDateRed:
    igPopStyleColor()

  if app.currentFlight == 0: # Meaning one-way flight
    igPopItemFlag()
    igPopStyleVar()

  if startDateRed or returnDateRed or 
    (app.currentFlight == 1 and (let (returnOK, returnDate) = app.returnDate.cleanString().validateDate("dd'.'mm'.'yyyy");
      let (startOk, startDate) = app.startDate.cleanString().validateDate("dd'.'mm'.'yyyy"); returnOk and startOk and returnDate < startDate)):
    bookDisabled = true
    igPushItemFlag(ImGuiItemFlags.Disabled, true)
    igPushStyleVar(ImGuiStyleVar.Alpha, igGetStyle().alpha * 0.6)

  if igButton("Book"):
    igOpenPopup("###booked")

  if bookDisabled:
    igPopItemFlag()
    igPopStyleVar()

  let unusedOpen = true
  igSetNextWindowPos(igGetMainViewport().getCenter(), Always, igVec2(0.5f, 0.5f))
  if igBeginPopupModal("Succesfully Booked###booked", unusedOpen.unsafeAddr, flags = makeFlags(ImGuiWindowFlags.NoResize, NoMove)):
    igPushTextWrapPos(250)
    if app.currentFlight == 0: # one-way flight
      igTextWrapped(&"You have booked a one-way flight on {app.startDate}")
    elif app.currentFlight == 1: # return flight
      igTextWrapped(&"You have booked a one-way flight departing on {app.startDate} and {app.returnDate}")
    igPopTextWrapPos()

    igEndPopup()

proc drawTimer(app: var App) = 
  if (app.curTime - app.startTime) < app.duration:
    app.curTime = igGetTime()

  echo &"{app.startTime=} {app.curTime=} {app.duration=}"

  igText("Elapsed Time: "); igSameLine()
  igProgressBar(1 / (app.duration / (app.curTime - app.startTime)))
  
  igText("%.1fs", app.curTime - app.startTime)
  
  igText("Duration: "); igSameLine()
  if igSliderFloat("##slider", app.duration.addr, 0f, 15f, ""):
    app.curTime = (app.curTime - app.startTime) + igGetTime()
    app.startTime = igGetTime()

  if igButton("Reset"):
    app.startTime = igGetTime()
    app.curTime = igGetTime()

proc drawCRUD(app: var App) = 
  igBeginGroup()
  igInputTextWithHint("##filterPrefix", "Filter prefix", app.filterBuf, 64)

  if igBeginListBox("##namesList"):
    for e, (name, surname) in app.namesData:
      if app.filterBuf.cleanString().len < 1 or surname.startsWith(app.filterBuf.cleanString()):
        if igSelectable(&"{surname}, {name}", app.currentName == e):
          app.currentName = e

    igEndListBox()

  igEndGroup(); igSameLine()
  igBeginGroup()
  igInputTextWithHint("##name", "Name", app.nameBuf, 32)
  igInputTextWithHint("##surname", "Surname", app.surnameBuf, 32)
  igEndGroup()

  if igButton("Create"):
    echo "create"
  igSameLine()
  if igButton("Update"):
    echo "update"
  igSameLine()
  if igButton("Delete"):
    app.namesData.del(app.currentName)

proc drawBasic(app: var App) = 
  # Widgets/Basic/Button
  if igButton("Button"):
    inc app.clicked
  if app.clicked mod 2 != 0: # Odd number
    igSameLine()
    igText("Thanks for clicking me!")

  # Widgets/Basic/Checkbox
  igCheckbox("checkbox", app.checked.addr)

  # Widgets/Basic/RadioButton
  igRadioButton("radio a", app.radioCurrent.addr, 0); igSameLine()
  igRadioButton("radio b", app.radioCurrent.addr, 1); igSameLine()
  igRadioButton("radio c", app.radioCurrent.addr, 2)

  # Color buttons, demonstrate using PushID() to add unique identifier in the ID stack, and changing style.
  # Widgets/Basic/Buttons (Colored)
  for i in 0..<7:
    if i > 0:
      igSameLine()
    igPushID(i.int32)
    igPushStyleColor(ImGuiCol.Button, igHSV(i / 7, 0.6f, 0.6f).value)
    igPushStyleColor(ImGuiCol.ButtonHovered, igHSV(i / 7, 0.7f, 0.7f).value)
    igPushStyleColor(ImGuiCol.ButtonActive, igHSV(i / 7, 0.8f, 0.8f).value)
    igButton("Click")
    igPopStyleColor(3)
    igPopID()

  # Use AlignTextToFramePadding() to align text baseline to the baseline of framed widgets elements
  # (otherwise a Text+SameLine+Button sequence will have the text a little too high by default!)
  # See 'Demo->Layout->Text Baseline Alignment' for details.
  igAlignTextToFramePadding()
  igText("Hold to repeat:")
  igSameLine()

  # Arrow buttons with Repeater
  # Widgets/Basic/Buttons (Repeating)
  igPushButtonRepeat(true)
  
  if igArrowButton("##left", ImGuiDir.Left): dec app.basicCounter
  igSameLine(0f, igGetStyle().itemInnerSpacing.x)
  if igArrowButton("##right", ImGuiDir.Right): inc app.basicCounter
  
  igPopButtonRepeat()
  
  igSameLine()
  igText($app.basicCounter)

  # Widgets/Basic/Tooltips
  igText("Hover over me")
  if igIsItemHovered():
    igSetTooltip("I am a tooltip")

  igSeparator()
  igLabelText("label", "Value")

  # Using the _simplified_ one-liner Combo() api here
  # See "Combo" section for examples of how to use the more flexible BeginCombo()/EndCombo() api.
  # Widgets/Basic/Combo
  const comboItems = ["AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIIIIII", "JJJJ", "KKKKKKK"]
  if igBeginCombo("combo", comboItems[app.comboCurrent]):
    for e, i in comboItems:
      if igSelectable(i, e == app.comboCurrent):
        app.comboCurrent = e

    igEndCombo()

  # To wire InputText() with std::string or any other custom string type,
  # see the "Text Input > Resize Callback" section of this demo, and the misc/cpp/imgui_stdlib.h file.
  # Widgets/Basic/InputText
  igInputText("input text", app.buffer, 128)
  igSameLine(); igHelpMarker("""
  USER:
  Hold SHIFT or use mouse to select text.
  CTRL+Left/Right to word jump.
  CTRL+A or double-click to select all.
  CTRL+X,CTRL+C,CTRL+V clipboard.
  CTRL+Z,CTRL+Y undo/redo.
  ESCAPE to revert.

  PROGRAMMER:
  You can use the ImGuiInputTextFlags_CallbackResize facility if you need to wire InputText() to a dynamic string type. See misc/cpp/imgui_stdlib.h for an example (this is not demonstrated in imgui_demo.cpp).
  """)

  igInputTextWithHint("input text (w/ hint)", "enter text here", app.hintBuffer, 128)

  # Widgets/Basic/InputInt, InputFloat
  igInputInt("input int", app.num.addr)
  igInputFloat("input float", app.floatNum.addr, 0f, 1f, "%.3f")
  igInputDouble("input double", app.double.addr, 0f, 1f, "%.8f")
  igInputFloat("input scientific", app.scientFloat.addr, 0f, 0f, "%e")
  igSameLine(); igHelpMarker("You can input value using the scientific notation, \ne.g. \"1e+8\" becomes \"100000000\".")
  igInputFloat3("input float3", app.float3)

  # Widgets/Basic/DragInt, DragFloat
  igDragInt("drag int", app.dragInt.addr, 1f)
  igSameLine(); igHelpMarker("""
  Click and drag to edit value.
  Hold SHIFT/ALT for faster/slower edit.
  Double-click or CTRL+click to input value.
  """)

  igDragInt("drag int 0..100", app.dragInt2.addr, 1f, 0, 100, "%d%%", ImGuiSliderFlags.AlwaysClamp)

  igDragFloat("drag float", app.dragFloat.addr, 0.005f)
  igDragFloat("drag small float", app.dragFloat2.addr, 0.0001f, 0.0f, 0.0f, "%.06f ns")

  # Widgets/Basic/SliderInt, SliderFloat
  igSliderInt("slider int", app.sliderInt.addr, -1, 3)
  igSameLine(); igHelpMarker("CTRL+click to input value.")

  igSliderFloat("slider float", app.sliderFloat.addr, 0.0f, 1.0f, "ratio = %.3f")
  igSliderFloat("slider float (log)", app.sliderFloat2.addr, -10.0f, 10.0f, "%.4f", ImGuiSliderFlags.Logarithmic)

  # Widgets/Basic/SliderAngle
  igSliderAngle("slider angle", app.angle.addr)

  # Using the format string to display a name instead of an integer.
  # Here we completely omit '%d' from the format string, so it'll only display a name.
  # This technique can also be used with DragInt().
  # Widgets/Basic/Slider (enum)
  var elem = app.elem.int32
  if igSliderInt("slider enum", elem.addr, 0, Element.high.int32, $app.elem): app.elem = elem.Element
  igSameLine(); igHelpMarker("Using the format string parameter to display a name instead of the underlying integer.")

  # Widgets/Basic/ColorEdit3, ColorEdit4
  igColorEdit3("color 1", app.color3)
  igSameLine(); igHelpMarker("""
  Click on the color square to open a color picker.
  Click and hold to use drag and drop.
  Right-click on the color square to show options.
  CTRL+click on individual component to input value.
  """)

  igColorEdit4("color 2", app.color4)

  # Using the _simplified_ one-liner ListBox() api here
  # See "List boxes" section for examples of how to use the more flexible BeginListBox()/EndListBox() api.
  # Widgets/Basic/ListBox
  if igBeginListBox("listbox"):
    for e, i in ["Apple", "Banana", "Cherry", "Kiwi", "Mango", "Orange", "Pineapple", "Strawberry", "Watermelon"]:
      if igSelectable(i, e == app.listCurrent):
        app.listCurrent = e

      if e == app.listCurrent:
        igSetItemDefaultFocus()

    igEndListBox()

proc drawMainMenuBar(app: var App) =
  var openAbout, openPrefs = false

  if igBeginMainMenuBar():
    if igBeginMenu("File"):
      igMenuItem("Preferences " & FA_Cog, "Ctrl+P", openPrefs.addr)
      if igMenuItem("Quit " & FA_Times, "Ctrl+Q"):
        app.win.setWindowShouldClose(true)
      igEndMenu()

    if igBeginMenu("Edit"):
      if igMenuItem("Reset Counter " & FA_Refresh, "Ctrl+R"):
        app.counter = 0

      igEndMenu()

    if igBeginMenu("About"):
      if igMenuItem("Website " & FA_ExternalLink):
        app.config["website"].getString().openURL()

      igMenuItem("About " & app.config["name"].getString(), shortcut = nil, p_selected = openAbout.addr)

      igEndMenu() 

    igEndMainMenuBar()

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
  
  app.drawMainMenuBar()
  # Work area is the entire viewport minus main menu bar, task bars, etc.
  igSetNextWindowPos(viewport.workPos)
  igSetNextWindowSize(viewport.workSize)

  if igBegin(app.config["name"].getString(), flags = makeFlags(ImGuiWindowFlags.NoResize, NoDecoration, NoMove)):
    igText(FA_Info & " Application average %.3f ms/frame (%.1f FPS)", 1000.0f / igGetIO().framerate, igGetIO().framerate)
    if igBeginTabBar("tabs"): 
      if igBeginTabItem("Counter"):
        app.drawCounter()
        igEndTabItem()
      
      if igBeginTabItem("Temperature Converter"):
        app.drawTempConverter()
        igEndTabItem()
      
      if igBeginTabItem("Flight Booker"):
        app.drawFlightBooker()
        igEndTabItem()

      if igBeginTabItem("Timer"):
        app.drawTimer()
        igEndTabItem()

      if igBeginTabItem("CRUD"):
        app.drawCRUD()
        igEndTabItem()

      if igBeginTabItem("Basic"):
        app.drawBasic()
        igEndTabItem()
      
      igEndTabBar()

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

proc initApp(config: PObjectType): App = 
  result = App(config: config, 
    buffer: newString(128, "Hello, world!"), hintBuffer: newString(128), 
    celsius: newString(32), fahrenheit: newString(32), 
    startDate: newString(32, "03.03.2003"), returnDate: newString(32, "03.03.2003"), 
    filterBuf: newString(64), nameBuf: newString(32), surnameBuf: newString(32), currentName: -1, namesData: @[("Elegant", "Beef"), ("Rika", "Nanakusa"), ("Omar", "Cornut")], 
  )
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

template initFonts(app: var App, io: ptr ImGuiIO) = 
  app.font = io.fonts.igAddFontFromMemoryTTF(app.config["fontPath"].getData(), app.config["fontSize"].getFloat())

  # Add ForkAwesome icon font
  var
    config = utils.newImFontConfig(mergeMode = true)
    ranges = [FA_Min.uint16,  FA_Max.uint16]

  io.fonts.igAddFontFromMemoryTTF(app.config["iconFontPath"].getData(), app.config["fontSize"].getFloat(), config.addr, ranges[0].addr)

proc main() =
  var app = initApp(configPath.getData().parsePrefs())

  # Init
  let
    context = igCreateContext()
    io = igGetIO()

  io.iniFilename = nil # Disable ini file

  doAssert glfwInit()
  app.initWindow()
  app.initFonts(io)
  doAssert glInit()

  doAssert igGlfwInitForOpenGL(app.win, true)
  doAssert igOpenGL3Init()

  # Load application style
  setIgStyle(app.config["stylePath"].getData().parsePrefs())

  # Main loop
  while not app.win.windowShouldClose:
    app.display()
    app.win.swapBuffers()

  # Shutdown
  igOpenGL3Shutdown()
  igGlfwShutdown()
  
  context.igDestroyContext()
  
  app.terminate()
  glfwTerminate()

when isMainModule:
  main()
