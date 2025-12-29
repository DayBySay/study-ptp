import ArgumentParser
import Foundation
import PTPToolCore

struct InfoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show detailed camera information"
    )

    @MainActor
    func run() async throws {
        print("Connecting to camera...")

        let service = CameraService()
        let cameras = await service.getCameraDetails()

        if cameras.isEmpty {
            print("No cameras found.")
            return
        }

        for camera in cameras {
            print("\n=== \(camera.name) ===\n")
            for (key, value) in camera.details.sorted(by: { $0.key < $1.key }) {
                print("  \(key): \(value)")
            }
        }
    }
}
