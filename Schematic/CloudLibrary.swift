//
//  CloudLibrary.swift
//  Schematic
//
//  Created by Matt Brandt on 6/22/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa
import CloudKit

let cloudDatabase = CKContainer.default().publicCloudDatabase

let defaultCategories: [String: [String]] = [
    "Symbols": [],
    "Connectors": [
        "Header", "Edge", "DB", "RJ", "Audio", "Power", "Bus", "Debug"
    ],
    "Mechanical": [],
    "IC": [
        "Memory", "74ALS", "PLD", "Micro Controllers", "Processors", "Power Supply", "Audio", "Analog", "RF", "Networking", "Bus Control"
    ],
    "Active Discretes": [
        "Small Signal", "Power", "SCR/TRIAC"
    ],
    "Resistors": [],
    "Capacitors": [],
    "Inductors": [],
    "Transformers": []
]

var categoriesCreated = false
var cloudLibrary = CloudLibrary()

class CloudLibrary: SchematicDocument
{
    var changeToken: CKServerChangeToken?
    var records: [CKRecordID: CKRecord] = [:]
    
    override var name: String { return "iCloud Library" }

    override init() {
        do {
            super.init()
            schematic.pages = []
            let cacheDirectory = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let fileURL = cacheDirectory.appendingPathComponent("iCloudLibrary.sch")
            self.fileURL = fileURL
            try read(from: fileURL, ofType: "sch")
            Swift.print("iCloud cache opened")
        } catch (let error) {
            Swift.print("Creating icloud library cache: \(error)")
            if let fileURL = fileURL {
                _ = try? write(to: fileURL, ofType: "sch")
            }
        }
        Swift.print("Syncing from cloud")
        syncCategoriesFromCloud()
        registerForNotifications()
    }
    
    func didModify(forceWrite: Bool = false) {
        if let fileURL = fileURL, forceWrite {
            _ = try? write(to: fileURL, ofType: "sch")
        } else if self.undoManager?.canUndo ?? false {
            self.undoManager?.undo()
        } else {
            self.undoManager?.registerUndo(withTarget: self, handler: {_ in })
        }
        notifyChange()
    }
    
    func pageFor(recordID: CKRecordID) -> SchematicPage? {
        for page in pages {
            if page.record?.recordID == recordID {
                return page
            }
        }
        return nil
    }
    
    func pageFor(record: CKRecord, create: Bool = true) -> SchematicPage? {
        if let page = pageFor(recordID: record.recordID) {
            let newParent = parentPage(record: record)
            if let newName = record["name"] as? String, newParent != page.parentPage || page.name != newName {
                page.parentPage = newParent
                page.name = newName
                page.record = record
                didModify()
            }
            return page
        } else if create {
            let page = SchematicPage()
            if let name = record["name"] as? String {
                page.name = name
            }
            page.parentPage = parentPage(record: record)
            page.record = record
            schematic.pages.append(page)
            didModify()
            return page
        }
        return nil
    }
    
    func parentPage(record: CKRecord) -> SchematicPage? {
        if let owner = record["owner"] as? CKReference {
            if let page = pageFor(recordID: owner.recordID) {
                return page
            }
        }
        return nil
    }
    
    func pageFixup() {
        for page in pages {
            if let record = page.record {
                page.parentPage = parentPage(record: record)
            }
        }
        didModify()
    }
    
    func componentFor(recordID: CKRecordID) -> Component? {
        for component in components {
            if component.record?.recordID == recordID {
                return component
            }
        }
        return nil
    }
    
    func componentFor(record: CKRecord, create: Bool = true) -> Component? {
        for component in components {
            if let componentRecord = component.record {
                if componentRecord.recordID == record.recordID {
                    if component.record?.recordChangeTag != record.recordChangeTag {
                        if let oldPage = parentPage(record: componentRecord),
                        let newPage = parentPage(record: record),
                        let data = record["data"] as? Data,
                        let newComponent = NSKeyedUnarchiver.unarchiveObject(with: data) as? Component {
                            newComponent.record = record
                            oldPage.displayList.remove(component)
                            newPage.displayList.insert(newComponent)
                            didModify()
                            return newComponent
                        }
                    } else {
                        return component
                    }
                }
            }
        }
        if create {
            if let data = record["data"] as? Data,
                let component = NSKeyedUnarchiver.unarchiveObject(with: data) as? Component {
                component.record = record
                if let page = parentPage(record: record) {
                    page.displayList.insert(component)
                    didModify(forceWrite: false)
                    return component
                } else {
                    Swift.print("Couldn't find page for component: \(component.name)")
                }
            }
        }
        return nil
    }
    
