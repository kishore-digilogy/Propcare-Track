import Foundation

/// Append-only JSON-lines queue shared by the Core Location manager and the
/// Flutter method channel. Records survive app termination and are replayed
/// idempotently using their UUID.
final class TrackingStore {
    static let shared = TrackingStore()

    private let lock = NSLock()
    private let fileName = "tracking_queue.jsonl"

    private var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("PropCare", isDirectory: true)
    }

    private var fileURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }

    private func ensureDirectory() {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            // A read-only container would be fatal elsewhere; queueing is best effort.
        }
    }

    func append(_ record: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }
        ensureDirectory()
        guard
            let data = try? JSONSerialization.data(withJSONObject: record, options: []),
            var line = String(data: data, encoding: .utf8)
        else { return }
        line += "\n"
        guard let payload = line.data(using: .utf8) else { return }

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? payload.write(to: fileURL, options: .atomic)
            return
        }
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        defer { try? handle.close() }
        if #available(iOS 13.4, *) {
            try? handle.seekToEnd()
        } else {
            handle.seekToEndOfFile()
        }
        handle.write(payload)
    }

    func records() -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
    }

    func ack(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        let kept = recordsLocked().filter { record in
            guard let id = record["id"] as? String else { return true }
            return !ids.contains(id)
        }
        // Serialise as JSON-lines so the file format stays consistent.
        var text = kept.compactMap { record -> String? in
            guard let line = try? JSONSerialization.data(withJSONObject: record),
                  let string = String(data: line, encoding: .utf8) else { return nil }
            return string
        }.joined(separator: "\n")
        if !text.isEmpty { text += "\n" }
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return recordsLocked().count
    }

    /// Caller must hold `lock`.
    private func recordsLocked() -> [[String: Any]] {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
    }
}
