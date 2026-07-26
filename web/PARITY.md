# SafeRelay Functional Parity Contract

This document maps the last committed Next.js application to the Jac-native
refactor. It treats operator behavior as the contract while allowing the
implementation to change where Jac replaces a former framework or service.

## Feature Matrix

| Committed application behavior | Jac-native implementation | Verification |
| --- | --- | --- |
| Public interactive mesh demo | `MeshSignalDemo` advances an origin packet through two relays and a gateway | Browser: `/` |
| Public wildfire, tornado, hurricane, and earthquake selector | Four-state Jac segmented control resets and relabels the public topology | Browser: `/` |
| Account creation, login, logout, protected admin | Jac Scale auth and `AuthGuard` protect `/ops` and every operation | Direct API and browser |
| Per-operator persistence | Incidents, presets, runs, reviews, and handoffs attach to the authenticated Jac root | Isolation and restart checks |
| Dashboard, SOS table, live map, disasters, analytics | Eight command modes include all five committed navigation surfaces plus scenario, archive, and review workspaces | Browser: `/ops` |
| Search and 25-row pagination | Jac client filters ID, type, zone, message, and team before stable pagination | Browser: SOS signals |
| Alert details and relay trace | Full delivery fields, ordered `TraceRelay` traversal, origin, gateway, timestamps, and notes | Jac test and browser |
| Acknowledge, assign, resolve, cancel | Protected Jac functions mutate graph nodes and release or retain responder capacity correctly | Jac test and browser |
| Alert sound and mute setting | Embedded local WAV tone plays on manual and timed live ticks; mute state persists in the incident graph | Browser runtime settings |
| Demo/live mode, run/pause, 0.5x/1x/4x/16x | `update_drill_runtime` plus a Jac client interval drives protected graph ticks | Jac test and browser |
| Scenario seed and four generation controls | Deterministic generator responds to intensity, density, gateway ratio, and infrastructure damage | Jac test |
| Scenario-specific alert and device volume | All four committed scenario ranges feed graph node and score generation | Jac test |
| Preset save, apply, delete, import, export | `ScenarioPreset` nodes retain controls and responder assignments; versioned JSON round trips through protected APIs | Jac test and browser |
| Persistence diagnostics | Workspace reports synchronized Jac graph counts for presets, runs, reviews, and handoffs | Browser: Scenario lab |
| Drill briefing and plan evidence | Deterministic objectives, injects, evidence targets, focus, and archive action derive from current graph metrics | Jac test and browser |
| Responder recommendations and capacity coverage | Five committed team templates use capacity-aware assignment and coverage/ETA metrics | Jac test and browser |
| Frozen run archive and event inspector | `RunArchive`, `ArchivedAlert`, and `ArchivedEvent` nodes preserve the exact exercise artifact | Jac test and browser |
| Run A versus Run B comparison | Six deltas cover volume, delivery, hops, gateways, responders, and unresolved criticals | Jac test and browser |
| Replay timeline and scrubber | `get_run_replay` projects alert lifecycle and event visibility at any 0-100 position | Jac test and browser |
| After-action scoring and signed records | `DrillReview` nodes score archived evidence, retain reviewer notes, show trends, and export JSON | Jac test and browser |
| Handoff queue and lifecycle | Draft, sent, acknowledged, superseded, active, archived, deleted, accepted, follow-up, and rejected states persist with filters and JSON manifests | Jac test and browser |
| USGS earthquakes and NWS severe weather | Protected server refresh uses the same public feeds with timeouts, cache, source status, and an offline continuity snapshot | Browser and fallback test |
| Network zones, system health, analytics | Zone health, active nodes, gateway coverage, delivery, relay depth, critical aging, and responder coverage derive from graph state | Browser: Dashboard and Analytics |
| Grounded operations agent | Typed `by llm()` briefing uses only simulated graph context, with a deterministic Jac fallback | Jac test and browser |

## Intentional Implementation Replacements

- Next.js, React application source, API routes, and TypeScript domain modules
  are replaced by Jac server and client modules.
- Supabase synchronization is replaced by the authenticated Jac root graph.
  The user-visible durability, diagnostics, isolation, archives, and handoff
  behavior remain; there is no split local/remote source of truth.
- The incident map uses Mapbox GL with a public token supplied through
  `MAPBOX_ACCESS_TOKEN`. Alert selection, geographic positions, severity,
  gateway context, and relay inspection remain available.
- Framer Motion and matrix-rain decoration are not runtime dependencies.
  Functional transitions, live status, and scenario interactions remain in Jac
  and CSS.

## Automated Contract

`saferelay/store_test.jac` covers:

1. Control-driven deterministic drill generation.
2. All four committed scenarios.
3. Alert lifecycle and relay traversal.
4. Complete lifecycle timelines.
5. Timed live-simulation alert creation.
6. Preset JSON save/import/apply behavior.
7. Frozen archive, comparison, and replay projection.
8. Capacity-aware responder coverage.
9. Briefing, signed review, and handoff lifecycle.
10. Disaster-feed continuity behavior.

Run the complete release gate with:

```bash
jac x preflight
```

Production promotion still depends on the two Jac 0.34.7 runtime gates in
`PRODUCTION.md`: server-side registration password enforcement and disabled
documentation routes.
