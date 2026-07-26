"""Jac-native operator authentication."""

import from "@jac/runtime" {
    Link,
    Navigate,
    jacIsLoggedIn,
    jacLogin,
    jacSignup,
    useNavigate,
}
import from "lucide-react" {
    ArrowLeft,
    ArrowRight,
    KeyRound,
    LockKeyhole,
    ShieldCheck,
    UserRound,
    Waypoints,
}


def:pub LoginPage -> JsxElement {
    has mode: str = "login",
        email: str = "",
        password: str = "",
        password_confirmation: str = "",
        busy: bool = False,
        error_message: str = "";

    navigate = useNavigate();

    async def handle_submit(event: FormEvent) -> None {
        event.preventDefault();
        clean_email: str = email.strip().lower();
        login_ok: bool = False;
        signup_result: dict[str, bool | str] | None = None;
        error_message = "";

        if not clean_email or "@" not in clean_email {
            error_message = "Enter a valid email address.";
            return;
        }
        if len(password) < 12 {
            error_message = "Use a password with at least 12 characters.";
            return;
        }
        if mode == "signup" and password != password_confirmation {
            error_message = "Passwords do not match.";
            return;
        }

        busy = True;
        try {
            if mode == "signup" {
                signup_result = await jacSignup(clean_email, password);
                if not signup_result or not signup_result["success"] {
                    error_message = "Account creation failed. The address may already be registered.";
                    busy = False;
                    return;
                }
            }
            login_ok = await jacLogin(clean_email, password);
            if login_ok {
                navigate("/ops");
                return;
            }
            error_message = "The email or password was not accepted.";
        } except Exception {
            error_message = "Authentication is temporarily unavailable. Try again shortly.";
        }
        busy = False;
    }

    def switch_mode(next_mode: str) {
        mode = next_mode;
        error_message = "";
        password = "";
        password_confirmation = "";
    }

    if jacIsLoggedIn() {
        return <Navigate to="/ops" replace={True} />;
    }

    return <div className="auth-shell">
        <header className="auth-nav">
            <Link to="/" className="brand-lockup">
                <span className="brand-mark"><Waypoints size={20} /></span>
                <span>SAFE<strong>RELAY</strong></span>
            </Link>
            <Link to="/" className="auth-back"><ArrowLeft size={15} /> Public view</Link>
        </header>

        <main className="auth-main">
            <section className="auth-context">
                <span className="auth-context__icon"><ShieldCheck size={25} /></span>
                <span className="eyebrow">PROTECTED OPERATIONS</span>
                <h1>Enter your command workspace.</h1>
                <p>
                    Each operator account receives an isolated, persistent Jac graph for
                    drills, relay traces, decisions, and agent briefings.
                </p>
                <div className="auth-assurances">
                    <span><LockKeyhole size={16} /> Authenticated Jac endpoints</span>
                    <span><UserRound size={16} /> Per-operator graph isolation</span>
                    <span><KeyRound size={16} /> No shared guest mutations</span>
                </div>
            </section>

            <section className="auth-panel">
                <div className="auth-tabs" role="tablist" aria-label="Authentication mode">
                    <button
                        type="button"
                        className={"is-active" if mode == "login" else ""}
                        onClick={lambda (_e: MouseEvent) { switch_mode("login"); }}
                    >Sign in</button>
                    <button
                        type="button"
                        className={"is-active" if mode == "signup" else ""}
                        onClick={lambda (_e: MouseEvent) { switch_mode("signup"); }}
                    >Create account</button>
                </div>

                <div className="auth-panel__heading">
                    <span className="eyebrow">OPERATOR ACCESS</span>
                    <h2>{"Create your workspace" if mode == "signup" else "Welcome back"}</h2>
                    <p>
                        {"Start with a private wildfire drill graph." if mode == "signup"
                        else "Continue in your isolated command graph."}
                    </p>
                </div>

                <form className="auth-form" onSubmit={handle_submit}>
                    <label htmlFor="operator-email">
                        <span>Email address</span>
                        <input
                            id="operator-email"
                            type="email"
                            value={email}
                            onChange={lambda (event: ChangeEvent) { email = event.target.value; }}
                            autoComplete="email"
                            placeholder="operator@example.com"
                            disabled={busy}
                            required
                        />
                    </label>
                    <label htmlFor="operator-password">
                        <span>Password</span>
                        <input
                            id="operator-password"
                            type="password"
                            value={password}
                            onChange={lambda (event: ChangeEvent) { password = event.target.value; }}
                            autoComplete={"new-password" if mode == "signup" else "current-password"}
                            placeholder="12 characters minimum"
                            disabled={busy}
                            minLength={12}
                            required
                        />
                    </label>
                    {if mode == "signup" {
                        <label htmlFor="operator-password-confirmation">
                            <span>Confirm password</span>
                            <input
                                id="operator-password-confirmation"
                                type="password"
                                value={password_confirmation}
                                onChange={lambda (event: ChangeEvent) { password_confirmation = event.target.value; }}
                                autoComplete="new-password"
                                placeholder="Repeat your password"
                                disabled={busy}
                                minLength={12}
                                required
                            />
                        </label>;
                    }}
                    {if error_message {
                        <div className="auth-error" role="alert">{error_message}</div>;
                    }}
                    <button type="submit" className="button button--primary auth-submit" disabled={busy}>
                        {if busy { "Connecting"; } else {
                            <>{"Create workspace" if mode == "signup" else "Enter command"} <ArrowRight size={16} /></>;
                        }}
                    </button>
                </form>
                <p className="auth-disclaimer">Simulation and training only. Not an emergency service.</p>
            </section>
        </main>
    </div>;
}
