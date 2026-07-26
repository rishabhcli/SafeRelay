# SafeRelay Production Runbook

This runbook covers production readiness and JacHammer deployment operations.
It does not require or perform a Git push.

## Runtime Contract

- Jac version: `0.34.7`, pinned by `jac.toml`.
- Entry point: `main.jac`.
- Application type: full-stack Jac web app.
- Public surface: landing page and built-in user authentication.
- Protected surface: `/ops`, all incident functions, and `TraceRelay`.
- Persistence: one isolated root graph per authenticated operator, including
  presets, frozen runs, review records, handoffs, and disaster-feed cache.
- Default agent mode: deterministic Jac policy with no provider dependency.
- Production topology: one application replica backed by Jac's persistent
  SQLite volume.

The one-replica ceiling is deliberate. Do not increase
`scale.kubernetes.max_replicas` until `MONGODB_URI` and `REDIS_URL` are
configured and persistence, locks, and restart recovery have been verified.

## Required Environment

Create both required values independently with a cryptographically secure
generator. Store them in JacHammer **Settings > Environment**, never in source:

| Variable | Required | Purpose |
| --- | --- | --- |
| `JWT_SECRET` | Yes | Signs operator sessions; startup fails when absent |
| `PROMETHEUS_ADMIN_PASSWORD` | Yes | Protects the metrics/monitoring surface |
| `SAFERELAY_LIVE_AGENT` | No | Set to `true` only after provider validation |
| `BYLLM_DEFAULT_MODEL` | No | Defaults to `gpt-4o-mini` |
| Provider API key | No | Required only when live-agent mode is enabled |
| `MONGODB_URI` | Scale-out only | Shared graph and identity persistence |
| `REDIS_URL` | Scale-out only | Shared cache and coordination |

For local validation, export the required values before any Jac command:

```bash
export JWT_SECRET="$(openssl rand -hex 32)"
export PROMETHEUS_ADMIN_PASSWORD="$(openssl rand -base64 32)"
jac install
```

Do not put generated values in `.env.example`, logs, screenshots, tickets, or
deployment notes.

## Preflight

Run every gate against the exact source state that will be deployed:

```bash
jac x preflight
```

The gate performs type checking, Jac tests, and a production build. It must
complete without errors. Compiler warnings originating from Jac's bundled React
Router declarations are upstream type-resolution warnings; new project warnings
must be investigated.

The production configuration intentionally:

- requests that `/docs`, `/redoc`, and `/openapi.json` are disabled;
- disables the bootstrap admin portal and its default credential;
- limits JWT lifetime to one day;
- enables authenticated Prometheus and walker metrics;
- configures Jac Scale's `/healthz/live` liveness probe;
- applies ingress request and connection limits;
- keeps microservices disabled so graph calls and the client share one runtime;
- prevents unsafe multi-replica SQLite operation.

### Jac 0.34.7 documentation-route gate

The Jac 0.34.7 local runtime currently applies `docs_enabled = false` after
FastAPI has registered its documentation routes. As a result, `/docs` and
`/redoc` return `500`, while `/openapi.json` still returns a schema. Protected
SafeRelay functions and walkers continue to reject anonymous requests, but
this runtime behavior does not meet the production contract.

Treat release acceptance item 9 as a hard promotion gate in JacHammer Preview.
If any documentation route exposes a schema or returns `500`, keep the release
in Preview and use a JacHammer runtime containing the upstream fix. Do not
promote that build or work around the gate by enabling documentation.

### Jac 0.34.7 password-policy gate

The SafeRelay client enforces a 12-character minimum, and Jac stores passwords
with 12-round bcrypt. Jac 0.34.7's built-in `/user/register` validation,
however, only requires a non-empty password. A direct API caller can therefore
bypass the client-side length check.

Before a public production promotion, use a JacHammer runtime or edge policy
that enforces the 12-character minimum on `/user/register`, then verify item 4
with a direct short-password request. Preview and sandbox testing may proceed,
but a runtime that accepts the short password is not approved for public
production.

## JacHammer

1. Create a full-stack project from the source folder in
   [JacHammer](https://jachammer.ai/).
2. Open **Settings > Environment** and add the two required secrets.
3. Keep `SAFERELAY_LIVE_AGENT=false` for the first release.
4. Start Preview and complete the acceptance checks below.
5. Use a sandbox deployment for the release candidate.
6. Promote the same verified project state to a permanent production
   deployment.
7. Configure a custom domain only after the platform URL passes all checks.

Restart Preview after changing environment values so the Jac process receives
the new configuration.

## Release Acceptance

Verify against Preview, sandbox, and the final production URL:

1. `/` renders the public product surface.
2. An unauthenticated visit to `/ops` redirects to `/login`.
3. Account creation with a 12-character-or-longer password succeeds.
4. A direct `/user/register` request rejects passwords shorter than 12
   characters, while a compliant new account receives its own seeded wildfire
   drill.
5. Acknowledge, assign, resolve, reset, and advance persist after a reload.
   Also verify cancel notes, scenario controls, presets, archives, replay,
   comparisons, signed reviews, and handoff lifecycle changes.
6. A second account cannot observe the first account's graph changes.
7. Relay provenance returns the expected ordered path for `SOS-1042`.
8. Agent analysis returns a structured deterministic briefing.
9. `/docs`, `/redoc`, and `/openapi.json` return `404` or `403`, never `500`,
   and do not expose an API schema.
10. `/healthz/live` and `/healthz/ready` report healthy without authentication.
11. `/metrics` rejects unauthenticated requests.
12. Restarting the deployment preserves users and graph state.
13. Live simulation appends one deterministic signal per tick at every speed,
    and the mute control suppresses the local alert tone.
14. USGS/NWS refresh either returns live source status or retains the fallback
    continuity snapshot without failing the command surface.
15. Complete the feature checklist in `PARITY.md` at desktop and mobile widths.

When enabling a live model, set the provider key and
`SAFERELAY_LIVE_AGENT=true`, restart, and repeat the agent check. The UI must
still fall back to the deterministic Jac policy when the provider is
unavailable.

## Operations

- Treat `.jac/data/` as production data. Never run `jac clean --data`,
  `rm -rf .jac/data`, or `jac scale destroy` against a live environment.
- Before schema renames, declare Jac schema aliases and inspect quarantine state
  with `jac db inspect --app main.jac`.
- Rotate `JWT_SECRET` as a deliberate session-invalidating change.
- Monitor request rate, error rate, walker latency, memory, and failed agent
  provider calls.
- Keep API docs disabled. Inspect the generated contract locally only when
  necessary; the Jac 0.34.7 `--faux` command currently prints the contract and
  then exits nonzero during server cleanup, so it is not a release gate.
- Roll back to the previous known-good JacHammer version if health, auth,
  persistence, or graph-isolation checks fail.
