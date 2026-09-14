# Haystack Inc. — Version Roadmap

Godot 4.6, Windows/RTX 3050 primary target, stylized low-poly. Each version is a small,
shippable `.exe` the owner can run and play. Versioning: v1 → v1.1 → v1.2 → … → v1.9 → v2 → …

v1 (in progress, not covered here) = solo first-person hay-piece pickup from a static
stack, hold/carry/drop/throw physics only. No economy, no multiplayer.

---

## v1.1 — Sell Loop
**Goal:** close the core manual economy loop: pick up hay, sell it, see money go up.
- Conveyor belt object that accepts thrown/placed hay pieces
- Each piece removed from belt at its end → adds money to player's wallet
- Simple money HUD (number, top corner)
- Hay piece despawns/pools on sale (no memory growth over a long session)
- Debug counter: hay pieces remaining in the stack

**Done when:** run the game, manually carry 20 pieces to the belt, watch wallet increase
by the expected amount each time; stack count decreases 1:1; no crash after 200 sales in
one session (script a bot/automation loop or just grind it manually and check logs).

**Risks:** belt/trigger detection missing fast-thrown pieces; float money drift if using
floats instead of ints (use integer currency).

---

## v1.2 — Needle Placement & Detection
**Goal:** the actual win condition exists — one needle hidden at a specific stack index.
- Needle is a distinct pickup-able object seeded into the stack generation at a known index
- Pickup/sell of the needle triggers a "FOUND IT" event (just a console log + placeholder UI for now)
- Seeded RNG for stack generation so needle position is reproducible for testing
- Debug command/cheat to jump the needle to index 0 or last, for fast win-testing

**Done when:** with a debug seed, spawning + finding the needle logs the exact expected
index; running the same seed twice reproduces the identical needle location (screenshot
or log diff to confirm determinism).

**Risks:** if stack uses physics-driven settling, "index" must map to a stable spawn
order, not final resting position — decide now which one counts as canonical, since v2+
economy math depends on it.

---

## v1.3 — Win State & Celebration
**Goal:** finding the needle feels like an event, not a log line.
- Win screen/overlay: trophy model, particle/confetti burst, sound sting (placeholder SFX ok)
- Game doesn't hard-stop — after celebration, player is dropped back into free play (sandbox)
- Session stats shown at win: time elapsed, hay sold, money earned

**Done when:** trigger the debug win from v1.2, confirm celebration UI appears, then
confirm player retains control and the world keeps simulating afterward (walk around,
pick up more hay) — no soft-lock.

**Risks:** UI pause vs. game pause conflicts (don't accidentally freeze physics during
celebration if sandbox mode should already be live).

---

## v1.4 — Networking Foundation (Co-op Core, Host-Authoritative)
**Goal:** get 2 players in the same world over the internet before any more features are
built, so everything after this is designed multiplayer-first.
- Integrate webrtc-native GDExtension + Godot high-level multiplayer API
- Firebase RTDB signaling: host creates a room code, client joins by code, SDP/ICE
  exchange via RTDB, then direct WebRTC data channel
- Host-authoritative: host spawns/owns the stack and economy state; clients send input,
  host validates and replicates transform/state back
- Sync only: player position/rotation/animation state, hay-piece ownership on pickup
  (no economy sync needed yet — belt/money can stay host-only display for now)

**Done when:** two machines (or host + a second local instance pointed at a real/staging
Firebase project) join via room code over the internet, see each other move, and one
player's held hay piece is visibly attached to them on the other client. Log room-code
generation, join success/failure, and peer connection state to a file for headless
verification.

**Risks:** this is the highest-risk version in the whole roadmap — WebRTC NAT traversal,
Firebase security rules for the signaling channel, and host migration are all real
problems. Budget it as its own multi-day milestone, not "one feature among many." Decide
now: no host migration in v1 — if host disconnects, session ends for everyone (acceptable
for a co-op party game). This is *why* it's placed right after the win state and before
any economy/machine work: every system built afterward (selling, buying, machines) must
be written against a networked-state model from day one instead of retrofitted later.

