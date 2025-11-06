//
//  LocalizationHelper.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//

import Foundation

extension String {
    func localized() -> String {
        let appSettings = AppSettings.shared
        
        // 获取当前应用设置的语言
        guard let languageCode = appSettings.currentLanguageCode else {
            // 跟随系统
            return NSLocalizedString(self, comment: "")
        }
        
        // 获取指定语言的Bundle
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, comment: "")
        }
        
        return NSLocalizedString(self, tableName: nil, bundle: bundle, value: "", comment: "")
    }
}

