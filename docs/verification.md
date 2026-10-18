# Verification record

## Deep archive and research — October 18, 2026

- Full Godot build passed **154 checks, zero failures** and the release web export, including 20 new colony checks.
- Research tests cover facility/discovery requirements, insufficient balances without partial charges, exact payment, duplicate construction, underground purchase refusal, immediate equipment effects, recovery and full-save restoration of hull above 100.
- Archive tests exercise mounted refusal, on-foot collection with immediate save, one-time collection, and persistence through emergency recovery. Legacy version-one saves keep both new flags locked.
- Survey map now exposes the current progression objective in both touch and keyboard modes. The deep terminal has a visible pickup and a recovered state.
- Browser loaded the updated export and restored the existing test save. End-to-end manual archive retrieval and physical-device checks remain outstanding; automated gameplay checks directly exercise the recovery and research path.

## Controls, presentation and reliability update — October 18, 2026

- Full `node tools/build.mjs` pipeline passed: **134 checks, zero failures** (33 gameplay, 39 persistence, 26 controls/navigation, 36 networking), followed by the release web export. The build now stops on script errors and times out hung subprocesses.
- Control regressions cover acceleration/braking, joystick deadzone, collision, survey pause/resume, map plus focus-loss recovery, explicit touch preference retention, aim/shake alignment, reduced motion, malformed settings and terrain restoration.
- Browser QA in Chromium inspected the new terrain atlas, industrial station, survey map and pause menu. A fresh test origin mined copper and extended the survey. Closing/reopening that origin restored touch controls, muted audio and reduced motion, with successful save status.
- Inspected the new menu and map at 844×390 landscape; enlarged buttons and touch text remain readable. This is viewport validation, not physical-device or Safari certification.
- Persistence checks use real files and a simulated browser adapter for denied storage, corrupt/stale mirrors, invalid types, oversized data, future-version protection and revision bounds. The real browser reload separately validates the shipped JavaScript bridge path.
- The isolated networking spike connects two real localhost WebSocket clients and replicates authoritative mining state. It remains excluded from the public game pack. No online co-op, TLS service or paid infrastructure is claimed.
- Presentation uses original procedural textures/geometry and cached synthesized sound. Bespoke sprite production, broader content, device performance profiling, and production multiplayer remain unfinished.

## Initial implementation session

- Godot **4.6.3.stable.official.7d41c59c4** downloaded from godotengine/godot-builds; editor and export-template SHA512 verified against the release manifest.
- Godot import/parsing completed successfully after fixing an enum name collision.
- **28 headless behavioral checks passed**: collision and tunnelling prevention, actual mining, resource production, terrain restore, bedrock, capacity, idempotent deposits, upgrade effects/costs, discovery requirements, duplicate construction prevention, two-slot persistence/corruption recovery, expedition start, safe dismount/reboarding, blocked hatch refusal, lift restriction, colony return/departure, projectile damage, regulator discovery, defeat recovery, and full state save.
- Single-threaded Compatibility web export produced HTML, JavaScript, WASM, and game pack. WASM is approximately 37.7 MB uncompressed; game pack approximately 52 KB at the first export.
- Browser inspection in Codex's Chromium browser: title and mine render, keyboard downward drilling opened real terrain and collected 12 copper, returning through the cleared route deposited 12 copper / 36 credits, and a paid upgrade reduced banked copper from 12 to 2 and increased cargo capacity from 24 to 36.
- Missing arrow glyphs discovered during browser inspection and replaced with ASCII indicators.

- Browser reload restored the colony, 2 remaining copper, 36 credits, and the level-1 drill upgrade. Keyboard dismount transitioned to an on-foot character.
- Browser playtesting exposed a dismount risk beside an excavated shaft. Exit now requires a nearby landing, and the pause menu provides emergency recovery at a half-cargo penalty. Rebuilt successfully with **29 checks, 0 failures**, including the new unsafe-shaft regression.
- Corrupt-save recovery now uses a non-logging JSON parser; expected corruption no longer emits a runtime error during the test suite.
- GitHub Actions independently passed the complete Linux test/export workflow for commit `7f788568df84e0547b9ca82384f82a278d63317b` (run `38407042532`).
- Mobile controls enlarged and four multi-touch regression checks added: directional dragging, simultaneous movement/aim, independent finger release, and focus/reset clearing held input. **33 checks, 0 failures** in the updated local build.
- Inspected 844×390 phone landscape and 1024×768 tablet landscape viewports in Chromium. Touch layout and emergency recovery render and operate. Fixed colony button text fitting and made entire rooms tap targets. These are viewport checks, not physical iOS tests.
- Initial Vercel production deployment succeeded at https://supermotherload.vercel.app using the repository's build configuration on the existing Hobby plan.

Physical iPhone/iPad Safari, thermal behavior, and native exports are not yet tested. No claim of finished art or production performance is made.
