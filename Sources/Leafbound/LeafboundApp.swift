import AppKit
import LeafboundCore
import SwiftUI
import UniformTypeIdentifiers

@main
struct LeafboundApp: App {
    var body: some Scene {
        Window("Leafbound", id: "converter") {
            ConverterView()
                .preferredColorScheme(.light)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 980, height: 650)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

private struct ConverterView: View {
    private enum Mode: String, CaseIterable {
        case file = "Local file"
        case web = "Web link"

        var icon: String { self == .file ? "doc" : "link" }
    }

    private struct Export {
        let title: String
        let file: URL
    }

    @State private var mode: Mode = .file
    @State private var file: URL?
    @State private var address = ""
    @State private var isDropping = false
    @State private var progress: String?
    @State private var error: String?
    @State private var exported: Export?
    @FocusState private var urlFocused: Bool

    private let sendToKindle = URL(string: "https://www.amazon.com/sendtokindle")!

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Palette.rule).frame(height: 1)
            HStack(spacing: 0) {
                workspace
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                BookPreview(title: previewTitle)
                    .frame(minWidth: 335, idealWidth: 380, maxWidth: 410, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 885, minHeight: 620)
        .background(Palette.paper)
        .foregroundStyle(Palette.ink)
        .tint(Palette.moss)
        .onChange(of: address) { _, _ in
            if progress == nil { resetStatus() }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                Image(systemName: "book.pages")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Palette.moss, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Palette.lime)
                    .accessibilityHidden(true)
                Text("Leafbound")
                    .font(.system(size: 16, weight: .semibold))
            }
            Spacer()
            Link(destination: sendToKindle) {
                Label("Send to Kindle", systemImage: "arrow.up.right")
                    .labelStyle(TrailingIconLabelStyle())
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Palette.moss)
            .help("Open Amazon Send to Kindle")
        }
        .padding(.leading, 88)
        .padding(.trailing, 28)
        .frame(height: 57)
    }

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Made for\nreading.")
                .font(.system(size: 58, weight: .regular, design: .serif))
                .tracking(-3.6)
                .lineSpacing(-6)
                .accessibilityAddTraits(.isHeader)
            Text("Turn a PDF, HTML file, or web page into an ebook for your Kindle.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .frame(maxWidth: 360, alignment: .leading)

            tabs.padding(.top, 29)
            Group {
                switch mode {
                case .file: fileInput
                case .web: webInput
                }
            }
            .frame(height: 122)
            .padding(.top, 12)

            Button(action: chooseDestination) {
                HStack(spacing: 9) {
                    Image(systemName: "arrow.down.to.line")
                        .accessibilityHidden(true)
                    Text(progress == nil ? "Create EPUB" : "Creating EPUB…")
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(source == nil || progress != nil)
            .padding(.top, 15)

            status
                .padding(.top, 13)
                .frame(height: 49, alignment: .topLeading)
        }
        .frame(maxWidth: 490)
        .padding(.horizontal, 50)
        .padding(.vertical, 22)
    }

    private var tabs: some View {
        HStack(spacing: 5) {
            ForEach(Mode.allCases, id: \.self) { item in
                Button {
                    guard mode != item else { return }
                    mode = item
                    resetStatus()
                    urlFocused = item == .web
                } label: {
                    Label(item.rawValue, systemImage: item.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 13)
                        .frame(height: 32)
                        .foregroundStyle(mode == item ? Palette.paper : Palette.muted)
                        .background(mode == item ? Palette.moss : .clear, in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Palette.well, in: RoundedRectangle(cornerRadius: 10))
        .disabled(progress != nil)
    }

    private var fileInput: some View {
        ZStack(alignment: .trailing) {
            Button(action: selectFile) {
                if let file {
                    HStack(spacing: 13) {
                        inputIcon(file.pathExtension.lowercased() == "pdf" ? "doc.richtext" : "doc.text")
                        VStack(alignment: .leading, spacing: 5) {
                            Text(file.lastPathComponent)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(2)
                                .truncationMode(.middle)
                            Text("Click to replace")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 24)
                    }
                    .padding(17)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 4) {
                        inputIcon("arrow.up.document")
                        Text("Drop a file or browse")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.top, 2)
                        Text("PDF, HTML or HTM")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityHint("Opens a file picker")

            if file != nil {
                Button {
                    file = nil
                    resetStatus()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.muted)
                        .padding(10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove file")
                .padding(.trailing, 6)
            }
        }
        .background(isDropping ? Palette.paleGreen : Palette.input, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isDropping ? Palette.moss : Palette.dashed, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .allowsHitTesting(false)
        }
        .dropDestination(for: URL.self) { items, _ in
            guard progress == nil, let first = items.first else { return false }
            return accept(first)
        } isTargeted: {
            isDropping = $0
        }
        .disabled(progress != nil)
    }

    private var webInput: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Page address")
                .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 9) {
                Image(systemName: "link")
                    .foregroundStyle(Palette.moss)
                    .accessibilityHidden(true)
                TextField("https://example.com/article", text: $address)
                    .textFieldStyle(.plain)
                    .focused($urlFocused)
                    .accessibilityLabel("Page address")
            }
            .padding(.horizontal, 11)
            .frame(height: 37)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(urlFocused ? Palette.moss : Palette.rule, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            Text(address.isEmpty || Source.webURL(address) != nil
                 ? "Use a public article or a direct PDF link."
                 : "Enter a valid HTTP or HTTPS address.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.input, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.rule).allowsHitTesting(false)
        }
        .disabled(progress != nil)
    }

    @ViewBuilder private var status: some View {
        if let progress {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).accessibilityHidden(true)
                Text(progress).font(.system(size: 12))
            }
            .foregroundStyle(Palette.muted)
        } else if let error {
            Label(error, systemImage: "exclamationmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(Palette.failure)
        } else if let exported {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                Text("EPUB saved")
                    .fontWeight(.semibold)
                Spacer(minLength: 4)
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([exported.file])
                }
                .buttonStyle(.link)
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.moss)
        }
    }

    private func inputIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Palette.moss)
            .frame(width: 37, height: 37)
            .background(Palette.paleGreen, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }

    private var source: Source? {
        switch mode {
        case .file: file.map(Source.file)
        case .web: Source.webURL(address).map(Source.webpage)
        }
    }

    private var previewTitle: String? {
        if let exported { return exported.title }
        switch source {
        case .file(let url): return url.deletingPathExtension().lastPathComponent
        case .webpage(let url): return url.host()
        case nil: return nil
        }
    }

    private func resetStatus() {
        error = nil
        exported = nil
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .html, UTType(filenameExtension: "htm") ?? .html]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose File"
        if panel.runModal() == .OK, let url = panel.url { _ = accept(url) }
    }

    private func accept(_ url: URL) -> Bool {
        guard Source.supportsFile(url) else {
            error = "Choose a PDF, HTML, or HTM file."
            return false
        }
        file = url
        resetStatus()
        return true
    }

    private func chooseDestination() {
        guard let source, progress == nil else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.epub]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.prompt = "Save EPUB"
        let name = previewTitle ?? "Kindle Export"
        panel.nameFieldStringValue = name.replacingOccurrences(of: "/", with: "-") + ".epub"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        resetStatus()
        progress = "Preparing the source…"
        Task {
            let updates = AsyncStream<String>.makeStream(bufferingPolicy: .bufferingNewest(1))
            let operation = Task.detached {
                defer { updates.continuation.finish() }
                return try await Converter.export(source, to: url) { updates.continuation.yield($0) }
            }
            for await message in updates.stream { progress = message }
            defer { progress = nil }
            do {
                let title = try await operation.value
                exported = Export(title: title, file: url)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon.font(.system(size: 8, weight: .semibold))
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(enabled ? Palette.lime : Palette.disabledText)
            .background(
                enabled ? (configuration.isPressed ? Palette.pressed : Palette.moss) : Palette.well,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

enum Palette {
    static let paper = Color(red: 0.976, green: 0.969, blue: 0.939)
    static let input = Color(red: 0.989, green: 0.981, blue: 0.956)
    static let well = Color(red: 0.907, green: 0.912, blue: 0.858)
    static let ink = Color(red: 0.109, green: 0.159, blue: 0.115)
    static let muted = Color(red: 0.305, green: 0.348, blue: 0.294)
    static let rule = Color(red: 0.850, green: 0.858, blue: 0.794)
    static let dashed = Color(red: 0.649, green: 0.691, blue: 0.596)
    static let moss = Color(red: 0.163, green: 0.286, blue: 0.187)
    static let pressed = Color(red: 0.105, green: 0.217, blue: 0.129)
    static let lime = Color(red: 0.899, green: 0.955, blue: 0.635)
    static let paleGreen = Color(red: 0.895, green: 0.927, blue: 0.803)
    static let disabledText = Color(red: 0.342, green: 0.402, blue: 0.307)
    static let failure = Color(red: 0.55, green: 0.19, blue: 0.125)
}
