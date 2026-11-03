/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Central for the SmartBand peripheral. Advertising carries Heart Rate,
 * Battery, and Device Information. Steps and moving are on the custom
 * activity service and show up after connection.
 */

import CoreBluetooth
import Foundation
import Observation
import os

@Observable
final class BandCentral: NSObject {
    private(set) var link: LinkState = .unknown
    private(set) var metrics = BandMetrics.empty
    private(set) var discovered: [DiscoveredBand] = []
    private(set) var deviceName = BandGATT.advertisedName
    private(set) var statusMessage: String?

    private let preview: Bool
    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var shouldReconnect = true
    private let savedIDKey = "smartband.peripheral"

    private static let log = Logger(subsystem: "com.smartband.app", category: "ble")

    override init() {
        preview = false
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    init(preview metrics: BandMetrics, link: LinkState) {
        preview = true
        self.metrics = metrics
        self.link = link
        super.init()
    }

    func startScan() {
        guard !preview, let central, central.state == .poweredOn else { return }
        discovered.removeAll()
        peripherals.removeAll()
        statusMessage = nil
        link = .scanning
        central.scanForPeripherals(
            withServices: [CBUUID(string: BandGATT.heartRateService)],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func stopScan() {
        central?.stopScan()
        if link == .scanning {
            link = .idle
        }
    }

    func connect(_ id: UUID) {
        guard !preview, let central, let peripheral = peripherals[id] else { return }
        central.stopScan()
        shouldReconnect = true
        connectedPeripheral = peripheral
        deviceName = peripheral.name ?? BandGATT.advertisedName
        link = .connecting
        statusMessage = nil
        UserDefaults.standard.set(id.uuidString, forKey: savedIDKey)
        central.connect(peripheral, options: nil)
    }

    func disconnect() {
        shouldReconnect = false
        UserDefaults.standard.removeObject(forKey: savedIDKey)
        if let connectedPeripheral, let central {
            central.cancelPeripheralConnection(connectedPeripheral)
        }
        connectedPeripheral = nil
        if link == .connected || link == .connecting {
            link = .idle
        }
    }

    private func updateMetrics(_ body: (inout BandMetrics) -> Void) {
        var next = metrics
        body(&next)
        metrics = next
    }

    private func apply(_ data: Data, characteristic: CBUUID) {
        if characteristic == CBUUID(string: BandGATT.heartRateMeasurement) {
            guard let bpm = BandParsing.heartRate(from: data) else { return }
            updateMetrics { metrics in
                metrics.heartRate = bpm
                metrics.samples.append(HeartSample(time: Date(), bpm: bpm))
                if metrics.samples.count > 120 {
                    metrics.samples.removeFirst(metrics.samples.count - 120)
                }
            }
        } else if characteristic == CBUUID(string: BandGATT.batteryLevel) {
            guard let level = BandParsing.battery(from: data) else { return }
            updateMetrics { $0.battery = level }
        } else if characteristic == CBUUID(string: BandGATT.steps) {
            guard let steps = BandParsing.steps(from: data) else { return }
            updateMetrics { $0.steps = steps }
        } else if characteristic == CBUUID(string: BandGATT.moving) {
            guard let moving = BandParsing.moving(from: data) else { return }
            updateMetrics { $0.moving = moving }
        } else if characteristic == CBUUID(string: BandGATT.firmwareRevision) {
            guard let text = BandParsing.text(from: data) else { return }
            updateMetrics { $0.firmware = text }
        } else if characteristic == CBUUID(string: BandGATT.modelNumber) {
            guard let text = BandParsing.text(from: data) else { return }
            updateMetrics { $0.model = text }
        }
    }

    private func reconnectIfKnown() {
        guard shouldReconnect,
              link != .connected,
              let central,
              let saved = UserDefaults.standard.string(forKey: savedIDKey),
              let id = UUID(uuidString: saved) else {
            return
        }
        let known = central.retrievePeripherals(withIdentifiers: [id])
        guard let peripheral = known.first else { return }
        peripherals[id] = peripheral
        connect(id)
    }
}

extension BandCentral: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if link != .connected {
                link = .idle
            }
            statusMessage = nil
            reconnectIfKnown()
        case .poweredOff:
            link = .bluetoothOff
            statusMessage = "Turn Bluetooth on to reach the band."
        case .unauthorized:
            link = .unauthorized
            statusMessage = "Allow Bluetooth for SmartBand in Settings."
        case .unsupported:
            link = .bluetoothOff
            statusMessage = "This iPhone has no Bluetooth radio."
        default:
            link = .unknown
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let advertised = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = peripheral.name ?? advertised
        guard name?.caseInsensitiveCompare(BandGATT.advertisedName) == .orderedSame else { return }

        peripherals[peripheral.identifier] = peripheral
        let rssi = RSSI.intValue
        let shown = (rssi > 0 || rssi < -120) ? -90 : rssi
        var next = discovered
        if let index = next.firstIndex(where: { $0.id == peripheral.identifier }) {
            next[index].rssi = shown
            next[index].name = name ?? BandGATT.advertisedName
        } else {
            next.append(DiscoveredBand(id: peripheral.identifier,
                                       name: name ?? BandGATT.advertisedName,
                                       rssi: shown))
        }
        next.sort { $0.rssi > $1.rssi }
        discovered = next
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Self.log.info("Connected")
        connectedPeripheral = peripheral
        deviceName = peripheral.name ?? BandGATT.advertisedName
        link = .connected
        statusMessage = nil
        peripheral.delegate = self
        peripheral.discoverServices([
            CBUUID(string: BandGATT.heartRateService),
            CBUUID(string: BandGATT.batteryService),
            CBUUID(string: BandGATT.deviceInfoService),
            CBUUID(string: BandGATT.activityService),
        ])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        link = .idle
        statusMessage = "Could not connect. Move the band closer and search again."
        Self.log.error("Connect failed: \(error?.localizedDescription ?? "unknown", privacy: .public)")
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
        }
        guard shouldReconnect else {
            link = .idle
            return
        }
        link = .connecting
        central.connect(peripheral, options: nil)
    }
}

