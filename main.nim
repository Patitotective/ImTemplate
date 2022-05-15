import std/[strutils, sequtils, strformat, strscans, times, os]

import chroma
import imstyle
import niprefs
import nimgl/[opengl, glfw]
import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]

import src/[spreadsheet, prefsmodal, utils, icons]
when defined(release):
  from resourcesdata import resources

const
  framerate = 30
  configPath = "config.niprefs"

var lastTime: float64

proc getData(path: string): string = 
  when defined(release):
    resources[path]
  else:
    readFile(path)

proc getData(node: PrefsNode): string = 
  node.getString().getData()

proc getCacheDir(app: App): string = 
  getCacheDir(app.config["name"].getString())

proc drawAboutModal(app: App) = 
  var center: ImVec2
  getCenterNonUDT(center.addr, igGetMainViewport())
  igSetNextWindowPos(center, Always, igVec2(0.5f, 0.5f))

  let unusedOpen = true
  if igBeginPopupModal(cstring "About " & app.config["name"].getString(), unusedOpen.unsafeAddr, flags = makeFlags(ImGuiWindowFlags.NoResize)):

    # Display icon image
    var
      texture: GLuint
      image = app.config["iconPath"].getData().readImageFromMemory()

    image.loadTextureFromData(texture)

    igImage(cast[ptr ImTextureID](texture), igVec2(64, 64)) # Or igVec2(image.width.float32, image.height.float32)
    if igIsItemHovered():
      if igIsMouseClicked(ImGuiMouseButton.Left):
        app.config["website"].getString().openURL()

      igSetTooltip(cstring app.config["website"].getString() & " " & FA_ExternalLink)

    igSameLine()
    
    igPushTextWrapPos(250)
    igTextWrapped(app.config["comment"].getString().cstring)
    igPopTextWrapPos()

    igSpacing()

    igSelectable("Credits", true, makeFlags(ImGuiSelectableFlags.DontClosePopups))
    if igBeginChild("##credits", igVec2(0, 75)):
      for author in app.config["authors"]:
        let (name, url) = block: 
          let (name,  url) = author.getString().removeInside('<', '>')
          (name.strip(),  url.strip())

        if igSelectable(name.cstring) and url.len > 0:
            url.openURL()
        if igIsItemHovered() and url.len > 0:
          igSetTooltip(cstring url & " " & FA_ExternalLink)
      igEndChild()

    igText(app.config["version"].getString().cstring)

    igEndPopup()

proc drawCounter(app: var App) = 
  igText(cstring $app.counter)
  igSameLine()

  if igButton("Count " & FA_HandPointerO):
    inc app.counter

proc drawTempConverter(app: var App) = 
  if igInputText("Celsius", app.celsius.cstring, 32):
    if (let (valid, val) = scanTuple(app.celsius.cleanString(), "$i$."); valid):
      let fahr = $(val.float * (9 / 5) + 32)
      app.fahrenheit[0..app.fahrenheit.high] = fahr
  
  if igInputText("Fahrenheit", app.fahrenheit.cstring, 32):
    if (let (valid, val) = scanTuple(app.fahrenheit.cleanString(), "$i$."); valid):
      let cels = $((val - 32).float * (5 / 9))
      app.celsius[0..app.celsius.high] = cels

