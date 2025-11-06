//
//  AppSettings.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//

import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    
    static let shared = AppSettings()
    
    // MARK: - Published Properties
    
    @Published var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "selectedLanguage")
        }
    }
    
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // 加载保存的语言设置
        if let languageRaw = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = AppLanguage(rawValue: languageRaw) {
            self.selectedLanguage = language
        } else {
            // 默认跟随系统
            self.selectedLanguage = .system
        }
        
        // 加载保存的主题设置
        if let themeRaw = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: themeRaw) {
            self.selectedTheme = theme
        } else {
            // 默认跟随系统
            self.selectedTheme = .system
        }
    }
    
    // MARK: - Computed Properties
    
    var currentColorScheme: ColorScheme? {
        switch selectedTheme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    var currentLanguageCode: String? {
        switch selectedLanguage {
        case .system:
            return nil
        case .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case chinese = "zh-Hans"
    case english = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system:
            return NSLocalizedString("Follow System", comment: "")
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }
    
    var icon: String {
        switch self {
        case .system:
            return "globe"
        case .chinese:
            return "🇨🇳"
        case .english:
            return "🇺🇸"
        }
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system:
            return NSLocalizedString("Follow System", comment: "")
        case .light:
            return NSLocalizedString("Light", comment: "")
        case .dark:
            return NSLocalizedString("Dark", comment: "")
        }
    }
    
    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
}

