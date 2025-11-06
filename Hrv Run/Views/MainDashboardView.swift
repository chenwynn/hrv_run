//
//  MainDashboardView.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//

import SwiftUI
import Charts

struct MainDashboardView: View {
    @ObservedObject var viewModel: HRVViewModel
    @State private var showSettings = false
    @State private var showExplanation: ExplanationType?
    
    // 根据恢复评分返回对应的emoji和标题
    private var navigationTitleWithEmoji: String {
        guard let score = viewModel.recommendation?.suitabilityScore else {
            return "HRV Run"
        }
        
        let emoji: String
        switch score {
        case 85...100:
            emoji = "🌟"  // 优秀
        case 70..<85:
            emoji = "😊"  // 良好
        case 55..<70:
            emoji = "😐"  // 一般
        case 40..<55:
            emoji = "😓"  // 累
        default:
            emoji = "😴"  // 很累
        }
        
        return "HRV Run \(emoji)"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if !viewModel.hasData {
                        EmptyStateView()
                    } else {
                        // Today's Recommendation Card
                        if let recommendation = viewModel.recommendation {
                            RecommendationCard(
                                recommendation: recommendation,
                                onInfoTap: { showExplanation = .recoveryScore }
                            )
                        }
                        
                        // HRV Status Card
                        if let status = viewModel.currentStatus {
                            HRVStatusCard(
                                status: status,
                                currentValue: viewModel.currentHRVValue,
                                onInfoTap: { showExplanation = .hrvStatus }
                            )
                        }
                        
                        // HRV Trend Chart
                        if !viewModel.recentHRVSamples.isEmpty,
                           let baseline = viewModel.baseline {
                            HRVTrendChart(
                                samples: viewModel.recentHRVSamples,
                                baseline: baseline,
                                onInfoTap: { showExplanation = .chart }
                            )
                        }
                        
                        // Trend Card
                        if let trend = viewModel.trend {
                            TrendCard(
                                trend: trend,
                                onInfoTap: { showExplanation = .trend }
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
                    }
                }
                .padding()
            }
            .navigationTitle(navigationTitleWithEmoji)
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
            .sheet(item: $showExplanation) { type in
                ExplanationSheet(type: type)
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
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let recommendation: WorkoutRecommendation
    let onInfoTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(LocalizedStringKey("Today's Recommendation"))
                    .font(.headline)
                
                Button {
                    onInfoTap()
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                Text(recommendation.scoreEmoji)
                    .font(.title2)
            }
            
            // Score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Recovery Score"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(recommendation.suitabilityScore))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(colorForScore(recommendation.suitabilityScore))
                }
                
                Spacer()
                
                // Gauge
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 12)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: recommendation.suitabilityScore / 100)
                        .stroke(
                            colorForScore(recommendation.suitabilityScore).gradient,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                }
            }
            
            Divider()
            
            // Workout Details
            if recommendation.shouldWorkout {
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(
                        icon: "flame.fill",
                        title: NSLocalizedString("Intensity", comment: ""),
                        value: recommendation.intensity.localizedString,
                        color: .orange
                    )
                    
                    DetailRow(
                        icon: "clock.fill",
                        title: NSLocalizedString("Duration", comment: ""),
                        value: recommendation.formattedDuration,
                        color: .blue
                    )
                    
                    if let firstType = recommendation.workoutType.first {
                        DetailRow(
                            icon: "figure.run",
                            title: NSLocalizedString("Type", comment: ""),
                            value: firstType.localizedString,
                            color: .green
                        )
                    }
                }
            }
            
            // Advice
            Text(recommendation.advice)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
    
    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 85...100: return .green
        case 70..<85: return .blue
        case 50..<70: return .yellow
        default: return .red
        }
    }
}

// MARK: - HRV Status Card

struct HRVStatusCard: View {
    let status: HRVStatus
    let currentValue: Double?
    let onInfoTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey("HRV Status"))
                    .font(.headline)
                
                Button {
                    onInfoTap()
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            
            HStack {
                // Current HRV
                VStack(alignment: .leading) {
                    Text(LocalizedStringKey("Current HRV"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let value = currentValue {
                        Text(String(format: "%.1f ms", value))
                            .font(.title2)
                            .fontWeight(.semibold)
                    } else {
                        Text("--")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Baseline
                VStack(alignment: .trailing) {
                    Text(LocalizedStringKey("Baseline"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f ms", status.baseline.mean))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            
            // Zone Indicator
            HStack(spacing: 8) {
                Text(status.zone.emoji)
                    .font(.title3)
                Text(status.zone.rawValue.capitalized)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(zoneColor(status.zone).opacity(0.2))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
    
    private func zoneColor(_ zone: HRVZone) -> Color {
        switch zone {
        case .low: return .red
        case .normal: return .yellow
        case .high: return .green
        }
    }
}

// MARK: - HRV Trend Chart

struct HRVTrendChart: View {
    let samples: [HRVSample]
    let baseline: HRVBaseline
    let onInfoTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey("7-Day Trend"))
                    .font(.headline)
                
                Button {
                    onInfoTap()
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            
            Chart {
                // Baseline line
                RuleMark(y: .value("Baseline", baseline.mean))
                    .foregroundStyle(.blue.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                
                // High threshold
                RuleMark(y: .value("High", baseline.highThreshold))
                    .foregroundStyle(.green.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                
                // Low threshold
                RuleMark(y: .value("Low", baseline.lowThreshold))
                    .foregroundStyle(.red.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                
                // HRV data points
                ForEach(recentSamples()) { sample in
                    LineMark(
                        x: .value("Date", sample.date),
                        y: .value("HRV", sample.value)
                    )
                    .foregroundStyle(.purple.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Date", sample.date),
                        y: .value("HRV", sample.value)
                    )
                    .foregroundStyle(.purple)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
    
    private func recentSamples() -> [HRVSample] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return samples.filter { $0.date >= sevenDaysAgo }
    }
}

// MARK: - Trend Card

struct TrendCard: View {
    let trend: HRVTrend
    let onInfoTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(LocalizedStringKey("Trend"))
                    .font(.headline)
                
                Button {
                    onInfoTap()
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Direction"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text(trend.direction.emoji)
                            .font(.title2)
                        Text(trend.direction.rawValue.capitalized)
                            .font(.headline)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f%%", abs(trend.changePercentage)))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(trend.direction == .improving ? .green : trend.direction == .declining ? .red : .secondary)
                    
                    Text(trend.confidence.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(LocalizedStringKey(title))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(LocalizedStringKey(value))
                .fontWeight(.medium)
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(LocalizedStringKey("No Data"))
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(LocalizedStringKey("Not enough data to establish baseline. Wear your Apple Watch for at least 20 days."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    MainDashboardView(viewModel: HRVViewModel())
}