---

## v1.5 — Co-op Economy Sync
**Goal:** money and hay-stack state are shared and consistent across all players.
- Shared wallet (team money, not per-player) replicated from host to all clients
- Hay-stack depletion synced: a piece picked up by one player is gone for everyone
  (host resolves race conditions — first claim wins, RPC-rejected for the loser)
- Reconnect handling: a client that drops and rejoins with the same room code resumes
  into current world state (host resends full state snapshot on join)

**Done when:** 2+ clients simultaneously grab pieces near each other, confirm no
duplicate sale of the same piece; disconnect one client mid-session, rejoin, confirm
wallet/stack match host's current values (compare log dumps from host and rejoined
client).

**Risks:** race conditions on simultaneous pickup are the main bug source here — test
deliberately with two players lunging for the same piece.

---

## v1.6 — Room Lobby & Session Flow
**Goal:** turn "two people running the exe" into an actual product flow: create/join,
up to 4 players, basic lobby.
- Main menu: Create Room (generates code) / Join Room (enter code)
- Lobby screen: shows connected players (name/color), host can start
- Player cap enforced at 4; join attempts beyond that are rejected with a message
- Basic player identity: name entry + one of a few preset colors/skins (cosmetic only)

**Done when:** 4 separate clients join one room code and land in-world together;
a 5th join attempt is cleanly rejected with a visible message (screenshot the rejection).

**Risks:** none major — mostly UI/UX plumbing on top of v1.4/v1.5's networking.

---

## v1.7 — Shop & Tier-1 Machine: Wheelbarrow/Cart
**Goal:** first "buy something with money" loop and first automatic-ish machine (carry-more, still player-driven).
- Shop UI (interact with a stand/kiosk in the yard) listing purchasable machines
- Wheelbarrow/cart: player pushes/drives it into the stack, it holds N hay pieces
  (much more than 2 hands), player still manually walks it to the belt to sell
- Purchases replicate: bought machine appears for all clients, cost deducted from shared wallet
- Placement: simple — machine spawns at a fixed yard location or a small set of preset pads

**Done when:** with enough money from v1.1-era manual selling, buy a cart, fill it with
more than 2-hands-worth of hay, sell the batch, confirm wallet reflects it; confirm all
clients see the cart and its fill level update live.

