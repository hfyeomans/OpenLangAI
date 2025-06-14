import Foundation
import CoreData

extension UserProgress {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserProgress> {
        return NSFetchRequest<UserProgress>(entityName: "UserProgress")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var language: String?
    @NSManaged public var totalSessions: Int32
    @NSManaged public var totalMinutesPracticed: Int32
    @NSManaged public var currentStreak: Int32
    @NSManaged public var longestStreak: Int32
    @NSManaged public var lastSessionDate: Date?
}