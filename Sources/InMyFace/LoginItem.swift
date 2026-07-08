import Foundation
import ServiceManagement

/// Registers/unregisters InMyFace as a login item via SMAppService (macOS 13+).
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Apply the desired state. Returns the effective state afterward.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("InMyFace: login item update failed: \(error)")
        }
        return isEnabled
    }

    /// Reconcile the OS registration with the saved preference at launch.
    static func reconcile(desired: Bool) {
        if desired != isEnabled {
            setEnabled(desired)
        }
    }
}
