import SwiftUI
import DriftCore

struct MuscleHighlightCard: View {
    let primaryMuscles: [String]
    let secondaryMuscles: [String]

    private var primaryRegions: Set<MuscleRegion> {
        MuscleRegionMapper.regions(for: primaryMuscles)
    }

    private var secondaryRegions: Set<MuscleRegion> {
        MuscleRegionMapper.regions(for: secondaryMuscles).subtracting(primaryRegions)
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            BodyMapPanel(front: true, primary: primaryRegions, secondary: secondaryRegions)
            Spacer(minLength: 0)
            BodyMapPanel(front: false, primary: primaryRegions, secondary: secondaryRegions)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Body Map Panel

private struct BodyMapPanel: View {
    let front: Bool
    let primary: Set<MuscleRegion>
    let secondary: Set<MuscleRegion>

    var body: some View {
        VStack(spacing: 4) {
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let dim = Color(white: 0.45, opacity: 0.20)
                let zones = front ? Self.frontZones : Self.backZones

                for (nx, ny, nw, nh, isEllipse) in Self.silhouette {
                    let rect = CGRect(x: nx * w, y: ny * h, width: nw * w, height: nh * h)
                    ctx.fill(
                        isEllipse ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 3),
                        with: .color(dim)
                    )
                }

                for region in secondary {
                    guard let shapes = zones[region] else { continue }
                    for (nx, ny, nw, nh) in shapes {
                        let rect = CGRect(x: nx * w, y: ny * h, width: nw * w, height: nh * h)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: 3),
                                 with: .color(Theme.accent.opacity(0.38)))
                    }
                }

                for region in primary {
                    guard let shapes = zones[region] else { continue }
                    for (nx, ny, nw, nh) in shapes {
                        let rect = CGRect(x: nx * w, y: ny * h, width: nw * w, height: nh * h)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: 3),
                                 with: .color(Theme.accent.opacity(0.85)))
                    }
                }
            }
            .frame(width: 70, height: 130)
            Text(front ? "Front" : "Back")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    // MARK: - Zone Tables (normalized 0–1)

    // (nx, ny, nw, nh, isEllipse)
    private static let silhouette: [(CGFloat, CGFloat, CGFloat, CGFloat, Bool)] = [
        (0.35, 0.00, 0.30, 0.11, true),   // head
        (0.43, 0.10, 0.14, 0.06, false),  // neck
        (0.26, 0.16, 0.48, 0.35, false),  // torso
        (0.09, 0.15, 0.17, 0.28, false),  // left upper arm
        (0.74, 0.15, 0.17, 0.28, false),  // right upper arm
        (0.10, 0.43, 0.14, 0.17, false),  // left forearm
        (0.76, 0.43, 0.14, 0.17, false),  // right forearm
        (0.26, 0.51, 0.47, 0.05, false),  // hips
        (0.27, 0.54, 0.20, 0.24, false),  // left thigh
        (0.53, 0.54, 0.20, 0.24, false),  // right thigh
        (0.28, 0.78, 0.18, 0.22, false),  // left lower leg
        (0.54, 0.78, 0.18, 0.22, false),  // right lower leg
    ]

    // (nx, ny, nw, nh)
    private static let frontZones: [MuscleRegion: [(CGFloat, CGFloat, CGFloat, CGFloat)]] = [
        .neck:       [(0.43, 0.10, 0.14, 0.06)],
        .shoulders:  [(0.09, 0.15, 0.17, 0.13), (0.74, 0.15, 0.17, 0.13)],
        .chest:      [(0.27, 0.17, 0.21, 0.14), (0.52, 0.17, 0.21, 0.14)],
        .biceps:     [(0.10, 0.30, 0.14, 0.13), (0.76, 0.30, 0.14, 0.13)],
        .forearms:   [(0.11, 0.44, 0.12, 0.15), (0.77, 0.44, 0.12, 0.15)],
        .abdominals: [(0.34, 0.32, 0.32, 0.18)],
        .quadriceps: [(0.28, 0.55, 0.19, 0.21), (0.53, 0.55, 0.19, 0.21)],
        .adductors:  [(0.37, 0.55, 0.13, 0.19), (0.50, 0.55, 0.13, 0.19)],
        .calves:     [(0.28, 0.79, 0.17, 0.20), (0.55, 0.79, 0.17, 0.20)],
    ]

    private static let backZones: [MuscleRegion: [(CGFloat, CGFloat, CGFloat, CGFloat)]] = [
        .neck:       [(0.43, 0.10, 0.14, 0.06)],
        .traps:      [(0.30, 0.16, 0.40, 0.12)],
        .shoulders:  [(0.09, 0.15, 0.17, 0.13), (0.74, 0.15, 0.17, 0.13)],
        .lats:       [(0.22, 0.28, 0.18, 0.20), (0.60, 0.28, 0.18, 0.20)],
        .middleBack: [(0.37, 0.26, 0.26, 0.13)],
        .lowerBack:  [(0.37, 0.39, 0.26, 0.12)],
        .triceps:    [(0.10, 0.30, 0.14, 0.13), (0.76, 0.30, 0.14, 0.13)],
        .forearms:   [(0.11, 0.44, 0.12, 0.15), (0.77, 0.44, 0.12, 0.15)],
        .glutes:     [(0.27, 0.52, 0.22, 0.11), (0.51, 0.52, 0.22, 0.11)],
        .hamstrings: [(0.27, 0.55, 0.20, 0.21), (0.53, 0.55, 0.20, 0.21)],
        .abductors:  [(0.17, 0.52, 0.12, 0.22), (0.71, 0.52, 0.12, 0.22)],
        .calves:     [(0.28, 0.79, 0.17, 0.20), (0.55, 0.79, 0.17, 0.20)],
    ]
}
