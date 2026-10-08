import DesignSystem
import Domain
public import SwiftUI

public struct RootView: View {
    @State private var environment: AppEnvironment?
    @State private var router = AppRouter()
    @Environment(\.scenePhase) private var scenePhase

    public init() {
        _environment = State(initialValue: AppEnvironment.makeLive())
    }

    public var body: some View {
        if let environment {
            MainTabView(environment: environment, router: router)
                .task { await environment.start() }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        environment.requestSync(.foreground)
                    }
                }
        } else {
            EmptyStateView(
                systemImage: "externaldrive.badge.exclamationmark",
                title: .navigationStartupErrorTitle,
                message: .navigationStartupErrorMessage
            )
        }
    }
}
