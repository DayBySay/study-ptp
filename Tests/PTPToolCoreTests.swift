import Testing
@testable import PTPToolCore

@Suite("CameraInfo Tests")
struct CameraInfoTests {
    @Test("CameraInfo initialization")
    func testInit() {
        let info = CameraInfo(
            name: "RICOH GR IV",
            serialNumber: "12345678",
            deviceType: "PTP Camera"
        )

        #expect(info.name == "RICOH GR IV")
        #expect(info.serialNumber == "12345678")
        #expect(info.deviceType == "PTP Camera")
    }

    @Test("CameraInfo with nil serial number")
    func testNilSerialNumber() {
        let info = CameraInfo(
            name: "Unknown Camera",
            serialNumber: nil,
            deviceType: "PTP Camera"
        )

        #expect(info.name == "Unknown Camera")
        #expect(info.serialNumber == nil)
    }

    @Test("CameraInfo equality")
    func testEquality() {
        let info1 = CameraInfo(name: "Camera", serialNumber: "123", deviceType: "PTP")
        let info2 = CameraInfo(name: "Camera", serialNumber: "123", deviceType: "PTP")
        let info3 = CameraInfo(name: "Other", serialNumber: "456", deviceType: "PTP")

        #expect(info1 == info2)
        #expect(info1 != info3)
    }
}

@Suite("FileInfo Tests")
struct FileInfoTests {
    @Test("FileInfo initialization for file")
    func testFileInit() {
        let info = FileInfo(
            name: "R0000001.JPG",
            size: 12_345_678,
            isDirectory: false,
            path: "DCIM/100RICOH/R0000001.JPG"
        )

        #expect(info.name == "R0000001.JPG")
        #expect(info.size == 12_345_678)
        #expect(info.isDirectory == false)
        #expect(info.path == "DCIM/100RICOH/R0000001.JPG")
    }

    @Test("FileInfo initialization for directory")
    func testDirectoryInit() {
        let info = FileInfo(
            name: "DCIM",
            size: 0,
            isDirectory: true,
            path: "DCIM"
        )

        #expect(info.name == "DCIM")
        #expect(info.isDirectory == true)
    }

    @Test("FileInfo equality")
    func testEquality() {
        let info1 = FileInfo(name: "test.jpg", size: 100, isDirectory: false, path: "test.jpg")
        let info2 = FileInfo(name: "test.jpg", size: 100, isDirectory: false, path: "test.jpg")
        let info3 = FileInfo(name: "other.jpg", size: 200, isDirectory: false, path: "other.jpg")

        #expect(info1 == info2)
        #expect(info1 != info3)
    }
}

@Suite("CameraError Tests")
struct CameraErrorTests {
    @Test("noCameraFound error description")
    func testNoCameraFoundError() {
        let error = CameraError.noCameraFound

        #expect(error.errorDescription == "No camera found. Please connect a camera.")
    }

    @Test("fileNotFound error description")
    func testFileNotFoundError() {
        let error = CameraError.fileNotFound("test.jpg")

        #expect(error.errorDescription == "File not found: test.jpg")
    }

    @Test("downloadFailed error description")
    func testDownloadFailedError() {
        let error = CameraError.downloadFailed("Connection lost")

        #expect(error.errorDescription == "Download failed: Connection lost")
    }

    @Test("CameraError equality")
    func testEquality() {
        #expect(CameraError.noCameraFound == CameraError.noCameraFound)
        #expect(CameraError.fileNotFound("a.jpg") == CameraError.fileNotFound("a.jpg"))
        #expect(CameraError.fileNotFound("a.jpg") != CameraError.fileNotFound("b.jpg"))
    }
}
