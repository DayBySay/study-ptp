# ソースコード全体解説

## 1. アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLI Layer                                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐   │
│  │ devices  │ │   info   │ │   list   │ │     download     │   │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────────┬─────────┘   │
│       │            │            │                 │              │
│       └────────────┴────────────┴─────────────────┘              │
│                              │                                    │
├──────────────────────────────┼────────────────────────────────────┤
│                         Core Layer                                │
│                              ▼                                    │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                     CameraService                            │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │ │
│  │  │ CameraInfo  │  │  FileInfo   │  │    CameraError      │ │ │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                              │                                    │
├──────────────────────────────┼────────────────────────────────────┤
│                      Apple Framework                              │
│                              ▼                                    │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                   ImageCaptureCore                           │ │
│  │  ICDeviceBrowser, ICCameraDevice, ICCameraFile, ...         │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. CLI Layer（Sources/CLI/）

### main.swift - エントリポイント

```swift
@main
struct PTPTool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ptp-tool",
        subcommands: [
            DevicesCommand.self,
            InfoCommand.self,
            ListCommand.self,
            DownloadCommand.self
        ]
    )
}
```

**責務**:
- CLI のルートコマンド定義
- サブコマンドの登録
- `@main` でプログラムのエントリポイントを指定

**依存**: `ArgumentParser`（Apple製CLIフレームワーク）

---

### 各サブコマンドの責務

| コマンド | ファイル | 責務 |
|----------|----------|------|
| `devices` | DevicesCommand.swift | カメラ検出・一覧表示 |
| `info` | InfoCommand.swift | カメラ詳細情報表示 |
| `list` | ListCommand.swift | ファイル一覧表示 |
| `download` | DownloadCommand.swift | ファイルダウンロード |

**共通パターン**:
```swift
struct XxxCommand: AsyncParsableCommand {
    @MainActor
    func run() async throws {
        let service = CameraService()  // サービス生成
        let result = await service.xxx()  // 非同期呼び出し
        // 結果を表示
    }
}
```

- すべて `AsyncParsableCommand` を採用（async/await対応）
- `@MainActor` でメインスレッド実行を保証
- `CameraService` を生成して処理を委譲

---

## 3. Core Layer（Sources/Core/）

### CameraService - 中心となるサービスクラス

```swift
@MainActor
public final class CameraService: NSObject {
    private let deviceBrowser: ICDeviceBrowser      // デバイス検索
    private var cameras: [ICCameraDevice] = []       // 発見したカメラ
    private var continuation: CheckedContinuation<...>?  // async/await変換用
    private var pendingFiles: [FileInfo] = []        // ファイルキャッシュ
}
```

**責務**:
1. **デバイス検出**: USBカメラの検出・管理
2. **セッション管理**: カメラとの接続確立
3. **ファイル操作**: 一覧取得・ダウンロード
4. **API変換**: ImageCaptureCore のコールバック → async/await

**設計上のポイント**:
- `@MainActor`: UIスレッドでの実行を保証（ImageCaptureCoreの要件）
- `NSObject` 継承: Objective-C デリゲートパターンのため必須
- `final class`: 継承不可（パフォーマンス最適化）

---

## 4. ImageCaptureCore との連携

### 4.1 デバイス検出フロー

```
┌─────────────┐         ┌─────────────────┐         ┌──────────────┐
│ CLI Command │         │  CameraService  │         │ICDeviceBrowser│
└──────┬──────┘         └────────┬────────┘         └───────┬──────┘
       │                         │                          │
       │ discoverCameras()       │                          │
       │────────────────────────>│                          │
       │                         │ start()                  │
       │                         │─────────────────────────>│
       │                         │                          │
       │                         │    deviceBrowser(_:didAdd:)
       │                         │<─────────────────────────│
       │                         │                          │
       │                         │ (タイムアウト後)           │
       │                         │                          │
       │   [CameraInfo]          │                          │
       │<────────────────────────│                          │
```

**コード対応**:

