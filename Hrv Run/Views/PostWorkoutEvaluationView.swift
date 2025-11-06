//
//  PostWorkoutEvaluationView.swift
//  Hrv Run
//
//  Created by AI on 2025/11/7.
//

import SwiftUI
import HealthKit

struct PostWorkoutEvaluationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: HRVViewModel
    
    let workout: WorkoutSummary
    let preWorkoutHRV: Double
    let postWorkoutHRV: Double?
    
    @State private var selectedFeeling: SubjectiveFeeling = .moderate
    @State private var showingSaved = false
    @State private var isLoading = true
    
    private var hrvChange: Double {
        guard let postHRV = postWorkoutHRV else { return 0 }
        return ((postHRV - preWorkoutHRV) / preWorkoutHRV) * 100
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    // 加载指示器
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading training data...".localized())
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // 1. 训练数据
                            workoutDataSection
                            
                            // 2. HRV变化分析
                            hrvAnalysisSection
                            
                            // 3. 主观感受选择
                            if postWorkoutHRV != nil {
                                subjectiveFeelingSection
                                
                                // 4. AI综合评估
                                aiAnalysisSection
                            } else {
                                // 提示需要测量HRV
                                needMeasurementPrompt
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Post-Workout Evaluation".localized())
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // 短暂延迟后显示内容，确保动画流畅
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                isLoading = false
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel".localized()) {
                        dismiss()
                    }
                }
                
                if postWorkoutHRV != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save".localized()) {
                            saveEvaluation()
                        }
                    }
                }
            }
            .alert("Saved".localized(), isPresented: $showingSaved) {
                Button("OK".localized()) {
                    dismiss()
                }
            } message: {
                Text("Training evaluation saved successfully".localized())
            }
        }
    }
    
    // MARK: - Workout Data Section
    
    private var workoutDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Data".localized())
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundColor(.blue)
                    Text(workout.type.localized())
                    Spacer()
                    Text(workout.formattedDuration)
                        .foregroundColor(.secondary)
                }
                
                if let distance = workout.formattedDistance {
                    HStack {
                        Image(systemName: "map")
                            .foregroundColor(.green)
                        Text("Distance".localized())
                        Spacer()
                        Text(distance)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let pace = workout.formattedPace {
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundColor(.orange)
                        Text("Pace".localized())
                        Spacer()
                        Text(pace)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let calories = workout.calories {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.red)
                        Text("Calories".localized())
                        Spacer()
                        Text("\(Int(calories)) kcal")
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.purple)
                    Text("Finished".localized())
                    Spacer()
                    Text(workout.timeSinceWorkoutFormatted.localized())
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - HRV Analysis Section
    
    private var hrvAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HRV Change".localized())
                .font(.headline)
            
            VStack(spacing: 16) {
                // HRV对比
                HStack {
                    VStack(alignment: .leading) {
                        Text("Pre-Workout".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(preWorkoutHRV)) ms")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Post-Workout".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let postHRV = postWorkoutHRV {
                            Text("\(Int(postHRV)) ms")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(colorForChange(hrvChange))
                        } else {
                            Text("Not measured".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 可视化对比条
                if let postHRV = postWorkoutHRV {
                    VStack(alignment: .leading, spacing: 8) {
                        // 训练前
                        HStack {
                            Text("Pre".localized())
                                .font(.caption2)
                                .frame(width: 40, alignment: .leading)
                            GeometryReader { geometry in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: geometry.size.width)
                            }
                            .frame(height: 8)
                        }
                        
                        // 训练后
                        HStack {
                            Text("Post".localized())
                                .font(.caption2)
                                .frame(width: 40, alignment: .leading)
                            GeometryReader { geometry in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(colorForChange(hrvChange).opacity(0.8))
                                    .frame(width: geometry.size.width * CGFloat(postHRV / preWorkoutHRV))
                            }
                            .frame(height: 8)
                        }
                    }
                    .frame(height: 40)
                    
                    // 变化百分比
                    Text("Change: \(hrvChange >= 0 ? "+" : "")\(String(format: "%.1f", hrvChange))%")
                        .font(.headline)
                        .foregroundColor(colorForChange(hrvChange))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - Subjective Feeling Section
    
    private var subjectiveFeelingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How did you feel?".localized())
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(SubjectiveFeeling.allCases) { feeling in
                    Button {
                        selectedFeeling = feeling
                    } label: {
                        HStack {
                            Text(feeling.emoji)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feeling.localizedName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(feeling.rpe)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedFeeling == feeling {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.title3)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedFeeling == feeling ? Color.accentColor.opacity(0.1) : Color(.tertiarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - AI Analysis Section
    
    private var aiAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Analysis".localized())
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                // 综合评分
                HStack {
                    Text("Overall Score".localized())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(evaluation.stars)
                        .font(.title3)
                    Text("\(evaluation.overallScore)/100")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(colorForScore(evaluation.overallScore))
                }
                
                Divider()
                
                // 四象限判断
                HStack(spacing: 12) {
                    Image(systemName: evaluation.quadrant.icon)
                        .font(.title2)
                        .foregroundColor(quadrantColor(evaluation.quadrant))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(evaluation.quadrant.displayName.localized())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if isConsistent {
                            Text("Subjective and objective data match".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Warning: Data mismatch detected".localized())
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Divider()
                
                // 个性化建议
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Recommendations".localized())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Text(evaluation.recommendation.localized())
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - Need Measurement Prompt
    
    private var needMeasurementPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Measure HRV Now".localized())
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Measure your HRV now to evaluate training effect".localized())
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Helper Properties
    
    private var evaluation: PostWorkoutEvaluation {
        PostWorkoutEvaluation(
            id: UUID(),
            workout: workout,
            preWorkoutHRV: preWorkoutHRV,
            postWorkoutHRV: postWorkoutHRV ?? preWorkoutHRV,
            hrvChange: hrvChange,
            subjectiveFeeling: selectedFeeling,
            evaluationDate: Date()
        )
    }
    
    private var isConsistent: Bool {
        let objectiveLevel = getObjectiveLevel()
        let subjectiveLevel = selectedFeeling.rawValue
        return abs(objectiveLevel - subjectiveLevel) <= 1
    }
    
    private func getObjectiveLevel() -> Int {
        if hrvChange >= -5 { return 1 }
        else if hrvChange >= -15 { return 2 }
        else if hrvChange >= -25 { return 3 }
        else { return 4 }
    }
    
    private func colorForChange(_ change: Double) -> Color {
        if change >= -5 { return .green }
        else if change >= -15 { return .blue }
        else if change >= -25 { return .orange }
        else { return .red }
    }
    
    private func colorForScore(_ score: Int) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .blue }
        else if score >= 40 { return .orange }
        else { return .red }
    }
    
    private func quadrantColor(_ quadrant: TrainingQuadrant) -> Color {
        switch quadrant {
        case .perfect: return .green
        case .hiddenFatigue: return .orange
        case .mentalFatigue: return .blue
        case .overtraining: return .red
        }
    }
    
    // MARK: - Actions
    
    private func saveEvaluation() {
        // 保存评估记录
        viewModel.savePostWorkoutEvaluation(evaluation)
        showingSaved = true
    }
}

// MARK: - Workout Selection Sheet

struct WorkoutSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: HRVViewModel
    let onWorkoutSelected: (WorkoutSummary) -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.recentWorkouts.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            
                            Text("No Recent Workouts".localized())
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Complete a workout to see it here".localized())
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ForEach(viewModel.recentWorkouts) { workout in
                            WorkoutRowView(
                                workout: workout,
                                onEvaluate: {
                                    onWorkoutSelected(workout)
                                }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Today's Workouts".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done".localized()) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Workout Row View

struct WorkoutRowView: View {
    let workout: WorkoutSummary
    let onEvaluate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: workoutIcon(workout.type))
                    .foregroundColor(.purple)
                Text(workout.type.localized())
                    .font(.headline)
                Spacer()
                Text(workout.timeSinceWorkoutFormatted.localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 训练数据
            VStack(spacing: 6) {
                HStack {
                    Label(workout.formattedDuration, systemImage: "timer")
                        .font(.subheadline)
                    Spacer()
                    if let distance = workout.formattedDistance {
                        Label(distance, systemImage: "map")
                            .font(.subheadline)
                    }
                }
                
                if let pace = workout.formattedPace {
                    HStack {
                        Label(pace, systemImage: "speedometer")
                            .font(.subheadline)
                        Spacer()
                        if let calories = workout.calories {
                            Label("\(Int(calories)) kcal", systemImage: "flame.fill")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .foregroundColor(.secondary)
            
            // 评估按钮
            Button {
                onEvaluate()
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
    
    private func workoutIcon(_ type: String) -> String {
        switch type {
        case "Running": return "figure.run"
        case "Cycling": return "figure.outdoor.cycle"
        case "Walking": return "figure.walk"
        case "Swimming": return "figure.pool.swim"
        case "Hiking": return "figure.hiking"
        default: return "figure.mixed.cardio"
        }
    }
}

#Preview {
    PostWorkoutEvaluationView(
        viewModel: HRVViewModel(),
        workout: WorkoutSummary(
            id: UUID(),
            type: "Running",
            startDate: Date().addingTimeInterval(-3600),
            endDate: Date().addingTimeInterval(-1800),
            duration: 1800,
            distance: 6800,
            calories: 420
        ),
        preWorkoutHRV: 55,
        postWorkoutHRV: 48
    )
}

