import Foundation

/// Manual protobuf parser for Bilibili seg.so binary danmaku response.
/// No external dependencies — reads wire format directly.
///
/// Wire format reference:
/// ```
/// message DmSegMobileReply { repeated DanmakuElem elems = 1; }
/// message DanmakuElem {
///     int64  id       = 1;  // varint
///     int32  progress = 2;  // varint (ms)
///     int32  mode     = 3;  // varint
///     int32  fontsize = 4;  // varint
///     uint32 color    = 5;  // varint
///     string midHash  = 6;  // length-delimited
///     string content  = 7;  // length-delimited
///     int64  ctime    = 8;  // varint
/// }
/// ```
public final class ProtobufDanmakuParser {

    public init() {}

    public func parse(data: Data) -> [DanmakuItem] {
        data.withUnsafeBytes { rawBuffer -> [DanmakuItem] in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return []
            }
            return parseTop(bytes: baseAddress, count: rawBuffer.count)
        }
    }

    // MARK: - Top-level parse (DmSegMobileReply)

    private func parseTop(bytes: UnsafePointer<UInt8>, count: Int) -> [DanmakuItem] {
        var items: [DanmakuItem] = []
        var offset = 0

        while offset < count {
            guard let (fieldNumber, wireType, newOffset) = readTag(bytes: bytes, offset: offset, count: count) else { break }
            offset = newOffset

            if fieldNumber == 1 && wireType == 2 {
                guard let (length, dataOffset) = readVarint(bytes: bytes, offset: offset, count: count) else { break }
                offset = dataOffset
                let end = offset + Int(length)
                guard end <= count else { break }
                if let item = parseElem(bytes: bytes, offset: offset, end: end) {
                    items.append(item)
                }
                offset = end
            } else {
                guard let newOff = skipField(wireType: wireType, bytes: bytes, offset: offset, count: count) else { break }
                offset = newOff
            }
        }

        return items
    }

    // MARK: - Parse single DanmakuElem

    private func parseElem(bytes: UnsafePointer<UInt8>, offset: Int, end: Int) -> DanmakuItem? {
        var off = offset
        var id: Int64 = 0
        var progress: Int32 = 0
        var modeRaw: Int32 = 1
        var fontsize: Int32 = 25
        var color: UInt32 = 0xFFFFFF
        var midHash = ""
        var content = ""
        var ctime: Int64 = 0

        while off < end {
            guard let (fieldNumber, wireType, tagEnd) = readTag(bytes: bytes, offset: off, count: end) else { break }
            off = tagEnd

            switch (fieldNumber, wireType) {
            case (1, 0):
                guard let (val, newOff) = readVarint(bytes: bytes, offset: off, count: end) else { return nil }
                id = Int64(bitPattern: val)
                off = newOff
            case (2, 0):
                guard let (val, newOff) = readVarint(bytes: bytes, offset: off, count: end) else { return nil }
                progress = Int32(truncatingIfNeeded: val)
                off = newOff
            case (3, 0):
                guard let (val, newOff) = readVarint(bytes: bytes, offset: off, count: end) else { return nil }
                modeRaw = Int32(truncatingIfNeeded: val)
                off = newOff
            case (4, 0):
                guard let (val, newOff) = readVarint(bytes: bytes, offset: off, count: end) else { return nil }
                fontsize = Int32(truncatingIfNeeded: val)
                off = newOff
            case (5, 0):
                guard let (val, newOff) = readVarint(bytes: bytes, offset: off, count: end) else { return nil }
                color = UInt32(truncatingIfNeeded: val)
                off = newOff
            case (6, 2):
                guard let (str, newOff) = readString(bytes: bytes, offset: off, count: end) else { return nil }
                midHash = str
                off = newOff
            case (7, 2):
                guard let (str, newOff) = readString(bytes: bytes, offset: off, count: end) else { return nil }
                content = str
                off = newOff
            case (8, 0):
                guard let (val, newOff) = readVarint(bytes: bytes, offset: off, count: end) else { return nil }
                ctime = Int64(bitPattern: val)
                off = newOff
            default:
                guard let newOff = skipField(wireType: wireType, bytes: bytes, offset: off, count: end) else { return nil }
                off = newOff
            }
        }

        guard !content.isEmpty else { return nil }

        let mode: DanmakuMode
        switch modeRaw {
        case 4: mode = .bottom
        case 5: mode = .top
        case 6: mode = .reverse
        case 7: mode = .advanced
        default: mode = .scroll
        }

        var displayText = content
        var advancedParams: AdvancedDanmakuParams? = nil
        if mode == .advanced {
            let parsed = DanmakuParser.parseAdvancedJSON(content)
            advancedParams = parsed.params
            displayText = parsed.text ?? content
        }
        guard !displayText.isEmpty else { return nil }

        let time = Double(progress) / 1000.0
        let idStr = "\(id)"

        return DanmakuItem(
            id: idStr,
            time: time,
            mode: mode,
            size: Int(fontsize),
            color: color,
            timestamp: Int(clamping: ctime),
            pool: 0,
            userHash: midHash,
            rowId: idStr,
            text: displayText,
            advancedParams: advancedParams
        )
    }

    // MARK: - Protobuf Wire Primitives

    private func readTag(bytes: UnsafePointer<UInt8>, offset: Int, count: Int) -> (fieldNumber: Int, wireType: Int, newOffset: Int)? {
        guard let (val, newOffset) = readVarint(bytes: bytes, offset: offset, count: count) else { return nil }
        let wireType = Int(val & 0x07)
        let fieldNumber = Int(val >> 3)
        return (fieldNumber, wireType, newOffset)
    }

    private func readVarint(bytes: UnsafePointer<UInt8>, offset: Int, count: Int) -> (UInt64, Int)? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        var off = offset
        while off < count {
            let byte = bytes[off]
            off += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return (result, off)
            }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }

    private func readString(bytes: UnsafePointer<UInt8>, offset: Int, count: Int) -> (String, Int)? {
        guard let (length, dataOffset) = readVarint(bytes: bytes, offset: offset, count: count) else { return nil }
        let len = Int(length)
        let end = dataOffset + len
        guard end <= count else { return nil }
        let str = String(bytes: UnsafeBufferPointer(start: bytes + dataOffset, count: len), encoding: .utf8) ?? ""
        return (str, end)
    }

    private func skipField(wireType: Int, bytes: UnsafePointer<UInt8>, offset: Int, count: Int) -> Int? {
        switch wireType {
        case 0: // varint
            guard let (_, newOff) = readVarint(bytes: bytes, offset: offset, count: count) else { return nil }
            return newOff
        case 1: // 64-bit
            let newOff = offset + 8
            return newOff <= count ? newOff : nil
        case 2: // length-delimited
            guard let (length, dataOffset) = readVarint(bytes: bytes, offset: offset, count: count) else { return nil }
            let end = dataOffset + Int(length)
            return end <= count ? end : nil
        case 5: // 32-bit
            let newOff = offset + 4
            return newOff <= count ? newOff : nil
        default:
            return nil
        }
    }
}
