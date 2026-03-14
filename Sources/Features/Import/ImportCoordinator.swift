import AppKit
import Foundation

protocol ImportCoordinating {
    func runImport(
        request: ImportRequest,
        autoOpenBrowser: Bool,
        progress: @escaping (Double, String) async -> Void
    ) async throws -> ImportResult
}

final class ImportCoordinator: ImportCoordinating {
    private let authManager: AccessTokenProviding
    private let csvParser: CSVParsing
    private let xlsxParser: XLSXParsing
    private let sheetsService: SheetsServicing
    private let openURL: (URL) -> Void

    init(
        authManager: AccessTokenProviding,
        csvParser: CSVParsing = CSVParser(),
        xlsxParser: XLSXParsing = XLSXParser(),
        sheetsService: SheetsServicing = SheetsService(),
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.authManager = authManager
        self.csvParser = csvParser
        self.xlsxParser = xlsxParser
        self.sheetsService = sheetsService
        self.openURL = openURL
    }

    func runImport(
        request: ImportRequest,
        autoOpenBrowser: Bool,
        progress: @escaping (Double, String) async -> Void
    ) async throws -> ImportResult {
        let start = Date()
        await progress(0.02, "Authenticating with Google")
        let accessToken = try await authManager.validAccessToken()

        let rows: [[String]]
        if request.sourceURL.pathExtension.lowercased() == "xlsx" {
            await progress(0.1, "Reading Excel file")
            rows = try xlsxParser.parse(url: request.sourceURL)
        } else {
            await progress(0.1, "Reading CSV")
            let data = try Data(contentsOf: request.sourceURL)
            let delimiter = request.delimiterOverride ?? ","
            rows = try csvParser.parse(data: data, delimiter: delimiter)
        }
        let title = request.customTitle ?? request.sourceURL.deletingPathExtension().lastPathComponent
        let maxColumns = rows.map(\.count).max() ?? 1

        await progress(0.3, "Creating spreadsheet")
        let sheet = try await sheetsService.createSpreadsheet(
            title: title,
            minimumRows: rows.count,
            minimumColumns: maxColumns,
            accessToken: accessToken
        )

        let totalRows = max(rows.count, 1)
        await progress(0.35, "Uploading rows")
        do {
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
        } catch {
            if autoOpenBrowser {
                openURL(sheet.url)
            }
            throw error
        }

        if autoOpenBrowser {
            openURL(sheet.url)
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
