# Project Gauntlet: scope and mechanics proposal

Status: discussion draft, not an approved production specification.

This proposal uses the supplied brief and eight concept images as references. The project owner selected vehicle-led mining and exploration. All numeric design targets are initial playtest hypotheses. Team size, budget, and device floor remain unconfirmed. Scope assumes a small team. No release date is implied.

## 1. Concept verdict

Build a vehicle-led underground expedition game in which the resources and discoveries you bring home physically expand a surviving human colony. The recurring emotional beat is: dig into the unknown, find something worth taking a risk for, bring it home, see a change, and prepare to reach farther.

The strongest identity is the relationship between a chunky drill, a vulnerable explorer, and a growing underground home. The largest risk is treating five inspirations as five complete games that must coexist.

Use the post-apocalyptic colony, drill, and cavern images as the main reference family. Keep amber inhabited spaces, cyan mineral discoveries, violet fungal spaces, and red biological threats. The frozen moon, cheerful frontier, and jungle versions are alternative settings, not additional launch biomes. Image 7 is useful for the vehicle/character relationship but its squad portraits, weapon panel, and simultaneous HUD elements are too dense for the mobile baseline.

Preserve drilling, purposeful excursions on foot, visible colony growth, and the contrast between a lost surface and a strange underground. Remove launch requirements for surface warfare, resident micromanagement, hunger, oxygen, fuel, vehicle interiors, fluid simulation, structural collapse, extensive crafting recipes, and equipment rarity rolls. These are cuts to systems, not to atmosphere.

Use bounded expeditions connected to a permanent colony. Preserve an active expedition across solo suspend/resume. Between completed expeditions, preserve discoveries and unlocked depth routes rather than every excavated tile in an infinite world. Explain new layouts as adjacent mining sectors. Do not present revisiting an exact sector as the same place if its terrain has regenerated.

## 2. A representative 12-minute session

| Time | Player action | Purpose |
| --- | --- | --- |
| 0–1 min | See an unfinished workshop upgrade requiring copper and a recovered regulator; equip a drill module. | Establish a concrete reason to leave home. |
| 1–4 min | Enter a sector, drill toward visible deposits, and choose between an easy seam and a promising cave opening. | Let excavation and route choice carry the experience. |
| 4–7 min | Park by an old pumping station, dismount, fight a small encounter, and retrieve its regulator. | Give on-foot play a discovery that ordinary drilling cannot supply. |
| 7–10 min | Return to the rig; choose to extract or risk remaining cargo space and hull health on a richer deposit. | Make the main decision about how much farther to go. |
| 10–12 min | Return through the cleared route, deposit materials, and construct the workshop upgrade. | Turn an expedition into visible progress and a new capability. |

The clock is illustrative, not a mission timer. Early return must be valid. Solo play needs immediate pause and recoverable saves because a phone session can end at any moment.

## 3. Integrated mechanics

### Mining and movement

One movement stick controls the rig. Holding toward mineable terrain engages the drill automatically. Excavation opens enough space for the full hull rather than leaving the vehicle stuck behind its drill bit. Ore is collected into cargo automatically. Deposits, hardness, and nearby openings should support readable route decisions; a scanner can hint at nearby value without marking every secret.

Use assisted vertical thrust in cleared space so the rectangular rig can return from shafts it excavates. Keep the chassis upright, with visible directional drill articulation for excavation. This needs an early art-and-controls test: a giant front drill must not appear to mine through its roof by magic. Blocked upward excavation is preferable to an unreadable rotating truck; if necessary, constrain upward motion to cleared passages and support it with path generation.

Movement through empty tunnels is considerably faster than drilling. Cargo and hull health are the initial expedition limits. Defer fuel and drill heat until playtests show a specific decision they improve. There is no passive survival drain forcing the player to rush past interesting places.

Keep the rig powerful against loose rock and small creatures, but poor at navigating narrow ruins and fighting flankers. A stopped rig can be damaged by nearby threats; distant dormant enemies do not silently destroy it while the player explores. No global attacks on unattended vehicles in the slice.

### Entering, exiting, and travel on foot

One context button enters or exits a stopped rig. Place the character at a checked hatch position with room to stand; indicate why exit is unavailable if neither side is safe. Do not teleport into solids or hazards. Re-entering uses proximity rather than a precise tap on the hatch.

