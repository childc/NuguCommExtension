//
//  NuguTmapDummy.swift
//  NuguComms
//
//  Created by childc on 2021/02/24.
//

import Foundation

import NuguCore
import NuguAgents

public class NuguTmapDummy {
    public lazy var contextInfoProvider: ContextInfoProviderType = { [weak self] completion in
        guard let self = self else { return }
        
        var payload = [String: AnyHashable?]()
        payload["version"] = "1.0"
        
        let currentPoi: [String: AnyHashable?] = [
            "latitude": 37.5662956237793,
            "longitude": 126.98905944824219,
            "centerY": 1352286,
            "centerX": 4571682,
            "address": "서울특별시 중구 을지로"
        ]
        
        let toPoi: [String: AnyHashable?] = [
            "latitude": 556586486812705,
            "longitude": 126.97569056145043,
            "centerY": 1351941,
            "centerX": 4571208,
            "name": "SK남산빌딩",
            "address": "서울특별시 중구 퇴계로"
        ]
        
        let route: [String: AnyHashable?] = [
            "status": "ROUTING",
            "current": [
                "poi": currentPoi
            ],
            "to": [
                "distanceLeftInMeter": 2661 as AnyHashable,
                "timeLeftInsec": 613 as AnyHashable,
                "poi": toPoi
            ]
        ]
        
        payload["route"] = route
        
        completion(
            ContextInfo(
                contextType: .capability,
                name: "NuguTmap",
                payload: payload.compactMapValues { $0 }
            )
        )
    }
    
    public init(contextManager: ContextManageable) {
        contextManager.addProvider(contextInfoProvider)
    }
}
