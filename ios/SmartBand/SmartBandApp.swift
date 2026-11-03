/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * SmartBand companion. Dark, ring-based home for the band's live metrics.
 */

import SwiftUI

@main
struct SmartBandApp: App {
    @State private var band = BandCentral()

    var body: some Scene {
        WindowGroup {
            HomeView(band: band)
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}
