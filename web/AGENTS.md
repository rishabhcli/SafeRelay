# Working In SafeRelay

SafeRelay is a Jac 0.34 full-stack application. Before editing `.jac` files,
read the relevant compiler guide with `jac guide <name>`.

Core validation:

- `jac check .`
- `jac test`
- `jac start --dev main.jac`

Keep server and client code in Jac. Do not add JavaScript, TypeScript, Python,
handwritten API routes, or a second persistence layer. Use graph nodes and
walkers for topology, typed `def:protect` functions for authenticated RPC, and
`by llm()` for model-backed agent abilities.
