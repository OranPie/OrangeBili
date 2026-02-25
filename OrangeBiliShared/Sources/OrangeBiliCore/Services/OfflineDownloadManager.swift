import Foundation

public struct DownloadStatusItem: Identifiable, Hashable {
    public enum State: String {
        case queued
        case downloading
        case completed
        case failed
        case canceled
    }

    public let id: UUID
    public let bvid: String
    public let title: String
    public var state: State
    public var progress: Double
    public var receivedBytes: Int64
    public var totalBytes: Int64
    public var speedBytesPerSec: Double
    public var localFileURL: URL?
    public var coverURL: URL?
    public var localCoverURL: URL?
    public var errorMessage: String?

    public init(bvid: String, title: String, coverURL: URL?) {
        id = UUID()
        self.bvid = bvid
        self.title = title
        self.coverURL = coverURL
        state = .queued
        progress = 0
        receivedBytes = 0
        totalBytes = 0
        speedBytesPerSec = 0
    }
}

public final class OfflineDownloadManager: NSObject, ObservableObject {
    public static let shared = OfflineDownloadManager()

    @Published public private(set) var items: [DownloadStatusItem] = []

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    private var taskToItemID: [Int: UUID] = [:]
    private var lastSample: [Int: (time: Date, bytes: Int64)] = [:]
    private let folderURL: URL

    override private init() {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        folderURL = baseURL.appendingPathComponent("offline-downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        super.init()
    }

    public func startDownload(bvid: String, title: String, url: URL, headers: [String: String], coverURL: URL?) {
        if items.contains(where: { $0.bvid == bvid && ($0.state == .queued || $0.state == .downloading) }) {
            return
        }

        let item = DownloadStatusItem(bvid: bvid, title: title, coverURL: coverURL)
        items.insert(item, at: 0)

        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let task = session.downloadTask(with: request)
        taskToItemID[task.taskIdentifier] = item.id
        lastSample[task.taskIdentifier] = (Date(), 0)
        update(itemID: item.id) { $0.state = .downloading }
        if let coverURL {
            downloadCover(itemID: item.id, bvid: bvid, url: coverURL, headers: headers)
        }
        task.resume()
    }

    public func cancel(itemID: UUID) {
        guard let taskID = taskToItemID.first(where: { $0.value == itemID })?.key else {
            update(itemID: itemID) { $0.state = .canceled }
            return
        }
        session.getAllTasks { tasks in
            tasks.first(where: { $0.taskIdentifier == taskID })?.cancel()
        }
    }

    public func remove(itemID: UUID) {
        if let fileURL = items.first(where: { $0.id == itemID })?.localFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        if let fileURL = items.first(where: { $0.id == itemID })?.localCoverURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        items.removeAll { $0.id == itemID }
    }

    private func update(itemID: UUID, mutate: (inout DownloadStatusItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        var item = items[index]
        mutate(&item)
        items[index] = item
    }

    private func outputURL(for bvid: String, response: URLResponse?) -> URL {
        let suggested = (response?.suggestedFilename as NSString?)?.pathExtension
        let ext = (suggested?.isEmpty == false ? suggested! : "mp4")
        return folderURL.appendingPathComponent("\(bvid).\(ext)")
    }

    private func coverOutputURL(for bvid: String, url: URL, response: URLResponse?) -> URL {
        let extFromURL = url.pathExtension
        let extFromMime = response?.mimeType?.split(separator: "/").last.map(String.init)
        let ext = !extFromURL.isEmpty ? extFromURL : (extFromMime?.isEmpty == false ? extFromMime! : "jpg")
        return folderURL.appendingPathComponent("\(bvid)_cover.\(ext)")
    }

    private func downloadCover(itemID: UUID, bvid: String, url: URL, headers: [String: String]) {
        let finalURL: URL
        if url.scheme == "http", let host = url.host {
            var comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
            comp?.scheme = "https"
            comp?.host = host
            finalURL = comp?.url ?? url
        } else {
            finalURL = url
        }

        var request = URLRequest(url: finalURL)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        session.dataTask(with: request) { [weak self] data, response, _ in
            guard let self, let data, !data.isEmpty else { return }
            let output = self.coverOutputURL(for: bvid, url: url, response: response)
            try? FileManager.default.removeItem(at: output)
            do {
                try data.write(to: output, options: .atomic)
                DispatchQueue.main.async {
                    self.update(itemID: itemID) {
                        $0.localCoverURL = output
                    }
                }
            } catch {
                DebugLogStore.shared.log(category: "download", message: "save cover fail \(bvid): \(error.localizedDescription)")
            }
        }.resume()
    }
}

extension OfflineDownloadManager: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let itemID = taskToItemID[downloadTask.taskIdentifier],
              let item = items.first(where: { $0.id == itemID })
        else { return }

        let output = outputURL(for: item.bvid, response: downloadTask.response)
        try? FileManager.default.removeItem(at: output)

        do {
            try FileManager.default.moveItem(at: location, to: output)
            update(itemID: itemID) {
                $0.state = .completed
                $0.progress = 1
                $0.localFileURL = output
                $0.speedBytesPerSec = 0
            }
            if item.localCoverURL == nil, let coverURL = item.coverURL {
                let headers = [
                    "Referer": "https://www.bilibili.com",
                    "User-Agent": PlatformInfo.userAgent
                ]
                downloadCover(itemID: itemID, bvid: item.bvid, url: coverURL, headers: headers)
            }
        } catch {
            update(itemID: itemID) {
                $0.state = .failed
                $0.errorMessage = error.localizedDescription
                $0.speedBytesPerSec = 0
            }
        }

        taskToItemID.removeValue(forKey: downloadTask.taskIdentifier)
        lastSample.removeValue(forKey: downloadTask.taskIdentifier)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let itemID = taskToItemID[downloadTask.taskIdentifier] else { return }

        var speed = 0.0
        if let last = lastSample[downloadTask.taskIdentifier] {
            let dt = Date().timeIntervalSince(last.time)
            if dt > 0.2 {
                speed = Double(totalBytesWritten - last.bytes) / dt
                lastSample[downloadTask.taskIdentifier] = (Date(), totalBytesWritten)
            }
        }

        update(itemID: itemID) {
            $0.state = .downloading
            $0.receivedBytes = totalBytesWritten
            $0.totalBytes = totalBytesExpectedToWrite
            if totalBytesExpectedToWrite > 0 {
                $0.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
            if speed > 0 {
                $0.speedBytesPerSec = speed
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let itemID = taskToItemID[task.taskIdentifier] else { return }

        update(itemID: itemID) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                $0.state = .canceled
            } else {
                $0.state = .failed
                $0.errorMessage = error.localizedDescription
            }
            $0.speedBytesPerSec = 0
        }

        taskToItemID.removeValue(forKey: task.taskIdentifier)
        lastSample.removeValue(forKey: task.taskIdentifier)
    }
}
