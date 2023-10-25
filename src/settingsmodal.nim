import std/[strutils, options, tables, os]

import kdl/prefs
import tinydialogs
import nimgl/imgui

import utils, icons, types

proc settingLabel(name: string, setting: Setting[auto]): cstring =
  cstring (if setting.display.len == 0: name else: setting.display) & ": "

proc drawSettings(app: var App) =
  for name, setting in app.prefs[settings].fieldPairs:
    let label = settingLabel(name, setting)
    let id = cstring "##" & name
    if setting.kind != stSection:
      igText(label); igSameLine(0, 0)
      igDummy(igVec2(app.maxLabelWidth - igCalcTextSize(label).x, 0))
      igSameLine(0, 0)

    case setting.kind
    of stInput:
      let flags = makeFlags(setting.inputFlags)
      let buffer = newString(100, setting.inputCache)

      if setting.hint.len > 0:
        if igInputTextWithHint(id, cstring setting.hint, cstring buffer, 100, flags):
          setting.inputCache = buffer.cleanString()
      else:
        if igInputText(id, cstring buffer, 100, flags):
          setting.inputCache = buffer.cleanString()
    else: discard
    # of stCheck:
    #   assert field is bool
    #   when field is bool:
    #     igCheckbox(id, field.addr)
    # of stSlider:
    #   assert field is int32
    #   assert setting.min.isSome and setting.max.isSome
    #   when field is int32:
    #     igSliderInt(
    #       id,
    #       field.addr,
    #       int32 setting.min.get,
    #       int32 setting.max.get,
    #       cstring (if setting.format.isSome: setting.format.get else: "%d"),
    #       parseMakeFlags[ImGuiSliderFlags](setting.flags)
    #     )
    # of stFSlider:
    #   assert field is float32
    #   assert setting.min.isSome and setting.max.isSome
    #   when field is float32:
    #     igSliderFloat(
    #       id,
    #       field.addr,
    #       setting.min.get,
    #       setting.max.get,
    #       cstring (if setting.format.isSome: setting.format.get else: "%.3f"),
    #       parseMakeFlags[ImGuiSliderFlags](setting.flags)
    #     )
    # of stSpin:
    #   assert field is int32
    #   when field is int32:
    #     var temp = field
    #     if igInputInt(
    #       id,
    #       temp.addr,
    #       int32 setting.step,
    #       int32 setting.stepfast,
    #       parseMakeFlags[ImGuiInputTextFlags](setting.flags)
    #     ) and (setting.min.isNone or temp >= int32(setting.min.get)) and (setting.max.isNone or temp <= int32(setting.max.get)):
    #       field = temp
    # of stFSpin:
    #   assert field is float32
    #   when field is float32:
    #     var temp = field
    #     if igInputFloat(
    #       id,
    #       temp.addr,
    #       setting.step,
    #       setting.stepfast,
    #       cstring (if setting.format.isSome: setting.format.get else: "%.3f"),
    #       parseMakeFlags[ImGuiInputTextFlags](setting.flags)
    #     ) and (setting.min.isNone or temp >= setting.min.get) and (setting.max.isNone or temp <= setting.max.get):
    #       field = temp
    # of stCombo:
    #   assert field is enum
    #   when field is enum:
    #     if igBeginCombo(id, cstring $field, parseMakeFlags[ImGuiComboFlags](setting.flags)):
    #       for item in setting.items:
    #         let itenum = parseEnum[typeof field](item)
    #         if igSelectable(cstring item, field == itenum):
    #           field = itenum

    #       igEndCombo()
    # of stRadio:
    #   assert field is enum
    #   when field is enum:
    #     for e, item in setting.items:
    #       let itenum = parseEnum[typeof field](item)
    #       if igRadioButton(cstring $itenum & "##" & name & $e, itenum == field):
    #         field = itenum

    #       if e < setting.items.high:
    #         igSameLine()
    # of stRGB:
    #   assert field is tuple[r, g, b: float32]
    #   when field is tuple[r, g, b: float32]:
    #     var colArray = [field.r, field.g, field.b]
    #     if igColorEdit3(id, colArray, parseMakeFlags[ImGuiColorEditFlags](setting.flags)):
    #       field = (colArray[0], colArray[1], colArray[2])
    # of stRGBA:
    #   assert field is tuple[r, g, b, a: float32]
    #   when field is tuple[r, g, b, a: float32]:
    #     var colArray = [field.r, field.g, field.b, field.a]
    #     if igColorEdit4(id, colArray, parseMakeFlags[ImGuiColorEditFlags](setting.flags)):
    #       field = (colArray[0], colArray[1], colArray[2], colArray[3])
    # of stFile:
    #   assert field is string
    #   when field is string:
    #     igPushID(id)
    #     igInputTextWithHint(id, "Nothing selected", cstring field, uint field.len, flags = ImGuiInputTextFlags.ReadOnly)
    #     igSameLine()
    #     if (igIsItemHovered(flags = AllowWhenDisabled) and igIsMouseDoubleClicked(ImGuiMouseButton.Left)) or igButton("Browse " & FA_FolderOpen):
    #       if (let path = openFileDialog("Choose File", getCurrentDir() / "\0", setting.filterPatterns, setting.singleFilterDescription); path.len > 0):
    #         field = path
    #     igPopID()
    # of stFiles:
    #   assert field is seq[string]
    #   when field is seq[string]:
    #     let str = field.join(",")
    #     igPushID(id)
    #     igInputTextWithHint(id, "Nothing selected", cstring str, uint str.len, flags = ImGuiInputTextFlags.ReadOnly)
    #     igSameLine()
    #     if (igIsItemHovered(flags = AllowWhenDisabled) and igIsMouseDoubleClicked(ImGuiMouseButton.Left)) or igButton("Browse " & FA_FolderOpen):
    #       if (let paths = openMultipleFilesDialog("Choose Files", getCurrentDir() / "\0", setting.filterPatterns, setting.singleFilterDescription); paths.len > 0):
    #         field = paths
    #     igPopID()
    # of stFolder:
    #   assert field is string
    #   when field is string:
    #     igPushID(id)
    #     igInputTextWithHint(id, "Nothing selected", cstring field, uint field.len, flags = ImGuiInputTextFlags.ReadOnly)
    #     igSameLine()
    #     if (igIsItemHovered(flags = AllowWhenDisabled) and igIsMouseDoubleClicked(ImGuiMouseButton.Left)) or igButton("Browse " & FA_FolderOpen):
    #       if (let path = selectFolderDialog("Choose Folder", getCurrentDir() / "\0"); path.len > 0):
    #         field = path
    #     igPopID()
    # of stSection:
    #   assert field is object
    #   when field is object:
    #     igPushID(id)
    #     if igCollapsingHeader(label, parseMakeFlags[ImGuiTreeNodeFlags](setting.flags)):
    #       igIndent()
    #       drawSettings(field, setting.content, maxLabelWidth)
    #       igUnindent()
    #     igPopID()

    if setting.help.len > 0:
      igSameLine()
      igHelpMarker(setting.help)

