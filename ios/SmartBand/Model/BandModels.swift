/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Values published by the band firmware:
 *   Heart Rate Measurement 0x2A37, flags 0x06 then a uint8 bpm
 *   Battery Level 0x2A19, uint8 percent
 *   Activity steps fb5a0002-..., uint32 little-endian
 *   Activity moving fb5a0003-..., uint8, 1 while the IMU reports motion
 */

import Foundation

enum HeartZone: Equatable {
    case none
    case calm
    case steady
    case high
    case peak

    var title: String {
        switch self {
        case .none: return "Waiting"
        case .calm: return "Calm"
        case .steady: return "Steady"
        case .high: return "High"
        case .peak: return "Peak"
        }
    }

    static func zone(for bpm: Int?) -> HeartZone {
        guard let bpm, bpm > 0 else { return .none }
        switch bpm {
        case ..<90: return .calm
        case ..<120: return .steady
        case ..<150: return .high
        default: return .peak
        }
    }
}

struct HeartSample: Identifiable, Equatable {
    let id: UUID
    let time: Date
    let bpm: Int

    init(id: UUID = UUID(), time: Date, bpm: Int) {
        self.id = id
        self.time = time
        self.bpm = bpm
    }
}

struct BandMetrics: Equatable {
    var heartRate: Int?
    var steps: UInt32?
    var moving: Bool?
    var battery: Int?
    var firmware: String?
    var model: String?
    var samples: [HeartSample] = []

    var zone: HeartZone {
        HeartZone.zone(for: heartRate)
    }

    static let empty = BandMetrics()
}

enum LinkState: Equatable {
    case unknown
    case bluetoothOff
    case unauthorized
    case idle
    case scanning
    case connecting
    case connected
}

struct DiscoveredBand: Identifiable, Equatable {
    let id: UUID
    var name: String
    var rssi: Int
}

enum BandParsing {
    static func heartRate(from data: Data) -> Int? {
        guard let flags = data.first, data.count >= 2 else { return nil }
        let bpm: Int
        if flags & 0x01 == 0 {
            bpm = Int(data[1])
        } else if data.count >= 3 {
            bpm = Int(UInt16(data[1]) | (UInt16(data[2]) << 8))
        } else {
            return nil
        }
        guard (1...250).contains(bpm) else { return nil }
        return bpm
    }

    static func steps(from data: Data) -> UInt32? {
        guard data.count >= 4 else { return nil }
        return UInt32(data[0])
            | (UInt32(data[1]) << 8)
            | (UInt32(data[2]) << 16)
            | (UInt32(data[3]) << 24)
    }

    static func moving(from data: Data) -> Bool? {
        guard let byte = data.first else { return nil }
        return byte != 0
    }

    static func battery(from data: Data) -> Int? {
        guard let byte = data.first, byte <= 100 else { return nil }
        return Int(byte)
    }

    static func text(from data: Data) -> String? {
        let bytes = data.prefix { $0 != 0 }
        guard let string = String(data: bytes, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else {
            return nil
        }
        return string
    }
}

enum BandGATT {
    static let heartRateService = "180D"
    static let heartRateMeasurement = "2A37"
    static let batteryService = "180F"
    static let batteryLevel = "2A19"
    static let deviceInfoService = "180A"
    static let modelNumber = "2A24"
    static let firmwareRevision = "2A26"
    static let manufacturerName = "2A29"
    static let activityService = "FB5A0001-6C4B-4A5A-9F10-B1C2D3E4F500"
    static let steps = "FB5A0002-6C4B-4A5A-9F10-B1C2D3E4F500"
    static let moving = "FB5A0003-6C4B-4A5A-9F10-B1C2D3E4F500"
    static let advertisedName = "SmartBand"
}
