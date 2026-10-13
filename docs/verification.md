# Verification record

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

Physical iPhone/iPad Safari, thermal behavior, and native exports are not yet tested. No claim of finished art or production performance is made.