extension BandCentral: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            Self.log.error("Services: \(error.localizedDescription, privacy: .public)")
            return
        }
        for service in peripheral.services ?? [] {
            let ids = Self.characteristicIDs(for: service.uuid)
            guard !ids.isEmpty else { continue }
            peripheral.discoverCharacteristics(ids, for: service)
        }
    }

    private static func characteristicIDs(for service: CBUUID) -> [CBUUID] {
        if service == CBUUID(string: BandGATT.heartRateService) {
            return [CBUUID(string: BandGATT.heartRateMeasurement)]
        }
        if service == CBUUID(string: BandGATT.batteryService) {
            return [CBUUID(string: BandGATT.batteryLevel)]
        }
        if service == CBUUID(string: BandGATT.deviceInfoService) {
            return [
                CBUUID(string: BandGATT.modelNumber),
                CBUUID(string: BandGATT.firmwareRevision),
                CBUUID(string: BandGATT.manufacturerName),
            ]
        }
        if service == CBUUID(string: BandGATT.activityService) {
            return [CBUUID(string: BandGATT.steps), CBUUID(string: BandGATT.moving)]
        }
        return []
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error {
            Self.log.error("Characteristics: \(error.localizedDescription, privacy: .public)")
            return
        }
        for characteristic in service.characteristics ?? [] {
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            Self.log.error("Value: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard let data = characteristic.value else { return }
        apply(data, characteristic: characteristic.uuid)
    }
}

extension BandCentral {
    static var previewLive: BandCentral {
        let start = Date().addingTimeInterval(-48 * 60)
        let samples = (0..<48).map { index in
            HeartSample(
                time: start.addingTimeInterval(Double(index) * 60),
                bpm: 64 + (index % 9) + (index > 30 ? 8 : 0)
            )
        }
        return BandCentral(
            preview: BandMetrics(
                heartRate: 72,
                steps: 4281,
                moving: true,
                battery: 78,
                firmware: "0.4.0",
                model: "SmartBand",
                samples: samples
            ),
            link: .connected
        )
    }

    static var previewEmpty: BandCentral {
        BandCentral(preview: .empty, link: .idle)
    }
}
