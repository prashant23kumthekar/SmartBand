/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Black canvas, hairline cards, and a few zone colors. The layout borrows
 * the ring-and-number rhythm of a recovery app, and only shows band data.
 */

import SwiftUI

enum Whoop {
    static let background = Color.black
    static let card = Color(red: 0.09, green: 0.09, blue: 0.09)
    static let track = Color.white.opacity(0.08)
    static let secondaryText = Color(white: 0.62)
    static let tertiaryText = Color(white: 0.42)
    static let calm = Color(red: 0.16, green: 0.86, blue: 0.58)
    static let steady = Color(red: 0.42, green: 0.64, blue: 1.0)
    static let high = Color(red: 0.98, green: 0.80, blue: 0.28)
    static let peak = Color(red: 1.0, green: 0.38, blue: 0.34)
    static let steps = Color(red: 0.96, green: 0.92, blue: 0.82)
    static let live = Color(red: 0.36, green: 0.78, blue: 1.0)

    static func color(for zone: HeartZone) -> Color {
        switch zone {
        case .none: return Color.white.opacity(0.35)
        case .calm: return calm
        case .steady: return steady
        case .high: return high
        case .peak: return peak
        }
    }
}

struct WhoopCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Whoop.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
    }
}
