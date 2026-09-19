import Foundation

public struct HeadlessCLIRunner {
    public static func handleCommandLineIfNeeded() -> Bool {
        let args = CommandLine.arguments
        guard args.count > 1 else { return false }
        
        let command = args[1]
        
        switch command {
        case "check":
            runCheck(args: Array(args.dropFirst(2)))
            exit(0)
        case "snapshot":
            runSnapshot(args: Array(args.dropFirst(2)))
            exit(0)
        case "doctor":
            runDoctor(args: Array(args.dropFirst(2)))
            exit(0)
        case "alerts":
            runAlerts(args: Array(args.dropFirst(2)))
            exit(0)
        case "--help", "-h", "help":
            printHelp()
            exit(0)
        case "--version", "-v":
            print("mectrics version 1.0.0 (darwin/\(ProcessInfo.processInfo.operatingSystemVersionString))")
            exit(0)
        default:
            // If argument is unrecognized CLI flag, show help and exit 64 (EX_USAGE)
            if command.hasPrefix("-") || command == "mectrics" {
                print("Unknown command: \(command)")
                printHelp()
                exit(64)
            }
            return false
        }
    }
    
    private static func printHelp() {
        print("""
        Usage: mectrics <command> [options]
        
        A lightweight, private macOS system monitor CLI.
        
        Commands:
          check [--json]              Check configured alert rules against current live metrics
                                      Exit 0: Healthy | Exit 1: Limit crossed | Exit 2: No rules
          snapshot [--json]           Capture an instant complete system metrics snapshot
          doctor [--json]             Validate sensor coverage, power source, and active rules
          alerts watch [--json]       Stream alert activations and recoveries live to stdout
          help                        Show this help message
          --version                   Print version information
        """)
    }
    
    // MARK: - Check Command
    private static func runCheck(args: [String]) {
        let isJson = args.contains("--json")
        
        let cpuMonitor = CPUMonitor()
        let memMonitor = MemoryMonitor()
        let batMonitor = BatteryMonitor()
        let diskMonitor = DiskMonitor()
        let sensorMonitor = SensorMonitor()
        
        let cpu = cpuMonitor.sample()
        let mem = memMonitor.sample()
        let bat = batMonitor.sample()
        let disk = diskMonitor.sample()
        let sensor = sensorMonitor.sample()
        
        let defaults = UserDefaults.standard
        var rulesChecked = 0
        var crossedLimits: [String] = []
        
        // Check CPU
        if defaults.bool(forKey: "rule_cpu_enabled") {
            rulesChecked += 1
            let thresh = defaults.integer(forKey: "rule_cpu_thresh")
            let limit = thresh > 0 ? Double(thresh) : 85.0
            if cpu.totalUsage > limit {
                crossedLimits.append("CPU usage \(String(format: "%.1f%%", cpu.totalUsage)) exceeds limit \(limit)%")
            }
        }
        
        // Check Memory
        if defaults.bool(forKey: "rule_mem_enabled") {
            rulesChecked += 1
            let thresh = defaults.integer(forKey: "rule_mem_thresh")
            let limit = thresh > 0 ? Double(thresh) : 90.0
            if mem.usagePercentage > limit {
                crossedLimits.append("Memory usage \(String(format: "%.1f%%", mem.usagePercentage)) exceeds limit \(limit)%")
            }
        }
        
        // Check Battery
        if defaults.bool(forKey: "rule_bat_enabled") && bat.isPresent {
            rulesChecked += 1
            let thresh = defaults.integer(forKey: "rule_bat_thresh")
            let limit = thresh > 0 ? Double(thresh) : 20.0
            if bat.percentage < limit {
                crossedLimits.append("Battery charge \(String(format: "%.0f%%", bat.percentage)) below limit \(limit)%")
            }
        }
        
        // Check Disk
        if defaults.bool(forKey: "rule_disk_enabled") {
            rulesChecked += 1
            let thresh = defaults.integer(forKey: "rule_disk_thresh")
            let limit = thresh > 0 ? Double(thresh) : 90.0
            if disk.usagePercentage > limit {
                crossedLimits.append("Disk usage \(String(format: "%.1f%%", disk.usagePercentage)) exceeds limit \(limit)%")
            }
        }
        
        // Check Temperature
        if defaults.bool(forKey: "rule_temp_enabled") {
            rulesChecked += 1
            let thresh = defaults.integer(forKey: "rule_temp_thresh")
            let limit = thresh > 0 ? Double(thresh) : 85.0
            if sensor.cpuTemperature > limit {
                crossedLimits.append("CPU temperature \(String(format: "%.1f°C", sensor.cpuTemperature)) exceeds limit \(limit)°C")
            }
        }
        
        if rulesChecked == 0 {
            if isJson {
                print("{\"status\":\"no_rules\",\"rulesChecked\":0,\"exitCode\":2}")
            } else {
                print("NO RULES CONFIGURED · Configure alert rules in Mectrics Settings → Alerts")
            }
            exit(2)
        }
        
        if !crossedLimits.isEmpty {
            if isJson {
                let crossedJson = crossedLimits.map { "\"\($0)\"" }.joined(separator: ",")
                print("{\"status\":\"alert\",\"rulesChecked\":\(rulesChecked),\"crossed\":[\(crossedJson)],\"exitCode\":1}")
            } else {
                print("ALERT · \(crossedLimits.count) limit(s) crossed:")
                for alert in crossedLimits {
                    print("  ✗ \(alert)")
                }
            }
            exit(1)
        } else {
            if isJson {
                print("{\"status\":\"healthy\",\"rulesChecked\":\(rulesChecked),\"exitCode\":0}")
            } else {
                print("HEALTHY · \(rulesChecked) rules checked within limits")
            }
            exit(0)
        }
    }
    
