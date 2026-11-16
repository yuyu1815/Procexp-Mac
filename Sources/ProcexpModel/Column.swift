//
//  Column.swift
//  ProcexpModel — W0 shared contracts
//
//  The user-selectable columns of the main process list, with pure
//  formatting and sort-key functions so any renderer stays consistent.
//

import Foundation

/// A sortable key derived from a column value. Comparable across a single column.
public enum SortKey: Comparable, Sendable {
    case number(Double)
    case text(String)
    case none

    public static func < (lhs: SortKey, rhs: SortKey) -> Bool {
        switch (lhs, rhs) {
        case let (.number(a), .number(b)): return a < b
        case let (.text(a), .text(b)):     return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        case (.none, _):                   return false
        case (_, .none):                   return true
        default:                           return false
        }
    }
}

public enum Column: String, CaseIterable, Sendable, Codable {
    case name, pid, ppid, cpu, cpuTime, privateBytes, workingSet, virtualSize,
         threads, handles, description, company, version, path, commandLine,
         user, session, startTime, priority, nice, ioRead, ioWrite,
         runningThreads, pageIns, cowFaults, machMessagesSent,
         machMessagesReceived, machSyscalls, unixSyscalls, threadUserTime,
         threadSystemTime, taskPolicy, bsdFlags,
         network, gpu, gpuMemory, integrity, signature, virusTotal, autostart

    public var title: String {
        switch self {
        case .name:         return String(localized: "Process", bundle: .module)
        case .pid:          return String(localized: "PID", bundle: .module)
        case .ppid:         return String(localized: "Parent PID", bundle: .module)
        case .cpu:          return String(localized: "CPU", bundle: .module)
        case .cpuTime:      return String(localized: "CPU Time", bundle: .module)
        case .privateBytes: return String(localized: "Physical Footprint", bundle: .module)
        case .workingSet:   return String(localized: "Resident Memory (RSS)", bundle: .module)
        case .virtualSize:  return String(localized: "Virtual Size", bundle: .module)
        case .threads:      return String(localized: "Threads", bundle: .module)
        case .handles:      return String(localized: "File Descriptors", bundle: .module)
        case .description:  return String(localized: "Description", bundle: .module)
        case .company:      return String(localized: "Organization (inferred)", bundle: .module)
        case .version:      return String(localized: "Version", bundle: .module)
        case .path:         return String(localized: "Path", bundle: .module)
        case .commandLine:  return String(localized: "Command Line", bundle: .module)
        case .user:         return String(localized: "User Name", bundle: .module)
        case .session:      return String(localized: "Terminal (TTY)", bundle: .module)
        case .startTime:    return String(localized: "Start Time", bundle: .module)
        case .priority:     return String(localized: "Task Priority", bundle: .module)
        case .nice:         return String(localized: "Nice Value", bundle: .module)
        case .ioRead:       return String(localized: "Bytes Read (cumulative)", bundle: .module)
        case .ioWrite:      return String(localized: "Bytes Written (cumulative)", bundle: .module)
        case .runningThreads: return String(localized: "Running Threads", bundle: .module)
        case .pageIns:      return String(localized: "Page Ins", bundle: .module)
        case .cowFaults:    return String(localized: "COW Faults", bundle: .module)
        case .machMessagesSent: return String(localized: "Mach Msg Sent", bundle: .module)
        case .machMessagesReceived: return String(localized: "Mach Msg Received", bundle: .module)
        case .machSyscalls: return String(localized: "Mach Syscalls", bundle: .module)
        case .unixSyscalls: return String(localized: "Unix Syscalls", bundle: .module)
        case .threadUserTime: return String(localized: "Thread User Time", bundle: .module)
        case .threadSystemTime: return String(localized: "Thread Kernel Time", bundle: .module)
        case .taskPolicy:   return String(localized: "Task Policy", bundle: .module)
        case .bsdFlags:     return String(localized: "BSD Flags", bundle: .module)
        case .network:      return String(localized: "Network", bundle: .module)
        case .gpu:          return String(localized: "GPU", bundle: .module)
        case .gpuMemory:    return String(localized: "GPU Memory", bundle: .module)
        case .integrity:    return String(localized: "Integrity", bundle: .module)
        case .signature:    return String(localized: "Verified Signer", bundle: .module)
        case .virusTotal:   return String(localized: "VirusTotal", bundle: .module)
        case .autostart:    return String(localized: "Autostart Location", bundle: .module)
        }
    }