proc drawFlightBooker(app: var App) = 
  const flights = ["one-way flight", "return flight"]
  if igBeginCombo("##flight", flights[app.currentFlight].cstring):
    for e, item in flights:
      if igSelectable(item.cstring, app.currentFlight == e):
        app.currentFlight = e
    igEndCombo()

  var startDateRed, returnDateRed, bookDisabled = false

  if not app.startDate.cleanString().validateDate("dd'.'mm'.'yyyy").success:
    startDateRed = true
    igPushStyleColor(FrameBg, "#A8232D".parseHtmlColor().igVec4())
  igInputText("Departure date", app.startDate.cstring, 32)
  if startDateRed:
    igPopStyleColor()

  if app.currentFlight == 0: # Meaning one-way flight
    igPushDisabled()
  if not app.returnDate.cleanString().validateDate("dd'.'mm'.'yyyy").success:
    returnDateRed = true
    igPushStyleColor(FrameBg, "#A8232D".parseHtmlColor().igVec4())
  igInputText("Return date", app.returnDate.cstring, 32)
  if returnDateRed:
    igPopStyleColor()

  if app.currentFlight == 0: # Meaning one-way flight
    igPopDisabled()

  if startDateRed or returnDateRed or 
    (app.currentFlight == 1 and (let (returnOK, returnDate) = app.returnDate.cleanString().validateDate("dd'.'mm'.'yyyy");
      let (startOk, startDate) = app.startDate.cleanString().validateDate("dd'.'mm'.'yyyy"); returnOk and startOk and returnDate < startDate)):
    bookDisabled = true
    igPushDisabled()

  if igButton("Book"):
    igOpenPopup("###booked")

  if bookDisabled:
    igPopDisabled()

  let unusedOpen = true
  igSetNextWindowPos(igGetMainViewport().getCenter(), Always, igVec2(0.5f, 0.5f))
  if igBeginPopupModal("Succesfully Booked###booked", unusedOpen.unsafeAddr, flags = makeFlags(ImGuiWindowFlags.NoResize, NoMove)):
    igPushTextWrapPos(250)
    if app.currentFlight == 0: # one-way flight
      igTextWrapped(cstring &"You have booked a one-way flight on {app.startDate}")
    elif app.currentFlight == 1: # return flight
      igTextWrapped(cstring &"You have booked a one-way flight departing on {app.startDate} and {app.returnDate}")
    igPopTextWrapPos()

    igEndPopup()

proc drawTimer(app: var App) = 
  if (app.curTime - app.startTime) < app.duration:
    app.curTime = igGetTime()

  igText("Elapsed Time: "); igSameLine()
  igProgressBar(1 / (app.duration / (app.curTime - app.startTime)))
  
  igText("%.1fs", app.curTime - app.startTime)
  
  igText("Duration: "); igSameLine()
  if igSliderFloat("##slider", app.duration.addr, 0f, 15f, ""):
    app.startTime = igGetTime() - (app.curTime - app.startTime)
    app.curTime = igGetTime()

  if igButton("Reset"):
    app.startTime = igGetTime()
    app.curTime = igGetTime()

proc drawCRUD(app: var App) = 
  var btnsDisabled = false
  igBeginGroup()
  igInputTextWithHint("##filterPrefix", "Filter prefix", app.filterBuf.cstring, 64)

  if igBeginListBox("##namesList"):
    for e, (name, surname) in app.namesData:
      if app.filterBuf.cleanString().len == 0 or surname.toLowerAscii().startsWith(app.filterBuf.cleanString().toLowerAscii()):
        if igSelectable(cstring &"{surname}, {name}", app.currentName == e):
          app.currentName = e

    igEndListBox()

  igEndGroup(); igSameLine()
  igBeginGroup()
  igInputTextWithHint("##name", "Name", app.nameBuf.cstring, 32)
  igInputTextWithHint("##surname", "Surname", app.surnameBuf.cstring, 32)
  igEndGroup()

  if igButton("Create"):
    let (nameBuf, surnameBuf) = (app.nameBuf.cleanString(), app.surnameBuf.cleanString())
    if nameBuf.len > 0 and surnameBuf.len > 0:
      app.namesData.add (nameBuf, surnameBuf)
  igSameLine()

  if app.currentName < 0:
    btnsDisabled = true
    igPushDisabled()

  if igButton("Update"):
    let (nameBuf, surnameBuf) = (app.nameBuf.cleanString(), app.surnameBuf.cleanString())
    if nameBuf.len > 0 and surnameBuf.len > 0:
      app.namesData[app.currentName] = (nameBuf, surnameBuf)
  igSameLine()
  if igButton("Delete"):
    app.namesData.del(app.currentName)
    app.currentName = -1

  if btnsDisabled:
    igPopDisabled()