```swift
// 1. ブラウザ初期化（init時）
deviceBrowser = ICDeviceBrowser()
deviceBrowser.delegate = self
deviceBrowser.browsedDeviceTypeMask = ICDeviceTypeMask.camera | ICDeviceLocationTypeMask.local

// 2. 検索開始
public func discoverCameras(timeout: TimeInterval = 3.0) async -> [CameraInfo] {
    return await withCheckedContinuation { continuation in
        self.continuation = continuation
        deviceBrowser.start()  // 検索開始

        Task {
            try? await Task.sleep(...)  // タイムアウト待機
            cont.resume(returning: cameras.map { ... })  // 結果を返す
        }
    }
}

// 3. デリゲートでカメラ発見を受信
func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
    guard let camera = device as? ICCameraDevice else { return }
    cameras.append(camera)
}
```

---

### 4.2 ファイル一覧取得フロー

```
┌─────────────┐       ┌─────────────────┐       ┌──────────────────┐
│ CLI Command │       │  CameraService  │       │  ICCameraDevice  │
└──────┬──────┘       └────────┬────────┘       └────────┬─────────┘
       │                       │                         │
       │ listFiles()           │                         │
       │──────────────────────>│                         │
       │                       │ requestOpenSession()    │
       │                       │────────────────────────>│
       │                       │                         │
       │                       │   cameraDevice(_:didAdd:) ×N回
       │                       │<────────────────────────│
       │                       │                         │
       │                       │   deviceDidBecomeReady()│
       │                       │<────────────────────────│
       │                       │                         │
       │   [FileInfo]          │                         │
       │<──────────────────────│                         │
```

**コード対応**:

```swift
// 1. セッション開始リクエスト
public func listFiles(timeout: TimeInterval = 10.0) async -> [FileInfo] {
    return await withCheckedContinuation { continuation in
        self.fileContinuation = continuation
        camera.delegate = self
        camera.requestOpenSession()  // PTP OpenSession
    }
}

// 2. ファイル追加通知（複数回呼ばれる）
func cameraDevice(_ camera: ICCameraDevice, didAdd items: [ICCameraItem]) {
    let fileInfos = items.map { item in
        FileInfo(
            name: item.name ?? "Unknown",
            size: (item as? ICCameraFile)?.fileSize ?? 0,
            isDirectory: item is ICCameraFolder,
            path: item.name ?? ""
        )
    }
    self.pendingFiles.append(contentsOf: fileInfos)
}

// 3. 全ファイル取得完了通知
func deviceDidBecomeReady(withCompleteContentCatalog device: ICCameraDevice) {
    fileContinuation?.resume(returning: pendingFiles)
}
```

---

### 4.3 ダウンロードフロー

```
┌─────────────┐       ┌─────────────────┐       ┌──────────────────┐
│ CLI Command │       │  CameraService  │       │  ICCameraDevice  │
└──────┬──────┘       └────────┬────────┘       └────────┬─────────┘
       │                       │                         │
       │ downloadFile()        │                         │
       │──────────────────────>│                         │
       │                       │ requestDownloadFile()   │
       │                       │────────────────────────>│
       │                       │                         │
       │                       │   didDownloadFile()     │
       │                       │<────────────────────────│
       │                       │                         │
       │   URL (保存先)         │                         │
       │<──────────────────────│                         │
```

**コード対応**:

```swift
// 1. ダウンロードリクエスト
public func downloadFile(named fileName: String, to destinationDir: URL) async throws -> URL {
    return try await withCheckedThrowingContinuation { continuation in
        self.downloadContinuation = continuation

        camera.requestDownloadFile(
            cameraFile,
            options: [.downloadsDirectoryURL: destinationDir, ...],
            downloadDelegate: self,
            didDownloadSelector: #selector(didDownloadFile(_:error:options:contextInfo:)),
            contextInfo: nil
        )
    }
}

// 2. ダウンロード完了コールバック
@objc func didDownloadFile(_ file: ICCameraFile, error: Error?, options: [String: Any], ...) {
    if let error = error {
        downloadContinuation?.resume(throwing: error)
    } else {
        downloadContinuation?.resume(returning: savedURL)
    }
}
```

---

