import Foundation
@preconcurrency import ImageCaptureCore

/// カメラ情報を表す構造体
struct CameraInfo: Sendable {
    let name: String
    let serialNumber: String?
    let deviceType: String
}

/// ファイル情報を表す構造体
struct FileInfo: Sendable {
    let name: String
    let size: Int64
    let isDirectory: Bool
    let path: String
}

/// ImageCaptureCoreを使用したカメラサービス
/// PTPデバイスの検出、情報取得、ファイル操作を提供
@MainActor
final class CameraService: NSObject {
    private let deviceBrowser: ICDeviceBrowser
    private var cameras: [ICCameraDevice] = []
    private var continuation: CheckedContinuation<[CameraInfo], Never>?
    private var fileContinuation: CheckedContinuation<[FileInfo], Never>?
    private var downloadContinuation: CheckedContinuation<URL, any Error>?
    private var pendingFiles: [FileInfo] = []
    private var isEnumerating = false

    override init() {
        deviceBrowser = ICDeviceBrowser()
        super.init()
        deviceBrowser.delegate = self
        deviceBrowser.browsedDeviceTypeMask = ICDeviceTypeMask(rawValue:
            ICDeviceTypeMask.camera.rawValue | ICDeviceLocationTypeMask.local.rawValue
        )!
    }

    /// 接続されているカメラを検出する
    func discoverCameras(timeout: TimeInterval = 3.0) async -> [CameraInfo] {
        // 既にカメラが見つかっている場合は再検索しない
        if !cameras.isEmpty {
            return cameras.map { device in
                CameraInfo(
                    name: device.name ?? "Unknown",
                    serialNumber: device.serialNumberString,
                    deviceType: "PTP Camera"
                )
            }
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            deviceBrowser.start()

            // タイムアウト後に結果を返す（ブラウザは停止しない）
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await MainActor.run {
                    // deviceBrowser.stop() を呼ばない - カメラとの接続を維持
                    if let cont = self.continuation {
                        self.continuation = nil
                        let infos = self.cameras.map { device in
                            CameraInfo(
                                name: device.name ?? "Unknown",
                                serialNumber: device.serialNumberString,
                                deviceType: "PTP Camera"
                            )
                        }
                        cont.resume(returning: infos)
                    }
                }
            }
        }
    }

    /// 接続されているカメラの詳細情報を取得
    func getCameraDetails() async -> [(name: String, details: [String: String])] {
        let _ = await discoverCameras()
        return cameras.map { device in
            var details: [String: String] = [:]
            details["Name"] = device.name ?? "Unknown"
            details["Serial Number"] = device.serialNumberString ?? "N/A"
            details["Model"] = device.name ?? "N/A"
            if let uuidString = device.uuidString {
                details["UUID"] = uuidString
            }
            return (name: device.name ?? "Unknown", details: details)
        }
    }

    /// カメラ内のファイル一覧を取得
    func listFiles(path: String? = nil, timeout: TimeInterval = 10.0) async -> [FileInfo] {
        // 既にファイル一覧がある場合はキャッシュを返す
        if !pendingFiles.isEmpty {
            return pendingFiles
        }

        let _ = await discoverCameras()

        guard let camera = cameras.first else {
            return []
        }

        return await withCheckedContinuation { continuation in
            self.fileContinuation = continuation
            self.pendingFiles = []
            self.isEnumerating = true

            camera.delegate = self
            camera.requestOpenSession()

            // タイムアウト後に現在取得済みのファイルを返す
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await MainActor.run {
                    if let cont = self.fileContinuation {
                        self.fileContinuation = nil
                        cont.resume(returning: self.pendingFiles)
                    }
                }
            }
        }
    }

    /// ファイルをダウンロード
    func downloadFile(named fileName: String, to destinationDir: URL) async throws -> URL {
        let _ = await discoverCameras()

        guard let camera = cameras.first else {
            throw CameraError.noCameraFound
        }

        // ファイル一覧を取得してファイルを探す
        let files = await listFiles()
        guard let _ = files.first(where: { $0.name == fileName }) else {
            throw CameraError.fileNotFound(fileName)
        }

        // ImageCaptureCoreのファイルオブジェクトを探す
        guard let cameraFile = findCameraFile(named: fileName, in: camera) else {
            throw CameraError.fileNotFound(fileName)
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.downloadContinuation = continuation

            let options: [ICDownloadOption: Any] = [
                .downloadsDirectoryURL: destinationDir,
                .overwrite: true,
                .saveAsFilename: fileName
            ]

            camera.requestDownloadFile(
                cameraFile,
                options: options,
                downloadDelegate: self,
                didDownloadSelector: #selector(didDownloadFile(_:error:options:contextInfo:)),
                contextInfo: nil
            )
        }
    }

    /// 全ファイルをダウンロード
    func downloadAllFiles(to destinationDir: URL, progress: @escaping (String, Int, Int) -> Void) async throws -> Int {
        let files = await listFiles()
        let downloadableFiles = files.filter { !$0.isDirectory }
        var downloadedCount = 0

        for (index, file) in downloadableFiles.enumerated() {
            progress(file.name, index + 1, downloadableFiles.count)
            let _ = try await downloadFile(named: file.name, to: destinationDir)
            downloadedCount += 1
        }

        return downloadedCount
    }

    private func findCameraFile(named name: String, in camera: ICCameraDevice) -> ICCameraFile? {
        func searchFiles(_ items: [ICCameraItem]?) -> ICCameraFile? {
            guard let items = items else { return nil }
            for item in items {
                if let file = item as? ICCameraFile, file.name == name {
                    return file
                }
                if let folder = item as? ICCameraFolder {
                    if let found = searchFiles(folder.contents) {
                        return found
                    }
                }
            }
            return nil
        }
        return searchFiles(camera.mediaFiles)
    }
}

