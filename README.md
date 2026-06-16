# ⚡ SniperDuel-Chair

Cheat script for **Sniper Duels** (Roblox) — by LOCKED IN NETWORK.

## Features

| Feature | Key / Control | Description |
|---------|--------------|-------------|
| **Menu** | `INSERT` | Toggle settings panel |
| **Aimbot** | Hold `RMB` | Smooth lock to nearest enemy head |
| **FOV Circle** | Menu slider | Adjust radius (30–800), toggle visibility |
| **Rainbow FOV** | Menu toggle | Cycles FOV circle color through rainbow |
| **Smoothness** | Menu slider | 1 = instant snap, 20 = slow track |
| **Chams** | Menu toggle | Neon red highlight through walls |
| **3rd Person** | Menu toggle | Unlock camera to 3rd person (adjustable distance) |
| **Bunnyhop** | Menu toggle | Auto-jump while holding movement keys |

## How to Use

1. Open your executor (Synapse X, Fluxus, Delta, Wave, etc.)
2. Attach to **Sniper Duels**
3. Copy/paste `main.lua` or use `loadstring`:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Snip301/SniperDuel-Chair/main/main.lua"))()
```

4. Press **INSERT** to open the menu in-game.

## File Structure

```
SniperDuel-Chair/
├── main.lua      -- the cheat script
└── README.md     -- this file
```

## Preview

Press `INSERT` in-game to open the draggable settings panel. All features can be toggled and adjusted live.

## Cleanup

To unload, run in executor console:
```lua
getgenv().ByteCleanup()
```

---

> **Disclaimer:** For educational and research purposes only.
