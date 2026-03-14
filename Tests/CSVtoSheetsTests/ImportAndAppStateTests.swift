import Foundation
import XCTest
@testable import CSVtoSheets

final class ImportAndAppStateTests: XCTestCase {
    func testRunImportPassesRowAndColumnMinimumsToCreateSpreadsheet() async throws {
        let auth = MockAuthProvider()
        let parser = MockParser(rows: [["a"], ["1", "2", "3"]])
        let sheets = MockSheetsService()
        let coordinator = ImportCoordinator(authManager: auth, csvParser: parser, sheetsService: sheets, openURL: { _ in })
        let request = ImportRequest(sourceURL: try makeTempCSV(), delimiterOverride: nil, customTitle: "MyTitle")

        _ = try await coordinator.runImport(request: request, autoOpenBrowser: false) { _, _ in }

        XCTAssertEqual(sheets.lastCreateMinimumRows, 2)
        XCTAssertEqual(sheets.lastCreateMinimumColumns, 3)
    }

    func testRunImportOpensBrowserOnAppendFailureWhenEnabled() async throws {
        let auth = MockAuthProvider()
        let parser = MockParser(rows: [["a"], ["b"]])
        let sheets = MockSheetsService()
        sheets.appendError = AppError.partialUpload(uploadedRows: 1, message: "boom")
        var openedURLs: [URL] = []
        let coordinator = ImportCoordinator(
            authManager: auth,
            csvParser: parser,
            sheetsService: sheets,
            openURL: { openedURLs.append($0) }
        )
        let request = ImportRequest(sourceURL: try makeTempCSV(), delimiterOverride: nil, customTitle: nil)

        do {
            _ = try await coordinator.runImport(request: request, autoOpenBrowser: true) { _, _ in }
            XCTFail("Expected append error")
        } catch {
            XCTAssertEqual(openedURLs.count, 1)
            XCTAssertEqual(openedURLs.first?.absoluteString, "https://docs.google.com/spreadsheets/d/mock/edit")
        }
    }

    func testRunImportDoesNotOpenBrowserOnAppendFailureWhenDisabled() async throws {
        let auth = MockAuthProvider()
        let parser = MockParser(rows: [["a"], ["b"]])
        let sheets = MockSheetsService()
        sheets.appendError = AppError.partialUpload(uploadedRows: 1, message: "boom")
        var openedURLs: [URL] = []
        let coordinator = ImportCoordinator(
            authManager: auth,
            csvParser: parser,
            sheetsService: sheets,
            openURL: { openedURLs.append($0) }
        )
        let request = ImportRequest(sourceURL: try makeTempCSV(), delimiterOverride: nil, customTitle: nil)

        do {
            _ = try await coordinator.runImport(request: request, autoOpenBrowser: false) { _, _ in }
            XCTFail("Expected append error")
        } catch {
            XCTAssertEqual(openedURLs.count, 0)
        }
    }

    func testRunImportUploadProgressDoesNotExceed095() async throws {
        let auth = MockAuthProvider()
        let parser = MockParser(rows: [["a"], ["b"]])
        let sheets = MockSheetsService()
        sheets.uploadCallbacks = [1, 2]
        let coordinator = ImportCoordinator(authManager: auth, csvParser: parser, sheetsService: sheets, openURL: { _ in })
        let request = ImportRequest(sourceURL: try makeTempCSV(), delimiterOverride: nil, customTitle: nil)
        var progressValues: [Double] = []

        _ = try await coordinator.runImport(request: request, autoOpenBrowser: false) { value, _ in
            progressValues.append(value)
        }
        try? await Task.sleep(nanoseconds: 20_000_000)

        let uploadValues = progressValues.filter { $0 >= 0.35 && $0 < 1.0 }
        XCTAssertTrue(uploadValues.allSatisfy { $0 <= 0.95 })
        XCTAssertTrue(uploadValues.contains(0.95))
    }

