import SwiftUI
import Foundation
import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    let bleService: WhoopBLEService
    private var updateTimer: Timer?

    override init() {
        bleService = WhoopBLEService()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "♥ --"
            button.action = #selector(togglePopover)
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 350, height: 270)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: HeartRateGraphView(bleService: bleService))

        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMenuBar()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
        updateTimer = nil
        bleService.disconnect()
    }

    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    func updateMenuBar() {
        guard let button = statusItem?.button else { return }

        if let hr = bleService.currentHeartRate {
            button.title = "♥ \(hr)"
        } else if bleService.isConnected {
            button.title = "♥ --"
        } else {
            button.title = "♥ ···"
        }
    }
}

struct HeartRateGraphView: View {
    @ObservedObject var bleService: WhoopBLEService
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                if let hr = bleService.currentHeartRate {
                    Text("\(hr)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                    Text("BPM")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("--")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(.horizontal)

            if bleService.isConnected && !bleService.heartRateHistory.isEmpty {
                HeartRateChart(readings: bleService.heartRateHistory)
                    .frame(height: 150)
                    .padding(.horizontal, 8)
            } else if bleService.isConnected {
                VStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Collecting data...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
            } else {
                VStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(bleService.statusMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 150)
            }

            Divider()

            HStack {
                Toggle("Start at Login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue
                        }
                    }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.caption)
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 12)
        .frame(width: 350, height: 270)
    }
}

struct HeartRateChart: View {
    let readings: [HeartRateReading]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                VStack(spacing: 0) {
                    ForEach(0..<5) { _ in
                        Divider()
                        Spacer()
                    }
                }

                // Line chart
                if readings.count > 1 {
                    Path { path in
                        let points = calculatePoints(in: geometry.size)
                        guard !points.isEmpty else { return }

                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.red, lineWidth: 2)

                    // Fill area under line
                    Path { path in
                        let points = calculatePoints(in: geometry.size)
                        guard !points.isEmpty else { return }

                        path.move(to: CGPoint(x: points[0].x, y: geometry.size.height))
                        path.addLine(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: points.last!.x, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.red.opacity(0.3), Color.red.opacity(0.05)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                // Y-axis labels
                VStack {
                    if let maxHR = readings.map({ $0.heartRate }).max(),
                       let minHR = readings.map({ $0.heartRate }).min() {
                        HStack {
                            Text("\(maxHR)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            Text("\(minHR)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private func calculatePoints(in size: CGSize) -> [CGPoint] {
        guard !readings.isEmpty else { return [] }

        let sortedReadings = readings.sorted { $0.timestamp < $1.timestamp }
        let heartRates = sortedReadings.map { $0.heartRate }

        guard let minHR = heartRates.min(),
              let maxHR = heartRates.max(),
              maxHR > minHR else {
            return sortedReadings.enumerated().map { index, _ in
                CGPoint(x: CGFloat(index) / CGFloat(sortedReadings.count - 1) * size.width, y: size.height / 2)
            }
        }

        let hrRange = CGFloat(maxHR - minHR)
        let padding: CGFloat = 40

        return sortedReadings.enumerated().map { index, reading in
            let x = CGFloat(index) / CGFloat(sortedReadings.count - 1) * (size.width - padding) + (padding / 2)
            let normalizedHR = (CGFloat(reading.heartRate - minHR) / hrRange)
            let y = size.height - (normalizedHR * (size.height - 20)) - 10

            return CGPoint(x: x, y: y)
        }
    }
}
