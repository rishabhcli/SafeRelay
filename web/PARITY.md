# SafeRelay Evidence Contract

This contract defines the active Jac web application's data boundaries.

## Feature Matrix

| Product behavior | Jac-native implementation | Verification |
| --- | --- | --- |
| Public map preview | `RelayPlayground` confines synthetic markers to a visibly labeled map-only layer | Browser: `/` |
| Protected operations | Jac Scale auth and `AuthGuard` protect `/ops` and both source endpoints | Direct API and browser |
| Per-operator source cache | Verified USGS/NWS records attach to the authenticated Jac root | Jac test and browser |
| Active operations route | `VerifiedCommandCenter` shows source records and honest empty relay, receipt, responder, and outcome states | Browser: `/ops` |
| USGS earthquakes | Server refresh reads the official all-day GeoJSON feed with a bounded timeout | Browser and server |
| NWS severe weather | Server refresh reads active Severe/Extreme alerts with a bounded timeout | Browser and server |
| Partial source availability | A successful source remains visible while the failed source is reported as partial | Browser and server |
| Total source failure | Verified cache is retained; without cache the result is unavailable and empty | Jac test |
| Legacy generated records | Old continuity records are deleted during cache reads | Jac test |
| Synthetic data boundary | Synthetic artifacts exist only in clearly labeled map layers and never enter counts or evidence lists | Source audit and browser |

## Automated Contract

`saferelay/store_test.jac` verifies:

1. Unavailable sources produce an honest zero-record state.
2. Legacy generated continuity records are purged.

Run the complete release gate with:

```bash
jac x preflight
```

Production promotion still depends on the Jac 0.34.7 runtime gates in
`PRODUCTION.md`: server-side registration password enforcement and disabled
documentation routes.
