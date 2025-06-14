import Foundation
import CoreData

extension Conversation {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Conversation> {
        return NSFetchRequest<Conversation>(entityName: "Conversation")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var language: String?
    @NSManaged public var userLevel: String?
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var messages: NSSet?
    @NSManaged public var vocabularyItems: NSSet?
}

// MARK: Generated accessors for messages
extension Conversation {
    
    @objc(addMessagesObject:)
    @NSManaged public func addToMessages(_ value: Message)
    
    @objc(removeMessagesObject:)
    @NSManaged public func removeFromMessages(_ value: Message)
    
    @objc(addMessages:)
    @NSManaged public func addToMessages(_ values: NSSet)
    
    @objc(removeMessages:)
    @NSManaged public func removeFromMessages(_ values: NSSet)
}

// MARK: Generated accessors for vocabularyItems
extension Conversation {
    
    @objc(addVocabularyItemsObject:)
    @NSManaged public func addToVocabularyItems(_ value: VocabularyItem)
    
    @objc(removeVocabularyItemsObject:)
    @NSManaged public func removeFromVocabularyItems(_ value: VocabularyItem)
    
    @objc(addVocabularyItems:)
    @NSManaged public func addToVocabularyItems(_ values: NSSet)
    
    @objc(removeVocabularyItems:)
    @NSManaged public func removeFromVocabularyItems(_ values: NSSet)
}