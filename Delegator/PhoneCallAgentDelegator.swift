//
//  PhoneCallAgentDelegator.swift
//  NuguComms
//
//  Created by chidlc on 2021/02/24.
//

import Foundation
import os.log

import NuguCore
import NuguAgents
import NuguUtils

class PhoneCallAgentDelegator: PhoneCallAgentDelegate {
    private weak var agent: PhoneCallAgentProtocol?
    @Atomic var context = PhoneCallContext(
        state: .idle,
        template: nil,
        recipient: nil
    )
    
    public init(agent: PhoneCallAgentProtocol) {
        self.agent = agent
    }
    
    func phoneCallAgentRequestContext() -> PhoneCallContext {
        return context
    }
    
    func phoneCallAgentDidReceiveSendCandidates(item: PhoneCallCandidatesItem, header: Downstream.Header) {
        os_log("making phone phoneCallAgentDidReceiveSendCandidates %@", "\(item)")
        
        guard let candidates = item.candidates else {
            if let name = item.recipientIntended?.name {
                ContactsUtil.shared.searchByName(names: [name], type: .partial) { [weak self] (type, contacts) in
                    let personList = contacts.map { (contact) -> PhoneCallPerson in
                        let contactList = contact.phoneNumbers.map { (phoneNumger) -> PhoneCallPerson.Contact in
                            let label: PhoneCallPerson.Contact.Label
                            switch phoneNumger.label {
                            case "MOBILE":
                                label = .mobile
                            default:
                                label = .home
                            }
                            
                            return PhoneCallPerson.Contact(label: label, number: phoneNumger.value.stringValue)
                        }
                        
                        
                        
                        return PhoneCallPerson(name: contact.familyName+contact.givenName, type: .contact, profileImgUrl: nil, category: nil, address: nil, businessHours: nil, history: nil, numInCallHistory: nil, token: nil, score: nil, contacts: contactList)
                    }
                    
                    let template = PhoneCallContext.Template(intent: item.intent, callType: item.callType, recipientIntended: item.recipientIntended, candidates: personList, searchScene: item.searchScene)
                    let context = PhoneCallContext(state: .idle, template: template, recipient: nil)
                    self?.context = context
                    
                    self?.agent?.requestSendCandidates(playServiceId: item.playServiceId, header: header, completion: { (state) in
                        os_log("requestSendCandidates state: %@", "\(state)")
                    })
                }
            }
            
            return
        }
        
        let template = PhoneCallContext.Template(intent: item.intent, callType: item.callType, recipientIntended: item.recipientIntended, candidates: candidates, searchScene: item.searchScene)
        let context = PhoneCallContext(state: .idle, template: template, recipient: nil)
        self.context = context
        
        agent?.requestSendCandidates(playServiceId: item.playServiceId , header: header) { (state) in
            os_log("requestSendCandidates state: %@", "\(state)")
        }
    }
    
    func phoneCallAgentDidReceiveMakeCall(callType: PhoneCallType, recipient: PhoneCallPerson, header: Downstream.Header) -> PhoneCallErrorCode? {
        guard .callar != callType else {
            return .callTypeNotSupported
        }
        
        guard let address = recipient.address,
            let phoneCallUrl = URL(string: "tel://\(address)"),
              UIApplication.shared.canOpenURL(phoneCallUrl) else { return .noSystemPermission }
        
        UIApplication.shared.open(phoneCallUrl, options: [:]) { (success) in
            os_log("making phone call %@", "\(success)")
        }
        
        return nil
    }
}
