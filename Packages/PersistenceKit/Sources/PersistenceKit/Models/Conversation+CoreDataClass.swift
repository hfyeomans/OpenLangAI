import Foundation
import CoreData

@objc(Conversation)
public class Conversation: NSManagedObject {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.id = UUID()
        self.startTime = Date()
    }
    
    public var duration: TimeInterval {
        guard let endTime = endTime else { return 0 }
        return endTime.timeIntervalSince(startTime ?? Date())
    }
    
    public var messageArray: [Message] {
        let set = messages as? Set<Message> ?? []
        return set.sorted { $0.timestamp ?? Date() < $1.timestamp ?? Date() }
    }
    
    public var vocabularyArray: [VocabularyItem] {
        let set = vocabularyItems as? Set<VocabularyItem> ?? []
        return set.sorted { $0.word ?? "" < $1.word ?? "" }
    }
}