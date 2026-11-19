import Foundation
import ImageIO
import UniformTypeIdentifiers
@preconcurrency import libxml2

enum HTMLReader {
    static func read(
        _ data: Data, source: URL, fallbackTitle: String,
        encoding: String? = nil, download: WebDownload?
    ) async throws -> Book {
        let draft = try parse(data, source: source, fallbackTitle: fallbackTitle, encoding: encoding)

        var assets: [Book.Asset] = []
        var imageTags: [String] = []
        var storedImages: [String: String] = [:]
        var imageBytes = 0
        for image in draft.images {
            try Task.checkCancellation()
            if let path = storedImages[image.address] {
                imageTags.append(image.tag(path: path))
                continue
            }
            if imagesCanGrow(assets.count, imageBytes),
               let data = try? await imageData(image.address, source: source, download: download),
               let png = makePNG(data), png.count <= Limits.allImages - imageBytes {
                let path = "images/image-\(assets.count + 1).png"
                assets.append(Book.Asset(path: path, mediaType: "image/png", data: png))
                storedImages[image.address] = path
                imageBytes += png.count
                imageTags.append(image.tag(path: path))
            } else {
                imageTags.append(image.alt.xmlEscaped)
            }
        }

        let parts = draft.markup.components(separatedBy: "\u{0}")
        let body = parts.enumerated().map { index, part in
            index.isMultiple(of: 2) ? part : Int(part).map { imageTags[$0] } ?? ""
        }.joined()
        guard draft.hasText || !assets.isEmpty || draft.images.contains(where: { !$0.alt.isEmpty }) else {
            throw ConversionError.empty
        }
        return Book(
            title: draft.title, author: draft.author, language: draft.language, body: body,
            contents: draft.contents, assets: assets
        )
    }

    private static func imagesCanGrow(_ count: Int, _ bytes: Int) -> Bool {
        count < 40 && bytes < Limits.allImages
    }

    private typealias Node = xmlNodePtr

    private struct Image {
        let address: String
        let alt: String

        func tag(path: String) -> String {
            "<img src=\"\(path)\" alt=\"\(alt.xmlEscaped)\"/>"
        }
    }

    private struct Draft {
        let title: String
        let author: String?
        let language: String
        let markup: String
        let hasText: Bool
        let contents: [Book.Entry]
        let images: [Image]
    }

    private static func parse(_ data: Data, source: URL, fallbackTitle: String, encoding: String?) throws -> Draft {
        guard !data.isEmpty else { throw ConversionError.empty }
        let encoding = encoding ?? (String(data: data, encoding: .utf8) == nil ? nil : "UTF-8")
        let options = HTML_PARSE_NONET.rawValue | HTML_PARSE_NOERROR.rawValue | HTML_PARSE_NOWARNING.rawValue
        let parsed = data.withUnsafeBytes { bytes in
            htmlReadMemory(bytes.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(data.count),
                           nil, encoding, Int32(options))
        }
        guard let parsed else { throw ConversionError.empty }
        defer { xmlFreeDoc(parsed) }
        guard let root = xmlDocGetRootElement(parsed), let body = first(in: root, named: "body") else {
            throw ConversionError.empty
        }

        let head = first(in: root, named: "head")
        let title = head.flatMap { first(in: $0, named: "title") }.map(nodeText)
        let author = head.flatMap { head in
            children(of: head).first {
                nodeName($0) == "meta" && attribute("name", on: $0)?.lowercased() == "author"
            }.flatMap { attribute("content", on: $0) }
        }
        let lang = attribute("lang", on: root) ?? "und"
        let language = lang.range(of: "^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$", options: .regularExpression) == nil
            ? "und" : lang
        let content = source.isFileURL ? body : article(in: body)
        var renderer = Renderer(source: source)
        for node in children(of: content) { renderer.collectIDs(node) }
        let markup = children(of: content).map { renderer.render($0) }.joined()
        return Draft(
            title: title.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTitle,
            author: author.flatMap { $0.isEmpty ? nil : $0 }, language: language,
            markup: markup, hasText: renderer.hasText, contents: renderer.contents,
            images: renderer.images
        )
    }

