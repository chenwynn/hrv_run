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
    
    // MARK: - Dependencies
    
    private let healthKitManager = HealthKitManager.shared
    private let analyzer = HRVAnalyzer.shared
    private let recommendationEngine = WorkoutRecommendationEngine.shared
    
    // MARK: - Initialization
    
    init() {
        checkAuthorizationStatus()
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
            
            // 7. 生成建议
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
        await loadData()
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
    
    var currentHRVValue: Double? {
        return todayHRVSamples.last?.value ?? recentHRVSamples.last?.value
    }
    
    var baselineIsReliable: Bool {
        return baseline?.isReliable ?? false
    }
    
    // MARK: - Formatting Helpers
    
    func formatHRV(_ value: Double) -> String {
        return String(format: "%.1f", value) + " ms"
    }
    
    func formatScore(_ score: Double) -> String {
        return String(format: "%.0f", score)
    }
}

