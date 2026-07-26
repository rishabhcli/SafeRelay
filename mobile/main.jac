"""SafeRelay Jac mobile entry point."""

import "./assets/app.css";
cl import from .components.AppShell { AppShell }


cl def:pub app -> JsxElement {
    return <AppShell />;
}
