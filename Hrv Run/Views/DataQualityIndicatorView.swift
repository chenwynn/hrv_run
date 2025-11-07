//
//  DataQualityIndicatorView.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//  Data Quality Indicator Component
//

import SwiftUI

struct DataQualityIndicatorView: View {
    let samples: [HRVSample]
    let baseline: HRVBaseline?
    
    private let analyzer = HRVAnalyzer.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.accentColor)
                Text("Data Quality")
                    .font(.headline)
                
                Spacer()
                
                if let quality = overallQuality {
                    HStack(spacing: 4) {
                        Text(quality.level.emoji)
                        Text(quality.level.localizedString)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(qualityColor(quality.level))
                    }
                }
            }
            
            // Quality Breakdown
            if !samples.isEmpty {
                VStack(spacing: 12) {
                    // Recent measurements quality
                    let recentSamples = Array(samples.suffix(7))
                    let qualityDistribution = calculateQualityDistribution(recentSamples)
                    
                    HStack(spacing: 8) {
                        QualityBar(
                            label: "Excellent",
                            count: qualityDistribution.excellent,
                            total: recentSamples.count,
                            color: .green
                        )
                        
                        QualityBar(
                            label: "Good",
                            count: qualityDistribution.good,
                            total: recentSamples.count,
                            color: .blue
                        )
                        
                        QualityBar(
                            label: "Fair",
                            count: qualityDistribution.fair,
                            total: recentSamples.count,
                            color: .orange
                        )
                        
                        QualityBar(
                            label: "Poor",
                            count: qualityDistribution.poor,
                            total: recentSamples.count,
                            color: .red
                        )
                    }
                    .frame(height: 60)
                    
                    // Quality tips
                    if let latestSample = samples.last {
                        let quality = analyzer.assessDataQuality(sample: latestSample)
                        
                        if quality.level != .excellent {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("💡 Tips for Better Quality")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                ForEach(Array(quality.issues.enumerated()), id: \.offset) { index, issue in
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        Text(localizedIssue(issue))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // Best practice
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                    Text("Best time: 6-10 AM, right after waking up")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Baseline quality info
            if let baseline = baseline {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Baseline Quality")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 16) {
                        InfoItem(
                            icon: "chart.bar.fill",
                            label: "Samples",
                            value: "\(baseline.sampleCount)"
                        )
                        
                        InfoItem(
                            icon: "waveform.path.ecg",
                            label: "Stability",
                            value: baseline.stabilityRating
                        )
                        
                        if baseline.outlierRemovedCount > 0 {
                            InfoItem(
                                icon: "xmark.circle.fill",
                                label: "Filtered",
                                value: "\(baseline.outlierRemovedCount)"
                            )
                        }
                    }
                    
                    if baseline.isHighlyReliable {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Highly reliable baseline")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if baseline.isReliable {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.blue)
                            Text("Reliable baseline")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Need more data for reliable baseline")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Helper Properties
    
    private var overallQuality: DataQuality? {
        guard let latestSample = samples.last else { return nil }
        return analyzer.assessDataQuality(sample: latestSample)
    }
    
    private func qualityColor(_ level: DataQualityLevel) -> Color {
        switch level {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    private func calculateQualityDistribution(_ samples: [HRVSample]) -> (excellent: Int, good: Int, fair: Int, poor: Int) {
        var excellent = 0, good = 0, fair = 0, poor = 0
        
        for sample in samples {
            let quality = analyzer.assessDataQuality(sample: sample)
            switch quality.level {
            case .excellent: excellent += 1
            case .good: good += 1
            case .fair: fair += 1
            case .poor: poor += 1
            }
        }
        
        return (excellent, good, fair, poor)
    }
    
    private func localizedIssue(_ issue: String) -> String {
        if issue.contains("out of normal range") {
            return NSLocalizedString("Value outside normal range (10-200ms)", comment: "")
        } else if issue.contains("sleep hours") {
            return NSLocalizedString("Measured during sleep hours", comment: "")
        } else if issue.contains("optimal morning") {
            return NSLocalizedString("Not measured in optimal morning window (6-10 AM)", comment: "")
        }
        return issue
    }
}

// MARK: - Supporting Views

struct QualityBar: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 40)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.gradient)
                    .frame(height: 40 * percentage)
            }
            
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.semibold)
            
            Text(LocalizedStringKey(label))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct InfoItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(label))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        DataQualityIndicatorView(
            samples: [
                HRVSample(value: 45, date: Date().addingTimeInterval(-86400 * 5), source: "Apple Watch"),
                HRVSample(value: 52, date: Date().addingTimeInterval(-86400 * 4), source: "Apple Watch"),
                HRVSample(value: 48, date: Date().addingTimeInterval(-86400 * 3), source: "Apple Watch"),
                HRVSample(value: 55, date: Date().addingTimeInterval(-86400 * 2), source: "Apple Watch"),
                HRVSample(value: 50, date: Date().addingTimeInterval(-86400 * 1), source: "Apple Watch"),
                HRVSample(value: 53, date: Date(), source: "Apple Watch")
            ],
            baseline: HRVBaseline(
                mean: 50,
                standardDeviation: 5,
                lowThreshold: 45,
                highThreshold: 55,
                sampleCount: 30,
                dateRange: DateInterval(start: Date().addingTimeInterval(-86400 * 30), end: Date()),
                weekdayMean: 49,
                weekendMean: 52,
                coefficientOfVariation: 10,
                rollingAverage7Day: 51,
                median: 50,
                qualityFilteredCount: 28,
                outlierRemovedCount: 2
            )
        )
        .padding()
    }
}

