import SwiftUI

/// How a particle is drawn in a Feynman diagram.
enum LineStyle: String, CaseIterable, Identifiable {
    case fermion, photon, gluon, weak, higgs

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .fermion: return .primary
        case .photon: return .orange
        case .gluon: return .green
        case .weak: return .purple
        case .higgs: return .pink
        }
    }

    var title: String {
        switch self {
        case .fermion: return "Fermions (matter)"
        case .photon: return "Photon"
        case .gluon: return "Gluon"
        case .weak: return "W and Z bosons"
        case .higgs: return "Higgs boson"
        }
    }

    /// Particle family and spin, e.g. "Boson · spin 1".
    var family: String {
        switch self {
        case .fermion: return "Fermion · spin ½"
        case .photon, .gluon, .weak: return "Boson · spin 1"
        case .higgs: return "Boson · spin 0"
        }
    }

    var drawing: String {
        switch self {
        case .fermion: return "Solid line with an arrow"
        case .photon: return "Wavy line"
        case .gluon: return "Curly (coiled) line"
        case .weak: return "Long wavy line"
        case .higgs: return "Dashed line"
        }
    }

    var examples: String {
        switch self {
        case .fermion: return "e⁻, μ⁻, ν, quarks u d s c b t — and their antiparticles"
        case .photon: return "γ — the electromagnetic force carrier"
        case .gluon: return "g — the strong force carrier (8 colors)"
        case .weak: return "W⁺, W⁻, Z⁰ — the weak force carriers"
        case .higgs: return "H — spin-0 excitation of the Higgs field"
        }
    }

    var summary: String {
        switch self {
        case .fermion:
            return "The arrow tracks the flow of particle number, not the direction of motion. An arrow pointing forward in time is a particle; an arrow pointing backward in time is its antiparticle moving forward. Arrows never start or stop at a vertex — fermion lines are continuous."
        case .photon:
            return "Couples to electric charge with strength e (α = e²/4π ≈ 1/137). Photons are neutral, so two photons never meet at a vertex."
        case .gluon:
            return "Couples to color charge with strength g_s. Gluons carry color themselves, so there are three- and four-gluon vertices. This self-interaction leads to confinement."
        case .weak:
            return "Very heavy: the W weighs 80 GeV and the Z 91 GeV, about 100 proton masses. The weak coupling is actually stronger than electromagnetism's, but at everyday energies the heavy mass suppresses the propagator, 1/(q² − M²) ≈ −1/M². That suppression is why the force seems weak. The W also changes flavor: it turns d into u, or e⁻ into νₑ."
        case .higgs:
            return "Couples to particles in proportion to their mass. A dashed line is the generic notation for any spin-0 (scalar) particle."
        }
    }
}

struct Particle: Hashable, Identifiable {
    let id: String
    let name: String
    let symbol: String
    let style: LineStyle
    let charge: String
    let spin: String
    let mass: String
    let isAntiparticle: Bool
    let blurb: String
}

extension Particle {
    static let electron = Particle(
        id: "e-", name: "Electron", symbol: "e⁻", style: .fermion,
        charge: "−1", spin: "½", mass: "0.511 MeV", isAntiparticle: false,
        blurb: "The lightest charged lepton, and stable. Everything in chemistry is about electrons.")
    static let positron = Particle(
        id: "e+", name: "Positron", symbol: "e⁺", style: .fermion,
        charge: "+1", spin: "½", mass: "0.511 MeV", isAntiparticle: true,
        blurb: "The electron's antiparticle: same mass, opposite charge. Drawn as an electron line whose arrow points backward in time.")
    static let muon = Particle(
        id: "mu-", name: "Muon", symbol: "μ⁻", style: .fermion,
        charge: "−1", spin: "½", mass: "105.7 MeV", isAntiparticle: false,
        blurb: "A heavier copy of the electron (≈207× heavier). Decays in about 2.2 μs.")
    static let antimuon = Particle(
        id: "mu+", name: "Antimuon", symbol: "μ⁺", style: .fermion,
        charge: "+1", spin: "½", mass: "105.7 MeV", isAntiparticle: true,
        blurb: "The muon's antiparticle.")
    static let antiNuE = Particle(
        id: "nubar-e", name: "Electron antineutrino", symbol: "ν̄ₑ", style: .fermion,
        charge: "0", spin: "½", mass: "< 0.8 eV", isAntiparticle: true,
        blurb: "Nearly massless and feels only the weak force — it can pass through light-years of lead.")
    static let up = Particle(
        id: "u", name: "Up quark", symbol: "u", style: .fermion,
        charge: "+⅔", spin: "½", mass: "≈2.2 MeV", isAntiparticle: false,
        blurb: "The lightest quark. A proton is uud.")
    static let down = Particle(
        id: "d", name: "Down quark", symbol: "d", style: .fermion,
        charge: "−⅓", spin: "½", mass: "≈4.7 MeV", isAntiparticle: false,
        blurb: "A neutron is udd. Slightly heavier than the up quark, which is why free neutrons decay.")
    static let top = Particle(
        id: "t", name: "Top quark", symbol: "t", style: .fermion,
        charge: "+⅔", spin: "½", mass: "≈172.6 GeV", isAntiparticle: false,
        blurb: "The heaviest known elementary particle, so it couples most strongly to the Higgs.")
    static let photon = Particle(
        id: "gamma", name: "Photon", symbol: "γ", style: .photon,
        charge: "0", spin: "1", mass: "0", isAntiparticle: false,
        blurb: "Carrier of electromagnetism. It is neutral, so photons don't couple directly to each other.")
    static let gluon = Particle(
        id: "g", name: "Gluon", symbol: "g", style: .gluon,
        charge: "0 (but carries color)", spin: "1", mass: "0", isAntiparticle: false,
        blurb: "Carrier of the strong force. Comes in 8 color combinations and interacts with other gluons.")
    static let wMinus = Particle(
        id: "W-", name: "W⁻ boson", symbol: "W⁻", style: .weak,
        charge: "−1", spin: "1", mass: "80.4 GeV", isAntiparticle: false,
        blurb: "Charged carrier of the weak force. It changes flavor: d → u, e⁻ → νₑ.")
    static let higgs = Particle(
        id: "H", name: "Higgs boson", symbol: "H", style: .higgs,
        charge: "0", spin: "0", mass: "125.1 GeV", isAntiparticle: false,
        blurb: "Excitation of the Higgs field, which gives mass to the W, Z and fermions. Discovered at the LHC in 2012.")
}
