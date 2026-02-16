import Foundation
// Wells import removed - now using ReportSubmitter protocol abstraction
import Meter
@preconcurrency import os.log
#if os(macOS)
import AppKit
#endif

extension UUID {
    var lowerAlphaOnly: String {
        return uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
}

/// Collect and relay MetricKit payloads.
///
/// This class will accept MetricKit data and relay it to a remote endpoint, per its configuration.
///
/// - Important: You must hold a reference to an instance of this class to keep it active.
public actor MeterReporter {
    private let submitter: any ReportSubmitter
    public let configuration: Configuration
    private let subscriber: DiagnosticSubscriber
    private let log: OSLog
    private nonisolated let baseURL: URL

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.subscriber = DiagnosticSubscriber()
        self.log = OSLog(subsystem: "com.chimehq.MeterReporter", category: "MeterReporter")
        self.baseURL = configuration.reportsURL
        self.submitter = Self.createSubmitter(
            baseURL: configuration.reportsURL,
            backgroundIdentifier: configuration.backgroundIdentifier
        )

		let baseURL = configuration.reportsURL

		Task { [submitter] in
			await submitter.setLocationProvider {
				baseURL.appendingPathComponent($0).appendingPathExtension("mxdiagnostic")
			}

			await submitter.setExistingLogHandler {logUrl, date in
				Task { [weak self] in
					await self?.handleExistingLog(at: logUrl, date: date)
				}
			}
		}
    }

    public init(endpointURL: URL) {
        self.init(configuration: Configuration(endpointURL: endpointURL))
    }

    public func start() {
        os_log("starting", log: log, type: .debug)

		Task { [log, submitter] in
			do {
				try await submitter.createReportDirectoryIfNeeded()
			} catch {
				os_log("failed to create reporting directory %{public}@", log: log, type: .error, String(describing: error))
				return
			}

			await configureExceptionLogging()

			subscriber.onReceive = { payloads in
				Task { [weak self] in
					await self?.receivedPayloads(payloads)
				}
			}
			subscriber.start()
		}
    }

    private nonisolated var reportDirectoryURL: URL {
        return baseURL
    }
}

// MARK: - Submitter Factory
extension MeterReporter {
    /// Creates the appropriate ReportSubmitter implementation based on platform availability
    /// - Parameters:
    ///   - baseURL: Base directory for storing reports
    ///   - backgroundIdentifier: Optional identifier for background URLSession
    /// - Returns: WellsReportSubmitter on iOS 14+, NoOpReportSubmitter on iOS 13
    private static func createSubmitter(
        baseURL: URL,
        backgroundIdentifier: String?
    ) -> any ReportSubmitter {
        #if canImport(Wells)
        if #available(iOS 14.0, macOS 12.0, tvOS 14.0, watchOS 7.0, *) {
            return WellsReportSubmitter(
                baseURL: baseURL,
                backgroundIdentifier: backgroundIdentifier
            )
        }
        #endif

        return NoOpReportSubmitter(
            baseURL: baseURL,
            backgroundIdentifier: backgroundIdentifier
        )
    }
}

extension MeterReporter {
	public struct Configuration: Sendable {
        public var endpointURL: URL
        public var hostIdentifier: String?
        public var appName: String
        public var appShortCode: String

		/// The NSURLSession background indentifier
		///
		/// This has a default value, but can be customized if needed. Setting the value to `nil` will disable background uploading.
		public var backgroundIdentifier: String? = Self.computedDefaultBackgroundIdentifier
        public var reportsURL: URL = Self.computedDefaultDirectory
        public var log: OSLog = OSLog(subsystem: "com.chimehq.MeterReporter", category: "MeterReporter")
        public var filterSimulatedPayloads = true

        public init(endpointURL: URL, appName: String, appShortCode: String ) {
            self.endpointURL = endpointURL
            self.appName: appName
            self.appShortCode: appShortCode
        }

        // MARK: - Default Value Computation

        /// Default background identifier, using Wells on iOS 14+ or fallback on iOS 13
        private static var computedDefaultBackgroundIdentifier: String {
            #if canImport(Wells)
            if #available(iOS 14.0, macOS 12.0, tvOS 14.0, watchOS 7.0, *) {
                return WellsReportSubmitter.defaultBackgroundIdentifier
            }
            #endif
            return NoOpReportSubmitter.defaultBackgroundIdentifier
        }

        /// Default directory for reports, using Wells on iOS 14+ or fallback on iOS 13
        private static var computedDefaultDirectory: URL {
            #if canImport(Wells)
            if #available(iOS 14.0, macOS 12.0, tvOS 14.0, watchOS 7.0, *) {
                return WellsReportSubmitter.defaultDirectory
            }
            #endif
            return NoOpReportSubmitter.defaultDirectory
        }
    }
}

