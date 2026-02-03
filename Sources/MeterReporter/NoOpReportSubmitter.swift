import Foundation

/// No-op implementation for platforms where Wells is unavailable (iOS 13)
/// This is safe because MetricKit doesn't collect payloads on iOS 13 anyway
actor NoOpReportSubmitter: ReportSubmitter {
    let baseURL: URL

    init(baseURL: URL, backgroundIdentifier: String?) {
        self.baseURL = baseURL
    }

    func createReportDirectoryIfNeeded() async throws {
        // No-op: On iOS 13, no MetricKit payloads are collected anyway
    }

    func submit(fileURL: URL, identifier: String, uploadRequest: URLRequest) async {
        // No-op: Nothing to submit on iOS 13
    }

    func setLocationProvider(_ provider: @escaping @Sendable (String) -> URL?) async {
        // No-op: Not needed on iOS 13
    }

    func setExistingLogHandler(_ handler: @escaping @Sendable (URL, Date) -> Void) async {
        // No-op: Not needed on iOS 13
    }

    static var defaultBackgroundIdentifier: String {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.chimehq.MeterReporter"
        return bundleId + ".Uploader"
    }

    static var defaultDirectory: URL {
        let baseURL = FileManager.default.bundleIdSubdirectoryURL(for: .cachesDirectory)
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL.appendingPathComponent("com.chimehq.MeterReporter")
    }
}