proc drawCircleDrawer(app: var App) = 
  proc contains(circ: Circle, pos: ImVec2): bool =  ((circ.pos.x - pos.x) * (circ.pos.x - pos.x) + (circ.pos.y - pos.y) * (circ.pos.y - pos.y)) <= (circ.radius * circ.radius)
  proc contains(list: seq[Circle], pos: ImVec2): bool = any(list, proc (circ: Circle): bool = pos in circ)

  var openCirclePopup, undoDisabled, redoDisabled = false

  if app.currentAction == -1 or app.actionsStack.len == 0:
    undoDisabled = true
    igPushDisabled()

  if igButton("Undo"): 
    if app.currentAction > -1:
      let action = app.actionsStack[app.currentAction]
      case action.kind
      of Create:
        for e in 0..app.circlesList.high: 
          if app.circlesList[e].pos == action.pos:
            app.circlesList.del(e)
            dec app.currentAction
            break
      of Resize:
        for e in 0..app.circlesList.high:
          if app.circlesList[e].pos == action.pos: 
            app.actionsStack[app.currentAction].radius = app.circlesList[e].radius
            app.circlesList[e].radius = action.radius
            dec app.currentAction
            break
  if undoDisabled:
    igPopDisabled()

  igSameLine()

  if app.currentAction + 1 > app.actionsStack.high:
    redoDisabled = true
    igPushDisabled()
  if igButton("Redo"):
    inc app.currentAction
    if app.currentAction > -1:
      let action = app.actionsStack[app.currentAction]
      case action.kind
      of Create:
        app.circlesList.add newCircle(action.pos, action.radius)
      of Resize:
        for e in 0..app.circlesList.high:
          if app.circlesList[e].pos == action.pos: 
            app.actionsStack[app.currentAction].radius = app.circlesList[e].radius
            app.circlesList[e].radius = action.radius

  if redoDisabled:
    igPopDisabled()

  igPushStyleVar(WindowPadding, igVec2(0, 0))
  igPushStyleColor(ChildBg, "#ffffff".parseHtmlColor().igVec4())
  if igBeginChild("##canvas", igVec2(0, 250), border = true, flags = makeFlags(NoMove)):
    let canvas = igGetWindowDrawList()
    for circle in app.circlesList:
      if circle.hovered:
        canvas.addCircleFilled(circle.pos, circle.radius, igGetColorU32(ScrollbarGrab))
        canvas.addCircle(circle.pos, circle.radius, igGetColorU32(BorderShadow))
      else:
        canvas.addCircle(circle.pos, circle.radius, igGetColorU32(BorderShadow))

  igPopStyleVar()
  igPopStyleColor()
  igEndChild()

  if igIsItemClicked(ImGuiMouseButton.Left):
    if (let pos = igGetIO().mousePos; pos notin app.circlesList):
      if app.currentAction != app.actionsStack.high:
        app.actionsStack.delete(app.currentAction + 1..app.actionsStack.high)

      app.circlesList.add newCircle(pos, 20)
      app.actionsStack.add newAction(pos, Create, 20)
      app.currentAction = app.actionsStack.high

  if igIsItemHovered():
    let pos = igGetIO().mousePos
    var hovered = false
    for e in countdown(app.circlesList.high, 0):
      app.circlesList[e].hovered = not hovered and pos in app.circlesList[e]
      if pos in app.circlesList[e]: hovered = true
  else:
    for circ in app.circlesList.mitems: circ.hovered = false

  if igIsItemClicked(ImGuiMouseButton.Right):
    let pos = igGetIO().mousePos
    for e in countdown(app.circlesList.high, 0):
      if pos in app.circlesList[e]:
        app.diameter = (app.circlesList[e].radius * 2).int32
        app.currentCirc = e
        igOpenPopup("circlePopup")
        break

  if igBeginPopup("circlePopup"):
    if igSelectable("Adjust Diameter"):
      openCirclePopup = true
    igEndPopup()

  if openCirclePopup:
    app.actionsStack.add newAction(app.circlesList[app.currentCirc].pos, Resize, app.circlesList[app.currentCirc].radius)
    app.currentAction = app.actionsStack.high
    igOpenPopup("##adjustDiameter")

  if igBeginPopupModal("##adjustDiameter", flags = makeFlags(ImGuiWindowFlags.NoResize)):
    igText(cstring &"Adjust the diameter of the circle at {app.circlesList[app.currentCirc].pos}")
    if igSliderInt("##diameter", app.diameter.addr, 10, 70, format = ""):
      app.circlesList[app.currentCirc].radius = app.diameter / 2        

    if igButton("OK"):
      if app.actionsStack[^1].radius == app.circlesList[app.currentCirc].radius:
        app.actionsStack.del(app.actionsStack.high)
        app.currentAction = app.actionsStack.high
      else:
        if app.currentAction != app.actionsStack.high:
          app.actionsStack.delete(app.currentAction + 1..app.actionsStack.high)

        app.currentAction = app.actionsStack.high

      igCloseCurrentPopup()

    igEndPopup()