    private static func article(in body: Node) -> Node {
        let articles = descendants(of: body).filter { nodeName($0) == "article" }.prefix(40)
        let main = descendants(of: body).first { nodeName($0) == "main" || attribute("role", on: $0) == "main" }
        let largest = articles.map { ($0, nodeText($0).count) }.max { $0.1 < $1.1 }
        if let (article, length) = largest, length >= 140,
           main.map({ length >= nodeText($0).count / 2 }) ?? true {
            return article
        }
        return main ?? (articles.count == 1 ? articles.first : nil) ?? body
    }

    private struct Renderer {
        static let headings: Set<String> = ["h1", "h2", "h3", "h4", "h5", "h6"]
        static let elements: Set<String> = [
            "a", "abbr", "article", "b", "blockquote", "br", "caption", "cite", "code", "dd", "del",
            "details", "dfn", "div", "dl", "dt", "em", "figcaption", "figure", "header", "hr", "i", "kbd",
            "li", "mark", "ol", "p", "pre", "q", "s", "samp", "section", "small", "span", "strong",
            "sub", "summary", "sup", "table", "tbody", "td", "th", "thead", "tfoot", "tr", "u", "ul", "var"
        ]
        static let ignored: Set<String> = [
            "audio", "button", "canvas", "dialog", "form", "iframe", "input", "noscript", "object",
            "script", "select", "style", "svg", "template", "textarea", "video"
        ]

        let source: URL
        var images: [Image] = []
        var contents: [Book.Entry] = []
        var hasText = false
        var knownIDs: [String: String] = [:]
        var usedIDs: Set<String> = []

        func skip(_ node: Node, named name: String) -> Bool {
            Self.ignored.contains(name) || attribute("hidden", on: node) != nil
                || (!source.isFileURL && ["nav", "aside", "footer"].contains(name))
        }

        mutating func collectIDs(_ node: Node) {
            guard node.pointee.type == XML_ELEMENT_NODE, let name = nodeName(node), !skip(node, named: name) else {
                return
            }
            if Self.elements.contains(name) || Self.headings.contains(name),
               let original = attribute("id", on: node), !original.isEmpty, knownIDs[original] == nil {
                knownIDs[original] = "ref-\(knownIDs.count + 1)"
            }
            for child in children(of: node) { collectIDs(child) }
        }

        mutating func render(_ node: Node) -> String {
            if node.pointee.type == XML_TEXT_NODE || node.pointee.type == XML_CDATA_SECTION_NODE {
                guard let content = node.pointee.content else { return "" }
                let text = String(cString: content)
                if !text.trimmed.isEmpty { hasText = true }
                return text.xmlEscaped
            }
            guard node.pointee.type == XML_ELEMENT_NODE, let name = nodeName(node),
                  !skip(node, named: name) else { return "" }

            if name == "img" {
                let alt = attribute("alt", on: node) ?? ""
                guard images.count < 80, let address = attribute("src", on: node), !address.isEmpty else {
                    if !alt.isEmpty { hasText = true }
                    return alt.xmlEscaped
                }
                let index = images.count
                images.append(Image(address: address, alt: alt))
                return "\u{0}\(index)\u{0}"
            }

            let heading = Self.headings.contains(name)
            let tag = ["details", "summary"].contains(name) ? "div" : name
            let attributes = nodeAttributes(node, tag: tag, heading: heading)
            let inside = children(of: node).map { render($0) }.joined()
            guard heading || Self.elements.contains(name) else { return inside }
            if ["br", "hr"].contains(name) { return "<\(tag)\(attributes)/>" }
            return "<\(tag)\(attributes)>\(inside)</\(tag)>"
        }

