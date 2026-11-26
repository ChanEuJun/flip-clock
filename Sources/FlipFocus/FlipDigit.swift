import SwiftUI

/// A single split-flap tile. When `value` changes, the top flap (old digit)
/// folds down and the bottom flap (new digit) lands, like a mechanical flip clock.
struct FlipDigit: View {
    let value: String
    @State private var previous: String

    init(_ value: String) {
        self.value = value
        _previous = State(initialValue: value)
    }

    private struct Angles {
        var top: Double = -90   // hidden (edge-on) when idle
        var bottom: Double = 0  // resting flat when idle
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let prev = previous
            Color.clear
                .keyframeAnimator(initialValue: Angles(), trigger: value) { _, a in
                    ZStack {
                        // Static layers: new digit on top half, old digit on bottom half.
                        VStack(spacing: 0) {
                            Half(text: value, top: true, size: size)
                            Half(text: prev, top: false, size: size)
                        }
                        // Moving flaps.
                        VStack(spacing: 0) {
                            Half(text: prev, top: true, size: size)
                                .rotation3DEffect(.degrees(a.top), axis: (1, 0, 0), anchor: .bottom, perspective: 0.35)
                                .opacity(a.top <= -89.9 ? 0 : 1)
                            Half(text: value, top: false, size: size)
                                .rotation3DEffect(.degrees(a.bottom), axis: (1, 0, 0), anchor: .top, perspective: 0.35)
                        }
                        // Hinge line.
                        Rectangle()
                            .fill(Color.black.opacity(0.45))
                            .frame(height: max(1, size.height * 0.006))
                    }
                } keyframes: { _ in
                    KeyframeTrack(\.top) {
                        MoveKeyframe(0)
                        LinearKeyframe(-90, duration: 0.17, timingCurve: .easeIn)
                        LinearKeyframe(-90, duration: 0.17)
                    }
                    KeyframeTrack(\.bottom) {
                        MoveKeyframe(90)
                        LinearKeyframe(90, duration: 0.17)
                        LinearKeyframe(0, duration: 0.17, timingCurve: .easeOut)
                    }
                }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
        .onChange(of: value) { old, _ in previous = old }
    }
}

/// Top or bottom half of a full card face.
private struct Half: View {
    let text: String
    let top: Bool
    let size: CGSize

    var body: some View {
        CardFace(text: text, size: size, shadeLower: !top)
            .frame(width: size.width, height: size.height)
            .frame(width: size.width, height: size.height / 2, alignment: top ? .top : .bottom)
            .clipped()
    }
}

private struct CardFace: View {
    let text: String
    let size: CGSize
    let shadeLower: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.width * 0.1, style: .continuous)
                .fill(Color(white: shadeLower ? 0.155 : 0.17))
            Text(text)
                .font(.system(size: min(size.height * 0.84, size.width * 1.3), weight: .bold).width(.compressed))
                .foregroundStyle(
                    shadeLower
                        ? AnyShapeStyle(LinearGradient(colors: [Color(white: 0.82), .white],
                                                       startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.62)))
                        : AnyShapeStyle(Color.white)
                )
        }
    }
}
