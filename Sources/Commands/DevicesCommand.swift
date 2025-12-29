import ArgumentParser
import Foundation

struct DevicesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "devices",
        abstract: "List connected PTP cameras"
    )

    @Option(name: .shortAndLong, help: "Discovery timeout in seconds")
    var timeout: Double = 3.0

    @MainActor
    func run() async throws {
        print("Searching for cameras...")

        let service = CameraService()
        let cameras = await service.discoverCameras(timeout: timeout)

        if cameras.isEmpty {
            print("No cameras found.")
            print("Make sure your camera is:")
            print("  - Connected via USB")
            print("  - Turned on")
            print("  - Set to PTP/PC connection mode")
            return
        }

        print("\nFound \(cameras.count) camera(s):\n")
        for (index, camera) in cameras.enumerated() {
            print("[\(index + 1)] \(camera.name)", terminator: "")
            if let serial = camera.serialNumber {
                print(" (Serial: \(serial))")
            } else {
                print("")
            }
        }
    }
}