The rig provides cargo storage and a limited field resupply. It is a staging point, not an invulnerable healing exploit. Do not require exiting to pick up ordinary ore, inspect menus, or pay routine upgrade costs.

On-foot excursions reach facilities, rescue locations, and compact caves. Aim for one or two meaningful excursions per early expedition, not repeated forced dismounting at every deposit. Give each authored excursion a traversable return path. Simple automatic mantling and contextual ladders support access; freeform grappling is deferred.

### Combat and mobile input

Landscape orientation. Left thumb moves; right thumb drags an aim/fire area with generous aim assistance. Release to stop firing; reload is automatic. Jump is a separate large button, and interact is contextual. There is one equipped gun and one contextual utility in the first slice, with no weapon wheel, manual reload button, dodge button, or grenade inventory competing for space.

Jumping and precision aiming must not be simultaneously necessary for basic combat. Most encounters happen on readable ground with simple height changes. Test an optional auto-fire control variant if two-stick play is uncomfortable; do not settle the entire control scheme on desktop.

Start with three enemy behaviors: a closing crawler, a stationary or slowly moving spitter with a telegraphed projectile, and an armored charger with a punishable recovery. Their roles matter more than skin count. Gun feel comes from strong hit reactions, sound, readable tracers, brief impact effects, and enemy responses. Avoid large damage-number clouds and constant screen shake.

Terrain destruction remains important for route choices, opening sightlines, and explosives. Ordinary rifle fire does not chew through every floor. Mark non-excavatable facility frames consistently and reserve destructible walls for intentional shortcuts. Avoid requiring perfect platform collision while everything beneath the player disintegrates.

### Return and failure

For the slice, return manually through cleared tunnels to the entry lift. Design the sector so an ordinary return takes roughly 30–60 seconds; measure it. If return is consistently dead time, add unlockable transit anchors or safe-route fast return before adding larger sectors. There is no reason to defend tedious backtracking as realism.

Defeat returns the player to the colony with previously banked progression intact. Initial tuning proposal: lose half of unbanked common cargo; discovered key schematics remain recorded. Emergency recovery restores a usable baseline rig without debt. Losing should hurt the expedition outcome, not demand repetitive recovery runs or strand a player without the means to earn resources. Validate the loss amount and watch for deliberate defeat becoming the optimal return route.

### Colony and economy

The colony is a separate protected scene depicted as rooms extending down a shared shaft. Expedition minerals finance excavation and construction, so the connection is mechanically real even though terrain simulations are separate.

Use fixed build slots and a few branch choices. No individual resident schedules, power wiring, food meters, or room-placement traps. Residents bring life and acknowledge discoveries; they are not a second job for the player.

Early facilities are a drill bay for mining capabilities, a workshop for combat and utility options, and living quarters that support rescued inhabitants and unlock their projects. Add each only when it produces an observable consequence. A room whose sole purpose is repeatedly paying to increase a percentage needs redesign.

Use three resource categories: common ores, credits, and specific discoveries. Colony projects consume identified ores directly; surplus ore can be sold for credits used in equipment upgrades. Clearly show and reserve materials required by a pinned project so automatic selling cannot erase progress. Do not create a separate currency for every biome or facility.

Build immediately when affordable. Visible construction animation supplies feedback without real-time waiting. Prioritize upgrades that change behavior, such as breaking reinforced seams or installing a deployable light, alongside a limited set of understandable capacity and power improvements.

### Biomes and progression

Depth should change decisions as well as palettes. Initial content sequence: shallow industrial workings teach excavation and facilities; crystal caverns introduce harder seams and exposed richer deposits; fungal depths introduce clearly telegraphed spore zones and enemies using vertical space. These are launch candidates, not three biomes required for the slice.

Magma, ancient machine cities, and the abyss belong after the core game proves itself. Avoid six visually expensive biomes with identical ore and reskinned enemies. Depth gates should combine discovered routes and capability upgrades, with enough optional side routes to avoid linear key hunting.

### Multiplayer

Preserve the ambition of one to four players with separate rigs, independent cameras, shared discoveries, and useful cooperation without mandatory classes. Scale objectives and encounter pressure for solo play rather than forcing solo players to cover four jobs.

