import Foundation
import XCTest
@testable import CSVtoSheets

final class XLSXParserTests: XCTestCase {

    // MARK: - Cell type tests

    func testParsesSharedStringCells() throws {
        let ss = """
            <?xml version="1.0" encoding="UTF-8"?>
            <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <si><t>Name</t></si>
              <si><t>Score</t></si>
              <si><t>Alice</t></si>
            </sst>
            """
        let ws = """
            <?xml version="1.0" encoding="UTF-8"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>
                <row r="1">
                  <c r="A1" t="s"><v>0</v></c>
                  <c r="B1" t="s"><v>1</v></c>
                </row>
                <row r="2">
                  <c r="A2" t="s"><v>2</v></c>
                  <c r="B2"><v>99</v></c>
                </row>
              </sheetData>
            </worksheet>
            """
        let url = try makeXLSXFile(sharedStrings: ss, worksheet: ws)
        let rows = try XLSXParser().parse(url: url)
        XCTAssertEqual(rows, [["Name", "Score"], ["Alice", "99"]])
    }

    func testParsesNumericCells() throws {
        let ws = """
            <?xml version="1.0" encoding="UTF-8"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>
                <row r="1">
                  <c r="A1"><v>1</v></c>
                  <c r="B1"><v>2.5</v></c>
                  <c r="C1"><v>-3</v></c>
                </row>
              </sheetData>
            </worksheet>
            """
        let url = try makeXLSXFile(worksheet: ws)
        let rows = try XLSXParser().parse(url: url)
        XCTAssertEqual(rows, [["1", "2.5", "-3"]])
    }

    func testParsesBooleanCells() throws {
        let ws = """
            <?xml version="1.0" encoding="UTF-8"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>
                <row r="1">
                  <c r="A1" t="b"><v>1</v></c>
                  <c r="B1" t="b"><v>0</v></c>
                </row>
              </sheetData>
            </worksheet>
            """
        let url = try makeXLSXFile(worksheet: ws)
        let rows = try XLSXParser().parse(url: url)
        XCTAssertEqual(rows, [["TRUE", "FALSE"]])
    }

    func testParsesInlineStringCells() throws {
        let ws = """
            <?xml version="1.0" encoding="UTF-8"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>
                <row r="1">
                  <c r="A1" t="inlineStr"><is><t>hello</t></is></c>
                  <c r="B1" t="inlineStr"><is><t>world</t></is></c>
                </row>
              </sheetData>
            </worksheet>
            """
        let url = try makeXLSXFile(worksheet: ws)
        let rows = try XLSXParser().parse(url: url)
        XCTAssertEqual(rows, [["hello", "world"]])
    }

    func testParsesFormulaResultCells() throws {
        let ws = """
            <?xml version="1.0" encoding="UTF-8"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>
                <row r="1">
                  <c r="A1" t="str"><v>CONCAT_RESULT</v></c>
                </row>
              </sheetData>
            </worksheet>
            """
        let url = try makeXLSXFile(worksheet: ws)
        let rows = try XLSXParser().parse(url: url)
        XCTAssertEqual(rows, [["CONCAT_RESULT"]])
    }

    // MARK: - Sparse row tests

    func testHandlesSparseRow() throws {
        // Row has A1 and C1 but no B1; B1 should be filled with an empty string.
        let ss = """
            <?xml version="1.0" encoding="UTF-8"?>
            <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <si><t>alpha</t></si>
              <si><t>gamma</t></si>
            </sst>
            """
        let ws = """
            <?xml version="1.0" encoding="UTF-8"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>
                <row r="1">
                  <c r="A1" t="s"><v>0</v></c>
                  <c r="C1" t="s"><v>1</v></c>
                </row>
              </sheetData>
            </worksheet>
            """
        let url = try makeXLSXFile(sharedStrings: ss, worksheet: ws)
        let rows = try XLSXParser().parse(url: url)
        XCTAssertEqual(rows, [["alpha", "", "gamma"]])
    }

    // MARK: - Missing sharedStrings.xml