    func testRunImportReturnsRowsUploadedFromParser() async throws {
        let auth = MockAuthProvider()
        let parser = MockParser(rows: [["a"], ["b"], ["c"]])
        let sheets = MockSheetsService()
        let coordinator = ImportCoordinator(authManager: auth, csvParser: parser, sheetsService: sheets, openURL: { _ in })
        let request = ImportRequest(sourceURL: try makeTempCSV(), delimiterOverride: nil, customTitle: nil)

        let result = try await coordinator.runImport(request: request, autoOpenBrowser: false) { _, _ in }

        XCTAssertEqual(result.rowsUploaded, 3)
    }

    @MainActor
    func testDocumentOpenHandlerAcceptsCSVAndXLSX() {
        let state = makeAppStateWithMockCoordinator()
        let settings = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let handler = DocumentOpenHandler()

        handler.handle(paths: ["/tmp/data.csv"], appState: state, settingsStore: settings)
        XCTAssertEqual(state.lastOpenedFile?.pathExtension, "csv")

        handler.handle(paths: ["/tmp/report.xlsx"], appState: state, settingsStore: settings)
        XCTAssertEqual(state.lastOpenedFile?.pathExtension, "xlsx")
    }

    @MainActor
    func testDocumentOpenHandlerRejectsOtherExtensions() {
        let state = makeAppStateWithMockCoordinator()
        let settings = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let handler = DocumentOpenHandler()

        handler.handle(
            paths: ["/tmp/doc.txt", "/tmp/report.pdf", "/tmp/sheet.numbers"],
            appState: state,
            settingsStore: settings
        )
        XCTAssertNil(state.lastOpenedFile, "Non-CSV/XLSX files should be silently ignored")
    }

    @MainActor
    func testImportCSVTerminatesOnlyOnSuccess() async throws {
        let coordinator = MockImportCoordinator()
        coordinator.result = .success(
            ImportResult(
                spreadsheetID: "id",
                spreadsheetURL: URL(string: "https://example.com")!,
                rowsUploaded: 2,
                duration: 0.1
            )
        )
        var terminateCalls = 0
        let state = AppState(
            importCoordinator: coordinator,
            terminateApp: { terminateCalls += 1 },
            shouldPostNotifications: { true },
            terminationDelayNanoseconds: 0,
            notificationPoster: { _, _ in }
        )
        let settings = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)

        await state.importCSV(try makeTempCSV(), settings: settings, terminateWhenFinished: true)
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(terminateCalls, 1)
    }

    func testRunImportUsesXLSXParserForXLSXFile() async throws {
        let auth = MockAuthProvider()
        let csvParser = MockParser(rows: [])
        let xlsxParser = MockXLSXParser(rows: [["header"], ["value"]])
        let sheets = MockSheetsService()
        let coordinator = ImportCoordinator(
            authManager: auth,
            csvParser: csvParser,
            xlsxParser: xlsxParser,
            sheetsService: sheets,
            openURL: { _ in }
        )
        let xlsxURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".xlsx")
        // The coordinator only cares about the extension; the file doesn't need to exist
        // because MockXLSXParser doesn't actually read it.
        let request = ImportRequest(sourceURL: xlsxURL, delimiterOverride: nil, customTitle: nil)

        _ = try await coordinator.runImport(request: request, autoOpenBrowser: false) { _, _ in }

        XCTAssertEqual(xlsxParser.parsedURL, xlsxURL)
        XCTAssertNil(csvParser.lastParsedData, "CSV parser should not be called for an .xlsx file")
    }

    func testRunImportUsesCSVParserForCSVFile() async throws {
        let auth = MockAuthProvider()
        let csvParser = MockParser(rows: [["header"], ["value"]])
        let xlsxParser = MockXLSXParser(rows: [])
        let sheets = MockSheetsService()
        let coordinator = ImportCoordinator(
            authManager: auth,
            csvParser: csvParser,
            xlsxParser: xlsxParser,
            sheetsService: sheets,
            openURL: { _ in }
        )
        let request = ImportRequest(sourceURL: try makeTempCSV(), delimiterOverride: nil, customTitle: nil)

        _ = try await coordinator.runImport(request: request, autoOpenBrowser: false) { _, _ in }

        XCTAssertNil(xlsxParser.parsedURL, "XLSX parser should not be called for a .csv file")
        XCTAssertNotNil(csvParser.lastParsedData)
    }

    @MainActor
    func testImportCSVDoesNotTerminateOnFailure() async throws {
        let coordinator = MockImportCoordinator()
        coordinator.result = .failure(AppError.network("upload failed"))
        var terminateCalls = 0
        var notifications: [(String, String)] = []
        let state = AppState(
            importCoordinator: coordinator,
            terminateApp: { terminateCalls += 1 },
            shouldPostNotifications: { true },
            terminationDelayNanoseconds: 0,
            notificationPoster: { title, body in
                notifications.append((title, body))
            }
        )
        let settings = SettingsStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)

        await state.importCSV(try makeTempCSV(), settings: settings, terminateWhenFinished: true)
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(terminateCalls, 0)
        if case .failure(let message) = state.importStatus {
            XCTAssertTrue(message.contains("upload failed"))
        } else {
            XCTFail("Expected failure status")
        }
        XCTAssertEqual(notifications.count, 1)
        XCTAssertEqual(notifications.first?.0, "CSV import failed")
    }
}