// MARK: - ICDeviceBrowserDelegate
extension CameraService: ICDeviceBrowserDelegate {
    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        guard let camera = device as? ICCameraDevice else { return }
        // カメラ発見時にデリゲートを設定
        camera.delegate = self
        Task { @MainActor in
            self.cameras.append(camera)
        }
    }

    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        let uuid = device.uuidString
        Task { @MainActor in
            self.cameras.removeAll { $0.uuidString == uuid }
        }
    }
}

// MARK: - ICCameraDeviceDelegate
extension CameraService: ICCameraDeviceDelegate {
    nonisolated func cameraDevice(_ camera: ICCameraDevice, didAdd items: [ICCameraItem]) {
        let fileInfos = items.map { item in
            FileInfo(
                name: item.name ?? "Unknown",
                size: (item as? ICCameraFile)?.fileSize ?? 0,
                isDirectory: item is ICCameraFolder,
                path: item.name ?? ""
            )
        }
        Task { @MainActor in
            self.pendingFiles.append(contentsOf: fileInfos)
        }
    }

    nonisolated func cameraDevice(_ camera: ICCameraDevice, didRemove items: [ICCameraItem]) {}

    nonisolated func cameraDevice(_ camera: ICCameraDevice, didRenameItems items: [ICCameraItem]) {}

    nonisolated func cameraDevice(_ camera: ICCameraDevice, didCompleteDeleteFilesWithError error: Error?) {}

    nonisolated func cameraDevice(_ camera: ICCameraDevice, didReceiveThumbnail thumbnail: CGImage?, for item: ICCameraItem, error: Error?) {}

    nonisolated func cameraDevice(_ camera: ICCameraDevice, didReceiveMetadata metadata: [AnyHashable: Any]?, for item: ICCameraItem, error: Error?) {}

    nonisolated func cameraDevice(_ camera: ICCameraDevice, didReceivePTPEvent eventData: Data) {}

    nonisolated func cameraDeviceDidChangeCapability(_ camera: ICCameraDevice) {}

    nonisolated func cameraDeviceDidRemoveAccessRestriction(_ device: ICDevice) {}

    nonisolated func cameraDeviceDidEnableAccessRestriction(_ device: ICDevice) {}

    nonisolated func deviceDidBecomeReady(withCompleteContentCatalog device: ICCameraDevice) {
        Task { @MainActor in
            if let cont = self.fileContinuation {
                self.fileContinuation = nil
                cont.resume(returning: self.pendingFiles)
            }
        }
    }

    nonisolated func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("Failed to open session: \(error)")
                if let cont = self.fileContinuation {
                    self.fileContinuation = nil
                    cont.resume(returning: [])
                }
            }
        }
    }

    nonisolated func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {}

    nonisolated func didRemove(_ device: ICDevice) {}
}

// MARK: - ICCameraDeviceDownloadDelegate
extension CameraService: ICCameraDeviceDownloadDelegate {
    @objc nonisolated func didDownloadFile(_ file: ICCameraFile, error: Error?, options: [String: Any], contextInfo: UnsafeMutableRawPointer?) {
        let savedFilename = options[ICDownloadOption.savedFilename.rawValue] as? String
        let destDir = options[ICDownloadOption.downloadsDirectoryURL.rawValue] as? URL
        let downloadError = error

        Task { @MainActor in
            if let error = downloadError {
                self.downloadContinuation?.resume(throwing: error)
            } else if let filename = savedFilename, let dir = destDir {
                self.downloadContinuation?.resume(returning: dir.appendingPathComponent(filename))
            } else {
                self.downloadContinuation?.resume(throwing: CameraError.downloadFailed("Unknown error"))
            }
            self.downloadContinuation = nil
        }
    }
}

// MARK: - Errors
enum CameraError: LocalizedError {
    case noCameraFound
    case fileNotFound(String)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .noCameraFound:
            return "No camera found. Please connect a camera."
        case .fileNotFound(let name):
            return "File not found: \(name)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        }
    }
}
