# <img title="Icon" width=50 height=50 src="https://github.com/Patitotective/ImTemplate/blob/main/assets/icon.png"></img> ImTemplate
Template for making a single-windowed Dear ImGui application in Nim.

![image](https://github.com/Patitotective/ImTemplate/assets/79225325/6acb8632-1505-4cf9-a520-80255a13c499)

(Check [ImDemo](https://github.com/Patitotective/ImDemo) for a **full** example)

## Features
- Icon font support.
- About modal.
- Preferences system.
- Settings modal.
- AppImage support (Linux).
- Updateable AppImage support (with [gh-releases-zsync](https://github.com/AppImage/AppImageSpec/blob/master/draft.md#github-releases)).
- Simple data resources support (embed files into the binary).
- GitHub workflow for building and uploading the AppImage and `.exe` as assets.
- Non-blocking (using a [`std/threadpool`](https://nim-lang.org/docs/threadpool.html)) native system dialogs using [`tinydialogs`](https://github.com/Patitotective/tinydialogs).

(To use NimGL in Ubuntu you might need some libraries `sudo apt install libxcursor-dev libxrandr-dev libxinerama-dev libxi-dev libgl-dev`)

## Files Structure
- `README.md`: Project's description.
- `LICENSE`: Project's license.
- `main.nim`: Application's logic.
- `resources.nim`: To bundle data resources (see [Bundling](#bundling)).
- `config.nims`: Nim compile configuration.
- `ImExample.nimble`: [Nimble file](https://github.com/nim-lang/nimble#creating-packages).
- `assets`:
  - `icon.png`, `icon.svg`: App icons.
  - `style.kdl`: Style (using [ImStyle](https://github.com/Patitotective/ImStyle)).
  - `Cousine-Regular.ttf`, `Karla-Regular.ttf`, `Roboto-Regular.ttf`, `ProggyVector Regular.ttf`: Multiple fonts so you can choose the one you like the most.
  - `forkawesome-webfont.ttf`: ForkAwesome icon font (see https://forkaweso.me/).
- `src`:
  - `types.nim`: Type definitions used by other modules.
  - `icons.nim`: Helper module with [ForkAwesome](https://forkaweso.me) icons unicode points.
  - `utils.nim`: Useful procedures, general types or anything used by more than one module.
  - `settingsmodal.nim`: Draw the settings modal

## Icon Font
ImTemplate uses [ForkAwesome](https://forkaweso.me)'s icon font to be able to display icon in labels, to do it you only need to import [`icons.nim`](https://github.com/Patitotective/ImTemplate/blob/main/src/icons.nim) (where the unicode points for each icon are defined), browse https://forkaweso.me/Fork-Awesome/icons, choose the one you want and, for example, if you want to use [`fa-floppy-o`](https://forkaweso.me/Fork-Awesome/icon/floppy-o/), you will write `FA_FloppyO` in a string:
```nim
...
# main.nim
import src/icons

if igButton("Open Link " & FA_ExternalLink):
  openURL("https://forkaweso.me")
```

## App Structure
The code is designed to rely on the `App` type (defined in [`utils.nim`](https://github.com/Patitotective/ImTemplate/blob/main/src/utils.nim)), you may want to store anything that your program needs inside it.
```nim
type
  App* = object
    win*: GLFWWindow
    config*: Config
    prefs*: KdlPrefs[Prefs]
    fonts*: array[Config.fonts.len, ptr ImFont]
    resources*: Table[string, string]

    maxLabelWidth*: float32
    messageBoxResult*: FlowVar[Button]
    # Add your variables here
    ...
```
- `win`: GLFW window.
- `fonts`: An array containing the loaded fonts from `Config.fonts`.
- `prefs`: See [Prefs](#prefs).
- `config`: Configuration file (loaded from `config.toml`).
- `resources`: Data resources where the key is the filename and the value is the binary data.
- `maxLabelWidth`: This is a value that's used to draw the settingsmodal (see https://github.com/Patitotective/ImTemplate/blob/main/src/settingsmodal.nim)
- `messageBoxResult`: This variable stores the result to a message box dialog opened by [`tinydialogs`](https://github.com/Patitotective/tinydialogs), it uses the `FlowVar` type since it's the result of a spawned thread.

## Config
The configuration stores data like name and version of the application, it is stored in its type definition in `src/configtype.nim` using `constructor/defaults` to define the default values:
```nim
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
    categories* = "Utility"

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
```
### Fields Explanation
- `name`: App's name.
- `comment`: App's description.
- `version`: App's version.
- `website`: A link where you can find more information about the app.
- `authors`: An array containing information about the authors.
- `categories`: Sequence of [registered categories](https://specifications.freedesktop.org/menu-spec/latest/apa.html) (for the AppImage).
- `stylePath`: App's ImStyle path (using https://github.com/Patitotective/ImStyle).
- `iconPath`: PNG icon path.
- `svgIconPath`: Scalable icon path
- `iconFontPath`: [ForkAwesome](https://forkaweso.me)'s font path.
- `fonts`: An array of `Font` objects containing the font's path, size and range of glyphs for japanese, korean, chinese, etc.
- `ghRepo`: GitHub repo to fetch releases from (if it's some it will generate an `AppImage.zsync` file, include it in your releases for [AppImage updates](https://docs.appimage.org/packaging-guide/optional/updates.html#using-appimagetool)).
- `appstreamPath`: Path to the [AppStream metadata](https://docs.appimage.org/packaging-guide/optional/appstream.html).
- `minSize`: Window's minimum size, use numbers less than zero to disable a limit.

### About Modal
Using the information from the config object, ImTemplate creates a simple about modal.

![image](https://github.com/Patitotective/ImTemplate/assets/79225325/bd018f26-4d8f-4dd4-a7ea-cfece401a3b5)

## Prefs
The preferences are data can change during runtime and data that you want to store for the future like the position and size of the window, this includes the settings like the language and theme.
The preferences are saved in a KDL file (using [kdl/prefs](https://patitotective.github.io/kdl-nim/kdl/prefs.html)).
You just have to provide an object including all the data you want to store as fields:
```nim
type
  Prefs* {.defaults: {defExported}.} = object
    maximized* = false # Was the window maximized when the app was closed?
    winpos* = (x: -1i32, y: -1i32) # Window position
    winsize* = (w: 600i32, h: 650i32) # Window size
    settings* = initSettings()
```

### Settings
The settings are preferences that the user can modify through the settings modal.

![image](https://github.com/Patitotective/ImTemplate/assets/79225325/0b268d5a-e034-4541-be96-954263bab2ae)

You can define all the settings' settings (i.e.: combobox, checkbox, input, etc.) through the `Settings` object:
```nim
type
  Os* {.defaults: {}.} = object
    file* = fileSetting(display = "Text File", filterPatterns = @["*.txt", "*.nim", "*.kdl", "*.json"])
    files* = filesSetting(display = "Multiple files", singleFilterDescription = "Anything", default = @[".bashrc", ".profile"])
    folder* = folderSetting(display = "Folder")

  Numbers* {.defaults: {}.} = object
    spin* = spinSetting(display = "Int Spinner", default = 4, range = 0i32..10i32)
    fspin* = fspinSetting(display = "Float Spinner", default = 3.14, range = 0f..10f)
    slider* = sliderSetting(display = "Int Slider", default = 40, range = -100i32..100i32)
    fslider* = fsliderSetting(display = "Float Slider", default = -2.5, range = -10f..10f)

  Colors* {.defaults: {}.} = object
    rgb* = rgbSetting(default = [1f, 0f, 0.2f])
    rgba* = rgbaSetting(default = [0.4f, 0.7f, 0f, 0.5f], flags = @[AlphaBar, AlphaPreviewHalf])

  Sizes* = enum
    None, Huge, Big, Medium, Small, Mini

  Settings* {.defaults: {}.} = object
    input* = inputSetting(display = "Input", default = "Hello World")
    input2* = inputSetting(
      display = "Custom Input", hint = "Type...",
      help = "Has a hint, 10 characters maximum and only accepts on return",
      limits = 0..10, flags = @[ImGuiInputTextFlags.EnterReturnsTrue]
    )
    check* = checkSetting(display = "Checkbox", default = true)
    combo* = comboSetting(display = "Combo box", items = Sizes.toSeq, default = None)
    radio* = radioSetting(display = "Radio button", items = @[Big, Medium, Small], default = Medium)
    os* = sectionSetting(display = "File dialogs", help = "Single file, multiple files and folder pickers", content = initOs())
    numbers* = sectionSetting(display = "Spinners and sliders", content = initNumbers())
    colors* = sectionSetting(display = "Color pickers", content = initColors())
```

## Building
To build your app you may want to run `nimble buildr` task.
You can set the following environment variables to change the building process:
- `ARCH`: the architecture used to compile the binary, by default `amd64`.
- `OUTPATH`: the path of the binary file (or exe file on Windows), by default "name-version-arch"
- `FLAGS`: any other flags you want to pass to the compiler, optional.

**_Note: Unfortunately on Window most of the times Nim binaries are flagged as virus, see https://github.com/nim-lang/Nim/issues/17820._**

### Bundling
To bundle your app resources inside the compiled binary, you only need to go to [`resources.nim`](https://github.com/Patitotective/ImTemplate/blob/main/resources.nim) file and define their paths in the `resourcesPaths` array.
After that `resources` is imported in `main.nim`. So when you compile it, it statically reads those files and creates a table with the binary data.
To access them use `app.resources["path"]`.
By default this is how `resourcesPaths` looks like:
```nim
...
const resourcesPaths = @[
  config.stylePath,
  config.iconPath,
  config.iconFontPath,
] & config.fonts.mapIt(it.path) # Add the paths of each font
...
```

### Nimble
You can publish your application as a [binary package](https://github.com/nim-lang/nimble#binary-packages) with nimble.

### AppImage (Linux)
To build your app as an AppImage you will need to run `nimble buildapp`, it will install the dependencies, compile the app, check for `appimagetool` (and install it if its not found in the `$PATH`), generate the `AppDir` directory and finally build the AppImage.
If you included `ghRepo` in the config, it will also generate an `AppImage.zsync` file. You should attach this file along with the `AppImage` to your GitHub release.
If you included `appstreamPath`, it will get copied to `AppDir/usr/share/shareinfo/{config.name}.appdata.xml` (see https://docs.appimage.org/packaging-guide/optional/appstream.html).

### Creating a release
ImTemplate has a [`build.yml` workflow](https://github.com/Patitotective/ImTemplate/blob/main/.github/workflows/build.yml) that automatically when you publish a release, builds an AppImage and an `.exe` file to then upload them as assets to the release.
This can take several minutes.

## Generated from ImTemplate
Apps using this template:
- [ImDemo](https://github.com/Patitotective/ImDemo).
- [ImPasswordGen](https://github.com/Patitotective/ImPasswordGen).
- [ImClocks](https://github.com/Patitotective/ImClocks).
- [ImThemes](https://github.com/Patitotective/ImThemes).

(Contact me if you want your app to be added here).

## About
- Icon Font: https://forkaweso.me (MIT).
- GitHub: https://github.com/Patitotective/ImTemplate.
- Discord: https://discord.gg/U23ZQMsvwc.

Contact me:
- Discord: **Patitotective#0127**.
- Twitter: [@patitotective](https://twitter.com/patitotective).
- Email: **cristobalriaga@gmail.com**.
