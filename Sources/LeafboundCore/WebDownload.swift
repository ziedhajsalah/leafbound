import Foundation

final class WebDownload: Sendable {
    struct Resource {
        let data: Data
        let url: URL
        let mimeType: String?
        let encoding: String?
    }

    func get(_ url: URL, limit: Int, sameOrigin: URL? = nil) async throws -> Resource {
        guard url.isWebURL, sameOrigin.map({ url.isSameOrigin(as: $0) }) ?? true else {
            throw ConversionError.invalidURL
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 45
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let redirects = Redirects(origin: sameOrigin)
        var request = URLRequest(url: url)
        request.setValue("Leafbound/1.0", forHTTPHeaderField: "User-Agent")
        let (temporary, response) = try await session.download(for: request, delegate: redirects)
        defer { try? FileManager.default.removeItem(at: temporary) }

        guard let http = response as? HTTPURLResponse, let finalURL = http.url, finalURL.isWebURL else {
            throw ConversionError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else { throw ConversionError.http(http.statusCode) }
        return Resource(
            data: try readFile(temporary, limit: limit),
            url: finalURL,
            mimeType: http.mimeType,
            encoding: http.textEncodingName
        )
    }

    private final class Redirects: NSObject, URLSessionTaskDelegate {
        let origin: URL?

        init(origin: URL?) { self.origin = origin }

        func urlSession(
            _ session: URLSession, task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest
        ) async -> URLRequest? {
            guard let url = request.url, url.isWebURL,
                  origin.map({ url.isSameOrigin(as: $0) }) ?? true else { return nil }
            return request
        }
    }
}