Build the enjoyable solo loop first, but perform an early two-client experiment with drilling, dismounting, terrain edits, and collection before producing substantial content. Test four rigs and four separated cameras as a subsequent feasibility gate. Separate rigs may turn narrow tunnels into traffic jams; test non-blocking teammate collision in constrained passages before adding vehicle collision physics.

For a first cooperative version, the host owns the expedition and colony changes. Each player retains an explicitly defined personal reward from the completed session; do not duplicate or redistribute collected cargo implicitly. Guests need an understandable progress benefit even when they are not upgrading their own colony. Final reward rules are a design gate before release.

Defer shared always-online colonies, host migration, public matchmaking, PvP, and cross-platform account systems. On host loss, return everyone to a safe menu with last committed progression; communicate this limitation. Mobile backgrounding and interrupted connections must be tested before advertising reliable co-op.

## 4. Implementable art direction

Target authored pixel art with consistent scale. First scale test: 32-pixel terrain cells, roughly 40–48-pixel-tall people, and a rig around 120–160 pixels long. Test these at an approximately 640×360 world viewport, adapted for phone aspect ratios with safe UI areas. These are prototype dimensions, not final asset contracts.

The cinematic mobile fortress in the references should shrink to a recognizable player vehicle. A rig occupying half a phone screen leaves too little space to react. Keep giant industrial machines as background landmarks or exceptional set pieces.

Keep traversable edges crisp, background detail lower contrast, and hazards distinguishable by shape, motion, and sound as well as color. Frame the active character or rig with modest look-ahead; do not zoom out until characters become dots. Use a gentle bounded transition on dismount. Put touches and HUD outside common combat focal areas.

Invest in drill contact, suspension, tread movement, recoil, enemy impact poses, ore pickup, and room construction. Use a shared pixel grid and authored animation cadence with smooth simulation and carefully controlled camera movement. Avoid inconsistent asset resolutions. Limit shadow-casting lights and overlapping effects; beauty must survive sustained operation on the chosen phone floor.

## 5. Technical architecture

Provisional choice: Unity with C# and URP's 2D Renderer, provided the team has no strong existing engine preference. Its documented 2D workflow includes sprite lighting, animation, physics, and profiling. This is a production recommendation, not a claim that Unity automatically solves destructible terrain or makes this game faster than Godot.

Godot is a credible alternative with documented renderers and high-level multiplayer APIs. Existing Godot expertise could outweigh switching engines. Select the exact supported engine version only when implementation begins; verify mobile builds and representative rendering on physical devices first.

Keep colony state, expedition state, and presentation separate. Store terrain in chunked cell arrays containing material and damage state. Render and rebuild collisions only for changed nearby chunks; do not instantiate one networked object per terrain tile. Use pooled effects and bounded active enemy counts, with inactive distant regions.

Use authored encounter rooms embedded in generated geological layouts. Validate entry connectivity, vehicle clearance, mandatory objectives, and return paths. Procedural generation does not eliminate level design or accessibility testing.

Persist sector seed, generator version, modifications, objectives, player/vehicle state, and progression transactions. Seed alone cannot reproduce all physics or gameplay state. Make saves atomic and versioned; interrupt writes deliberately in tests. Single-player suspend/resume is essential, not late polish.

Structure gameplay around explicit commands and events. In cooperative play, the host validates movement-related actions, mining, damage, and rewards; clients predict only what can be corrected safely. Send sequenced terrain changes, entity state, and chunk snapshots for late joins, rather than trusting identical simulation from a seed. Enforce one commit per collection/reward transaction to prevent duplicated cargo.

Initial performance goal: stable 60 fps on a specifically chosen midrange test phone, with a stable reduced-effects 30 fps mode if necessary. Set memory, lighting, and active-world budgets from measurements. Test sustained play and thermal behavior, not just a brief desktop capture. These targets have not been demonstrated.

Primary technical references checked for this proposal:

- Unity 2D workflow: https://docs.unity3d.com/6000.1/Documentation/Manual/2d-game-creation-wokflow.html
- Godot renderer overview: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Godot multiplayer overview: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html

## 6. Smallest convincing vertical slice

One character, one rig, one compact sector combining industrial ruins and a crystal pocket, three resource types, one rifle, three enemy behaviors, one recoverable project component, and two functional colony rooms. The player must drill, make a route choice, dismount, survive an encounter, recover the component, return, construct an upgrade, save, reload, and feel the upgrade on a second expedition.

