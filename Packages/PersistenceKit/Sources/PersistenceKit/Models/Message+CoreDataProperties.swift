import Foundation
import CoreData

extension Message {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Message> {
        return NSFetchRequest<Message>(entityName: "Message")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var text: String?
    @NSManaged public var translation: String?
    @NSManaged public var isUser: Bool
    @NSManaged public var timestamp: Date?
    @NSManaged public var conversation: Conversation?
}