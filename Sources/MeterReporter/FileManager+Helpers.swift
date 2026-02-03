import Foundation

extension FileManager {
    /// Returns a URL for a subdirectory within a search path directory,
    /// named after the app's bundle identifier
    /// - Parameter dir: The search path directory (e.g., .cachesDirectory)
    /// - Returns: URL to the bundle-scoped subdirectory, or nil if unavailable
    func bundleIdSubdirectoryURL(for dir: FileManager.SearchPathDirectory) -> URL? {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let baseURL = urls(for: dir, in: .userDomainMask).first else {
            return nil
        }
        return baseURL.appendingPathComponent(bundleId)
    }
}
