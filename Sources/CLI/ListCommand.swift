import ArgumentParser
import Foundation
import PTPToolCore

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List files on the camera"
    )

    @MainActor
    func run() async throws {
        print("Connecting to camera...")

        let service = CameraService()
        let files = await service.listFiles()

        if files.isEmpty {
            print("No files found.")
            return
        }

        print("\nFound \(files.count) item(s):\n")

        for file in files {
            if file.isDirectory {
                print("  \(file.name)/")
            } else {
                let sizeStr = formatFileSize(file.size)
                print("  \(file.name) (\(sizeStr))")
            }
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
