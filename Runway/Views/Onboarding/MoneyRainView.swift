import SwiftUI

// MARK: - Data Model

private struct MoneyParticle: Identifiable {
    let id = UUID()
    let symbol: String
    let size: CGFloat
    let xFraction: CGFloat       // 0…1 across screen width
    let fallDuration: Double
    let rotationEnd: Double      // degrees
    let horizontalDrift: CGFloat // slight lateral movement
    let opacity: Double

    /// Whether this particle has started its fall animation.
    var isFalling = false
    /// Starting y offset for pre-seeded particles (0 = top of screen)
    var initialY: CGFloat = -50

    static func random() -> MoneyParticle {
        let symbols = ["$", "$", "$", "💵", "💰"]  // weighted toward $
        return MoneyParticle(
            symbol: symbols.randomElement() ?? "$",
            size: CGFloat.random(in: 18...36),
            xFraction: CGFloat.random(in: 0.05...0.95),
            fallDuration: Double.random(in: 3.5...6.0),
            rotationEnd: Double.random(in: -35...35),
            horizontalDrift: CGFloat.random(in: -20...20),
            opacity: Double.random(in: 0.2...0.6)
        )
    }
}

// MARK: - Pile Item

private struct PileItem: Identifiable {
    let id = UUID()
    let symbol: String
    let size: CGFloat
    let x: CGFloat       // absolute x position (0…screenWidth)
    let y: CGFloat       // absolute y position from top of pile frame
    let rotation: Double
    let opacity: Double
}

// MARK: - MoneyRainView

struct MoneyRainView: View {
    @Binding var pileHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var particles: [MoneyParticle] = []
    @State private var pileItems: [PileItem] = []
    @State private var timer: Timer?
    @State private var pileGenerated = false

    private let maxParticles = 20
    private let pileFrameHeight: CGFloat = 120  // total frame for pile

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height

            ZStack {
                // Falling particles
                if !reduceMotion {
                    ForEach(particles) { p in
                        Text(p.symbol)
                            .font(.system(size: p.size))
                            .opacity(p.opacity)
                            .offset(
                                x: p.isFalling ? p.horizontalDrift : 0,
                                y: p.isFalling ? H + 50 : p.initialY
                            )
                            .rotationEffect(.degrees(p.isFalling ? p.rotationEnd : 0))
                            .position(x: W * p.xFraction, y: 0)
                            .animation(
                                p.isFalling
                                    ? .linear(duration: p.fallDuration)
                                    : .none,
                                value: p.isFalling
                            )
                    }
                    .drawingGroup()
                }

                // Mound-shaped pile at bottom
                VStack {
                    Spacer()
                    ZStack {
                        ForEach(pileItems) { item in
                            Text(item.symbol)
                                .font(.system(size: item.size))
                                .opacity(item.opacity)
                                .rotationEffect(.degrees(item.rotation))
                                .position(x: item.x, y: item.y)
                        }
                    }
                    .frame(width: W, height: pileFrameHeight)
                }
            }
            .onAppear {
                if !pileGenerated {
                    generateMoundPile(screenWidth: W)
                    pileGenerated = true
                }
                pileHeight = pileFrameHeight
                if !reduceMotion {
                    seedInitialParticles(screenHeight: H)
                    startRain()
                }
            }
        }
        .accessibilityHidden(true)
        .ignoresSafeArea()
        .onDisappear {
            stopRain()
        }
    }

    // MARK: - Rain Control

    private func seedInitialParticles(screenHeight H: CGFloat) {
        // Spawn particles already mid-fall so rain is visible immediately
        for _ in 0..<14 {
            var p = MoneyParticle.random()
            p.isFalling = true
            p.initialY = CGFloat.random(in: (-50)...(H * 0.75))  // scattered across screen
            particles.append(p)

            // Remove after remaining fall time
            let fractionRemaining = max(0.1, 1.0 - Double(p.initialY / H))
            let remainingDuration = p.fallDuration * fractionRemaining
            let pid = p.id
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingDuration + 0.3) {
                particles.removeAll { $0.id == pid }
            }
        }
    }

    private func startRain() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            Task { @MainActor in
                if particles.count >= maxParticles {
                    particles.removeFirst()
                }

                let newParticle = MoneyParticle.random()
                particles.append(newParticle)
                let id = newParticle.id

                // Start falling on next frame so SwiftUI sees the state change
                DispatchQueue.main.async {
                    if let idx = particles.firstIndex(where: { $0.id == id }) {
                        particles[idx].isFalling = true
                    }
                }

                // Remove after it's fallen off screen
                let duration = newParticle.fallDuration
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) {
                    particles.removeAll { $0.id == id }
                }
            }
        }
    }

    private func stopRain() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Pile (Mound Shape)

    private func generateMoundPile(screenWidth W: CGFloat) {
        // Dense mound: pack items tightly in a grid-like pattern with jitter,
        // shaped by a bell curve so it's tallest in the center.
        let symbols = ["$", "$", "$", "💵", "💰"]

        // Lay items in columns across the width, with height determined by bell curve
        let columnSpacing: CGFloat = 12  // tight horizontal spacing
        let rowSpacing: CGFloat = 10     // tight vertical spacing
        let columns = Int(W / columnSpacing)

        for col in 0..<columns {
            let xBase = CGFloat(col) * columnSpacing + columnSpacing / 2
            let xFraction = xBase / W

            // Bell curve height at this x position
            let distFromCenter = abs(xFraction - 0.5) / 0.5  // 0…1
            let curve = 1.0 - distFromCenter * distFromCenter
            let maxHeightAtX = pileFrameHeight * curve * 0.9
            let rowCount = max(1, Int(maxHeightAtX / rowSpacing))

            for row in 0..<rowCount {
                let x = xBase + CGFloat.random(in: -5...5)  // jitter
                let heightInPile = CGFloat(row) * rowSpacing + CGFloat.random(in: 0...6)
                let y = pileFrameHeight - heightInPile

                pileItems.append(PileItem(
                    symbol: symbols.randomElement() ?? "$",
                    size: CGFloat.random(in: 14...22),
                    x: x,
                    y: y,
                    rotation: Double.random(in: -40...40),
                    opacity: Double.random(in: 0.5...0.95)
                ))
            }
        }

        // Extra scatter pass to fill any remaining gaps
        for _ in 0..<60 {
            let xFraction = CGFloat.random(in: 0.05...0.95)
            let x = W * xFraction
            let distFromCenter = abs(xFraction - 0.5) / 0.5
            let curve = 1.0 - distFromCenter * distFromCenter
            let maxHeightAtX = pileFrameHeight * curve * 0.85
            let heightInPile = CGFloat.random(in: 0...max(maxHeightAtX, 8))
            let y = pileFrameHeight - heightInPile

            pileItems.append(PileItem(
                symbol: symbols.randomElement() ?? "$",
                size: CGFloat.random(in: 12...18),
                x: x,
                y: y,
                rotation: Double.random(in: -50...50),
                opacity: Double.random(in: 0.4...0.85)
            ))
        }
    }
}