    public var defaultWidth: CGFloat {
        switch self {
        case .name:         return 260
        case .pid:          return 58
        case .ppid:         return 78
        case .cpu:          return 54
        case .cpuTime:      return 88
        case .privateBytes: return 130
        case .workingSet:   return 155
        case .virtualSize:  return 96
        case .threads:      return 62
        case .handles:      return 120
        case .description:  return 220
        case .company:      return 180
        case .version:      return 118
        case .path, .commandLine: return 420
        case .user:         return 130
        case .session:      return 105
        case .startTime:    return 142
        case .priority:     return 100
        case .nice:         return 80
        case .ioRead, .ioWrite: return 180
        case .runningThreads: return 108
        case .pageIns, .cowFaults: return 90
        case .machMessagesSent, .machMessagesReceived: return 120
        case .machSyscalls, .unixSyscalls: return 110
        case .threadUserTime, .threadSystemTime: return 122
        case .taskPolicy:   return 82
        case .bsdFlags:     return 92
        case .network:      return 96
        case .gpu:          return 58
        case .gpuMemory:    return 96
        case .integrity:    return 92
        case .signature:    return 240
        case .virusTotal:   return 82
        case .autostart:    return 260
        }
    }

    public var isRightAligned: Bool {
        switch self {
        case .name, .description, .company, .version, .path, .commandLine,
             .user, .startTime, .signature, .autostart, .integrity:
            return false
        default:
            return true
        }
    }

    /// Meaning shown when hovering the column header; `nil` shows no tooltip.
    public var headerExplanation: String? {
        switch self {
        case .name:
            return String(localized: "Executable name. Child processes are nested under their parent.", bundle: .module)
        case .pid:
            return String(localized: "Process ID assigned by the kernel. A PID can be reused after the process exits.", bundle: .module)
        case .cpu:
            return String(localized: "Share of CPU time used since the previous refresh. 100% is one fully busy logical core, so a multithreaded process can exceed 100%.", bundle: .module)
        case .privateBytes:
            return String(localized: "Physical footprint: memory the system charges to this process. Not the same as resident memory. Blank when unavailable.", bundle: .module)
        case .workingSet:
            return String(localized: "Resident memory (RSS): physical pages currently resident for the process. Distinct from physical footprint.", bundle: .module)
        case .signature:
            return String(localized: "Who signed the executable, read from its code signature. Unsigned and invalid signatures are shown in parentheses.", bundle: .module)
        default:
            return nil
        }
    }

    /// Columns backed by supportable macOS data sources in this app. Unsupported
    /// Windows-only/private-API columns stay decodable for old settings but are
    /// removed from menus, saved layouts, and active column sets.
    public var isSupportedOnMac: Bool {
        switch self {
        case .network, .gpu, .gpuMemory, .integrity:
            return false
        default:
            return true
        }
    }

    public static var supportedOnMac: [Column] {
        allCases.filter(\.isSupportedOnMac)
    }

    public static let pinnedOnMac: [Column] = [.name, .pid]

