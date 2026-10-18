# Co-op feasibility spike

Status: **local experiment, not playable online co-op**. Researched and tested October 17, 2026 with Godot 4.6.3. The public game remains single-player. No service, paid infrastructure, Vercel Function, or public listener was provisioned.

## What runs

`tests/network_smoke.gd` starts a native Godot `TCPServer` on an OS-assigned port bound exclusively to `127.0.0.1`. Two independent `WebSocketPeer` clients connect through real sockets in the same headless process. The test delivers movement and drilling commands, simulates the existing `MineTerrain`, and verifies that both clients receive identical player/terrain snapshots. The first rig collects ore while the second remains stationary; duplicate input is rejected and a disconnected client loses authority.

The code is deliberately separate from `game.gd`:

| File | Responsibility |
| --- | --- |
| `scripts/net/command_protocol.gd` | Versioned, size-bounded JSON input validation |
| `scripts/net/expedition_authority.gd` | Four slots, server-owned positions, collision, mining, cargo, sequence and rate policy |
| `scripts/net/loopback_host.gd` | Local-only WebSocket handshake, packet admission, snapshots, disconnect cleanup |
| `tests/network_smoke.gd` | Deterministic authority regressions and real two-client transport test |

## Wire and simulation decisions

Clients send intent only: `{v: 1, kind: "input", seq: 0, move: [0, 1], drill: true}`. The transport assigns identity; a command cannot name another player or supply position, cargo, terrain edits, clock, or damage. Commands are at most 512 bytes. Components must be finite numbers in `[-1, 1]`, with diagonals normalized. Sequence numbers must increase within a bounded window. A per-connection token bucket permits 60 commands/second with a burst of eight; rejected packets also spend budget. The host processes at most eight queued packets per peer per poll, limits queued buffers, times out incomplete handshakes, and closes slow readers.

The authority advances at 30 fixed ticks/second, independently of packet count. Held input expires after 250 ms without a fresh command. Snapshots are emitted every third tick (10 Hz), carrying accepted sequence acknowledgements, positions, cargo, seed and terrain edits. Movement uses the actual game's swept terrain collision and drilling code. This tests a reusable boundary without coupling transport to rendering or input devices.

The snapshot currently repeats the complete small world's edit set, and the latest received command is held until replaced. Production needs chunk revisions/deltas, reconciliation and interpolation. There is no player-player collision, combat, dismounting, colony transactions, authentication, reconnect identity, persistence, or host migration in this spike. Disconnection drops that test actor and cargo. Do not enable this transport as a public service.

## Browser and hosting findings

Godot 4.6 web exports support WebSocket clients and WebRTC, but cannot open raw TCP/UDP listeners. The browser can join an external authority; it cannot run this native WebSocket host. Secure pages should connect using `wss://` with a matching trusted certificate. Browser exports also cannot set custom WebSocket handshake headers, so future authentication must use a browser-compatible application handshake or another supported mechanism. [Godot web networking](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html#networking), [WebSocketPeer](https://docs.godotengine.org/en/4.6/classes/class_websocketpeer.html).

**Vercel now supports WebSocket Functions.** Its June 22, 2026 public-beta announcement supersedes older guidance saying Functions cannot host WebSockets. However, our current deployment only serves static Godot assets and has no socket endpoint. Each Function connection is pinned to its own instance; newly connected or reconnecting clients are not guaranteed the same instance. Connections close at the Function's maximum duration, so shared room state and reconnects need explicit coordination. [Vercel announcement](https://vercel.com/changelog/websocket-support-is-now-in-public-beta), [current WebSocket documentation](https://vercel.com/docs/functions/websockets).

Vercel currently documents a 300-second maximum Function duration on Hobby with Fluid compute. That requires recovery during an expedition longer than five minutes if we use this hosting option. [Function limits](https://vercel.com/docs/functions/limitations#max-duration).

Our engineering inference: an explicitly owned room running a persistent native Godot authority is the simplest first match for the existing GDScript simulation. Keep the browser client on Vercel and evaluate a small separately hosted authority only after a local browser join test. A Vercel Functions architecture remains possible, but distributed room ownership, state storage, runtime compatibility and bounded connection lifetimes must be proven; this spike does not establish those properties. WebRTC is an alternative to investigate if peer hosting becomes essential, including signaling, relay costs and host loss.

## Verification

Run from the repository root, after Godot is downloaded by the standard build:

```powershell
& '.tools/godot/Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tests/network_smoke.gd
```

Linux uses `.tools/godot/Godot_v4.6.3-stable_linux.x86_64` with the same arguments. The test exits nonzero on a failed assertion and takes a few seconds. Local firewall/sandbox restrictions must permit loopback sockets; the test opens no external network connection.

**Observed: 36 checks passed, zero failed** on Windows with real Godot 4.6.3, including protocol validation, sequence replay, rate refill, fixed-speed simulation, stale-input stopping, four-player admission, spawn reuse, terrain collision/mining/cargo, two socket handshakes, peer isolation, replicated world edits and disconnect removal. A first sandboxed run could not complete the loopback handshake; rerunning with localhost execution permission passed. These tests have not run in a web export, on physical mobile devices, across machines, under TLS, or under simulated latency/loss.

## Next integration gates

1. Extract the current solo simulation behind the same input/snapshot boundary without changing the mining feel. Add combat and colony operations as server-validated transactions with unique IDs; deposits must remain exactly once.
2. Export a separate local networking test client and join the native host from two browser tabs. Test movement prediction, snapshot interpolation, joins during mining, visibility/background pauses, disconnects and resume after a short network outage.
3. Exercise four actual clients at 50/100/200 ms latency, loss and constrained bandwidth. Measure snapshot bytes, server tick time, mobile frame time and correction distance before selecting the production transport/hosting.
4. Add versioned chunk deltas, room ownership, reconnect tokens, durable world saves and TLS/authentication. Select hosting based on measured session duration, operating cost and reliability; keep those decisions separate from the public single-player deployment.
