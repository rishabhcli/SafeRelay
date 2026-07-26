# SafeRelay Production Runbook

This runbook covers production readiness and JacHammer deployment operations.
It does not require or perform a Git push.

## Runtime Contract

- Jac version: `0.34.7`, pinned by `jac.toml`.
- Entry point: `main.jac`.
- Application type: full-stack Jac web app.
- Public surface: landing page, `/ops`, both public hazard-feed endpoints,
  cloud relay health, and validated idempotent mobile signal ingestion.
- Authentication: none. The operations console and its data endpoints accept
  anonymous requests.
- Persistence: one shared public root graph containing verified public-source
  hazard records and unverified mobile relay reports.
- Production topology: one application replica backed by Jac's persistent
  SQLite volume.

The one-replica ceiling is deliberate. Do not increase
`scale.kubernetes.max_replicas` until `MONGODB_URI` and `REDIS_URL` are
configured and persistence, locks, and restart recovery have been verified.

## Required Environment

Create the required value with a cryptographically secure generator. Store it
in JacHammer **Settings > Environment**, never in source:

| Variable | Required | Purpose |
| --- | --- | --- |
| `PROMETHEUS_ADMIN_PASSWORD` | Yes | Protects the metrics/monitoring surface |
| `MONGODB_URI` | Scale-out only | Shared graph persistence |
| `REDIS_URL` | Scale-out only | Shared cache and coordination |

For local validation, export the required values before any Jac command:

```bash
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
- enables authenticated Prometheus and walker metrics;
- configures Jac Scale's `/healthz/live` liveness probe;
- applies ingress request and connection limits;
- keeps microservices disabled so graph calls and the client share one runtime;
- prevents unsafe multi-replica SQLite operation.

### Jac 0.34.7 documentation-route gate

The Jac 0.34.7 local runtime currently applies `docs_enabled = false` after
FastAPI has registered its documentation routes. As a result, `/docs` and
`/redoc` return `500`, while `/openapi.json` still returns a schema. This
runtime behavior does not meet the production contract.

Treat release acceptance item 5 as a hard promotion gate in JacHammer Preview.
If any documentation route exposes a schema or returns `500`, keep the release
in Preview and use a JacHammer runtime containing the upstream fix. Do not
promote that build or work around the gate by enabling documentation.

## JacHammer

[`rishabhcli/SafeRelay`](https://github.com/rishabhcli/SafeRelay) is the
canonical source and the only submission repository. After every push to
`main` that changes `web/`, its deployment workflow publishes only this
directory to JacHammer's isolated build source. The mobile and native project
trees never enter the hosted web build context.

1. Open the SafeRelay project in [JacHammer](https://jachammer.ai/).
2. Pull the latest published web source.
3. Open **Settings > Environment** and add the required metrics secret.
4. Start Preview and complete the acceptance checks below.
5. Use a sandbox deployment for the release candidate.
6. Promote the same verified project state to a permanent production
   deployment.
7. Configure a custom domain only after the platform URL passes all checks.

Restart Preview after changing environment values so the Jac process receives
the new configuration. JacHammer preview and sandbox URLs can be protected by
the platform's preview token even when Jac endpoints are marked public. Do not
configure `SAFERELAY_CLOUD_URL` with a URL that returns `401` to an anonymous
health probe; the mobile relay requires the permanent public deployment origin.

## Release Acceptance

Verify against Preview, sandbox, and the final production URL:

1. `/` renders the public product surface.
2. An anonymous visit to `/ops` renders the operations console without a login
   redirect.
3. Anonymous `POST /function/get_disaster_feed` and
   `POST /function/refresh_disaster_feed` do not return `401`.
4. Relay reports, receipts, acknowledgements, and outcomes remain empty or
   unknown until their own evidence exists.
5. `/docs`, `/redoc`, and `/openapi.json` return `404` or `403`, never `500`,
   and do not expose an API schema.
6. `/healthz/live` and `/healthz/ready` report healthy without authentication.
7. `/metrics` rejects unauthenticated requests.
8. Restarting the deployment preserves shared graph state.
9. USGS/NWS refresh returns `live` or `partial` only for a successful source
    request; total source failure retains verified cache or reports
    `unavailable`.
10. No source failure creates example, fallback, or continuity records.
11. Synthetic artifacts appear only inside clearly labeled map layers.
12. Complete the active-route checklist in `PARITY.md` at desktop and mobile
    widths.
13. Anonymous `POST /function/cloud_relay_health` returns `accepting: true`.
14. Repeating the same valid `POST /function/ingest_mobile_signal` returns one
    new receipt followed by a duplicate receipt without storing a second node.
15. Invalid status codes or coordinates return `success: false`.

## Operations

- Treat `.jac/data/` as production data. Never run `jac clean --data`,
  `rm -rf .jac/data`, or `jac scale destroy` against a live environment.
- Before schema renames, declare Jac schema aliases and inspect quarantine state
  with `jac db inspect --app main.jac`.
- Monitor request rate, error rate, source refresh latency, and memory.
- Keep API docs disabled. Inspect the generated contract locally only when
  necessary; the Jac 0.34.7 `--faux` command currently prints the contract and
  then exits nonzero during server cleanup, so it is not a release gate.
- Roll back to the previous known-good JacHammer version if health,
  persistence, or public endpoint checks fail.
