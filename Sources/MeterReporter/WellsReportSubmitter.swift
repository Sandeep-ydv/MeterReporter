import Foundation

#if canImport(Wells)
import Wells

/// Real implementation using Wells for iOS 14+
/// This is conditionally compiled only when Wells is available
@available(iOS 14.0, macOS 12.0, tvOS 14.0, watchOS 7.0, *)
actor WellsReportSubmitter: ReportSubmitter {
    private let wellsReporter: WellsReporter

    nonisolated var baseURL: URL {
        wellsReporter.baseURL
    }

    init(baseURL: URL, backgroundIdentifier: String?) {
        self.wellsReporter = WellsReporter(
            baseURL: baseURL,
            backgroundIdentifier: backgroundIdentifier
        )
    }

    func createReportDirectoryIfNeeded() async throws {
        try await wellsReporter.createReportDirectoryIfNeeded()
    }

    func submit(fileURL: URL, identifier: String, uploadRequest: URLRequest) async {
        await wellsReporter.submit(
            fileURL: fileURL,
            identifier: identifier,
            uploadRequest: uploadRequest
        )
    }

    func setLocationProvider(_ provider: @escaping @Sendable (String) -> URL?) async {
        await wellsReporter.setLocationProvider(provider)
    }

    func setExistingLogHandler(_ handler: @escaping @Sendable (URL, Date) -> Void) async {
        await wellsReporter.setExistingLogHandler(handler)
    }

    static var defaultBackgroundIdentifier: String {
        WellsReporter.defaultBackgroundIdentifier
    }

    static var defaultDirectory: URL {
        WellsReporter.defaultDirectory
    }
}
#endif