## 5. コールバック → async/await 変換パターン

ImageCaptureCore はデリゲートベースのコールバックAPI。これを `async/await` に変換：

```swift
// パターン: withCheckedContinuation
public func listFiles() async -> [FileInfo] {
    return await withCheckedContinuation { continuation in
        // 1. continuation を保存
        self.fileContinuation = continuation

        // 2. 非同期処理を開始
        camera.requestOpenSession()

        // 3. タイムアウト処理
        Task {
            try? await Task.sleep(...)
            if let cont = self.fileContinuation {
                self.fileContinuation = nil
                cont.resume(returning: self.pendingFiles)
            }
        }
    }
}

// デリゲートメソッドで continuation.resume() を呼ぶ
func deviceDidBecomeReady(...) {
    if let cont = self.fileContinuation {
        self.fileContinuation = nil
        cont.resume(returning: self.pendingFiles)
    }
}
```

**ポイント**:
- `continuation` はインスタンス変数に保存（デリゲートからアクセスするため）
- `resume()` は**1回だけ**呼ぶ（2回呼ぶとクラッシュ）
- タイムアウト処理で「応答がない場合」にも対応

---

## 6. Swift 6 対応

### 6.1 `@preconcurrency import`

```swift
@preconcurrency import ImageCaptureCore
```

ImageCaptureCore は Swift 6 の `Sendable` に未対応。`@preconcurrency` で警告を抑制。

### 6.2 `nonisolated` デリゲートメソッド

```swift
public nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, ...) {
    Task { @MainActor in
        self.cameras.append(camera)  // MainActor で状態更新
    }
}
```

- デリゲートメソッドは任意スレッドから呼ばれる
- `nonisolated` でアクター分離を解除
- 状態更新は `Task { @MainActor in }` で安全に実行

---

## 7. クラス間の依存関係

```
                    ┌─────────────────┐
                    │   ArgumentParser │ (外部依存)
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│DevicesCommand│    │ ListCommand  │    │ DownloadCmd  │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           ▼
                   ┌───────────────┐
                   │ CameraService │ ◄─── PTPToolCore モジュール
                   └───────┬───────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  CameraInfo  │   │   FileInfo   │   │ CameraError  │
└──────────────┘   └──────────────┘   └──────────────┘
                           │
                           ▼
                ┌─────────────────────┐
                │  ImageCaptureCore   │ (Apple Framework)
                └─────────────────────┘
```

---

## 8. データモデル

### CameraInfo

```swift
public struct CameraInfo: Sendable, Equatable {
    public let name: String           // カメラ名（例: "RICOH GR IV"）
    public let serialNumber: String?  // シリアル番号（取得できない場合は nil）
    public let deviceType: String     // デバイス種別（"PTP Camera"）
}
```

### FileInfo

```swift
public struct FileInfo: Sendable, Equatable {
    public let name: String       // ファイル名（例: "R0000531.JPG"）
    public let size: Int64        // ファイルサイズ（バイト）
    public let isDirectory: Bool  // ディレクトリかどうか
    public let path: String       // パス
}
```

### CameraError

```swift
public enum CameraError: LocalizedError, Equatable {
    case noCameraFound              // カメラ未接続
    case fileNotFound(String)       // ファイルが見つからない
    case downloadFailed(String)     // ダウンロード失敗
}
```

---

## 9. まとめ

| レイヤー | 責務 | 主要クラス |
|----------|------|-----------|
| CLI | ユーザー入出力、引数解析 | `PTPTool`, `*Command` |
| Core | ビジネスロジック、API抽象化 | `CameraService` |
| Model | データ表現 | `CameraInfo`, `FileInfo`, `CameraError` |
| Framework | USB/PTP通信 | `ICDeviceBrowser`, `ICCameraDevice` |

**設計のポイント**:
1. **CLI と Core の分離**: テスト容易性、再利用性
2. **async/await への変換**: モダンな非同期API提供
3. **Swift 6 対応**: 厳格な並行処理チェックをパス
4. **キャッシュ戦略**: カメラ/ファイル情報を保持して再検索を回避
