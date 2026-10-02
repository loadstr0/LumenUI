# NDS Fun Lab

The hub is intentionally modular:

- `Loader.lua` — tiny remote bootstrap and reload-safe lifecycle.
- `Main.lua` — orchestration, UI wiring, targeting, and optimized ownership scans.
- `PhysicsPatterns.lua` — continuous formations, stable debris forms, aimed attacks, and demolition pulses.
- `Defense.lua` — health repair, impact resistance, and void recovery.
- `Avatar.lua` — replicated cyclone, launch, and flight movement.
- `Config.lua` — shared performance and version settings.

Run with:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/loadstr0/LumenUI/main/NDSFunLab/Loader.lua"))()
```
