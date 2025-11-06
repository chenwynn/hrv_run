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
    @StateObject private var appSettings = AppSettings.shared
    @State private var showSettings = false
    @State private var showDetailedData = false
    @State private var showWorkoutsList = false
    @State private var evaluationItem: EvaluationItem?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if !viewModel.hasData {
                        EmptyStateView()
                    } else if viewModel.needsTodayMeasurement {
                        // 需要今天的HRV测量
                        TodayMeasurementPromptView()
                    } else {
                        // 核心问题卡片
                        coreQuestionsSection
                        
                        // 查看详细数据入口
                        detailedDataButton
                    }
                }
                .padding()
            }
            .id(appSettings.selectedLanguage)
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
            .sheet(isPresented: $showWorkoutsList) {
                WorkoutSelectionSheet(
                    viewModel: viewModel,
                    onWorkoutSelected: { workout in
                        // print("🔵 [Step 1] User clicked workout: \(workout.type) at \(workout.startDate)")
                        
                        // 异步加载数据
                        Task {
                            // print("🔵 [Step 2] Started async task")
                            
                            // 1. 先加载HRV数据
                            // print("🔵 [Step 3] Loading HRV data...")
                            let hrvData = await viewModel.getPostWorkoutHRVData(for: workout)
                            // print("🔵 [Step 4] HRV data loaded")
                            
                            // 2. 准备数据
                            var item: EvaluationItem?
                            switch hrvData {
                            case .hasData(let pre, let post, _):
                                item = EvaluationItem(workout: workout, preHRV: pre, postHRV: post)
                                // print("✅ [Step 5] Data ready - Pre: \(pre)ms, Post: \(post)ms")
                            case .needPostMeasurement(_, let pre):
                                item = EvaluationItem(workout: workout, preHRV: pre, postHRV: nil)
                                // print("⚠️ [Step 5] Need post measurement - Pre: \(pre)ms")
                            default:
                                item = nil
                                // print("❌ [Step 5] No data available")
                            }
                            
                            // 3. 确保数据准备好了
                            guard item != nil else {
                                // print("❌ [Step 6] Evaluation item is nil, aborting")
                                return
                            }
                            // print("✅ [Step 6] Data confirmed - Workout: \(item!.workout.type)")
                            
                            // 4. 关闭列表
                            await MainActor.run {
                                // print("🔵 [Step 7] Closing workout list sheet")
                                showWorkoutsList = false
                            }
                            
                            // 5. 等待列表sheet关闭动画完成
                            // print("🔵 [Step 8] Waiting for sheet close animation (0.4s)...")
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            // print("🔵 [Step 9] Animation wait complete")
                            
                            // 6. 设置评估item（这会触发sheet打开）
                            await MainActor.run {
                                // print("🔵 [Step 10] Setting evaluation item")
                                // print("🔵 [Step 10a] Workout: \(item!.workout.type)")
                                // print("🔵 [Step 10b] Pre-HRV: \(item!.preHRV)ms")
                                // print("🔵 [Step 10c] Post-HRV: \(item!.postHRV != nil ? "\(item!.postHRV!)ms" : "nil")")
                                evaluationItem = item
                                // print("✅ [Step 11] Evaluation item set, sheet should open")
                            }
                        }
                    }
                )
            }
            .sheet(item: $evaluationItem) { item in
                PostWorkoutEvaluationView(
                    viewModel: viewModel,
                    workout: item.workout,
                    preWorkoutHRV: item.preHRV,
                    postWorkoutHRV: item.postHRV
                )
                // .onAppear {
                //     print("🟢 [Sheet] Evaluation sheet appeared with item")
                //     print("🟢 [Sheet] Workout: \(item.workout.type)")
                //     print("🟢 [Sheet] Pre-HRV: \(item.preHRV)ms")
                //     print("🟢 [Sheet] Post-HRV: \(item.postHRV != nil ? "\(item.postHRV!)ms" : "nil")")
                // }
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
                question: "Is today suitable for running?".localized(),
                answer: todaySuitability,
                icon: "checkmark.circle.fill",
                color: suitabilityColor
            )
            
            // Question 2: When to run?
            if let window = viewModel.optimalWindow {
                QuestionCard(
                    question: "When to run?".localized(),
                    answer: formatTimeWindow(window),
                    icon: "clock.fill",
                    color: .blue
                )
            }
            
            // Question 3: What to run?
            if let recommendation = viewModel.recommendation {
                QuestionCard(
                    question: "What to run?".localized(),
                    answer: workoutPlan(recommendation),
                    icon: "figure.run",
                    color: .green
                )
            }
            
            // Question 4: How was the run?
            Question4Card(
                viewModel: viewModel,
                onEvaluateTap: {
                    showWorkoutsList = true
                }
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
                Text(LocalizedStringKey("View Detailed Data and Trends"))
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
            return "No data available".localized()
        }
        
        if recommendation.shouldWorkout {
            if recommendation.suitabilityScore >= 85 {
                return "Perfect! Excellent condition".localized()
            } else if recommendation.suitabilityScore >= 70 {
                return "Good to go".localized()
            } else {
                return "Okay, but control intensity".localized()
            }
        } else {
            return "Not recommended, rest today".localized()
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
        
        let optimalWindow = "Optimal window".localized()
        return "\(startTime) - \(endTime)\n\(optimalWindow)"
    }
    
    private func workoutPlan(_ recommendation: WorkoutRecommendation) -> String {
        let intensity = recommendation.intensity.localizedString
        let duration = recommendation.formattedDuration
        let type = recommendation.workoutType.first?.localizedString ?? "Running".localized()
        
        return "\(type)\n\(intensity) · \(duration)"
    }
}