@MainActor
private func makeAppStateWithMockCoordinator() -> AppState {
    AppState(
        importCoordinator: MockImportCoordinator(),
        terminateApp: { },
        shouldPostNotifications: { false },
        terminationDelayNanoseconds: 0,
        notificationPoster: { _, _ in }
    )
}

private func makeTempCSV() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".csv")
    try "a,b\n1,2".write(to: url, atomically: true, encoding: .utf8)
    return url
}

private final class MockAuthProvider: AccessTokenProviding {
    var token = "token"
    func validAccessToken() async throws -> String { token }
}

private final class MockParser: CSVParsing {
    var lastParsedData: Data?
    let rows: [[String]]
    init(rows: [[String]]) { self.rows = rows }
    func parse(data: Data, delimiter: Character) throws -> [[String]] {
        lastParsedData = data
        return rows
    }
}

private final class MockXLSXParser: XLSXParsing {
    var parsedURL: URL?
    let rows: [[String]]
    init(rows: [[String]]) { self.rows = rows }
    func parse(url: URL) throws -> [[String]] {
        parsedURL = url
        return rows
    }
}

private final class MockSheetsService: SheetsServicing {
    var lastCreateMinimumRows: Int?
    var lastCreateMinimumColumns: Int?
    var appendError: Error?
    var uploadCallbacks: [Int] = []

    func createSpreadsheet(
        title: String,
        minimumRows: Int,
        minimumColumns: Int,
        accessToken: String
    ) async throws -> SpreadsheetInfo {
        lastCreateMinimumRows = minimumRows
        lastCreateMinimumColumns = minimumColumns
        return SpreadsheetInfo(id: "mock", url: URL(string: "https://docs.google.com/spreadsheets/d/mock/edit")!)
    }

    func appendRows(
        spreadsheetID: String,
        rows: [[String]],
        accessToken: String,
        onBatchUploaded: ((Int) -> Void)?
    ) async throws {
        for callback in uploadCallbacks {
            onBatchUploaded?(callback)
        }
        if let appendError {
            throw appendError
        }
    }
}

private final class MockImportCoordinator: ImportCoordinating {
    var result: Result<ImportResult, Error> = .failure(AppError.unknown("unset"))

    func runImport(
        request: ImportRequest,
        autoOpenBrowser: Bool,
        progress: @escaping (Double, String) async -> Void
    ) async throws -> ImportResult {
        try result.get()
    }
}
