import Sparkle
import SwiftUI

@Observable
final class UpdateService {
    static let shared = UpdateService()

    private let updaterController: SPUStandardUpdaterController

    var canCheckForUpdates = false

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        canCheckForUpdates = updaterController.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
