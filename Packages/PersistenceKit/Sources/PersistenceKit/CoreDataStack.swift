import CoreData

public final class CoreDataStack {
    public static let shared = CoreDataStack()
    public let persistentContainer: NSPersistentContainer

    private init() {
        guard let modelURL = Bundle.main.url(forResource: "OpenLangAI", withExtension: "momd") else {
            fatalError("Failed to find data model")
        }
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to create model from file: \(modelURL)")
        }
        
        persistentContainer = NSPersistentCloudKitContainer(name: "OpenLangAI", managedObjectModel: mom)
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
