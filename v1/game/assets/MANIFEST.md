# Asset manifest — Haystack Inc. (co-op) v1

Paths are relative to `game/`. Licenses and sources: `CREDITS.md`.
Everything is glTF 2.0 binary (`.glb`), Y-up, meters as authored (see scale notes).

## Models — general notes

- **Kenney kits are tile-sized, not meter-sized.** Suggested uniform scale per kit:
  - `survival_kit` — x2 (fence 0.5 m tile -> ~1 m, 1.05 m tall)
  - `nature_kit` — x3 (1-unit tile; fence 0.35 -> ~1.05 m). Base sits at y=-0.05
  - `fantasy_town_kit` — x2.5-3 (1-unit tile; wall 1 unit -> 2.5-3 m)
  - Pick one fence kit for the yard; `nature_kit/fence_simple` reads most "farm".
- **Kenney fence/wall pieces sit on the tile edge** (e.g. min z = -0.5 or min x = +0.42), not centered — snap to a grid, don't assume center pivot.
- `survival_kit` and `fantasy_town_kit` GLBs reference an **external atlas** `Textures/colormap.png` (relative). Keep each `Textures/` folder next to its GLBs, or models import white. The two atlases are different — don't swap them.
- `nature_kit` and `farm/*` store colors in materials (no textures), except `farm/pitchfork.glb` (embedded palette JPG).
- Some nodes may carry baked transforms: after instancing, measure the AABB at runtime before placing (don't trust pivots).
- "Size" = AABB W x H x D in the file's own units (X x Y x Z) at scale 1. "Tris" = triangle count.
- **No haystack / hay clump model was found in the right style** — build the stack and hay pieces procedurally (chunky low-poly blobs, straw-yellow material). `farm/hay_sheaf.glb` is the closest reference.

| Path | What | Suggested use / scale | Size (x1) | Tris |
|---|---|---|---|---|
| `assets/models/fantasy_town_kit/cart.glb` | wooden hand cart | yard prop; future hay cart | 0.89x0.54x1.34 | 608 |
| `assets/models/fantasy_town_kit/cart_high.glb` | cart with high sides | future hay cart | 0.89x0.86x1.39 | 1028 |
| `assets/models/fantasy_town_kit/fence.glb` | wooden fence (tile edge, x offset +0.42) | boundary | 0.08x0.38x1.00 | 84 |
| `assets/models/fantasy_town_kit/fence_broken.glb` | broken fence | boundary variety | 0.25x0.38x1.00 | 124 |
| `assets/models/fantasy_town_kit/fence_curved.glb` | curved fence | boundary corner | 1.00x0.38x1.00 | 308 |
| `assets/models/fantasy_town_kit/fence_gate.glb` | fence gate | yard entrance | 0.08x0.38x1.00 | 560 |
| `assets/models/fantasy_town_kit/lantern.glb` | lantern post | yard decor | 0.22x1.56x0.22 | 158 |
| `assets/models/fantasy_town_kit/overhang.glb` | small roof overhang | shed detail | 0.28x0.33x1.00 | 68 |
| `assets/models/fantasy_town_kit/pillar_wood.glb` | wood pillar | shed post | 0.16x1.00x0.16 | 44 |
| `assets/models/fantasy_town_kit/planks.glb` | plank floor tile | shed floor / platform | 1.00x0.06x1.00 | 96 |
| `assets/models/fantasy_town_kit/poles.glb` | pole wall | shed wall variant | 0.10x1.00x1.00 | 28 |
| `assets/models/fantasy_town_kit/roof.glb` | roof tile | modular shed | 1.07x0.65x1.00 | 64 |
| `assets/models/fantasy_town_kit/roof_corner.glb` | roof corner | modular shed | 1.07x0.65x1.07 | 36 |
| `assets/models/fantasy_town_kit/roof_gable.glb` | gable roof | modular shed | 1.10x0.57x1.07 | 72 |
| `assets/models/fantasy_town_kit/stall_stool.glb` | stool | prop | 0.26x0.23x0.26 | 180 |
| `assets/models/fantasy_town_kit/wall_wood.glb` | wooden wall (tile edge) | modular shed | 0.10x1.00x1.00 | 32 |
| `assets/models/fantasy_town_kit/wall_wood_corner.glb` | wooden wall corner | modular shed | 1.00x1.00x1.00 | 52 |
| `assets/models/fantasy_town_kit/wall_wood_door.glb` | wooden wall with door | modular shed | 0.10x1.00x1.00 | 376 |
| `assets/models/fantasy_town_kit/wall_wood_window_shutters.glb` | wooden wall with window | modular shed | 0.10x1.00x1.00 | 122 |
| `assets/models/fantasy_town_kit/wheel.glb` | cart wheel | prop leaning on barn | 0.24x0.48x0.47 | 192 |
| `assets/models/farm/barn.glb` | red barn (Quaternius), doors/windows are separate nodes | main building; ~real scale, x1 | 7.73x6.01x8.22 | 2910 |
| `assets/models/farm/barn_open_shed.glb` | open-front barn / shed | shelter next to haystack; x1 | 5.74x4.74x6.18 | 1612 |
| `assets/models/farm/barn_small.glb` | small red barn | alt main building; x1 | 6.08x4.96x6.27 | 2176 |
| `assets/models/farm/crate_wood.glb` | wooden crate | prop; x1 (~0.8 m), stylized-painted look | 0.82x0.82x0.82 | 784 |
| `assets/models/farm/hay_sheaf.glb` | bundled hay sheaf | reference/decor; x6 -> ~1 m (could be a hay-piece stand-in) | 0.12x0.18x0.12 | 488 |
| `assets/models/farm/market_cart.glb` | market cart with awning | decor; x2 | 0.46x0.80x0.93 | 2659 |
| `assets/models/farm/pitchfork.glb` | pitchfork, lying along Z, origin off-center, embedded palette texture | prop/future tool; x0.5 (-> ~1.5 m), rotate to stand | 0.53x0.21x3.08 | 240 |
| `assets/models/farm/silo.glb` | grain silo 9 m | background landmark; x1 | 3.67x9.07x3.51 | 1592 |
| `assets/models/farm/wheelbarrow.glb` | red wheelbarrow (CC-BY!), origin ~mid-height | future; x0.45, offset y +0.41 after scaling | 1.94x1.44x3.28 | 704 |
| `assets/models/nature_kit/crop_pumpkin.glb` | pumpkin | farm decor | 0.44x0.33x0.45 | 120 |
| `assets/models/nature_kit/crops_corn_stage_d.glb` | grown corn plant | field edge | 0.44x1.25x0.44 | 300 |
| `assets/models/nature_kit/crops_dirt_row.glb` | dirt crop row | field edge | 1.00x0.05x0.62 | 44 |
| `assets/models/nature_kit/crops_wheat_stage_a.glb` | young wheat | field edge | 0.54x0.33x0.45 | 720 |
| `assets/models/nature_kit/crops_wheat_stage_b.glb` | grown wheat | field edge | 0.54x0.53x0.45 | 360 |
| `assets/models/nature_kit/fence_bend.glb` | curved fence | boundary corner | 1.00x0.35x1.00 | 240 |
| `assets/models/nature_kit/fence_corner.glb` | fence corner | boundary corner | 1.00x0.35x1.00 | 116 |
| `assets/models/nature_kit/fence_gate.glb` | fence with gate | yard entrance | 1.00x0.35x0.07 | 524 |
| `assets/models/nature_kit/fence_planks.glb` | plank fence | boundary (tile edge, offset to z=-0.5) | 1.00x0.35x0.10 | 96 |
| `assets/models/nature_kit/fence_planks_double.glb` | double plank fence | boundary | 1.00x0.35x0.06 | 152 |
| `assets/models/nature_kit/fence_simple.glb` | rail fence | boundary (tile edge, offset to z=-0.5) — best farm look | 1.00x0.35x0.07 | 64 |
| `assets/models/nature_kit/fence_simple_center.glb` | rail fence centered | boundary | 1.00x0.35x0.07 | 116 |
| `assets/models/nature_kit/fence_simple_high.glb` | fence post high | boundary post | 1.04x0.35x0.11 | 44 |
| `assets/models/nature_kit/fence_simple_low.glb` | fence post low | boundary post | 1.04x0.20x0.11 | 44 |
| `assets/models/nature_kit/flower_purple_a.glb` | flowers | scatter | 0.16x0.24x0.18 | 76 |
| `assets/models/nature_kit/flower_red_a.glb` | flowers | scatter | 0.16x0.29x0.18 | 76 |
| `assets/models/nature_kit/flower_yellow_a.glb` | flowers | scatter | 0.16x0.19x0.18 | 76 |
| `assets/models/nature_kit/grass.glb` | grass tuft | scatter | 0.38x0.25x0.39 | 132 |
| `assets/models/nature_kit/grass_large.glb` | large grass tuft | scatter | 0.41x0.25x0.41 | 224 |
| `assets/models/nature_kit/grass_leafs.glb` | leafy tuft | scatter | 0.23x0.14x0.26 | 36 |
| `assets/models/nature_kit/log.glb` | log | prop | 0.23x0.17x0.71 | 200 |
| `assets/models/nature_kit/log_large.glb` | big log | prop | 1.00x0.42x0.55 | 96 |
| `assets/models/nature_kit/log_stack.glb` | firewood stack | next to barn | 0.42x0.35x0.71 | 184 |
| `assets/models/nature_kit/log_stack_large.glb` | big firewood stack | next to barn | 0.63x0.35x0.71 | 310 |
| `assets/models/nature_kit/mushroom_tan.glb` | mushrooms | scatter | 0.19x0.15x0.22 | 48 |
| `assets/models/nature_kit/plant_bush.glb` | bush | scatter | 0.40x0.24x0.40 | 32 |
| `assets/models/nature_kit/plant_bush_large.glb` | bush | scatter | 0.37x0.24x0.34 | 60 |
| `assets/models/nature_kit/plant_bush_small.glb` | bush | scatter | 0.38x0.21x0.34 | 16 |
| `assets/models/nature_kit/rock_large_a.glb` | large flat rock | scatter | 0.78x0.26x1.02 | 80 |
| `assets/models/nature_kit/rock_large_b.glb` | large rock | scatter | 0.77x0.43x1.02 | 85 |
| `assets/models/nature_kit/rock_small_a.glb` | small rock | scatter | 0.36x0.19x0.36 | 16 |
| `assets/models/nature_kit/rock_small_b.glb` | small rock | scatter | 0.36x0.18x0.36 | 24 |
| `assets/models/nature_kit/rock_small_c.glb` | small rock | scatter | 0.36x0.12x0.36 | 16 |
| `assets/models/nature_kit/rock_tall_a.glb` | tall rock | landmark | 0.98x1.00x0.68 | 136 |
| `assets/models/nature_kit/sign.glb` | wooden sign | "Haystack Inc." sign | 0.30x0.41x0.07 | 44 |
| `assets/models/nature_kit/stump_old.glb` | old stump | prop | 0.36x0.27x0.37 | 120 |
| `assets/models/nature_kit/stump_round.glb` | stump | prop | 0.32x0.21x0.37 | 56 |
| `assets/models/nature_kit/tree_default.glb` | tree | background trees | 0.76x1.71x0.65 | 114 |
| `assets/models/nature_kit/tree_detailed.glb` | detailed tree | hero tree near yard | 0.85x1.33x0.76 | 402 |
| `assets/models/nature_kit/tree_fat.glb` | chunky tree | background trees | 0.76x1.15x0.65 | 50 |
| `assets/models/nature_kit/tree_oak.glb` | oak | background trees | 0.64x1.23x0.74 | 196 |
| `assets/models/nature_kit/tree_simple.glb` | slim tree | tree line | 0.35x1.52x0.41 | 62 |
| `assets/models/nature_kit/tree_small.glb` | small tree | tree line | 0.35x1.11x0.41 | 62 |
| `assets/models/nature_kit/tree_tall.glb` | tall tree | tree line | 0.40x1.69x0.46 | 72 |
| `assets/models/survival_kit/barrel.glb` | wooden barrel | yard prop, physics obstacle | 0.24x0.34x0.24 | 412 |
| `assets/models/survival_kit/barrel_open.glb` | open barrel | prop | 0.24x0.34x0.24 | 380 |
| `assets/models/survival_kit/box.glb` | small wooden crate | prop / stackable crate | 0.25x0.25x0.25 | 124 |
| `assets/models/survival_kit/box_large.glb` | long wooden crate | prop | 0.25x0.25x0.50 | 124 |
| `assets/models/survival_kit/box_open.glb` | open crate | prop; future: deposit bin for hay pieces | 0.25x0.31x0.25 | 156 |
| `assets/models/survival_kit/bucket.glb` | bucket | small prop | 0.14x0.19x0.14 | 68 |
| `assets/models/survival_kit/chest.glb` | wooden chest | prop | 0.26x0.26x0.27 | 322 |
| `assets/models/survival_kit/fence.glb` | plank fence segment 0.5 wide | yard boundary | 0.50x0.52x0.04 | 48 |
| `assets/models/survival_kit/fence_doorway.glb` | fence with opening | yard entrance | 0.50x0.52x0.05 | 108 |
| `assets/models/survival_kit/fence_fortified.glb` | reinforced fence | boundary variant | 0.50x0.52x0.05 | 120 |
| `assets/models/survival_kit/floor_old.glb` | old plank floor tile | shed floor / pallet | 0.50x0.05x0.50 | 84 |
| `assets/models/survival_kit/grass.glb` | grass tuft | scatter | 0.23x0.14x0.26 | 36 |
| `assets/models/survival_kit/grass_large.glb` | large grass tuft | scatter | 0.48x0.14x0.49 | 144 |
| `assets/models/survival_kit/patch_grass.glb` | flat grass decal patch (0 height) | break up dirt ground | 1.20x0.00x1.20 | 33 |
| `assets/models/survival_kit/patch_grass_large.glb` | flat grass decal patch, large | break up dirt ground | 1.40x0.00x1.20 | 33 |
| `assets/models/survival_kit/resource_planks.glb` | stack of planks | prop | 0.37x0.09x0.63 | 72 |
| `assets/models/survival_kit/resource_stone.glb` | stone chunk | small prop | 0.17x0.11x0.14 | 44 |
| `assets/models/survival_kit/resource_wood.glb` | small log bundle | small prop | 0.21x0.06x0.09 | 64 |
| `assets/models/survival_kit/rock_a.glb` | rock | scatter | 0.56x0.39x0.62 | 104 |
| `assets/models/survival_kit/rock_b.glb` | rock | scatter | 0.83x0.42x0.72 | 156 |
| `assets/models/survival_kit/rock_c.glb` | rock | scatter | 0.78x0.51x0.57 | 120 |
| `assets/models/survival_kit/rock_flat_grass.glb` | flat rock with grass | ground detail | 1.79x0.23x1.45 | 758 |
| `assets/models/survival_kit/signpost.glb` | signpost (two arrows) | yard decoration | 0.21x0.46x0.04 | 44 |
| `assets/models/survival_kit/signpost_single.glb` | signpost (one arrow) | yard decoration | 0.21x0.46x0.04 | 28 |
| `assets/models/survival_kit/structure.glb` | open wooden frame | lean-to / shed frame | 0.50x0.50x0.50 | 80 |
| `assets/models/survival_kit/structure_roof.glb` | frame with roof | simple lean-to shed | 0.54x0.66x0.55 | 188 |
| `assets/models/survival_kit/tool_axe.glb` | axe | hand prop | 0.11x0.26x0.03 | 84 |
| `assets/models/survival_kit/tool_hammer.glb` | hammer | hand prop | 0.09x0.15x0.04 | 52 |
| `assets/models/survival_kit/tool_hoe.glb` | hoe | hand prop / wall decor | 0.08x0.24x0.07 | 58 |
| `assets/models/survival_kit/tool_pickaxe.glb` | pickaxe | hand prop | 0.18x0.24x0.04 | 74 |
| `assets/models/survival_kit/tool_shovel.glb` | shovel | hand prop / lean on barn | 0.07x0.29x0.03 | 124 |
| `assets/models/survival_kit/tree.glb` | round tree | background trees | 0.55x1.41x0.53 | 226 |
| `assets/models/survival_kit/tree_autumn.glb` | autumn tree | background trees | 0.55x1.41x0.53 | 198 |
| `assets/models/survival_kit/tree_log.glb` | fallen log | prop | 0.25x0.28x1.00 | 88 |
| `assets/models/survival_kit/tree_log_small.glb` | short log | prop / seat | 0.25x0.28x0.65 | 88 |
| `assets/models/survival_kit/tree_tall.glb` | tall tree | background trees | 0.55x1.71x0.53 | 254 |
| `assets/models/survival_kit/tree_trunk.glb` | stump | prop | 0.20x0.26x0.20 | 52 |
| `assets/models/survival_kit/workbench.glb` | workbench | yard prop | 0.33x0.29x0.30 | 236 |

## Audio

Short SFX are 44.1 kHz mono 16-bit WAV (Godot: best latency for one-shots); the rest are OGG Vorbis.
Enable **Loop** in the import settings for the three `ambience_*` files.
SFX processing done here: rustles trimmed to onset + fade-out + normalized; `hay_land_*` = Kenney `impactSoft_medium` + 0.45 s rustle at -7 dB; `throw_whoosh_1..3` = swishes pitched to 0.62x; wind loop = 60 s excerpt with a 3 s crossfade seam, +12 dB.

| Path | What | Suggested use |
|---|---|---|
| `assets/audio/hay_grab_1.wav … hay_grab_4.wav` | short dry rustle (0.6–0.8 s) | play on pickup (random variant, pitch 0.9–1.1) |
| `assets/audio/hay_rustle_long_1.wav … hay_rustle_long_3.wav` | longer rustle (1–2 s) | pulling a piece out of the stack / digging |
| `assets/audio/hay_land_1.wav … hay_land_4.wav` | soft thud + short rustle crunch (layered) | hay piece lands (scale volume by impact speed) |
| `assets/audio/hay_land_heavy_1.ogg … hay_land_heavy_3.ogg` | deeper soft impact | hard/fast landings, big clumps |
| `assets/audio/throw_whoosh_1.wav … throw_whoosh_3.wav` | short airy whoosh (swish pitched down) | on throw release |
| `assets/audio/throw_whoosh_soft.wav` | slower, quieter whoosh | gentle toss / drop |
| `assets/audio/footstep_grass_1.ogg … footstep_grass_5.ogg` | footstep on grass | walking on grass |
| `assets/audio/footstep_dirt_1.ogg … footstep_dirt_6.ogg` | footstep on dirt/earth (generic) | walking on the dusty yard |
| `assets/audio/cloth_1.ogg … cloth_3.ogg` | cloth movement | player foley on grab/carry start, jump |
| `assets/audio/ambience_morning_birds_loop.ogg` | 63 s stereo morning birds, seamless loop | main outdoor bed (loop) |
| `assets/audio/ambience_birds_loop.ogg` | 30 s stereo birds | alt/extra bird layer (loop; seam not verified) |
| `assets/audio/ambience_wind_loop.ogg` | 60 s stereo field wind, crossfade-looped here | low wind layer under birds (loop) |
| `assets/audio/ui_click.ogg` | UI click | button press |
| `assets/audio/ui_select.ogg` | UI tick | hover / focus |
| `assets/audio/ui_confirm.ogg` | UI confirmation | join/ready confirm |

## Textures

| Path | What | Suggested use |
|---|---|---|
| `assets/textures/sky_kloofendal_48d_partly_cloudy_puresky_2k.hdr` | 2k equirect HDRI, sunny midday, blue sky with puffy clouds, no ground | **default** `WorldEnvironment` → `PanoramaSkyMaterial` + ambient/reflections |
| `assets/textures/sky_farm_field_puresky_1k.hdr` | 1k HDRI, softer/hazier partly cloudy midday | alternative, lower-contrast lighting |
| `assets/textures/ground_dirt_floor_diff_1k.jpg` | light tan dusty dirt, low detail (photo-based) | yard ground albedo, tile 4–8 m, tint warm |
| `assets/textures/ground_dirt_floor_diff_256.png` | same, downscaled 256px | more stylized: nearest/linear filter, large tiling, or just sample its average color (~tan) |
