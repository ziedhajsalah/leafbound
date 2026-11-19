import Combine
import Sparkle
import SwiftUI

struct CheckForUpdatesMenuItem: View {
    private let updater: SPUUpdater
    @StateObject private var availability: UpdateCheckAvailability

    init(updater: SPUUpdater) {
        self.updater = updater
        _availability = StateObject(wrappedValue: UpdateCheckAvailability(updater: updater))
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!availability.canCheck)
    }
}

@MainActor
private final class UpdateCheckAvailability: ObservableObject {
    @Published private(set) var canCheck = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheck)
    }
}
