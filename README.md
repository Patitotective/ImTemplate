# ImTemplate
Template for making a single-windowed ImGui application in Nim.

![Main window](https://github.com/Patitotective/ImTemplate/blob/main/screenshots/main.png)

## Structure
- `main.nim`: Application logic.
- `assets`: 
	- The application icon in `.png` and `.svg`
	- Various fonts so you can choose the one you like the most.
- `src`:
	- `config.niprefs`: Application configuration (see the next section).
	- `style.niprefs`: Application style (using https://github.com/Patitotective/ImStyle).
	- `common.nim`: Simple procedures or types used by other modules.
	- `prefsmodal.nim`: Create the preferences modal (called in `main.nim`)

## Config
Config about the application so it doesn't need to be compiled again. It is stored using [niprefs](https://patitotective.github.io/niprefs/).  
It looks like:
```nim
# App
name="ImExample"
version="0.1.0"
website="https://github.com/Patitotective/ImTemplate"
authors=["Patitotective", "Cristobal", "Andoni"]

prefsPath="prefs.niprefs"
stylePath="src/style.niprefs"
iconPath="assets/icon.png"
fontPath="assets/ProggyClean.ttf" # Other options are Roboto-Regular.ttf, DroidSans.ttf, Cousine-Regular.ttf, NotoSans-Regular.ttf or Karla-Regular.ttf
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

Explanation:
- `name`: Used for the title and about modal.
- `version`: Used for the about modal.
- `website`: A link where you can find more information about the app.
- `authors`: A sequence of strings to display in the about modal.

- `prefsPath`: The path to save the (user) prefs file.
- `stylePath`: The path of the application style (using https://github.com/Patitotective/ImStyle).
- `iconPath`: The path of the application icon.
- `fontPath`: The path of the application font.
- `fontSize`: The (float) size of the font.

- `minSize`: Window's minimum size.
- `settings`: ...

### `settings`
Define the preferences the user can modify from the preferences window (which will be saved at `prefsPath`).
![Preferences modal](https://github.com/Patitotective/ImTemplate/blob/main/screenshots/prefsmodal.png)

All the `settings` children keys will get stored at `prefsPath` except the ones of type `Section`.  
Example:
- `input`: This will be saved at `prefsPath` as a key.
- `type`: See [SettingTypes](https://github.com/Patitotective/ImTemplate/blob/main/src/common.nim#L22).
- `default`: Default value.
- `max`: Max buffer length (Not available for all types).
- `flags`: Integer, string or sequence with the widget flags.
- `help`: If passed, display a help marker with this message.

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

Take a look at [src/config.niprefs](https://github.com/Patitotective/ImTemplate/blob/main/src/config.niprefs#L17).

## Building
Because of ImGui and Nim, build your application is really easy.  
Just do `nimble build` and it will check all your app dependencies defined at `ImExample.nimble` and generate a binary (`ImExample`).  
To distribute it, you can [add it to nimble packages list](https://github.com/nim-lang/packages), host it on git cloud repository so people can install it with nimble or you could try and use some other tool (like [Snap](https://snapcraft.io/), [Flatpak](https://flatpak.org/) or [AppImage](https://appimage.org/)).

## About
- GitHub: https://github.com/Patitotective/ImTemplate.
- Discord: https://discord.gg/as85Q4GnR6.

Contact me:
- Discord: **Patitotective#0127**.
- Tiwtter: [@patitotective](https://twitter.com/patitotective).
- Email: **cristobalriaga@gmail.com**.
