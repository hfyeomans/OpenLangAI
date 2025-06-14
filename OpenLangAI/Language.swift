import Foundation

public enum Language: String, CaseIterable, Identifiable {
    case spanish = "Spanish"
    case french = "French"
    case japanese = "Japanese"
    case italian = "Italian"
    case portuguese = "Portuguese"

    public var id: String { rawValue }
    
    public var flag: String {
        switch self {
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .japanese: return "🇯🇵"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        }
    }
}
