import std/[threadpool, typetraits, strutils, options, tables, macros, os]
import micros
import kdl/prefs
import tinydialogs
import nimgl/imgui

import utils, icons, types

proc settingLabel(name: string, setting: Setting[auto]): cstring =
  cstring (if setting.display.len == 0: name else: setting.display) & ": "

proc drawSettings(settings: var object, maxLabelWidth: float32) =
  for name, setting in settings.fieldPairs:
    let label = settingLabel(name, setting)
    let id = cstring "##" & name
    if setting.kind != stSection:
      igText(label); igSameLine(0, 0)
      if igIsItemHovered() and setting.help.len > 0:
        igSetToolTip(cstring setting.help)

      igDummy(igVec2(maxLabelWidth - igCalcTextSize(label).x, 0))
      igSameLine(0, 0)

    case setting.kind
    of stInput:
      let flags = makeFlags(setting.inputFlags)
      let buffer = newString(setting.limits.b, setting.inputCache)

      if setting.hint.len > 0:
        if igInputTextWithHint(id, cstring setting.hint, cstring buffer, uint setting.limits.b, flags) and (let newBuffer = buffer.cleanString(); newBuffer.len >= setting.limits.a):
          setting.inputCache = newBuffer
      else:
        if igInputText(id, cstring buffer, uint setting.limits.b, flags) and (let newBuffer = buffer.cleanString(); newBuffer.len >= setting.limits.a):
          setting.inputCache = newBuffer
    of stCheck:
      igCheckbox(id, setting.checkCache.addr)
    of stSlider:
      igSliderInt(
        id,
        setting.sliderCache.addr,
        setting.sliderRange.a,
        setting.sliderRange.b,
        cstring setting.sliderFormat,
        makeFlags(setting.sliderFlags)
      )
    of stFSlider:
      igSliderFloat(
        id,
        setting.fsliderCache.addr,
        setting.fsliderRange.a,
        setting.fsliderRange.b,
        cstring setting.fsliderFormat,
        makeFlags(setting.fsliderFlags)
      )
    of stSpin:
      var temp = setting.spinCache
      if igInputInt(
        id,
        temp.addr,
        setting.step,
        setting.stepFast,
        makeFlags(setting.spinflags)
      ) and temp in setting.spinRange:
        setting.spinCache = temp
    of stFSpin:
      var temp = setting.fspinCache
      if igInputFloat(
        id,
        temp.addr,
        setting.fstep,
        setting.fstepFast,
        cstring setting.fspinFormat,
        makeFlags(setting.fspinflags)
      ) and temp in setting.fspinRange:
        setting.fspinCache = temp
    of stCombo:
      if igBeginCombo(id, cstring $setting.comboCache, makeFlags(setting.comboFlags)):
        for item in setting.comboItems:
          if igSelectable(cstring $item, item == setting.comboCache):
            setting.comboCache = item
        igEndCombo()
    of stRadio:
      for e, item in setting.radioItems:
        if igRadioButton(cstring $item & "##" & name, item == setting.radioCache):
          setting.radioCache = item

        if e < setting.radioItems.high:
          igSameLine()
    of stRGB:
      igColorEdit3(id, setting.rgbCache, makeFlags(setting.rgbFlags))
    of stRGBA:
      igColorEdit4(id, setting.rgbaCache, makeFlags(setting.rgbaFlags))
    of stFile:
      let fileCache =
        if setting.fileCache.isNil or not setting.fileCache.isReady:
          ""
        else:
          ^setting.fileCache
      igPushID(id)
      igInputTextWithHint("##input", "No file selected", cstring fileCache, uint fileCache.len, flags = ImGuiInputTextFlags.ReadOnly)
      igSameLine()
      if (igIsItemHovered(flags = AllowWhenDisabled) and igIsMouseDoubleClicked(ImGuiMouseButton.Left)) or igButton("Browse " & FA_FolderOpen):
        setting.fileCache = spawn openFileDialog("Choose File", getCurrentDir() / "\0", setting.fileFilterPatterns, setting.fileSingleFilterDescription)
      igPopID()
    of stFiles:
      let files = setting.filesCache.join(",")
      igPushID(id)
      igInputTextWithHint("##input", "No files selected", cstring files, uint files.len, flags = ImGuiInputTextFlags.ReadOnly)
      igSameLine()
      if (igIsItemHovered(flags = AllowWhenDisabled) and igIsMouseDoubleClicked(ImGuiMouseButton.Left)) or igButton("Browse " & FA_FolderOpen):
        if (let paths = openMultipleFilesDialog("Choose Files", getCurrentDir() / "\0", setting.filesFilterPatterns, setting.filesSingleFilterDescription); paths.len > 0):
          setting.filesCache = paths
      igPopID()
    of stFolder:
      igPushID(id)
      igInputTextWithHint("##input", "No folder selected", cstring setting.folderCache, uint setting.folderCache.len, flags = ImGuiInputTextFlags.ReadOnly)
      igSameLine()
      if (igIsItemHovered(flags = AllowWhenDisabled) and igIsMouseDoubleClicked(ImGuiMouseButton.Left)) or igButton("Browse " & FA_FolderOpen):
        if (let path = selectFolderDialog("Choose Folder", getCurrentDir() / "\0"); path.len > 0):
          setting.folderCache = path
      igPopID()
    of stSection:
      igPushID(id)
      if igCollapsingHeader(label, makeFlags(setting.sectionFlags)):
        igIndent()
        when setting.content is object:
          drawSettings(setting.content, maxLabelWidth)
        igUnindent()
      igPopID()

    if setting.help.len > 0:
      igSameLine()
      igHelpMarker(setting.help)

proc calcMaxLabelWidth(settings: object): float32 =
  when settings is object:
    for name, setting in settings.fieldPairs:
      when setting is Setting:
        let label = settingLabel(name, setting)

        let width =
          if setting.kind == stSection:
            when setting.content is object:
              calcMaxLabelWidth(setting.content)
            else: 0f
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
    drawSettings(app.prefs[settings], app.maxLabelWidth)

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
