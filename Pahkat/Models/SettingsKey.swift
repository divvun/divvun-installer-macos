//
//  SettingsKey.swift
//  Pahkat
//
//  Created by Brendan Molloy on 2018-03-04.
//  Copyright © 2018 Divvun. All rights reserved.
//

import Foundation

protocol UserSettingsJSON {
    var requiresJSON: Bool { get }
    var rawValue: String { get }
}

enum SettingsKey: String, UserSettingsJSON {
    static let suiteName = "no.divvun.Pahkat"
    
    case interfaceLanguage = "AppleLanguages"
    case repositories = "no.divvun.Pahkat.repositories"
    case nextUpdateCheck = "no.divvun.Pahkat.nextUpdateCheck"
    case updateCheckInterval = "no.divvun.Pahkat.updateCheckInterval"
    
    var requiresJSON: Bool {
        switch self {
        case .interfaceLanguage, .nextUpdateCheck, .updateCheckInterval:
            return false
        case .repositories:
            return true
        }
    }
}