Use an authored layout with limited variation initially. Include one finished visual treatment and a cohesive sound pass. Full procedural generation, three biomes, bosses, and finished multiplayer are outside this slice. The separate early networking experiment checks feasibility; it need not have finished art.

Playtest gates, proposed rather than proven: most first-time testers can mine without explanation; they understand why and where to dismount; they can aim and move on a phone without frequent wrong inputs; the first room upgrade changes the next trip; returning does not feel like a chore; and players voluntarily start another expedition. Start with 5–8 external testers to discover obvious friction, then broaden testing. This is qualitative evidence, not market validation.

## 7. Roadmap and scope boundaries

1. Controls and terrain proof: rig movement, dig feedback, vertical return, safe exit, and a phone combat encounter. Stop adding systems if these feel poor.
2. Complete solo loop: cargo, return, one consequential colony project, defeat recovery, and robust save/resume. Run the two-client terrain experiment before substantial content expansion.
3. Polished slice: one art treatment, sound, readable UI, external testing, and sustained physical-device profiling.
4. Production decision: set staffing, budget, device floor, content quantities, and whether cooperative play is funded for launch using measured results.
5. Candidate launch scope: three distinct biomes, one rig chassis with meaningful modules, a small weapon roster, roughly five useful facility types, bounded replayable sectors, a finite progression arc, and a satisfying endpoint. Quantities are ceilings for estimation, not obligations.
6. Later expansion: additional rigs, advanced traversal, deeper biomes, more colony branches, and co-op if it was not ready for launch.

Four-player co-op is a major product goal but not an unconditional solo-launch requirement. If it becomes the main selling point, its validation and budget must precede a launch commitment; it cannot be appended casually after single-player content is complete. Do not announce delivery dates before the slice establishes content throughput.

## 8. Design gauntlet

| Risk | Consequence | Practical mitigation |
| --- | --- | --- |
| Mining and combat interrupt each other | Players resent half the loop | Limit compulsory dismounts and give each an exclusive discovery or meaningful encounter. |
| Rig traversal looks or feels wrong | The signature mechanic loses credibility | Prototype articulation, hull clearance, and vertical return before final art. |
| Touchscreen control overload | Combat becomes frustrating | Two main input regions, assisted aiming, automatic reload, and no required aim/jump combinations. |
| Mining lacks route decisions | Drilling becomes a progress bar | Legible seams, alternate paths, capacity pressure, and optional danger. |
| Return travel becomes repetition | Players stop after one trip | Faster cleared-tunnel movement, compact sectors, then transit anchors if testing demands them. |
| Colony is either shallow or demanding | It becomes a menu treadmill or a second job | Few facilities, visible changes, immediate construction, and capabilities tied to discoveries. |
| Economy rewards grinding or intentional death | Expeditions lose tension and purpose | Transparent project needs, protected baseline equipment, and measured loss/return incentives. |
| Destruction undermines levels or performance | Broken routes, collision spikes, unreadable fights | Chunked terrain, controlled destructibility, bounded activity, and validated authored spaces. |
| Co-op multiplies unresolved problems | Desync, traffic jams, unfair progression | Early terrain/vehicle experiments, host authority, explicit ownership, and connection-failure tests. |
| Art ambitions exceed production capacity | A beautiful screenshot never becomes a finished game | One consistent scale, modular environments, limited launch biomes, and measured asset throughput. |

## Self-critique and revisions

The skeptical designer would ask why the player ever leaves a satisfying drill. Revision: ordinary resources stay vehicle-accessible; facilities, recoveries, and deliberate combat encounters justify leaving it. On-foot content must earn its place rather than being imposed by constant arbitrary gates.

The mobile player would object to mandatory 15-minute uninterrupted sessions and thumb gymnastics. Revision: the duration is a session example, not a timer; solo suspend/resume is required, early extraction is valid, and jumping while aiming is not a baseline skill requirement.

The technical lead would object that a solo-first plan hides networking risk until too late. Revision: schedule a two-client terrain and dismount experiment before content production, then a four-vehicle test before promising co-op. Keep permanent colony terrain outside the destructive expedition simulation.

Remaining decisions with the project owner: available team and engine experience; target phone floor; and whether cooperative play is required for the first commercial release. Vehicle-led mining and exploration is confirmed. The current recommendation remains mobile-first and bounded around a polished solo loop.
