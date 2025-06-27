import CoreData

public final class CoreDataStack {
    public static let shared = CoreDataStack()
    public let persistentContainer: NSPersistentContainer

    private init() {
        // First try to find the model in the framework bundle
        let bundle = Bundle(for: CoreDataStack.self)
        
        // Try to find the compiled model (.momd)
        var modelURL = bundle.url(forResource: "OpenLangAI", withExtension: "momd")
        
        // If not found, try the model definition (.xcdatamodeld)
        if modelURL == nil {
            modelURL = bundle.url(forResource: "OpenLangAI", withExtension: "xcdatamodeld")
        }
        
        // If still not found, try Bundle.main as a fallback
        if modelURL == nil {
            modelURL = Bundle.main.url(forResource: "OpenLangAI", withExtension: "momd")
        }
        
        guard let finalModelURL = modelURL else {
            fatalError("Failed to find data model in bundle: \(bundle)")
        }
        
        guard let mom = NSManagedObjectModel(contentsOf: finalModelURL) else {
            fatalError("Failed to create model from file: \(finalModelURL)")
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
