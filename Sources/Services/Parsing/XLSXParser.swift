import Foundation

protocol XLSXParsing {
    func parse(url: URL) throws -> [[String]]
}

struct XLSXParser: XLSXParsing {
    func parse(url: URL) throws -> [[String]] {
        let path = url.path
        let sharedStrings = (try? extractXMLFromZIP(path: path, entry: "xl/sharedStrings.xml")) ?? Data()
        let worksheetXML = try extractXMLFromZIP(path: path, entry: "xl/worksheets/sheet1.xml")

        let strings = try parseSharedStrings(data: sharedStrings)
        let rows = try parseWorksheet(data: worksheetXML, sharedStrings: strings)

        guard !rows.isEmpty else { throw AppError.emptyFile }
        return rows
    }

    // MARK: - ZIP Extraction

    private func extractXMLFromZIP(path: String, entry: String) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", path, entry]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw AppError.parsing("Failed to run unzip: \(error.localizedDescription)")
        }

        // Read stdout BEFORE waitUntilExit to avoid the pipe-buffer deadlock:
        // if the child fills the pipe buffer it blocks waiting for a reader,
        // while waitUntilExit blocks waiting for the child — both stall forever.
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "unknown error"
            throw AppError.parsing("Could not read '\(entry)' from XLSX: \(errMsg.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        guard !data.isEmpty else {
            throw AppError.parsing("Entry '\(entry)' is empty in the XLSX file.")
        }
        return data
    }

    // MARK: - Shared Strings

    private func parseSharedStrings(data: Data) throws -> [String] {
        guard !data.isEmpty else { return [] }
        let delegate = SharedStringsDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        if let error = delegate.parseError {
            throw AppError.parsing("Shared strings XML error: \(error.localizedDescription)")
        }
        return delegate.strings
    }

    // MARK: - Worksheet

    private func parseWorksheet(data: Data, sharedStrings: [String]) throws -> [[String]] {
        let delegate = WorksheetDelegate(sharedStrings: sharedStrings)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        if let error = delegate.parseError {
            throw AppError.parsing("Worksheet XML error: \(error.localizedDescription)")
        }
        return delegate.rows
    }
}

// MARK: - Column Letter to Index

/// Converts an Excel column reference like "A" → 0, "B" → 1, "Z" → 25, "AA" → 26.
private func columnIndex(from ref: String) -> Int {
    var index = 0
    for char in ref.uppercased() {
        guard let ascii = char.asciiValue, ascii >= 65, ascii <= 90 else { break }
        index = index * 26 + Int(ascii - 64)
    }
    return index - 1
}

/// Splits a cell reference like "AB12" into column letters "AB" and row number 12.
private func splitCellRef(_ ref: String) -> (col: String, row: Int)? {
    var col = ""
    var rowStr = ""
    for char in ref {
        if char.isLetter {
            col.append(char)
        } else {
            rowStr.append(char)
        }
    }
    guard let row = Int(rowStr) else { return nil }
    return (col, row)
}

// MARK: - SharedStringsDelegate

private final class SharedStringsDelegate: NSObject, XMLParserDelegate {
    var strings: [String] = []
    var parseError: Error?

    // Tracks whether we are inside an <si> element collecting text
    private var currentText = ""
    private var inSI = false
    private var inT = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        switch elementName {
        case "si":
            inSI = true
            currentText = ""
        case "t" where inSI:
            inT = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inT {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "si":
            strings.append(currentText)
            inSI = false
            inT = false
            currentText = ""
        case "t":
            inT = false
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
}

// MARK: - WorksheetDelegate

private final class WorksheetDelegate: NSObject, XMLParserDelegate {
    var rows: [[String]] = []
    var parseError: Error?

    private let sharedStrings: [String]

    // Current row state
    private var currentRowIndex: Int = -1
    private var currentRowCells: [(col: Int, value: String)] = []

    // Current cell state
    private var currentCellRef: String = ""
    private var currentCellType: String = ""
    private var currentValue: String = ""
    private var currentInlineText: String = ""

    private var inV = false
    private var inT = false
    private var inIS = false
    private var inCell = false
    private var inSheetData = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        switch elementName {
        case "sheetData":
            inSheetData = true
        case "row" where inSheetData:
            currentRowCells = []
            if let rStr = attributes["r"], let r = Int(rStr) {
                currentRowIndex = r - 1  // convert to 0-based
            } else {
                currentRowIndex = (rows.count)
            }
        case "c" where inSheetData:
            inCell = true
            currentCellRef = attributes["r"] ?? ""
            currentCellType = attributes["t"] ?? ""
            currentValue = ""
            currentInlineText = ""
        case "v" where inCell:
            inV = true
        case "is" where inCell:
            inIS = true
        case "t" where inIS:
            inT = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inV {
            currentValue += string
        } else if inT && inIS {
            currentInlineText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "c" where inCell:
            let resolvedValue = resolveCell()
            if let (colStr, _) = splitCellRef(currentCellRef) {
                let colIdx = columnIndex(from: colStr)
                currentRowCells.append((col: colIdx, value: resolvedValue))
            }
            inCell = false
            inV = false
            inIS = false
            inT = false
        case "v":
            inV = false
        case "is":
            inIS = false
        case "t":
            inT = false
        case "row" where inSheetData:
            flushRow()
        case "sheetData":
            inSheetData = false
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    private func resolveCell() -> String {
        switch currentCellType {
        case "s":
            // Shared string index
            if let idx = Int(currentValue.trimmingCharacters(in: .whitespaces)),
               idx >= 0, idx < sharedStrings.count {
                return sharedStrings[idx]
            }
            return ""
        case "inlineStr":
            return currentInlineText
        case "b":
            return currentValue == "1" ? "TRUE" : "FALSE"
        case "str", "e", "":
            return currentValue
        default:
            return currentValue
        }
    }

    private func flushRow() {
        guard !currentRowCells.isEmpty else {
            // Preserve empty rows up to the current row index so the grid is consistent
            while rows.count <= currentRowIndex {
                rows.append([])
            }
            return
        }

        let maxCol = (currentRowCells.map(\.col).max() ?? 0) + 1

        // Fill any gap rows above with empty arrays
        while rows.count < currentRowIndex {
            rows.append([])
        }

        var row = Array(repeating: "", count: maxCol)
        for cell in currentRowCells {
            if cell.col < maxCol {
                row[cell.col] = cell.value
            }
        }
        rows.append(row)
    }
}