extension MeterReporter {
    func receivedPayloads(_ payloads: [Data]) {
        os_log("received payloads %{public}d", log: log, type: .info, payloads.count)

        let symbolicator = DlfcnSymbolicator()
        let exceptionInfo = existingExceptionInfo()

        removeExistingExceptionInfo()

        for rawData in payloads {
            let data: Data

            do {
                let payload = try DiagnosticPayload.from(data: rawData)

                if payload.isSimulated && configuration.filterSimulatedPayloads {
                    os_log("skipping simulated payload", log: log, type: .error)
                    continue
                }

                data = processPayload(payload, with: symbolicator, exceptionInfo: exceptionInfo)
            } catch {
                data = rawData
                os_log("failed to decode payload %{public}@", log: log, type: .error, String(describing: error))
            }

            do {
                try submit(data)
            } catch {
                os_log("failed to submit payload %{public}@", log: log, type: .error, String(describing: error))
            }
        }
    }
}

extension MeterReporter {
	@MainActor
    private func configureExceptionLogging() {
        #if os(macOS)
        if let app = NSApp as? ExceptionLoggingApplication {
            app.exceptionInfoURL = exceptionInfoURL
        }
        #endif

        UncaughtExceptionLogger.logger.exceptionInfoURL = exceptionInfoURL
    }
    
    private nonisolated var exceptionInfoURL: URL {
        return reportDirectoryURL.appendingPathComponent("exception_info.json")
    }

    private func existingExceptionInfo() -> ExceptionInfo? {
        let url = exceptionInfoURL

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return nil
        }

        let info: ExceptionInfo?

        do {
            let data = try Data(contentsOf: url)
            info = try JSONDecoder().decode(ExceptionInfo.self, from: data)
        } catch {
            os_log("failed to decode exception_info.json %{public}@", log: log, type: .error, String(describing: error))
            info = nil
        }

        return info
    }

    private func removeExistingExceptionInfo() {
        let url = exceptionInfoURL

        if FileManager.default.fileExists(atPath: url.path) == false {
            return
        }

        removeItem(at: url)
    }

    func processPayload(_ payload: DiagnosticPayload, with symbolicator: Symbolicator, exceptionInfo: ExceptionInfo?) -> Data {
        let symPayload = symbolicator.symbolicate(payload: payload)
        let lastCrash = symPayload.crashDiagnostics?.last

        if let lastCrash = lastCrash, let info = exceptionInfo {
            if info.matchesCrashDiagnostic(lastCrash) {
                lastCrash.exceptionInfo = info
            }
        }

        return symPayload.jsonRepresentation()
    }

    func submit(_ data: Data) throws {
        let id = UUID().lowerAlphaOnly
        let url = reportDirectoryURL.appendingPathComponent(id).appendingPathExtension("mxdiagnostic")

        try data.write(to: url)

        submit(url, identifier: id)
    }

    func submit(_ url: URL, identifier: String? = nil) {
        let id = identifier ?? url.deletingPathExtension().lastPathComponent

        os_log("submitting %{public}@", log: log, type: .info, url.path)

        let request = makeURLRequest(for: id)

		Task { [submitter] in
			await submitter.submit(fileURL: url, identifier: id, uploadRequest: request)
		}
    }

    func removeItem(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            os_log("failed to remove item at %{public}@ %{public}@", log: log, type: .error, url.path, String(describing: error))
        }
    }

    func handleExistingLog(at url: URL, date: Date) {
        if url == exceptionInfoURL {
            os_log("removing existing exception_info.json", log: log, type: .info)
            removeItem(at: url)
            return
        }

        // ~ 7 days
        let oldDate = Date().addingTimeInterval(-7.0 * 24.0 * 60.0 * 60.0)

        if date < oldDate {
            os_log("removing old log %{public}@", log: log, type: .info, url.path)
            removeItem(at: url)
            return
        }

        os_log("resubmitting %{public}@", log: log, type: .info, url.path)

        submit(url)
    }
}

extension MeterReporter {
    private var platformName: String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        return "iOS"
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(watchOS)
        return "watchOS"
        #else
        return "unknown"
        #endif
    }

    private func makeURLRequest(for reportID: String) -> URLRequest {
        let url = configuration.endpointURL

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)

        request.httpMethod = "PUT"

        request.addValue(reportID, forHTTPHeaderField: "MeterReporter-Report-Id")
        request.addValue(platformName, forHTTPHeaderField: "MeterReporter-Platform")

        if let host = configuration.hostIdentifier {
            request.addValue(host, forHTTPHeaderField: "MeterReporter-Host-Id")
        }
        request.addValue(configuration.appShortCode, forHTTPHeaderField: "appShortCode")
        request.addValue(configuration.appName, forHTTPHeaderField: "appName")
        request.addValue("Application/json", forHTTPHeaderField: "Content-Type")

        return request
    }
}
