# PTP学習用CLIツール 設計書

## 1. プロジェクト概要

### プロジェクト名
study-ptp (`ptp-tool`)

### 目的
PTP（Picture Transfer Protocol）の仕組みを学習するためのCLIツール。
プロトコルの基本フローから、USBトランスポート層・パケット構造まで段階的に理解することを目指す。

### 背景
- 学習目的のプロジェクト
- 既存ツールの代替ではなく、PTPプロトコルの理解が主眼

## 2. 要件

### 機能要件

#### Phase 1（ImageCaptureCore使用）
1. **デバイス検出**: 接続されたPTPデバイス（カメラ）の一覧表示
2. **デバイス情報取得**: モデル名、シリアル番号などの表示
3. **ファイル一覧**: カメラ内のファイル・フォルダ構造の表示
4. **ファイルダウンロード**: 指定ファイルまたは全ファイルのダウンロード

#### Phase 2（IOKit + 自前実装）
1. USBデバイスへの直接アクセス
2. PTPパケットの組み立て・送信
3. PTPレスポンスの受信・解析
4. 主要PTPオペレーションの実装
   - GetDeviceInfo
   - OpenSession / CloseSession
   - GetObjectHandles
   - GetObjectInfo
   - GetObject

### 非機能要件
- macOS 13以上で動作
- Swift Package Managerでビルド
- テスト対象カメラ: RICOH GR IV

### スコープ外（YAGNI）
- GUI実装
- リモート撮影機能
- ライブビュー機能
- 複数カメラ同時接続
- MTPデバイス対応
- Windows/Linux対応

## 3. 技術スタック

| 項目 | 選定 |
|------|------|
| 言語 | Swift |
| フレームワーク（Phase 1） | ImageCaptureCore |
| フレームワーク（Phase 2） | IOKit |
| ビルドシステム | Swift Package Manager |
| 対応OS | macOS 13+ |

## 4. CLI設計

### 実行ファイル名
`ptp-tool`

### サブコマンド

| コマンド | 説明 |
|----------|------|
| `devices` | 接続中のカメラ一覧を表示 |
| `info` | カメラの詳細情報を表示 |
| `list [--path <path>]` | カメラ内のファイル一覧を表示 |
| `download <file\|--all> [--output <dir>]` | ファイルをダウンロード |

### 使用例

```bash
# カメラ一覧の表示
$ ptp-tool devices
[1] RICOH GR IV (Serial: XXXXXXXX)

# デバイス情報の表示
$ ptp-tool info
Model: RICOH GR IV
Serial: XXXXXXXX
Manufacturer: RICOH IMAGING COMPANY, LTD.
Device Version: 1.00
...

# ファイル一覧の表示
$ ptp-tool list
DCIM/100RICOH/
  R0000001.DNG (25.3 MB)
  R0000001.JPG (8.2 MB)
  R0000002.DNG (25.1 MB)
  ...

# 特定フォルダの一覧
$ ptp-tool list --path DCIM/100RICOH

# 単一ファイルのダウンロード
$ ptp-tool download R0000001.DNG --output ./photos

# 全ファイルのダウンロード
$ ptp-tool download --all --output ./photos
Downloading 42 files...
[====================] 100% R0000042.JPG
Done. 42 files saved to ./photos
```

## 5. アーキテクチャ

### Phase 1 構成

```
ptp-tool (CLI)
    │
    ├── Commands/          # CLIコマンド定義
    │   ├── DevicesCommand.swift
    │   ├── InfoCommand.swift
    │   ├── ListCommand.swift
    │   └── DownloadCommand.swift
    │
    ├── Services/          # ビジネスロジック
    │   └── CameraService.swift    # ImageCaptureCoreのラッパー
    │
    └── main.swift
```

### Phase 2 構成（追加）

```
    ├── PTP/               # PTPプロトコル実装
    │   ├── PTPSession.swift       # セッション管理
    │   ├── PTPPacket.swift        # パケット構造定義
    │   ├── PTPOperations.swift    # オペレーションコード
    │   └── PTPTransport.swift     # USB通信
    │
    └── USB/               # USBアクセス
        └── USBDevice.swift        # IOKitラッパー
```

## 6. PTPプロトコル概要（学習メモ用）

### 通信フロー
```
Host (Mac)                    Device (Camera)
    |                              |
    |-- OpenSession -------------->|
    |<-------------- OK -----------|
    |                              |
    |-- GetDeviceInfo ------------>|
    |<-------- DeviceInfo ---------|
    |                              |
    |-- GetObjectHandles --------->|
    |<------ ObjectHandles --------|
    |                              |
    |-- GetObject (handle) ------->|
    |<-------- Object Data --------|
    |                              |
    |-- CloseSession ------------->|
    |<-------------- OK -----------|
```

### PTPパケット構造
```
+----------------+----------------+----------------+
| Container      | Operation/     | Transaction    |
| Length (4B)    | Response Code  | ID (4B)        |
|                | (2B)           |                |
+----------------+----------------+----------------+
| Parameters (0-5 x 4B)                            |
+--------------------------------------------------+
| Data (variable length, for Data phase)           |
+--------------------------------------------------+
```

### 主要オペレーションコード
| Code   | Name              | 説明 |
|--------|-------------------|------|
| 0x1001 | GetDeviceInfo     | デバイス情報取得 |
| 0x1002 | OpenSession       | セッション開始 |
| 0x1003 | CloseSession      | セッション終了 |
| 0x1004 | GetStorageIDs     | ストレージ一覧 |
| 0x1007 | GetObjectHandles  | オブジェクト一覧 |
| 0x1008 | GetObjectInfo     | オブジェクト情報 |
| 0x1009 | GetObject         | オブジェクト取得 |
| 0x100A | GetThumb          | サムネイル取得 |

## 7. 開発フェーズ

### Phase 1: ImageCaptureCore（基礎理解）
1. プロジェクトセットアップ（SPM、エントリポイント）
2. ImageCaptureCoreでカメラ検出実装
3. デバイス情報取得の実装
4. ファイル一覧取得の実装
5. ファイルダウンロードの実装
6. CLIインターフェース整備

### Phase 2: IOKit + 自前実装（深掘り）
1. IOKitでUSBデバイスアクセス
2. PTPパケット構造体の定義
3. OpenSession / CloseSession実装
4. GetDeviceInfo実装・レスポンス解析
5. GetObjectHandles / GetObjectInfo実装
6. GetObject実装（バイナリデータ転送）
7. Phase 1との比較・学習まとめ

## 8. 参考資料

- [PTP (Picture Transfer Protocol) Specification](https://www.usb.org/document-library/still-image-capture-device-class-ptp)
- [Apple ImageCaptureCore Documentation](https://developer.apple.com/documentation/imagecapturecore)
- [IOKit Fundamentals](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/)
- libgphoto2 ソースコード（参考実装として）
