import Foundation
import XCTest
@testable import CSVtoSheets

final class URLProtocolStub: URLProtocol {
    private static let lock = NSLock()
    private static var handlers: [String: (URLRequest) throws -> (HTTPURLResponse, Data)] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let testID = request.value(forHTTPHeaderField: "X-Test-ID"),
            let handler = Self.handler(for: testID)
        else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "URLProtocolStub", code: 0))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func registerHandler(
        testID: String,
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) {
        lock.lock()
        handlers[testID] = handler
        lock.unlock()
    }

    static func removeHandler(testID: String) {
        lock.lock()
        handlers.removeValue(forKey: testID)
        lock.unlock()
    }

    private static func handler(for testID: String) -> ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        lock.lock()
        defer { lock.unlock() }
        return handlers[testID]
    }
}

func makeStubSession(testID: String) -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [URLProtocolStub.self]
    config.httpAdditionalHeaders = ["X-Test-ID": testID]
    return URLSession(configuration: config)
}

func makeHTTPResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

func bodyData(from request: URLRequest) -> Data {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else {
        return Data()
    }
    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: bufferSize)
        if read <= 0 { break }
        data.append(buffer, count: read)
    }
    return data
}

final class InMemoryTokenStore: TokenStore {
    var stored: OAuthToken?
    var loadError: Error?
    var clearCount = 0
    var savedTokens: [OAuthToken] = []

    func save(token: OAuthToken) throws {
        savedTokens.append(token)
        stored = token
    }

    func load() throws -> OAuthToken? {
        if let loadError {
            throw loadError
        }
        return stored
    }

    func clear() throws {
        clearCount += 1
        stored = nil
    }
}
