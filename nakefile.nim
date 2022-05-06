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
  X-AppImage-Arch=$arch
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
  arch = if "arch" in config: config["arch"].getString() else: "x86_64"

task "build", "Build AppImage":
  shell "nimble install -d -y"
  shell "nimble bundleData"

  discard existsOrCreateDir("AppDir")
  if "AppDir/AppRun".needsRefresh("main.nim"):
    shell "nim cpp -d:release -d:appImage --app:gui --out:AppDir/AppRun main"

  writeFile(
    &"AppDir/{name}.desktop", 
    desktop % [
      "name", name, 
      "categories", config["categories"].getSeq().mapIt(it.getString()).join(";"), 
      "version", config["version"].getString(), 
      "comment", config["comment"].getString(), 
      "arch", arch
    ]
  )
  copyFile(config["svgIconPath"].getString(), "AppDir" / &"{name}.svg")

  var appimagetoolPath = "appimagetoola"
  if not silentShell("Checking for appimagetool", appimagetoolPath, "--help"):
      appimagetoolPath = "./appimagetool-x86_64.AppImage"
      if not fileExists(appimagetoolPath):
        direSilentShell &"Dowloading {appimagetoolPath}", "wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O ", appimagetoolPath
      shell "chmod +x", appimagetoolPath

  if "ghRepo" in config:
    echo "Building updateable AppImage"
    let ghInfo = config["ghRepo"].getString().split('/')
    direShell appimagetoolPath, "-u", &"\"gh-releases-zsync|{ghInfo[0]}|{ghInfo[1]}|latest|{name}-*.AppImage.zsync\"", ".", &"AppDir/{name}-{arch}.AppImage"
  else:
    echo &"ghRepo key not in {configPath}. Skipping updateable AppImage"
    direShell appimagetoolPath, "."

  echo "Succesfully built AppImage at AppDir/"

task "run", "Build (if needed) and run AppImage":
  if "AppDir/AppRun".needsRefresh("main.nim"):
    runTask("build")

  shell "chmod a+x AppDir/*.AppImage" # Make it executable
  shell "./AppDir/*.AppImage"
