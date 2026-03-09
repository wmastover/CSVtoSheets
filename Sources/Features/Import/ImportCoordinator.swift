import AppKit
import Foundation

final class ImportCoordinator {
    private let authManager: AuthManager
    private let parser: CSVParser
    private let sheetsService: SheetsService

    init(authManager: AuthManager, parser: CSVParser = CSVParser(), sheetsService: SheetsService = SheetsService()) {
        self.authManager = authManager
        self.parser = parser
        self.sheetsService = sheetsService
    }

    func runImport(
        request: ImportRequest,
        autoOpenBrowser: Bool,
        progress: @escaping @Sendable (Double, String) async -> Void
    ) async throws -> ImportResult {
        let start = Date()
        await progress(0.02, "Authenticating with Google")
        let accessToken = try await authManager.validAccessToken()

        await progress(0.1, "Reading CSV")
        let data = try Data(contentsOf: request.sourceURL)
        let delimiter = request.delimiterOverride ?? ","
        let rows = try parser.parse(data: data, delimiter: delimiter)
        let title = request.customTitle ?? request.sourceURL.deletingPathExtension().lastPathComponent

        await progress(0.3, "Creating spreadsheet")
        let sheet = try await sheetsService.createSpreadsheet(title: title, accessToken: accessToken)

        let totalRows = max(rows.count, 1)
        await progress(0.35, "Uploading rows")
        try await sheetsService.appendRows(
            spreadsheetID: sheet.id,
            rows: rows,
            accessToken: accessToken,
            onBatchUploaded: { uploaded in
                Task {
                    let value = 0.35 + (Double(uploaded) / Double(totalRows)) * 0.6
                    await progress(min(value, 0.95), "Uploading rows (\(uploaded)/\(totalRows))")
                }
            }
        )

        if autoOpenBrowser {
            NSWorkspace.shared.open(sheet.url)
        }
        await progress(1.0, "Done")

        return ImportResult(
            spreadsheetID: sheet.id,
            spreadsheetURL: sheet.url,
            rowsUploaded: rows.count,
            duration: Date().timeIntervalSince(start)
        )
    }
}