proc drawCells(app: App) = 
  app.spreadsheet.draw()

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
  igText(cstring $app.basicCounter)

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
  if igBeginCombo("combo", comboItems[app.comboCurrent].cstring):
    for e, i in comboItems:
      if igSelectable(i.cstring, e == app.comboCurrent):
        app.comboCurrent = e

    igEndCombo()

  # To wire InputText() with std::string or any other custom string type,
  # see the "Text Input > Resize Callback" section of this demo, and the misc/cpp/imgui_stdlib.h file.
  # Widgets/Basic/InputText
  igInputText("input text", app.buffer.cstring, 128)
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

  igInputTextWithHint("input text (w/ hint)", "enter text here", app.hintBuffer.cstring, 128)

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
  if igSliderInt("slider enum", elem.addr, 0, Element.high.int32, cstring $app.elem): app.elem = elem.Element
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
      if igSelectable(i.cstring, e == app.listCurrent):
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

      igMenuItem(cstring "About " & app.config["name"].getString(), shortcut = nil, p_selected = openAbout.addr)

      igEndMenu() 

    igEndMainMenuBar()

  # See https://github.com/ocornut/imgui/issues/331#issuecomment-751372071
  if openPrefs:
    igOpenPopup("Preferences")
  if openAbout:
    igOpenPopup(cstring "About " & app.config["name"].getString())

  # These modals will only get drawn when igOpenPopup(name) are called, respectly
  app.drawAboutModal()
  app.drawPrefsModal()

proc drawMain(app: var App) = # Draw the main window
  let viewport = igGetMainViewport()  
  
  app.drawMainMenuBar()
  # Work area is the entire viewport minus main menu bar, task bars, etc.
  igSetNextWindowPos(viewport.workPos)
  igSetNextWindowSize(viewport.workSize)

  if igBegin(app.config["name"].getString().cstring, flags = makeFlags(ImGuiWindowFlags.NoResize, NoDecoration, NoMove)):
    igText(FA_Info & " Application average %.3f ms/frame (%.1f FPS)", 1000f / igGetIO().framerate, igGetIO().framerate)
   
    if igBeginTabBar("tabs"): 
      if igBeginTabItem("7GUIs"):
        if igCollapsingHeader("Counter"): app.drawCounter()
        if igCollapsingHeader("Temperature Converter"): app.drawTempConverter()
        if igCollapsingHeader("Flight Booker"): app.drawFlightBooker()
        if igCollapsingHeader("Timer"): app.drawTimer()
        if igCollapsingHeader("CRUD"): app.drawCRUD()
        if igCollapsingHeader("Circle Drawer"): app.drawCircleDrawer()
        if igCollapsingHeader("Cells"): app.drawCells()

        igEndTabItem()

      if igBeginTabItem("Basic"):
        app.drawBasic()
        igEndTabItem()
      
      igEndTabBar()

  igEnd()

