import Foundation

enum AppError: Error, LocalizedError {
    case auth(String)
    case parsing(String)
    case network(String)
    case rateLimit(String)
    case unsupportedEncoding
    case partialUpload(uploadedRows: Int, message: String)
    case emptyFile
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .auth(let message): return "Authentication failed: \(message)"
        case .parsing(let message): return "Parsing error: \(message)"
        case .network(let message): return "Network error: \(message)"
        case .rateLimit(let message): return "Rate limited by Google API: \(message)"
        case .unsupportedEncoding: return "Unsupported file encoding. Please use a UTF-8 encoded file."
        case .partialUpload(let uploadedRows, let message):
            return "Partial upload (\(uploadedRows) rows): \(message)"
        case .emptyFile: return "The selected file is empty."
        case .unknown(let message): return message
        }
    }
}

struct ImportRequest {
    let sourceURL: URL
    let delimiterOverride: Character?
    let customTitle: String?
}

struct ImportResult: Equatable {
    let spreadsheetID: String
    let spreadsheetURL: URL
    let rowsUploaded: Int
    let duration: TimeInterval
}

enum ImportStatus: Equatable {
    case idle
    case working(progress: Double, message: String)
    case success(ImportResult)
    case failure(String)
}
