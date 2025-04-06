//
//  Analytics.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 16/03/25.
//

protocol Analytics {
    func log(_ event: AnalyticsEvent)
}

enum AnalyticsEvent {
    
    enum Social: String {
        case x, github, linkedin
    }
    
    case cleaner([Command])
    case social(Social)
    case donate
    
    var name: String {
        switch self {
        case .cleaner: "cleaner"
        case .social: "social"
        case .donate: "donate"
        }
    }
    
    var properties: [String:Any] {
        switch self {
        case .cleaner(let commands):
            ["commands": commands.map { $0.script }.joined(separator: ", ")]
        case .social(let social):
            ["platform": social.rawValue]
        case .donate:
            [:]
        }
    }
    
}
