import SwiftUI

extension Diagram {
    static func named(_ id: String) -> Diagram { catalog.first { $0.id == id }! }

    static let catalog: [Diagram] = [
        eeToMuMu, moller, compton, annihilation, betaDecay,
        quarkScattering, gluonSelfCoupling, vacuumPolarization, vertexCorrection, higgsToPhotons,
    ]

    static let eeToMuMu = Diagram(
        id: "ee-mumu",
        title: "e⁺e⁻ → μ⁺μ⁻",
        process: "e⁻ e⁺ → μ⁻ μ⁺",
        interaction: .qed,
        summary: "An electron and positron annihilate into a virtual photon, which then turns into a muon–antimuon pair.",
        details: [
            "Read it left to right. At the first vertex the electron and positron disappear and a **virtual photon** appears. At the second vertex the photon turns into a muon and an antimuon.",
            "This is an **s-channel** diagram: the virtual photon carries the whole collision energy, so q² = s = E²ᶜᵐ. A real photon always has q² = 0 (it's massless), so this photon is **off-shell**: it isn't on the mass shell q² = m² that real particles satisfy. That's allowed only because it is never observed.",
            "There are two vertices, so the amplitude goes as e² and the cross-section as α². Working through the Feynman rules gives the textbook result σ = 4πα²/3s.",
        ],
        amplitude: "𝓜 = [v̄(p₂)(−ieγ^μ)u(p₁)] · (−ig_μν / q²) · [ū(p₃)(−ieγ^ν)v(p₄)]",
        nodes: [.ext("a", 0.04, 0.12), .ext("b", 0.04, 0.88), .vtx("v1", 0.36, 0.5), .vtx("v2", 0.64, 0.5),
                .ext("c", 0.96, 0.12), .ext("d", 0.96, 0.88)],
        edges: [
            Edge("a", "v1", .electron),
            Edge("b", "v1", .positron, labelSide: 1),
            Edge("v1", "v2", .photon, label: "γ*"),
            Edge("v2", "c", .muon),
            Edge("v2", "d", .antimuon, labelSide: 1),
        ])

    static let moller = Diagram(
        id: "moller",
        title: "Møller scattering",
        process: "e⁻ e⁻ → e⁻ e⁻",
        interaction: .qed,
        summary: "Two electrons repel each other by exchanging a virtual photon.",
        details: [
            "This is a **t-channel** exchange. The photon carries momentum from one electron to the other, and q² = t < 0, which no real photon can have.",
            "The electrons are identical, so there's a second diagram with the two outgoing electrons swapped (the **u-channel**). Add the amplitudes *before* squaring. They come with a relative minus sign because electrons are fermions.",
            "The photon propagator 1/q² is where Coulomb's law comes from: its Fourier transform is the 1/r potential.",
            "The photon line is drawn vertically, but that doesn't mean it travels instantly. One diagram covers *every* time ordering of the internal vertices at once.",
        ],
        amplitude: "𝓜 = 𝓜_t − 𝓜_u,   𝓜_t = (−ie)² [ū₃γ^μu₁] (−ig_μν / t) [ū₄γ^νu₂]",
        nodes: [.ext("a", 0.04, 0.1), .ext("b", 0.04, 0.9), .vtx("v1", 0.5, 0.25), .vtx("v2", 0.5, 0.75),
                .ext("c", 0.96, 0.1), .ext("d", 0.96, 0.9)],
        edges: [
            Edge("a", "v1", .electron),
            Edge("v1", "c", .electron),
            Edge("b", "v2", .electron, labelSide: 1),
            Edge("v2", "d", .electron, labelSide: 1),
            Edge("v1", "v2", .photon, label: "γ*"),
        ])

