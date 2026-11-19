import Foundation

public enum Source: Sendable {
    case file(URL)
    case webpage(URL)

    public static func supportsFile(_ url: URL) -> Bool {
        url.isFileURL && ["pdf", "html", "htm"].contains(url.pathExtension.lowercased())
    }

    public static func webURL(_ input: String) -> URL? {
        let input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return nil
        }
        let address = URL(string: input.contains("://") ? input : "https://" + input)
        guard let address, address.isWebURL else { return nil }
        return address
    }
}

public enum Converter {
    public static func export(
        _ source: Source,
        to destination: URL,
        progress: @Sendable (String) -> Void = { _ in }
    ) async throws -> String {
        let book: Book
        switch source {
        case .file(let url):
            guard Source.supportsFile(url) else { throw ConversionError.unsupported }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try readFile(url, limit: Limits.source)
            if url.pathExtension.lowercased() == "pdf" {
                book = try PDFReader.read(data, fallbackTitle: fileTitle(url), progress: progress)
            } else {
                book = try await HTMLReader.read(
                    data, source: url, fallbackTitle: fileTitle(url), download: nil
                )
            }
        case .webpage(let url):
            guard url.isWebURL else { throw ConversionError.invalidURL }
            progress("Fetching the page…")
            let download = WebDownload()
            let resource = try await download.get(url, limit: Limits.source)
            let title = resource.url.host() ?? "Web page"
            if resource.mimeType == "application/pdf" || resource.data.starts(with: Data("%PDF-".utf8)) {
                book = try PDFReader.read(resource.data, fallbackTitle: fileTitle(resource.url), progress: progress)
            } else {
                let supported = ["text/html", "application/xhtml+xml", "application/octet-stream"]
                guard resource.mimeType.map(supported.contains) ?? true else {
                    throw ConversionError.unsupportedResponse
                }
                progress("Preparing the article…")
                book = try await HTMLReader.read(
                    resource.data, source: resource.url, fallbackTitle: title,
                    encoding: resource.encoding, download: download
                )
            }
        }
        try Task.checkCancellation()
        progress("Writing the EPUB…")
        try EPUBWriter.write(book, to: destination)
        return book.title
    }

    private static func fileTitle(_ url: URL) -> String {
        let title = url.deletingPathExtension().lastPathComponent
        return title.isEmpty ? "Untitled document" : title
    }
}

struct Book {
    struct Entry {
        let label: String
        let id: String
    }

    struct Asset {
        let path: String
        let mediaType: String
        let data: Data
    }

    let title: String
    var author: String? = nil
    var language: String = "und"
    let body: String
    var contents: [Entry] = []
    var assets: [Asset] = []
}

enum Limits {
    static let source = 80 * 1024 * 1024
    static let image = 8 * 1024 * 1024
    static let allImages = 32 * 1024 * 1024
}

enum ConversionError: LocalizedError, Equatable {
    case unsupported, invalidURL, unsupportedResponse, invalidPDF, lockedPDF, empty, tooLarge
    case inaccessibleFile, invalidResponse, http(Int), archive

    var errorDescription: String? {
        switch self {
        case .unsupported: "Choose a PDF, HTML, or HTM file."
        case .invalidURL: "Enter a valid HTTP or HTTPS address."
        case .unsupportedResponse: "This address did not return an HTML page or PDF."
        case .invalidPDF: "This PDF could not be opened. It may be damaged."
        case .lockedPDF: "Unlock this password-protected PDF before converting it."
        case .empty: "No readable content was found in this source."
        case .tooLarge: "The source exceeds the size limit for conversion."
        case .inaccessibleFile: "This source is unavailable. Choose a local file and try again."
        case .invalidResponse: "The address did not return a readable response."
        case .http(let status): "The website returned HTTP \(status). Check the address and its access settings."
        case .archive: "The EPUB could not be packaged."
        }
    }
}

func readFile(_ url: URL, limit: Int) throws -> Data {
    let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
    guard attributes.isRegularFile == true, let size = attributes.fileSize else {
        throw ConversionError.inaccessibleFile
    }
    guard size <= limit else { throw ConversionError.tooLarge }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let data = try handle.read(upToCount: limit + 1) ?? Data()
    guard data.count <= limit else { throw ConversionError.tooLarge }
    return data
}

extension URL {
    var isWebURL: Bool {
        ["http", "https"].contains(scheme?.lowercased() ?? "")
            && host()?.isEmpty == false && user() == nil && password() == nil
    }

    func isSameOrigin(as other: URL) -> Bool {
        scheme?.lowercased() == other.scheme?.lowercased()
            && host()?.lowercased() == other.host()?.lowercased()
            && effectivePort == other.effectivePort
    }

    private var effectivePort: Int { port ?? (scheme?.lowercased() == "https" ? 443 : 80) }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    var xmlEscaped: String {
        let clean = String(unicodeScalars.filter {
            switch $0.value {
            case 9, 10, 13, 0x20...0xD7FF, 0xE000...0xFFFD, 0x10000...0x10FFFF: true
            default: false
            }
        })
        return clean
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
