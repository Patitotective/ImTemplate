# Package

version          = "0.1.0"
author           = "Patitotective"
description      = "A new awesome ImGui application"
license          = "MIT"
bin              = @["main"]
namedBin["main"] = "ImExample"

# Dependencies

requires "nim >= 1.6.2"
requires "chroma >= 0.2.4"
requires "niprefs >= 0.1.0"
requires "imstyle >= 0.1.0"
requires "nimgl >= 1.3.2"
requires "stb_image >= 2.5"