    static let compton = Diagram(
        id: "compton",
        title: "Compton scattering",
        process: "e⁻ γ → e⁻ γ",
        interaction: .qed,
        summary: "A photon scatters off an electron: the electron absorbs it, briefly becomes virtual, then emits a new photon.",
        details: [
            "In this s-channel diagram the electron absorbs the incoming photon first. The internal electron line is virtual: its four-momentum p + k doesn't satisfy p² = m².",
            "There's a second (u-channel) diagram where the electron emits the outgoing photon *before* absorbing the incoming one. You need both for a gauge-invariant answer.",
            "At low energy this reduces to Thomson scattering, σ = 8πr²ₑ/3. At high energy you get the Klein–Nishina formula. Compton's 1923 wavelength-shift measurement was early evidence that light comes in quanta.",
        ],
        amplitude: "𝓜 = (−ie)² ε*_ν ε_μ ū(p′) γ^ν [i(p̸ + k̸ + m) / (s − m²)] γ^μ u(p)  +  (u-channel)",
        nodes: [.ext("a", 0.04, 0.82), .ext("b", 0.04, 0.18), .vtx("v1", 0.36, 0.5), .vtx("v2", 0.64, 0.5),
                .ext("c", 0.96, 0.82), .ext("d", 0.96, 0.18)],
        edges: [
            Edge("a", "v1", .electron, labelSide: 1),
            Edge("b", "v1", .photon),
            Edge("v1", "v2", .electron, labelSide: 1, label: "e*"),
            Edge("v2", "c", .electron, labelSide: 1),
            Edge("v2", "d", .photon),
        ])

    static let annihilation = Diagram(
        id: "annihilation",
        title: "Pair annihilation",
        process: "e⁻ e⁺ → γ γ",
        interaction: .qed,
        summary: "Matter meets antimatter: an electron and positron annihilate into two photons.",
        details: [
            "Follow the fermion arrow. It comes in along the electron, runs down the internal line, and leaves backward in time along the positron. That's one continuous fermion line.",
            "Why two photons and not one? A single real photon can't carry away the energy of a pair at rest while also having zero total momentum.",
            "PET scanners use this process. They detect the two back-to-back 511 keV photons from positrons annihilating in the body.",
        ],
        amplitude: "𝓜 = (−ie)² ε*_μ(k₁) ε*_ν(k₂) v̄(p₂) γ^ν [i(p̸₁ − k̸₁ + m) / (t − m²)] γ^μ u(p₁)  +  (crossed)",
        nodes: [.ext("a", 0.04, 0.15), .ext("b", 0.04, 0.85), .vtx("v1", 0.5, 0.28), .vtx("v2", 0.5, 0.72),
                .ext("c", 0.96, 0.12), .ext("d", 0.96, 0.88)],
        edges: [
            Edge("a", "v1", .electron),
            Edge("b", "v2", .positron, labelSide: 1),
            Edge("v1", "v2", .electron, label: "e*"),
            Edge("v1", "c", .photon),
            Edge("v2", "d", .photon, labelSide: 1),
        ])

    static let betaDecay = Diagram(
        id: "beta",
        title: "Neutron β decay",
        process: "n → p e⁻ ν̄ₑ",
        interaction: .weak,
        summary: "A down quark inside a neutron emits a virtual W⁻ and becomes an up quark, turning the neutron into a proton.",
        details: [
            "Reading the quark lines top to bottom, the neutron (ddu) becomes a proton (udu). The order is just how they're drawn; books usually write udd and uud. The virtual W⁻ carries away one unit of negative charge and decays to an electron and an electron antineutrino.",
            "The W is about 80,000 times heavier than the ~1 MeV of energy released. Its propagator 1/(q² − M²_W) ≈ −1/M²_W is therefore tiny. That's why the weak force is weak, and why a free neutron lives about 15 minutes.",
            "The other two quarks are **spectators**. They don't touch any vertex.",
            "The W vertex couples only to left-handed particles, through the factor (1 − γ⁵). This is where parity violation comes from.",
        ],
        amplitude: "𝓜 ≈ (g² / 8M²_W) [ū_u γ^μ(1 − γ⁵) u_d] [ū_e γ_μ(1 − γ⁵) v_ν],   G_F/√2 = g²/8M²_W",
        nodes: [.ext("a", 0.04, 0.55), .vtx("v1", 0.4, 0.55), .ext("c", 0.96, 0.55),
                .vtx("v2", 0.66, 0.22), .ext("e", 0.96, 0.05), .ext("f", 0.96, 0.36),
                .ext("s1", 0.04, 0.72), .ext("s2", 0.96, 0.72), .ext("s3", 0.04, 0.88), .ext("s4", 0.96, 0.88)],
        edges: [
            Edge("a", "v1", .down),
            Edge("v1", "c", .up),
            Edge("v1", "v2", .wMinus),
            Edge("v2", "e", .electron),
            Edge("v2", "f", .antiNuE, labelSide: 1),
            Edge("s1", "s2", .down),
            Edge("s3", "s4", .up),
        ])

