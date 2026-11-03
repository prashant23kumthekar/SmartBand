/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Scan sheet. The band advertises the name SmartBand with the Heart Rate service.
 */

import SwiftUI

struct ConnectView: View {
    var band: BandCentral
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Find your band")
                        .font(.system(size: 28, weight: .semibold))
                    Text("Heart rate, steps, motion, and battery appear once SmartBand is connected.")
                        .font(.subheadline)
                        .foregroundStyle(Whoop.secondaryText)
                }

                if band.discovered.isEmpty {
                    VStack(spacing: 14) {
                        MetricRing(
                            progress: band.link == .scanning ? 0.72 : 0.08,
                            color: band.link == .scanning ? Whoop.live : Color.white.opacity(0.35),
                            lineWidth: 8
                        )
                        .frame(width: 92, height: 92)
                        Text(band.link == .scanning ? "Listening nearby" : "Ready to search")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Whoop.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    VStack(spacing: 10) {
                        ForEach(band.discovered) { found in
                            Button {
                                band.connect(found.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(found.name)
                                            .font(.system(size: 17, weight: .semibold))
                                        Text(signal(found.rssi))
                                            .font(.footnote)
                                            .foregroundStyle(Whoop.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "link")
                                        .foregroundStyle(Whoop.tertiaryText)
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let statusMessage = band.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(Whoop.peak)
                }

                Spacer(minLength: 0)

                Button {
                    if band.link == .scanning {
                        band.stopScan()
                    } else {
                        band.startScan()
                    }
                } label: {
                    Text(band.link == .scanning ? "Stop" : "Search")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(band.link != .idle && band.link != .scanning)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Whoop.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        band.stopScan()
                        dismiss()
                    }
                }
            }
            .onChange(of: band.link) { _, link in
                if link == .connected {
                    dismiss()
                }
            }
        }
    }

    private func signal(_ rssi: Int) -> String {
        switch rssi {
        case -60...0: return "Strong signal"
        case -75..<(-60): return "Nearby"
        default: return "Faint signal"
        }
    }
}
