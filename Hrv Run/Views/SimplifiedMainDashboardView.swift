//
//  SimplifiedMainDashboardView.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//  Simplified UI focused on core questions
//

import SwiftUI

struct SimplifiedMainDashboardView: View {
    @ObservedObject var viewModel: HRVViewModel
    @State private var showSettings = false
    @State private var showDetailedData = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if !viewModel.hasData {
                        EmptyStateView()
                    } else {
                        // 核心问题卡片
                        coreQuestionsSection
                        
                        // 查看详细数据入口
                        detailedDataButton
                    }
                }
                .padding()
            }
            .navigationTitle("HRV Run \(statusEmoji)")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showDetailedData) {
                DetailedDataView(viewModel: viewModel)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            if viewModel.hasData == false && !viewModel.needsAuthorization {
                await viewModel.loadData()
            }
        }
    }
    
    // MARK: - Core Questions Section
    
    private var coreQuestionsSection: some View {
        VStack(spacing: 16) {
            // Question 1: Is today suitable for running?
            QuestionCard(
                number: "1",
                question: "Is today suitable for running?",
                answer: todaySuitability,
                emoji: suitabilityEmoji,
                color: suitabilityColor
            )
            
            // Question 2: When to run?
            if let window = viewModel.optimalWindow {
                QuestionCard(
                    number: "2",
                    question: "When to run?",
                    answer: formatTimeWindow(window),
                    emoji: "⏰",
                    color: .blue
                )
            }
            
            // Question 3: What to run?
            if let recommendation = viewModel.recommendation {
                QuestionCard(
                    number: "3",
                    question: "What to run?",
                    answer: workoutPlan(recommendation),
                    emoji: "🏃‍♂️",
                    color: .green
                )
            }
            
            // Question 4: How was the run?
            QuestionCard(
                number: "4",
                question: "How was the run?",
                answer: "Measure HRV after training to see results",
                emoji: "📊",
                color: .purple,
                isPlaceholder: true
            )
        }
    }
    
    // MARK: - Detailed Data Button
    
    private var detailedDataButton: some View {
        Button {
            showDetailedData = true
        } label: {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                Text("View Detailed Data and Trends")
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Properties
    
    private var statusEmoji: String {
        guard let score = viewModel.recommendation?.suitabilityScore else {
            return ""
        }
        
        switch score {
        case 85...100: return "🌟"
        case 70..<85: return "😊"
        case 55..<70: return "😐"
        case 40..<55: return "😓"
        default: return "😴"
        }
    }
    
    private var todaySuitability: String {
        guard let recommendation = viewModel.recommendation else {
            return "No data available"
        }
        
        if recommendation.shouldWorkout {
            if recommendation.suitabilityScore >= 85 {
                return "Perfect! Excellent condition"
            } else if recommendation.suitabilityScore >= 70 {
                return "Good to go"
            } else {
                return "Okay, but control intensity"
            }
        } else {
            return "Not recommended, rest today"
        }
    }
    
    private var suitabilityEmoji: String {
        guard let score = viewModel.recommendation?.suitabilityScore else {
            return "❓"
        }
        
        if score >= 85 {
            return "✅"
        } else if score >= 70 {
            return "👍"
        } else if score >= 50 {
            return "⚠️"
        } else {
            return "🛑"
        }
    }
    
    private var suitabilityColor: Color {
        guard let score = viewModel.recommendation?.suitabilityScore else {
            return .gray
        }
        
        if score >= 85 {
            return .green
        } else if score >= 70 {
            return .blue
        } else if score >= 50 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func formatTimeWindow(_ window: WorkoutWindow) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let startTime = formatter.string(from: window.timeRange.start)
        let endTime = formatter.string(from: window.timeRange.end)
        
        return "\(startTime) - \(endTime)\nOptimal window"
    }
    
    private func workoutPlan(_ recommendation: WorkoutRecommendation) -> String {
        let intensity = recommendation.intensity.localizedString
        let duration = recommendation.formattedDuration
        let type = recommendation.workoutType.first?.localizedString ?? "Running"
        
        return "\(type)\n\(intensity) · \(duration)"
    }
}

// MARK: - Question Card

struct QuestionCard: View {
    let number: String
    let question: String
    let answer: String
    let emoji: String
    let color: Color
    var isPlaceholder: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question Header
            HStack(spacing: 8) {
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(color)
                    .clipShape(Circle())
                
                Text(question)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(emoji)
                    .font(.title2)
            }
            
            // Answer
            Text(answer)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(isPlaceholder ? .secondary : color)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Detailed Data View

struct DetailedDataView: View {
    @ObservedObject var viewModel: HRVViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // HRV Status Card
                    if let status = viewModel.currentStatus {
                        HRVStatusCard(
                            status: status,
                            currentValue: viewModel.currentHRVValue,
                            onInfoTap: {}
                        )
                    }
                    
                    // HRV Trend Chart
                    if !viewModel.recentHRVSamples.isEmpty,
                       let baseline = viewModel.baseline {
                        HRVTrendChart(
                            samples: viewModel.recentHRVSamples,
                            baseline: baseline,
                            onInfoTap: {}
                        )
                    }
                    
                    // Data Quality Indicator
                    if !viewModel.recentHRVSamples.isEmpty {
                        DataQualityIndicatorView(
                            samples: viewModel.recentHRVSamples,
                            baseline: viewModel.baseline
                        )
                    }
                    
                    // HRV Calendar Heatmap
                    if !viewModel.recentHRVSamples.isEmpty {
                        HRVCalendarHeatmapView(
                            samples: viewModel.recentHRVSamples,
                            baseline: viewModel.baseline
                        )
                    }
                    
                    // Trend Card
                    if let trend = viewModel.trend {
                        TrendCard(
                            trend: trend,
                            onInfoTap: {}
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Detailed Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No HRV Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Use Apple Watch to measure HRV or start with Breathe app")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    SimplifiedMainDashboardView(viewModel: HRVViewModel())
}

