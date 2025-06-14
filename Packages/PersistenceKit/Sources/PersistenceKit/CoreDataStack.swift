import CoreData

public final class CoreDataStack {
    public static let shared = CoreDataStack()
    public let persistentContainer: NSPersistentContainer

    private init() {
        persistentContainer = NSPersistentCloudKitContainer(name: "OpenLangAI")
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unresolved error \(error)")
            }
        }
    }

    public var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    public func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