    static let quarkScattering = Diagram(
        id: "qq",
        title: "Quark scattering",
        process: "u d → u d",
        interaction: .qcd,
        summary: "Two quarks scatter by exchanging a virtual gluon — the strong-force version of Møller scattering.",
        details: [
            "It's the same shape as photon exchange, but the gluon carries **color**: a color–anticolor combination. The quarks can swap colors in the process.",
            "The coupling α_s is about 0.1 at high energies and approaches 1 below a few hundred MeV. Near 1, adding more loops doesn't make the answer smaller, so perturbation theory stops working.",
            "At very high energies α_s gets *smaller* (**asymptotic freedom**, Nobel Prize 2004), so diagrams like this one describe jets at the LHC well.",
        ],
        amplitude: "𝓜 = (−ig_s)² [ū₃ γ^μ Tᵃ u₁] (−ig_μν δᵃᵇ / t) [ū₄ γ^ν Tᵇ u₂]",
        nodes: [.ext("a", 0.04, 0.1), .ext("b", 0.04, 0.9), .vtx("v1", 0.5, 0.25), .vtx("v2", 0.5, 0.75),
                .ext("c", 0.96, 0.1), .ext("d", 0.96, 0.9)],
        edges: [
            Edge("a", "v1", .up),
            Edge("v1", "c", .up),
            Edge("b", "v2", .down, labelSide: 1),
            Edge("v2", "d", .down, labelSide: 1),
            Edge("v1", "v2", .gluon, label: "g*"),
        ])

    static let gluonSelfCoupling = Diagram(
        id: "ggg",
        title: "Gluon self-interaction",
        process: "g g → g g",
        interaction: .qcd,
        summary: "Gluons scatter off each other through the three-gluon vertex — something photons can never do.",
        details: [
            "A photon has no electric charge, so no vertex joins three photons. A gluon *does* carry color charge, so gluons couple directly to other gluons.",
            "This self-interaction is what makes QCD so different from QED. It's behind both **confinement** (quarks are never seen alone) and **asymptotic freedom**.",
            "The full amplitude also needs s-, t- and u-channel exchanges plus a four-gluon contact vertex. Only the s-channel piece is drawn here.",
        ],
        amplitude: "𝓜 ∝ g_s² f^{abe} f^{cde} V_{μνλ} (−ig^{λσ}/s) V_{ρτσ} ε^μ ε^ν ε*^ρ ε*^τ  +  (t, u, contact)",
        nodes: [.ext("a", 0.04, 0.12), .ext("b", 0.04, 0.88), .vtx("v1", 0.36, 0.5), .vtx("v2", 0.64, 0.5),
                .ext("c", 0.96, 0.12), .ext("d", 0.96, 0.88)],
        edges: [
            Edge("a", "v1", .gluon),
            Edge("b", "v1", .gluon, labelSide: 1),
            Edge("v1", "v2", .gluon, label: "g*"),
            Edge("v2", "c", .gluon),
            Edge("v2", "d", .gluon, labelSide: 1),
        ])

    static let vacuumPolarization = Diagram(
        id: "vacpol",
        title: "Vacuum polarization",
        process: "e⁻ μ⁻ → e⁻ μ⁻ (1 loop)",
        interaction: .qed,
        summary: "The exchanged photon briefly splits into a virtual electron–positron pair — a one-loop correction.",
        details: [
            "The virtual photon fluctuates into an e⁺e⁻ pair that annihilates again. Empty space behaves like a polarizable medium.",
            "**Effect:** charge is screened at long distances, so the effective coupling *grows* at short distances. α runs from 1/137 at low energy to about 1/128 at the Z mass.",
            "The loop momentum isn't fixed by conservation, so you integrate over all of it, and the integral diverges. **Renormalization** absorbs the infinity into the measured value of e.",
            "Four vertices give e⁴. Compared with the tree diagram, that's a correction of order α/π ≈ 0.2%.",
        ],
        amplitude: "𝓜 ∝ e⁴ [ū₃γ^μu₁] (1/q²) Π_μν(q) (1/q²) [ū₄γ^νu₂],   Π ∝ ∫d⁴k Tr[γ S(k) γ S(k+q)]",
        nodes: [.ext("a", 0.04, 0.1), .vtx("v1", 0.5, 0.14), .ext("c", 0.96, 0.1),
                .vtx("v2", 0.5, 0.36), .vtx("v3", 0.5, 0.64),
                .ext("b", 0.04, 0.9), .vtx("v4", 0.5, 0.86), .ext("d", 0.96, 0.9)],
        edges: [
            Edge("a", "v1", .electron),
            Edge("v1", "c", .electron),
            Edge("b", "v4", .muon, labelSide: 1),
            Edge("v4", "d", .muon, labelSide: 1),
            Edge("v1", "v2", .photon, label: "γ*"),
            Edge("v2", "v3", .electron, bend: 0.8, labelSide: 1, label: "e"),
            Edge("v3", "v2", .electron, bend: 0.8, labelSide: 1, label: "e"),
            Edge("v3", "v4", .photon, label: "γ*"),
        ])

