import std/strutils

import niprefs
import nimgl/imgui
import niprefs/utils as prefsUtils

import utils

proc drawSettings(app: var App, settings: PrefsNode, alignCount: Natural, parent = "")

proc drawSetting(app: var App, name: string, data: PObjectType, alignCount: Natural, parent = "") = 
  proc getCacheVal(app: var App, key: string, parent = ""): PrefsNode = 
    if parent.len > 0:
      app.cache.getNested(parent, name)
    else:
      app.cache[name]
  proc addToCache(app: var App, key: string, val: PrefsNode, parent = "") = 
    if parent.len > 0:
      app.cache = app.cache.changeNested(parent, name, val)
    else:
      app.cache[key] = val

  let
    settingType = parseEnum[SettingTypes](data["type"])
    label = if "display" in data: data["display"].getString() else: name.capitalizeAscii()
  if settingType != Section:
    igText((label & ": ").alignLeft(alignCount))
    igSameLine()

  case settingType:
  of Input:
    let
      flags = getFlags[ImGuiInputTextFlags](data["flags"])
      text = app.getCacheVal(name, parent).getString()

    var buffer = newString(data["max"].getInt())
    buffer[0..text.high] = text

    if igInputTextWithHint("##" & name, if "hint" in data: data["hint"].getString() else: "", buffer, data["max"].getInt().uint, flags):
      app.addToCache(name, buffer.newPString(), parent)
  of Check:
    var checked = app.getCacheVal(name, parent).getBool()
    if igCheckbox("##" & name, checked.addr):
      app.addToCache(name, checked.newPBool(), parent)
  of Slider:
    let flags = getFlags[ImGuiSliderFlags](data["flags"])
    var val = app.getCacheVal(name, parent).getInt().int32
    
    if igSliderInt(
      "##" & name, 
      val.addr, 
      data["min"].getInt().int32, 
      data["max"].getInt().int32, 
      data["format"].getString(), 
      flags
    ):
      app.addToCache(name, val.newPInt(), parent)
  of FSlider:
    let flags = getFlags[ImGuiSliderFlags](data["flags"])
    var val: float32 = app.getCacheVal(name, parent).getFloat()
    
    if igSliderFloat(
      "##" & name, 
      val.addr, 
      data["min"].getFloat(), 
      data["max"].getFloat(), 
      data["format"].getString(), 
      flags
    ):
      app.addToCache(name, val.newPFloat(), parent)
  of Spin:
    let flags = getFlags[ImGuiInputTextFlags](data["flags"])
    var val = app.getCacheVal(name, parent).getInt().int32
    
    if igInputInt(
      "##" & name, 
      val.addr, 
      data["step"].getInt().int32, 
      data["step_fast"].getInt().int32, 
      flags
    ):
      app.addToCache(name, val.newPInt(), parent)
  of FSpin:
    let flags = getFlags[ImGuiInputTextFlags](data["flags"])
    var val = app.getCacheVal(name, parent).getFloat().float32
    
    if igInputFloat(
      "##" & name, 
      val.addr, 
      data["step"].getFloat(), 
      data["step_fast"].getFloat(), 
      data["format"].getString(),
      flags
    ):
      app.addToCache(name, val.newPFloat(), parent)
  of Combo:
    let flags = getFlags[ImGuiComboFlags](data["flags"])
    var currentItem = app.getCacheVal(name, parent)

    if currentItem.kind == PInt:
      currentItem = data["items"][currentItem.getInt()]

    if igBeginCombo("##" & name, currentItem.getString(), flags):

      for i in data["items"].getSeq():
        let selected = currentItem == i
        if igSelectable(i.getString(), selected):
          app.addToCache(name, i, parent)

        if selected:
          igSetItemDefaultFocus()

      igEndCombo()
  of Radio:
    var currentItem: int32

    if app.getCacheVal(name, parent).kind == PString:
      currentItem = data["items"].getSeq().find(app.getCacheVal(name, parent).getString()).int32
    else:
      currentItem = app.getCacheVal(name, parent).getInt().int32

    for e, i in data["items"].getSeq():
      if igRadioButton(i.getString(), currentItem.addr, e.int32):
        app.addToCache(name, i, parent)
      
      if e < data["items"].getSeq().high:
        igSameLine()
  of Color3:
    let flags = getFlags[ImGuiColorEditFlags](data["flags"])
    var col = app.getCacheVal(name, parent).parseColor3()

    if igColorEdit3("##" & name, col, flags):
      var color = newPSeq()
      color.add col[0].newPFloat()
      color.add col[1].newPFloat()
      color.add col[2].newPFloat()
      app.addToCache(name, color, parent)
  of Color4:
    let flags = getFlags[ImGuiColorEditFlags](data["flags"])
    var col = app.getCacheVal(name, parent).parseColor4()
    
    if igColorEdit4("##" & name, col, flags):
      var color = newPSeq()
      color.add col[0].newPFloat()
      color.add col[1].newPFloat()
      color.add col[2].newPFloat()
      color.add col[3].newPFloat()
      app.addToCache(name, color, parent)
  of Section:
    let flags = getFlags[ImGuiTreeNodeFlags](data["flags"])
    if igCollapsingHeader(label, flags):
      if parent.len > 0:
        app.drawSettings(data["content"], alignCount, parent & "/" & name)
      else:
        app.drawSettings(data["content"], alignCount, name)

  if "help" in data:
    igSameLine()
    igHelpMarker(data["help"].getString())

