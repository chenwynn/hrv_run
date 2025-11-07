//
//  HealthKitManager.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//

import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var authorizationError: Error?
    
    // MARK: - Initialization
    
    init() {
        // 异步检查授权状态
        Task {
            await checkInitialAuthorizationStatus()
        }
    }
    
    /// 检查初始授权状态
    private func checkInitialAuthorizationStatus() async {
        // HealthKit的读取权限无法直接查询状态（隐私保护）
        // 我们通过尝试读取数据来判断是否已授权
        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
            
            // 尝试读取最近1天的HRV数据
            let _ = try await fetchHRVData(from: startDate, to: endDate)
            
            // 如果能读取到数据（或没有错误），说明已授权
            await MainActor.run {
                self.isAuthorized = true
            }
        } catch {
            // 如果出错，说明未授权
            await MainActor.run {
                self.isAuthorized = false
            }
        }
    }
    
    // MARK: - HealthKit Types
    
    /// HRV数据类型
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    
    /// 心率数据类型
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    
    /// 静息心率数据类型
    private let restingHeartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
    
    /// 睡眠数据类型
    private let sleepAnalysisType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
    
    /// 锻炼数据类型
    private let workoutType = HKObjectType.workoutType()
    
    /// 需要读取的数据类型
    private var typesToRead: Set<HKObjectType> {
        return [
            hrvType,
            heartRateType,
            restingHeartRateType,
            sleepAnalysisType,
            workoutType
        ]
    }
    
    /// 需要写入的数据类型
    private var typesToWrite: Set<HKSampleType> {
        return [
            workoutType
        ]
    }
    
    // MARK: - Authorization
    
    /// 检查HealthKit是否可用
    var isHealthKitAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    /// 请求HealthKit授权
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            
            // 检查授权状态
            await MainActor.run {
                self.isAuthorized = true
                self.authorizationError = nil
            }
        } catch {
            await MainActor.run {
                self.authorizationError = error
                self.isAuthorized = false
            }
            throw error
        }
    }
    
    /// 检查特定类型的授权状态
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: type)
    }
    
    // MARK: - HRV Data Fetching
    
    /// 获取指定日期范围的HRV数据
    func fetchHRVData(from startDate: Date, to endDate: Date) async throws -> [HRVSample] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let hrvSamples = quantitySamples.map { sample in
                    HRVSample(
                        value: sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)),
                        date: sample.startDate,
                        source: sample.sourceRevision.source.name
                    )
                }
                
                continuation.resume(returning: hrvSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// 获取最近N天的HRV数据
    func fetchRecentHRVData(days: Int = 30) async throws -> [HRVSample] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        
        return try await fetchHRVData(from: startDate, to: endDate)
    }
    
    /// 获取今日HRV数据
    func fetchTodayHRVData() async throws -> [HRVSample] {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = Date()
        
        return try await fetchHRVData(from: startDate, to: endDate)
    }
    
    // MARK: - Resting Heart Rate Data
    
    /// 获取静息心率数据
    func fetchRestingHeartRate(from startDate: Date, to endDate: Date) async throws -> [RestingHeartRateSample] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: restingHeartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let rhrSamples = quantitySamples.map { sample in
                    RestingHeartRateSample(
                        value: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                        date: sample.startDate
                    )
                }
                
                continuation.resume(returning: rhrSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// 获取最近的静息心率
    func fetchRecentRestingHeartRate(days: Int = 7) async throws -> [RestingHeartRateSample] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        return try await fetchRestingHeartRate(from: startDate, to: endDate)
    }
    
    // MARK: - Sleep Data
    
    /// 获取睡眠数据
    func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> [SleepSample] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepAnalysisType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let sleepSamples = categorySamples.compactMap { sample -> SleepSample? in
                    guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value) else {
                        return nil
                    }
                    
                    return SleepSample(
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        value: sleepValue,
                        duration: sample.endDate.timeIntervalSince(sample.startDate)
                    )
                }
                
                continuation.resume(returning: sleepSamples)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// 获取最近的睡眠数据
    func fetchRecentSleepData(days: Int = 7) async throws -> [SleepSample] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        return try await fetchSleepData(from: startDate, to: endDate)
    }
    
    /// 计算睡眠质量评分
    func calculateSleepQuality(samples: [SleepSample]) -> SleepQuality? {
        guard !samples.isEmpty else { return nil }
        
        // 按日期分组
        let calendar = Calendar.current
        var dailySleep: [Date: [SleepSample]] = [:]
        
        for sample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            dailySleep[day, default: []].append(sample)
        }
        
        // 计算最近一晚的睡眠
        guard let lastNight = dailySleep.keys.sorted().last,
              let lastSleepSamples = dailySleep[lastNight] else {
            return nil
        }
        
        // 计算总睡眠时长
        let totalSleepDuration = lastSleepSamples
            .filter { $0.value == .asleepUnspecified || $0.value == .asleepCore || $0.value == .asleepDeep || $0.value == .asleepREM }
            .reduce(0) { $0 + $1.duration }
        
        let totalSleepHours = totalSleepDuration / 3600
        
        // 计算深度睡眠时长
        let deepSleepDuration = lastSleepSamples
            .filter { $0.value == .asleepDeep }
            .reduce(0) { $0 + $1.duration }
        
        let deepSleepHours = deepSleepDuration / 3600
        
        // 计算睡眠质量评分 (0-100)
        var score: Double = 0
        
        // 1. 总睡眠时长评分 (最高50分)
        if totalSleepHours >= 7 && totalSleepHours <= 9 {
            score += 50
        } else if totalSleepHours >= 6 && totalSleepHours < 7 {
            score += 40
        } else if totalSleepHours >= 5 && totalSleepHours < 6 {
            score += 30
        } else {
            score += 20
        }
        
        // 2. 深度睡眠评分 (最高30分)
        let deepSleepPercentage = (deepSleepDuration / totalSleepDuration) * 100
        if deepSleepPercentage >= 15 {
            score += 30
        } else if deepSleepPercentage >= 10 {
            score += 20
        } else {
            score += 10
        }
        
        // 3. 睡眠连续性评分 (最高20分)
        let interruptionCount = lastSleepSamples.filter { $0.value == .awake }.count
        if interruptionCount == 0 {
            score += 20
        } else if interruptionCount <= 2 {
            score += 15
        } else if interruptionCount <= 5 {
            score += 10
        } else {
            score += 5
        }
        
        return SleepQuality(
            totalSleepHours: totalSleepHours,
            deepSleepHours: deepSleepHours,
            score: score,
            date: lastNight
        )
    }
    
    // MARK: - Workout Data
    
    /// 保存锻炼数据到HealthKit
    func saveWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        distance: Double? = nil,
        energyBurned: Double? = nil
    ) async throws {
        var metadata: [String: Any] = [:]
        
        let workout = HKWorkout(
            activityType: activityType,
            start: start,
            end: end,
            duration: end.timeIntervalSince(start),
            totalEnergyBurned: energyBurned.map { HKQuantity(unit: .kilocalorie(), doubleValue: $0) },
            totalDistance: distance.map { HKQuantity(unit: .meter(), doubleValue: $0) },
            metadata: metadata
        )
        
        try await healthStore.save(workout)
    }
    
    /// 获取锻炼数据
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// 获取最近N个训练
    func fetchRecentWorkouts(limit: Int = 10) async throws -> [HKWorkout] {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// 将HKWorkout转换为WorkoutSummary
    func convertToWorkoutSummary(_ workout: HKWorkout) -> WorkoutSummary {
        return WorkoutSummary(
            id: UUID(),
            type: workoutTypeString(workout.workoutActivityType),
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            distance: workout.totalDistance?.doubleValue(for: .meter()),
            calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        )
    }
    
    /// 获取训练类型的本地化名称
    private func workoutTypeString(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        default: return "Workout"
        }
    }
}

// MARK: - Data Models

/// HRV样本数据模型
struct HRVSample: Identifiable {
    let id = UUID()
    let value: Double  // 单位: 毫秒
    let date: Date
    let source: String
}

/// 静息心率样本
struct RestingHeartRateSample: Identifiable {
    let id = UUID()
    let value: Double  // 单位: bpm
    let date: Date
}

/// 睡眠样本
struct SleepSample: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let value: HKCategoryValueSleepAnalysis
    let duration: TimeInterval  // 秒
}

/// 睡眠质量
struct SleepQuality {
    let totalSleepHours: Double
    let deepSleepHours: Double
    let score: Double  // 0-100
    let date: Date
    
    var rating: String {
        if score >= 80 {
            return NSLocalizedString("Excellent", comment: "")
        } else if score >= 60 {
            return NSLocalizedString("Good", comment: "")
        } else if score >= 40 {
            return NSLocalizedString("Fair", comment: "")
        } else {
            return NSLocalizedString("Poor", comment: "")
        }
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case dataNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .dataNotAvailable:
            return "Requested data is not available"
        }
    }
}

