//
//  HRVViewModel.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//

import Foundation
import SwiftUI

@MainActor
class HRVViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var error: Error?
    @Published var needsAuthorization = true
    
    // HRV数据
    @Published var recentHRVSamples: [HRVSample] = []
    @Published var todayHRVSamples: [HRVSample] = []
    
    // 分析结果
    @Published var baseline: HRVBaseline?
    @Published var currentStatus: HRVStatus?
    @Published var trend: HRVTrend?
    @Published var optimalWindow: WorkoutWindow?
    @Published var recommendation: WorkoutRecommendation?
    
    // Workout相关
    @Published var recentWorkouts: [WorkoutSummary] = []
    @Published var selectedWorkoutForEvaluation: WorkoutSummary?
    @Published var savedEvaluations: [PostWorkoutEvaluation] = []
    
    // MARK: - Dependencies
    
    private let healthKitManager = HealthKitManager.shared
    private let analyzer = HRVAnalyzer.shared
    private let recommendationEngine = WorkoutRecommendationEngine.shared
    
    // MARK: - Initialization
    
    init() {
        // 初始值设为true，等待异步检查完成
        needsAuthorization = true
        
        // 启动异步授权检查
        Task {
            // 等待HealthKitManager完成初始检查
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            await MainActor.run {
                needsAuthorization = !healthKitManager.isAuthorized
            }
        }
    }
    
    // MARK: - Authorization
    
    /// 检查授权状态
    func checkAuthorizationStatus() {
        needsAuthorization = !healthKitManager.isAuthorized
    }
    
    /// 请求HealthKit授权
    func requestAuthorization() async {
        isLoading = true
        error = nil
        
        do {
            try await healthKitManager.requestAuthorization()
            needsAuthorization = false
            
            // 授权成功后立即加载数据
            await loadData()
        } catch {
            self.error = error
            needsAuthorization = true
        }
        
        isLoading = false
    }
    
    // MARK: - Data Loading
    
    /// 加载所有数据
    func loadData() async {
        isLoading = true
        error = nil
        
        do {
            // 1. 加载历史HRV数据（用于建立基准）
            let recentSamples = try await healthKitManager.fetchRecentHRVData(days: 30)
            recentHRVSamples = recentSamples
            
            // 2. 计算基准
            if let calculatedBaseline = analyzer.calculateBaseline(from: recentSamples) {
                baseline = calculatedBaseline
            }
            
            // 3. 加载今日HRV数据
            let todaySamples = try await healthKitManager.fetchTodayHRVData()
            todayHRVSamples = todaySamples
            
            // 4. 分析当前状态
            if let baseline = baseline,
               let latestHRV = todaySamples.last ?? recentSamples.last {
                currentStatus = analyzer.analyzeStatus(
                    currentValue: latestHRV.value,
                    baseline: baseline
                )
            }
            
            // 5. 分析趋势
            if recentSamples.count >= 7 {
                trend = analyzer.analyzeTrend(samples: recentSamples)
            }
            
            // 6. 寻找最佳锻炼窗口
            if let baseline = baseline, !todaySamples.isEmpty {
                optimalWindow = analyzer.findOptimalWorkoutWindow(
                    todaySamples: todaySamples,
                    baseline: baseline
                )
            }
            
            // 7. 加载最近的训练记录
            await loadRecentWorkouts()
            
            // 8. 加载保存的评估
            loadSavedEvaluations()
            
            // 9. 生成建议
            if let status = currentStatus,
               let trend = trend {
                recommendation = recommendationEngine.generateRecommendation(
                    status: status,
                    trend: trend,
                    optimalWindow: optimalWindow
                )
            }
            
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    /// 刷新数据
    func refresh() async {
        print("🔄 [ViewModel] Refreshing data...")
        print("🔄 [ViewModel] Current today samples: \(todayHRVSamples.count)")
        if let latest = todayHRVSamples.last {
            print("🔄 [ViewModel] Current latest HRV: \(latest.value)ms at \(latest.date)")
        }
        
        await loadData()
        
        print("✅ [ViewModel] Refresh complete")
        print("✅ [ViewModel] New today samples: \(todayHRVSamples.count)")
        if let latest = todayHRVSamples.last {
            print("✅ [ViewModel] New latest HRV: \(latest.value)ms at \(latest.date)")
        }
    }
    
    /// 重新计算基准
    func recalculateBaseline() async {
        isLoading = true
        
        do {
            let samples = try await healthKitManager.fetchRecentHRVData(days: 30)
            recentHRVSamples = samples
            
            if let calculatedBaseline = analyzer.calculateBaseline(from: samples) {
                baseline = calculatedBaseline
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    // MARK: - Computed Properties
    
    var hasData: Bool {
        return !recentHRVSamples.isEmpty
    }
    
    var hasTodayData: Bool {
        return !todayHRVSamples.isEmpty
    }
    
    var currentHRVValue: Double? {
        return todayHRVSamples.last?.value ?? recentHRVSamples.last?.value
    }
    
    var baselineIsReliable: Bool {
        return baseline?.isReliable ?? false
    }
    
    var needsTodayMeasurement: Bool {
        // 如果有历史数据但没有今天的数据，需要测量
        return hasData && !hasTodayData
    }
    
    // MARK: - Formatting Helpers
    
    func formatHRV(_ value: Double) -> String {
        return String(format: "%.1f", value) + " ms"
    }
    
    func formatScore(_ score: Double) -> String {
        return String(format: "%.0f", score)
    }
    
    // MARK: - Workout Methods
    
    /// 加载最近的训练记录（今天的所有训练）
    func loadRecentWorkouts() async {
        do {
            // 获取今天的所有训练
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
            
            let workouts = try await healthKitManager.fetchWorkouts(from: today, to: tomorrow)
            await MainActor.run {
                self.recentWorkouts = workouts.map { healthKitManager.convertToWorkoutSummary($0) }
            }
        } catch {
            print("Error loading workouts: \(error)")
        }
    }
    
    /// 获取训练后HRV数据
    func getPostWorkoutHRVData(for workout: WorkoutSummary) async -> PostWorkoutHRVData {
        // print("📊 [ViewModel] Getting HRV data for workout: \(workout.type)")
        // print("📊 [ViewModel] Workout time: \(workout.startDate) - \(workout.endDate)")
        // print("📊 [ViewModel] Total HRV samples: \(recentHRVSamples.count)")
        
        // 1. 获取训练前HRV（当天早晨）
        let dayStart = Calendar.current.startOfDay(for: workout.startDate)
        // print("📊 [ViewModel] Day start: \(dayStart)")
        
        let morningHRVs = recentHRVSamples.filter { sample in
            sample.date >= dayStart && sample.date < workout.startDate
        }
        // print("📊 [ViewModel] Morning HRVs found: \(morningHRVs.count)")
        // morningHRVs.forEach { print("  - \($0.date): \($0.value)ms") }
        
        guard let preHRV = morningHRVs.last else {
            // print("❌ [ViewModel] No morning HRV found")
            return .needMorningMeasurement
        }
        // print("✅ [ViewModel] Pre-workout HRV: \(preHRV.value)ms at \(preHRV.date)")
        
        // 2. 获取训练后HRV（训练结束后3小时内）
        let postWindowEnd = min(
            workout.endDate.addingTimeInterval(3 * 3600),
            Date()
        )
        // print("📊 [ViewModel] Post-workout window: \(workout.endDate) - \(postWindowEnd)")
        
        let postWorkoutHRVs = recentHRVSamples.filter { sample in
            sample.date >= workout.endDate && sample.date <= postWindowEnd
        }
        // print("📊 [ViewModel] Post-workout HRVs found: \(postWorkoutHRVs.count)")
        // postWorkoutHRVs.forEach { print("  - \($0.date): \($0.value)ms") }
        
        if let postHRV = postWorkoutHRVs.first {
            // print("✅ [ViewModel] Post-workout HRV: \(postHRV.value)ms at \(postHRV.date)")
            return .hasData(pre: preHRV.value, post: postHRV.value, workout: workout)
        } else {
            // 检查是否还在窗口期
            let timeSince = Date().timeIntervalSince(workout.endDate)
            // print("📊 [ViewModel] Time since workout: \(timeSince/60) minutes")
            if timeSince < 3 * 3600 {
                // print("⚠️ [ViewModel] In window but no post-HRV measurement")
                return .needPostMeasurement(workout: workout, preHRV: preHRV.value)
            } else {
                // print("❌ [ViewModel] Missed 3-hour measurement window")
                return .missedWindow
            }
        }
    }
    
    /// 保存训练后评估
    func savePostWorkoutEvaluation(_ evaluation: PostWorkoutEvaluation) {
        savedEvaluations.append(evaluation)
        // 可以保存到UserDefaults或CoreData
        saveEvaluationsToStorage()
    }
    
    /// 保存评估到本地存储
    private func saveEvaluationsToStorage() {
        if let encoded = try? JSONEncoder().encode(savedEvaluations) {
            UserDefaults.standard.set(encoded, forKey: "savedEvaluations")
        }
    }
    
    /// 从本地存储加载评估
    func loadSavedEvaluations() {
        if let data = UserDefaults.standard.data(forKey: "savedEvaluations"),
           let decoded = try? JSONDecoder().decode([PostWorkoutEvaluation].self, from: data) {
            savedEvaluations = decoded
        }
    }
    
    /// 获取最新训练的评估状态
    func getLatestWorkoutEvaluation() -> String? {
        guard let latestWorkout = recentWorkouts.first else {
            return nil
        }
        
        // 检查是否已评估
        if let evaluation = savedEvaluations.first(where: { $0.workout.id == latestWorkout.id }) {
            return "HRV \(evaluation.hrvChange >= 0 ? "+" : "")\(String(format: "%.1f", evaluation.hrvChange))% · \(evaluation.stars)"
        }
        
        return nil
    }
}

