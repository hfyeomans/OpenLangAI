import Foundation

enum Language: String, CaseIterable, Identifiable {
    case english = "English"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case japanese = "Japanese"

    var id: String { rawValue }
}
