"""Public SafeRelay product surface."""

import from "@jac/runtime" { Link }
import from "lucide-react" {
    Activity,
    ArrowRight,
    Bluetooth,
    Check,
    ChevronRight,
    CircleGauge,
    LocateFixed,
    Network,
    Radio,
    Satellite,
    ShieldCheck,
    Signal,
    Smartphone,
    Waypoints,
}


def:pub MeshSignalDemo -> JsxElement {
    has phase: int = 0,
        scenario: str = "wildfire";

    def advance(_e: MouseEvent) {
        phase = (phase + 1) % 4;
    }

    def choose_scenario(next_scenario: str) {
        scenario = next_scenario;
        phase = 0;
    }

    scenario_label: str = "Paradise Fire" if scenario == "wildfire" else (
        "Oklahoma Tornado" if scenario == "tornado" else (
            "Galveston Hurricane" if scenario == "hurricane" else "San Andreas Quake"
        )
    );
    origin_label: str = {
        "wildfire": "EVAC SOS",
        "tornado": "SHELTER SOS",
        "hurricane": "FLOOD SOS",
        "earthquake": "RESCUE SOS",
    }[scenario];

    return <div className="mesh-demo" aria-label="Interactive mesh relay simulation">
        <div className="mesh-demo__header">
            <div>
                <span className="eyebrow">LIVE TOPOLOGY</span>
                <h2>{scenario_label} · AM-7C21</h2>
            </div>
            <span className="live-indicator"><span></span> DRILL ACTIVE</span>
        </div>
        <div className="public-scenario-selector" role="tablist" aria-label="Disaster scenario">
            {for option in ["wildfire", "tornado", "hurricane", "earthquake"] {
                <button key={option} role="tab" aria-selected={scenario == option} className={"is-active" if scenario == option else ""} onClick={lambda (_e: MouseEvent) { choose_scenario(option); }}>{option.title()}</button>
            }}
        </div>
        <div className="mesh-canvas">
            <div className="terrain terrain--one"></div>
            <div className="terrain terrain--two"></div>
            <div className="mesh-route mesh-route--one"></div>
            <div className="mesh-route mesh-route--two"></div>
            <div className="mesh-route mesh-route--three"></div>

            <button
                className={"mesh-node mesh-node--origin is-active" if phase >= 0 else "mesh-node mesh-node--origin"}
                onClick={advance}
                aria-label="Advance origin signal"
            >
                <Smartphone size={18} />
                <span>{origin_label}</span>
                <small>38% battery</small>
            </button>
            <button
                className={"mesh-node mesh-node--relay-a is-active" if phase >= 1 else "mesh-node mesh-node--relay-a"}
                onClick={advance}
                aria-label="Advance first relay"
            >
                <Radio size={18} />
                <span>RELAY 01</span>
                <small>-68 dBm</small>
            </button>
            <button
                className={"mesh-node mesh-node--relay-b is-active" if phase >= 2 else "mesh-node mesh-node--relay-b"}
                onClick={advance}
                aria-label="Advance second relay"
            >
                <Radio size={18} />
                <span>RELAY 02</span>
                <small>-73 dBm</small>
            </button>
            <button
                className={"mesh-node mesh-node--gateway is-active" if phase >= 3 else "mesh-node mesh-node--gateway"}
                onClick={advance}
                aria-label="Advance gateway delivery"
            >
                <Satellite size={18} />
                <span>GATEWAY</span>
                <small>uplink ready</small>
            </button>
            <div className="map-label map-label--north">{scenario_label.upper()}</div>
            <div className="map-label map-label--canyon">OUTAGE CORRIDOR</div>
        </div>
        <div className="packet-status">
            <div>
                <span>PACKET STATE</span>
                <strong>{["Broadcasting", "Relayed by AM-1F09", "Crossing outage", "Delivered to command"][phase]}</strong>
            </div>
            <div className="packet-steps">
                {for idx in range(4) {
                    <span key={idx} className={"complete" if idx <= phase else ""}></span>
                }}
            </div>
            <button className="icon-action" onClick={advance} title="Advance packet">
                <ChevronRight size={18} />
            </button>
        </div>
    </div>;
}


