import SwiftUI
import AppKit

public enum HoverDetailType: String, Equatable, Sendable {
    case master
    case cpu
    case memory
    case disk
    case network
    case battery
    case sensor
    case fans
    case gpu
}

public struct HoverDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    let type: HoverDetailType
    
    private var isVi: Bool {
        LocalizationManager.shared.currentLanguage == .vietnamese
    }
    
    public init(monitor: SystemMonitor, type: HoverDetailType) {
        self.monitor = monitor
        self.type = type
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerView
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            contentBody
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            footerView
        }
        .padding(14)
        .frame(width: 310)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [MectricsTheme.coral.opacity(0.5), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(MectricsTheme.coral.opacity(0.18))
                    .frame(width: 26, height: 26)
                Image(systemName: headerIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MectricsTheme.coral)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(headerTitle)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.white)
                Text(headerSubtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(MectricsTheme.textTertiary)
            }
            
            Spacer()
            
            // Live Status Indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(statusColor)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Body By Type
    @ViewBuilder
    private var contentBody: some View {
        switch type {
        case .cpu:
            cpuContent
        case .memory:
            memoryContent
        case .disk:
            diskContent
        case .network:
            networkContent
        case .battery:
            batteryContent
        case .sensor, .fans:
            sensorContent
        case .gpu:
            gpuContent
        case .master:
            masterContent
        }
    }
    
    // MARK: - CPU Content
    private var cpuContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                Text(String(format: "%.0f%%", monitor.cpu.totalUsage))
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(isVi ? "tổng tải" : "total load")
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textSecondary)
                
                Spacer()
                
                if monitor.sensor.cpuTemperature > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 10))
                        Text(monitor.formatTemperature(monitor.sensor.cpuTemperature))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(MectricsTheme.coral)
                }
            }
            
            // User / System / Idle Split
            HStack(spacing: 12) {
                metricMiniChip(label: isVi ? "Người dùng" : "User", value: String(format: "%.0f%%", monitor.cpu.userUsage))
                metricMiniChip(label: isVi ? "Hệ thống" : "System", value: String(format: "%.0f%%", monitor.cpu.systemUsage))
                metricMiniChip(label: isVi ? "Rảnh rỗi" : "Idle", value: String(format: "%.0f%%", monitor.cpu.idleUsage))
            }
            
            // Mini sparkline
            if !monitor.cpuHistory.values.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    SparklineView(
                        values: monitor.cpuHistory.values,
                        strokeColor: MectricsTheme.coral,
                        lineWidth: 1.2,
                        showFill: true
                    )
                    .frame(height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            
            // Top 2 CPU Processes
            let topCPU = ProcessMonitor.shared.topCPUProcesses()
            if !topCPU.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isVi ? "Tiến trình chiếm nhiều CPU:" : "Top CPU consumers:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(MectricsTheme.textTertiary)
                    
                    ForEach(topCPU.prefix(2)) { proc in
                        HStack(spacing: 6) {
                            Text(proc.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.1f%%", proc.cpuPercentage))
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(MectricsTheme.coral)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Memory Content
    private var memoryContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                let usedGB = Double(monitor.memory.usedBytes) / (1024 * 1024 * 1024)
                let totalGB = Double(monitor.memory.totalBytes) / (1024 * 1024 * 1024)
                Text(String(format: "%.1f GB", usedGB))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("/ \(Int(totalGB)) GB (\(String(format: "%.0f%%", monitor.memory.usagePercentage)))")
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textSecondary)
            }
            
            // Memory Gauge Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [MectricsTheme.coral, Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(monitor.memory.usagePercentage / 100.0))))
                }
            }
            .frame(height: 6)
            
            // Detailed Tags
            HStack(spacing: 8) {
                let appGB = Double(monitor.memory.activeBytes) / (1024 * 1024 * 1024)
                let wiredGB = Double(monitor.memory.wiredBytes) / (1024 * 1024 * 1024)
                let compGB = Double(monitor.memory.compressedBytes) / (1024 * 1024 * 1024)
                metricMiniChip(label: isVi ? "App" : "App", value: String(format: "%.1fG", appGB))
                metricMiniChip(label: isVi ? "Cố định" : "Wired", value: String(format: "%.1fG", wiredGB))
                metricMiniChip(label: isVi ? "Nén" : "Comp", value: String(format: "%.1fG", compGB))
            }
            
            // Top 2 RAM Processes
            let topMem = ProcessMonitor.shared.topMemoryProcesses()
            if !topMem.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isVi ? "Tiến trình chiếm nhiều RAM:" : "Top RAM consumers:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(MectricsTheme.textTertiary)
                    
                    ForEach(topMem.prefix(2)) { proc in
                        HStack(spacing: 6) {
                            Text(proc.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.1f%%", proc.memoryPercentage))
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.cyan)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Disk Content
    private var diskContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                let freeGB = monitor.disk.freeBytes / (1024 * 1024 * 1024)
                let totalGB = monitor.disk.totalBytes / (1024 * 1024 * 1024)
                Text("\(freeGB) GB")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(isVi ? "trống / \(totalGB) GB" : "free of \(totalGB) GB")
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textSecondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(MectricsTheme.coral)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(monitor.disk.usagePercentage / 100.0))))
                }
            }
            .frame(height: 6)
            
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(MectricsTheme.coral)
                    Text(isVi ? "Đọc:" : "Read:")
                        .font(.system(size: 10.5))
                        .foregroundStyle(MectricsTheme.textTertiary)
                    Text(formatRate(monitor.disk.readBytesPerSec))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.cyan)
                    Text(isVi ? "Ghi:" : "Write:")
                        .font(.system(size: 10.5))
                        .foregroundStyle(MectricsTheme.textTertiary)
                    Text(formatRate(monitor.disk.writeBytesPerSec))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    // MARK: - Network Content
    private var networkContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(MectricsTheme.coral)
                            .font(.system(size: 11))
                        Text(isVi ? "Tải xuống" : "Download")
                            .font(.system(size: 10))
                            .foregroundStyle(MectricsTheme.textSecondary)
                    }
                    Text(formatRate(monitor.network.downloadBytesPerSec))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(Color.cyan)
                            .font(.system(size: 11))
                        Text(isVi ? "Tải lên" : "Upload")
                            .font(.system(size: 10))
                            .foregroundStyle(MectricsTheme.textSecondary)
                    }
                    Text(formatRate(monitor.network.uploadBytesPerSec))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            
            HStack(spacing: 8) {
                metricMiniChip(label: isVi ? "Cổng mạng" : "Interface", value: monitor.network.primaryInterfaceName)
                metricMiniChip(label: "IPv4", value: monitor.network.ipv4Address)
                if let ping = monitor.network.pingLatencyMs {
                    metricMiniChip(label: "Ping", value: String(format: "%.0fms", ping))
                }
            }
        }
    }
    
    // MARK: - Battery Content
    private var batteryContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                Text(String(format: "%.0f%%", monitor.battery.percentage))
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(monitor.battery.isPluggedIn ? (isVi ? "Đang cắm sạc" : "Plugged In") : (isVi ? "Đang dùng Pin" : "On Battery"))
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textSecondary)
            }
            
            HStack(spacing: 8) {
                metricMiniChip(label: isVi ? "Tình trạng" : "Health", value: String(format: "%.0f%%", monitor.battery.healthPercentage))
                metricMiniChip(label: isVi ? "Chu kỳ sạc" : "Cycles", value: "\(monitor.battery.cycleCount)")
                metricMiniChip(label: isVi ? "Nguồn điện" : "Source", value: monitor.battery.powerSource)
            }
        }
    }
    
    // MARK: - Sensor & Fans Content
    private var sensorContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isVi ? "Nhiệt độ CPU" : "CPU Temp")
                        .font(.system(size: 10))
                        .foregroundStyle(MectricsTheme.textSecondary)
                    Text(monitor.formatTemperature(monitor.sensor.cpuTemperature))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(MectricsTheme.coral)
                }
                
                if monitor.sensor.gpuTemperature > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isVi ? "Nhiệt độ GPU" : "GPU Temp")
                            .font(.system(size: 10))
                            .foregroundStyle(MectricsTheme.textSecondary)
                        Text(monitor.formatTemperature(monitor.sensor.gpuTemperature))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.orange)
                    }
                }
                
                if !monitor.sensor.fans.isEmpty {
                    let maxRPM = monitor.sensor.fans.map(\.currentRPM).max() ?? 0
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isVi ? "Quạt tản nhiệt" : "Fan Speed")
                            .font(.system(size: 10))
                            .foregroundStyle(MectricsTheme.textSecondary)
                        Text("\(maxRPM) RPM")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.cyan)
                    }
                }
            }
        }
    }
    
    // MARK: - GPU Content
    private var gpuContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                Text(String(format: "%.0f%%", monitor.gpu.usagePercentage))
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(isVi ? "tải đồ họa" : "GPU load")
                    .font(.system(size: 11))
                    .foregroundStyle(MectricsTheme.textSecondary)
            }
            
            Text(monitor.gpu.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MectricsTheme.textTertiary)
        }
    }
    
    // MARK: - Master Quick Overview Content ([M] Sample)
    private var masterContent: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // CPU Mini Card
                miniOverviewCard(
                    icon: "cpu",
                    title: "CPU",
                    val: String(format: "%.0f%%", monitor.cpu.totalUsage),
                    color: MectricsTheme.coral
                )
                
                // RAM Mini Card
                miniOverviewCard(
                    icon: "memorychip",
                    title: "RAM",
                    val: String(format: "%.0f%%", monitor.memory.usagePercentage),
                    color: Color.cyan
                )
            }
            
            HStack(spacing: 8) {
                // Disk Mini Card
                let freeGB = monitor.disk.freeBytes / (1024 * 1024 * 1024)
                miniOverviewCard(
                    icon: "internaldrive",
                    title: isVi ? "Ổ đĩa" : "Disk",
                    val: "\(freeGB)GB",
                    color: Color.orange
                )
                
                // Net Mini Card
                miniOverviewCard(
                    icon: "network",
                    title: isVi ? "Mạng" : "Net",
                    val: formatRate(monitor.network.downloadBytesPerSec),
                    color: Color.green
                )
            }
        }
    }
    
    private func miniOverviewCard(icon: String, title: String, val: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(MectricsTheme.textTertiary)
                Text(val)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 9))
                .foregroundStyle(MectricsTheme.coral)
            Text(isVi ? "Nhấp chuột để mở Bảng điều khiển đầy đủ" : "Click to open full dashboard")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(MectricsTheme.textTertiary)
            Spacer()
        }
    }
    
    // MARK: - Helpers
    private func metricMiniChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8.5, weight: .regular))
                .foregroundStyle(MectricsTheme.textTertiary)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private func formatRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSec / (1024 * 1024))
        } else if bytesPerSec >= 1024 {
            return String(format: "%.0f KB/s", bytesPerSec / 1024)
        } else {
            return "\(Int(bytesPerSec)) B/s"
        }
    }
    
    private var headerIcon: String {
        switch type {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .battery: return "battery.100"
        case .sensor: return "thermometer.medium"
        case .fans: return "fan.fill"
        case .gpu: return "display"
        case .master: return "macbook.gen2"
        }
    }
    
    private var headerTitle: String {
        switch type {
        case .cpu: return isVi ? "Bộ vi xử lý (CPU)" : "Processor (CPU)"
        case .memory: return isVi ? "Bộ nhớ hợp nhất (RAM)" : "Unified Memory (RAM)"
        case .disk: return isVi ? "Dung lượng Ổ đĩa" : "Storage Drive"
        case .network: return isVi ? "Lưu lượng Mạng" : "Network Activity"
        case .battery: return isVi ? "Pin & Nguồn điện" : "Battery & Power"
        case .sensor, .fans: return isVi ? "Nhiệt độ & Quạt" : "Thermals & Fans"
        case .gpu: return isVi ? "Đồ họa (GPU)" : "Graphics (GPU)"
        case .master: return isVi ? "Tổng quan Mectrics" : "Mectrics Overview"
        }
    }
    
    private var headerSubtitle: String {
        switch type {
        case .cpu: return monitor.cpu.modelName
        case .memory: return "\(Int(Double(monitor.memory.totalBytes) / (1024*1024*1024)))GB LPDDR5"
        case .disk: return monitor.disk.volumeName
        case .network: return monitor.network.primaryInterfaceName
        case .battery: return monitor.battery.powerSource
        case .sensor, .fans: return "Apple Silicon Sensors"
        case .gpu: return monitor.gpu.name
        case .master: return "Mectrics v1.2"
        }
    }
    
    private var statusColor: Color {
        switch type {
        case .cpu:
            return monitor.cpu.totalUsage > 85 ? .red : (monitor.cpu.totalUsage > 60 ? .orange : .green)
        case .memory:
            return monitor.memory.usagePercentage > 85 ? .red : (monitor.memory.usagePercentage > 70 ? .orange : .green)
        default:
            return .green
        }
    }
    
    private var statusText: String {
        switch type {
        case .cpu:
            return monitor.cpu.totalUsage > 85 ? "HIGH" : (monitor.cpu.totalUsage > 60 ? "BUSY" : "NORMAL")
        case .memory:
            return monitor.memory.usagePercentage > 85 ? "HIGH" : (monitor.memory.usagePercentage > 70 ? "BUSY" : "NORMAL")
        default:
            return "NORMAL"
        }
    }
}
