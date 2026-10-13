# BELOW — Project Gauntlet

A mobile-first Godot 4 mining/exploration prototype. The player pilots a tracked drill, excavates actual terrain, collects minerals, explores on foot, fights creatures, and returns to an underground colony to construct upgrades.

## Play / build

Requires Node.js 22+ and, on Linux, `unzip`. No npm packages are needed.

```sh
npm run build
npm start
```

Open http://localhost:4173. The build script obtains **Godot 4.6.3** and its official web templates, verifies SHA512 checksums, imports the project, runs gameplay regression tests, and exports to `build/web`. The initial download is approximately 1.3 GB because Godot distributes all platform templates together; subsequent builds reuse ignored local tools. Downloads stream to disk instead of buffering the template archive in RAM.

For native editor development, open `project.godot` in Godot 4.6.3. The project uses GDScript and the Compatibility renderer. Web export is single-threaded and does not require cross-origin isolation headers.

## Controls

| Action | Desktop | Touch |
| --- | --- | --- |
| Move / drill | WASD or arrows | Drag left control |
| Dismount / board | E or on-screen button | Dismount / Board |
| Aim / shoot on foot | Mouse + left click, or F facing forward | Drag right control |
| Jump / short boost | Space or W | Boost |
| Bank cargo / colony | R at the entry lift while boarded | Colony at the entry lift |
| Pause and save | Escape | Pause |

Start by drilling down into the amber copper seam immediately below the lift. Bring at least 10 copper back to upgrade the drill bay. The pumping station to the right of the shaft contains a regulator that must be retrieved on foot. It unlocks the workshop with 8 banked copper. Blue crystals farther down help construct living quarters.

Terrain, enemies, cargo, discoveries, upgrades, and player position are saved automatically, and when boarding, returning, building, or pausing. Two checksum-validated save slots tolerate one interrupted/corrupt write. Browser saves use this origin's localStorage, with Godot filesystem copies. Private browsing, clearing site data, changing domains, or storage denial can prevent retention. Saves do not synchronize across devices.

## Deployment

Import **andredaoud04/Supermotherload** into Vercel, using the existing `vercel.json`. The build command is `node tools/build.mjs`, output is `build/web`, and no secrets are required to build. GitHub Actions independently tests and exports a downloadable web artifact. Do not commit `.tools`, `.godot`, `.vercel`, credentials, or build binaries.

## Current scope

This is an initial **solo mechanics prototype**, not a finished premium-art vertical slice. It has one persistent seeded sector, a fixed return shaft, three underground visual regions, two collectible ores, three enemy behaviors, one rifle, a recoverable regulator, and three colony facility interactions. Environment and actor visuals are original procedural pixel-style drawings with dynamic 2D lights. No concept illustration is shipped as a pretend gameplay background.

Known limitations: no co-op, no native mobile export yet, no cross-device saves, no alternate sectors/endgame, and no bespoke sprite animation pipeline. Credits are currently a haul score; copper/crystals purchase improvements. Physical iPhone/iPad performance and Safari behavior require device testing. Desktop resize checks do not constitute device certification.

See [architecture](docs/architecture.md) for implementation boundaries and [verification](docs/verification.md) for recorded results. The historical [design proposal](docs/design-scope.md) is superseded by the owner's Godot/GDScript authorization where it discusses engine selection.
