import Foundation

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
        default:
            mode = .scroll
        }

        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

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
            text: text
        )
        items.append(item)
    }
}

