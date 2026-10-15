public import SwiftUI

public enum Typography {
    public static let title = Font.title2.weight(.semibold)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let caption = Font.caption
    public static let metric = Font.system(.title2, design: .rounded).weight(.bold)
    public static let amount = Font.system(.headline, design: .rounded).weight(.semibold)
}
