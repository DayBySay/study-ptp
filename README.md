# ptp-tool

PTP（Picture Transfer Protocol）を学習するためのCLIツール。

## 概要

macOSのImageCaptureCoreフレームワークを使用して、PTPデバイス（デジタルカメラ）と通信するCLIツールです。

## 動作確認済み環境

- macOS 13+
- Swift 6.1
- RICOH GR IV

## インストール

```bash
git clone https://github.com/DayBySay/study-ptp.git
cd study-ptp
swift build
```

## 使い方

### カメラの検出

```bash
swift run ptp-tool devices
```

```
Searching for cameras...

Found 1 camera(s):

[1] RICOH GR IV (Serial: XXXXXXXX)
```

### カメラ情報の表示

```bash
swift run ptp-tool info
```

```
Connecting to camera...

=== RICOH GR IV ===

  Model: RICOH GR IV
  Name: RICOH GR IV
  Serial Number: XXXXXXXX
  UUID: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

### ファイル一覧の表示

```bash
swift run ptp-tool list
```

```
Connecting to camera...

Found 1394 item(s):

  R0000531.JPG (11.7 MB)
  R0000233.JPG (11.7 MB)
  R0000233.DNG (32.7 MB)
  ...
```

### ファイルのダウンロード

```bash
# 単一ファイル
swift run ptp-tool download R0000531.JPG --output ./photos

# 全ファイル
swift run ptp-tool download --all --output ./photos
```

## プロジェクト構成

```
Sources/
├── main.swift                 # エントリポイント
├── Commands/
│   ├── DevicesCommand.swift   # devices サブコマンド
│   ├── InfoCommand.swift      # info サブコマンド
│   ├── ListCommand.swift      # list サブコマンド
│   └── DownloadCommand.swift  # download サブコマンド
└── Services/
    └── CameraService.swift    # ImageCaptureCoreラッパー
```

## PTPプロトコルについて

PTP (Picture Transfer Protocol) は、デジタルカメラとコンピュータ間でファイルを転送するためのUSBプロトコルです。

### 主要なオペレーション

| コード | 名前 | 説明 |
|--------|------|------|
| 0x1001 | GetDeviceInfo | デバイス情報取得 |
| 0x1002 | OpenSession | セッション開始 |
| 0x1003 | CloseSession | セッション終了 |
| 0x1007 | GetObjectHandles | オブジェクト一覧取得 |
| 0x1008 | GetObjectInfo | オブジェクト情報取得 |
| 0x1009 | GetObject | オブジェクト（ファイル）取得 |

### 通信フロー

```
Host (Mac)                    Device (Camera)
    |                              |
    |-- OpenSession -------------->|
    |<-------------- OK -----------|
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

## 参考資料

- [PTP Specification (USB-IF)](https://www.usb.org/document-library/still-image-capture-device-class-ptp)
- [Apple ImageCaptureCore Documentation](https://developer.apple.com/documentation/imagecapturecore)

## ライセンス

MIT
