import Foundation
import Darwin

final class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()

    @Published var cpuUsage: Double = 0
    @Published var memUsage: Double = 0

    private var timer: Timer?
    private var prevCpu: host_cpu_load_info_data_t?
    private let hwMemBytes: UInt64 = {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return size
    }()

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        let cpu = readCPU()
        let mem = readMem()
        DispatchQueue.main.async {
            self.cpuUsage = cpu
            self.memUsage = mem
        }
    }

    private func readCPU() -> Double {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return cpuUsage }
        defer { prevCpu = info }
        guard let prev = prevCpu else { return 0 }

        let user   = Double(info.cpu_ticks.0 &- prev.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1 &- prev.cpu_ticks.1)
        let idle   = Double(info.cpu_ticks.2 &- prev.cpu_ticks.2)
        let nice   = Double(info.cpu_ticks.3 &- prev.cpu_ticks.3)
        let busy = user + system + nice
        let total = busy + idle
        return total > 0 ? max(0, min(1, busy / total)) : 0
    }

    private func readMem() -> Double {
        guard hwMemBytes > 0 else { return 0 }
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return memUsage }
        let pageSize = UInt64(vm_kernel_page_size)
        let active     = UInt64(info.active_count)          * pageSize
        let wired      = UInt64(info.wire_count)            * pageSize
        let compressed = UInt64(info.compressor_page_count) * pageSize
        let used = active + wired + compressed
        return max(0, min(1, Double(used) / Double(hwMemBytes)))
    }
}
