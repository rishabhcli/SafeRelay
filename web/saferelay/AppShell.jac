"""Client routing for SafeRelay."""

import from "@jac/runtime" { Navigate, Router, Routes, Route }
import from .LandingPage { LandingPage }
import from .VerifiedCommandCenter { VerifiedCommandCenter }


def:pub SafeRelayApp -> JsxElement {
    return <Router>
        <Routes>
            <Route path="/" element={<LandingPage />} />
            <Route path="/login" element={<Navigate to="/ops" replace={True} />} />
            <Route path="/ops" element={<VerifiedCommandCenter />} />
            <Route path="*" element={<LandingPage />} />
        </Routes>
    </Router>;
}
