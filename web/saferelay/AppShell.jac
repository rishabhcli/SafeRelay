"""Client routing and access control for SafeRelay."""

import from "@jac/runtime" { AuthGuard, Router, Routes, Route }
import from .LandingPage { LandingPage }
import from .LoginPage { LoginPage }
import from .CommandCenter { CommandCenter }


def:pub SafeRelayApp -> JsxElement {
    return <Router>
        <Routes>
            <Route path="/" element={<LandingPage />} />
            <Route path="/login" element={<LoginPage />} />
            <Route element={<AuthGuard redirect="/login" />}>
                <Route path="/ops" element={<CommandCenter />} />
            </Route>
            <Route path="*" element={<LandingPage />} />
        </Routes>
    </Router>;
}
