//
//  NotificationManager.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//

import Foundation
import UserNotifications
import HealthKit

class NotificationManager: ObservableObject {
    
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var notificationsEnabled = true {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }
    
    private let healthKitManager = HealthKitManager.shared
    private let analyzer = HRVAnalyzer.shared
    private let recommendationEngine = WorkoutRecommendationEngine.shared
    
    // MARK: - Initialization
    
    init() {
        // 加载通知开关状态
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        if UserDefaults.standard.object(forKey: "notificationsEnabled") == nil {
            // 首次使用，默认开启
            notificationsEnabled = true
        }
    }
    
    // MARK: - Authorization
    
    /// 请求通知权限
    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        let granted = try await center.requestAuthorization(options: options)
        
        await MainActor.run {
            self.isAuthorized = granted
        }
    }
    
    /// 检查通知权限状态
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }
    
    // MARK: - Background Observers
    
    /// 启动后台数据监听
    func startObservingHealthData() {
        guard isAuthorized && notificationsEnabled else { return }
        
        // 监听HRV数据变化
        observeHRVChanges()
        
        // 监听锻炼数据
        observeWorkoutChanges()
        
        // 设置每日测量提醒
        scheduleDailyMeasurementReminder()
    }
    
    /// 停止后台监听
    func stopObservingHealthData() {
        let healthStore = HKHealthStore()
        
        // 停止HRV观察
        if let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            healthStore.disableBackgroundDelivery(for: hrvType) { _, _ in }
        }
        
        // 停止锻炼观察
        healthStore.disableBackgroundDelivery(for: HKObjectType.workoutType()) { _, _ in }
    }
    
    // MARK: - HRV Data Observer
    
    /// 监听HRV数据变化
    private func observeHRVChanges() {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return
        }
        
        let healthStore = HKHealthStore()
        
        // 启用后台传输
        healthStore.enableBackgroundDelivery(for: hrvType, frequency: .immediate) { success, error in
            if !success {
                print("Failed to enable background delivery for HRV: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
        
        // 创建观察者查询
        let query = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] query, completionHandler, error in
            guard let self = self else {
                completionHandler()
                return
            }
            
            if let error = error {
                print("HRV observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            // 在后台处理新的HRV数据
            Task {
                await self.handleNewHRVData()
                completionHandler()
            }
        }
        
        healthStore.execute(query)
    }
    
    /// 处理新的HRV数据
    private func handleNewHRVData() async {
        guard notificationsEnabled else { return }
        
        do {
            // 获取最新的HRV数据
            let recentSamples = try await healthKitManager.fetchRecentHRVData(days: 30)
            guard !recentSamples.isEmpty else { return }
            
            // 计算基准
            guard let baseline = analyzer.calculateBaseline(from: recentSamples) else { return }
            
            // 获取最新的HRV值
            guard let latestHRV = recentSamples.last else { return }
            
            // 分析状态
            let status = analyzer.analyzeStatus(currentValue: latestHRV.value, baseline: baseline)
            
            // 分析趋势
            let trend = analyzer.analyzeTrend(samples: recentSamples)
            
            // 生成建议
            let recommendation = recommendationEngine.generateRecommendation(
                status: status,
                trend: trend,
                optimalWindow: nil
            )
            
            // 发送通知
            await sendHRVUpdateNotification(
                score: recommendation.suitabilityScore,
                zone: status.zone,
                advice: recommendation.advice
            )
            
        } catch {
            print("Error handling new HRV data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Workout Observer
    
    /// 监听锻炼数据变化
    private func observeWorkoutChanges() {
        let workoutType = HKObjectType.workoutType()
        let healthStore = HKHealthStore()
        
        // 启用后台传输
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { success, error in
            if !success {
                print("Failed to enable background delivery for workouts: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
        
        // 创建观察者查询
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] query, completionHandler, error in
            guard let self = self else {
                completionHandler()
                return
            }
            
            if let error = error {
                print("Workout observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            // 在后台处理新的锻炼数据
            Task {
                await self.handleNewWorkoutData()
                completionHandler()
            }
        }
        
        healthStore.execute(query)
    }
    
    /// 处理新的锻炼数据
    private func handleNewWorkoutData() async {
        guard notificationsEnabled else { return }
        
        do {
            // 获取最近的锻炼
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .hour, value: -6, to: endDate)!
            let workouts = try await healthKitManager.fetchWorkouts(from: startDate, to: endDate)
            
            guard let latestWorkout = workouts.first else { return }
            
            // 获取锻炼前后的HRV数据
            let workoutEnd = latestWorkout.endDate
            let postWorkoutStart = workoutEnd
            let postWorkoutEnd = Calendar.current.date(byAdding: .hour, value: 6, to: workoutEnd)!
            
            let postWorkoutHRV = try await healthKitManager.fetchHRVData(from: postWorkoutStart, to: postWorkoutEnd)
            
            // 如果有锻炼后的HRV数据，分析并发送通知
            if !postWorkoutHRV.isEmpty {
                await sendWorkoutCompletionNotification(
                    workout: latestWorkout,
                    postHRV: postWorkoutHRV
                )
            }
            
        } catch {
            print("Error handling new workout data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Send Notifications
    
    /// 发送HRV更新通知
    private func sendHRVUpdateNotification(score: Double, zone: HRVZone, advice: String) async {
        let content = UNMutableNotificationContent()
        
        // 根据评分设置标题和emoji
        let emoji: String
        let title: String
        
        switch score {
        case 85...100:
            emoji = "🌟"
            title = NSLocalizedString("Excellent Recovery!", comment: "")
        case 70..<85:
            emoji = "😊"
            title = NSLocalizedString("Good Recovery", comment: "")
        case 55..<70:
            emoji = "😐"
            title = NSLocalizedString("Moderate Recovery", comment: "")
        case 40..<55:
            emoji = "😓"
            title = NSLocalizedString("Low Recovery", comment: "")
        default:
            emoji = "😴"
            title = NSLocalizedString("Rest Needed", comment: "")
        }
        
        content.title = "\(emoji) \(title)"
        content.body = advice
        content.sound = .default
        content.badge = 1
        
        // 添加分类（用于通知操作）
        content.categoryIdentifier = "HRV_UPDATE"
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: "hrv_update_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // 立即发送
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error sending notification: \(error.localizedDescription)")
        }
    }
    
    /// 发送锻炼完成通知
    private func sendWorkoutCompletionNotification(workout: HKWorkout, postHRV: [HRVSample]) async {
        let content = UNMutableNotificationContent()
        
        // 分析恢复情况
        let avgPostHRV = postHRV.map { $0.value }.reduce(0, +) / Double(postHRV.count)
        
        // 获取基准用于对比
        let recentSamples = try? await healthKitManager.fetchRecentHRVData(days: 30)
        guard let baseline = recentSamples.flatMap({ analyzer.calculateBaseline(from: $0) }) else {
            return
        }
        
        let recoveryPercentage = (avgPostHRV / baseline.mean) * 100
        
        let emoji: String
        let title: String
        let body: String
        
        if recoveryPercentage >= 95 {
            emoji = "⭐️"
            title = NSLocalizedString("Great Workout!", comment: "")
            body = NSLocalizedString("Your HRV is recovering well. Excellent training session!", comment: "")
        } else if recoveryPercentage >= 85 {
            emoji = "👍"
            title = NSLocalizedString("Good Workout", comment: "")
            body = NSLocalizedString("Your HRV is recovering normally. Good job!", comment: "")
        } else if recoveryPercentage >= 70 {
            emoji = "👌"
            title = NSLocalizedString("Moderate Workout", comment: "")
            body = NSLocalizedString("Your HRV dropped more than usual. Consider easier training tomorrow.", comment: "")
        } else {
            emoji = "💪"
            title = NSLocalizedString("Challenging Workout", comment: "")
            body = NSLocalizedString("Your HRV dropped significantly. Make sure to rest and recover properly.", comment: "")
        }
        
        content.title = "\(emoji) \(title)"
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "WORKOUT_COMPLETION"
        
        // 延迟2小时后发送（给HRV时间恢复）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 7200, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "workout_completion_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error sending workout notification: \(error.localizedDescription)")
        }
    }
    
    /// 发送每日建议通知
    func sendDailyRecommendationNotification() async {
        guard isAuthorized && notificationsEnabled else { return }
        
        do {
            // 获取最新数据并分析
            let recentSamples = try await healthKitManager.fetchRecentHRVData(days: 30)
            guard !recentSamples.isEmpty else { return }
            
            guard let baseline = analyzer.calculateBaseline(from: recentSamples) else { return }
            guard let latestHRV = recentSamples.last else { return }
            
            let status = analyzer.analyzeStatus(currentValue: latestHRV.value, baseline: baseline)
            let trend = analyzer.analyzeTrend(samples: recentSamples)
            let recommendation = recommendationEngine.generateRecommendation(
                status: status,
                trend: trend,
                optimalWindow: nil
            )
            
            // 创建通知内容
            let content = UNMutableNotificationContent()
            
            let emoji = getEmojiForScore(recommendation.suitabilityScore)
            content.title = "\(emoji) " + NSLocalizedString("Today's Training Recommendation", comment: "")
            content.body = recommendation.advice
            content.sound = .default
            content.categoryIdentifier = "DAILY_RECOMMENDATION"
            
            // 每天早上8点发送
            var dateComponents = DateComponents()
            dateComponents.hour = 8
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            
            let request = UNNotificationRequest(
                identifier: "daily_recommendation",
                content: content,
                trigger: trigger
            )
            
            try await UNUserNotificationCenter.current().add(request)
            
        } catch {
            print("Error sending daily notification: \(error.localizedDescription)")
        }
    }
    
    /// 取消每日通知
    func cancelDailyNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_recommendation"])
    }
    
    // MARK: - Helper Methods
    
    /// 根据评分获取emoji
    private func getEmojiForScore(_ score: Double) -> String {
        switch score {
        case 85...100: return "🌟"
        case 70..<85: return "😊"
        case 55..<70: return "😐"
        case 40..<55: return "😓"
        default: return "😴"
        }
    }
    
    /// 清除所有待发送的通知
    func clearAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// 清除所有已发送的通知
    func clearAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // MARK: - Daily Measurement Reminder
    
    /// 设置每日测量提醒
    func scheduleDailyMeasurementReminder() {
        guard isAuthorized && notificationsEnabled else { return }
        
        // 取消旧的提醒
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning_measurement_reminder"])
        
        // 创建新的提醒
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Time to Measure HRV", comment: "")
        content.body = NSLocalizedString("Good morning! Measure your HRV now for the most accurate reading.", comment: "")
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "MEASUREMENT_REMINDER"
        
        // 每天早上8:00提醒
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "morning_measurement_reminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling measurement reminder: \(error.localizedDescription)")
            }
        }
    }
    
    /// 取消测量提醒
    func cancelMeasurementReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning_measurement_reminder"])
    }
    
    /// 发送测量质量反馈通知
    func sendMeasurementQualityFeedback(quality: DataQuality) {
        guard isAuthorized && notificationsEnabled else { return }
        
        // 只在质量不佳时发送反馈
        guard quality.level == .fair || quality.level == .poor else { return }
        
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Measurement Quality Tips", comment: "")
        
        if quality.level == .fair {
            content.body = NSLocalizedString("Your measurement quality was fair. For best results, measure between 6-10 AM right after waking up.", comment: "")
        } else {
            content.body = NSLocalizedString("Your measurement quality was poor. Try measuring in the morning (6-10 AM) while sitting calmly.", comment: "")
        }
        
        content.sound = .default
        content.categoryIdentifier = "QUALITY_FEEDBACK"
        
        // 5秒后发送
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "measurement_quality_feedback_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending quality feedback: \(error.localizedDescription)")
            }
        }
    }
    
    /// 发送连续测量成就通知
    func sendConsecutiveMeasurementAchievement(days: Int) {
        guard isAuthorized && notificationsEnabled else { return }
        guard days >= 7 && days % 7 == 0 else { return } // 每7天发送一次
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 " + NSLocalizedString("Achievement Unlocked!", comment: "")
        content.body = String(format: NSLocalizedString("You've measured your HRV for %d consecutive days! Keep up the great work!", comment: ""), days)
        content.sound = .default
        content.categoryIdentifier = "ACHIEVEMENT"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "achievement_\(days)_days",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending achievement notification: \(error.localizedDescription)")
            }
        }
    }
    
    /// 发送最佳测量窗口提醒
    func sendOptimalMeasurementWindowReminder() {
        guard isAuthorized && notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "⏰ " + NSLocalizedString("Optimal Measurement Window", comment: "")
        content.body = NSLocalizedString("You're in the optimal measurement window (6-10 AM). Measure now for the most accurate results!", comment: "")
        content.sound = .default
        content.categoryIdentifier = "OPTIMAL_WINDOW"
        
        // 立即发送
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "optimal_window_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending optimal window reminder: \(error.localizedDescription)")
            }
        }
    }
}

