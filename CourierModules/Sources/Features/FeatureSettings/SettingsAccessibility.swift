enum SettingsAccessibility {
    static let offlineToggle = "settings.offlineToggle"
    static let syncNowButton = "settings.syncNowButton"
    static let resetButton = "settings.resetButton"
    static let resetConfirmButton = "settings.resetConfirmButton"

    static func job(id: String) -> String {
        "settings.job.\(id)"
    }
}
