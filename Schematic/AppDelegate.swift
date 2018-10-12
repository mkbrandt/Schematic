//
//  AppDelegate.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa
import CloudKit

var icloudUser: CKRecordID?
var icloudUserRecord: CKRecord?

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Defaults.register(defaults: initialUserDefaults)
        SchematicDocument.installScripts()
        
        NSApp.registerForRemoteNotifications(matching: [])
        
        CKContainer.default().accountStatus { (status, error) in
            if status == CKAccountStatus.noAccount {
                let alert = NSAlert()
                alert.messageText = "Please login to your iCloud Account"
                alert.informativeText = "Unless you log in, you will not be able to save parts in the cloud database. You can login in System Preferences: iCloud"
                alert.runModal()
            }
            
            CKContainer.default().requestApplicationPermission(.userDiscoverability, completionHandler: { (status, error) in
                if status != CKApplicationPermissionStatus.granted {
                    print("Denied...")
                }
            })
            
            CKContainer.default().fetchUserRecordID(completionHandler: { (recordID, error) in
                if let error = error {
                    print("Error retrieving user ID: \(error)")
                }
                icloudUser = recordID
                print("iCloud user is: \(String(describing: icloudUser?.recordName))")
                if let user = icloudUser {
                    cloudDatabase.fetch(withRecordID: user, completionHandler: { (userRecord, error) in
                        if let error = error {
                            print("Error fetching user record: \(error)")
                        }
                        if let userRecord = userRecord {
                            icloudUserRecord = userRecord
                            if let launchCount = userRecord["launches"] as? Int {
                                userRecord["launches"] = launchCount + 1 as CKRecordValue
                            } else {
                                userRecord["launches"] = 1 as CKRecordValue
                            }
                            let op = CKModifyRecordsOperation(recordsToSave: [userRecord], recordIDsToDelete: [])
                            cloudDatabase.add(op)
                        }
                    })
                }
            })
        }
    }
    
    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("did register")
    }
    
    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("failed to register: \(error)")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        print("Received notification: \(userInfo)")
        if let userInfo = userInfo as? [String: NSObject] {
            let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
            cloudLibrary.handleNotification(notification: notification)
        }
    }
}

