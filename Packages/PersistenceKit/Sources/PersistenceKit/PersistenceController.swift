import CoreData
import Foundation

public class PersistenceController {
    public static let shared = PersistenceController()
    
    public let container: NSPersistentCloudKitContainer
    
    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    private init() {
        container = NSPersistentCloudKitContainer(name: "OpenLangAI")
        
        // Configure for CloudKit sync
        container.persistentStoreDescriptions.forEach { description in
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    public func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
    
    // MARK: - Conversation Management
    
    public func createConversation(language: String, userLevel: String) -> Conversation {
        let conversation = Conversation(context: viewContext)
        conversation.language = language
        conversation.userLevel = userLevel
        save()
        return conversation
    }
    
    public func endConversation(_ conversation: Conversation) {
        conversation.endTime = Date()
        updateUserProgress(for: conversation)
        save()
    }
    
    public func addMessage(to conversation: Conversation, text: String, isUser: Bool, translation: String? = nil) -> Message {
        let message = Message(context: viewContext)
        message.text = text
        message.isUser = isUser
        message.translation = translation
        conversation.addToMessages(message)
        save()
        return message
    }
    
    // MARK: - User Progress Management
    
    public func fetchOrCreateUserProgress(for language: String) -> UserProgress {
        let request = UserProgress.fetchRequest()
        request.predicate = NSPredicate(format: "language == %@", language)
        
        do {
            if let progress = try viewContext.fetch(request).first {
                return progress
            }
        } catch {
            print("Failed to fetch user progress: \(error)")
        }
        
        // Create new progress
        let progress = UserProgress(context: viewContext)
        progress.language = language
        save()
        return progress
    }
    
    private func updateUserProgress(for conversation: Conversation) {
        guard let language = conversation.language else { return }
        
        let progress = fetchOrCreateUserProgress(for: language)
        progress.totalSessions += 1
        progress.totalMinutesPracticed += Int32(conversation.duration / 60)
        progress.lastSessionDate = Date()
        progress.updateStreak()
        save()
    }
    
    // MARK: - Vocabulary Management
    
    public func addVocabularyItem(to conversation: Conversation, word: String, translation: String? = nil, definition: String? = nil) -> VocabularyItem {
        let item = VocabularyItem(context: viewContext)
        item.word = word
        item.translation = translation
        item.definition = definition
        conversation.addToVocabularyItems(item)
        save()
        return item
    }
    
    public func fetchVocabularyForReview(language: String) -> [VocabularyItem] {
        let request = VocabularyItem.fetchRequest()
        request.predicate = NSPredicate(format: "conversation.language == %@ AND nextReviewDate <= %@", language, Date() as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "nextReviewDate", ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Failed to fetch vocabulary for review: \(error)")
            return []
        }
    }
    
    // MARK: - Fetch Conversations
    
    public func fetchRecentConversations(limit: Int = 10) -> [Conversation] {
        let request = Conversation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Failed to fetch conversations: \(error)")
            return []
        }
    }
}