    override func insert(components: [Component], in page: SchematicPage) {
        if let parentRecord = page.record {
            var records: [CKRecord] = []
            for comp in components {
                let record = CKRecord(recordType: "Component")
                record["name"] = (comp.package?.partNumber ?? comp.value ?? "UNNAMED") as CKRecordValue
                comp.record = nil       // don't save the record in the archive to go to the server
                record["data"] = NSKeyedArchiver.archivedData(withRootObject: comp) as CKRecordValue
                record["owner"] = CKReference(record: parentRecord, action: .deleteSelf)
                comp.record = record
                records.append(record)
            }
            let writeOp = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [])
            writeOp.modifyRecordsCompletionBlock = { (saved, deleted, error) in
                if let error = error {
                    Swift.print("Error saving \(records.count) records to server: \(error)")
                }
                if let saved = saved {
                    Swift.print("\(saved.count) components written to server")
                }
            }
            cloudDatabase.add(writeOp)
            super.insert(components: components, in: page)
        }
        didModify(forceWrite: true)
    }
    
    func updateRecord(record: CKRecord) {
        records[record.recordID] = record
        switch record.recordType {
        case "Category":
            let _ = pageFor(record: record)
        case "Component":
            let _ = componentFor(record: record)
        default:
            Swift.print("unknown record type: \(record.recordType)")
        }
    }
    
    func createCategory(name: String, subs: [String], owner: CKRecord?) {
        let category = CKRecord(recordType: "Category")
        category["name"] = name as CKRecordValue
        if let owner = owner {
            category["owner"] = CKReference(record: owner, action: .deleteSelf)
        }
        updateRecord(record: category)
        for sub in subs {
            createCategory(name: sub, subs: [], owner: category)
        }
    }
    
    func createDefaultCategories() {
        guard categoriesCreated == false else { return }
        categoriesCreated = true
        for (name, subs) in defaultCategories {
            createCategory(name: name, subs: subs, owner: nil)
        }
        let savedRecords = Array(records.values.filter { $0.recordType == "Category" })
        let op = CKModifyRecordsOperation(recordsToSave: savedRecords, recordIDsToDelete: [])
        op.savePolicy = .allKeys
        op.modifyRecordsCompletionBlock = { saved, deleted, error in
            if let error = error {
                Swift.print("Error creating default categories: \(error)")
            } else {
                Swift.print("\(String(describing: saved?.count)) Default categories created, deleted = \(String(describing: deleted?.count))")
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
                self.syncCategoriesFromCloud()
            }
        }
        cloudDatabase.add(op)
    }
    
    func fetchRecords(recordIDs: [CKRecordID]) {
        let fetch = CKFetchRecordsOperation(recordIDs: recordIDs)
        fetch.fetchRecordsCompletionBlock = { dict, error in
            if let error = error {
                Swift.print("unknown error in fetch records: \(error)")
            }
            if let dict = dict {
                for (_, record) in dict {
                    self.updateRecord(record: record)
                }
            }
        }
        cloudDatabase.add(fetch)
    }
    
    override func add(page: SchematicPage, to parent: SchematicPage?) {
        let record = CKRecord(recordType: "Category")
        record["name"] = page.name as CKRecordValue
        if let parentRecord = parent?.record {
            record["owner"] = CKReference(record: parentRecord, action: .deleteSelf)
        }
        let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: [])
        op.savePolicy = .ifServerRecordUnchanged
        op.qualityOfService = .userInitiated
        op.modifyRecordsCompletionBlock = { (saved, deleted, error) in
            if let error = error {
                Swift.print("Error creating category \(page.name) as child of \(String(describing: parent?.name)): \(error)")
            } else {
                page.record = record
                super.add(page: page, to: parent)
            }
        }
        cloudDatabase.add(op)
        didModify(forceWrite: true)
    }
    
    func delete(page: SchematicPage, fromCloud: Bool) {
        let components = page.components
        if fromCloud {
            if let record = page.record {
                cloudDatabase.delete(withRecordID: record.recordID, completionHandler: { (recordID, error) in
                    if let error = error {
                        Swift.print("Error deleting page \(page.name) from cloud: \(error)")
                        return
                    } else {
                        Swift.print("page \(page.name) deleted from cloud")
                        DispatchQueue.main.async {
                            self.delete(page: page, fromCloud: false)
                        }
                    }
                })
            }
            return
        }
        // local delete
        for component in components {
            delete(component: component, fromCloud: false)
        }
        if let index = schematic.pages.index(of: page) {
            page.parentPage = nil
            schematic.pages.remove(at: index)
            Swift.print("page \(page.name) deleted")
        }
        if let recordID = page.record?.recordID {
            records[recordID] = nil
        }
        didModify(forceWrite: true)
    }
    
    func delete(component: Component, fromCloud: Bool) {
        Swift.print("Deleting component \(component.name), fromCloud = \(fromCloud)")
        if fromCloud {
            if let record = component.record {
                cloudDatabase.delete(withRecordID: record.recordID, completionHandler: { (recordID, error) in
                    if let error = error {
                        Swift.print("Error deleting component \(component.name) from cloud: \(error)")
                        return
                    } else {
                        Swift.print("component \(component.name) deleted from cloud")
                        DispatchQueue.main.async {
                            self.delete(component: component, fromCloud: false)
                        }
                    }
                })
            }
        }
        if let record = component.record,
            let page = parentPage(record: record),
            let index = page.displayList.index(of: component) {
            page.displayList.remove(at: index)
            records[record.recordID] = nil
        }
        didModify(forceWrite: true)
    }
    
    override func delete(page: SchematicPage) {
        delete(page: page, fromCloud: true)
        didModify(forceWrite: true)
    }
    
    override func delete(component: Component) {
        delete(component: component, fromCloud: true)
        didModify(forceWrite: true)
    }
    
    func deleteRecords(recordIDs: [CKRecordID]) {
        for recordID in recordIDs {
            if let page = pageFor(recordID: recordID) {
                delete(page: page, fromCloud: false)
            } else if let component = componentFor(recordID: recordID) {
                delete(component: component, fromCloud: false)
            }
        }
    }
    
    func fetchAllComponents() {
        let fetch = CKQuery(recordType: "Component", predicate: NSPredicate(value: true))
        cloudDatabase.perform(fetch, inZoneWith: nil) { (records, error) in
            if let error = error {
                Swift.print("Error fetching components: \(error)")
            }
            if let records = records {
                Swift.print("\(records.count) Components retrieved")
                for record in records {
                    self.updateRecord(record: record)
                }
            }
        }
        DispatchQueue.main.async {
            self.didModify(forceWrite: true)
        }
    }
    
    func syncChangesFromCloud() {
        var pendingChanges: Set<CKRecordID> = []
        var pendingDeletes: Set<CKRecordID> = []
        let op = CKFetchNotificationChangesOperation(previousServerChangeToken: changeToken)
        op.fetchNotificationChangesCompletionBlock = { changeToken, error in
            if self.changeToken == nil {
                self.fetchAllComponents()
            } else {
                self.fetchRecords(recordIDs: Array(pendingChanges))
                self.deleteRecords(recordIDs: Array(pendingDeletes))
            }
            self.changeToken = changeToken
            DispatchQueue.main.async {
                self.didModify(forceWrite: true)
            }
        }
        
        op.notificationChangedBlock = { notification in
            if let notification = notification as? CKQueryNotification {
                if let recordID = notification.recordID {
                    if notification.queryNotificationReason == .recordDeleted {
                        pendingDeletes.insert(recordID)
                    } else {    // change or create record
                        pendingChanges.insert(recordID)
                    }
                }
            }
        }
        CKContainer.default().add(op)
    }
    
    func syncCategoriesFromCloud() {
        let query = CKQuery(recordType: "Category", predicate: NSPredicate(value: true))
        cloudDatabase.perform(query, inZoneWith: nil) { (records, error) in
            if let error = error {
                switch error._code {
                default:
                    Swift.print("Unknown error in syncFromCloud: \(error)")
                }
            } else if let records = records {
                if records.count == 0 {
                    self.createDefaultCategories()
                    return
                }
                for record in records {
                    self.updateRecord(record: record)
                }
                self.pageFixup()
                self.syncChangesFromCloud()
            }
        }
    }
    
    func handleNotification(notification: CKNotification) {
        Swift.print("Notification received")
        syncChangesFromCloud()
    }
    
    func registerForNotifications() {
        let all: CKSubscriptionOptions = [.firesOnRecordUpdate, .firesOnRecordCreation, .firesOnRecordDeletion]
        let info = CKNotificationInfo()
        info.shouldBadge = false
        info.shouldSendContentAvailable = false
        info.alertBody = ""
        info.soundName = ""
        let categorySubscription = CKSubscription(recordType: "Category", predicate: NSPredicate(value: true), options: all)
        categorySubscription.notificationInfo = info
        cloudDatabase.save(categorySubscription) { subscription, error in
            if let error = error {
                switch (error._domain, error._code) {
                case (CKErrorDomain, CKError.serverRejectedRequest.rawValue):
                    // ignore this since it is probably just a duplicate subscription
                    break
                default:
                    Swift.print("subscribe error: \(error) for categories")
                }
            } else if let subscription = subscription {
                Swift.print("subscription \(subscription) active")
            }
        }
        
        let componentSubscription = CKSubscription(recordType: "Component", predicate: NSPredicate(value: true), options: all)
        componentSubscription.notificationInfo = info
        cloudDatabase.save(componentSubscription) { subscription, error in
            if let error = error {
                switch (error._domain, error._code) {
                case (CKErrorDomain, CKError.serverRejectedRequest.rawValue):
                    // ignore this since it is probably just a duplicate subscription
                    break
                default:
                    Swift.print("subscribe error: \(error) for components")
                }
            } else if let subscription = subscription {
                Swift.print("subscription \(subscription) active")
            }
        }
    }
}
