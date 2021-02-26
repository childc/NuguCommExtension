//
//  ContactsUtil.swift
//  NuguComms
//
//  Created by chidlc on 2021/02/24.
//

import Foundation
import Contacts
import os.log

import NuguCore
import NuguAgents

import RxSwift

public enum ContactMatchType: Int32 {
    case exact
    case partial
}

public class ContactsUtil {
    public static let shared = ContactsUtil()
    private let MaxContactCount = 10000
    private let maxRecipientCount = 70
    
    let contactStore = CNContactStore()
    private let contactsQueue: DispatchQueue = DispatchQueue(label: "ContactsUtilQueue")
    private var contactsWorkItem: DispatchWorkItem?
    private var contacts: [CNContact]?
    private var notificationObserver: NSObjectProtocol?
    
    private let disposeBag = DisposeBag()
    
    private init() {
        refreshLocalContacts()
        addContactsObserver()
    }
    
    deinit {
        removeContactObserver()
    }
    
    private func isGranted() -> Bool {
        let authorizationStatus = CNContactStore.authorizationStatus(for: CNEntityType.contacts)
        return authorizationStatus == .authorized
    }
    
    public func refreshLocalContacts() {
        contactsQueue.async { [unowned self] in
            self.contacts = getAllContacts()
        }
    }
    
    public func getLocalContact(complete: @escaping ([CNContact]?) -> Void) {
        contactsQueue.async { [unowned self] in
            complete(self.contacts)
        }
    }
    
    private func getAllContacts() -> [CNContact] {
        var contacts = [CNContact]()
        let keys = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPhoneNumbersKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        do {
            try contactStore.enumerateContacts(with: request) { (contact, _) in
                // 전화번호가 있는 연락처만 가져온다.
                if 0 < contact.phoneNumbers.count {
                    contacts.append(contact)
                }
            }
        } catch {
            os_log("unable to fetch contacts in sendContactsToServer")
        }
        
        contacts.sort { (contact1, contact2) -> Bool in
            let fullName1 = contact1.familyName + contact1.givenName
            let fullName2 = contact2.familyName + contact2.givenName
            return fullName1.count < fullName2.count
        }
        
        return contacts
    }
}

// MARK: - Search
public extension ContactsUtil {
    func searchByName(names: [String], type: ContactMatchType, complete: @escaping (ContactMatchType, [CNContact]) -> Void) {
        contactsQueue.async { [unowned self] in
            guard let contacts = self.contacts else {
                complete(type, [CNContact]())
                return
            }
            
            var exactlyMatchedContacts = [CNContact]()
            for name in names {
                // exactly match logic
                let searchSpace = maxRecipientCount - exactlyMatchedContacts.count
                if searchSpace <= 0 {
                    break
                }

                let matchedList = contacts.lazy.filter {
                    let phonebookName = $0.familyName + $0.givenName
                    return name.stringWithoutEmoji == phonebookName.stringWithoutEmoji
                }.prefix(searchSpace)
                exactlyMatchedContacts.append(contentsOf: matchedList)
            }
            if 0 < exactlyMatchedContacts.count || type == .exact {
                complete(.exact, exactlyMatchedContacts)
                return
            }
            
            var partialyMatchedContacts = [CNContact]()
            for name in names {
                // partialy match logic
                // 모두 가져와서 정렬해야한다. (abc0000~abc5000까지 있는 경우 정렬해서 abc0000~abc0070을 보여줘야 한다는 정책 때문.
                let matchedList = contacts.filter {
                    let phonebookName = ($0.familyName + $0.givenName).replacingOccurrences(of: " ", with: "").stringWithoutEmoji
                    let nonWhiteSpaceName = name.replacingOccurrences(of: " ", with: "").stringWithoutEmoji
                    return phonebookName.contains(nonWhiteSpaceName) || nonWhiteSpaceName.contains(phonebookName)
                }
                partialyMatchedContacts.append(contentsOf: matchedList)
            }
            partialyMatchedContacts.sort { (contact1, contact2) -> Bool in
                let fullname1 = contact1.familyName + contact1.givenName
                let fullname2 = contact2.familyName + contact2.givenName
                
                if fullname1.count != fullname2.count {
                    let rate1 = max(Double(names[0].count)/Double(fullname1.count), Double(fullname1.count)/Double(names[0].count))
                    let rate2 = max(Double(names[0].count)/Double(fullname2.count), Double(fullname2.count)/Double(names[0].count))
                    return rate1 < rate2
                }
                
                return fullname1 < fullname2
            }
            if maxRecipientCount < partialyMatchedContacts.count {
                partialyMatchedContacts = Array(partialyMatchedContacts[..<maxRecipientCount])
            }
            
            complete(.partial, partialyMatchedContacts)
        }
    }
}

// MARK: - Observer

private extension ContactsUtil {
    func addContactsObserver() {
        removeContactObserver()
        
        notificationObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.CNContactStoreDidChange, object: nil, queue: nil) { [unowned self] _ in
            self.refreshLocalContacts()
            
            // TODO: send to server
        }
    }
    
    func removeContactObserver() {
        if let notificationObserver = notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
            self.notificationObserver = nil
        }
    }
}
