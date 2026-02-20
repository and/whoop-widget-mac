import Foundation
import CoreBluetooth

struct HeartRateReading {
    let timestamp: Date
    let heartRate: Int
}

class WhoopBLEService: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var currentHeartRate: Int?
    @Published var statusMessage = "Scanning for WHOOP..."
    @Published var heartRateHistory: [HeartRateReading] = []

    private var centralManager: CBCentralManager!
    private var whoopPeripheral: CBPeripheral?

    // Standard Bluetooth Heart Rate Service UUID
    private let heartRateServiceUUID = CBUUID(string: "0x180D")
    private let heartRateCharacteristicUUID = CBUUID(string: "0x2A37")

    // Keep 5 minutes of history
    private let historyDuration: TimeInterval = 5 * 60

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        if centralManager.state == .poweredOn {
            statusMessage = "Scanning for WHOOP..."
            centralManager.scanForPeripherals(
                withServices: [heartRateServiceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        } else {
            statusMessage = "Bluetooth is not available"
        }
    }

    func stopScanning() {
        centralManager.stopScan()
    }

    func disconnect() {
        if let peripheral = whoopPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension WhoopBLEService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        case .poweredOff:
            statusMessage = "Bluetooth is powered off"
        case .unauthorized:
            statusMessage = "Bluetooth permission denied"
        case .unsupported:
            statusMessage = "Bluetooth not supported"
        default:
            statusMessage = "Bluetooth unavailable"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Look for WHOOP device by name
        if let name = peripheral.name, name.contains("WHOOP") {
            statusMessage = "Found WHOOP device: \(name)"
            whoopPeripheral = peripheral
            centralManager.stopScan()
            centralManager.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusMessage = "Connected to WHOOP"
        isConnected = true
        peripheral.delegate = self
        peripheral.discoverServices([heartRateServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        statusMessage = "Disconnected from WHOOP"
        isConnected = false
        currentHeartRate = nil
        whoopPeripheral = nil

        // Attempt to reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        statusMessage = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
        isConnected = false

        // Retry scanning
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.startScanning()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension WhoopBLEService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid == heartRateServiceUUID {
                peripheral.discoverCharacteristics([heartRateCharacteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == heartRateCharacteristicUUID {
                // Subscribe to heart rate notifications
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == heartRateCharacteristicUUID,
              let data = characteristic.value else { return }

        // Parse heart rate from BLE data
        // Format: https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0/
        let heartRate = parseHeartRate(from: data)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentHeartRate = heartRate
            self.statusMessage = "Receiving heart rate data"

            // Add to history
            let reading = HeartRateReading(timestamp: Date(), heartRate: heartRate)
            self.heartRateHistory.append(reading)

            // Remove readings older than 5 minutes
            let cutoffTime = Date().addingTimeInterval(-self.historyDuration)
            self.heartRateHistory.removeAll { $0.timestamp < cutoffTime }
        }
    }

    private func parseHeartRate(from data: Data) -> Int {
        var heartRate: UInt16 = 0
        let flags = data[0]

        // Check if heart rate is in UINT16 format (bit 0 of flags)
        if (flags & 0x01) == 0 {
            // Heart rate is UINT8
            heartRate = UInt16(data[1])
        } else {
            // Heart rate is UINT16
            heartRate = UInt16(data[1]) | (UInt16(data[2]) << 8)
        }

        return Int(heartRate)
    }
}