proc render(app: var App) = # Called in the main loop
  # Poll and handle events (inputs, window resize, etc.)
  glfwPollEvents()

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

  app.win = glfwCreateWindow(
    app.prefs["win/width"].getInt().int32, 
    app.prefs["win/height"].getInt().int32, 
    app.config["name"].getString().cstring, 
    icon = false # Do not use default icon
  )

  if app.win == nil:
    quit(-1)

  # Set the window icon
  var icon = initGLFWImage(app.config["iconPath"].getData().readImageFromMemory())
  app.win.setWindowIcon(1, icon.addr)

  app.win.setWindowSizeLimits(app.config["minSize"][0].getInt().int32, app.config["minSize"][1].getInt().int32, GLFW_DONT_CARE, GLFW_DONT_CARE) # minWidth, minHeight, maxWidth, maxHeight

  # If negative pos "center" the window on the monitor
  if app.prefs["win/x"].getInt() < 0 or app.prefs["win/y"].getInt() < 0:
    var monitorX, monitorY, count: int32
    let
      monitors = glfwGetMonitors(count.addr)
      videoMode = monitors[0].getVideoMode()
      windowWidth = videoMode.width.float / 1.5
      windowHeight = windowWidth / 16 * 9
 
    monitors[0].getMonitorPos(monitorX.addr, monitorY.addr)
    app.win.setWindowPos(
      int32(monitorX.float + (videoMode.width.float - windowWidth) / 2), 
      int32(monitorY.float + (videoMode.height.float - windowHeight) / 2)
    )
  else:
    app.win.setWindowPos(app.prefs["win/x"].getInt().int32, app.prefs["win/y"].getInt().int32)

proc initPrefs(app: var App) = 
  app.prefs = toPrefs({
    win: {
      # Negative numbers center the window
      x: -1,
      y: -1,
      width: 500,
      height: 500
    }
  }).initPrefs((app.getCacheDir() / app.config["name"].getString()).changeFileExt("niprefs"))

proc initApp(config: PObjectType): App = 
  result = App(config: config, 
    buffer: newString(128, "Hello, world!"), hintBuffer: newString(128), 
    celsius: newString(32), fahrenheit: newString(32), 
    startDate: newString(32, "03.03.2003"), returnDate: newString(32, "03.03.2003"), 
    filterBuf: newString(64), nameBuf: newString(32), surnameBuf: newString(32), currentName: -1, 
    namesData: @[("Elegant", "Beef"), ("Rika", "Nanakusa"), ("Omar", "Cornut"), ("Armen", "Ghazaryan"), ("Uncle", "Hmm")], 
    currentCirc: -1, currentAction: -1, 
    spreadsheet: initSpreadsheet("##spreadsheet", 99, 25, makeFlags(ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY, Borders)), 
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

proc initFonts(app: var App) = 
  let io = igGetIO()
  app.font = io.fonts.igAddFontFromMemoryTTF(app.config["fontPath"].getData(), app.config["fontSize"].getFloat())

  # Add ForkAwesome icon font
  var
    config = utils.newImFontConfig(mergeMode = true)
    ranges = [FA_Min.uint16,  FA_Max.uint16]

  io.fonts.igAddFontFromMemoryTTF(app.config["iconFontPath"].getData(), app.config["fontSize"].getFloat(), config.addr, ranges[0].addr)

proc main() =
  var app = initApp(configPath.getData().parsePrefs())

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
  setIgStyle(app.config["stylePath"].getData().parsePrefs())

  # Setup Platform/Renderer backends
  doAssert igGlfwInitForOpenGL(app.win, true)
  doAssert igOpenGL3Init()

  # Load fonts
  app.initFonts()

  # Main loop
  lastTime = glfwGetTime()
  glfwWaitEvents()

  while not app.win.windowShouldClose:
    app.render()
    
    # See https://github.com/glfw/glfw/issues/1308#issuecomment-409245792
    while glfwGetTime() < lastTime + (1 / framerate):
      sleep(10)

    lastTime += 1 / framerate

  # Cleanup
  igOpenGL3Shutdown()
  igGlfwShutdown()
  
  igDestroyContext()
  
  app.terminate()
  app.win.destroyWindow()
  glfwTerminate()

when isMainModule:
  main()
