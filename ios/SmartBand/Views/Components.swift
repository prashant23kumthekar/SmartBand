/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Rings, the heart-rate trace, and the small battery chip.
 */

import SwiftUI

struct MetricRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(Whoop.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

struct RingColumn<Center: View>: View {
    var title: String
    var progress: Double
    var color: Color
    var diameter: CGFloat
    var lineWidth: CGFloat
    private let center: Center

    init(title: String,
         progress: Double,
         color: Color,
         diameter: CGFloat,
         lineWidth: CGFloat,
         @ViewBuilder center: () -> Center) {
        self.title = title
        self.progress = progress
        self.color = color
        self.diameter = diameter
        self.lineWidth = lineWidth
        self.center = center()
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.16))
                    .blur(radius: diameter * 0.12)
                    .frame(width: diameter * 0.72, height: diameter * 0.72)
                MetricRing(progress: progress, color: color, lineWidth: lineWidth)
                    .frame(width: diameter, height: diameter)
                center
            }
            .frame(width: diameter, height: diameter)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Whoop.secondaryText)
        }
    }
}

struct SeriesShape: Shape {
    var values: [Double]
    var closed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !values.isEmpty else { return path }

        let low: Double
        let high: Double
        if let minV = values.min(), let maxV = values.max(), maxV - minV >= 4 {
            let pad = (maxV - minV) * 0.2
            low = minV - pad
            high = maxV + pad
        } else {
            let mid = values[0]
            low = mid - 6
            high = mid + 6
        }

        func point(_ index: Int) -> CGPoint {
            let x: CGFloat
            if values.count == 1 {
                x = rect.midX
            } else {
                x = rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1)
            }
            let t = (values[index] - low) / (high - low)
            let y = rect.maxY - rect.height * CGFloat(t)
            return CGPoint(x: x, y: y)
        }

        if values.count == 1 {
            let y = point(0).y
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        } else {
            path.move(to: point(0))
            for index in 1..<values.count {
                path.addLine(to: point(index))
            }
        }

        if closed {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

struct HeartChart: View {
    var samples: [HeartSample]
    var color: Color

    var body: some View {
        let values = samples.map { Double($0.bpm) }
        ZStack {
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    Spacer()
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                }
                Spacer()
            }
            if !values.isEmpty {
                SeriesShape(values: values, closed: true)
                    .fill(LinearGradient(
                        colors: [color.opacity(0.32), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                SeriesShape(values: values, closed: false)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

struct BatteryChip: View {
    var level: Int?
    var connected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
            Text(level.map { "\($0)%" } ?? "—")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: Capsule())
    }

    private var symbol: String {
        guard let level else { return connected ? "battery.100" : "battery.0" }
        switch level {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    private var tint: Color {
        guard connected, let level else { return Whoop.secondaryText }
        return level < 20 ? Whoop.peak : .white
    }
}
