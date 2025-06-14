import Foundation
import CoreData

@objc(Message)
public class Message: NSManagedObject {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.id = UUID()
        self.timestamp = Date()
    }
}