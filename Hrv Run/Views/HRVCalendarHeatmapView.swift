//
//  HRVCalendarHeatmapView.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//  HRV Calendar Heatmap - Visual trend analysis
//

import SwiftUI

struct HRVCalendarHeatmapView: View {
    let samples: [HRVSample]
    let baseline: HRVBaseline?
    
    @State private var selectedDate: Date?
    @State private var selectedSample: HRVSample?
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题和图例
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HRV Calendar")
                        .font(.headline)
                    Text("Last 30 Days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 图例
                HStack(spacing: 8) {
                    LegendItem(color: .red, label: NSLocalizedString("Low", comment: ""))
                    LegendItem(color: .yellow, label: NSLocalizedString("Normal", comment: ""))
                    LegendItem(color: .green, label: NSLocalizedString("High", comment: ""))
                }
                .font(.caption2)
            }
            
            // 星期标签
            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // 日历热力图
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(calendarDays, id: \.date) { day in
                    DayCell(
                        day: day,
                        baseline: baseline,
                        isSelected: selectedDate == day.date
                    )
                    .onTapGesture {
                        if day.sample != nil {
                            selectedDate = day.date
                            selectedSample = day.sample
                        }
                    }
                }
            }
            
            // 选中日期的详情
            if let sample = selectedSample, let date = selectedDate {
                Divider()
                    .padding(.vertical, 8)
                
                DayDetailView(sample: sample, date: date, baseline: baseline)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 统计摘要
            if let baseline = baseline {
                Divider()
                    .padding(.vertical, 8)
                
                StatisticsSummaryView(samples: samples, baseline: baseline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Helper Properties
    
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        // 调整为周一开始
        return Array(symbols[1...]) + [symbols[0]]
    }
    
    private var calendarDays: [CalendarDay] {
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -29, to: endDate)!
        
        // 找到开始日期所在周的周一
        var currentDate = startDate
        while calendar.component(.weekday, from: currentDate) != 2 { // 2 = Monday
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        var days: [CalendarDay] = []
        let targetEndDate = calendar.date(byAdding: .day, value: 34, to: currentDate)! // 5周
        
        while currentDate < targetEndDate {
            let sample = samples.first { calendar.isDate($0.date, inSameDayAs: currentDate) }
            let isInRange = currentDate >= startDate && currentDate <= endDate
            
            days.append(CalendarDay(
                date: currentDate,
                sample: sample,
                isInRange: isInRange
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return days
    }
}

// MARK: - Supporting Views

struct DayCell: View {
    let day: CalendarDay
    let baseline: HRVBaseline?
    let isSelected: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(cellColor)
            .frame(height: 40)
            .overlay(
                VStack(spacing: 2) {
                    Text("\(Calendar.current.component(.day, from: day.date))")
                        .font(.caption2)
                        .fontWeight(isSelected ? .bold : .regular)
                    
                    if let sample = day.sample {
                        Text("\(Int(sample.value))")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                    }
                }
                .foregroundColor(day.sample != nil ? .white : .secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .opacity(day.isInRange ? 1.0 : 0.3)
    }
    
    private var cellColor: Color {
        guard let sample = day.sample, let baseline = baseline else {
            return Color(.systemGray5)
        }
        
        // 根据HRV值相对于基准的位置确定颜色
        if sample.value < baseline.lowThreshold {
            return .red
        } else if sample.value > baseline.highThreshold {
            return .green
        } else {
            return .yellow
        }
    }
}

struct DayDetailView: View {
    let sample: HRVSample
    let date: Date
    let baseline: HRVBaseline?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dateFormatter.string(from: date))
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HRV")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", sample.value)) ms")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                if let baseline = baseline {
                    Divider()
                        .frame(height: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("vs Baseline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Text(deviationText)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(deviationColor)
                            Text(deviationEmoji)
                                .font(.title3)
                        }
                    }
                }
                
                Spacer()
            }
            
            if let baseline = baseline {
                Text(statusDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private var deviationText: String {
        guard let baseline = baseline else { return "" }
        let deviation = ((sample.value - baseline.mean) / baseline.mean) * 100
        let sign = deviation >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", deviation))%"
    }
    
    private var deviationColor: Color {
        guard let baseline = baseline else { return .primary }
        if sample.value < baseline.lowThreshold {
            return .red
        } else if sample.value > baseline.highThreshold {
            return .green
        } else {
            return .orange
        }
    }
    
    private var deviationEmoji: String {
        guard let baseline = baseline else { return "" }
        if sample.value < baseline.lowThreshold {
            return "📉"
        } else if sample.value > baseline.highThreshold {
            return "📈"
        } else {
            return "➡️"
        }
    }
    
    private var statusDescription: String {
        guard let baseline = baseline else { return "" }
        if sample.value < baseline.lowThreshold {
            return NSLocalizedString("Below your baseline - Consider rest or light activity", comment: "")
        } else if sample.value > baseline.highThreshold {
            return NSLocalizedString("Above your baseline - Good day for training", comment: "")
        } else {
            return NSLocalizedString("Within normal range - Moderate training suitable", comment: "")
        }
    }
}

struct StatisticsSummaryView: View {
    let samples: [HRVSample]
    let baseline: HRVBaseline
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("30-Day Summary")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                StatItem(
                    title: NSLocalizedString("Average", comment: ""),
                    value: "\(String(format: "%.1f", baseline.mean)) ms",
                    icon: "chart.bar.fill"
                )
                
                StatItem(
                    title: NSLocalizedString("Highest", comment: ""),
                    value: "\(String(format: "%.1f", samples.map { $0.value }.max() ?? 0)) ms",
                    icon: "arrow.up.circle.fill"
                )
                
                StatItem(
                    title: NSLocalizedString("Lowest", comment: ""),
                    value: "\(String(format: "%.1f", samples.map { $0.value }.min() ?? 0)) ms",
                    icon: "arrow.down.circle.fill"
                )
            }
            
            // 稳定性指标
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.accentColor)
                Text("Stability: \(baseline.stabilityRating)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("CV: \(String(format: "%.1f", baseline.coefficientOfVariation))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Data Models

struct CalendarDay {
    let date: Date
    let sample: HRVSample?
    let isInRange: Bool
}

// MARK: - Preview

#Preview {
    ScrollView {
        HRVCalendarHeatmapView(
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
                qualityFilteredCount: 30,
                outlierRemovedCount: 2
            )
        )
        .padding()
    }
}

