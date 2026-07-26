# Repository Guidelines

## Project Structure & Module Organization

SafeRelay contains two independent Jac applications. `web/` is the graph-native
operations console: `saferelay/` holds client components, graph/domain logic,
and `store_test.jac`; `styles/` contains its UI styles. `mobile/` is the
offline-first field relay: `domain/` defines protocol and operations logic,
`services/` wraps device and data integrations, `components/` contains the
mobile UI, and `tests/` covers protocol and operations behavior. Native
Capacitor projects live in `mobile/android/` and `mobile/ios/`; modify them
only for platform bridge or entitlement work.

## Build, Test, and Development Commands

Run commands from the relevant application directory.

```sh
# web/
jac install && jac start --dev main.jac  # Local web application
jac check . && jac test && jac build main.jac  # Preflight

# mobile/
jac install && bun install
jac start main.jac --client web --dev --port 4173 -a 4174  # Browser preview
jac check . && jac test tests/protocol_tests.jac tests/operations_tests.jac -v
jac build --client mobile --platform android  # Requires JDK 21 and Android SDK
jac build --client mobile --platform ios      # Requires Xcode on macOS
```

## Coding Style & Naming Conventions

Keep application logic in Jac. Use typed `def:protect` functions for protected
RPC, graph nodes and walkers for topology, and `by llm()` only for structured
agent behavior. Follow existing four-space indentation and `snake_case` for
Jac functions, variables, and modules. Use `PascalCase` for Jac components,
nodes, walkers, and Java classes. Keep web modules under `web/saferelay/` and
mobile modules within their existing domain, service, or component boundary.

## Testing Guidelines

Add or update Jac tests beside the affected application. Name test files
`*_test.jac` or `*_tests.jac`, and give tests behavior-focused names. Run
`jac check .` before tests. Browser previews and builds do not prove BLE relay
behavior; validate scanning, advertising, background continuity, and delivery
on two physical devices before claiming native radio support.

## Commit & Pull Request Guidelines

The visible history currently has only the baseline `Create README.md` commit,
so use concise, imperative subjects such as `Add relay packet validation`.
Keep commits scoped to one application or native bridge concern. Pull requests
should describe the changed workflow, list validation commands, link relevant
issues, and include screenshots for web or mobile UI changes. Never commit
secrets; use `web/.env.example` and documented environment variables instead.
