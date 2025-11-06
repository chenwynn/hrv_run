//
//  WorkoutRecommendationEngine.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//

import Foundation

class WorkoutRecommendationEngine: ObservableObject {
    
    static let shared = WorkoutRecommendationEngine()
    
    @Published var currentRecommendation: WorkoutRecommendation?
    
    // MARK: - Generate Recommendation
    
    /// 生成锻炼建议
    func generateRecommendation(
        status: HRVStatus,
        trend: HRVTrend,
        optimalWindow: WorkoutWindow?
    ) -> WorkoutRecommendation {
        
        // 计算适宜度评分（综合考虑当前状态和趋势）
        let baseScore = status.recoveryScore
        let trendAdjustment = calculateTrendAdjustment(trend)
        let suitabilityScore = min(100, max(0, baseScore + trendAdjustment))
        
        // 确定是否适合锻炼
        let shouldWorkout = suitabilityScore >= 50
        
        // 建议强度
        let intensity = determineIntensity(score: suitabilityScore, zone: status.zone)
        
        // 建议时长
        let duration = determineDuration(score: suitabilityScore, intensity: intensity)
        
        // 建议类型
        let workoutType = determineWorkoutType(score: suitabilityScore, zone: status.zone)
        
        // 生成建议文本
        let advice = generateAdvice(
            shouldWorkout: shouldWorkout,
            zone: status.zone,
            intensity: intensity,
            trend: trend
        )
        
        // 恢复建议
        let recoveryAdvice = generateRecoveryAdvice(zone: status.zone, score: suitabilityScore)
        
        return WorkoutRecommendation(
            shouldWorkout: shouldWorkout,
            suitabilityScore: suitabilityScore,
            intensity: intensity,
            duration: duration,
            workoutType: workoutType,
            optimalWindow: optimalWindow,
            advice: advice,
            recoveryAdvice: recoveryAdvice,
            timestamp: Date()
        )
    }
    
    // MARK: - Private Helper Methods
    
    /// 计算趋势调整值
    private func calculateTrendAdjustment(_ trend: HRVTrend) -> Double {
        let baseAdjustment: Double
        
        switch trend.direction {
        case .improving:
            baseAdjustment = 10
        case .declining:
            baseAdjustment = -10
        case .stable:
            baseAdjustment = 0
        }
        
        // 根据置信度调整
        let confidenceMultiplier: Double
        switch trend.confidence {
        case .high:
            confidenceMultiplier = 1.0
        case .medium:
            confidenceMultiplier = 0.7
        case .low:
            confidenceMultiplier = 0.4
        }
        
        return baseAdjustment * confidenceMultiplier
    }
    
    /// 确定锻炼强度
    private func determineIntensity(score: Double, zone: HRVZone) -> WorkoutIntensity {
        switch zone {
        case .high:
            if score >= 85 {
                return .high
            } else {
                return .moderate
            }
        case .normal:
            if score >= 70 {
                return .moderate
            } else {
                return .low
            }
        case .low:
            return .veryLow
        }
    }
    
    /// 确定锻炼时长
    private func determineDuration(score: Double, intensity: WorkoutIntensity) -> TimeInterval {
        switch intensity {
        case .high:
            return 45 * 60  // 45分钟
        case .moderate:
            return 30 * 60  // 30分钟
        case .low:
            return 20 * 60  // 20分钟
        case .veryLow:
            return 15 * 60  // 15分钟
        }
    }
    
    /// 确定锻炼类型
    private func determineWorkoutType(score: Double, zone: HRVZone) -> [WorkoutType] {
        switch zone {
        case .high:
            return [.intervalTraining, .tempoRun, .longRun]
        case .normal:
            return [.easyRun, .tempoRun]
        case .low:
            return [.recovery, .walking]
        }
    }
    
    /// 生成建议文本
    private func generateAdvice(
        shouldWorkout: Bool,
        zone: HRVZone,
        intensity: WorkoutIntensity,
        trend: HRVTrend
    ) -> String {
        if !shouldWorkout {
            return NSLocalizedString("Your body needs rest today. Focus on recovery activities like light stretching or walking.", comment: "")
        }
        
        var advice = ""
        
        switch zone {
        case .high:
            advice = NSLocalizedString("Your recovery is excellent! This is a great day for high-intensity training or a challenging workout.", comment: "")
        case .normal:
            advice = NSLocalizedString("Your recovery is good. You can proceed with moderate training as planned.", comment: "")
        case .low:
            advice = NSLocalizedString("Your recovery is below baseline. Consider light exercise or rest.", comment: "")
        }
        
        // 添加趋势信息
        switch trend.direction {
        case .improving:
            advice += " " + NSLocalizedString("Your HRV is trending upward, which is a positive sign.", comment: "")
        case .declining:
            advice += " " + NSLocalizedString("Your HRV is trending downward. Be mindful of overtraining.", comment: "")
        case .stable:
            advice += " " + NSLocalizedString("Your HRV is stable.", comment: "")
        }
        
        return advice
    }
    
