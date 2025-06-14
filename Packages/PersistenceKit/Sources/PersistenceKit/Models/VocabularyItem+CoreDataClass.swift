import Foundation
import CoreData

@objc(VocabularyItem)
public class VocabularyItem: NSManagedObject {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.id = UUID()
        self.reviewCount = 0
    }
    
    public func scheduleNextReview() {
        let intervals = [1, 3, 7, 14, 30, 90] // Days for spaced repetition
        let index = min(Int(reviewCount), intervals.count - 1)
        let daysToAdd = intervals[index]
        
        nextReviewDate = Calendar.current.date(byAdding: .day, value: daysToAdd, to: Date())
        lastReviewedDate = Date()
        reviewCount += 1
    }
}