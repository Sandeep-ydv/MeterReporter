import Foundation

/// Protocol abstracting report submission functionality
/// This allows conditional compilation of Wells (iOS 14+) vs no-op (iOS 13)
protocol ReportSubmitter: Actor {
    /// Base URL for report storage directory
    var baseURL: URL { get }

    /// Creates the report directory if it doesn't exist
    func createReportDirectoryIfNeeded() async throws

    /// Submits a report file to the backend
    /// - Parameters:
    ///   - fileURL: Local file URL containing report data
    ///   - identifier: Unique identifier for this report
    ///   - uploadRequest: URLRequest configured for upload
    func submit(fileURL: URL, identifier: String, uploadRequest: URLRequest) async

    /// Sets a custom location provider for mapping report IDs to file URLs
    /// - Parameter provider: Closure that maps identifier to file URL
    func setLocationProvider(_ provider: @escaping @Sendable (String) -> URL?) async

    /// Sets handler for existing log files found during initialization
    /// - Parameter handler: Closure called for each existing log file with URL and creation date
    func setExistingLogHandler(_ handler: @escaping @Sendable (URL, Date) -> Void) async

    /// Default background session identifier
    static var defaultBackgroundIdentifier: String { get }

    /// Default directory for storing reports
    static var defaultDirectory: URL { get }
}
