import std/[strformat, strutils, sequtils, os]

import nake
import niprefs

const
  configPath = "config.niprefs"
  desktop = """
  [Desktop Entry]
  Name=$name
  Exec=AppRun
  Comment=$comment
  Icon=$name
  Type=Application
  Categories=$categories

  X-AppImage-Name=$name
  X-AppImage-Version=$version
  """.dedent()
let
  config = configPath.readPrefs()
  resources = [
    configPath, 
    config["iconPath"].getString(), 
    config["stylePath"].getString(), 
    config["iconFontPath"].getString(),
    config["fontPath"].getString()
  ]
  name = config["name"].getString() 

task "build", "Build AppImage application":
  shell "nimble install -d -y"

  discard existsOrCreateDir("AppDir")
  if "AppDir/AppRun".needsRefresh("main.nim"):
    shell "nim cpp -d:release -d:appImage --app:gui --out:AppDir/AppRun main"

  writeFile(
    &"AppDir/{name}.desktop", 
    desktop % [
      "name", name, 
      "categories", config["categories"].getSeq().mapIt(it.getString()).join(";"), 
      "version", config["version"].getString(), 
      "comment", config["comment"].getString()
    ]
  )
  copyFile(config["svgIconPath"].getString(), "AppDir" / &"{name}.svg")

  let appimagetoolPath = "appimagetool-x86_64.AppImage"
  if not silentShell("Trying to build AppImage with appimagetool", "appimagetool AppDir"): 
    if not fileExists(appimagetoolPath):
      silentShell &"Dowloading {appimagetoolPath}", "wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O ", appimagetoolPath
      shell "chmod +x ", appimagetoolPath
    shell appimagetoolPath, " AppDir"

task "run", "Build (if needed) and run AppImage application":
  if "AppDir/AppRun".needsRefresh("main.nim"):
    runTask("build")
  
  # First .AppImage in AppDir starting with name
  var appFile = walkFiles(&"AppDir/{name}*.AppImage").toSeq[0]

  shell &"chmod a+x {appFile}" # Make it executable
  shell &"./{appFile}"
