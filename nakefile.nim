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
  name = config["name"].getString() 
  arch = if "arch" in config: config["arch"].getString() else: "x86_64"

task "build", "Build AppImage":
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
      "comment", config["comment"].getString(), 
      "arch", arch
    ]
  )
  copyFile(config["iconPath"].getString(), "AppDir/.DirIcon")
  copyFile(config["svgIconPath"].getString(), &"AppDir/{name}.svg")
  if "appstreamPath" in config:
    createDir("AppDir/usr/share/metainfo")
    copyFile(config["appstreamPath"].getString(), &"AppDir/usr/share/metainfo/{name}.appdata.xml")

  var appimagetoolPath = "appimagetool"
  if not silentShell("Checking for appimagetool", appimagetoolPath, "--help"):
      withDir "AppDir":
        appimagetoolPath = "../appimagetool-x86_64.AppImage"
        if not fileExists(appimagetoolPath):
          direSilentShell &"Dowloading {appimagetoolPath}", "wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O ", appimagetoolPath
        shell "chmod +x", appimagetoolPath

  withDir "AppDir":
    if "ghRepo" in config:
      echo "Building updateable AppImage"
      let ghInfo = config["ghRepo"].getString().split('/')
      direShell appimagetoolPath, "-u", &"\"gh-releases-zsync|{ghInfo[0]}|{ghInfo[1]}|latest|{name}-*.AppImage.zsync\"", CurDir, &"{name}-{arch}.AppImage"
    else:
      echo &"ghRepo key not in {configPath}. Skipping updateable AppImage"
      direShell appimagetoolPath, CurDir

  echo "Succesfully built AppImage at AppDir/"

task "run", "Build and run AppImage":
  if "AppDir/AppRun".needsRefresh("main.nim"):
    runTask("build")

  shell "chmod a+x AppDir/*.AppImage" # Make it executable
  shell "AppDir/*.AppImage"
