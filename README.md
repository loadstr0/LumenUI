# LumenUI

A dark, monochrome Roblox UI library — window chrome, tabs, form elements, dialogs, and toasts, with a hover/tween language modeled on a real production admin panel rather than the usual Rayfield-style sidebar layout.

## Features

- **Window** — draggable/resizable chrome, fullscreen toggle, a popup nav menu (not a sidebar) with a search box to filter tabs by title, a "welcome back" splash intro on open, and automatic cleanup of any previous LumenUI window (and its keybinds) if the loadstring is re-run in the same session.
- **Elements** — `Paragraph`, `Button`, `Toggle`, `Section` + `Card` (icon grid), `Slider`, `Keybind`, `Dropdown` (with optional multi-select), `Input`, `Divider`, `ColorPicker`, `ProgressBar`.
- **Confirm** — a blocking confirmation dialog (`title`, `content`, `callback`).
- **Notify** — dismissible toast notifications with icon + auto-dismiss duration, same background as the main window (not a flat color fill), fading and sliding in/out. Multiple toasts stack newest-on-top and animate to a new slot whenever one is added or dismissed, instead of snapping.
- **Config** — tag any stateful element with a `Flag` and save/load its value to disk with `window:SaveConfig`/`window:LoadConfig`, so a hub's settings survive a script restart. `Window.new({ AutoSaveConfig = name })` saves automatically whenever the window is destroyed (including the automatic cleanup on reload), so nothing is lost even if you forget to call `SaveConfig` yourself.
- **Icons** — built-in [Lucide](https://lucide.dev) icon resolver (`Helpers.icon` / `Helpers.withIcon`), used by name (`"home"`, `"settings"`, …) with automatic fallback for unknown names.
- **Theme** — a single module of colors, fonts, corner radii, and `TweenInfo` presets; override any field to reskin the whole library.

Every animation (shimmer hover, halo hover, panel open/close, page-switch slide, content fade) is driven from `Theme.Tweens`, so retiming the whole library is a one-file change.

## Installation

LumenUI ships as a single `Loader.lua` — load it once with `loadstring`, then pull out whichever modules you need with `:Require(name)`:

```lua
local LumenUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/loadstr0/LumenUI/main/Loader.lua"))()
local Window = LumenUI:Require("Window")
```

`Loader.lua` is a generated, self-contained bundle of the library's modules — nothing else to download, no Rojo project, no sync step. It's the only supported way to consume LumenUI.

## Quickstart

```lua
local LumenUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/loadstr0/LumenUI/main/Loader.lua"))()
local Window = LumenUI:Require("Window")

local window = Window.new({
    Title = "My Hub",
    Size = UDim2.fromOffset(620, 470), -- optional
    ToggleKeybind = Enum.KeyCode.RightControl, -- optional
    AutoSaveConfig = "default", -- optional: saves every Flag automatically when this window is destroyed
})

local home = window:Tab("home", "Home", "home") -- id, title, Lucide icon name

home:Paragraph({
    Title = "Welcome",
    Desc = "This is a paragraph element.",
})

home:Button({
    Title = "Click me",
    Desc = "Runs a callback on click.",
    Icon = "zap",
    Callback = function()
        window:Notify("Clicked!", "The button was pressed.", "check", 3)
    end,
})

local toggle = home:Toggle({
    Title = "Enable feature",
    Icon = "toggle-left",
    Value = false,
    Flag = "enableFeature", -- optional: makes this value save/load with window:SaveConfig/LoadConfig
    Callback = function(value)
        print("Toggled:", value)
    end,
})
-- toggle:Set(true) -- set programmatically without firing Callback
-- toggle:Get() -- current value

home:Slider({
    Title = "Volume",
    Min = 0,
    Max = 100,
    Increment = 5,
    Value = 50,
    Flag = "volume", -- optional, same Config-persistence hook as Toggle above
    Callback = function(value)
        print("Slider:", value)
    end,
})

local keybind = home:Keybind({
    Title = "Fire action",
    Desc = "Click the key badge to rebind, Escape cancels.",
    Icon = "keyboard",
    Value = Enum.KeyCode.F,
    Callback = function(key)
        print("Bound key pressed:", key.Name)
    end,
})
-- keybind:Set(Enum.KeyCode.G) -- set programmatically without firing Callback

home:Divider({ Title = "More options" }) -- Title is optional, a plain line if omitted

local input = home:Input({
    Title = "Username",
    Desc = "Committed on Enter or clicking away.",
    Icon = "user",
    Placeholder = "Enter text...",
    Callback = function(text, enterPressed)
        print("Input:", text, enterPressed)
    end,
})
-- input:Set("preset value") -- set programmatically without firing Callback

home:Input({
    Title = "Max players",
    NumberOnly = true, -- strips non-numeric characters as you type; Callback still gets a string
    Value = "10",
    Callback = function(text)
        print("Max players:", tonumber(text))
    end,
})

local dropdown = home:Dropdown({
    Title = "Map",
    Desc = "Pick one from the list.",
    Icon = "map",
    Options = { "Kyoto", "Kawasaki", "Kasamatsu" },
    Callback = function(value)
        print("Selected:", value)
    end,
})
-- dropdown:SetOptions({ "New", "List" }) -- replaces the choices, clearing selection if stale

local multiDropdown = home:Dropdown({
    Title = "Modules",
    Desc = "Multi = true lets you pick several without closing the list.",
    Icon = "layers",
    Multi = true,
    Options = { "Combat", "Movement", "ESP" },
    Value = { "Combat" }, -- initial selection, array of strings
    Callback = function(values)
        print("Selected:", table.concat(values, ", "))
    end,
})
-- multiDropdown:Get() -- array of currently-selected strings

local progressBar = home:ProgressBar({
    Title = "Loading progress",
    Min = 0,
    Max = 100,
    Value = 25,
})
-- progressBar:Set(80) -- read-only display, no Callback; update it as your own state changes

local colorpicker = home:ColorPicker({
    Title = "Accent Color",
    Desc = "Click the swatch to expand a saturation/value square + hue bar.",
    Icon = "palette",
    Value = Color3.fromRGB(255, 0, 0),
    Callback = function(color)
        print("Color:", color)
    end,
})
-- colorpicker:Set(Color3.fromRGB(0, 255, 0)) -- set programmatically without firing Callback

local section = home:Section({
    Title = "Quick Actions",
    Desc = "A row of icon cards.",
})
section:Card({
    Title = "Restart",
    Icon = "refresh-cw",
    Callback = function()
        window:Confirm("Restart?", "This will restart the hub.", function()
            -- Window.new() automatically destroys the previous window (and disconnects its
            -- keybinds/dragging/etc.) the moment it runs - no need to call window:Destroy()
            -- yourself first. See "Called automatically on the previous window..." above.
            loadstring(game:HttpGet("https://raw.githubusercontent.com/loadstr0/LumenUI/main/Loader.lua"))()
        end)
    end,
})

-- Config persistence: any element created with a Flag (toggle/slider/dropdown above) gets
-- saved and restored together. Load fires each element's real Callback, so restoring a config
-- actually re-applies its effects, not just the widget's displayed value. Call this once all
-- your Flag elements exist - AutoSaveConfig above means you don't need a matching SaveConfig
-- call; it happens on its own whenever this window is destroyed (including on reload).
window:LoadConfig("default")
-- window:ListConfigs() -- { "default" }
-- window:DeleteConfig("default")
```

## API reference

### `Window`

| Method | Description |
|---|---|
| `Window.new(options)` | Creates a window. `options`: `Name`, `Title`, `Size` (`UDim2`), `ToggleKeybind` (`Enum.KeyCode`), `AutoSaveConfig` (string, optional — config name to save every `Flag`-tagged element to whenever this window is destroyed, including the automatic cleanup on reload). |
| `window:Tab(id, title, icon)` | Creates (or returns the existing) tab. `icon` is a Lucide icon name. First tab created becomes active automatically. |
| `window:GoTo(id)` | Switches to a tab by id. |
| `window:SetVisible(visible)` | Shows/hides the whole window (animated). |
| `window:ToggleMenu(forceState?)` | Opens/closes the nav popup; pass `true`/`false` to force a state. |
| `window:Notify(title, content, icon?, duration?)` | Shows a toast. |
| `window:Confirm(title, content, callback)` | Shows a confirmation dialog; `callback` runs on confirm. |
| `window:Destroy()` | Tears down the window and disconnects every service-level connection it owns (drag/resize, every `tab:Keybind`, `tab:Slider`/`tab:ColorPicker` dragging). Called automatically on the previous window if you re-run the loadstring in the same session - no stacked windows or leaked input listeners across reloads. |
| `window:SaveConfig(name)` | Writes the current value of every `Flag`-tagged element to `"<window Name>/Configs/<name>.json"` on disk. Returns `true`, or `false, errorString`. |
| `window:LoadConfig(name)` | Applies a saved config's values to every `Flag`-tagged element that still exists, firing each element's real `Callback` (not just updating the widget). Returns `true`, or `false, errorString`. |
| `window:ListConfigs()` | Returns an array of saved config names (no `.json`) for this window. |
| `window:DeleteConfig(name)` | Deletes a saved config. Returns `true`, or `false, errorString`. |

### Tab elements

Every tab returned by `window:Tab(...)` exposes:

| Method | Options |
|---|---|
| `tab:Paragraph(options)` | `Title`, `Desc` — a static text block, or a live status line via its returned `{ SetTitle(self, text), SetDesc(self, text), Destroy(self) }` |
| `tab:Button(options)` | `Title`, `Desc`, `Icon`, `Callback()` |
| `tab:Toggle(options)` | `Title`, `Desc`, `Icon`, `Value`, `Flag`, `Callback(value)` — returns `{ Set(self, value), Get(self) }` |
| `tab:Slider(options)` | `Title`, `Desc`, `Min`, `Max`, `Increment`, `Value`, `Flag`, `Callback(value)` — returns `{ Set(self, value), Get(self) }` |
| `tab:Keybind(options)` | `Title`, `Desc`, `Icon`, `Value` (`Enum.KeyCode`), `Flag`, `Callback(key)` — `Callback` fires when the *bound* key is pressed, not on rebind (and not on a `Flag`-driven config load either — a config load restores which key is bound, it doesn't simulate a keypress); click the badge to rebind, Escape cancels. Returns `{ Set(self, key), Get(self) }` |
| `tab:Dropdown(options)` | `Title`, `Desc`, `Icon`, `Options` (array of strings), `Value` (initial selection — a string, or an array of strings when `Multi` is set), `Multi` (bool, optional — allow selecting several options without closing the list), `Flag`, `Callback(value)` — `value` is a string normally, or an array of strings when `Multi` is set. Returns `{ Set(self, value), Get(self), SetOptions(self, newOptions) }` |
| `tab:Input(options)` | `Title`, `Desc`, `Icon`, `Placeholder`, `Value` (initial text), `NumberOnly` (bool, optional — strips non-numeric characters as you type; `Callback` still receives a string), `Flag`, `Callback(text, enterPressed)` — fires on `FocusLost` (Enter or clicking away), not every keystroke. Returns `{ Set(self, text), Get(self) }` |
| `tab:Divider(options?)` | `Title` (optional) — a thin rule for breaking a tab into visual groups |
| `tab:ColorPicker(options)` | `Title`, `Desc`, `Icon`, `Value` (`Color3`), `Flag`, `Callback(color)` — click the swatch to expand a saturation/value square + hue bar. Returns `{ Set(self, color), Get(self) }` |
| `tab:ProgressBar(options)` | `Title`, `Desc`, `Icon`, `Min`, `Max`, `Value` — read-only display, no `Callback`; call `:Set(value)` to update it as your own state changes. Returns `{ Set(self, value), Get(self) }` |
| `tab:Section(options)` | `Title`, `Desc` — returns a section with `:Card(cardOptions)` |
| `section:Card(cardOptions)` | `Title`, `Icon`, `Callback()` |

`Flag` (a unique string) is optional on every element above except `ProgressBar`. Set it to make that element's value participate in `window:SaveConfig`/`LoadConfig`/`ListConfigs`/`DeleteConfig` — see the Config example in Quickstart.

### Theme

`Theme.lua` is a plain table — colors (`Background`, `Surface`, `SurfaceRaised`, `Text`, `TextMuted`, `Glow`), fonts, `CornerRadius`/`CornerRadiusPill`, `Icons` (asset ids for chrome icons), and `Tweens` (named `TweenInfo` presets used throughout the library). Fork or edit this file to reskin LumenUI without touching any other module.

## License

All rights reserved. This library is distributed as a compiled/obfuscated build (`Loader.lua`) for use via the loadstring URL above — it is not licensed for redistribution, resale, or reuse of its source.
