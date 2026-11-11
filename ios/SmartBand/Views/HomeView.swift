/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Home screen. Heart rate sits in the center ring. Steps and motion sit
 * beside it. The trace below is the readings the band has sent this session.
 */

import SwiftUI

struct HomeView: View {
    var band: BandCentral
    @AppStorage("stepScale") private var stepScale = 10_000
    @State private var showConnect = false
    @State private var showDevice = false

    var body: some View {
        let metrics = band.metrics
        let zone = metrics.zone
        let zoneColor = Whoop.color(for: zone)

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if band.link != .connected {
                    connectBanner
                }
                rings(metrics: metrics, zoneColor: zoneColor)
                heartCard(metrics: metrics, zone: zone, zoneColor: zoneColor)
                HStack(spacing: 12) {
                    stepsCard(metrics.steps)
                    motionCard(metrics.moving)
                }
                Text("Readings come from the band. Not a medical device.")
                    .font(.footnote)
                    .foregroundStyle(Whoop.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Whoop.background.ignoresSafeArea())
        .sheet(isPresented: $showConnect) {
            ConnectView(band: band)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDevice) {
            DeviceSheet(band: band, stepScale: $stepScale)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide))
                    .font(.system(size: 28, weight: .semibold))
                Text(Date.now, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Whoop.secondaryText)
            }
            Spacer()
            Button {
                if band.link == .connected {
                    showDevice = true
                } else {
                    showConnect = true
                }
            } label: {
                BatteryChip(level: band.metrics.battery, connected: band.link == .connected)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(band.link == .connected ? "Band battery and device" : "Connect band")
        }
        .padding(.top, 8)
    }

    private var connectBanner: some View {
        Button {
            showConnect = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "wave.3.right")
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(bannerTitle)
                        .font(.system(size: 16, weight: .semibold))
                    Text(band.statusMessage ?? "Search for the band to fill these rings.")
                        .font(.footnote)
                        .foregroundStyle(Whoop.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Whoop.tertiaryText)
            }
        }
        .buttonStyle(.plain)
        .padding(16)
        .background(Whoop.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var bannerTitle: String {
        switch band.link {
        case .scanning: return "Searching"
        case .connecting: return "Connecting"
        case .bluetoothOff: return "Bluetooth is off"
        case .unauthorized: return "Bluetooth is blocked"
        default: return "Connect your band"
        }
    }

    private func rings(metrics: BandMetrics, zoneColor: Color) -> some View {
        GeometryReader { geo in
            let center = min(geo.size.width * 0.42, 188)
            let side = center * 0.62
            HStack(alignment: .center, spacing: 8) {
                RingColumn(
                    title: "STEPS",
                    progress: stepProgress(metrics.steps),
                    color: Whoop.steps,
                    diameter: side,
                    lineWidth: 8
                ) {
                    Text(stepText(metrics.steps))
                        .font(.system(size: side * 0.22, weight: .semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                RingColumn(
                    title: "BPM",
                    progress: heartProgress(metrics.heartRate),
                    color: zoneColor,
                    diameter: center,
                    lineWidth: 12
                ) {
                    Text(metrics.heartRate.map(String.init) ?? "—")
                        .font(.system(size: center * 0.32, weight: .semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                RingColumn(
                    title: metrics.moving == true ? "MOVING" : "STILL",
                    progress: metrics.moving == true ? 1 : 0.08,
                    color: metrics.moving == true ? Whoop.live : Color.white.opacity(0.45),
                    diameter: side,
                    lineWidth: 8
                ) {
                    Image(systemName: metrics.moving == true ? "figure.walk" : "figure.stand")
                        .font(.system(size: side * 0.28, weight: .medium))
                        .symbolEffect(.pulse, isActive: metrics.moving == true)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 230)
    }

    private func heartCard(metrics: BandMetrics, zone: HeartZone, zoneColor: Color) -> some View {
        WhoopCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("HEART RATE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Whoop.secondaryText)
                    Spacer()
                    Text(zone.title.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(zoneColor)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(metrics.heartRate.map(String.init) ?? "—")
                        .font(.system(size: 42, weight: .semibold))
                        .monospacedDigit()
                    Text("bpm")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Whoop.secondaryText)
                    Spacer()
                    if let low = metrics.samples.map(\.bpm).min(),
                       let high = metrics.samples.map(\.bpm).max() {
                        Text("\(low)–\(high)")
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Whoop.tertiaryText)
                    }
                }
                HeartChart(samples: metrics.samples, color: zoneColor)
                    .frame(height: 112)
                Text(heartCaption(metrics))
                    .font(.footnote)
                    .foregroundStyle(Whoop.tertiaryText)
            }
        }
    }

    private func stepsCard(_ steps: UInt32?) -> some View {
        WhoopCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("STEPS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Whoop.secondaryText)
                Text(steps.map { Int($0).formatted(.number) } ?? "—")
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("scale \(stepScale.formatted(.number))")
                    .font(.footnote)
                    .foregroundStyle(Whoop.tertiaryText)
            }
        }
    }

    private func motionCard(_ moving: Bool?) -> some View {
        WhoopCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("ACTIVITY")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Whoop.secondaryText)
                Text(motionTitle(moving))
                    .font(.system(size: 28, weight: .semibold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(moving == nil ? "No motion yet" : "From the accelerometer")
                    .font(.footnote)
                    .foregroundStyle(Whoop.tertiaryText)
            }
        }
    }

    private func stepProgress(_ steps: UInt32?) -> Double {
        guard let steps, stepScale > 0 else { return 0 }
        return min(Double(steps) / Double(stepScale), 1)
    }

    private func heartProgress(_ bpm: Int?) -> Double {
        guard let bpm else { return 0 }
        return min(Double(bpm) / 180, 1)
    }

    private func stepText(_ steps: UInt32?) -> String {
        guard let steps else { return "—" }
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000).replacingOccurrences(of: ".0k", with: "k")
        }
        return "\(steps)"
    }

    private func motionTitle(_ moving: Bool?) -> String {
        switch moving {
        case true: return "Live"
        case false: return "Still"
        case nil: return "—"
        }
    }

    private func heartCaption(_ metrics: BandMetrics) -> String {
        guard let last = metrics.samples.last else {
            return "The band takes a short reading, then rests the sensor."
        }
        return "Last reading \(last.time.formatted(.relative(presentation: .named)))"
    }
}

struct DeviceSheet: View {
    var band: BandCentral
    @Binding var stepScale: Int
    @Environment(\.dismiss) private var dismiss

    private let scales = [5_000, 8_000, 10_000, 15_000]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(band.deviceName)
                        .font(.title2.weight(.semibold))
                    Text(detailLine)
                        .font(.subheadline)
                        .foregroundStyle(Whoop.secondaryText)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("STEP RING")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Whoop.secondaryText)
                    Picker("Step ring", selection: $stepScale) {
                        ForEach(scales, id: \.self) { scale in
                            Text(scale.formatted(.number)).tag(scale)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Spacer()
                Button(role: .destructive) {
                    band.disconnect()
                    dismiss()
                } label: {
                    Text("Disconnect")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.08), in: Capsule())
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Whoop.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var detailLine: String {
        var parts = ["Connected"]
        if let model = band.metrics.model { parts.append(model) }
        if let firmware = band.metrics.firmware { parts.append("fw \(firmware)") }
        return parts.joined(separator: " · ")
    }
}

#Preview("Live") {
    HomeView(band: .previewLive)
        .preferredColorScheme(.dark)
}

#Preview("Waiting") {
    HomeView(band: .previewEmpty)
        .preferredColorScheme(.dark)
}
