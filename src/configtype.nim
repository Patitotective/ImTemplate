import std/options

type

  GlyphRanges* = enum
    Default, ChineseFull, ChineseSimplified, Cyrillic, Japanese, Korean, Thai, Vietnamese

  Font* = object
    path*: string
    size*: float32
    glyphRanges*: GlyphRanges

proc font*(path: string, size: float32, glyphRanges = GlyphRanges.Default): Font =
  Font(path: path, size: size, glyphRanges: glyphRanges)

type
  Config* = object
    name* = "ImExample"
    comment* = "ImExample is a simple Dear ImGui application example"
    version* = "2.0.0"
    website* = "https://github.com/Patitotective/ImTemplate"
    authors* = [
      (name: "Patitotective", url: "https://github.com/Patitotective"),
      ("Cristobal", "mailto:cristobalriaga@gmail.com"),
      ("Omar Cornut", "https://github.com/ocornut"),
      ("Beef, Yard, Rika", ""),
      ("and the Nim community :]", ""),
      ("Inu147", ""),
    ]
    categories* = ["Utility"]

    stylePath* = "assets/style.kdl"
    iconPath* = "assets/icon.png"
    svgIconPath* = "assets/icon.svg"

    iconFontPath* = "assets/forkawesome-webfont.ttf"
    fonts* = [
      font("assets/ProggyVector Regular.ttf", 16f), # Other options are Roboto-Regular.ttf, Cousine-Regular.ttf or Karla-Regular.ttf
      font("assets/NotoSansJP-Regular.otf", 16f, GlyphRanges.Japanese),
    ]

    # AppImage
    ghRepo* = (user: "Patitotective", repo: "ImTemplate").some
    appstreamPath* = ""

    # Window
    minSize* = (w: 200i32, h: 200i32) # < 0: don't care

