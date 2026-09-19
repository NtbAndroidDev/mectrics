import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case vietnamese = "vi"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .vietnamese: return "Tiếng Việt"
        }
    }
}

@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()
    
    @AppStorage("app_language") public var selectedLanguageCode: String = AppLanguage.english.rawValue {
        didSet {
            objectWillChange.send()
            SystemMonitor.shared.objectWillChange.send()
        }
    }
    
    public var currentLanguage: AppLanguage {
        get { AppLanguage(rawValue: selectedLanguageCode) ?? .english }
        set { selectedLanguageCode = newValue.rawValue }
    }
    
    private init() {}
    
    public func t(_ key: String) -> String {
        let isVi = (currentLanguage == .vietnamese)
        
        switch key {
        // Headers & Items
        case "CPU": return isVi ? "Bộ vi xử lý CPU" : "CPU"
        case "Memory": return isVi ? "Bộ nhớ RAM" : "Memory"
        case "Disk": return isVi ? "Ổ đĩa lưu trữ" : "Disk"
        case "Network": return isVi ? "Mạng kết nối" : "Network"
        case "Battery": return isVi ? "Pin & Nguồn" : "Battery"
        case "Sensors": return isVi ? "Cảm biến nhiệt" : "Sensors"
        case "GPU": return isVi ? "Đồ hoạ GPU" : "GPU"
        case "All systems normal": return isVi ? "Hệ thống hoạt động tốt" : "All systems normal"
        case "Active Alerts": return isVi ? "Cảnh báo đang hoạt động" : "Active Alerts"
        case "Mectrics will show selected alert conditions here.":
            return isVi ? "Mectrics sẽ hiển thị các điều kiện cảnh báo tại đây." : "Mectrics will show selected alert conditions here."
            
        // CPU
        case "Cores": return isVi ? "Số nhân" : "Cores"
        case "Busiest core": return isVi ? "Nhân bận nhất" : "Busiest core"
        case "Core Activity": return isVi ? "Hoạt động từng nhân" : "Core Activity"
        case "Performance Cores (P)": return isVi ? "Nhân hiệu năng cao (P-Cores)" : "Performance Cores (P)"
        case "Efficiency Cores (E)": return isVi ? "Nhân tiết kiệm điện (E-Cores)" : "Efficiency Cores (E)"
        case "P-Cores": return isVi ? "Nhân P" : "P-Cores"
        case "E-Cores": return isVi ? "Nhân E" : "E-Cores"
        case "Temperature": return isVi ? "Nhiệt độ" : "Temperature"
        case "Uptime": return isVi ? "Thời gian chạy" : "Uptime"
        case "Top processes": return isVi ? "Tiến trình chiếm nhiều CPU" : "Top processes"
        case "Open Activity Monitor": return isVi ? "Mở Giám sát Hoạt động" : "Open Activity Monitor"
        case "Open Activity Monitor (Memory)": return isVi ? "Mở Giám sát Bộ nhớ" : "Open Activity Monitor (Memory)"
        case "Open Activity Monitor (Energy)": return isVi ? "Mở Giám sát Năng lượng" : "Open Activity Monitor (Energy)"
        
        // Disk
        case "Used": return isVi ? "Đã dùng" : "Used"
        case "Free": return isVi ? "Còn trống" : "Free"
        case "Purgeable": return isVi ? "Có thể giải phóng" : "Purgeable"
        case "Total": return isVi ? "Tổng cộng" : "Total"
        case "Trash": return isVi ? "Thùng rác" : "Trash"
        case "Empty Trash": return isVi ? "Dọn sạch Thùng rác" : "Empty Trash"
        case "Emptying Trash...": return isVi ? "Đang dọn Thùng rác..." : "Emptying Trash..."
        case "Read": return isVi ? "Tốc độ đọc" : "Read"
        case "Write": return isVi ? "Tốc độ ghi" : "Write"
        case "Read (Disk I/O)": return isVi ? "Tốc độ đọc ổ đĩa" : "Read (Disk I/O)"
        case "Write (Disk I/O)": return isVi ? "Tốc độ ghi ổ đĩa" : "Write (Disk I/O)"
        case "Volume": return isVi ? "Phân vùng" : "Volume"
        case "Mounted Volumes": return isVi ? "Các ổ đĩa & phân vùng" : "Mounted Volumes"
        case "Internal": return isVi ? "Ổ trong" : "Internal"
        case "External / Removable": return isVi ? "Ổ gắn ngoài" : "External / Removable"
        case "Eject": return isVi ? "Ngắt ổ đĩa" : "Eject"
        case "Open Disk Utility": return isVi ? "Mở Tiện ích Ổ đĩa" : "Open Disk Utility"
        case "Open Storage Settings": return isVi ? "Mở Cài đặt Dung lượng" : "Open Storage Settings"
        
        // Memory
        case "App Memory": return isVi ? "Bộ nhớ ứng dụng" : "App Memory"
        case "Wired Memory": return isVi ? "Bộ nhớ cố định" : "Wired Memory"
        case "Compressed": return isVi ? "Bộ nhớ đã nén" : "Compressed"
        case "Cached Files": return isVi ? "Bộ đệm tệp" : "Cached Files"
        case "Total RAM": return isVi ? "Tổng dung lượng RAM" : "Total RAM"
        case "Swap Used": return isVi ? "Hoán đổi Swap" : "Swap Used"
        case "Memory Trend": return isVi ? "Xu hướng bộ nhớ (30s)" : "Memory Trend (30s)"
        case "Memory Pressure": return isVi ? "Áp lực bộ nhớ" : "Memory Pressure"
        case "Top memory consumers": return isVi ? "Tiến trình chiếm nhiều RAM" : "Top memory consumers"
        case "Stopped": return isVi ? "Đã dừng" : "Stopped"
        case "App": return isVi ? "Ứng dụng" : "App"
        case "Wired": return isVi ? "Cố định" : "Wired"
        case "Cached": return isVi ? "Bộ đệm" : "Cached"
        case "Active": return isVi ? "Đang kết nối" : "Connected"
        
        // Network
        case "Download (Inbound)": return isVi ? "Tải xuống (Inbound)" : "Download (Inbound)"
        case "Upload (Outbound)": return isVi ? "Tải lên (Outbound)" : "Upload (Outbound)"
        case "Interface": return isVi ? "Giao diện mạng" : "Interface"
        case "IP Address": return isVi ? "Địa chỉ IP" : "IP Address"
        case "Public IP": return isVi ? "IP Công cộng" : "Public IP"
        case "Gateway IP": return isVi ? "Địa chỉ Cổng (Gateway)" : "Gateway IP"
        case "Wi-Fi Signal": return isVi ? "Tín hiệu Wi-Fi" : "Wi-Fi Signal"
        case "Link Speed": return isVi ? "Tốc độ kết nối" : "Link Speed"
        case "Total Downloaded": return isVi ? "Tổng tải xuống" : "Total Downloaded"
        case "Total Uploaded": return isVi ? "Tổng tải lên" : "Total Uploaded"
        case "Ping Latency": return isVi ? "Độ trễ mạng (Ping)" : "Ping Latency"
        case "Flush DNS Cache": return isVi ? "Xoá bộ đệm DNS" : "Flush DNS Cache"
        case "Flushing DNS...": return isVi ? "Đang xoá DNS..." : "Flushing DNS..."
        case "DNS Cache Flushed!": return isVi ? "Đã xoá bộ đệm DNS!" : "DNS Cache Flushed!"
        case "Open Network Settings": return isVi ? "Mở Cài đặt Mạng" : "Open Network Settings"
        
        // Battery
        case "Power Source": return isVi ? "Nguồn điện" : "Power Source"
        case "Power Draw": return isVi ? "Công suất tiêu thụ" : "Power Draw"
        case "Low Power Mode": return isVi ? "Chế độ Nguồn điện thấp" : "Low Power Mode"
        case "Enabled": return isVi ? "Bật" : "Enabled"
        case "Disabled": return isVi ? "Tắt" : "Disabled"
        case "State": return isVi ? "Trạng thái" : "State"
        case "Charging": return isVi ? "Đang sạc" : "Charging"
        case "Plugged In": return isVi ? "Đã cắm sạc" : "Plugged In"
        case "Discharging": return isVi ? "Đang dùng pin" : "Discharging"
        case "Time Remaining": return isVi ? "Thời lượng còn lại" : "Time Remaining"
        case "Time to Full": return isVi ? "Thời gian sạc đầy" : "Time to Full"
        case "Health Capacity": return isVi ? "Dung lượng tối đa" : "Health Capacity"
        case "Cycle Count": return isVi ? "Số chu kỳ sạc" : "Cycle Count"
        case "Design Capacity": return isVi ? "Dung lượng thiết kế" : "Design Capacity"
        case "Full Charge Capacity": return isVi ? "Dung lượng sạc đầy" : "Full Charge Capacity"
        case "Remaining Capacity": return isVi ? "Dung lượng hiện có" : "Remaining Capacity"
        case "Charger Power": return isVi ? "Công suất củ sạc" : "Charger Power"
        case "Condition": return isVi ? "Tình trạng pin" : "Condition"
        case "Open Battery Settings": return isVi ? "Mở Cài đặt Pin" : "Open Battery Settings"
        
        // Sensors & GPU
        case "CPU Temperature": return isVi ? "Nhiệt độ CPU" : "CPU Temperature"
        case "GPU Temperature": return isVi ? "Nhiệt độ GPU" : "GPU Temperature"
        case "Thermal Pressure": return isVi ? "Áp lực nhiệt" : "Thermal Pressure"
        case "Nominal": return isVi ? "Bình thường (Mát mẻ)" : "Nominal"
        case "Fair": return isVi ? "Vừa phải" : "Fair"
        case "Serious": return isVi ? "Nghiêm trọng (Nóng)" : "Serious"
        case "Critical": return isVi ? "Nguy cấp (Quá nhiệt)" : "Critical"
        case "Cooling Fan": return isVi ? "Quạt làm mát" : "Cooling Fan"
        case "Cooling Architecture": return isVi ? "Kiến trúc làm mát" : "Cooling Architecture"
        case "Fanless / Passive": return isVi ? "Tản nhiệt thụ động (Không quạt)" : "Fanless / Passive"
        case "Processor": return isVi ? "Bộ xử lý" : "Processor"
        case "Working Set VRAM": return isVi ? "VRAM đang dùng" : "Working Set VRAM"
        case "Total Metal VRAM": return isVi ? "Tổng VRAM Metal" : "Total Metal VRAM"
        case "VRAM Allocation": return isVi ? "Phân bổ VRAM" : "VRAM Allocation"
        case "Open Displays Settings": return isVi ? "Mở Cài đặt Màn hình" : "Open Displays Settings"
        
        // Compact Health Actions
        case "Keep Awake: Active": return isVi ? "Chống ngủ: Đang bật" : "Keep Awake: Active"
        case "Keep Awake: Off": return isVi ? "Chống ngủ máy: Đang tắt" : "Keep Awake: Off"
        case "Open Attention Log": return isVi ? "Mở Nhật ký Cảnh báo" : "Open Attention Log"
        case "Attention Log": return isVi ? "Nhật ký Cảnh báo" : "Attention Log"
        case "Done": return isVi ? "Xong" : "Done"
        case "No active alerts or events": return isVi ? "Không có cảnh báo hoặc sự kiện nào" : "No active alerts or events"
        case "Copy System Summary": return isVi ? "Sao chép Tóm tắt Hệ thống" : "Copy System Summary"
        case "Summary Copied!": return isVi ? "Đã sao chép Tóm tắt!" : "Summary Copied!"
        case "Purge Memory Cache": return isVi ? "Giải phóng Bộ nhớ đệm" : "Purge Memory Cache"
        case "Purging...": return isVi ? "Đang giải phóng..." : "Purging..."
        case "Purged!": return isVi ? "Đã giải phóng!" : "Purged!"
        case "Copied!": return isVi ? "Đã sao chép!" : "Copied!"
        case "Click to copy": return isVi ? "Nhấn để sao chép" : "Click to copy"
        case "Attention Log...": return isVi ? "Nhật ký Cảnh báo..." : "Attention Log..."
        case "Mectrics Settings...": return isVi ? "Cài đặt Mectrics..." : "Mectrics Settings..."
        case "Quit Mectrics": return isVi ? "Thoát Mectrics" : "Quit Mectrics"
        
        // Footer
        case "Settings": return isVi ? "Cài đặt" : "Settings"
        case "Quit": return isVi ? "Thoát" : "Quit"
        
        // Settings Window
        case "General": return isVi ? "Chung" : "General"
        case "Menu Bar": return isVi ? "Thanh Menu" : "Menu Bar"
        case "Alerts": return isVi ? "Cảnh báo" : "Alerts"
        case "Appearance": return isVi ? "Giao diện & Màu sắc" : "Appearance"
        case "Accent Color": return isVi ? "Màu sắc chủ đạo" : "Accent Color"
        case "Language": return isVi ? "Ngôn ngữ hiển thị" : "Language"
        case "Startup": return isVi ? "Khởi động" : "Startup"
        case "Launch Mectrics automatically at login":
            return isVi ? "Mở Mectrics tự động khi đăng nhập máy" : "Launch Mectrics automatically at login"
        case "Performance & Polling": return isVi ? "Hiệu năng & Tần suất cập nhật" : "Performance & Polling"
        case "Hardware Refresh Rate:": return isVi ? "Tần suất làm mới phần cứng:" : "Hardware Refresh Rate:"
        case "Zero Network Requests Guarantee": return isVi ? "Cam kết Không gửi Dữ liệu Mạng" : "Zero Network Requests Guarantee"
        case "Offline Guarantee Note":
            return isVi ? "Mectrics hoạt động hoàn toàn offline qua các API kernel Darwin Mach, sysctl và IOKit. Tuyệt đối không gửi telemetry, crash report hay mở bất kỳ kết nối mạng nào."
                        : "Mectrics operates 100% offline using Darwin Mach kernel, sysctl, and IOKit APIs. No telemetry, crash reporting, or network sockets are ever opened."
            
        // Menu Bar Settings
        case "Live Status Bar Preview": return isVi ? "Xem trước Thanh Menu Trực tiếp" : "Live Status Bar Preview"
        case "macOS Menu Bar": return isVi ? "Thanh Menu macOS" : "macOS Menu Bar"
        case "Display Mode": return isVi ? "Chế độ Hiển thị" : "Display Mode"
        case "Compact Health Mode (Single Shield Slot)":
            return isVi ? "Chế độ Khiên gọn gàng (Một icon duy nhất)" : "Compact Health Mode (Single Shield Slot)"
        case "Compact Health Note":
            return isVi ? "Gộp tất cả thông số phần cứng vào một biểu tượng khiên trên thanh menu để giữ không gian làm việc tối giản."
                        : "Gathers all hardware metrics into a single shield icon in the status bar to keep your workspace minimal."
        case "Menu Bar Optimization": return isVi ? "Tối ưu hoá Thanh Menu" : "Menu Bar Optimization"
        case "Dual Stacked CPU & RAM (35px Slot)": return isVi ? "Gộp CPU & RAM Xếp Chồng (Khe 35px)" : "Dual Stacked CPU & RAM (35px Slot)"
        case "Dual Stacked Note":
            return isVi ? "Kết hợp thông số CPU và RAM vào một biểu tượng micro ~35px xếp tầng dọc. Nhấn vào sẽ mở Bảng điều khiển Tổng hợp (Master Dashboard) với toàn bộ hệ thống."
                        : "Combines CPU and RAM metrics into a single micro ~35px stacked vertical slot. Clicking opens the unified Master Dashboard with all system metrics."
        case "Item Width & Style": return isVi ? "Độ rộng & Kiểu hiển thị" : "Item Width & Style"
        case "Wide": return isVi ? "Đầy đủ (Wide)" : "Wide"
        case "Medium": return isVi ? "Vừa phải (Medium)" : "Medium"
        case "Tiny": return isVi ? "Siêu nhỏ (Tiny)" : "Tiny"
        case "Display Style Note":
            return isVi ? "Chế độ Siêu nhỏ (Tiny) ẩn biểu tượng và đồ thị sóng để tiết kiệm tới 60% diện tích thanh Menu, lý tưởng cho MacBook có tai thỏ (notch)."
                        : "Tiny mode hides icons and sparklines to save up to 60% menu bar width, ideal for MacBooks with camera notches."
        case "Master Dashboard": return isVi ? "Bảng Điều Khiển Tổng Hợp" : "Master Dashboard"
        case "Awake": return isVi ? "Chống ngủ" : "Awake"
        case "Sleep OK": return isVi ? "Ngủ bình thường" : "Sleep OK"
        case "Flush DNS": return isVi ? "Xoá Cache DNS" : "Flush DNS"
        case "Flushing...": return isVi ? "Đang xoá..." : "Flushing..."
        case "Flushed!": return isVi ? "Đã xoá xong!" : "Flushed!"
        case "Activity Monitor": return isVi ? "Giám sát Hoạt động" : "Activity Monitor"
        case "Visible Status Bar Items": return isVi ? "Các mục hiển thị trên thanh Menu" : "Visible Status Bar Items"
        case "Restore Defaults": return isVi ? "Khôi phục Mặc định" : "Restore Defaults"
        case "Disk Storage": return isVi ? "Dung lượng Ổ đĩa" : "Disk Storage"
        case "Memory (RAM)": return isVi ? "Bộ nhớ (RAM)" : "Memory (RAM)"
        case "Show mini sparkline history box": return isVi ? "Hiển thị hộp biểu đồ mini" : "Show mini sparkline history box"
        case "Processor (CPU)": return isVi ? "Bộ vi xử lý (CPU)" : "Processor (CPU)"
        case "Show live waveform sparkline": return isVi ? "Hiển thị biểu đồ sóng trực tiếp" : "Show live waveform sparkline"
        case "Network Throughput": return isVi ? "Tốc độ mạng" : "Network Throughput"
        case "Battery & Power": return isVi ? "Pin & Nguồn điện" : "Battery & Power"
        case "Sensors & Thermals": return isVi ? "Cảm biến & Nhiệt độ" : "Sensors & Thermals"
        case "Graphics (GPU)": return isVi ? "Đồ hoạ (GPU)" : "Graphics (GPU)"
        case "Format:": return isVi ? "Định dạng:" : "Format:"
        
        // Alerts Tab
        case "Rules": return isVi ? "Quy tắc Cảnh báo" : "Rules"
        case "on": return isVi ? "đang bật" : "on"
        case "alerting": return isVi ? "đang báo động" : "alerting"
        case "CPU usage above": return isVi ? "Mức dùng CPU vượt quá" : "CPU usage above"
        case "Memory usage above": return isVi ? "Mức dùng RAM vượt quá" : "Memory usage above"
        case "Battery charge below": return isVi ? "Mức pin giảm dưới" : "Battery charge below"
        case "Disk usage above": return isVi ? "Mức dùng ổ đĩa vượt quá" : "Disk usage above"
        case "Free disk space below": return isVi ? "Dung lượng ổ đĩa trống dưới" : "Free disk space below"
        case "GPU usage above": return isVi ? "Mức dùng GPU vượt quá" : "GPU usage above"
        case "CPU temperature above": return isVi ? "Nhiệt độ CPU vượt quá" : "CPU temperature above"
        case "Normal": return isVi ? "Bình thường" : "Normal"
        case "Alert after 10 seconds": return isVi ? "Báo động sau 10 giây" : "Alert after 10 seconds"
        case "Alert after 30 seconds": return isVi ? "Báo động sau 30 giây" : "Alert after 30 seconds"
        case "Alert after 60 seconds": return isVi ? "Báo động sau 60 giây" : "Alert after 60 seconds"
        case "Alert description":
            return isVi ? "Khi kích hoạt, hệ thống sẽ phát thông báo, đổi màu biểu tượng khiên và lưu vào Nhật ký. Mỗi quy tắc sẽ nghỉ 15 phút sau khi phát báo động."
                        : "When a rule alerts it notifies you, marks the Compact Health item, and is recorded in the Attention Log. A rule rests for 15 minutes after it alerts."
        case "Notifications": return isVi ? "Thông báo" : "Notifications"
        case "Open Notification Settings": return isVi ? "Mở Cài đặt Thông báo" : "Open Notification Settings"
        case "Send a Test Notification": return isVi ? "Gửi Thông báo Thử nghiệm" : "Send a Test Notification"
        case "Notification Sent!": return isVi ? "Đã gửi Thông báo!" : "Notification Sent!"
        case "Notifications Note":
            return isVi ? "macOS quản lý quyền thông báo. Mectrics chỉ có thể hiển thị cảnh báo khi bạn cấp quyền trong Cài đặt Hệ thống."
                        : "macOS owns notification permission and decides how alerts are presented. Mectrics cannot show one until you allow it there."
            
        // Fans & Cooling
        case "Cooling Fans": return isVi ? "Quạt tản nhiệt" : "Cooling Fans"
        case "Idle / Passive": return isVi ? "Tĩnh lặng / Thụ động" : "Idle / Passive"
        case "Fanless Architecture": return isVi ? "Thiết kế Không quạt" : "Fanless Architecture"
        case "This Mac is passively cooled with zero mechanical noise.":
            return isVi ? "Chiếc Mac này được tản nhiệt thụ động hoàn toàn êm ái, không có tiếng ồn cơ học."
                        : "This Mac is passively cooled with zero mechanical noise."
        case "Thermal State": return isVi ? "Trạng thái nhiệt" : "Thermal State"
        case "CPU Thermal Zone": return isVi ? "Vùng nhiệt CPU" : "CPU Thermal Zone"
        case "GPU Thermal Zone": return isVi ? "Vùng nhiệt GPU" : "GPU Thermal Zone"
            
        // Diagnostics
        case "System Diagnostics": return isVi ? "Chẩn đoán Hệ thống" : "System Diagnostics"
        case "System Diagnostics...": return isVi ? "Chẩn đoán Hệ thống..." : "System Diagnostics..."
        case "Open System Diagnostics…": return isVi ? "Mở Chẩn đoán Hệ thống…" : "Open System Diagnostics…"
        case "Copy Diagnostics": return isVi ? "Sao chép Báo cáo" : "Copy Diagnostics"
        case "Export...": return isVi ? "Xuất tệp..." : "Export..."
        case "Hardware & Operating System": return isVi ? "Phần cứng & Hệ điều hành" : "Hardware & Operating System"
        case "Model Identifier": return isVi ? "Mã định danh máy" : "Model Identifier"
        case "macOS Version": return isVi ? "Phiên bản macOS" : "macOS Version"
        case "Kernel Version": return isVi ? "Phiên bản Kernel" : "Kernel Version"
        case "System Uptime": return isVi ? "Thời gian hoạt động" : "System Uptime"
        case "Privacy Status": return isVi ? "Tình trạng Quyền riêng tư" : "Privacy Status"
        case "100% Offline / Zero Telemetry": return isVi ? "100% Ngoại tuyến / Không gửi Telemetry" : "100% Offline / Zero Telemetry"
        case "Chip": return isVi ? "Bộ vi xử lý Chip" : "Chip"
        case "Cores Count": return isVi ? "Số lượng nhân" : "Cores Count"
        case "Current Total Usage": return isVi ? "Tổng mức sử dụng hiện tại" : "Current Total Usage"
        case "Load Average": return isVi ? "Tải trung bình (Load Avg)" : "Load Average"
        case "Physical Memory": return isVi ? "Bộ nhớ Vật lý" : "Physical Memory"
        case "RAM Utilization": return isVi ? "Hiệu suất sử dụng RAM" : "RAM Utilization"
        case "Battery Charge": return isVi ? "Mức sạc pin" : "Battery Charge"
        case "Maximum Capacity": return isVi ? "Dung lượng tối đa" : "Maximum Capacity"
        case "Storage Volume": return isVi ? "Phân vùng Lưu trữ" : "Storage Volume"
        case "Volume Path": return isVi ? "Đường dẫn phân vùng" : "Volume Path"
        case "Space Breakdown": return isVi ? "Phân bố dung lượng" : "Space Breakdown"
        case "Disk Utilization": return isVi ? "Tỷ lệ chiếm dụng ổ đĩa" : "Disk Utilization"
        case "Network Interfaces": return isVi ? "Giao diện Mạng" : "Network Interfaces"
        case "Current Download": return isVi ? "Tốc độ tải xuống" : "Current Download"
        case "Current Upload": return isVi ? "Tốc độ tải lên" : "Current Upload"
        case "DNS Ping Latency": return isVi ? "Độ trễ DNS Ping" : "DNS Ping Latency"
        case "Cooling Type": return isVi ? "Loại làm mát" : "Cooling Type"
        case "Passive Fanless Architecture": return isVi ? "Kiến trúc Tản nhiệt Thụ động" : "Passive Fanless Architecture"
            
        // Settings Extra
        case "Temperature Unit": return isVi ? "Đơn vị Nhiệt độ" : "Temperature Unit"
        case "Alert Behavior & Delivery": return isVi ? "Cách thức & Hành vi Cảnh báo" : "Alert Behavior & Delivery"
        case "Play audible alert sound when condition triggers":
            return isVi ? "Phát âm thanh chuông khi điều kiện cảnh báo xảy ra"
                        : "Play audible alert sound when condition triggers"
        case "Headless Automation CLI": return isVi ? "Bộ công cụ CLI Tự động hoá" : "Headless Automation CLI"
        case "Install CLI (/usr/local/bin/mectrics)": return isVi ? "Cài đặt CLI (/usr/local/bin/mectrics)" : "Install CLI (/usr/local/bin/mectrics)"
        case "Uninstall Mectrics": return isVi ? "Gỡ cài đặt Mectrics" : "Uninstall Mectrics"
        case "Uninstall Mectrics…": return isVi ? "Gỡ cài đặt Mectrics…" : "Uninstall Mectrics…"
            
        default:
            return key
        }
    }
}

extension View {
    @MainActor
    public func loc(_ key: String) -> String {
        LocalizationManager.shared.t(key)
    }
}
