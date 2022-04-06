import std/[strformat, strutils, sequtils, os]

import nake
import niprefs

proc checkPath(path: string) = 
  ## Iterate through `path.parentDirs` from the root creating all the directories that do not exist.
  ## **Example:**
  ## ```nim
  ## checkPath("a/b/c")
  ## checkPath("a/b/c/d.png".parentDir)
  ## ```
  for dir in path.normalizedPath().parentDirs(fromRoot=true):
    discard existsOrCreateDir(dir)

proc checkFile(path: string) = 
  ## Iterate through `path.parentDir.parentDirs` from the root creating all the directories that do not exist.
  ## **Example:**
  ## ```nim
  ## checkFile("a/b/c") # Takes c as a file, not as a directory
  ## checkFile("a/b/c/d.png") # Only creates a/b/c directories
  ## ```
  for dir in path.parentDir.parentDirs(fromRoot=true):
    discard existsOrCreateDir(dir)

const
  resourcesDir = "data"
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
    config["fontPath"].getString()
  ]
  name = config["name"].getString() 

task "build", "Build AppImage application":
  checkPath("AppDir")
  writeFile(
    &"AppDir/{name}.desktop", 
    desktop % [
      "name", name, 
      "categories", config["categories"].getSeq().mapIt(it.getString()).join(";"), 
      "version", config["version"].getString(), 
      "comment", config["comment"].getString()
    ]
  )
  copyFile(config["iconPath"].getString(), "AppDir" / ".DirIcon")
  copyFile(config["svgIconPath"].getString(), "AppDir" / &"{name}.svg")

  shell "nim cpp -d:release -d:appImage --app:gui --out:AppDir/AppRun main.nim"

  # Add resources
  checkPath("AppDir" / resourcesDir)

  for name, path in resources:
    copyFile(path, "AppDir" / resourcesDir / path.extractFilename())

  let appDir = "AppDir".absolutePath()
  withDir "AppDir":
    shell &"appimagetool ."

task "run", "Build (if needed) and run AppImage application":
  if "AppDir/AppRun".needsRefresh("main.nim"):
    runTask("build")
  
  # First .AppImage in AppDir starting with name
  var appFile = walkFiles(&"AppDir/{name}*.AppImage").toSeq[0]

  shell &"chmod a+x {appFile}" # Make it executable
  shell &"./{appFile}"
