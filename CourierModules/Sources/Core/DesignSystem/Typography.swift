public import SwiftUI

public enum Typography {
    public static let headline = Font.headline
    public static let body = Font.body
    public static let caption = Font.caption
    public static let amount = Font.system(.headline, design: .rounded).weight(.semibold)
}
