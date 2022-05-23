# <img title="Icon" width=50 height=50 src="https://github.com/Patitotective/ImTemplate/blob/main/assets/icon.svg"></img> ImTemplate
Template for making a single-windowed (or not) Dear ImGui application in Nim.

![Main window](https://user-images.githubusercontent.com/79225325/162832213-cfcf3304-3b44-4917-acb8-79a038ecd5f8.png)

## Features
- Icon font support.
- Simple about modal.
- Preferences system (with preferences modal).
- AppImage support (Linux).
- Updateable AppImage support (with [gh-releases-zsync](https://github.com/AppImage/AppImageSpec/blob/master/draft.md#github-releases)).
- Simple data resources support.
- GitHub workflow for building and uploading the AppImage and exe to the last release.
(To use NimGL in Ubuntu you might need some libraries `sudo apt install libxcursor-dev libxrandr-dev libxinerama-dev libxi-dev libgl-dev`)

## Files Structure
- `README.md`: Project's description.
- `LICENSE`: Project's license.
- `main.nim`: Application's logic.
- `resourcesdata.nim`: To bundle data resources (see [Building](#building)).
- `nakefile.md`: [Nakefile](https://github.com/fowlmouth/nake) to build the AppImage (see [Building](#building)).
- `config.nims`: Nim compile configuration.
- `config.niprefs`: Application's configuration (see [Config](#config)).
- `ImExample.nimble`: [Nimble file](https://github.com/nim-lang/nimble#creating-packages).
- `assets`: 
	- `icon.png`, `icon.svg`: App icons.
	- `style.niprefs`: App style (using https://github.com/Patitotective/ImStyle).
	- `Cousine-Regular.ttf`, `Karla-Regular.ttf`, `Roboto-Regular.ttf`, `ProggyVector Regular.ttf`: Multiple fonts so you can choose the one you like the most.
	- `forkawesome-webfont.ttf`: ForkAwesome icon font (see https://forkaweso.me/).
- `src`:
	- `icons.nim`: Helper module with [ForkAwesome](https://forkaweso.me) icons unicode points.
	- `utils.nim`: Anything used by more than one module.
	- `prefsmodal.nim`: Draw the preferences modal (called in `main.nim`)

## Icon Font
ImTemplate uses [ForkAwesome](https://forkaweso.me)'s icon font to be able to display icon as text, to do it you only need to import [`icons.nim`](https://github.com/Patitotective/ImTemplate/blob/main/src/icons.niprefs) (where the unicode points for each icon are defined), browse https://forkaweso.me/Fork-Awesome/icons, choose the one you want and, for example, if you want to use [`fa-floppy-o`](https://forkaweso.me/Fork-Awesome/icon/floppy-o/), you will write `FA_FloppyO` in string for Dear Imgui to display:
```nim
...
if igButton("Open Link " & FA_ExternalLink):
  openURL("https://forkaweso.me")
```

## App Structure
The code is designed to rely on the `App` type (defined in [`utils.niprefs`](https://github.com/Patitotective/ImTemplate/blob/main/src/utils.niprefs)), you may want to store anything that your program needs inside it.
```nim
type
  App* = ref object
    win*: GLFWWindow
    font*: ptr ImFont
    prefs*: Prefs
    cache*: PObjectType # Settings cache
    config*: PObjectType # Prefs table

    # Variables
    somefloat*: float32
    counter*: int
```
- `win`: GLFW window.
- `font`: Default app font (you may want to add more fonts).
- `prefs`: App preferences (using [niprefs](https://patitotective.github.io/niprefs/)).
- `cache`: Preferences modal cache settings (to discard or apply them).
- `config`: Configuration file (loaded from `config.niprefs`).

You may also want to store the variables your program uses here.

## Config
The application's configuration will store information about the app that you may want to change after compiled and before deployed (like the name or version).   
It is stored using [niprefs](https://patitotective.github.io/niprefs/) and by default at [`config.niprefs`](https://github.com/Patitotective/ImTemplate/blob/main/config.niprefs):
```nim
# App
name="ImExample"
comment="ImExample is a simple Dear ImGui application example"
version="0.2.0"
website="https://github.com/Patitotective/ImTemplate"
authors=["Patitotective <https://github.com/Patitotective>", "Cristobal <mailto:cristobalriaga@gmail.com>", "Inu147"]
categories=["Utility"]

# AppImage
ghRepo="Patitotective/ImTemplate"
arch="x86_64"

stylePath="assets/style.niprefs"
iconPath="assets/icon.png"
svgIconPath="assets/icon.svg"
iconFontPath="assets/forkawesome-webfont.ttf"
fontPath="assets/ProggyVector Regular.ttf" # Other options are Roboto-Regular.ttf, Cousine-Regular.ttf or Karla-Regular.ttf
fontSize=16f

# Window
minSize=[200, 200] # Width, height

# Settings for the preferences window
settings=>
  input=>
    type="input"
    default=""
    max=100
    flags="EnterReturnsTrue" # See https://nimgl.dev/docs/imgui.html#ImGuiInputTextFlags
    help="Press enter to save"
	...
```

### About Modal
Using the information from the config file, ImTemplate creates a simple about modal.

![About modal](https://user-images.githubusercontent.com/79225325/162832316-daae0575-b840-4d66-bf39-7c287d282e57.png)

### Keys Explanation
- `name`: App name.
- `comment`: App description.
- `version`: App version.
- `website`: A link where you can find more information about the app.
- `authors`: A sequence of strings to display in the about modal, a link for the author can be specified inside `<>`, e.i.: `@["Patitotective <https://github.com/Patitotective>", "Cristobal <mailto:cristobalriaga@gmail.com>"]`.
- `categories`: Sequence of [registered categories](https://specifications.freedesktop.org/menu-spec/latest/apa.html) (for the AppImage).

(AppImage)
- `ghRepo`: GitHub repo to fetch releases from (including this key will generate an `AppImage.zsync` file, include it in your releases for [updates](https://docs.appimage.org/packaging-guide/optional/updates.html#using-appimagetool), skip it to disable).
- `arch`: AppImage architechture (see https://docs.appimage.org/reference/desktop-integration.html#id2)
- `appstreamPath`: Path to the [AppStream metadata](https://docs.appimage.org/packaging-guide/optional/appstream.html) (optional).

(Paths)
- `stylePath`: App style path (using https://github.com/Patitotective/ImStyle).
- `iconPath`: Icon path.
- `svgIconPath`: Scalable icon path
- `iconFontPath`: [ForkAwesome](https://forkaweso.me)'s font path.
- `fontPath`: Font path.
- `fontSize`: Font size.

- `minSize`: Window's minimum size.
- `settings`: See [`settings`](#settings).

### `settings`
Define the preferences that the user can modify through the preferences modal.  
These preferences will be stored at `getCacheDir(config["name"])` along with the window size and position using [niprefs](https://patitotective.github.io/niprefs/). To acces them you only need to do `app.prefs["setting"]`

![Prefs modal](https://user-images.githubusercontent.com/79225325/162832406-888ac721-7c2b-4524-b9c8-0654878215e3.png)

Each child key has to have the `type` key, and depending on it the required keys may change so go check [config.niprefs](https://github.com/Patitotective/ImTemplate/blob/main/config.niprefs) to see which keys which types do require.  
```nim
settings=>
  combo=>
    type="combo"
    display="Combo box"
    help="Click me to change my value"
    default=2 # Or "c"
    items=["a", "b", "c"]
    flags="None" # See https://nimgl.dev/docs/imgui.html#ImGuiComboFlags
```
There are two special keys, `display` and `help`, `display` replaces the name to display and `help` shows a help marker with help information (`help` does not work for `Section`s).

#### Setting types
- `Input`: Input text.
- `Check`: Checkbox.
- `Slider`: Integer slider.
- `FSlider`: Float slider.
- `Spin`: Integer spin.
- `FSpin`: Float spin.
- `Combo`: Combo.
- `Radio`: Radio button.
- `Color3`: Color edit RGB.
- `Color4`: Color edit RGBA.
- `Section`: See (`Section`)[#section]

#### `Section`

![Settings section](https://user-images.githubusercontent.com/79225325/162832465-b3d8d593-dfed-4ddb-8ef6-1d652c0a32e0.png)

Section types are useful to group similar settings.  
It fits the settings at `content` inside a [collapsing header](https://nimgl.dev/docs/imgui.html#igCollapsingHeader%2Ccstring%2CImGuiTreeNodeFlags).
```nim
settings=>
  colors=>
    display="Color pickers"
    type="section"
    flags="None" # See https://nimgl.dev/docs/imgui.html#ImGuiTreeNodeFlags
    content=>
      color=>
        display="RGB color"
        type="color3" # RGB
        default="#000000" # Or [0, 0, 0] or rgb(0, 0, 0) or black
        flags="None" # See https://nimgl.dev/docs/imgui.html#ImGuiColorEditFlags
      alphaColor=>
        display="RGBA color"
        type="color4" # RGBA
        default = "#11D1C2A3" # Or [0.06666667014360428, 0.8196078538894653, 0.7607843279838562, 0.6392157077789307]
        flags="None" # See https://nimgl.dev/docs/imgui.html#ImGuiColorEditFlags
```
To access `alphaColor` you will need to do `app.prefs["colors/alphaColor"]`.

## Building
To bundle your app resources inside the compiled binary, you only need to go to `resourcesdata.nim` file and define their paths in `resources`. After that `resourcesdata` is imported in `main.nim`. Then you compile it, it statically reads those files and creates a table with `[path, data]`, to access them use `getData(path)`.
[`resourcesdata.nim`](https://github.com/Patitotective/ImTemplate/blob/main/resourcesdata.nim)
```nim
..
const resourcesPaths = [
  configPath, 
  config["iconPath"].getString(), 
  config["stylePath"].getString(), 
  config["fontPath"].getString(), 
  config["iconFontPath"].getString()
]
...
```

### Nimble
You can publish your application as a [binary package](https://github.com/nim-lang/nimble#binary-packages) with nimble.

### AppImage (Linux)
To build your app as an AppImage you will need to run `nake build`, it will install the dependencies, compile the app, check for `appimagetool` (and install it if its not found), generate the `AppDir` directory and finally build it.  
If you included the `ghRepo` key in the config file, it will generate also a `AppImage.zsync` file. You atach this file along with the `AppImage` to your GitHub release.  
If you included the `appstreamPath` key, it will get copied to `AppDir/usr/share/shareinfo/{config["name"]}.appdata.xml` (see https://docs.appimage.org/packaging-guide/optional/appstream.html).

### Creating a release
When you release your app you will want to include the AppImage for linux, to make this easier there is a [Tagged release](https://github.com/Patitotective/ImTemplate/actions/workflows/build.yml) workflow that creates a release (and tag), builds the AppImage and adds it to the release for you.  
To use it, go to the [Tagged release](https://github.com/Patitotective/ImTemplate/actions/workflows/build.yml), click _Run workflow_, enter the tag name (and check draft release if you want) and click _Run workflow_.

![image](https://user-images.githubusercontent.com/79225325/162830571-6c990649-32b2-4731-89f6-cfa39b27f3c9.png)

It can take various minutes to finish.

## Generated from ImTemplate
Apps using this template:
- [ImPasswordGen](https://github.com/Patitotective/ImPasswordGen)
- [ImClocks](https://github.com/Patitotective/ImClocks)

## About
- GitHub: https://github.com/Patitotective/ImTemplate.
- Discord: https://discord.gg/as85Q4GnR6.

Contact me:
- Discord: **Patitotective#0127**.
- Twitter: [@patitotective](https://twitter.com/patitotective).
- Email: **cristobalriaga@gmail.com**.
