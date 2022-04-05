# ImTemplate
Template for making a single-windowed (or not) ImGui application in Nim.

![Main window](https://github.com/Patitotective/ImTemplate/blob/main/screenshots/main.png)

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
	- `Cousine-Regular.ttf`, `DroidSans.ttf`, `Karla-Regular.ttf`, `ProggyClean.ttf`, `Roboto-Regular.ttf`, `ProggyVector Regular.ttf`: Various fonts so you can choose the one you like the most.
- `src`:
	- `utils.nim`: Anything used by more than one module.
	- `prefsmodal.nim`: Create the preferences modal (called in `main.nim`)

(`.gitignore` and `screenshots/` are not relevant)

## Config
Config about the application so it doesn't need to be compiled again. It is stored using [niprefs](https://patitotective.github.io/niprefs/):
```nim
# App
name="ImExample"
comment="ImExample is a simple ImGui application example"
version="0.1.0"
website="https://github.com/Patitotective/ImTemplate"
authors=["Patitotective", "Cristobal", "Inu147"]
categories=["Utility"]

prefsPath="ImExample.niprefs"
stylePath="assets/style.niprefs"
iconPath="assets/icon.png"
svgIconPath="assets/icon.svg"
fontPath="assets/ProggyVector Regular.ttf" # Other options are Roboto-Regular.ttf, DroidSans.ttf, Cousine-Regular.ttf, NotoSans-Regular.ttf, ProggyClean.ttf or Karla-Regular.ttf
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
https://github.com/Patitotective/ImTemplate/blob/main/src/config.niprefs

### About Modal
Using the information from the config file, ImTemplate creates a simple about modal.
![About modal](https://github.com/Patitotective/ImTemplate/blob/main/screenshots/aboutmodal.png)

### Keys Explanation
- `name`: Application's name.
- `comment`: Application's description.
- `version`: Application's version.
- `website`: A link where you can find more information about the app.
- `authors`: A sequence of strings to display in the about modal.
- `categories`: Sequence of [registered categories](https://specifications.freedesktop.org/menu-spec/latest/apa.html) (for the AppImage).

(Paths)
- `prefsPath`: The path to save the (user) prefs file.
- `stylePath`: The path of the application style (using https://github.com/Patitotective/ImStyle).
- `iconPath`: The path of the application icon.
- `fontPath`: The path of the application font.
- `fontSize`: The (float) size of the font.

- `minSize`: Window's minimum size.
- `settings`: See [`settings`](#settings).

### `settings`
Define the preferences the user can modify from the preferences window (preferences that will be saved at `config["prefsPath"]`).
![Preferences modal](https://github.com/Patitotective/ImTemplate/blob/main/screenshots/prefsmodal.png)

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
![Settings section](https://github.com/Patitotective/ImTemplate/blob/main/screenshots/prefsmodal1.png)

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
installFiles = @["config.niprefs", "assets/icon.png", "assets/style.niprefs", "assets/ProggyVector Regular.ttf"]

...
```

### AppImage (Linux)
You can also build your app as an AppImage, you only need to follow these steps:
1. Install [appimagetool](https://appimage.github.io/appimagetool/) (For Debian/Ubuntu/Arch)
```sh
sudo wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O /usr/local/bin/appimagetool
sudo chmod +x /usr/local/bin/appimagetool
```
2. (Install `nimble install nake` and) run `nake build` (or to build and run it use `nake run`)

After that a new `ImExample-x86_64.AppImage` (architecture may change) file should be created inside `AppDir`.

#### Resources
If you build your application as an AppImage you may want to have some resources like the icon or the font.  
These are defined in the `nakefile.nim` module, the default resources are:
```nim
resources = [
  configPath, 
  config["iconPath"].getString(), 
  config["stylePath"].getString(), 
  config["fontPath"].getString()
]
```
These resources are going to be copied from their path to `AppDir/data`.  
Then in `main.nim` every time you need to access to some file you call `path.getPath()`.  
It's (only `when defined(appImage)`) going to look for that path inside the `data` directory inside `APPDIR` environment variable.

(You could also try [Snap](https://snapcraft.io/) or [Flatpak](https://flatpak.org/) and if you get it working please let me know).

## Generated from ImTemplate
- [ImPasswordGen](https://github.com/Patitotective/ImPasswordGen)

## About
- GitHub: https://github.com/Patitotective/ImTemplate.
- Discord: https://discord.gg/as85Q4GnR6.

Contact me:
- Discord: **Patitotective#0127**.
- Twitter: [@patitotective](https://twitter.com/patitotective).
- Email: **cristobalriaga@gmail.com**.
