import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` for "Launch at Login" toggling.
///
/// Reads/writes the persistent state stored by macOS so the app starts on
/// boot. Only meaningful when running from a real `.app` bundle.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            fputs("LoginItem toggle failed: \(error)\n", stderr)
        }
    }
}
