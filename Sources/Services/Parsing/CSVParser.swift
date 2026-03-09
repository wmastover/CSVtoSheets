import Foundation

struct CSVParser {
    func parse(data: Data, delimiter: Character = ",") throws -> [[String]] {
        guard !data.isEmpty else { throw AppError.emptyFile }
        guard let text = String(data: data, encoding: .utf8) else {
            throw AppError.unsupportedEncoding
        }
        return try parse(text: text, delimiter: delimiter)
    }

    func parse(text: String, delimiter: Character = ",") throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.makeIterator()

        while let char = iterator.next() {
            if inQuotes {
                if char == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            if next == delimiter {
                                row.append(field)
                                field = ""
                            } else if next == "\n" {
                                row.append(field)
                                rows.append(row)
                                row = []
                                field = ""
                            } else if next == "\r" {
                                row.append(field)
                                rows.append(row)
                                row = []
                                field = ""
                                _ = iterator.next()
                            } else {
                                field.append(next)
                            }
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"":
                    if field.isEmpty {
                        inQuotes = true
                    } else {
                        throw AppError.parsing("Unexpected quote in unquoted field.")
                    }
                case delimiter:
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                case "\r":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                    _ = iterator.next()
                default:
                    field.append(char)
                }
            }
        }

        if inQuotes {
            throw AppError.parsing("Unclosed quoted field.")
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        if rows.isEmpty {
            throw AppError.emptyFile
        }
        return rows
    }
}