    static let vertexCorrection = Diagram(
        id: "g-2",
        title: "Electron g − 2",
        process: "e⁻ + field → e⁻ (1 loop)",
        interaction: .qed,
        summary: "The electron emits and reabsorbs a virtual photon while interacting with a magnetic field. This shifts its magnetic moment.",
        details: [
            "The photon at the top represents an external magnetic field. Without the loop you just get Dirac's prediction, g = 2.",
            "Julian Schwinger computed this one-loop diagram in 1948 and found a = (g − 2)/2 = α/2π ≈ 0.00116. That number is carved on his tombstone.",
            "Since then, physicists have calculated the 5-loop contributions (12,672 diagrams). Theory and experiment agree to better than one part in a billion, which makes this one of the most precise predictions in all of science.",
        ],
        amplitude: "𝓜 ∝ e³ ∫d⁴k  ū(p′) γ^ν S(p′ − k) γ^μ S(p − k) γ_ν u(p) · (1/k²) · A_μ(q)",
        nodes: [.ext("a", 0.04, 0.86), .vtx("v1", 0.3, 0.7), .vtx("v0", 0.5, 0.42), .vtx("v2", 0.7, 0.7),
                .ext("c", 0.96, 0.86), .ext("f", 0.5, 0.05)],
        edges: [
            Edge("a", "v1", .electron, labelSide: 1),
            Edge("v1", "v0", .electron, label: "e*"),
            Edge("v0", "v2", .electron, label: "e*"),
            Edge("v2", "c", .electron, labelSide: 1),
            Edge("f", "v0", .photon, label: "γ (field)"),
            Edge("v1", "v2", .photon, bend: 0.4, labelSide: 1, label: "γ*"),
        ])

    static let higgsToPhotons = Diagram(
        id: "h-gg",
        title: "Higgs → γγ",
        process: "H → γ γ",
        interaction: .higgs,
        summary: "The neutral Higgs decays to two photons through a triangle loop of charged top quarks.",
        details: [
            "The Higgs has no electric charge, so it can't couple to photons directly. It reaches them only through a **loop** of massive charged particles: mostly the top quark, plus W bosons in other diagrams.",
            "Each Higgs–fermion vertex is proportional to the fermion's mass (m_f / v). That's why the heaviest particle, the top, dominates the loop.",
            "Only about 0.2% of Higgs bosons decay this way. Even so, the clean two-photon signal was one of the two channels in which the Higgs was discovered at the LHC in 2012.",
        ],
        amplitude: "𝓜 ∝ (m_t/v) e² Q²_t N_c ∫d⁴k Tr[S(k) γ^μ S(k+p₁) γ^ν S(k−p₂)] ε*_μ ε*_ν",
        nodes: [.ext("a", 0.04, 0.5), .vtx("v1", 0.36, 0.5), .vtx("v2", 0.64, 0.24), .vtx("v3", 0.64, 0.76),
                .ext("c", 0.96, 0.1), .ext("d", 0.96, 0.9)],
        edges: [
            Edge("a", "v1", .higgs),
            Edge("v1", "v2", .top),
            Edge("v2", "v3", .top),
            Edge("v3", "v1", .top),
            Edge("v2", "c", .photon),
            Edge("v3", "d", .photon, labelSide: 1),
        ])
}
