import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ZipDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    static var writableContentTypes: [UTType] { [.zip] }
    let data: Data

    init(project: GeneratedProject) throws { data = try ZipArchive.make(files: project.files) }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum ZipArchive {
    private struct Entry { let name: Data; let crc: UInt32; let size: UInt32; let offset: UInt32 }

    static func make(files: [ProjectFile]) throws -> Data {
        var data = Data()
        var entries: [Entry] = []
        for file in files {
            guard let name = file.path.data(using: .utf8),
                  let content = file.content.data(using: .utf8) else { throw ProjectError.invalidOutput }
            guard data.count <= Int(UInt32.max), content.count <= Int(UInt32.max),
                  name.count <= Int(UInt16.max) else { throw ProjectError.tooLarge }
            let crc = crc32(content), offset = UInt32(data.count)
            let size = UInt32(content.count), nameLen = UInt16(name.count)
            data.appendLE(UInt32(0x04034b50)); data.appendLE(UInt16(20))
            data.appendLE(UInt16(0x0800)); data.appendLE(UInt16(0))
            data.appendLE(UInt16(0)); data.appendLE(UInt16(0))
            data.appendLE(crc); data.appendLE(size); data.appendLE(size)
            data.appendLE(nameLen); data.appendLE(UInt16(0))
            data.append(name); data.append(content)
            entries.append(Entry(name: name, crc: crc, size: size, offset: offset))
        }
        guard data.count <= Int(UInt32.max), entries.count <= Int(UInt16.max) else { throw ProjectError.tooLarge }
        let centralOffset = UInt32(data.count)
        for e in entries {
            data.appendLE(UInt32(0x02014b50)); data.appendLE(UInt16(20)); data.appendLE(UInt16(20))
            data.appendLE(UInt16(0x0800)); data.appendLE(UInt16(0))
            data.appendLE(UInt16(0)); data.appendLE(UInt16(0))
            data.appendLE(e.crc); data.appendLE(e.size); data.appendLE(e.size)
            data.appendLE(UInt16(e.name.count)); data.appendLE(UInt16(0))
            data.appendLE(UInt16(0)); data.appendLE(UInt16(0)); data.appendLE(UInt16(0))
            data.appendLE(UInt32(0)); data.appendLE(e.offset); data.append(e.name)
        }
        let centralSize = UInt32(data.count) - centralOffset, count = UInt16(entries.count)
        data.appendLE(UInt32(0x06054b50)); data.appendLE(UInt16(0)); data.appendLE(UInt16(0))
        data.appendLE(count); data.appendLE(count); data.appendLE(centralSize)
        data.appendLE(centralOffset); data.appendLE(UInt16(0))
        return data
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask: UInt32 = (crc & 1) == 1 ? 0xEDB8_8320 : 0
                crc = (crc >> 1) ^ mask
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