    /// Formats the display string for this column for a given process.
    public func string(for p: ProcessRecord) -> String {
        switch self {
        case .name:         return p.name
        case .pid:          return String(p.id.pid)
        case .ppid:         return p.parent.map { String($0.pid) } ?? ""
        case .cpu:          return p.hasTaskInfo ? (p.cpuPercent < 0.01 ? "" : String(format: "%.2f", p.cpuPercent)) : "-"
        case .cpuTime:      return p.hasTaskInfo ? ByteFormat.duration(nanos: p.cpuTime) : "-"
        case .privateBytes: return p.hasTaskInfo ? p.physFootprint.map(ByteFormat.bytes) ?? "-" : "-"
        case .workingSet:   return p.hasTaskInfo ? ByteFormat.bytes(p.residentSize) : "-"
        case .virtualSize:  return p.hasTaskInfo ? ByteFormat.bytes(p.virtualSize) : "-"
        case .threads:      return p.hasTaskInfo ? String(p.threadCount) : "-"
        case .handles:      return p.fileDescriptorCount.map(String.init) ?? "-"
        case .description:  return p.displayDescription ?? ""
        case .company:      return p.companyName ?? ""
        case .version:      return p.version ?? ""
        case .path:         return p.executablePath ?? ""
        case .commandLine:  return p.commandLine ?? ""
        case .user:         return p.userName ?? String(p.uid)
        case .session:      return p.sessionTTY ?? ""
        case .startTime:    return ByteFormat.dateTime(p.startTimeDate)
        case .priority:     return p.hasTaskInfo ? String(p.priority) : "-"
        case .nice:         return String(p.nice)
        case .ioRead:       return p.diskBytesRead.map(ByteFormat.bytes) ?? "-"
        case .ioWrite:      return p.diskBytesWritten.map(ByteFormat.bytes) ?? "-"
        case .runningThreads: return p.hasTaskInfo ? p.runningThreadCount.map(String.init) ?? "-" : "-"
        case .pageIns:      return p.hasTaskInfo ? p.pageIns.map(String.init) ?? "-" : "-"
        case .cowFaults:    return p.hasTaskInfo ? p.copyOnWriteFaults.map(String.init) ?? "-" : "-"
        case .machMessagesSent: return p.hasTaskInfo ? p.machMessagesSent.map(String.init) ?? "-" : "-"
        case .machMessagesReceived: return p.hasTaskInfo ? p.machMessagesReceived.map(String.init) ?? "-" : "-"
        case .machSyscalls: return p.hasTaskInfo ? p.machSyscalls.map(String.init) ?? "-" : "-"
        case .unixSyscalls: return p.hasTaskInfo ? p.unixSyscalls.map(String.init) ?? "-" : "-"
        case .threadUserTime: return p.hasTaskInfo ? p.threadUserTime.map(ByteFormat.duration) ?? "-" : "-"
        case .threadSystemTime: return p.hasTaskInfo ? p.threadSystemTime.map(ByteFormat.duration) ?? "-" : "-"
        case .taskPolicy:   return p.hasTaskInfo ? p.taskPolicy.map(String.init) ?? "-" : "-"
        case .bsdFlags:     return p.bsdFlagsRaw.map { String(format: "0x%08X", $0) } ?? "-"
        case .network:      return p.networkBytesPerSec.map { ByteFormat.bytes($0) + "/s" } ?? ""
        case .gpu:          return p.gpuPercent.map { String(format: "%.1f", $0) } ?? ""
        case .gpuMemory:    return ""
        case .integrity:    return p.flags.contains(.sandboxed) ? String(localized: "Sandboxed", bundle: .module) : (p.flags.contains(.platformBinary) ? String(localized: "Platform", bundle: .module) : "")
        case .signature:    return p.signing?.signerDescription ?? ""
        case .virusTotal:
            guard let vt = p.signing?.virusTotal else { return "" }
            return "\(vt.positives)/\(vt.total)"
        case .autostart:    return p.autostartLocation ?? ""
        }
    }

