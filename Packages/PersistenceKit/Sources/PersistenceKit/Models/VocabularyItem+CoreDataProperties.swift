import Foundation
import CoreData

extension VocabularyItem {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<VocabularyItem> {
        return NSFetchRequest<VocabularyItem>(entityName: "VocabularyItem")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var word: String?
    @NSManaged public var translation: String?
    @NSManaged public var definition: String?
    @NSManaged public var exampleSentence: String?
    @NSManaged public var reviewCount: Int32
    @NSManaged public var lastReviewedDate: Date?
    @NSManaged public var nextReviewDate: Date?
    @NSManaged public var conversation: Conversation?
}