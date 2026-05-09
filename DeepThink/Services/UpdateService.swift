import Security
import Sparkle
import SwiftUI

private func bundleIsEligibleForSparkle(_ bundle: Bundle) -> Bool {
    if bundle.sparkleLooksSigned { return true }
    if Bundle.main.publicSparkleSigningKeyConfigured { return true }
    return false
}

@MainActor
@Observable
final class UpdateService {
    static let shared = UpdateService()

    private static let hostEligibleForSparkle = bundleIsEligibleForSparkle(.main)

    private var updaterController: SPUStandardUpdaterController?

    /// When Sparkle refuses to run (typically unsigned hosts without SUPublicEDKey), skips startup so SwiftUI touching this service does not show Sparkle's
    /// fatal modal.
    var isEmbedded: Bool {
        Self.hostEligibleForSparkle
    }

    var canCheckForUpdates: Bool {
        guard isEmbedded else { return false }
        return updaterController?.updater.canCheckForUpdates ?? false
    }

    private init() {}

    func prepareIfNeeded() {
        guard isEmbedded, updaterController == nil else { return }
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        guard isEmbedded else { return }
        prepareIfNeeded()
        updaterController?.checkForUpdates(nil)
    }
}

private extension Bundle {
    var publicSparkleSigningKeyConfigured: Bool {
        guard let key = object(forInfoDictionaryKey: "SUPublicEDKey") as? String else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Same gate Sparkle applies: `-bundleAtURLIsCodeSigned:` treats errSecCSUnsigned as not signed.
    var sparkleLooksSigned: Bool {
        guard let url = bundleURL as CFURL? else { return false }
        var staticCode: SecStaticCode?
        let created = SecStaticCodeCreateWithPath(url, [], &staticCode)
        if created == errSecCSUnsigned {
            return false
        }
        guard created == errSecSuccess, let code = staticCode else { return false }
        var requirement: SecRequirement?
        let reqResult = SecCodeCopyDesignatedRequirement(code, [], &requirement)
        _ = requirement
        if reqResult == errSecCSUnsigned {
            return false
        }
        return reqResult == errSecSuccess
    }
}
