import Foundation
import SwiftUI

enum AppConstants {
    static let appName = "MacPulse"
    static let widgetKind = "com.macpulse.local.MacPulse.widget"
    static let sharedPayloadFilename = "macpulse-payload.json"
    static let sharedPayloadKey = "sharedPayload"
    static let payloadSchemaVersion = 4
}

extension Color {
    /// Returns a reactive color transitioning from green (low) >> orange (medium) >> red (high load).
    static func reactiveMetric(for percentage: Double) -> Color {
        let p = min(max(percentage, 0.0), 100.0)
        if p <= 40.0 {
            return .green
        } else if p <= 70.0 {
            // Smooth transition from Green (~0.38) to Orange (~0.10)
            let t = (p - 40.0) / 30.0
            let hue = 0.38 - (t * 0.28)
            return Color(hue: hue, saturation: 0.85, brightness: 0.90)
        } else if p <= 90.0 {
            // Smooth transition from Orange (~0.10) to Red (~0.00)
            let t = (p - 70.0) / 20.0
            let hue = max(0.10 - (t * 0.10), 0.0)
            return Color(hue: hue, saturation: 0.88, brightness: 0.95)
        } else {
            return .red
        }
    }
}
