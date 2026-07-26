# SafeRelay

SafeRelay keeps the SafeRelay mobile and web applications in one repository
while preserving them as independent projects.

| Project | Path | Source |
| --- | --- | --- |
| Mobile app | [`mobile/`](mobile/) | `meowshmalloww/SafeRelay-mobile` |
| Web app | [`web/`](web/) | [`rishabhcli/SafeRelay-web`](https://github.com/rishabhcli/SafeRelay-web) |

Build, test, and run each application from its own directory. See the README in
that directory for project-specific instructions. Pushes to `main` that change
`web/` automatically publish that folder to the web-only repository used by
JacHammer; mobile sources are never copied into its build context.
