import std/[sequtils, tables]
import kdl
import src/types

const configPath {.strdefine.} = "config.kdl"
const config = parseKdlFile(configPath).decode(Config)

const resourcesPaths = @[
  configPath, 
  config.stylePath, 
  config.iconPath, 
  config.fonts.iconFontPath, 
] & config.fonts.fonts.mapIt(it.path)

proc readResources*(): Table[string, string] {.compileTime.} = 
  for path in resourcesPaths:
    result[path] = slurp(path)