proc calcMaxLabelWidth(settings: auto): float32 =
  when settings is object:
    for name, setting in settings.fieldPairs:
      when setting is Setting:
        let label = settingLabel(name, setting)

        let width =
          if setting.kind == stSection:
            calcMaxLabelWidth(setting.content)
          else:
            igCalcTextSize(label).x
        if width > result:
          result = width
      else:
        {.error: name & "is not a settings object".}

proc drawSettingsmodal*(app: var App) =
  if app.maxLabelWidth <= 0:
    app.maxLabelWidth = app.prefs[settings].calcMaxLabelWidth()

  igSetNextWindowPos(igGetMainViewport().getCenter(), Always, igVec2(0.5f, 0.5f))

  if igBeginPopupModal("Settings", flags = makeFlags(AlwaysAutoResize, HorizontalScrollbar)):
    var close = false

    # app.settingsmodal.cache must be set to app.prefs[settings] once when opening the modal
    app.drawSettings()

    igSpacing()

    if igButton("Save"):
      echo "TODO: save"
      # app.prefs[settings] = app.settingsmodal.cache
      igCloseCurrentPopup()

    igSameLine()

    if igButton("Cancel"):
      echo "TODO: cache"
      # app.settingsmodal.cache = app.prefs[settings]
      igCloseCurrentPopup()

    igSameLine()

    # Right aling button
    igSetCursorPosX(igGetCurrentWindow().size.x - igCalcFrameSize("Reset").x - igGetStyle().windowPadding.x)
    if igButton("Reset"):
      igOpenPopup("Reset")

    igSetNextWindowPos(igGetMainViewport().getCenter(), Always, igVec2(0.5f, 0.5f))

    if igBeginPopupModal("Reset", flags = makeFlags(AlwaysAutoResize)):
      igPushTextWrapPos(250)
      igTextWrapped("Are you sure?\nYou won't be able to undo this action")
      igPopTextWrapPos()

      if igButton("Yes"):
        close = true
        app.prefs[settings] = app.prefs{settings}
        igCloseCurrentPopup()

      igSameLine()

      if igButton("Cancel"):
        igCloseCurrentPopup()

      igEndPopup()

    if close:
      igCloseCurrentPopup()

    igEndPopup()