        private mutating func nodeAttributes(_ node: Node, tag: String, heading: Bool) -> String {
            guard heading || Self.elements.contains(tag) else { return "" }
            let target = attribute("id", on: node).flatMap { knownIDs[$0] }
            var id = target.flatMap { usedIDs.insert($0).inserted ? $0 : nil }
            if heading, contents.count < 300 {
                let title = nodeText(node)
                if !title.isEmpty {
                    let headingID = id ?? "heading-\(contents.count + 1)"
                    contents.append(Book.Entry(label: title, id: headingID))
                    id = headingID
                }
            }
            var attributes = id.map { " id=\"\($0)\"" } ?? ""
            if tag == "a", let value = attribute("href", on: node), let href = link(value) {
                attributes += " href=\"\(href.xmlEscaped)\""
            }
            if tag == "td" || tag == "th" {
                for key in ["rowspan", "colspan"] {
                    if let value = attribute(key, on: node).flatMap(Int.init), (1...1000).contains(value) {
                        attributes += " \(key)=\"\(value)\""
                    }
                }
            }
            if let direction = attribute("dir", on: node), ["ltr", "rtl", "auto"].contains(direction) {
                attributes += " dir=\"\(direction)\""
            }
            return attributes
        }

        private func link(_ value: String) -> String? {
            if value.hasPrefix("#") {
                let fragment = String(value.dropFirst())
                return knownIDs[fragment.removingPercentEncoding ?? fragment].map { "#" + $0 }
            }
            guard !value.isEmpty, let url = URL(string: value, relativeTo: source)?.absoluteURL else { return nil }
            return url.isWebURL || url.scheme == "mailto" ? url.absoluteString : nil
        }
    }

    private static func children(of node: Node) -> AnySequence<Node> {
        guard let first = node.pointee.children else { return AnySequence([]) }
        return AnySequence(sequence(first: first) { (sibling: Node) -> Node? in
            sibling.pointee.next
        })
    }

    private static func descendants(of node: Node) -> [Node] {
        var result: [Node] = []
        for child in children(of: node) where child.pointee.type == XML_ELEMENT_NODE {
            result.append(child)
            result.append(contentsOf: descendants(of: child))
        }
        return result
    }

    private static func first(in node: Node, named name: String) -> Node? {
        if nodeName(node) == name { return node }
        for child in children(of: node) where child.pointee.type == XML_ELEMENT_NODE {
            if let match = first(in: child, named: name) { return match }
        }
        return nil
    }

    private static func nodeName(_ node: Node) -> String? {
        node.pointee.name.map { String(cString: $0) }
    }

    private static func nodeText(_ node: Node) -> String {
        guard let value = xmlNodeGetContent(node) else { return "" }
        defer { xmlFree(value) }
        return String(cString: value).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func attribute(_ name: String, on node: Node) -> String? {
        guard let value = name.withCString({ pointer in
            pointer.withMemoryRebound(to: UInt8.self, capacity: name.utf8.count + 1) { xmlGetProp(node, $0) }
        }) else { return nil }
        defer { xmlFree(value) }
        return String(cString: value).trimmed
    }

    private static func imageData(_ address: String, source: URL, download: WebDownload?) async throws -> Data? {
        if address.hasPrefix("data:image/"), address.utf8.count <= Limits.image * 2,
           let comma = address.firstIndex(of: ","), address[..<comma].hasSuffix(";base64") {
            return Data(base64Encoded: String(address[address.index(after: comma)...]))
        }
        guard let url = URL(string: address, relativeTo: source)?.absoluteURL else { return nil }
        if let download {
            return try await download.get(url, limit: Limits.image, sameOrigin: source).data
        }
        guard url.isFileURL else { return nil }
        let directory = source.deletingLastPathComponent().resolvingSymlinksInPath().path
        let image = url.resolvingSymlinksInPath()
        let prefix = directory == "/" ? "/" : directory + "/"
        guard image.path.hasPrefix(prefix) else { return nil }
        return try readFile(image, limit: Limits.image)
    }

    private static func makePNG(_ data: Data) -> Data? {
        guard data.count <= Limits.image,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              (1...12_000).contains(width), (1...12_000).contains(height),
              width * height <= 48_000_000 else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1500
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? result as Data : nil
    }
}
