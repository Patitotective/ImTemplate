# <img title="Icon" width=50 height=50 src="https://github.com/Patitotective/ImTemplate/blob/main/assets/icon.svg"></img> ImTemplate
Template for making a single-windowed (or not) Dear ImGui application in Nim.

![Main window](https://user-images.githubusercontent.com/79225325/162832213-cfcf3304-3b44-4917-acb8-79a038ecd5f8.png)

## Features
- AppImage support (for Linux).
- Icon font support.
- Configuration system.
- Data resources support.
- Preferences system (with a preferences modal).
- GitHub workflow for releasing a tag and building the AppImage.

## Structure
- `README.md`: Project's description (in markdown).
- `main.nim`: Application's logic.
- `config.nims`: Nim compile configuration.
- `ImExample.nimble`: [Nimble file](https://github.com/nim-lang/nimble#creating-packages).
- `LICENSE`: Project's license.
- `nakefile.md`: Used to build an AppImage (see [Building](#building)).
- `config.niprefs`: Application's configuration (see [Config](#config)).
- `assets`: 
	- `icon.png`, `icon.svg`: Application's icon.
	- `style.niprefs`: Application's style (using https://github.com/Patitotective/ImStyle).
	- `Cousine-Regular.ttf`, `Karla-Regular.ttf`, `Roboto-Regular.ttf`, `ProggyVector Regular.ttf`: Various fonts so you can choose the one you like the most.
	- `forkawesome-webfont.ttf`: ForkAwesome icon font (see https://forkaweso.me/).
- `src`:
	- `icons.nim`: Helper module with ForkAwesome icons unicode points.
	- `utils.nim`: Anything used by more than one module.
	- `prefsmodal.nim`: Draw the preferences modal (called in `main.nim`)

## Config
The application's configuration will store information about the app that you may want to change after compiled and before deployed (like the name or version).   
It is stored using [niprefs](https://patitotective.github.io/niprefs/) and by default at [`config.niprefs`](https://github.com/Patitotective/ImTemplate/blob/main/src/config.niprefs):
```nim
# App
name="ImExample"
comment="ImExample is a simple Dear ImGui application example"
version="0.1.0"
website="https://github.com/Patitotective/ImTemplate"
authors=["Patitotective", "Cristobal", "Inu147"]
categories=["Utility"]

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
    default="Hellow World"
    max=100
    flags="None" # See https://nimgl.dev/docs/imgui.html#ImGuiInputTextFlags
    help="Help Message"
	...
```

### About Modal
Using the information from the config file, ImTemplate creates a simple about modal.

![About modal](https://user-images.githubusercontent.com/79225325/162832316-daae0575-b840-4d66-bf39-7c287d282e57.png)

### Keys Explanation
- `name`: Application's name.
- `comment`: Application's description.
- `version`: Application's version.
- `website`: A link where you can find more information about the app.
- `authors`: A sequence of strings to display in the about modal.
- `categories`: Sequence of [registered categories](https://specifications.freedesktop.org/menu-spec/latest/apa.html) (for the AppImage).

(Paths)
- `prefsPath`: Prefs's path (using https://patitotective.github.io/niprefs/).
- `stylePath`: Application's style path (using https://github.com/Patitotective/ImStyle).
- `iconPath`: Application's icon path.
- `iconFontPath`: ForkAwesome's font path.
- `fontPath`: Application's font path.
- `fontSize`: Font's size.

- `minSize`: Window's minimum size.
- `settings`: See [`settings`](#settings).

### `settings`
Define the preferences the user can modify from the preferences window (preferences that will be saved at `config["prefsPath"]`).

![Prefs modal](https://user-images.githubusercontent.com/79225325/162832406-888ac721-7c2b-4524-b9c8-0654878215e3.png)

All the `settings` children keys will get stored at `config["prefsPath"]` with [niprefs](https://patitotective.github.io/niprefs/) (`input` in this example).
Depending on each `type`, required keys may change, so go check [config.niprefs](https://github.com/Patitotective/ImTemplate/blob/main/src/config.niprefs#L24) to see which keys which types require.  
In the case of `input`, these are the required keys.
- `type`: See [SettingTypes](https://github.com/Patitotective/ImTemplate/blob/main/src/utils.nim#L22).
- `default`: Default value.
- `max`: Max buffer length (Not available for all types).
- `flags`: Integer, string or sequence with the widget flags (https://nimgl.dev/docs/imgui.html#ImGuiInputTextFlags).
- `help`: Display a help marker with this message. (Optional)

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

#### `Section`

![Settings section](https://user-images.githubusercontent.com/79225325/162832465-b3d8d593-dfed-4ddb-8ef6-1d652c0a32e0.png)

Section types are useful to group similar settings.  
It fits the settings at `content` inside a [collapsing header](https://nimgl.dev/docs/imgui.html#igCollapsingHeader%2Ccstring%2CImGuiTreeNodeFlags).
```nim
...
settings=>
  colors=>
    type="section"
    flags="None" # See https://nimgl.dev/docs/imgui.html#ImGuiTreeNodeFlags
    content=>
      color=>
        type="color3" # RGB
        default="#000000" # Or [0, 0, 0] or rgb(0, 0, 0) or black
        flags="None" # See https://nimgl.dev/docs/imgui.html#ImGuiColorEditFlags
      alpha color=>
        type="color4" # RGBA
        default = "#11D1C2A3" # Or [0.06666667014360428, 0.8196078538894653, 0.7607843279838562, 0.6392157077789307] xD
        flags="None" # See https://nimgl.dev/docs/imgui.html#ImGuiColorEditFlags
```

Take a look at [`config.niprefs`](https://github.com/Patitotective/ImTemplate/blob/main/src/config.niprefs#L24).

## Building
### Nimble
You can publish your application as a [binary package](https://github.com/nim-lang/nimble#binary-packages) with nimble.  
Or you can just upload it to GitHub (or similar).  
(e.g.: To install ImExample you can `nimble install https://github.com/Patitotective/ImTemplate`)

#### Resources
To include the application resources in the binary package, you need to specify them in the `.nimble` file:
```nim
# Package

...
installFiles = @["config.niprefs", "assets/icon.png", "assets/style.niprefs", "assets/ProggyVector Regular.ttf", "assets/forkawesome-webfont.ttf"]

...
```

### AppImage (Linux)
You can also build your app as an AppImage, you only need to follow these steps:
1. Install [appimagetool](https://appimage.github.io/appimagetool/) (For Debian/Ubuntu/Arch)
```sh
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O /usr/local/bin/appimagetool
sudo chmod +x /usr/local/bin/appimagetool
```
2. Run `nake build` (or to build and run it use `nake run`)

After that a new `ImExample-x86_64.AppImage` (architecture may change) file should be created inside `AppDir`.

#### Resources
If you build your application as an AppImage you may want to have some resources like the icon or the font.  
These are defined in the `nakefile.nim` module, the default resources are:
```nim
...
resources = [
  configPath, 
  config["iconPath"].getString(), 
  config["stylePath"].getString(), 
  config["iconFontPath"].getString()
  config["fontPath"].getString()
]
```
These resources are going to be copied from their path to `AppDir/data`.  
Then in `main.nim` every time you need to access to some file you call `path.getPath()`.  
It's (only `when defined(appImage)`) going to look for that path inside the `data` directory inside `APPDIR` environment variable.

(You could also try [Snap](https://snapcraft.io/) or [Flatpak](https://flatpak.org/) and if you get it working please let me know).

### Creating a release
When you release your app you will want to include the AppImage for linux, to make this easier there is a [Tagged release](https://github.com/Patitotective/ImTemplate/actions/workflows/build.yml) workflow that creates a release (and tag), builds the AppImage and adds it to the release for you.  
To use it, go to the [Tagged release](https://github.com/Patitotective/ImTemplate/actions/workflows/build.yml), click _Run workflow_, enter the tag name (and check draft release if you want) and click _Run workflow_.

![image](https://user-images.githubusercontent.com/79225325/162830571-6c990649-32b2-4731-89f6-cfa39b27f3c9.png)

It can take various minutes to finish.

## Generated from ImTemplate
- [ImPasswordGen](https://github.com/Patitotective/ImPasswordGen)
- [ImClocks](https://github.com/Patitotective/ImClocks)

(To run NimGL in Linux you might need some libraries `sudo apt-get install libxcursor-dev libxrandr-dev libxinerama-dev libxi-dev libgl-dev`)

## About
- GitHub: https://github.com/Patitotective/ImTemplate.
- Discord: https://discord.gg/as85Q4GnR6.

Contact me:
- Discord: **Patitotective#0127**.
- Twitter: [@patitotective](https://twitter.com/patitotective).
- Email: **cristobalriaga@gmail.com**.
