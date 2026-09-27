import Foundation

/// Atomic local persistence used for diagnostics and last-known state.
///
/// The no-team edition intentionally does not use App Groups, because the
/// `group.` entitlement requires provisioning. The WidgetKit extension samples
/// the machine independently and therefore does not depend on this store.
enum SharedSnapshotStore {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    private static let defaults = UserDefaults.standard

    private static let payloadURLs: [URL] = {
        var urls: [URL] = []
        let fileManager = FileManager.default

        // 1. Process-local application support directory
        if let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let directory = support.appendingPathComponent("MacPulse", isDirectory: true)
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            urls.append(directory.appendingPathComponent(AppConstants.sharedPayloadFilename, isDirectory: false))
        }

        // 2. Widget container application support directory (accessible by unsandboxed main app)
        let home = fileManager.homeDirectoryForCurrentUser.path
        if !home.contains("/Library/Containers/") {
            let widgetSupport = URL(fileURLWithPath: home).appendingPathComponent(
                "Library/Containers/com.macpulse.local.MacPulse.Widget/Data/Library/Application Support/MacPulse",
                isDirectory: true
            )
            try? fileManager.createDirectory(at: widgetSupport, withIntermediateDirectories: true)
            let widgetURL = widgetSupport.appendingPathComponent(AppConstants.sharedPayloadFilename, isDirectory: false)
            if !urls.contains(widgetURL) {
                urls.append(widgetURL)
            }
        }

        return urls
    }()

    @discardableResult
    static func save(_ payload: SharedPayload) -> Bool {
        guard let data = try? encoder.encode(payload) else { return false }

        var written = false
        for url in payloadURLs {
            do {
                try data.write(to: url, options: [.atomic])
                written = true
            } catch {
                // Continue to next candidate
            }
        }

        defaults.set(data, forKey: AppConstants.sharedPayloadKey)
        return written
    }

    static func load() -> SharedPayload? {
        let candidates: [Data?] = payloadURLs.map { try? Data(contentsOf: $0, options: [.mappedIfSafe]) }

        for data in candidates.compactMap({ $0 }) {
            guard let payload = try? decoder.decode(SharedPayload.self, from: data),
                  payload.schemaVersion == AppConstants.payloadSchemaVersion else { continue }
            return payload
        }

        if let fallbackData = defaults.data(forKey: AppConstants.sharedPayloadKey),
           let payload = try? decoder.decode(SharedPayload.self, from: fallbackData),
           payload.schemaVersion == AppConstants.payloadSchemaVersion {
            return payload
        }

        return nil
    }

    static func reset() {
        for url in payloadURLs {
            try? FileManager.default.removeItem(at: url)
        }
        defaults.removeObject(forKey: AppConstants.sharedPayloadKey)
    }
}
