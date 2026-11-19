import AppKit
import PDFKit
import Vision

enum PDFReader {
    static func read(
        _ data: Data,
        fallbackTitle: String,
        progress: @Sendable (String) -> Void
    ) throws -> Book {
        guard let pdf = PDFDocument(data: data) else { throw ConversionError.invalidPDF }
        guard !pdf.isLocked else { throw ConversionError.lockedPDF }
        let title = (pdf.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)?.trimmed
        let author = (pdf.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String)?.trimmed
        var sections: [String] = []
        var entries: [Book.Entry] = []

        for index in 0..<pdf.pageCount {
            try Task.checkCancellation()
            guard let page = pdf.page(at: index) else { continue }
            let text = try autoreleasepool {
                let embedded = page.string?.trimmed ?? ""
                if embedded.rangeOfCharacter(from: .alphanumerics) != nil {
                    progress("Reading page \(index + 1) of \(pdf.pageCount)…")
                    return embedded
                }
                progress("Recognizing text on page \(index + 1) of \(pdf.pageCount)…")
                return try recognize(page)
            }
            guard !text.trimmed.isEmpty else { continue }
            let paragraphs = paragraphs(from: text).map { "<p>\($0.xmlEscaped)</p>" }.joined(separator: "\n")
            let id = "page-\(index + 1)"
            sections.append("<div id=\"\(id)\">\(paragraphs)</div>")
            entries.append(Book.Entry(label: "Page \(index + 1)", id: id))
        }

        guard !sections.isEmpty else { throw ConversionError.empty }
        return Book(
            title: title.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTitle,
            author: author.flatMap { $0.isEmpty ? nil : $0 },
            body: sections.joined(separator: "\n"),
            contents: entries.count > 1 ? entries : []
        )
    }

    private static func paragraphs(from text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized.replacingOccurrences(of: "\n[ \\t]*\n+", with: "\n\n", options: .regularExpression)
            .components(separatedBy: "\n\n")
            .map { section in
                section.split(whereSeparator: \.isNewline).map { String($0).trimmed }.joined(separator: " ")
            }
            .filter { !$0.isEmpty }
    }

    private static func recognize(_ page: PDFPage) throws -> String {
        let thumbnail = page.thumbnail(of: CGSize(width: 1800, height: 2400), for: .cropBox)
        var bounds = CGRect(origin: .zero, size: thumbnail.size)
        guard let image = thumbnail.cgImage(forProposedRect: &bounds, context: nil, hints: nil) else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? [])
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
