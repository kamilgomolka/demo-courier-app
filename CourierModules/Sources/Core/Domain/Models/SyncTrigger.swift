public enum SyncTrigger: Sendable {
    case launch
    case foreground
    case screenAppeared
    case connectivityRestored
    case manual
}
