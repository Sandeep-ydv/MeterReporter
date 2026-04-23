import Foundation
#if canImport(MetricKit)
import MetricKit
#endif
// [AI GENERATED CODE] Import for logging
@preconcurrency import os.log

class DiagnosticSubscriber: NSObject {
    var onReceive: (([Data]) -> Void)?
    // [AI GENERATED CODE] Callback for metric payloads (memory, CPU, disk metrics)
    var onMetricReceive: (([Data]) -> Void)?
    // [AI GENERATED CODE] Logger for debugging payload delivery
    private let log = OSLog(subsystem: "com.chimehq.MeterReporter", category: "DiagnosticSubscriber")

    override init() {
        super.init()
    }

    static var metricKitAvailable: Bool {
        #if (os(iOS) || os(macOS)) && compiler(>=5.5.1)
        if #available(iOS 14.0, macOS 12.0, *) {
            return true
        }
        #endif

        return false
    }

    func start() {
        #if (os(iOS) || os(macOS)) && compiler(>=5.5.1)
        if #available(iOS 14.0, macOS 12.0, *) {
            MXMetricManager.shared.add(self)
        }
        #endif
    }
}

#if (os(iOS) || os(macOS)) && compiler(>=5.5.1)
@available(iOS 14.0, macOS 12.0, *)
extension DiagnosticSubscriber: MXMetricManagerSubscriber {
    // [AI GENERATED CODE]
    /// Handles diagnostic payloads from MetricKit (crashes, hangs, CPU exceptions, disk writes)
    /// Sends raw MetricKit JSON without enrichment to preserve original structure
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard payloads.isEmpty == false else { return }

        // [AI GENERATED CODE] Log diagnostic counts for debugging
        for (index, payload) in payloads.enumerated() {
            let crashCount = payload.crashDiagnostics?.count ?? 0
            let hangCount = payload.hangDiagnostics?.count ?? 0
            let cpuCount = payload.cpuExceptionDiagnostics?.count ?? 0
            let diskCount = payload.diskWriteExceptionDiagnostics?.count ?? 0

            os_log("DiagnosticPayload #%d: crashes=%d, hangs=%d, cpu=%d, disk=%d",
                   log: log, type: .info,
                   index, crashCount, hangCount, cpuCount, diskCount)
        }

        onReceive?(payloads.map({ $0.jsonRepresentation() }))
    }

    // [AI GENERATED CODE]
    /// Handles metric payloads from MetricKit (memory, CPU usage, disk metrics, network metrics)
    /// Sends raw MetricKit JSON without enrichment to preserve original structure
    func didReceive(_ payloads: [MXMetricPayload]) {
        guard payloads.isEmpty == false else { return }

        // [AI GENERATED CODE] Log metric payload info for debugging
        for (index, payload) in payloads.enumerated() {
            let hasMemory = payload.memoryMetrics != nil
            let hasCPU = payload.cpuMetrics != nil
            let hasDisk = payload.diskIOMetrics != nil
            let hasNetwork = payload.networkTransferMetrics != nil

            os_log("MetricPayload #%d: memory=%d, cpu=%d, disk=%d, network=%d",
                   log: log, type: .info,
                   index, hasMemory, hasCPU, hasDisk, hasNetwork)
        }

        onMetricReceive?(payloads.map({ $0.jsonRepresentation() }))
    }
}
#endif