    /// 生成恢复建议
    private func generateRecoveryAdvice(zone: HRVZone, score: Double) -> String {
        switch zone {
        case .high:
            return NSLocalizedString("Continue your current recovery practices. Your body is responding well.", comment: "")
        case .normal:
            return NSLocalizedString("Maintain good sleep hygiene and stay hydrated. Consider adding a recovery day if needed.", comment: "")
        case .low:
            return NSLocalizedString("Prioritize sleep (8+ hours), hydration, and nutrition. Avoid intense training until HRV improves.", comment: "")
        }
    }
    
    // MARK: - Update Recommendation
    
    /// 更新当前建议
    func updateRecommendation(_ recommendation: WorkoutRecommendation) async {
        await MainActor.run {
            self.currentRecommendation = recommendation
        }
    }
}

// MARK: - Data Models

/// 锻炼建议
struct WorkoutRecommendation: Identifiable {
    let id = UUID()
    let shouldWorkout: Bool
    let suitabilityScore: Double  // 0-100
    let intensity: WorkoutIntensity
    let duration: TimeInterval
    let workoutType: [WorkoutType]
    let optimalWindow: WorkoutWindow?
    let advice: String
    let recoveryAdvice: String
    let timestamp: Date
    
    var scoreEmoji: String {
        switch suitabilityScore {
        case 85...100:
            return "🌟"
        case 70..<85:
            return "✅"
        case 50..<70:
            return "⚠️"
        default:
            return "🛑"
        }
    }
    
    var scoreColor: String {
        switch suitabilityScore {
        case 85...100:
            return "green"
        case 70..<85:
            return "blue"
        case 50..<70:
            return "yellow"
        default:
            return "red"
        }
    }
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        return "\(minutes) " + NSLocalizedString("min", comment: "")
    }
}

/// 锻炼强度
enum WorkoutIntensity: String, CaseIterable {
    case veryLow = "Very Light"
    case low = "Light"
    case moderate = "Moderate"
    case high = "High"
    
    var localizedString: String {
        switch self {
        case .veryLow:
            return NSLocalizedString("Very Light", comment: "")
        case .low:
            return NSLocalizedString("Light", comment: "")
        case .moderate:
            return NSLocalizedString("Moderate", comment: "")
        case .high:
            return NSLocalizedString("High", comment: "")
        }
    }
    
    var emoji: String {
        switch self {
        case .veryLow: return "🚶"
        case .low: return "🏃‍♂️"
        case .moderate: return "🏃‍♂️💨"
        case .high: return "🏃‍♂️💨💨"
        }
    }
    
    var description: String {
        switch self {
        case .veryLow:
            return NSLocalizedString("Recovery pace, can hold a conversation easily", comment: "")
        case .low:
            return NSLocalizedString("Easy pace, comfortable breathing", comment: "")
        case .moderate:
            return NSLocalizedString("Steady pace, somewhat hard breathing", comment: "")
        case .high:
            return NSLocalizedString("Fast pace, hard breathing", comment: "")
        }
    }
}

/// 锻炼类型
enum WorkoutType: String, CaseIterable {
    case recovery = "Recovery Run"
    case walking = "Walking"
    case easyRun = "Easy Run"
    case tempoRun = "Tempo Run"
    case intervalTraining = "Interval Training"
    case longRun = "Long Run"
    
    var localizedString: String {
        switch self {
        case .recovery:
            return NSLocalizedString("Recovery Run", comment: "")
        case .walking:
            return NSLocalizedString("Walking", comment: "")
        case .easyRun:
            return NSLocalizedString("Easy Run", comment: "")
        case .tempoRun:
            return NSLocalizedString("Tempo Run", comment: "")
        case .intervalTraining:
            return NSLocalizedString("Interval Training", comment: "")
        case .longRun:
            return NSLocalizedString("Long Run", comment: "")
        }
    }
    
    var emoji: String {
        switch self {
        case .recovery: return "🧘"
        case .walking: return "🚶"
        case .easyRun: return "🏃"
        case .tempoRun: return "🏃💨"
        case .intervalTraining: return "⚡️"
        case .longRun: return "🏃‍♂️📏"
        }
    }
}