// MARK: - Question 4 Card

struct Question4Card: View {
    @ObservedObject var viewModel: HRVViewModel
    let onEvaluateTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question Header
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.headline)
                    .foregroundColor(.purple)
                
                Text("How was the run?".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Answer or Evaluation Result
            if let evaluationText = viewModel.getLatestWorkoutEvaluation() {
                // 显示评估结果
                Text(evaluationText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                    .multilineTextAlignment(.leading)
            } else if !viewModel.recentWorkouts.isEmpty {
                // 有训练但未评估
                Text("Tap to evaluate your training".localized())
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                // 没有训练
                Text("Complete a workout to evaluate".localized())
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // 评估按钮
            if !viewModel.recentWorkouts.isEmpty {
                Button {
                    onEvaluateTap()
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Evaluate Training".localized())
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.purple)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
}

// MARK: - Question Card

struct QuestionCard: View {
    let question: String
    let answer: String
    let icon: String
    let color: Color
    var isPlaceholder: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question Header with Icon
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(color)
                
                Text(question)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
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
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
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
            .navigationTitle(LocalizedStringKey("Detailed Data"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Done")) {
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
            
            Text(LocalizedStringKey("No HRV Data"))
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(LocalizedStringKey("Use Apple Watch to measure HRV or start with Breathe app"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Today Measurement Prompt

struct TodayMeasurementPromptView: View {
    var body: some View {
        VStack(spacing: 24) {
            // 提示卡片
            VStack(spacing: 16) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple.gradient)
                
                Text("Good Morning!".localized())
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Please measure your HRV to get today's recommendations".localized())
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
            )
            
            // 测量步骤
            VStack(alignment: .leading, spacing: 12) {
                Text("How to measure:".localized())
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    MeasurementStep(
                        number: "1",
                        text: "Open Breathe app on Apple Watch".localized()
                    )
                    
                    MeasurementStep(
                        number: "2",
                        text: "Complete a 1-minute breathing session".localized()
                    )
                    
                    MeasurementStep(
                        number: "3",
                        text: "HRV will sync automatically".localized()
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
            )
            
            // 最佳测量时间提示
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Best time: 6-10 AM right after waking up".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Measurement Step

struct MeasurementStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.purple)
                .clipShape(Circle())
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Evaluation Item

struct EvaluationItem: Identifiable, Equatable {
    let id = UUID()
    let workout: WorkoutSummary
    let preHRV: Double
    let postHRV: Double?
    
    static func == (lhs: EvaluationItem, rhs: EvaluationItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Preview

#Preview {
    SimplifiedMainDashboardView(viewModel: HRVViewModel())
}

