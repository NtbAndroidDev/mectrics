import SwiftUI
import AppKit

public struct NetworkPopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var isFlushingDNS = false
    @State private var flushedDNSSuccess = false
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            PopoverHeaderView(
                icon: "arrow.up.arrow.down",
                title: loc("Network"),
                rightText: formatRate(monitor.network.downloadBytesPerSec + monitor.network.uploadBytesPerSec)
            )
            
            // Dual Sparklines
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(MectricsTheme.coral)
                            Text(loc("Download (Inbound)"))
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(MectricsTheme.textSecondary)
                        }
                        Spacer()
                        HStack(spacing: 5) {
                            if monitor.network.downloadBytesPerSec > 1024 {
                                Circle()
                                    .fill(MectricsTheme.coral)
                                    .frame(width: 5, height: 5)
                            }
                            Text(formatRate(monitor.network.downloadBytesPerSec))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(MectricsTheme.coral)
                        }
                    }
                    SparklineView(
                        values: monitor.networkDownHistory.values,
                        strokeColor: MectricsTheme.coral,
                        lineWidth: 1.5,
                        showFill: true,
                        minScale: 0.0,
                        maxScale: nil
                    )
                    .frame(height: 32)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(MectricsTheme.coralMuted)
                            Text(loc("Upload (Outbound)"))
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(MectricsTheme.textSecondary)
                        }
                        Spacer()
                        HStack(spacing: 5) {
                            if monitor.network.uploadBytesPerSec > 1024 {
                                Circle()
                                    .fill(MectricsTheme.coralMuted)
                                    .frame(width: 5, height: 5)
                            }
                            Text(formatRate(monitor.network.uploadBytesPerSec))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(MectricsTheme.coralMuted)
                        }
                    }
                    SparklineView(
                        values: monitor.networkUpHistory.values,
                        strokeColor: MectricsTheme.coralMuted,
                        lineWidth: 1.5,
                        showFill: true,
                        minScale: 0.0,
                        maxScale: nil
                    )
                    .frame(height: 32)
                }
            }
            
            // Key-Value List
            VStack(spacing: 2) {
                PopoverKeyValueRow(
                    label: loc("Interface"),
                    value: "\(monitor.network.primaryInterfaceName) (\(loc("Active")))",
                    icon: interfaceIcon
                )
                PopoverKeyValueRow(
                    label: loc("IP Address"),
                    value: monitor.network.ipv4Address,
                    icon: "network"
                )
                if let gateway = monitor.network.gatewayIpAddress, !gateway.isEmpty {
                    PopoverKeyValueRow(
                        label: loc("Gateway IP"),
                        value: gateway,
                        icon: "point.filled.topleft.down.curvedto.point.bottomright.up"
                    )
                }
                if let publicIP = monitor.network.publicIpAddress, !publicIP.isEmpty {
                    PopoverKeyValueRow(
                        label: loc("Public IP"),
                        value: publicIP,
                        icon: "globe.americas.fill"
                    )
                }
                if let rssi = monitor.network.wifiRssi {
                    let signalText = rssi >= -55 ? "Excellent (\(rssi) dBm)" : (rssi >= -70 ? "Good (\(rssi) dBm)" : "Weak (\(rssi) dBm)")
                    PopoverKeyValueRow(
                        label: loc("Wi-Fi Signal"),
                        value: signalText,
                        icon: "wifi"
                    )
                }
                if let rate = monitor.network.wifiTxRate, rate > 0 {
                    PopoverKeyValueRow(
                        label: loc("Link Speed"),
                        value: "\(Int(rate)) Mbps",
                        icon: "speedometer"
                    )
                }
                PopoverKeyValueRow(
                    label: loc("Total Downloaded"),
                    value: formatBytes(monitor.network.totalDownloadedBytes),
                    icon: "arrow.down"
                )
                PopoverKeyValueRow(
                    label: loc("Total Uploaded"),
                    value: formatBytes(monitor.network.totalUploadedBytes),
                    icon: "arrow.up"
                )
                if let ping = monitor.network.pingLatencyMs {
                    PopoverKeyValueRow(
                        label: loc("Ping Latency"),
                        value: String(format: "%.0f ms", ping),
                        icon: "waveform.path.ecg",
                        isHighlighted: ping > 120.0
                    )
                }
            }
            .padding(.vertical, 2)
            
            // Action Buttons
            VStack(spacing: 8) {
                PopoverActionButton(
                    icon: isFlushingDNS ? "arrow.triangle.2.circlepath" : "bolt.shield",
                    title: isFlushingDNS ? loc("Flushing DNS...") : (flushedDNSSuccess ? loc("DNS Cache Flushed!") : loc("Flush DNS Cache"))
                ) {
                    guard !isFlushingDNS else { return }
                    isFlushingDNS = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        let p1 = Process()
                        p1.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
                        p1.arguments = ["-flushcache"]
                        try? p1.run()
                        p1.waitUntilExit()
                        
                        let p2 = Process()
                        p2.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                        p2.arguments = ["-HUP", "mDNSResponder"]
                        try? p2.run()
                        p2.waitUntilExit()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isFlushingDNS = false
                            flushedDNSSuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                flushedDNSSuccess = false
                            }
                        }
                    }
                }
                
                PopoverActionButton(icon: "network", title: loc("Open Network Settings")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    } else if let url = URL(string: "x-apple.systempreferences:") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            
            // Footer
            PopoverFooterView()
        }
        .mectricsPopoverStyle()
    }
    
    private var interfaceIcon: String {
        let name = monitor.network.primaryInterfaceName.lowercased()
        if name.contains("en0") || name.contains("wl") || name.contains("wifi") {
            return "wifi"
        } else if name.contains("bridge") || name.contains("en") {
            return "cable.connector"
        } else if name.contains("utun") || name.contains("ppp") {
            return "lock.shield"
        }
        return "network"
    }
    
    private func formatRate(_ bytesPerSec: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSec)))/s"
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
