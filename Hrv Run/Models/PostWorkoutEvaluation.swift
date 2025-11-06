//
//  PostWorkoutEvaluation.swift
//  Hrv Run
//
//  Created by AI on 2025/11/7.
//

import Foundation
import HealthKit

// MARK: - Post Workout Evaluation Models

/// 训练后评估数据
struct PostWorkoutEvaluation: Identifiable, Codable {
    let id: UUID
    let workout: WorkoutSummary
    let preWorkoutHRV: Double       // 训练前HRV（早晨）
    let postWorkoutHRV: Double      // 训练后HRV
    let hrvChange: Double           // HRV变化百分比
    let subjectiveFeeling: SubjectiveFeeling  // 主观感受
    let evaluationDate: Date
    
    var overallScore: Int {
        return calculateOverallScore()
    }
    
    var recommendation: String {
        return generateRecommendation()
    }
    
    var quadrant: TrainingQuadrant {
        return determineQuadrant()
    }
    
    // 计算综合评分（0-100）
    private func calculateOverallScore() -> Int {
        // 基础分60分
        var score = 60
        
        // HRV变化评分（±30分）
        if hrvChange >= -5 {
            score += 30  // 恢复极佳
        } else if hrvChange >= -15 {
            score += 20  // 恢复良好
        } else if hrvChange >= -25 {
            score += 10  // 恢复一般
        } else {
            score += 0   // 恢复不佳
        }
        
        // 主观感受评分（±10分）
        switch subjectiveFeeling {
        case .veryEasy:
            score += 10
        case .easy:
            score += 5
        case .moderate:
            score += 0
        case .hard:
            score -= 5
        case .veryHard:
            score -= 10
        }
        
        // 主客观一致性加分（±10分）
        if isConsistent() {
            score += 10
        } else {
            score -= 5
        }
        
        return max(0, min(100, score))
    }
    
    // 判断主客观是否一致
    private func isConsistent() -> Bool {
        let objectiveLevel = getObjectiveLevel()
        let subjectiveLevel = getSubjectiveLevel()
        
        // 允许±1级的差异
        return abs(objectiveLevel - subjectiveLevel) <= 1
    }
    
    private func getObjectiveLevel() -> Int {
        if hrvChange >= -5 { return 1 }      // 轻松
        else if hrvChange >= -15 { return 2 } // 一般
        else if hrvChange >= -25 { return 3 } // 累
        else { return 4 }                     // 很累
    }
    
    private func getSubjectiveLevel() -> Int {
        switch subjectiveFeeling {
        case .veryEasy: return 1
        case .easy: return 1
        case .moderate: return 2
        case .hard: return 3
        case .veryHard: return 4
        }
    }
    
    // 生成建议
    private func generateRecommendation() -> String {
        switch quadrant {
        case .perfect:
            return "Perfect training! Your body and mind are aligned. Keep it up!"
        case .hiddenFatigue:
            return "Warning: Your body is stressed more than you feel. Reduce intensity and get more rest."
        case .mentalFatigue:
            return "Your body is fine but you feel tired. May be mental stress. Consider light recovery run or complete rest."
        case .overtraining:
            return "Overtraining detected! Take 1-2 days complete rest. Reduce training load."
        }
    }
    
    // 确定所在象限
    private func determineQuadrant() -> TrainingQuadrant {
        let objectiveEasy = hrvChange >= -10  // HRV下降<10%为轻松
        let subjectiveEasy = subjectiveFeeling.rawValue <= 2  // 感觉轻松或一般
        
        switch (subjectiveEasy, objectiveEasy) {
        case (true, true):
            return .perfect         // 主观轻松 + 客观轻松
        case (true, false):
            return .hiddenFatigue   // 主观轻松 + 客观累
        case (false, true):
            return .mentalFatigue   // 主观累 + 客观轻松
        case (false, false):
            return .overtraining    // 主观累 + 客观累
        }
    }
    
    var stars: String {
        let starCount = overallScore / 20
        return String(repeating: "⭐", count: max(1, min(5, starCount)))
    }
}

