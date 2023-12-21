//
//  BBCloudManager.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 11/21/23.
//

import Foundation
import CloudKit
import CoreData
import UserNotifications
import Combine

#if os(macOS)
    import AppKit

#endif

class CloudManager:NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var state:CloudState = .unknown
    @Published var id:String? = nil
    @Published var syncing:CloudSyncedState = .syncing

    static var shared = CloudManager()

    private var updates = Set<AnyCancellable>()

    static var container: CloudContainerObject? = {
        let object = "BBDataObject"
        let container = NSPersistentCloudKitContainer(name: object)
        
        var directory: URL?
        var subdirectory: URL?
        
        guard let description = container.persistentStoreDescriptions.first else {
            #if DEBUG
                fatalError("No Description found")
            #else
                return nil
            #endif
            
        }
        
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.ovatar.batteryboi")
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last {
            let parent = support.appendingPathComponent("BatteryBoi")

            do {
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
                
                subdirectory = parent
                directory = parent.appendingPathComponent("\(object).sqlite")

                print("\n\nSQL File: \(directory?.absoluteString ?? "")\n\n")

            } 
            catch {
                print("Error creating or setting SQLite store URL: \(error)")
                
            }
            
        } 
        else {
            print("Error retrieving Application Support directory URL.")
            
        }

        if let directory = directory {
            DispatchQueue.global(qos: .userInitiated).async {
                if container.persistentStoreDescriptions.contains(where: { $0.url == description.url }) == false {
                    container.persistentStoreDescriptions.append(description)
                    
                }  
                
                container.viewContext.automaticallyMergesChangesFromParent = true
                container.loadPersistentStores { (storeDescription, error) in
                    if let error = error {
                        DispatchQueue.main.async {
                            CloudManager.shared.syncing = .error

                            #if DEBUG
                                fatalError("iCloud Error \(error)")
                            #endif

                        }
                        
                    }
                    else {
                        DispatchQueue.main.async {
                            CloudManager.shared.syncing = .completed
                            AppManager.shared.updated = Date()
                            
                        }
                        
                    }
                    
                }
                
            }

        }
        else {
            fatalError("Directory Not Found")
            
        }
        
        return .init(container: container, directory: directory, parent: subdirectory)
        
    }()
    
    override init() {
        super.init()

        if let id = Bundle.main.infoDictionary?["ENV_ICLOUD_ID"] as? String  {
            CKContainer(identifier: id).accountStatus { status, error in
                if status == .available {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.cloudOwnerInformation()
                        
                    }
                    
                }
                
            }
                        
        }
        else {
            #if DEBUG
                fatalError("Cloud ID Enviroment is Missing")

            #endif

        }
        
        #if os(iOS)
            $state.removeDuplicates().delay(for: .seconds(0.2), scheduler: RunLoop.main).sink { state in
                 if state == .enabled {
                     self.cloudSubscriptionsSetup(.alerts)
                     self.cloudSubscriptionsSetup(.events)

                 }
                     
            }.store(in: &updates)
        
        #endif
    
        NotificationCenter.default.addObserver(self, selector: #selector(cloudContextDidChange(notification:)), name: .NSManagedObjectContextObjectsDidChange, object: nil)
        
    }
    
    public func cloudAllowNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options:[.alert, .carPlay, .sound]) { granted, error in
                    DispatchQueue.main.async {
                        self.cloudOwnerInformation()

                    }
                    
                }
                                
            }
            
        }
        
    }
    
    private func cloudOwnerInformation() {
        if let id = Bundle.main.infoDictionary?["ENV_ICLOUD_ID"] as? String  {
            CKContainer(identifier: id).fetchUserRecordID { id, error in
                if let id = id {
                    UNUserNotificationCenter.current().getNotificationSettings { settings in
                        DispatchQueue.main.async {
                            switch settings.authorizationStatus {
                                case .authorized: self.state = .enabled
                                default : self.state = .blocked
                                
                            }
                            
                            self.id = id.recordName
                            
                        }
                                                
                    }
                                        
                }
                                
            }
            
        }
        
    }
    
    private func cloudSubscriptionsSetup(_ type:CloudSubscriptionsType) {
        if let id = Bundle.main.infoDictionary?["ENV_ICLOUD_ID"] as? String  {
            let predicate = NSPredicate(value: true)
            let subscription = CKQuerySubscription(recordType: type.record, predicate: predicate, subscriptionID: type.identifyer, options:type.options)
            
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            
            subscription.notificationInfo = info
            
            let database = CKContainer(identifier: id).privateCloudDatabase
            database.save(subscription) { (savedSubscription, error) in
                if let error = error {
                    print("An error occurred: \(error.localizedDescription)")
                    
                }
                else {
                    print("Subscription saved successfully!")
                    
                }
                
            }
            
        }
        
    }
    
    @objc func cloudContextDidChange(notification: Notification) {
        if let userInfo = notification.userInfo {
            if userInfo[NSInsertedObjectsKey] != nil || userInfo[NSUpdatedObjectsKey] != nil || userInfo[NSDeletedObjectsKey] != nil {
                DispatchQueue.main.async {
                    AppManager.shared.updated = Date()

                }
                
            }
            
        }
        
    }
    
}