    /// A comparable sort key for this column.
    public func sortValue(for p: ProcessRecord) -> SortKey {
        switch self {
        case .name:         return .text(p.name)
        case .pid:          return .number(Double(p.id.pid))
        case .ppid:         return .number(Double(p.parent?.pid ?? -1))
        case .cpu:          return p.hasTaskInfo ? .number(p.cpuPercent) : .none
        case .cpuTime:      return p.hasTaskInfo ? .number(Double(p.cpuTime)) : .none
        case .privateBytes: return p.hasTaskInfo ? p.physFootprint.map { .number(Double($0)) } ?? .none : .none
        case .workingSet:   return p.hasTaskInfo ? .number(Double(p.residentSize)) : .none
        case .virtualSize:  return p.hasTaskInfo ? .number(Double(p.virtualSize)) : .none
        case .threads:      return p.hasTaskInfo ? .number(Double(p.threadCount)) : .none
        case .handles:      return .number(Double(p.fileDescriptorCount ?? 0))
        case .description:  return .text(p.displayDescription ?? "")
        case .company:      return .text(p.companyName ?? "")
        case .version:      return .text(p.version ?? "")
        case .path:         return .text(p.executablePath ?? "")
        case .commandLine:  return .text(p.commandLine ?? "")
        case .user:         return .text(p.userName ?? String(p.uid))
        case .session:      return .text(p.sessionTTY ?? "")
        case .startTime:    return .number(p.startTimeDate.timeIntervalSince1970)
        case .priority:     return p.hasTaskInfo ? .number(Double(p.priority)) : .none
        case .nice:         return .number(Double(p.nice))
        case .ioRead:       return .number(Double(p.diskBytesRead ?? 0))
        case .ioWrite:      return .number(Double(p.diskBytesWritten ?? 0))
        case .runningThreads: return p.hasTaskInfo ? p.runningThreadCount.map { .number(Double($0)) } ?? .none : .none
        case .pageIns:      return p.hasTaskInfo ? p.pageIns.map { .number(Double($0)) } ?? .none : .none
        case .cowFaults:    return p.hasTaskInfo ? p.copyOnWriteFaults.map { .number(Double($0)) } ?? .none : .none
        case .machMessagesSent: return p.hasTaskInfo ? p.machMessagesSent.map { .number(Double($0)) } ?? .none : .none
        case .machMessagesReceived: return p.hasTaskInfo ? p.machMessagesReceived.map { .number(Double($0)) } ?? .none : .none
        case .machSyscalls: return p.hasTaskInfo ? p.machSyscalls.map { .number(Double($0)) } ?? .none : .none
        case .unixSyscalls: return p.hasTaskInfo ? p.unixSyscalls.map { .number(Double($0)) } ?? .none : .none
        case .threadUserTime: return p.hasTaskInfo ? p.threadUserTime.map { .number(Double($0)) } ?? .none : .none
        case .threadSystemTime: return p.hasTaskInfo ? p.threadSystemTime.map { .number(Double($0)) } ?? .none : .none
        case .taskPolicy:   return p.hasTaskInfo ? p.taskPolicy.map { .number(Double($0)) } ?? .none : .none
        case .bsdFlags:     return p.bsdFlagsRaw.map { .number(Double($0)) } ?? .none
        case .network:      return .number(Double(p.networkBytesPerSec ?? 0))
        case .gpu:          return .number(p.gpuPercent ?? 0)
        case .gpuMemory:    return .none
        case .integrity:    return .text(string(for: p))
        case .signature:    return .text(p.signing?.signerDescription ?? "")
        case .virusTotal:   return .number(Double(p.signing?.virusTotal?.positives ?? -1))
        case .autostart:    return .text(p.autostartLocation ?? "")
        }
    }

    /// First-launch column layout. `.description` and `.company` stay available from the column menu.
    public static let defaultColumns: [Column] = [
        .name, .pid, .cpu, .privateBytes, .workingSet, .signature
    ]
}

private extension ProcessRecord {
    var hasTaskInfo: Bool { !flags.contains(.limitedTaskInfo) }
}

/// Pure formatting helpers used by column rendering (no locale surprises for tests).
public enum ByteFormat {
    public static func bytes(_ value: UInt64) -> String {
        if value == 0 { return "" }
        let units = ["B", "K", "M", "G", "T", "P"]
        var v = Double(value)
        var i = 0
        while v >= 1024 && i < units.count - 1 {
            v /= 1024
            i += 1
        }
        if i == 0 { return "\(value) B" }
        return String(format: "%.1f %@", v, units[i])
    }

    public static func duration(nanos: UInt64) -> String {
        let totalSeconds = Double(nanos) / 1_000_000_000
        let h = Int(totalSeconds) / 3600
        let m = (Int(totalSeconds) % 3600) / 60
        let s = Int(totalSeconds) % 60
        let cs = Int((totalSeconds - Double(Int(totalSeconds))) * 100)
        return String(format: "%d:%02d:%02d.%02d", h, m, s, cs)
    }

    public static func dateTime(_ date: Date) -> String {
        if date == .distantPast { return "" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }
}
