# Implementation decisions

- **Engine:** Godot 4.6.3 / GDScript, per owner authorization. Compatibility renderer and non-threaded web template preserve browser support without SharedArrayBuffer requirements. Native export remains possible but has not been validated.
- **Terrain:** fixed-size cell arrays, not a node or network object per tile. Generation and saved edits are independent of rendering. Swept, substepped AABB collision is shared by rig, explorer, and creatures. Visible cells only are drawn. The prototype bounds the entire sector; chunk streaming is unnecessary at this scale.
- **Movement:** four-direction excavation with an articulated drill; assisted thrust in open space. Hull-clearance excavation removes the cells needed by the rectangular vehicle. Cargo-full rigs cannot destroy valuable ore without collecting it.
- **Modes:** title, expedition, colony. The colony is a separate simulation. Returning deposits cargo exactly once and repairs equipment. Departing preserves the excavated sector. On-foot boost prevents routine shaft traversal traps.
- **Combat:** manual directional rifle fire with modest line-of-sight aim assistance, swept projectiles, terrain blocking, three simple enemy behaviors, and capped cosmetic particles. No full-world destruction from ordinary bullets.
- **Progression:** ore-funded upgrades. Drill upgrades affect speed and cargo, workshop requires an on-foot discovery and affects weapon damage, quarters affect maximum health. Credits are display-only haul score in this prototype.
- **Persistence:** versioned state, terrain seed + edit map, surviving enemies, and actor state. Alternating checksummed saves tolerate one bad write. Browser localStorage writes are synchronous to avoid background/close racing a filesystem sync. Storage failure is shown rather than claiming success.
- **Input:** landscape keyboard/mouse and multi-touch. Input resets and solo simulation pauses on focus loss. Touch controls track finger ownership separately for motion, aim, and boost.
- **Art:** hand-coded pixel-style shapes and layered scenery establish readable scale. Bounded real PointLight2D nodes provide local lighting. This is original prototype art, not the final premium production asset pipeline.
- **Build:** pinned vendor downloads and SHA512 verification. Automated tests run before export. Linux Vercel and GitHub builds use the same Node script as local Windows builds.

## Networking boundary

Godot's WebSocket transport is a candidate for an early reliable ordered terrain/state feasibility test. Godot's ENet UDP transport cannot be assumed to run in a browser. Vercel serves the static client; it is not a persistent game-session WebSocket host. A future co-op test needs a separate session service or a WebRTC signaling/relay strategy, followed by mobile backgrounding and reconnect testing. Do not describe a locally passing transport experiment as implemented four-player co-op.

The intended authority owns terrain edits, damage, collection IDs, and progression commits. Clients consume sequenced edits and can request a full snapshot after gaps. A seed alone is insufficient to synchronize movement or damage. First validate two clients with drilling/collection/dismount, then four separate rigs and cameras before building matchmaking.
