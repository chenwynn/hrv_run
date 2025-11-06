//
//  ExplanationContent.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//

import Foundation

struct ExplanationContent {
    let title: String
    let description: String
    let goodRange: RangeInfo
    let normalRange: RangeInfo?
    let badRange: RangeInfo
    let recommendations: [String]
    
    struct RangeInfo {
        let range: String
        let description: String
        let emoji: String
    }
}

enum ExplanationType: Identifiable {
    case recoveryScore
    case hrvStatus
    case trend
    case chart
    
    var id: String {
        switch self {
        case .recoveryScore: return "recoveryScore"
        case .hrvStatus: return "hrvStatus"
        case .trend: return "trend"
        case .chart: return "chart"
        }
    }
    
    var content: ExplanationContent {
        switch self {
        case .recoveryScore:
            return ExplanationContent(
                title: NSLocalizedString("Recovery Score Explanation", comment: ""),
                description: NSLocalizedString("Recovery Score Description", comment: ""),
                goodRange: ExplanationContent.RangeInfo(
                    range: "85-100",
                    description: NSLocalizedString("Excellent recovery. Your body is fully recovered and ready for high-intensity training.", comment: ""),
                    emoji: "🌟"
                ),
                normalRange: ExplanationContent.RangeInfo(
                    range: "70-84",
                    description: NSLocalizedString("Good recovery. Suitable for moderate training as planned.", comment: ""),
                    emoji: "✅"
                ),
                badRange: ExplanationContent.RangeInfo(
                    range: "0-69",
                    description: NSLocalizedString("Below optimal. Your body needs more rest. Consider light exercise or rest day.", comment: ""),
                    emoji: "⚠️"
                ),
                recommendations: [
                    NSLocalizedString("85-100: High-intensity training, intervals, tempo runs", comment: ""),
                    NSLocalizedString("70-84: Moderate training, easy runs, steady pace", comment: ""),
                    NSLocalizedString("50-69: Light exercise, recovery runs, walking", comment: ""),
                    NSLocalizedString("0-49: Rest or very light activity recommended", comment: "")
                ]
            )
            
        case .hrvStatus:
            return ExplanationContent(
                title: NSLocalizedString("HRV Status Explanation", comment: ""),
                description: NSLocalizedString("HRV Status Description", comment: ""),
                goodRange: ExplanationContent.RangeInfo(
                    range: NSLocalizedString("Above Baseline + 1SD", comment: ""),
                    description: NSLocalizedString("High Zone: Excellent recovery, body is well-rested and ready for intense training.", comment: ""),
                    emoji: "💪"
                ),
                normalRange: ExplanationContent.RangeInfo(
                    range: NSLocalizedString("Baseline ± 1SD", comment: ""),
                    description: NSLocalizedString("Normal Zone: Good recovery, suitable for regular training.", comment: ""),
                    emoji: "👍"
                ),
                badRange: ExplanationContent.RangeInfo(
                    range: NSLocalizedString("Below Baseline - 1SD", comment: ""),
                    description: NSLocalizedString("Low Zone: Body needs rest, avoid high-intensity training.", comment: ""),
                    emoji: "😴"
                ),
                recommendations: [
                    NSLocalizedString("High Zone: Great time for challenging workouts, PRs, hard sessions", comment: ""),
                    NSLocalizedString("Normal Zone: Proceed with planned training, maintain consistency", comment: ""),
                    NSLocalizedString("Low Zone: Focus on recovery, sleep 8+ hours, stay hydrated", comment: "")
                ]
            )
            
        case .trend:
            return ExplanationContent(
                title: NSLocalizedString("Trend Explanation", comment: ""),
                description: NSLocalizedString("Trend Description", comment: ""),
                goodRange: ExplanationContent.RangeInfo(
                    range: NSLocalizedString("Improving (↑)", comment: ""),
                    description: NSLocalizedString("Your HRV is trending upward, indicating improving recovery and adaptation to training.", comment: ""),
                    emoji: "📈"
                ),
                normalRange: ExplanationContent.RangeInfo(
                    range: NSLocalizedString("Stable (→)", comment: ""),
                    description: NSLocalizedString("Your HRV is stable, indicating consistent recovery status.", comment: ""),
                    emoji: "➡️"
                ),
                badRange: ExplanationContent.RangeInfo(
                    range: NSLocalizedString("Declining (↓)", comment: ""),
                    description: NSLocalizedString("Your HRV is trending downward, may indicate accumulated fatigue or overtraining.", comment: ""),
                    emoji: "📉"
                ),
                recommendations: [
                    NSLocalizedString("Improving: Good sign! You can maintain or slightly increase training load", comment: ""),
                    NSLocalizedString("Stable: Maintain current training and recovery balance", comment: ""),
                    NSLocalizedString("Declining: Warning sign! Add rest days, reduce intensity, focus on recovery", comment: ""),
                    NSLocalizedString("Monitor for 3-5 days before making major training changes", comment: "")
                ]
            )
            
        case .chart:
            return ExplanationContent(
                title: NSLocalizedString("HRV Chart Explanation", comment: ""),
                description: NSLocalizedString("HRV Chart Description", comment: ""),
                goodRange: ExplanationContent.RangeInfo(
                    range: NSLocalizedString("Above Green Line", comment: ""),
                    description: NSLocalizedString("Data points above the high threshold indicate excellent recovery days.", comment: ""),
                    emoji: "💚"
                ),
                normalRange: ExplanationContent.RangeInfo(
                    range: NSLocalizedString("Between Green and Red Lines", comment: ""),
                    description: NSLocalizedString("Data points in normal range indicate typical recovery status.", comment: ""),
                    emoji: "💛"
                ),
                badRange: ExplanationContent.RangeInfo(
                    range: NSLocalizedString("Below Red Line", comment: ""),
                    description: NSLocalizedString("Data points below low threshold indicate need for recovery.", comment: ""),
                    emoji: "❤️"
                ),
                recommendations: [
                    NSLocalizedString("Blue Dashed Line: Your personal baseline (average)", comment: ""),
                    NSLocalizedString("Green Dashed Line: High threshold (baseline + 1SD)", comment: ""),
                    NSLocalizedString("Red Dashed Line: Low threshold (baseline - 1SD)", comment: ""),
                    NSLocalizedString("Purple Line: Your actual HRV measurements over time", comment: ""),
                    NSLocalizedString("Look for patterns: consistent highs, lows, or fluctuations", comment: "")
                ]
            )
        }
    }
}

