import SwiftUI
import Testing

@testable import CourierApp

@MainActor
struct MainViewTests {

    @Test func viewsBuild() {
        let _ = CourierAppApp().body
        let _ = MainView().body
        let _ = SampleFeatureView().body
    }
}
