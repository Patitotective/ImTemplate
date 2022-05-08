import std/[strutils, os]

# Package

version          = "0.2.0"
author           = "Patitotective"
description      = "A new awesome Dear ImGui application"
license          = "MIT"
namedBin["main"] = "ImExample"

# Dependencies

requires "nim >= 1.6.2"
requires "nake >= 1.9.4"
requires "nimgl >= 1.3.2"
requires "chroma >= 0.2.4"
requires "niprefs >= 0.2.0"
requires "stb_image >= 2.5"
requires "nimassets >= 0.2.4"
requires "https://github.com/Patitotective/ImStyle >= 0.1.0"

const resources = @["config.niprefs", "assets/icon.png", "assets/style.niprefs", "assets/ProggyVector Regular.ttf", "assets/forkawesome-webfont.ttf"]

task bundleData, "Bundle data resources":
  var resourcesArgs = "" 
  for resource in resources:
      resourcesArgs.add "-f="
      resourcesArgs.addQuoted(resource.replace('/', DirSep))
      resourcesArgs.add " "
  
  # FIXME https://github.com/xmonader/nimassets/issues/14
  exec getHomeDir() / ".nimble" / "bin" / "nimassets " & resourcesArgs

task buildApp, "Build the application":
  exec "nimble install -d -y"
  bundleDataTask()
  exec "nim cpp -d:release --app:gui " & "-o:" & namedBin["main"] & " main"

task runApp, "Build and run the application":
  exec "nimble install -d -y"
  bundleDataTask()
  exec "nim cpp -r -d:release --app:gui " & "-o:" & namedBin["main"] & " main"
