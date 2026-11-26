import SwiftUI

/// Tile proportions, shared with the layout math in TileGrid.
enum TileMetrics {
    static let aspect: CGFloat = 1.25      // height / width
    static let pairGap: CGFloat = 0.08     // gap between the two digits of a pair, × tile width
    static let groupGap: CGFloat = 0.3     // gap between HH, MM, SS groups when horizontal, × tile width
}

/// A static split-flap style tile: two-tone card, hinge line, shaded lower half of the digit.
struct DigitTile: View {
    let value: String

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            ZStack {
                VStack(spacing: 0) {
                    Color(white: 0.17)
                    Color(white: 0.155)
                }
                .clipShape(RoundedRectangle(cornerRadius: s.width * 0.1, style: .continuous))
                Text(value)
                    .font(.system(size: min(s.height * 0.84, s.width * 1.3), weight: .bold).width(.compressed))
                    .frame(width: s.width, height: s.height)
                    .foregroundStyle(LinearGradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.5),
                        .init(color: Color(white: 0.8), location: 0.5),
                        .init(color: .white, location: 0.78),
                    ], startPoint: .top, endPoint: .bottom))
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .frame(height: max(1, s.height * 0.006))
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
    }
}
