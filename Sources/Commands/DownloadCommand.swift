import ArgumentParser
import Foundation

struct DownloadCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download files from the camera"
    )

    @Argument(help: "File name to download (or use --all for all files)")
    var fileName: String?

    @Flag(name: .shortAndLong, help: "Download all files")
    var all: Bool = false

    @Option(name: .shortAndLong, help: "Output directory")
    var output: String = "."

    @MainActor
    func run() async throws {
        guard all || fileName != nil else {
            print("Error: Specify a file name or use --all to download all files.")
            return
        }

        let outputURL = URL(fileURLWithPath: output, isDirectory: true)

        // 出力ディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: output) {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        }

        let service = CameraService()

        if all {
            print("Connecting to camera...")
            let count = try await service.downloadAllFiles(to: outputURL) { name, current, total in
                let progress = String(repeating: "=", count: Int(Double(current) / Double(total) * 20))
                let remaining = String(repeating: " ", count: 20 - progress.count)
                print("\r[\(progress)\(remaining)] \(current)/\(total) \(name)", terminator: "")
                fflush(stdout)
            }
            print("\n\nDone. \(count) files saved to \(output)")
        } else if let name = fileName {
            print("Downloading \(name)...")
            let savedURL = try await service.downloadFile(named: name, to: outputURL)
            print("Saved to: \(savedURL.path)")
        }
    }
}