def:pub LandingPage -> JsxElement {
    return <div className="landing">
        <header className="public-nav">
            <Link to="/" className="brand-lockup">
                <span className="brand-mark"><Waypoints size={20} /></span>
                <span>SAFE<strong>RELAY</strong></span>
            </Link>
            <nav>
                <a href="#network">Network</a>
                <a href="#readiness">Readiness</a>
                <Link to="/ops">Operations</Link>
            </nav>
            <Link to="/ops" className="button button--compact button--dark">
                Open command <ArrowRight size={15} />
            </Link>
        </header>

        <main>
            <section className="hero">
                <div className="hero__copy">
                    <div className="status-kicker">
                        <span className="status-dot"></span>
                        RESILIENT COMMUNICATIONS
                    </div>
                    <h1>SafeRelay</h1>
                    <p className="hero__lede">
                        Emergency signals move phone to phone when cellular infrastructure fails,
                        then surface in one operator-grade command view.
                    </p>
                    <div className="hero__actions">
                        <Link to="/ops" className="button button--primary">
                            Enter live drill <ArrowRight size={17} />
                        </Link>
                        <a href="#network" className="text-link">
                            View relay architecture <ChevronRight size={16} />
                        </a>
                    </div>
                    <div className="hero__proof">
                        <span><Check size={14} /> Offline BLE relay</span>
                        <span><Check size={14} /> Graph-native operations</span>
                        <span><Check size={14} /> Typed Jac agent</span>
                    </div>
                </div>
                <MeshSignalDemo />
            </section>

            <section className="signal-strip" aria-label="Network status">
                <div><span>DRILL NETWORK</span><strong>158</strong><small>phones online</small></div>
                <div><span>DELIVERY</span><strong>100%</strong><small>via mesh path</small></div>
                <div><span>MEDIAN ROUTE</span><strong>3.2</strong><small>BLE hops</small></div>
                <div><span>WEAKEST ZONE</span><strong>64%</strong><small>Canyon health</small></div>
            </section>

            <section id="network" className="system-band">
                <div className="section-heading">
                    <span className="eyebrow">THE RESILIENCE LOOP</span>
                    <h2>A signal path built for the moment the network disappears.</h2>
                    <p>Each phone becomes both beacon and bridge. Jac walkers make the relay path a queryable operations graph.</p>
                </div>
                <div className="system-flow">
                    <article>
                        <span className="flow-index">01</span>
                        <Smartphone size={24} />
                        <h3>Origin</h3>
                        <p>An SOS is signed, prioritized, and broadcast over Bluetooth Low Energy.</p>
                    </article>
                    <ArrowRight className="flow-arrow" size={20} />
                    <article>
                        <span className="flow-index">02</span>
                        <Bluetooth size={24} />
                        <h3>Relay</h3>
                        <p>Nearby phones carry the packet across the disconnected area.</p>
                    </article>
                    <ArrowRight className="flow-arrow" size={20} />
                    <article>
                        <span className="flow-index">03</span>
                        <Satellite size={24} />
                        <h3>Gateway</h3>
                        <p>The first reachable uplink delivers the complete path to command.</p>
                    </article>
                    <ArrowRight className="flow-arrow" size={20} />
                    <article>
                        <span className="flow-index">04</span>
                        <ShieldCheck size={24} />
                        <h3>Response</h3>
                        <p>Operators triage, assign, and resolve against shared graph state.</p>
                    </article>
                </div>
            </section>

            <section id="readiness" className="capability-band">
                <div className="capability-visual">
                    <div className="radar">
                        <span className="radar__ring radar__ring--a"></span>
                        <span className="radar__ring radar__ring--b"></span>
                        <span className="radar__sweep"></span>
                        <span className="radar__point radar__point--a"></span>
                        <span className="radar__point radar__point--b"></span>
                        <span className="radar__point radar__point--c"></span>
                        <Network size={38} />
                    </div>
                    <div className="readout">
                        <span>NETWORK READINESS</span>
                        <strong>84</strong>
                        <small>MODELED SCORE</small>
                    </div>
                </div>
                <div className="capability-copy">
                    <span className="eyebrow">ONE CONTINUOUS JAC SYSTEM</span>
                    <h2>Topology, persistence, decisions, and interface share one type system.</h2>
                    <div className="capability-list">
                        <div><CircleGauge size={20} /><span><strong>Operational state</strong> Persistent incidents, alerts, responders, and activity.</span></div>
                        <div><LocateFixed size={20} /><span><strong>Relay provenance</strong> Walk every hop from origin phone to gateway.</span></div>
                        <div><Activity size={20} /><span><strong>Advisory agent</strong> Structured briefings grounded in the current drill graph.</span></div>
                        <div><Signal size={20} /><span><strong>Resilient demo</strong> Complete deterministic operation without provider credentials.</span></div>
                    </div>
                    <Link to="/ops" className="button button--light">
                        Inspect the operation <ArrowRight size={17} />
                    </Link>
                </div>
            </section>
        </main>

        <footer className="public-footer">
            <div className="brand-lockup">
                <span className="brand-mark"><Waypoints size={20} /></span>
                <span>SAFE<strong>RELAY</strong></span>
            </div>
            <p>Simulation and training system. Not an official emergency service.</p>
            <span>Built end to end in Jac.</span>
        </footer>
    </div>;
}
