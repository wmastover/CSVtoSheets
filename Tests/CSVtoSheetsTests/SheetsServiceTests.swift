import Foundation
import XCTest
@testable import CSVtoSheets

final class SheetsServiceTests: XCTestCase {
    func testCreateSpreadsheetUsesDefaultGridWhenSmallCSV() async throws {
        let testID = UUID().uuidString
        defer { URLProtocolStub.removeHandler(testID: testID) }
        var capturedBody = Data()
        URLProtocolStub.registerHandler(testID: testID) { request in
            capturedBody = bodyData(from: request)
            let payload = #"{"spreadsheetId":"sheet-1","spreadsheetUrl":"https://docs.google.com/spreadsheets/d/sheet-1/edit"}"#
            return (makeHTTPResponse(url: request.url!, statusCode: 200), Data(payload.utf8))
        }
        let service = SheetsService(session: makeStubSession(testID: testID))

        _ = try await service.createSpreadsheet(
            title: "Small",
            minimumRows: 2,
            minimumColumns: 3,
            accessToken: "token"
        )

        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: capturedBody) as? [String: Any])
        let sheets = try XCTUnwrap(json["sheets"] as? [[String: Any]])
        let properties = try XCTUnwrap(sheets.first?["properties"] as? [String: Any])
        let grid = try XCTUnwrap(properties["gridProperties"] as? [String: Any])
        XCTAssertEqual(grid["rowCount"] as? Int, 1000)
        XCTAssertEqual(grid["columnCount"] as? Int, 26)
    }

    func testCreateSpreadsheetUsesCSVSizeWhenLargerThanDefaults() async throws {
        let testID = UUID().uuidString
        defer { URLProtocolStub.removeHandler(testID: testID) }
        var capturedBody = Data()
        URLProtocolStub.registerHandler(testID: testID) { request in
            capturedBody = bodyData(from: request)
            let payload = #"{"spreadsheetId":"sheet-2","spreadsheetUrl":"https://docs.google.com/spreadsheets/d/sheet-2/edit"}"#
            return (makeHTTPResponse(url: request.url!, statusCode: 200), Data(payload.utf8))
        }
        let service = SheetsService(session: makeStubSession(testID: testID))

        _ = try await service.createSpreadsheet(
            title: "Large",
            minimumRows: 1500,
            minimumColumns: 40,
            accessToken: "token"
        )

        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: capturedBody) as? [String: Any])
        let sheets = try XCTUnwrap(json["sheets"] as? [[String: Any]])
        let properties = try XCTUnwrap(sheets.first?["properties"] as? [String: Any])
        let grid = try XCTUnwrap(properties["gridProperties"] as? [String: Any])
        XCTAssertEqual(grid["rowCount"] as? Int, 1500)
        XCTAssertEqual(grid["columnCount"] as? Int, 40)
    }

    func testAppendRowsThrowsEmptyFile() async {
        let service = SheetsService(session: makeStubSession(testID: UUID().uuidString))
        do {
            try await service.appendRows(spreadsheetID: "sheet", rows: [], accessToken: "token")
            XCTFail("Expected empty file error")
        } catch let appError as AppError {
            guard case .emptyFile = appError else {
                return XCTFail("Unexpected app error: \(appError)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAppendRowsWrapsBatchFailureAsPartialUpload() async {
        let testID = UUID().uuidString
        defer { URLProtocolStub.removeHandler(testID: testID) }
        var callCount = 0
        URLProtocolStub.registerHandler(testID: testID) { request in
            callCount += 1
            if callCount == 1 {
                return (makeHTTPResponse(url: request.url!, statusCode: 200), Data("{}".utf8))
            }
            return (makeHTTPResponse(url: request.url!, statusCode: 500), Data("server down".utf8))
        }
        let service = SheetsService(session: makeStubSession(testID: testID))
        let rows = (0..<501).map { ["row-\($0)"] }

        do {
            try await service.appendRows(spreadsheetID: "sheet", rows: rows, accessToken: "token")
            XCTFail("Expected partial upload error")
        } catch let appError as AppError {
            guard case let .partialUpload(uploadedRows, message) = appError else {
                return XCTFail("Unexpected app error: \(appError)")
            }
            XCTAssertEqual(uploadedRows, 500)
            XCTAssertTrue(message.contains("Google API temporary server error"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateSpreadsheetMaps401ToAuthError() async {
        let testID = UUID().uuidString
        defer { URLProtocolStub.removeHandler(testID: testID) }
        URLProtocolStub.registerHandler(testID: testID) { request in
            (makeHTTPResponse(url: request.url!, statusCode: 401), Data("unauthorized".utf8))
        }
        let service = SheetsService(session: makeStubSession(testID: testID))

        do {
            _ = try await service.createSpreadsheet(title: "x", minimumRows: 1, minimumColumns: 1, accessToken: "token")
            XCTFail("Expected auth error")
        } catch let appError as AppError {
            guard case .auth = appError else {
                return XCTFail("Unexpected app error: \(appError)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateSpreadsheetMaps429ToRateLimitError() async {
        let testID = UUID().uuidString
        defer { URLProtocolStub.removeHandler(testID: testID) }
        URLProtocolStub.registerHandler(testID: testID) { request in
            (makeHTTPResponse(url: request.url!, statusCode: 429), Data("rate limit".utf8))
        }
        let service = SheetsService(session: makeStubSession(testID: testID))

        do {
            _ = try await service.createSpreadsheet(title: "x", minimumRows: 1, minimumColumns: 1, accessToken: "token")
            XCTFail("Expected rate limit error")
        } catch let appError as AppError {
            guard case .rateLimit = appError else {
                return XCTFail("Unexpected app error: \(appError)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateSpreadsheetMaps5xxToNetworkError() async {
        let testID = UUID().uuidString
        defer { URLProtocolStub.removeHandler(testID: testID) }
        URLProtocolStub.registerHandler(testID: testID) { request in
            (makeHTTPResponse(url: request.url!, statusCode: 503), Data("server error".utf8))
        }
        let service = SheetsService(session: makeStubSession(testID: testID))

        do {
            _ = try await service.createSpreadsheet(title: "x", minimumRows: 1, minimumColumns: 1, accessToken: "token")
            XCTFail("Expected network error")
        } catch let appError as AppError {
            guard case .network(let message) = appError else {
                return XCTFail("Unexpected app error: \(appError)")
            }
            XCTAssertTrue(message.contains("temporary server error"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
