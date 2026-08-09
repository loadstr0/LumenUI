# LumenUI

A dark, monochrome Roblox UI library — window chrome, tabs, form elements, dialogs, and toasts, with a hover/tween language modeled on a real production admin panel rather than the usual Rayfield-style sidebar layout.

## Features

- **Window** — draggable/resizable chrome, fullscreen toggle, a popup nav menu (not a sidebar), and a "welcome back" splash intro on open.
- **Elements** — `Paragraph`, `Button`, `Toggle`, `Section` + `Card` (icon grid), `Slider`.
- **Confirm** — a blocking confirmation dialog (`title`, `content`, `callback`).
- **Notify** — dismissible toast notifications with icon + auto-dismiss duration.
- **Icons** — built-in [Lucide](https://lucide.dev) icon resolver (`Helpers.icon` / `Helpers.withIcon`), used by name (`"home"`, `"settings"`, …) with automatic fallback for unknown names.
- **Theme** — a single module of colors, fonts, corner radii, and `TweenInfo` presets; override any field to reskin the whole library.

Every animation (shimmer hover, halo hover, panel open/close, page-switch slide, content fade) is driven from `Theme.Tweens`, so retiming the whole library is a one-file change.

## Installation

LumenUI ships as a single `Loader.lua` — load it once with `loadstring`, then pull out whichever modules you need with `:Require(name)`:

```lua
local LumenUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/loadstr0/LumenUI/main/Loader.lua"))()
local Window = LumenUI:Require("Window")
```

`Loader.lua` is a generated, self-contained bundle of every file in [`src/`](src/) (each module embedded as its own Luau chunk, wired together behind a small `ctx:Require` resolver) — nothing else to download, no Rojo project required.

If you're syncing `src/` into your own project instead (Rojo, a ModuleScript tree, etc.), each file follows the same factory convention `Loader.lua` uses internally:

```lua
-- every module: Window.lua, Elements.lua, Theme.lua, ...
return function(ctx)
    -- ctx:Require("Theme"), ctx:Require("Helpers"), etc.
    return Window -- (or Elements, Theme, ...)
end
```

so you can provide your own `ctx:Require(name)` (resolving `require(folder[name])(ctx)`, cached per name) instead of using `Loader.lua`. `DevBridge/build-loader.ps1` shows exactly how `Loader.lua` itself is assembled, and regenerates it after any `src/` change.

## Quickstart

```lua
local LumenUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/loadstr0/LumenUI/main/Loader.lua"))()
local Window = LumenUI:Require("Window")

local window = Window.new({
    Title = "My Hub",
    Size = UDim2.fromOffset(620, 470), -- optional
    ToggleKeybind = Enum.KeyCode.RightControl, -- optional
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
    Callback = function(value)
        print("Toggled:", value)
    end,
})
-- toggle:Set(true) -- set programmatically without firing Callback

home:Slider({
    Title = "Volume",
    Min = 0,
    Max = 100,
    Increment = 5,
    Value = 50,
    Callback = function(value)
        print("Slider:", value)
    end,
})

local section = home:Section({
    Title = "Quick Actions",
    Desc = "A row of icon cards.",
})
section:Card({
    Title = "Restart",
    Icon = "refresh-cw",
    Callback = function()
        window:Confirm("Restart?", "This will restart the hub.", function()
            -- confirmed
        end)
    end,
})
```

## API reference

### `Window`

| Method | Description |
|---|---|
| `Window.new(options)` | Creates a window. `options`: `Name`, `Title`, `Size` (`UDim2`), `ToggleKeybind` (`Enum.KeyCode`). |
| `window:Tab(id, title, icon)` | Creates (or returns the existing) tab. `icon` is a Lucide icon name. First tab created becomes active automatically. |
| `window:GoTo(id)` | Switches to a tab by id. |
| `window:SetVisible(visible)` | Shows/hides the whole window (animated). |
| `window:ToggleMenu(forceState?)` | Opens/closes the nav popup; pass `true`/`false` to force a state. |
| `window:Notify(title, content, icon?, duration?)` | Shows a toast. |
| `window:Confirm(title, content, callback)` | Shows a confirmation dialog; `callback` runs on confirm. |
| `window:Destroy()` | Tears down the window and disconnects everything. |

### Tab elements

Every tab returned by `window:Tab(...)` exposes:

| Method | Options |
|---|---|
| `tab:Paragraph(options)` | `Title`, `Desc` |
| `tab:Button(options)` | `Title`, `Desc`, `Icon`, `Callback()` |
| `tab:Toggle(options)` | `Title`, `Desc`, `Icon`, `Value`, `Callback(value)` — returns `{ Set(self, value) }` |
| `tab:Slider(options)` | `Title`, `Desc`, `Min`, `Max`, `Increment`, `Value`, `Callback(value)` |
| `tab:Section(options)` | `Title`, `Desc` — returns a section with `:Card(cardOptions)` |
| `section:Card(cardOptions)` | `Title`, `Icon`, `Callback()` |

### Theme

`Theme.lua` is a plain table — colors (`Background`, `Surface`, `SurfaceRaised`, `Text`, `TextMuted`, `Glow`), fonts, `CornerRadius`/`CornerRadiusPill`, `Icons` (asset ids for chrome icons), and `Tweens` (named `TweenInfo` presets used throughout the library). Fork or edit this file to reskin LumenUI without touching any other module.

## Project layout

```
Loader.lua       -- generated, self-contained bundle - what you actually loadstring
src/
  Window.lua      -- window chrome, tabs, navigation, open/close animation
  Elements.lua     -- Paragraph, Button, Toggle, Section/Card, Slider
  Confirm.lua      -- confirmation dialog
  Notify.lua       -- toast notifications
  Theme.lua        -- colors, fonts, tween presets
  Helpers.lua      -- shared instance/hover/icon utilities
  Icons.lua        -- Lucide icon sprite-sheet data
  Lucide.lua        -- Lucide icon name resolver
  BulkFade.lua     -- batched transparency fade helper used by Window/Confirm
```

## License

MIT
