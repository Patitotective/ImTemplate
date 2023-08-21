# Package

author           = "Patitotective"
description      = "A new awesome Dear ImGui application"
license          = "MIT"
backend          = "cpp"

# Dependencies

requires "nim >= 1.6.2"
requires "kdl >= 1.0.0"
requires "nimgl >= 1.3.2"
requires "stb_image >= 2.5"
requires "imstyle >= 1.0.0"
requires "openurl >= 2.0.3"
requires "tinydialogs >= 1.0.0"

import std/[strformat, options]
import src/types
import kdl

const configPath {.strdefine.} = "config.kdl"
const config = parseKdlFile(configPath).decode(Config)

version          = config.version
namedBin["main"] = config.name

let arch = getEnv("ARCH", "amd64")
let outPath = getEnv("OUTPATH", toExe &"{config.name}-{version}-{arch}")
let flags = getEnv("FLAGS")

let args = &"--app:gui --out:{outPath} --cpu:{arch} -d:configPath={configPath} {flags}"

task buildr, "Build the application for release":
  exec "nimble install -d -y"
  exec &"nim cpp -d:release {args} main.nim"

const desktop = """
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
"""

task buildapp, "Build the AppImage":
  let appimagePath = &"{config.name}-{version}-{arch}.AppImage"

  # Compile applicaiton executable
  if not existsDir("AppDir"): mkDir("AppDir")
  exec "nimble install -d -y"
  exec &"nim cpp -d:release -d:appimage {args} --out:AppDir/AppRun main.nim"

  # Make desktop file
  writeFile(
    &"AppDir/{config.name}.desktop", 
    desktop % [
      "name", config.name, 
      "categories", config.categories.join(";"), 
      "version", config.version, 
      "comment", config.comment, 
      "arch", arch
    ]
  )
  # Copy icons
  cpFile(config.iconPath, "AppDir/.DirIcon")
  cpFile(config.svgIconPath, &"AppDir/{config.name}.svg")

  if config.appstreamPath.isSome:
    mkDir("AppDir/usr/share/metainfo")
    cpFile(config.appstreamPath.get, &"AppDir/usr/share/metainfo/{config.name}.appdata.xml")

  # Get appimagetool
  var appimagetoolPath = "appimagetool"
  try:
    echo "Checking for appimagetool..."
    exec(&"{appimagetoolPath} --help")
  except OSError:
    appimagetoolPath = "./appimagetool-x86_64.AppImage"
    if not existsFile(appimagetoolPath):
      echo &"Downloading {appimagetoolPath}"
      exec &"wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O ", appimagetoolPath
      exec &"chmod +x {appimagetoolPath}"

  # Actually use appimagetool to build the AppImage
  if config.ghRepo.isSome:
    echo "Building updateable AppImage"
    exec &"{appimagetoolPath} -u \"gh-releases-zsync|{config.ghRepo.get[0]}|{config.ghRepo.get[0]}|latest|{config.name}-*-{arch}.AppImage.zsync\" AppDir {appimagePath}"
  else:
    echo &"ghRepo not defined. Skipping updateable AppImage"
    exec &"{appimagetoolPath} AppDir {appimagePath}"
