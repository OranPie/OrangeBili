import Foundation
import AVFoundation

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
    public var localPackageFolderURL: URL?
    public var sourceURL: URL?
    public var sourceAudioURL: URL?
    public var requestHeaders: [String: String]
    public var errorMessage: String?

    public init(
        bvid: String,
        title: String,
        coverURL: URL?,
        sourceURL: URL? = nil,
        sourceAudioURL: URL? = nil,
        requestHeaders: [String: String] = [:]
    ) {
        id = UUID()
        self.bvid = bvid
        self.title = title
        self.coverURL = coverURL
        self.sourceURL = sourceURL
        self.sourceAudioURL = sourceAudioURL
        self.requestHeaders = requestHeaders
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

        let item = DownloadStatusItem(bvid: bvid, title: title, coverURL: coverURL, sourceURL: url, requestHeaders: headers)
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

    public func startDASHDownload(
        bvid: String,
        title: String,
        videoURL: URL,
        audioURL: URL,
        headers: [String: String],
        coverURL: URL?
    ) {
        if items.contains(where: { $0.bvid == bvid && ($0.state == .queued || $0.state == .downloading) }) {
            return
        }

        let item = DownloadStatusItem(
            bvid: bvid,
            title: title,
            coverURL: coverURL,
            sourceURL: videoURL,
            sourceAudioURL: audioURL,
            requestHeaders: headers
        )
        items.insert(item, at: 0)
        update(itemID: item.id) { $0.state = .downloading }

        Task {
            await downloadDASHPackage(itemID: item.id, bvid: bvid, videoURL: videoURL, audioURL: audioURL, headers: headers, coverURL: coverURL)
        }
    }

    public func retry(itemID: UUID) {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        guard let videoURL = item.sourceURL else {
            update(itemID: itemID) {
                $0.state = .failed
                $0.errorMessage = L10n.t("downloads.retry.unavailable")
            }
            return
        }
        let audioURL = item.sourceAudioURL
        let headers = item.requestHeaders
        let coverURL = item.coverURL
        let bvid = item.bvid
        let title = item.title
        remove(itemID: itemID)
        if let audioURL {
            startDASHDownload(bvid: bvid, title: title, videoURL: videoURL, audioURL: audioURL, headers: headers, coverURL: coverURL)
        } else {
            startDownload(bvid: bvid, title: title, url: videoURL, headers: headers, coverURL: coverURL)
        }
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
        if let folderURL = items.first(where: { $0.id == itemID })?.localPackageFolderURL {
            try? FileManager.default.removeItem(at: folderURL)
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

    private struct LocalDASHManifest: Codable {
        let version: Int
        let bvid: String
        let videoFile: String
        let audioFile: String
    }

    private func downloadDASHPackage(
        itemID: UUID,
        bvid: String,
        videoURL: URL,
        audioURL: URL,
        headers: [String: String],
        coverURL: URL?
    ) async {
        func makeRequest(_ url: URL) -> URLRequest {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.timeoutInterval = 30
            for (k, v) in headers {
                req.setValue(v, forHTTPHeaderField: k)
            }
            return req
        }

        let packageFolder = folderURL.appendingPathComponent("\(bvid)-dash", isDirectory: true)
        let videoOut = packageFolder.appendingPathComponent("video.m4s")
        let audioOut = packageFolder.appendingPathComponent("audio.m4s")
        let manifestOut = packageFolder.appendingPathComponent("manifest.json")

        do {
            try? FileManager.default.removeItem(at: packageFolder)
            try FileManager.default.createDirectory(at: packageFolder, withIntermediateDirectories: true)

            let (videoTemp, videoResp) = try await URLSession.shared.download(for: makeRequest(videoURL))
            if let http = videoResp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            try FileManager.default.moveItem(at: videoTemp, to: videoOut)
            await MainActor.run {
                self.update(itemID: itemID) {
                    $0.progress = 0.5
                    $0.receivedBytes = (videoResp.expectedContentLength > 0 ? videoResp.expectedContentLength : 0)
                    $0.totalBytes = $0.receivedBytes
                    $0.localPackageFolderURL = packageFolder
                }
            }

            let (audioTemp, audioResp) = try await URLSession.shared.download(for: makeRequest(audioURL))
            if let http = audioResp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            try FileManager.default.moveItem(at: audioTemp, to: audioOut)

            let manifest = LocalDASHManifest(version: 1, bvid: bvid, videoFile: "video.m4s", audioFile: "audio.m4s")
            let data = try JSONEncoder().encode(manifest)
            try data.write(to: manifestOut, options: .atomic)

            await MainActor.run {
                self.update(itemID: itemID) {
                    let videoLen = videoResp.expectedContentLength > 0 ? videoResp.expectedContentLength : 0
                    let audioLen = audioResp.expectedContentLength > 0 ? audioResp.expectedContentLength : 0
                    $0.state = .completed
                    $0.progress = 1
                    $0.localFileURL = manifestOut
                    $0.localPackageFolderURL = packageFolder
                    $0.receivedBytes = videoLen + audioLen
                    $0.totalBytes = max($0.receivedBytes, 1)
                    $0.speedBytesPerSec = 0
                    $0.errorMessage = nil
                }
            }

            if let coverURL {
                await MainActor.run {
                    if self.items.first(where: { $0.id == itemID })?.localCoverURL == nil {
                        self.downloadCover(itemID: itemID, bvid: bvid, url: coverURL, headers: headers)
                    }
                }
            }
        } catch {
            try? FileManager.default.removeItem(at: packageFolder)
            await MainActor.run {
                self.update(itemID: itemID) {
                    $0.state = .failed
                    $0.errorMessage = error.localizedDescription
                    $0.speedBytesPerSec = 0
                    $0.progress = 0
                }
            }
        }
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

        if let http = downloadTask.response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            update(itemID: itemID) {
                $0.state = .failed
                $0.errorMessage = "HTTP \(http.statusCode)"
                $0.speedBytesPerSec = 0
            }
            taskToItemID.removeValue(forKey: downloadTask.taskIdentifier)
            lastSample.removeValue(forKey: downloadTask.taskIdentifier)
            return
        }

        let output = outputURL(for: item.bvid, response: downloadTask.response)
        try? FileManager.default.removeItem(at: output)

        do {
            try FileManager.default.moveItem(at: location, to: output)
            if output.pathExtension.lowercased() == "m4s" {
#if os(watchOS)
                // AVAssetExportSession is unavailable on watchOS.
                // Keep behavior explicit instead of producing a broken "completed" item.
                try? FileManager.default.removeItem(at: output)
                update(itemID: itemID) {
                    $0.state = .failed
                    $0.errorMessage = L10n.t("downloads.remux.unsupported.watch")
                    $0.speedBytesPerSec = 0
                }
#else
                // Some CDN variants return fragmented MP4 (.m4s). Remux to MP4 for stable local playback.
                update(itemID: itemID) {
                    $0.state = .downloading
                    $0.progress = 0.99
                    $0.localFileURL = output
                    $0.speedBytesPerSec = 0
                }
                remuxToMP4(inputURL: output, bvid: item.bvid) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success(let mergedURL):
                        try? FileManager.default.removeItem(at: output)
                        self.update(itemID: itemID) {
                            $0.state = .completed
                            $0.progress = 1
                            $0.localFileURL = mergedURL
                            $0.speedBytesPerSec = 0
                            $0.errorMessage = nil
                        }
                        if item.localCoverURL == nil, let coverURL = item.coverURL {
                            let headers = [
                                "Referer": "https://www.bilibili.com",
                                "User-Agent": PlatformInfo.userAgent
                            ]
                            self.downloadCover(itemID: itemID, bvid: item.bvid, url: coverURL, headers: headers)
                        }
                    case .failure(let error):
                        self.update(itemID: itemID) {
                            $0.state = .failed
                            $0.errorMessage = L10n.f("action.download.fail", error.localizedDescription)
                            $0.speedBytesPerSec = 0
                        }
                    }
                }
#endif
            } else {
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

#if !os(watchOS)
    private func remuxToMP4(inputURL: URL, bvid: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVURLAsset(url: inputURL)
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let sourceVideoTrack = asset.tracks(withMediaType: .video).first else {
            completion(.failure(BiliError.noStream))
            return
        }

        do {
            let duration = sourceVideoTrack.timeRange.duration
            guard duration.isNumeric && duration.seconds > 0 else {
                completion(.failure(BiliError.noStream))
                return
            }
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)

            if let sourceAudioTrack = asset.tracks(withMediaType: .audio).first,
               let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                let audioDuration = sourceAudioTrack.timeRange.duration
                if audioDuration.isNumeric && audioDuration.seconds > 0 {
                    let audioRange = CMTimeRange(start: .zero, duration: CMTimeMinimum(duration, audioDuration))
                    try audioTrack.insertTimeRange(audioRange, of: sourceAudioTrack, at: .zero)
                }
            }

            let output = folderURL.appendingPathComponent("\(bvid).mp4")
            try? FileManager.default.removeItem(at: output)

            guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
                completion(.failure(BiliError.noStream))
                return
            }

            exporter.outputURL = output
            exporter.outputFileType = .mp4
            exporter.shouldOptimizeForNetworkUse = false
            exporter.exportAsynchronously {
                DispatchQueue.main.async {
                    if exporter.status == .completed {
                        completion(.success(output))
                    } else {
                        completion(.failure(exporter.error ?? BiliError.noStream))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
#endif
}