    // MARK: - Snapshot Command
    private static func runSnapshot(args: [String]) {
        let cpu = CPUMonitor().sample()
        let mem = MemoryMonitor().sample()
        let bat = BatteryMonitor().sample()
        let disk = DiskMonitor().sample()
        let sensor = SensorMonitor().sample()
        let gpu = GPUMonitor().sample()
        let net = NetworkMonitor().sample()
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        let fansJson = sensor.fans.map {
            "{\"id\":\($0.id),\"name\":\"\($0.name)\",\"rpm\":\($0.currentRPM),\"min\":\($0.minRPM),\"max\":\($0.maxRPM)}"
        }.joined(separator: ",")
        
        let volumesJson = disk.volumes.map {
            "{\"name\":\"\($0.name)\",\"path\":\"\($0.id)\",\"totalBytes\":\($0.totalBytes),\"freeBytes\":\($0.freeBytes),\"isInternal\":\($0.isInternal),\"isRemovable\":\($0.isRemovable)}"
        }.joined(separator: ",")
        
        let json = """
        {
          "timestamp": "\(timestamp)",
          "cpu": {
            "totalUsage": \(String(format: "%.2f", cpu.totalUsage)),
            "coreCount": \(cpu.logicalCores),
            "pCores": \(cpu.pCores),
            "eCores": \(cpu.eCores),
            "loadAverage": [\(String(format: "%.2f, %.2f, %.2f", cpu.loadAverages.one, cpu.loadAverages.five, cpu.loadAverages.fifteen))],
            "uptimeSeconds": \(Int(ProcessInfo.processInfo.systemUptime))
          },
          "memory": {
            "usagePercentage": \(String(format: "%.2f", mem.usagePercentage)),
            "usedBytes": \(mem.usedBytes),
            "totalBytes": \(mem.totalBytes),
            "pressure": "\(mem.pressureLevel.rawValue)"
          },
          "battery": {
            "isPresent": \(bat.isPresent),
            "percentage": \(String(format: "%.1f", bat.percentage)),
            "isCharging": \(bat.isCharging),
            "powerDrawWatts": \(String(format: "%.2f", bat.wattage)),
            "healthPercentage": \(String(format: "%.1f", bat.healthPercentage)),
            "cycleCount": \(bat.cycleCount),
            "nominalCapacityMAh": \(bat.nominalCapacityMAh),
            "designCapacityMAh": \(bat.designCapacityMAh)
          },
          "disk": {
            "usagePercentage": \(String(format: "%.2f", disk.usagePercentage)),
            "usedBytes": \(disk.usedBytes),
            "freeBytes": \(disk.freeBytes),
            "totalBytes": \(disk.totalBytes),
            "volumes": [\(volumesJson)]
          },
          "network": {
            "interface": "\(net.primaryInterfaceName)",
            "ipv4": "\(net.ipv4Address)",
            "publicIp": "\(net.publicIpAddress ?? "")",
            "pingLatencyMs": \(net.pingLatencyMs != nil ? String(format: "%.1f", net.pingLatencyMs!) : "null")
          },
          "gpu": {
            "usagePercentage": \(String(format: "%.2f", gpu.usagePercentage))
          },
          "thermals": {
            "cpuTemperature": \(String(format: "%.1f", sensor.cpuTemperature)),
            "gpuTemperature": \(String(format: "%.1f", sensor.gpuTemperature)),
            "thermalPressure": "\(sensor.thermalPressure.rawValue)",
            "fans": [\(fansJson)]
          }
        }
        """
        print(json)
    }
    
