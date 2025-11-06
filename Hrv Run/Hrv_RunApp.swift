//
//  Hrv_RunApp.swift
//  Hrv Run
//
//  Created by 陈吟书 on 2025/11/6.
//

import SwiftUI

@main
struct Hrv_RunApp: App {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, appSettings.currentLanguageCode.map { Locale(identifier: $0) } ?? .current)
                .preferredColorScheme(appSettings.currentColorScheme)
                .tint(Color("AccentColor")) // 使用自定义主题色
                .task {
                    // 检查并请求通知权限
                    await notificationManager.checkAuthorizationStatus()
                    
                    if !notificationManager.isAuthorized {
                        try? await notificationManager.requestAuthorization()
                    }
                    
                    // 启动后台数据监听
                    if notificationManager.isAuthorized && notificationManager.notificationsEnabled {
                        notificationManager.startObservingHealthData()
                        
                        // 设置每日通知
                        await notificationManager.sendDailyRecommendationNotification()
                    }
                }
        }
    }
}
