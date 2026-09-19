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
    
    @State private var isPulsing = false
    
    private var isVi: Bool {
        LocalizationManager.shared.currentLanguage == .vietnamese
    }
    
    public init(monitor: SystemMonitor, type: HoverDetailType) {
        self.monitor = monitor
        self.type = type
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            headerView
            
            Divider()
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.04), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            contentBody
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            
            Divider()
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            footerView
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 316)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.13, blue: 0.15).opacity(0.92),
                            Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.96)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            MectricsTheme.coral.opacity(0.35),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.65), radius: 20, x: 0, y: 10)
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
    
    // MARK: - Header
    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        LinearGradient(
                            colors: [headerAccentColor.opacity(0.25), headerAccentColor.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(headerAccentColor.opacity(0.35), lineWidth: 0.8)
                    )
                Image(systemName: headerIcon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(headerAccentColor)
            }
            
            VStack(alignment: .leading, spacing: 1.5) {
                Text(headerTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(headerSubtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(MectricsTheme.textTertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Live Status Pill with Breathing Glow
            HStack(spacing: 4.5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 5.5, height: 5.5)
                    .scaleEffect(isPulsing ? 1.2 : 0.85)
                    .opacity(isPulsing ? 1.0 : 0.6)
                Text(statusText)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(statusColor)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(statusColor.opacity(0.3), lineWidth: 0.8)
            )
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
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .lastTextBaseline) {
                Text(String(format: "%.0f%%", monitor.cpu.totalUsage))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(isVi ? "tổng tải CPU" : "total CPU load")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MectricsTheme.textSecondary)
                
                Spacer()
                
                if monitor.sensor.cpuTemperature > 0 {
                    HStack(spacing: 3.5) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 10, weight: .semibold))
                        Text(monitor.formatTemperature(monitor.sensor.cpuTemperature))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(MectricsTheme.coral)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(MectricsTheme.coral.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            // Dynamic Gradient Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [MectricsTheme.coral, Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, min(geo.size.width, geo.size.width * CGFloat(monitor.cpu.totalUsage / 100.0))))
                }
            }
            .frame(height: 5)
            
            // User / System / Idle Split Chips
            HStack(spacing: 8) {
                metricMiniChip(label: isVi ? "User" : "User", value: String(format: "%.0f%%", monitor.cpu.userUsage), accent: MectricsTheme.coral)
                metricMiniChip(label: isVi ? "System" : "Sys", value: String(format: "%.0f%%", monitor.cpu.systemUsage), accent: Color.orange)
                metricMiniChip(label: isVi ? "Idle" : "Idle", value: String(format: "%.0f%%", monitor.cpu.idleUsage), accent: Color.gray)
                if monitor.cpu.logicalCores > 0 {
                    metricMiniChip(label: isVi ? "Nhân" : "Cores", value: "\(monitor.cpu.logicalCores)", accent: Color.cyan)
                }
            }
            
            // Sparkline Waveform
            if !monitor.cpuHistory.values.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    SparklineView(
                        values: monitor.cpuHistory.values,
                        strokeColor: MectricsTheme.coral,
                        lineWidth: 1.4,
                        showFill: true
                    )
                    .frame(height: 26)
                    .background(Color.white.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                    )
                }
            }
            
            // Top 2 CPU Processes
            let topCPU = ProcessMonitor.shared.topCPUProcesses()
            if !topCPU.isEmpty {
                VStack(alignment: .leading, spacing: 4.5) {
                    Text(isVi ? "TIẾN TRÌNH CHIẾM NHIỀU CPU" : "TOP CPU PROCESSES")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MectricsTheme.textTertiary)
                    
                    ForEach(topCPU.prefix(2)) { proc in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(MectricsTheme.coral.opacity(0.3))
                                .frame(width: 5, height: 5)
                            Text(proc.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.1f%%", proc.cpuPercentage))
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(MectricsTheme.coral)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(MectricsTheme.coral.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Memory Content
    private var memoryContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .lastTextBaseline) {
                let usedGB = Double(monitor.memory.usedBytes) / (1024 * 1024 * 1024)
                let totalGB = Double(monitor.memory.totalBytes) / (1024 * 1024 * 1024)
                Text(String(format: "%.1f GB", usedGB))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("/ \(Int(totalGB)) GB (\(String(format: "%.0f%%", monitor.memory.usagePercentage)))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MectricsTheme.textSecondary)
                
                Spacer()
                
                Text(monitor.memory.pressureLevel.rawValue.uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(pressureColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(pressureColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            // Stacked Multi-Segment Memory Composition Bar
            GeometryReader { geo in
                let total = max(1.0, Double(monitor.memory.totalBytes))
                let appW = geo.size.width * CGFloat(min(1.0, Double(monitor.memory.activeBytes) / total))
                let wiredW = geo.size.width * CGFloat(min(1.0, Double(monitor.memory.wiredBytes) / total))
                let compW = geo.size.width * CGFloat(min(1.0, Double(monitor.memory.compressedBytes) / total))
                
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(Color.orange.opacity(0.5)).frame(width: min(geo.size.width, appW + wiredW + compW))
                    Capsule().fill(Color.cyan.opacity(0.7)).frame(width: min(geo.size.width, appW + wiredW))
                    Capsule().fill(MectricsTheme.coral).frame(width: min(geo.size.width, appW))
                }
            }
            .frame(height: 5)
            
            // Memory Tags with distinctive accents
            HStack(spacing: 8) {
                let appGB = Double(monitor.memory.activeBytes) / (1024 * 1024 * 1024)
                let wiredGB = Double(monitor.memory.wiredBytes) / (1024 * 1024 * 1024)
                let compGB = Double(monitor.memory.compressedBytes) / (1024 * 1024 * 1024)
                metricMiniChip(label: "App", value: String(format: "%.1fG", appGB), accent: MectricsTheme.coral)
                metricMiniChip(label: isVi ? "Cố định" : "Wired", value: String(format: "%.1fG", wiredGB), accent: Color.cyan)
                metricMiniChip(label: isVi ? "Nén" : "Comp", value: String(format: "%.1fG", compGB), accent: Color.orange)
                let swapMB = monitor.memory.swapUsedBytes / (1024 * 1024)
                metricMiniChip(label: "Swap", value: "\(swapMB)M", accent: swapMB > 500 ? Color.red : Color.gray)
            }
            
            // Top 2 RAM Processes
            let topMem = ProcessMonitor.shared.topMemoryProcesses()
            if !topMem.isEmpty {
                VStack(alignment: .leading, spacing: 4.5) {
                    Text(isVi ? "TIẾN TRÌNH CHIẾM NHIỀU RAM" : "TOP MEMORY PROCESSES")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MectricsTheme.textTertiary)
                    
                    ForEach(topMem.prefix(2)) { proc in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(Color.cyan.opacity(0.3))
                                .frame(width: 5, height: 5)
                            Text(proc.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.1f%%", proc.memoryPercentage))
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.cyan)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.cyan.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Disk Content
    private var diskContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .lastTextBaseline) {
                let freeGB = monitor.disk.freeBytes / (1024 * 1024 * 1024)
                let totalGB = monitor.disk.totalBytes / (1024 * 1024 * 1024)
                Text("\(freeGB) GB")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(isVi ? "còn trống / \(totalGB) GB" : "free of \(totalGB) GB")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MectricsTheme.textSecondary)
                
                Spacer()
                
                Text(String(format: "%.0f%%", monitor.disk.usagePercentage) + " " + (isVi ? "đã dùng" : "used"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.orange)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, MectricsTheme.coral],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, min(geo.size.width, geo.size.width * CGFloat(monitor.disk.usagePercentage / 100.0))))
                }
            }
            .frame(height: 5)
            
            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    ZStack {
                        Circle().fill(MectricsTheme.coral.opacity(0.15)).frame(width: 20, height: 20)
                        Image(systemName: "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(MectricsTheme.coral)
                    }
                    VStack(alignment: .leading, spacing: 0.5) {
                        Text(isVi ? "Tốc độ đọc" : "Read I/O")
                            .font(.system(size: 8.5))
                            .foregroundStyle(MectricsTheme.textTertiary)
                        Text(formatRate(monitor.disk.readBytesPerSec))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 5) {
                    ZStack {
                        Circle().fill(Color.cyan.opacity(0.15)).frame(width: 20, height: 20)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.cyan)
                    }
                    VStack(alignment: .leading, spacing: 0.5) {
                        Text(isVi ? "Tốc độ ghi" : "Write I/O")
                            .font(.system(size: 8.5))
                            .foregroundStyle(MectricsTheme.textTertiary)
                        Text(formatRate(monitor.disk.writeBytesPerSec))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Network Content
    private var networkContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                // Download Card
                HStack(spacing: 7) {
                    ZStack {
                        Circle().fill(MectricsTheme.coral.opacity(0.15)).frame(width: 24, height: 24)
                        Image(systemName: "arrow.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(MectricsTheme.coral)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isVi ? "Tải xuống" : "Download")
                            .font(.system(size: 9.5))
                            .foregroundStyle(MectricsTheme.textTertiary)
                        Text(formatRate(monitor.network.downloadBytesPerSec))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Upload Card
                HStack(spacing: 7) {
                    ZStack {
                        Circle().fill(Color.cyan.opacity(0.15)).frame(width: 24, height: 24)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.cyan)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isVi ? "Tải lên" : "Upload")
                            .font(.system(size: 9.5))
                            .foregroundStyle(MectricsTheme.textTertiary)
                        Text(formatRate(monitor.network.uploadBytesPerSec))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            HStack(spacing: 8) {
                metricMiniChip(label: isVi ? "Giao diện" : "Interface", value: monitor.network.primaryInterfaceName, accent: Color.cyan)
                metricMiniChip(label: "IPv4", value: monitor.network.ipv4Address, accent: Color.gray)
                if let ping = monitor.network.pingLatencyMs {
                    metricMiniChip(label: "Ping", value: String(format: "%.0fms", ping), accent: ping > 100 ? Color.orange : Color.green)
                }
            }
        }
    }
    
    // MARK: - Battery Content
    private var batteryContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .lastTextBaseline) {
                Text(String(format: "%.0f%%", monitor.battery.percentage))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(monitor.battery.isPluggedIn ? (isVi ? "Đang cắm sạc" : "Power Adapter Connected") : (isVi ? "Đang dùng Pin" : "Running on Battery"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MectricsTheme.textSecondary)
                
                Spacer()
                
                if monitor.battery.isCharging {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(isVi ? "ĐANG SẠC" : "CHARGING")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(Color.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            HStack(spacing: 8) {
                metricMiniChip(label: isVi ? "Độ chai" : "Health", value: String(format: "%.0f%%", monitor.battery.healthPercentage), accent: Color.green)
                metricMiniChip(label: isVi ? "Chu kỳ" : "Cycles", value: "\(monitor.battery.cycleCount)", accent: Color.cyan)
                metricMiniChip(label: isVi ? "Nguồn" : "Source", value: monitor.battery.powerSource, accent: Color.gray)
            }
        }
    }
    
    // MARK: - Sensor & Fans Content
    private var sensorContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isVi ? "Nhiệt độ CPU" : "CPU Temp")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(MectricsTheme.textTertiary)
                    Text(monitor.formatTemperature(monitor.sensor.cpuTemperature))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(MectricsTheme.coral)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if monitor.sensor.gpuTemperature > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isVi ? "Nhiệt độ GPU" : "GPU Temp")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(MectricsTheme.textTertiary)
                        Text(monitor.formatTemperature(monitor.sensor.gpuTemperature))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Color.orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if !monitor.sensor.fans.isEmpty {
                    let maxRPM = monitor.sensor.fans.map(\.currentRPM).max() ?? 0
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isVi ? "Quạt tản nhiệt" : "Fan Speed")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(MectricsTheme.textTertiary)
                        Text("\(maxRPM) RPM")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Color.cyan)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    // MARK: - GPU Content
    private var gpuContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .lastTextBaseline) {
                Text(String(format: "%.0f%%", monitor.gpu.usagePercentage))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(isVi ? "tải đồ họa Metal" : "Metal GPU load")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MectricsTheme.textSecondary)
            }
            
            Text(monitor.gpu.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MectricsTheme.textTertiary)
        }
    }
    
    // MARK: - Master Quick Overview Content ([M] Sample Mode)
    private var masterContent: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // CPU Mini Tile
                miniOverviewCard(
                    icon: "cpu",
                    title: "CPU",
                    val: String(format: "%.0f%%", monitor.cpu.totalUsage),
                    sub: monitor.cpu.modelName,
                    color: MectricsTheme.coral,
                    progress: monitor.cpu.totalUsage / 100.0
                )
                
                // RAM Mini Tile
                miniOverviewCard(
                    icon: "memorychip",
                    title: "RAM",
                    val: String(format: "%.0f%%", monitor.memory.usagePercentage),
                    sub: "\(Int(Double(monitor.memory.usedBytes) / (1024*1024*1024)))GB Used",
                    color: Color.cyan,
                    progress: monitor.memory.usagePercentage / 100.0
                )
            }
            
            HStack(spacing: 8) {
                // Disk Mini Tile
                let freeGB = monitor.disk.freeBytes / (1024 * 1024 * 1024)
                miniOverviewCard(
                    icon: "internaldrive",
                    title: isVi ? "Ổ đĩa" : "Disk",
                    val: "\(freeGB) GB",
                    sub: isVi ? "Còn trống" : "Free Space",
                    color: Color.orange,
                    progress: monitor.disk.usagePercentage / 100.0
                )
                
                // Net Mini Tile
                miniOverviewCard(
                    icon: "network",
                    title: isVi ? "Mạng" : "Net",
                    val: formatRate(monitor.network.downloadBytesPerSec),
                    sub: monitor.network.primaryInterfaceName,
                    color: Color.green,
                    progress: nil
                )
            }
        }
    }
    
    private func miniOverviewCard(
        icon: String,
        title: String,
        val: String,
        sub: String,
        color: Color,
        progress: Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MectricsTheme.textSecondary)
                Spacer()
                Text(val)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            
            if let p = progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(color).frame(width: max(2, min(geo.size.width, geo.size.width * CGFloat(p))))
                    }
                }
                .frame(height: 3)
            }
            
            Text(sub)
                .font(.system(size: 8.5, weight: .regular))
                .foregroundStyle(MectricsTheme.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
        )
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 9.5))
                .foregroundStyle(MectricsTheme.coral)
            Text(isVi ? "Nhấp chuột vào icon để mở Dashboard đầy đủ" : "Click icon for full dashboard")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(MectricsTheme.textTertiary)
            Spacer()
            
            HStack(spacing: 2) {
                Text("⌘")
                    .font(.system(size: 9, weight: .bold))
                Text(",")
                    .font(.system(size: 9, weight: .bold))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .foregroundStyle(MectricsTheme.textSecondary)
        }
    }
    
    // MARK: - Helpers
    private func metricMiniChip(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(accent.opacity(0.85))
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
        )
    }
    
    private func formatRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1024 * 1024 {
            return String(format: "%.1fM", bytesPerSec / (1024 * 1024))
        } else if bytesPerSec >= 1024 {
            return String(format: "%.0fK", bytesPerSec / 1024)
        } else {
            return "\(Int(bytesPerSec))B"
        }
    }
    
    private var headerAccentColor: Color {
        switch type {
        case .cpu: return MectricsTheme.coral
        case .memory: return Color.cyan
        case .disk: return Color.orange
        case .network: return Color.green
        case .battery: return Color.green
        case .sensor, .fans: return MectricsTheme.coral
        case .gpu: return Color.purple
        case .master: return MectricsTheme.coral
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
        case .cpu: return isVi ? "Bộ vi xử lý CPU" : "Processor (CPU)"
        case .memory: return isVi ? "Bộ nhớ RAM" : "Unified Memory"
        case .disk: return isVi ? "Ổ đĩa lưu trữ" : "Disk Storage"
        case .network: return isVi ? "Lưu lượng mạng" : "Network Traffic"
        case .battery: return isVi ? "Pin & Nguồn điện" : "Battery & Power"
        case .sensor, .fans: return isVi ? "Nhiệt độ & Quạt" : "Thermals & Cooling"
        case .gpu: return isVi ? "Đồ họa Metal GPU" : "Graphics (GPU)"
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
        case .sensor, .fans: return "Darwin Mach Sensors"
        case .gpu: return monitor.gpu.name
        case .master: return "Mectrics System Monitor"
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
    
    private var pressureColor: Color {
        switch monitor.memory.pressureLevel {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
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
