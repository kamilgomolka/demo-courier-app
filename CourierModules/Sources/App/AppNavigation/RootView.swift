import DesignSystem
import Domain
public import SwiftUI

public struct RootView: View {
    @State private var environment: AppEnvironment?
    @State private var didFailToStart = false
    @State private var router = AppRouter()
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        Group {
            if let environment {
                MainTabView(environment: environment, router: router)
                    .task { await environment.start() }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            environment.requestSync(.foreground)
                        }
                    }
            } else if didFailToStart {
                EmptyStateView(
                    systemImage: "externaldrive.badge.exclamationmark",
                    title: .navigationStartupErrorTitle,
                    message: .navigationStartupErrorMessage
                )
            }
        }
        .task {
            guard environment == nil, !didFailToStart else { return }
            environment = AppEnvironment.makeLive()
            didFailToStart = environment == nil
        }
    }
}