// MARK: - Subjective Feeling

enum SubjectiveFeeling: Int, Codable, CaseIterable, Identifiable {
    case veryEasy = 1   // 很轻松
    case easy = 2       // 轻松
    case moderate = 3   // 一般
    case hard = 4       // 累
    case veryHard = 5   // 很累
    
    var id: Int { rawValue }
    
    var emoji: String {
        switch self {
        case .veryEasy: return "😌"
        case .easy: return "😊"
        case .moderate: return "😐"
        case .hard: return "😓"
        case .veryHard: return "😵"
        }
    }
    
    var displayName: String {
        switch self {
        case .veryEasy: return "Very Easy"
        case .easy: return "Easy"
        case .moderate: return "Moderate"
        case .hard: return "Hard"
        case .veryHard: return "Very Hard"
        }
    }
    
    var localizedName: String {
        return displayName.localized()
    }
    
    var rpe: String {
        switch self {
        case .veryEasy: return "RPE 1-2"
        case .easy: return "RPE 3-4"
        case .moderate: return "RPE 5-6"
        case .hard: return "RPE 7-8"
        case .veryHard: return "RPE 9-10"
        }
    }
}

// MARK: - Training Quadrant

enum TrainingQuadrant: String, Codable {
    case perfect         // 完美状态
    case hiddenFatigue   // 隐性疲劳
    case mentalFatigue   // 心理疲劳
    case overtraining    // 过度训练
    
    var icon: String {
        switch self {
        case .perfect: return "checkmark.circle.fill"
        case .hiddenFatigue: return "exclamationmark.triangle.fill"
        case .mentalFatigue: return "brain.head.profile"
        case .overtraining: return "xmark.octagon.fill"
        }
    }
    
    var color: String {
        switch self {
        case .perfect: return "green"
        case .hiddenFatigue: return "orange"
        case .mentalFatigue: return "blue"
        case .overtraining: return "red"
        }
    }
    
    var displayName: String {
        switch self {
        case .perfect: return "Perfect Training"
        case .hiddenFatigue: return "Hidden Fatigue"
        case .mentalFatigue: return "Mental Fatigue"
        case .overtraining: return "Overtraining"
        }
    }
}

// MARK: - Workout Summary

struct WorkoutSummary: Identifiable, Codable, Equatable {
    let id: UUID
    let type: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval      // 秒
    let distance: Double?           // 米
    let calories: Double?           // 卡路里
    
    static func == (lhs: WorkoutSummary, rhs: WorkoutSummary) -> Bool {
        return lhs.id == rhs.id
    }
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes)min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)min"
        }
    }
    
    var formattedDistance: String? {
        guard let distance = distance else { return nil }
        let km = distance / 1000
        return String(format: "%.1f km", km)
    }
    
    var formattedPace: String? {
        guard let distance = distance, distance > 0 else { return nil }
        let totalMinutes = duration / 60
        let paceMinutes = totalMinutes / (distance / 1000)
        let mins = Int(paceMinutes)
        let secs = Int((paceMinutes - Double(mins)) * 60)
        return String(format: "%d'%02d\"/km", mins, secs)
    }
    
    var timeSinceWorkout: TimeInterval {
        return Date().timeIntervalSince(endDate)
    }
    
    var timeSinceWorkoutFormatted: String {
        let minutes = Int(timeSinceWorkout / 60)
        if minutes < 60 {
            return "\(minutes)min ago"
        } else {
            let hours = minutes / 60
            return "\(hours)h ago"
        }
    }
}

// MARK: - Post Workout HRV Data

enum PostWorkoutHRVData {
    case noWorkout                              // 没有训练
    case needMorningMeasurement                 // 缺少早晨HRV
    case needPostMeasurement(workout: WorkoutSummary, preHRV: Double)  // 需要训练后测量
    case hasData(pre: Double, post: Double, workout: WorkoutSummary)   // 有完整数据
    case missedWindow                           // 错过测量窗口
}