**Risks:** networked ownership of a "vehicle" object (who's driving, input authority) —
apply the same host-authoritative pattern as player movement.

---

## v1.8 — Tier-1 Machine #2 + Yard Placement System
**Goal:** real machine placement (not fixed pads) and a second manual-carry machine for variety.
- Baler: compresses a batch of manually-fed hay into one bale worth more money per belt trip
- Free placement: player picks a spot in the yard (grid-snapped), ghost preview, confirm to place
- Placed machines persist and replicate to late-joining clients (from v1.5's reconnect snapshot logic)

**Done when:** place a baler anywhere in the yard on client A, confirm it appears in the
same spot for client B without rejoining; feed it hay, confirm bale value math matches
design (log expected vs actual sale value).

**Risks:** grid/placement validation (no overlapping machines) — keep it simple, reject
placement rather than trying to auto-resolve collisions.

---

## v1.9 — Tier-2 Machine: Auto-Loader
**Goal:** first machine that needs no player interaction — the automation shift begins.
- Auto-loader: stationary machine placed adjacent to the stack, periodically grabs a
  nearby hay piece on its own and feeds it onto the belt (timer-based, no player input)
- Runs identically whether 0 or 4 players are nearby (host simulates it regardless of
  proximity/culling)
- Visual tell (arm animation, sound) so it reads clearly as "working" from a distance

**Done when:** place an auto-loader, walk away, come back after N seconds, confirm wallet
increased with no player action (log timestamped sale events); confirm it keeps running
identically for a client who wasn't in the room when it was placed (late join).

**Risks:** this is the point where server-side (host) simulation of *non-player* economy
actors starts mattering for performance — keep loader logic cheap (timer + one raycast/
nearest-piece query), not per-frame physics scanning.

---

## v2 — Full Automation Line: Walking Robot + Sorter
**Goal:** the "set it and forget it" fantasy — a machine that walks into the stack and
works it autonomously, plus a sorter for throughput.
- Walking robot: navigates into the stack (NavMesh or simple steering), picks pieces up
  in a working radius, walks back to drop at a collection point or belt
- Sorter: junction that batches/routes hay from multiple sources onto one belt without
  jams (simple FIFO queue, not physics-based stacking)
- Robot pathing and pickup fully host-simulated, replicated as position + state only
  (clients don't run their own copy of the pathing logic)

**Done when:** place one robot, confirm it autonomously depletes a visible chunk of the
stack over a timed session with no player input; place 2 robots + a sorter feeding one
belt, confirm no belt jam/pileup over a long run (headless soak test: run host + bot
client for 10 min, diff hay-sold-per-minute against single-robot baseline).

**Risks:** NavMesh generation on a constantly-shrinking, physics-object stack is the
hard part — likely need a simplified "logical grid" for pathing/targeting separate from
the visual physics stack, so the robot doesn't try to navmesh-bake 10,000 hay pieces.

---

## v2.1 — Full Line & Scaling to the Needle
**Goal:** stack the automation so a fully-built factory can plausibly clear the whole
pile and find the needle within a fun session.
- Multiple robots + loaders + sorters running concurrently, feeding 1-2 belts
- Performance pass: object pooling for hay pieces, LOD/imposter for distant stack chunks,
  culling for stack regions no machine is actively working
- Live "pieces remaining" and "est. time to clear" HUD readout for player feedback

**Done when:** a maxed-out factory (per the tuning numbers below) clears a full-size pile
and triggers needle-found within the target session window, verified via log timestamps
from stack-generation to win-event; frame time stays within budget on RTX 3050 during
peak automation (profiler capture, no sustained drops below ~50fps at max machine count).

**Risks:** this is a tuning/perf version, not a features version — treat it as a
dedicated pass, don't bundle new machine types into it.

---

## v2.2 — Progression & Shop Polish
**Goal:** make the buy-and-upgrade loop legible and satisfying, not just a flat price list.
- Machine tiers shown as a clear upgrade tree/list in the shop UI (cost, throughput stat)
- Prices scale so each purchase is a felt decision, not a trivial tap
- Sell-back or refund option for misplaced machines (partial refund, prevents grief-by-mistake)

**Done when:** playtest the full manual→factory curve start to finish, confirm no dead
stretch where the player has nothing meaningful to buy for a long time (log purchase
timestamps across a full session, check for large gaps).

**Risks:** pure balance/tuning risk — expect this version to require iteration passes
based on playtests, not just one pass.

---

## v2.3 — Audio & Juice Pass
**Goal:** make every core action feel good — this is the "fun" polish version.
- SFX: pickup, throw, belt sale ding, machine ambient loops, win fanfare
- Juice: hit-stop/squash on pickup, money-counter tween instead of instant jump, screen
  shake or camera punch on needle find
- Music: ambient yard loop + a distinct win stinger

**Done when:** playtest with sound on, confirm no missing/placeholder SFX remain on core
actions (checklist pass through every interaction), confirm audio doesn't desync or
double-fire in co-op (test with 2+ clients performing the same action simultaneously).

**Risks:** networked audio triggers firing once per client vs. once globally — decide
per-sound whether it's local-only (footsteps) or host-broadcast (needle fanfare).

---

## v2.4 — Sandbox Post-Win Polish
**Goal:** the stated post-win "keep playing" mode is actually a designed state, not just
"nothing stops you."
- Post-win yard: option to reset stack (fresh needle, fresh seed) without leaving the room
- Persistent trophy/cosmetic marker in the yard from prior wins this session
- Optional "run it back" vote/prompt so the group can agree to reset together

**Done when:** after a win, all clients see a "reset stack" prompt, one player triggers
it, confirm a fresh stack + needle spawns for everyone and money/machines persist
(economy doesn't reset, only the pile does) — verify via log diff of stack state pre/post
reset.

**Risks:** deciding what *does* and doesn't reset (machines stay, pile resets, wallet
choice) — nail this down early since it's a design call, not just implementation.

---

## v2.5 — Stability, Save/Settings & Ship Candidate
**Goal:** the version the owner actually hands to friends without babysitting it.
- Settings menu: graphics quality presets (RTX 3050 target), volume, key rebinding
- Local save of last-used room code / player name for faster rejoin
- Crash/error logging to a file for post-session debugging
- Final export pass: Windows .exe, verify cold-start-to-playable time and no console
  window leaking on release build

**Done when:** run the exported .exe from a clean folder (not the editor) on the target
laptop, host a room, have a friend join over the internet, play a full session start to
win to sandbox reset, no crashes, no console spam — capture screenshots at each major
milestone (menu, lobby, first sale, win screen, sandbox) as the acceptance artifact.

**Risks:** this is the integration-test version — expect it to surface bugs from every
prior version; budget real time for it, don't treat it as a rubber stamp.

---

## Needle Math — Tuning Notes

Goal: manual search alone must be effectively hopeless (players should *feel* forced
toward automation), but a maxed-out factory should find the needle within a fun single
session (roughly 15-30 minutes of active factory-building + a shorter "grind" tail).

**Example numbers (tune during v1.2 and revisit at v2.1):**
- Pile size: 10,000 hay pieces per full stack.
- Needle index: seeded uniformly random 0–9999 (not always deep — sometimes early, so
  pure luck exists but isn't a strategy).
- Manual throughput (1 player, hands only): ~1 piece per 2-3 seconds sorted/sold ≈
  ~20-30 pieces/minute. Clearing the pile manually solo ≈ 333-500 minutes (5.5-8+ hours)
  — deliberately hopeless.
- Manual throughput (4-player co-op, hands only): ~80-120 pieces/minute combined ≈
  ~83-125 minutes to clear. Still too slow for one sitting — this is the pressure that
  sells the economy/machines.
- Tier-1 machine (cart/baler, still player-fed): ~2-3x per-player throughput while
  actively used ≈ 200-350 pieces/minute for 4 players running carts. Clears in
  ~30-50 minutes — better, but still a grind, motivating tier-2.
- Tier-2 auto-loader (per unit, unattended): ~15-20 pieces/minute per loader. 4 loaders
  running while players also work manually/tier-1 ≈ 60-80 pieces/minute *added* on top,
  pushing combined throughput past 300-400 pieces/minute ≈ under 30 minutes.
- Full factory (v2.1 target: multiple robots + loaders + sorters, ~8-12 automated units
  total): target combined throughput ~600-1000 pieces/minute → clears 10,000 pieces in
  roughly 10-17 minutes of active automated runtime, on top of the time spent building
  the factory itself (which is the actual "session length" — the clear itself should feel
  like a fast payoff, not the main time sink).
- **Design rule of thumb:** each machine tier should roughly halve-or-better the time to
  clear the pile solo-manual would need, so every purchase feels like a clear step-change,
  not a marginal upgrade. Re-tune pile size per level if sessions run long/short in
  playtesting — pile size is the cheapest knob to turn without touching code.

---

## Ideas Parked for Later (Out of Scope for This Roadmap)

- Procedural/seasonal yard themes (snow, night, different farms)
- Cosmetic skins/hats for players and machines, unlockable via play
- Leaderboards / fastest-clear times, either local or online
- Competitive mode (race to find the needle, separate piles per team)
- Mod support / custom machine scripting
- Mobile/Steam Deck port considerations
- Voice chat integration (rely on external tools like Discord for now)
- Multiple needles / difficulty tiers as a post-launch content update
- Weather/day-night cycle affecting visibility or machine efficiency
- Dedicated server hosting (currently host-authoritative P2P only; revisit if host
  churn or NAT issues prove too painful in practice)
