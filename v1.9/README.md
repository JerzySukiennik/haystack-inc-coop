# Haystack Inc. — co-op edition

Find one needle in a haystack of a million pieces. First-person, stylized low-poly, built in Godot 4.6 for Windows.
Start by pulling hay out by hand, later build a factory to do it for you. Built iteratively from playtest feedback.

## v1 — hay, stack, physics
- Pull hay pieces out of the stack (a counter tracks a million pieces)
- Carry pieces with physics, drop them, or charge up a throw
- Walk into loose hay to push it around
- Procedural low-poly yard: terrain, wind-blown grass, trees, fence, shed, dust
- Ambience and sound effects (CC0, see `game/assets/CREDITS.md`)

## Controls
WASD move · Shift sprint · Space jump · hold LMB grab / pull from stack · hold RMB while carrying to charge a throw · mouse wheel hold distance · Esc menu

## Project layout
- `game/` — Godot project (current working copy)
- `v1/`, `v1.1/`, … — frozen snapshots of each version

## Run / export
Open `game/project.godot` in Godot 4.6. Windows build: `godot --headless --path game --export-release "Windows Desktop" ../build/windows/HaystackInc.exe`.
Automated playtest with screenshots: `godot --path game -- --autotest --shots=/path/to/shots`.

## Windows icon
Godot can only write the .exe icon with rcedit on Windows. The export uses a pre-patched template
(`Niepotrzebne/templates/windows_release_x86_64_haystack.exe`, not in git): the official 4.6.2 release
template run through `rcedit-x64.exe template.exe --set-icon game/icon.ico --set-version-string ProductName "Haystack Inc." ...`
on the Windows laptop. Re-patch it when the icon changes or Godot is upgraded.
