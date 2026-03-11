import Foundation

struct SpreadsheetInfo {
    let id: String
    let url: URL
}

final class SheetsService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func createSpreadsheet(title: String, accessToken: String) async throws -> SpreadsheetInfo {
        guard let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets") else {
            throw AppError.network("Unable to build Sheets API URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = CreateSpreadsheetRequest(properties: .init(title: title))
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        let http = try validateHTTP(response: response, data: data)
        guard http.statusCode == 200 else { throw mapHTTPError(statusCode: http.statusCode, data: data) }
        let createResponse = try JSONDecoder().decode(CreateSpreadsheetResponse.self, from: data)

        guard let sheetURL = URL(string: createResponse.spreadsheetURL) else {
            throw AppError.network("Google returned an invalid spreadsheet URL.")
        }
        return SpreadsheetInfo(id: createResponse.spreadsheetID, url: sheetURL)
    }

    func appendRows(
        spreadsheetID: String,
        rows: [[String]],
        accessToken: String,
        batchSize: Int = 500,
        onBatchUploaded: ((Int) -> Void)? = nil
    ) async throws {
        guard !rows.isEmpty else { throw AppError.emptyFile }
        var uploaded = 0
        var nextRow = 1
        for start in stride(from: 0, to: rows.count, by: batchSize) {
            let end = min(start + batchSize, rows.count)
            let batch = Array(rows[start..<end])
            do {
                try await writeBatch(
                    spreadsheetID: spreadsheetID,
                    rows: batch,
                    startRow: nextRow,
                    accessToken: accessToken
                )
                nextRow += batch.count
                uploaded += batch.count
                onBatchUploaded?(uploaded)
            } catch let error as AppError {
                throw AppError.partialUpload(uploadedRows: uploaded, message: error.localizedDescription)
            } catch {
                throw AppError.partialUpload(uploadedRows: uploaded, message: error.localizedDescription)
            }
        }
    }

    private func writeBatch(
        spreadsheetID: String,
        rows: [[String]],
        startRow: Int,
        accessToken: String
    ) async throws {
        guard let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetID)/values:batchUpdate") else {
            throw AppError.network("Unable to build Sheets batchUpdate URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let range = "Sheet1!A\(startRow)"
        let valueRange = ValueRange(range: range, majorDimension: "ROWS", values: rows)
        let body = BatchUpdateValuesRequest(valueInputOption: "RAW", data: [valueRange])
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        let http = try validateHTTP(response: response, data: data)
        guard http.statusCode == 200 else { throw mapHTTPError(statusCode: http.statusCode, data: data) }
    }

    private func validateHTTP(response: URLResponse, data: Data) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw AppError.network("Invalid HTTP response.")
        }
        if (500...599).contains(http.statusCode) {
            throw AppError.network("Google API temporary server error (\(http.statusCode)).")
        }
        if http.statusCode == 429 {
            throw AppError.rateLimit("Too many requests. Try again shortly.")
        }
        if http.statusCode == 401 {
            throw AppError.auth("Access token expired or invalid.")
        }
        if (400...499).contains(http.statusCode), http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "unknown API error"
            throw AppError.network("Google API rejected request (\(http.statusCode)): \(body)")
        }
        return http
    }

    private func mapHTTPError(statusCode: Int, data: Data) -> AppError {
        if statusCode == 429 {
            return .rateLimit("Too many requests. Try again shortly.")
        }
        let body = String(data: data, encoding: .utf8) ?? "unknown API error"
        return .network("Google API request failed (\(statusCode)): \(body)")
    }
}

private struct CreateSpreadsheetRequest: Encodable {
    struct Properties: Encodable {
        let title: String
    }
    let properties: Properties
}

private struct CreateSpreadsheetResponse: Decodable {
    let spreadsheetID: String
    let spreadsheetURL: String

    enum CodingKeys: String, CodingKey {
        case spreadsheetID = "spreadsheetId"
        case spreadsheetURL = "spreadsheetUrl"
    }
}

private struct ValueRange: Encodable {
    let range: String
    let majorDimension: String
    let values: [[String]]
}

private struct BatchUpdateValuesRequest: Encodable {
    let valueInputOption: String
    let data: [ValueRange]
}