proc drawSettings(app: var App, settings: PrefsNode, alignCount: Natural, parent = "") = 
  assert settings.kind == PObject

  for name, data in settings:
    if parseEnum[SettingTypes](data["type"]) != Section:
      if parent.len > 0:
        if parent notin app.cache: app.cache[parent] = newPObject()
        if name notin app.cache[parent]:
          app.cache = app.cache.changeNested(parent, name, app.prefs[parent, name])
      else:
        if name notin app.cache:
          app.cache[name] = app.prefs[name]

    app.drawSetting(name, data.getObject(), alignCount, parent)

proc drawPrefsModal*(app: var App) = 
  proc calcAlignCount(settings: PrefsNode, margin: int = 6): Natural = 
    for name, data in settings:
      if parseEnum[SettingTypes](data["type"]) == Section:
        let alignCount = calcAlignCount(data["content"])
        if alignCount > result: result = alignCount+margin
      else:
        if name.len > result: result = name.len+margin
  var close = false

  igSetNextWindowPos(igGetMainViewport().getCenter(), Always, igVec2(0.5f, 0.5f))

  if igBeginPopupModal("Preferences", flags = makeFlags(AlwaysAutoResize, HorizontalScrollbar)):
    app.drawSettings(app.config["settings"], calcAlignCount(app.config["settings"]))

    igSpacing()

    if igButton("Save"):
      for name, val in app.cache:
        app.prefs[name] = val

      igCloseCurrentPopup()
    
    igSameLine()

    if igButton("Cancel"):
      app.cache = default PObjectType
      igCloseCurrentPopup()

    igSameLine()

    centerCursorX(igCalcTextSize("Reset").x, 1, igGetWindowPos().x) 
    if igButton("Reset"):
      igOpenPopup("Reset?")

    if igBeginPopupModal("Reset?", flags = makeFlags(AlwaysAutoResize)):
      igTextWrapped("Are you sure you want to reset the preferences?\nYou won't be able to undo this action")
      
      if igButton("Yes"):
        close = true
        app.prefs.overwrite()
        app.initConfig(app.config["settings"])
        app.cache = default PObjectType
        igCloseCurrentPopup()

      igSameLine()
    
      if igButton("Cancel"):
        igCloseCurrentPopup()

      igEndPopup()

    if close:
      igCloseCurrentPopup()

    igEndPopup()
