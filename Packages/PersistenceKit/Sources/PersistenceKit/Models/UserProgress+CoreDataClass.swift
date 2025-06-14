import Foundation
import CoreData

@objc(UserProgress)
public class UserProgress: NSManagedObject {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.id = UUID()
    }
    
    public func updateStreak() {
        guard let lastSession = lastSessionDate else {
            currentStreak = 1
            longestStreak = max(longestStreak, 1)
            return
        }
        
        let calendar = Calendar.current
        let daysSinceLastSession = calendar.dateComponents([.day], from: lastSession, to: Date()).day ?? 0
        
        if daysSinceLastSession == 1 {
            // Consecutive day
            currentStreak += 1
        } else if daysSinceLastSession > 1 {
            // Streak broken
            currentStreak = 1
        }
        // If daysSinceLastSession == 0, same day, don't update streak
        
        longestStreak = max(longestStreak, currentStreak)
    }
}