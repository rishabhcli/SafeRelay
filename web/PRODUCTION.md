# SafeRelay Production Runbook

This runbook covers production readiness and JacHammer deployment operations.
It does not require or perform a Git push.

## Runtime Contract

- Jac version: `0.34.7`, pinned by `jac.toml`.
- Entry point: `main.jac`.
- Application type: full-stack Jac web app.
- Public surface: landing page and built-in user authentication.
- Protected surface: `/ops`, `get_disaster_feed`, and
  `refresh_disaster_feed`.
- Persistence: one isolated root graph per authenticated operator containing
  only verified public-source hazard records.
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

The monorepo publishes this folder to
[`rishabhcli/SafeRelay-web`](https://github.com/rishabhcli/SafeRelay-web) after
every push to `main` that changes `web/`. JacHammer must track that web-only
repository, not the `rishabhcli/SafeRelay` monorepo.

1. Import `https://github.com/rishabhcli/SafeRelay-web` in
   [JacHammer](https://jachammer.ai/).
2. Open **Settings > Environment** and add the two required secrets.
3. Start Preview and complete the acceptance checks below.
4. Use a sandbox deployment for the release candidate.
5. Promote the same verified project state to a permanent production
   deployment.
6. Configure a custom domain only after the platform URL passes all checks.

Restart Preview after changing environment values so the Jac process receives
the new configuration.

## Release Acceptance

Verify against Preview, sandbox, and the final production URL:

1. `/` renders the public product surface.
2. An unauthenticated visit to `/ops` redirects to `/login`.
3. Account creation with a 12-character-or-longer password succeeds.
4. A direct `/user/register` request rejects passwords shorter than 12
   characters, while a compliant new account opens with no generated
   operational records.
5. Relay reports, receipts, acknowledgements, and outcomes remain empty or
   unknown until their own evidence exists.
6. A second account cannot observe the first account's cached source records.
7. `/docs`, `/redoc`, and `/openapi.json` return `404` or `403`, never `500`,
   and do not expose an API schema.
8. `/healthz/live` and `/healthz/ready` report healthy without authentication.
9. `/metrics` rejects unauthenticated requests.
10. Restarting the deployment preserves users and graph state.
11. USGS/NWS refresh returns `live` or `partial` only for a successful source
    request; total source failure retains verified cache or reports
    `unavailable`.
12. No source failure creates example, fallback, or continuity records.
13. Synthetic artifacts appear only inside clearly labeled map layers.
14. Complete the active-route checklist in `PARITY.md` at desktop and mobile
    widths.

## Operations

- Treat `.jac/data/` as production data. Never run `jac clean --data`,
  `rm -rf .jac/data`, or `jac scale destroy` against a live environment.
- Before schema renames, declare Jac schema aliases and inspect quarantine state
  with `jac db inspect --app main.jac`.
- Rotate `JWT_SECRET` as a deliberate session-invalidating change.
- Monitor request rate, error rate, source refresh latency, and memory.
- Keep API docs disabled. Inspect the generated contract locally only when
  necessary; the Jac 0.34.7 `--faux` command currently prints the contract and
  then exits nonzero during server cleanup, so it is not a release gate.
- Roll back to the previous known-good JacHammer version if health, auth,
  persistence, or graph-isolation checks fail.
