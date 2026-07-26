# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository shape

Monorepo holding **two independent Jac 0.34.7 applications** that share no build,
package manager, or persistence layer. Run every command from inside the relevant
app directory — there is no root-level build.

| App | Path | Kind | Purpose |
| --- | --- | --- | --- |
| Web | `web/` | `web-app` | Graph-native emergency-drill operations console (simulated exercise) |
| Mobile | `mobile/` | `mobile` | Offline-first BLE packet relay, packaged for iOS/Android via Capacitor |

## The one hard rule: everything stays in Jac

Both apps are written *entirely* in Jac — backend logic, graph schema, agent
abilities, tests, routes, and JSX-like client components. **Do not add JavaScript,
TypeScript, Python, handwritten API routes, or a second persistence layer.** Model
work with Jac primitives instead:

- **Graph nodes + edges + walkers** for topology and traversal (e.g. `TraceRelay`).
- **`def:protect` typed functions** for authenticated, client-callable RPC. Jac auth
  maps each operator to a private persistent root graph; the graph *is* the database.
- **`by llm()`** only for structured agent output, and always with a deterministic
  Jac fallback so the app runs with no model provider configured.

Before editing any `.jac` file, read the relevant compiler guide: `jac guide <name>`.

## Commands

`jac 0.34.7` must be on PATH. Both apps also define these as `[scripts]` in their
`jac.toml` (runnable via `jac run <script>`).

### web/
```sh
export JWT_SECRET="$(openssl rand -hex 32)"            # required to start
export PROMETHEUS_ADMIN_PASSWORD="$(openssl rand -base64 32)"  # required to start
jac install
jac start --dev main.jac        # serves http://localhost:8000  (ops UI at /ops)
jac check .                     # lint — run this BEFORE tests
jac test                        # runs saferelay/store_test.jac (see [test] in jac.toml)
jac test saferelay/store_test.jac   # single test file
jac build main.jac
# Preflight (CI gate): jac check . && jac test && jac build main.jac
```
The live `by llm()` agent is **off by default**. Enable it with
`SAFERELAY_LIVE_AGENT=true`, `BYLLM_DEFAULT_MODEL=<model>`, and the matching
provider key (`OPENAI_API_KEY` / `ANTHROPIC_API_KEY` / `GOOGLE_API_KEY`). Otherwise
the typed deterministic briefing is used. See `web/.env.example`.

### mobile/
```sh
jac install && bun install      # Jac deps + Capacitor npm deps (bun, not npm)
jac start main.jac --client web --dev --port 4173 -a 4174   # browser preview :4173
jac check .
jac clean --data --force && jac test -d tests -v    # canonical: clears graph data first
jac test tests/protocol_tests.jac -v                # single test file
jac build --client web
jac build --client mobile --platform android   # needs JAVA_HOME=JDK 21, ANDROID_HOME=Android SDK 36
jac build --client mobile --platform ios       # needs full Xcode on macOS
```

## Architecture

### web/ — one graph, one runtime
`saferelay/store.jac` is the whole backend: it declares the graph nodes (`Incident`
→ `Alert` → `RelayHop`, plus `Responder`, `ActivityEvent`, `ScenarioPreset`, frozen
run artifacts, reviews, handoffs), the 24 `def:protect` RPCs, the `TraceRelay`
walker, the `by llm()` agent, and all domain logic. `main.jac` re-exports each RPC
as a thin `def:priv` wrapper and mounts the client via a `cl { ... }` block. Client
UI lives in `saferelay/*.jac` (`AppShell`, `LandingPage`, `LoginPage`,
`CommandCenter`). Parity tests are `saferelay/store_test.jac`.

> The web app's real code is all under `saferelay/` (+ `styles/`). The `app/`,
> `components/`, `lib/`, `hooks/`, `supabase/` directories are currently empty.

### mobile/ — dual client/server compilation
Jac compiles server and client variants into separate codespaces, so each domain
module exists twice in one importable project:

- `*.jac` — server/test variant (e.g. `domain/protocol.jac`, `domain/operations.jac`).
- `*.cl.jac` — client-build variant (e.g. `domain/protocol.cl.jac`, all of
  `services/`, `components/AppShell.cl.jac`).

To avoid duplicate declarations during whole-project `jac check`, **client symbols
are prefixed `Client`/`CLIENT_`** (e.g. `SosPacket` ↔ `ClientSosPacket`,
`PACKET_SIZE` ↔ `CLIENT_PACKET_SIZE`). The two variants must be kept algorithmically
equivalent. Layout: `domain/` = protocol + operations logic, `services/` = Capacitor
device/data bindings (BLE mesh, storage, field feeds, handoff transfer),
`components/` = UI, `tests/` = protocol + operations tests. See `docs/ARCHITECTURE.md`.

`android/` and `ios/` are generated Capacitor shells (`jac setup mobile`) — no
Flutter/Dart. Touch them only for a native service, entitlement, permission, or
plugin bridge. App id: `com.development.saferelay`.

## Conventions

- 4-space indent. `snake_case` for Jac functions/variables/modules; `PascalCase`
  for components, nodes, walkers, and Java classes.
- Tests live beside the app they cover and are named `*_test.jac` / `*_tests.jac`
  with behavior-focused names. Always `jac check .` before running tests.
- Commit subjects are concise and imperative (`Add relay packet validation`); keep
  each commit scoped to one app or native-bridge concern.

## Evidence boundary (mobile BLE)

A generated shell, passing codec tests, a browser preview, or an installed APK **do
not prove phone-to-phone BLE behavior.** Do not claim native radio support until
central scanning, peripheral advertising, background continuity, packet receipt, and
relay have been validated on two physical devices. Responder receipt and rescue
outcome are never inferred from a local broadcast.

## License

Proprietary — Copyright (c) 2025 SafeRelay Team, All Rights Reserved. No copying,
modification, distribution, or hackathon resubmission without written permission.
Never commit secrets; use `web/.env.example` and documented environment variables.