    func testHandlesMissingSharedStrings() throws {
        // No sharedStrings.xml in the ZIP — a numeric-only sheet should still parse.
        let ws = """
            <?xml version="1.0" encoding="UTF-8"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>
                <row r="1">
                  <c r="A1"><v>10</v></c>
                  <c r="B1"><v>20</v></c>
                </row>
              </sheetData>
            </worksheet>
            """
        let url = try makeXLSXFile(sharedStrings: nil, worksheet: ws)
        let rows = try XLSXParser().parse(url: url)
        XCTAssertEqual(rows, [["10", "20"]])
    }

    // MARK: - Empty worksheet

    func testThrowsEmptyFileForBlankWorksheet() throws {
        let ws = """
            <?xml version="1.0" encoding="UTF-8"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData/>
            </worksheet>
            """
        let url = try makeXLSXFile(worksheet: ws)
        XCTAssertThrowsError(try XLSXParser().parse(url: url)) { error in
            guard case AppError.emptyFile = error else {
                XCTFail("Expected AppError.emptyFile, got \(error)")
                return
            }
        }
    }

    // MARK: - Rich text

    func testConcatenatesRichTextRuns() throws {
        // Excel rich-text shared strings use multiple <r><t> runs inside a single <si>.
        // The parser should concatenate all runs into one string.
        let ss = """
            <?xml version="1.0" encoding="UTF-8"?>
            <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <si>
                <r><t>foo</t></r>
                <r><t>bar</t></r>
              </si>
            </sst>
            """
        let ws = """
            <?xml version="1.0" encoding="UTF-8"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>
                <row r="1">
                  <c r="A1" t="s"><v>0</v></c>
                </row>
              </sheetData>
            </worksheet>
            """
        let url = try makeXLSXFile(sharedStrings: ss, worksheet: ws)
        let rows = try XLSXParser().parse(url: url)
        XCTAssertEqual(rows, [["foobar"]])
    }

    // MARK: - Invalid file

    func testThrowsParsingErrorForInvalidFile() throws {
        // A file that is not a ZIP archive should cause unzip to fail with a
        // non-zero exit code, which the parser converts to AppError.parsing.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".xlsx")
        try "this is not a zip file".write(to: url, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try XLSXParser().parse(url: url)) { error in
            guard case AppError.parsing = error else {
                XCTFail("Expected AppError.parsing, got \(error)")
                return
            }
        }
    }

    // MARK: - Fixture builder

    /// Assembles a minimal `.xlsx` ZIP from raw XML strings.
    ///
    /// The ZIP is built using `/usr/bin/zip` so the entry paths exactly match
    /// what `unzip -p` expects (`xl/worksheets/sheet1.xml`, `xl/sharedStrings.xml`).
    private func makeXLSXFile(sharedStrings: String? = nil, worksheet: String) throws -> URL {
        let sourceDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let xlDir = sourceDir.appendingPathComponent("xl")
        let sheetsDir = xlDir.appendingPathComponent("worksheets")
        try FileManager.default.createDirectory(at: sheetsDir, withIntermediateDirectories: true)

        try worksheet.write(
            to: sheetsDir.appendingPathComponent("sheet1.xml"),
            atomically: true, encoding: .utf8
        )
        if let ss = sharedStrings {
            try ss.write(
                to: xlDir.appendingPathComponent("sharedStrings.xml"),
                atomically: true, encoding: .utf8
            )
        }

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".xlsx")

        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        // Zip only the `xl` subtree so entries are stored as `xl/...` (no `./` prefix).
        zip.arguments = ["-r", dest.path, "xl"]
        zip.currentDirectoryURL = sourceDir

        let errorPipe = Pipe()
        zip.standardError = errorPipe

        try zip.run()
        zip.waitUntilExit()

        try? FileManager.default.removeItem(at: sourceDir)
        addTeardownBlock { try? FileManager.default.removeItem(at: dest) }

        if zip.terminationStatus != 0 {
            let msg = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw XCTSkip("zip failed in test fixture: \(msg)")
        }
        return dest
    }
}