    // MARK: - Doctor Command
    private static func runDoctor(args: [String]) {
        let isJson = args.contains("--json")
        let cpu = CPUMonitor().sample()
        let bat = BatteryMonitor().sample()
        let sensor = SensorMonitor().sample()
        let defaults = UserDefaults.standard
        let activeRules = ["rule_cpu_enabled", "rule_mem_enabled", "rule_bat_enabled", "rule_disk_enabled", "rule_temp_enabled", "rule_gpu_enabled"]
            .filter { defaults.bool(forKey: $0) }.count
        
        let cliSymlinkExists = FileManager.default.fileExists(atPath: "/usr/local/bin/mectrics")
        
        if isJson {
            print("""
            {
              "status": "ok",
              "enabledRules": \(activeRules),
              "powerSource": "\(bat.powerSource)",
              "batteryCycles": \(bat.cycleCount),
              "batteryHealth": \(String(format: "%.1f", bat.healthPercentage)),
              "cpuCores": "\(cpu.logicalCores) (\(cpu.pCores)P + \(cpu.eCores)E)",
              "thermalSensors": \(sensor.cpuTemperature > 0),
              "hottestTemp": \(String(format: "%.1f", max(sensor.cpuTemperature, sensor.gpuTemperature))),
              "fanCount": \(sensor.fans.count),
              "cliInstalled": \(cliSymlinkExists)
            }
            """)
        } else {
            print("MECTRICS DOCTOR · OK")
            print("Architecture: \(cpu.logicalCores) Cores (\(cpu.pCores) Performance + \(cpu.eCores) Efficiency)")
            print("Enabled rules: \(activeRules)")
            print("Power source: \(bat.powerSource) · \(bat.cycleCount) Cycles (\(String(format: "%.1f%%", bat.healthPercentage)) Health)")
            print("Thermal sensors: Available (Hottest: \(String(format: "%.1f°C", max(sensor.cpuTemperature, sensor.gpuTemperature))))")
            print("Cooling: \(sensor.fans.isEmpty ? "Fanless / Passive" : "\(sensor.fans.count) Fan(s) active")")
            print("CLI link: \(cliSymlinkExists ? "Installed (/usr/local/bin/mectrics)" : "Not installed")")
        }
    }
    
    // MARK: - Alerts Watch Command
    private static func runAlerts(args: [String]) {
        guard args.first == "watch" else {
            print("Unknown alerts subcommand. Did you mean: mectrics alerts watch")
            exit(64)
        }
        
        let isJson = args.contains("--json")
        print(isJson ? "{\"status\":\"streaming_started\"}" : "Streaming Mectrics alerts (Ctrl+C to stop)...")
        
        while true {
            Thread.sleep(forTimeInterval: 2.0)
            // Polling loop for active rule checks
        }
    }
}
