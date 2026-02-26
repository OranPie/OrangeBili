import Foundation
import CoreGraphics

final class DanmakuParser: NSObject, XMLParserDelegate {
    private var items: [DanmakuItem] = []
    private var currentText = ""
    private var currentP: String?

    func parse(data: Data) -> [DanmakuItem] {
        items = []
        currentText = ""
        currentP = nil
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items.sorted { $0.time < $1.time }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        if elementName == "d" {
            currentText = ""
            currentP = attributeDict["p"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard elementName == "d", let currentP else { return }
        let fields = currentP.split(separator: ",")
        guard fields.count >= 8 else { return }

        let time = Double(fields[0]) ?? 0
        let modeRaw = Int(fields[1]) ?? 1
        let size = Int(fields[2]) ?? 25
        let color = UInt32(fields[3]) ?? 0xFFFFFF
        let timestamp = Int(fields[4]) ?? 0
        let pool = Int(fields[5]) ?? 0
        let userHash = String(fields[6])
        let rowId = String(fields[7])

        let mode: DanmakuMode
        switch modeRaw {
        case 4:
            mode = .bottom
        case 5:
            mode = .top
        case 6:
            mode = .reverse
        case 7:
            mode = .advanced
        default:
            mode = .scroll
        }

        let rawText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else { return }

        var displayText = rawText
        var advancedParams: AdvancedDanmakuParams? = nil

        if mode == .advanced {
            let parsed = Self.parseAdvancedJSON(rawText)
            advancedParams = parsed.params
            displayText = parsed.text ?? rawText
        }

        guard !displayText.isEmpty else { return }

        let item = DanmakuItem(
            id: rowId,
            time: time,
            mode: mode,
            size: size,
            color: color,
            timestamp: timestamp,
            pool: pool,
            userHash: userHash,
            rowId: rowId,
            text: displayText,
            advancedParams: advancedParams
        )
        items.append(item)
    }

    // Mode 7 JSON: [startX, startY, "sOpacity-eOpacity", duration, "text", zRotate, yRotate, endX, endY, moveTime, moveDelay, stroke, "fontFamily", linearSpeedUp]
    static func parseAdvancedJSON(_ raw: String) -> (params: AdvancedDanmakuParams?, text: String?) {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              json.count >= 5 else {
            return (nil, nil)
        }

        let startX = cgFloat(json[0])
        let startY = cgFloat(json[1])

        var startOpacity = 1.0
        var endOpacity = 1.0
        if let opacityStr = json[2] as? String {
            let parts = opacityStr.split(separator: "-")
            if parts.count >= 2 {
                startOpacity = Double(parts[0]) ?? 1.0
                endOpacity = Double(parts[1]) ?? 1.0
            }
        }

        let duration = doubleVal(json[3])
        let text = json[4] as? String

        let zRotate = json.count > 5 ? doubleVal(json[5]) : 0
        let yRotate = json.count > 6 ? doubleVal(json[6]) : 0
        let endX = json.count > 7 ? cgFloat(json[7]) : startX
        let endY = json.count > 8 ? cgFloat(json[8]) : startY
        let moveTime = json.count > 9 ? doubleVal(json[9]) : 0
        let moveDelay = json.count > 10 ? doubleVal(json[10]) : 0

        var stroke = false
        if json.count > 11 {
            if let s = json[11] as? Bool { stroke = s }
            else if let s = json[11] as? Int { stroke = s != 0 }
            else if let s = json[11] as? String { stroke = s == "true" || s == "1" }
        }

        let fontFamily = json.count > 12 ? (json[12] as? String ?? "") : ""

        var linearSpeedUp = false
        if json.count > 13 {
            if let l = json[13] as? Bool { linearSpeedUp = l }
            else if let l = json[13] as? Int { linearSpeedUp = l != 0 }
            else if let l = json[13] as? String { linearSpeedUp = l == "true" || l == "1" }
        }

        let params = AdvancedDanmakuParams(
            startX: startX, startY: startY,
            startOpacity: startOpacity, endOpacity: endOpacity,
            duration: duration,
            zRotate: zRotate, yRotate: yRotate,
            endX: endX, endY: endY,
            moveTime: moveTime, moveDelay: moveDelay,
            stroke: stroke, fontFamily: fontFamily,
            linearSpeedUp: linearSpeedUp
        )
        return (params, text)
    }

    private static func cgFloat(_ val: Any) -> CGFloat {
        if let d = val as? Double { return CGFloat(d) }
        if let i = val as? Int { return CGFloat(i) }
        if let s = val as? String, let d = Double(s) { return CGFloat(d) }
        return 0
    }

    private static func doubleVal(_ val: Any) -> Double {
        if let d = val as? Double { return d }
        if let i = val as? Int { return Double(i) }
        if let s = val as? String, let d = Double(s) { return d }
        return 0
    }
}
