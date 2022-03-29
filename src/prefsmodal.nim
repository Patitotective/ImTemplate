import std/strutils

import niprefs
import nimgl/imgui

import common

proc drawSettings(app: var App, settings: PObjectType)

proc drawSetting(app: var App, name: string, data: PObjectType) = 
  let settingType = parseEnum[SettingTypes](data["type"])
  if settingType != Section:
    igText(name.capitalizeAscii() & ": ")
    igSameLine()

  case settingType:
  of Input:
    let
      flags = getFlags[ImGuiInputTextFlags](data["flags"])
      text = app.cache[name].getString()

    var buffer = newString(data["max"].getInt())
    buffer[0..text.high] = text

    if igInputText("##" & name, buffer, data["max"].getInt().uint, flags):
      app.cache[name] = buffer.newPString()
  of Check:
    var checked = app.cache[name].getBool()
    if igCheckbox("##" & name, checked.addr):
      app.cache[name] = checked.newPBool()
  of Slider:
    let flags = getFlags[ImGuiSliderFlags](data["flags"])
    var val = app.cache[name].getInt().int32
    
    if igSliderInt(
      "##" & name, 
      val.addr, 
      data["min"].getInt().int32, 
      data["max"].getInt().int32, 
      data["format"].getString(), 
      flags
    ):
      app.cache[name] = val.newPInt()
  of FSlider:
    let flags = getFlags[ImGuiSliderFlags](data["flags"])
    var val: float32 = app.cache[name].getFloat()
    
    if igSliderFloat(
      "##" & name, 
      val.addr, 
      data["min"].getFloat(), 
      data["max"].getFloat(), 
      data["format"].getString(), 
      flags
    ):
      app.cache[name] = val.newPFloat()
  of Spin:
    let flags = getFlags[ImGuiInputTextFlags](data["flags"])
    var val = app.cache[name].getInt().int32
    
    if igInputInt(
      "##" & name, 
      val.addr, 
      data["step"].getInt().int32, 
      data["step_fast"].getInt().int32, 
      flags
    ):
      app.cache[name] = val.newPInt()
  of FSpin:
    let flags = getFlags[ImGuiInputTextFlags](data["flags"])
    var val = app.cache[name].getFloat().float32
    
    if igInputFloat(
      "##" & name, 
      val.addr, 
      data["step"].getFloat(), 
      data["step_fast"].getFloat(), 
      data["format"].getString(),
      flags
    ):
      app.cache[name] = val.newPFloat()
  of Combo:
    let flags = getFlags[ImGuiComboFlags](data["flags"])
    var currentItem = app.cache[name]

    if currentItem.kind == PInt:
      currentItem = data["items"][currentItem.getInt()]

    if igBeginCombo("##" & name, currentItem.getString(), flags):

      for i in data["items"].getSeq():
        let selected = currentItem == i
        if igSelectable(i.getString(), selected):
          app.cache[name] = i

        if selected:
          igSetItemDefaultFocus()

      igEndCombo()
  of Radio:
    var currentItem: int32

    if app.cache[name].kind == PString:
      currentItem = data["items"].getSeq().find(app.cache[name].getString()).int32
    else:
      currentItem = app.cache[name].getInt().int32

    for e, i in data["items"].getSeq():
      if igRadioButton(i.getString(), currentItem.addr, e.int32):
        app.cache[name] = i
      
      if e < data["items"].getSeq().high:
        igSameLine()
  of Color3:
    let flags = getFlags[ImGuiColorEditFlags](data["flags"])
    var col = app.cache[name].parseColor3()

    if igColorEdit3("##" & name, col, flags):
      app.cache[name] = newPSeq()
      app.cache[name].seqV.add col[0].newPFloat()
      app.cache[name].seqV.add col[1].newPFloat()
      app.cache[name].seqV.add col[2].newPFloat()
  of Color4:
    let flags = getFlags[ImGuiColorEditFlags](data["flags"])
    var col = app.cache[name].parseColor4()
    
    if igColorEdit4("##" & name, col, flags):
      app.cache[name] = newPSeq()
      app.cache[name].seqV.add col[0].newPFloat()
      app.cache[name].seqV.add col[1].newPFloat()
      app.cache[name].seqV.add col[2].newPFloat()
      app.cache[name].seqV.add col[3].newPFloat()
  of Section:
    let flags = getFlags[ImGuiTreeNodeFlags](data["flags"])
    if igCollapsingHeader(name.capitalizeAscii(), flags):
      app.drawSettings(data["content"].getObject())

  if "help" in data:
    igSameLine()
    igHelpMarker(data["help"].getString())

proc drawSettings(app: var App, settings: PObjectType) = 
  for name, data in settings:
    if parseEnum[SettingTypes](data["type"]) != Section:
      if name notin app.prefs:
        app.prefs[name] = data["default"]
      if name notin app.cache:
        app.cache[name] = app.prefs[name]

    app.drawSetting(name, data.getObject())

proc drawPrefsModal*(app: var App) = 
  var center: ImVec2
  getCenterNonUDT(center.addr, igGetMainViewport())
  igSetNextWindowPos(center, Always, igVec2(0.5f, 0.5f))

  if igBeginPopupModal("Preferences", flags = makeFlags(AlwaysAutoResize)):
    app.drawSettings(app.config["settings"].getObject())

    if igButton("Save"):
      for name, val in app.cache:
        app.prefs[name] = val

      igCloseCurrentPopup()
    
    igSameLine()
    
    if igButton("Cancel"):
      app.cache = default PObjectType
      igCloseCurrentPopup()

    igEndPopup()
