//
//  RecoveryScoreDetailView.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//  Multi-Dimensional Recovery Score Detail View
//

import SwiftUI

struct RecoveryScoreDetailView: View {
    let recoveryScore: MultiDimensionalRecoveryScore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery Analysis")
                        .font(.headline)
                    Text("Multi-dimensional assessment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Overall score
                VStack(spacing: 4) {
                    Text(recoveryScore.level.emoji)
                        .font(.title)
                    Text("\(Int(recoveryScore.totalScore))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(colorForLevel(recoveryScore.level))
                }
            }
            
            // Score breakdown
            VStack(spacing: 12) {
                Text("Score Breakdown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ScoreComponentBar(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    score: recoveryScore.hrvScore,
                    weight: 50,
                    color: .purple
                )
                
                if recoveryScore.restingHeartRate != nil {
                    ScoreComponentBar(
                        icon: "heart.fill",
                        label: "Resting Heart Rate",
                        score: recoveryScore.restingHeartRateScore,
                        weight: 20,
                        color: .red
                    )
                }
                
                if recoveryScore.sleepQuality != nil {
                    ScoreComponentBar(
                        icon: "bed.double.fill",
                        label: "Sleep Quality",
                        score: recoveryScore.sleepScore,
                        weight: 20,
                        color: .blue
                    )
                }
                
                if recoveryScore.trainingLoad != nil {
                    ScoreComponentBar(
                        icon: "figure.run",
                        label: "Training Load",
                        score: recoveryScore.trainingLoadScore,
                        weight: 10,
                        color: .orange
                    )
                }
            }
            
            Divider()
            
            // Detailed metrics
            VStack(alignment: .leading, spacing: 12) {
                Text("Detailed Metrics")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                MetricRow(
                    icon: "waveform.path.ecg",
                    label: "Current HRV",
                    value: "\(String(format: "%.1f", recoveryScore.hrvValue)) ms",
                    color: .purple
                )
                
                if let rhr = recoveryScore.restingHeartRate {
                    MetricRow(
                        icon: "heart.fill",
                        label: "Resting Heart Rate",
                        value: "\(Int(rhr)) bpm",
                        color: .red,
                        status: rhrStatus(rhr)
                    )
                }
                
                if let sleep = recoveryScore.sleepQuality {
                    MetricRow(
                        icon: "bed.double.fill",
                        label: "Sleep Duration",
                        value: String(format: "%.1fh", sleep.totalSleepHours),
                        color: .blue,
                        status: sleepStatus(sleep)
                    )
                    
                    MetricRow(
                        icon: "moon.zzz.fill",
                        label: "Deep Sleep",
                        value: String(format: "%.1fh", sleep.deepSleepHours),
                        color: .indigo
                    )
                }
                
                if let load = recoveryScore.trainingLoad {
                    MetricRow(
                        icon: "figure.run",
                        label: "Training Load",
                        value: "\(Int(load))",
                        color: .orange,
                        status: loadStatus(load)
                    )
                }
            }
            
            // Improvement suggestions
            if !recoveryScore.improvementSuggestions.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Improvement Suggestions")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    ForEach(Array(recoveryScore.improvementSuggestions.enumerated()), id: \.offset) { index, suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            
            // Recommendation
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "figure.run.circle.fill")
                        .foregroundColor(.green)
                    Text("Recommendation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text(recoveryScore.recommendation)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorForLevel(recoveryScore.level).opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(colorForLevel(recoveryScore.level), lineWidth: 1)
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Helper Methods
    
    private func colorForLevel(_ level: RecoveryLevel) -> Color {
        switch level {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .veryPoor: return .red
        }
    }
    
    private func rhrStatus(_ rhr: Double) -> String {
        if rhr < 60 {
            return "Excellent"
        } else if rhr < 70 {
            return "Good"
        } else if rhr < 80 {
            return "Fair"
        } else {
            return "Elevated"
        }
    }
    
    private func sleepStatus(_ sleep: SleepQuality) -> String {
        if sleep.totalSleepHours >= 7 && sleep.totalSleepHours <= 9 {
            return "Optimal"
        } else if sleep.totalSleepHours >= 6 {
            return "Good"
        } else {
            return "Insufficient"
        }
    }
    
    private func loadStatus(_ load: Double) -> String {
        if load < 30 {
            return "Light"
        } else if load < 60 {
            return "Moderate"
        } else {
            return "High"
        }
    }
}

// MARK: - Supporting Views

struct ScoreComponentBar: View {
    let icon: String
    let label: String
    let score: Double
    let weight: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(LocalizedStringKey(label))
                    .font(.caption)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(Int(score))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                Text("(\(weight)%)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * (score / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var status: String? = nil
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(LocalizedStringKey(label))
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            if let status = status {
                Text(LocalizedStringKey(status))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(4)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        RecoveryScoreDetailView(
            recoveryScore: MultiDimensionalRecoveryScore(
                totalScore: 75,
                hrvScore: 80,
                restingHeartRateScore: 70,
                sleepScore: 65,
                trainingLoadScore: 85,
                level: .good,
                hrvValue: 52,
                restingHeartRate: 65,
                sleepQuality: SleepQuality(
                    totalSleepHours: 7.5,
                    deepSleepHours: 1.8,
                    score: 65,
                    date: Date()
                ),
                trainingLoad: 45
            )
        )
        .padding()
    }
}

