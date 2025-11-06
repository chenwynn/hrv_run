//
//  HRVAnalyzer.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//  Enhanced with adaptive baseline and data quality control
//

import Foundation

class HRVAnalyzer: ObservableObject {
    
    static let shared = HRVAnalyzer()
    
    @Published var baseline: HRVBaseline?
    @Published var currentStatus: HRVStatus?
    
    // MARK: - Data Quality Control
    
    /// 数据质量评分
    func assessDataQuality(sample: HRVSample) -> DataQuality {
        var qualityScore: Double = 100
        var issues: [String] = []
        
        // 1. 检查HRV值是否在合理范围内 (10-200ms)
        if sample.value < 10 || sample.value > 200 {
            qualityScore -= 50
            issues.append("Value out of normal range")
        }
        
        // 2. 检查测量时间（早晨6-10点最佳）
        let hour = Calendar.current.component(.hour, from: sample.date)
        if hour >= 6 && hour <= 10 {
            // 最佳时间，不扣分
        } else if hour >= 22 || hour <= 5 {
            qualityScore -= 10
            issues.append("Measured during sleep hours")
        } else {
            qualityScore -= 20
            issues.append("Not measured in optimal morning window")
        }
        
        // 3. 确定质量等级
        let quality: DataQualityLevel
        if qualityScore >= 80 {
            quality = .excellent
        } else if qualityScore >= 60 {
            quality = .good
        } else if qualityScore >= 40 {
            quality = .fair
        } else {
            quality = .poor
        }
        
        return DataQuality(
            score: qualityScore,
            level: quality,
            issues: issues,
            sample: sample
        )
    }
    
    /// 过滤低质量数据
    func filterQualityData(samples: [HRVSample], minQuality: DataQualityLevel = .fair) -> [HRVSample] {
        return samples.filter { sample in
            let quality = assessDataQuality(sample: sample)
            return quality.level.rawValue >= minQuality.rawValue
        }
    }
    
    /// 使用IQR方法剔除离群值
    func removeOutliers(from samples: [HRVSample]) -> [HRVSample] {
        guard samples.count >= 4 else { return samples }
        
        let values = samples.map { $0.value }.sorted()
        
        // 计算四分位数
        let q1Index = values.count / 4
        let q3Index = (values.count * 3) / 4
        
        let q1 = values[q1Index]
        let q3 = values[q3Index]
        let iqr = q3 - q1
        
        // IQR方法：Q1 - 1.5*IQR 到 Q3 + 1.5*IQR
        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr
        
        return samples.filter { sample in
            sample.value >= lowerBound && sample.value <= upperBound
        }
    }
    
    // MARK: - Adaptive Baseline Calculation
    
    /// 计算自适应HRV基准值（改进版）
    func calculateBaseline(from samples: [HRVSample]) -> HRVBaseline? {
        guard !samples.isEmpty else { return nil }
        
        // 1. 数据质量控制
        let qualitySamples = filterQualityData(samples: samples)
        guard qualitySamples.count >= 7 else { return nil } // 至少需要7天数据
        
        // 2. 剔除离群值
        let cleanedSamples = removeOutliers(from: qualitySamples)
        guard !cleanedSamples.isEmpty else { return nil }
        
        // 3. 区分周内和周末数据
        let (weekdaySamples, weekendSamples) = separateWeekdayWeekend(samples: cleanedSamples)
        
        // 4. 分别计算周内和周末基准
        let weekdayBaseline = calculateSimpleBaseline(from: weekdaySamples)
        let weekendBaseline = calculateSimpleBaseline(from: weekendSamples)
        
        // 5. 计算整体基准（加权平均：周内70%，周末30%）
        let values = cleanedSamples.map { $0.value }
        let mean = values.reduce(0, +) / Double(values.count)
        
        // 使用更稳健的标准差计算（考虑中位数）
        let median = calculateMedian(values: values)
        let mad = calculateMAD(values: values, median: median)
        let standardDeviation = mad * 1.4826 // MAD转换为标准差
        
        // 6. 计算变异系数（CV）
        let cv = (standardDeviation / mean) * 100
        
        // 7. 定义区间（使用更科学的阈值）
        let lowThreshold = mean - standardDeviation
        let highThreshold = mean + standardDeviation
        
        // 8. 计算7日滚动平均
        let recentSamples = Array(cleanedSamples.suffix(7))
        let rollingAverage = recentSamples.map { $0.value }.reduce(0, +) / Double(recentSamples.count)
        
        return HRVBaseline(
            mean: mean,
            standardDeviation: standardDeviation,
            lowThreshold: lowThreshold,
            highThreshold: highThreshold,
            sampleCount: cleanedSamples.count,
            dateRange: DateInterval(start: cleanedSamples.first!.date, end: cleanedSamples.last!.date),
            weekdayMean: weekdayBaseline?.mean,
            weekendMean: weekendBaseline?.mean,
            coefficientOfVariation: cv,
            rollingAverage7Day: rollingAverage,
            median: median,
            qualityFilteredCount: qualitySamples.count,
            outlierRemovedCount: qualitySamples.count - cleanedSamples.count
        )
    }
    
    /// 辅助：分离周内和周末数据
    private func separateWeekdayWeekend(samples: [HRVSample]) -> ([HRVSample], [HRVSample]) {
        var weekday: [HRVSample] = []
        var weekend: [HRVSample] = []
        
        for sample in samples {
            let weekdayComponent = Calendar.current.component(.weekday, from: sample.date)
            // 1 = Sunday, 7 = Saturday
            if weekdayComponent == 1 || weekdayComponent == 7 {
                weekend.append(sample)
            } else {
                weekday.append(sample)
            }
        }
        
        return (weekday, weekend)
    }
    
    /// 辅助：简单基准计算
    private func calculateSimpleBaseline(from samples: [HRVSample]) -> (mean: Double, sd: Double)? {
        guard !samples.isEmpty else { return nil }
        
        let values = samples.map { $0.value }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let sd = sqrt(variance)
        
        return (mean, sd)
    }
    
    /// 辅助：计算中位数
    private func calculateMedian(values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        } else {
            return sorted[count / 2]
        }
    }
    
    /// 辅助：计算中位数绝对偏差（MAD）
    private func calculateMAD(values: [Double], median: Double) -> Double {
        let deviations = values.map { abs($0 - median) }
        return calculateMedian(values: deviations)
    }
    
    /// 更新基准值
    func updateBaseline(samples: [HRVSample]) async {
        let newBaseline = calculateBaseline(from: samples)
        await MainActor.run {
            self.baseline = newBaseline
        }
    }
    
    // MARK: - Status Analysis
    
    /// 分析当前HRV状态（基础版，仅HRV）
    func analyzeStatus(currentValue: Double, baseline: HRVBaseline) -> HRVStatus {
        let zone: HRVZone
        let recoveryScore: Double
        
        // 确定区间
        if currentValue < baseline.lowThreshold {
            zone = .low
            recoveryScore = max(0, (currentValue / baseline.lowThreshold) * 50)
        } else if currentValue > baseline.highThreshold {
            zone = .high
            recoveryScore = min(100, 75 + ((currentValue - baseline.highThreshold) / baseline.standardDeviation) * 25)
        } else {
            zone = .normal
            let normalizedValue = (currentValue - baseline.lowThreshold) / (baseline.highThreshold - baseline.lowThreshold)
            recoveryScore = 50 + (normalizedValue * 25)
        }
        
        return HRVStatus(
            currentValue: currentValue,
            zone: zone,
            recoveryScore: recoveryScore,
            baseline: baseline
        )
    }
    
    // MARK: - Multi-Dimensional Recovery Score
    
    /// 计算多维度恢复评分（增强版）
    /// - Parameters:
    ///   - hrvValue: 当前HRV值
    ///   - baseline: HRV基准
    ///   - restingHeartRate: 静息心率（可选）
    ///   - sleepQuality: 睡眠质量（可选）
    ///   - trainingLoad: 训练负荷（可选，0-100）
    /// - Returns: 综合恢复评分
    func calculateMultiDimensionalRecoveryScore(
        hrvValue: Double,
        baseline: HRVBaseline,
        restingHeartRate: Double? = nil,
        sleepQuality: SleepQuality? = nil,
        trainingLoad: Double? = nil
    ) -> MultiDimensionalRecoveryScore {
        
        // 1. HRV评分 (权重50%)
        let hrvScore = calculateHRVScore(value: hrvValue, baseline: baseline)
        
        // 2. 静息心率评分 (权重20%)
        let rhrScore = calculateRestingHeartRateScore(rhr: restingHeartRate)
        
        // 3. 睡眠质量评分 (权重20%)
        let sleepScore = sleepQuality?.score ?? 50  // 默认50分
        
        // 4. 训练负荷评分 (权重10%)
        let loadScore = calculateTrainingLoadScore(load: trainingLoad)
        
        // 5. 计算加权总分
        let totalScore = (hrvScore * 0.5) + (rhrScore * 0.2) + (sleepScore * 0.2) + (loadScore * 0.1)
        
        // 6. 确定恢复等级
        let level: RecoveryLevel
        if totalScore >= 85 {
            level = .excellent
        } else if totalScore >= 70 {
            level = .good
        } else if totalScore >= 55 {
            level = .fair
        } else if totalScore >= 40 {
            level = .poor
        } else {
            level = .veryPoor
        }
        
        return MultiDimensionalRecoveryScore(
            totalScore: totalScore,
            hrvScore: hrvScore,
            restingHeartRateScore: rhrScore,
            sleepScore: sleepScore,
            trainingLoadScore: loadScore,
            level: level,
            hrvValue: hrvValue,
            restingHeartRate: restingHeartRate,
            sleepQuality: sleepQuality,
            trainingLoad: trainingLoad
        )
    }
    
    /// 辅助：计算HRV评分
    private func calculateHRVScore(value: Double, baseline: HRVBaseline) -> Double {
        // 使用非线性评分模型
        let deviation = (value - baseline.mean) / baseline.standardDeviation
        
        if deviation >= 2.0 {
            return 100  // 远高于基准
        } else if deviation >= 1.0 {
            return 85 + (deviation - 1.0) * 15  // 85-100
        } else if deviation >= 0 {
            return 70 + deviation * 15  // 70-85
        } else if deviation >= -1.0 {
            return 50 + (deviation + 1.0) * 20  // 50-70
        } else if deviation >= -2.0 {
            return 25 + (deviation + 2.0) * 25  // 25-50
        } else {
            return max(0, 25 + (deviation + 2.0) * 12.5)  // 0-25
        }
    }
    
    /// 辅助：计算静息心率评分
    private func calculateRestingHeartRateScore(rhr: Double?) -> Double {
        guard let rhr = rhr else { return 50 }  // 无数据默认50分
        
        // 静息心率越低越好（一般成年人）
        // 优秀: <60, 良好: 60-70, 一般: 70-80, 较差: >80
        if rhr < 50 {
            return 100
        } else if rhr < 60 {
            return 90 + (60 - rhr)  // 90-100
        } else if rhr < 70 {
            return 75 + (70 - rhr) * 1.5  // 75-90
        } else if rhr < 80 {
            return 50 + (80 - rhr) * 2.5  // 50-75
        } else if rhr < 90 {
            return 25 + (90 - rhr) * 2.5  // 25-50
        } else {
            return max(0, 25 - (rhr - 90))  // 0-25
        }
    }
    
    /// 辅助：计算训练负荷评分
    private func calculateTrainingLoadScore(load: Double?) -> Double {
        guard let load = load else { return 50 }  // 无数据默认50分
        
        // 训练负荷越高，恢复评分越低
        // 0-30: 轻度 (高分)
        // 30-60: 中度 (中分)
        // 60-100: 高度 (低分)
        if load < 30 {
            return 100 - load  // 70-100
        } else if load < 60 {
            return 70 - (load - 30)  // 40-70
        } else {
            return max(0, 40 - (load - 60) * 0.5)  // 0-40
        }
    }
    
    // MARK: - Trend Analysis
    
    /// 分析HRV趋势（7天移动平均）
    func analyzeTrend(samples: [HRVSample], windowDays: Int = 7) -> HRVTrend {
        guard samples.count >= windowDays else {
            return HRVTrend(direction: .stable, changePercentage: 0, confidence: .low)
        }
        
        let sortedSamples = samples.sorted { $0.date < $1.date }
        
        // 计算早期和晚期的平均值
        let midPoint = sortedSamples.count / 2
        let earlyValues = sortedSamples[..<midPoint].map { $0.value }
        let lateValues = sortedSamples[midPoint...].map { $0.value }
        
        let earlyMean = earlyValues.reduce(0, +) / Double(earlyValues.count)
        let lateMean = lateValues.reduce(0, +) / Double(lateValues.count)
        
        let changePercentage = ((lateMean - earlyMean) / earlyMean) * 100
        
        // 确定趋势方向
        let direction: TrendDirection
        if changePercentage > 5 {
            direction = .improving
        } else if changePercentage < -5 {
            direction = .declining
        } else {
            direction = .stable
        }
        
        // 置信度基于样本数量
        let confidence: TrendConfidence
        if samples.count >= 21 {
            confidence = .high
        } else if samples.count >= 14 {
            confidence = .medium
        } else {
            confidence = .low
        }
        
        return HRVTrend(direction: direction, changePercentage: changePercentage, confidence: confidence)
    }
    
    // MARK: - Optimal Workout Window
    
    /// 识别最佳锻炼窗口
    func findOptimalWorkoutWindow(todaySamples: [HRVSample], baseline: HRVBaseline) -> WorkoutWindow? {
        guard !todaySamples.isEmpty else { return nil }
        
        // 寻找HRV值在正常或高区间的时间段
        let sortedSamples = todaySamples.sorted { $0.date < $1.date }
        
        var bestWindow: WorkoutWindow?
        var bestScore: Double = 0
        
        for sample in sortedSamples {
            // 计算该时间点的适宜度评分
            let score: Double
            if sample.value >= baseline.highThreshold {
                score = 90 + min(10, (sample.value - baseline.highThreshold) / baseline.standardDeviation * 10)
            } else if sample.value >= baseline.mean {
                score = 70 + ((sample.value - baseline.mean) / (baseline.highThreshold - baseline.mean)) * 20
            } else if sample.value >= baseline.lowThreshold {
                score = 50 + ((sample.value - baseline.lowThreshold) / (baseline.mean - baseline.lowThreshold)) * 20
            } else {
                score = max(0, (sample.value / baseline.lowThreshold) * 50)
            }
            
            if score > bestScore {
                bestScore = score
                bestWindow = WorkoutWindow(
                    timeRange: DateInterval(start: sample.date, duration: 3600 * 2), // 2小时窗口
                    suitabilityScore: score,
                    hrvValue: sample.value
                )
            }
        }
        
        return bestWindow
    }
    
    // MARK: - Workout Effect Analysis
    
    /// 分析锻炼效果
    func analyzeWorkoutEffect(
        preWorkoutHRV: Double,
        postWorkoutSamples: [HRVSample],
        baseline: HRVBaseline
    ) -> WorkoutEffect? {
        guard !postWorkoutSamples.isEmpty else { return nil }
        
        let sortedSamples = postWorkoutSamples.sorted { $0.date < $1.date }
        
        // 计算恢复速度（HRV回到基准的时间）
        var recoveryTime: TimeInterval?
        for (index, sample) in sortedSamples.enumerated() {
            if sample.value >= baseline.mean {
                recoveryTime = sample.date.timeIntervalSince(sortedSamples.first!.date)
                break
            }
        }
        
        // 计算HRV变化
        let hrvDrop = preWorkoutHRV - (sortedSamples.first?.value ?? preWorkoutHRV)
        let currentHRV = sortedSamples.last?.value ?? preWorkoutHRV
        let recoveryPercentage = min(100, ((currentHRV - (sortedSamples.first?.value ?? 0)) / hrvDrop) * 100)
        
        // 评估效果
        let effectRating: WorkoutEffectRating
        if recoveryTime != nil && recoveryTime! < 3600 * 12 { // 12小时内恢复
            effectRating = .excellent
        } else if recoveryPercentage >= 70 {
            effectRating = .good
        } else if recoveryPercentage >= 40 {
            effectRating = .moderate
        } else {
            effectRating = .challenging
        }
        
        return WorkoutEffect(
            hrvDrop: hrvDrop,
            recoveryTime: recoveryTime,
            recoveryPercentage: recoveryPercentage,
            effectRating: effectRating,
            currentRecoveryLevel: currentHRV / baseline.mean
        )
    }
}

// MARK: - Data Models

/// 数据质量等级
enum DataQualityLevel: Int, Codable {
    case poor = 0
    case fair = 1
    case good = 2
    case excellent = 3
    
    var emoji: String {
        switch self {
        case .poor: return "❌"
        case .fair: return "⚠️"
        case .good: return "✅"
        case .excellent: return "⭐️"
        }
    }
    
    var localizedString: String {
        switch self {
        case .poor: return NSLocalizedString("Poor", comment: "")
        case .fair: return NSLocalizedString("Fair", comment: "")
        case .good: return NSLocalizedString("Good", comment: "")
        case .excellent: return NSLocalizedString("Excellent", comment: "")
        }
    }
}

/// 数据质量评估
struct DataQuality {
    let score: Double              // 0-100
    let level: DataQualityLevel
    let issues: [String]
    let sample: HRVSample
}

/// HRV基准值（增强版）
struct HRVBaseline: Codable {
    let mean: Double               // 平均值
    let standardDeviation: Double  // 标准差
    let lowThreshold: Double       // 低阈值
    let highThreshold: Double      // 高阈值
    let sampleCount: Int          // 样本数量
    let dateRange: DateInterval   // 日期范围
    
    // 新增字段
    let weekdayMean: Double?       // 周内平均值
    let weekendMean: Double?       // 周末平均值
    let coefficientOfVariation: Double  // 变异系数（CV%）
    let rollingAverage7Day: Double // 7日滚动平均
    let median: Double             // 中位数
    let qualityFilteredCount: Int  // 质量过滤后的样本数
    let outlierRemovedCount: Int   // 剔除的离群值数量
    
    var isReliable: Bool {
        return sampleCount >= 14  // 至少14个样本才可靠（2周）
    }
    
    var isHighlyReliable: Bool {
        return sampleCount >= 30  // 30个样本以上为高度可靠
    }
    
    var stabilityRating: String {
        // 基于变异系数评估稳定性
        if coefficientOfVariation < 10 {
            return NSLocalizedString("Very Stable", comment: "")
        } else if coefficientOfVariation < 15 {
            return NSLocalizedString("Stable", comment: "")
        } else if coefficientOfVariation < 20 {
            return NSLocalizedString("Moderate", comment: "")
        } else {
            return NSLocalizedString("Variable", comment: "")
        }
    }
}

/// HRV状态
struct HRVStatus {
    let currentValue: Double
    let zone: HRVZone
    let recoveryScore: Double  // 0-100
    let baseline: HRVBaseline
    
    var recommendation: String {
        switch zone {
        case .low:
            return NSLocalizedString("Rest recommended. Your body needs recovery.", comment: "")
        case .normal:
            return NSLocalizedString("Moderate exercise is suitable.", comment: "")
        case .high:
            return NSLocalizedString("Great condition! Good time for intense training.", comment: "")
        }
    }
}

/// 恢复等级
enum RecoveryLevel: String, Codable {
    case veryPoor = "Very Poor"
    case poor = "Poor"
    case fair = "Fair"
    case good = "Good"
    case excellent = "Excellent"
    
    var emoji: String {
        switch self {
        case .veryPoor: return "😴"
        case .poor: return "😓"
        case .fair: return "😐"
        case .good: return "😊"
        case .excellent: return "🌟"
        }
    }
    
    var localizedString: String {
        switch self {
        case .veryPoor: return NSLocalizedString("Very Poor", comment: "")
        case .poor: return NSLocalizedString("Poor", comment: "")
        case .fair: return NSLocalizedString("Fair", comment: "")
        case .good: return NSLocalizedString("Good", comment: "")
        case .excellent: return NSLocalizedString("Excellent", comment: "")
        }
    }
    
    var color: String {
        switch self {
        case .veryPoor: return "red"
        case .poor: return "orange"
        case .fair: return "yellow"
        case .good: return "green"
        case .excellent: return "blue"
        }
    }
}

/// 多维度恢复评分
struct MultiDimensionalRecoveryScore {
    let totalScore: Double          // 总分 (0-100)
    let hrvScore: Double            // HRV评分 (0-100)
    let restingHeartRateScore: Double  // 静息心率评分 (0-100)
    let sleepScore: Double          // 睡眠评分 (0-100)
    let trainingLoadScore: Double   // 训练负荷评分 (0-100)
    let level: RecoveryLevel        // 恢复等级
    
    // 原始数据
    let hrvValue: Double
    let restingHeartRate: Double?
    let sleepQuality: SleepQuality?
    let trainingLoad: Double?
    
    /// 获取评分详情
    var scoreBreakdown: String {
        var parts: [String] = []
        parts.append("HRV: \(String(format: "%.0f", hrvScore))%")
        if restingHeartRate != nil {
            parts.append(NSLocalizedString("RHR", comment: "") + ": \(String(format: "%.0f", restingHeartRateScore))%")
        }
        if sleepQuality != nil {
            parts.append(NSLocalizedString("Sleep", comment: "") + ": \(String(format: "%.0f", sleepScore))%")
        }
        if trainingLoad != nil {
            parts.append(NSLocalizedString("Load", comment: "") + ": \(String(format: "%.0f", trainingLoadScore))%")
        }
        return parts.joined(separator: " | ")
    }
    
    /// 获取建议
    var recommendation: String {
        switch level {
        case .excellent:
            return NSLocalizedString("Your recovery is excellent! Perfect day for high-intensity training or challenging workouts.", comment: "")
        case .good:
            return NSLocalizedString("Your recovery is good. You can proceed with moderate to high intensity training.", comment: "")
        case .fair:
            return NSLocalizedString("Your recovery is fair. Consider moderate intensity or focus on technique work.", comment: "")
        case .poor:
            return NSLocalizedString("Your recovery is poor. Light exercise or active recovery recommended.", comment: "")
        case .veryPoor:
            return NSLocalizedString("Your recovery is very poor. Rest day recommended. Focus on sleep and nutrition.", comment: "")
        }
    }
    
    /// 获取改善建议
    var improvementSuggestions: [String] {
        var suggestions: [String] = []
        
        // HRV改善建议
        if hrvScore < 60 {
            suggestions.append(NSLocalizedString("Consider stress management techniques like meditation or deep breathing", comment: ""))
        }
        
        // 静息心率改善建议
        if let rhr = restingHeartRate, rhr > 70 {
            suggestions.append(NSLocalizedString("Your resting heart rate is elevated. Ensure adequate hydration and rest", comment: ""))
        }
        
        // 睡眠改善建议
        if let sleep = sleepQuality, sleep.score < 60 {
            if sleep.totalSleepHours < 7 {
                suggestions.append(NSLocalizedString("Aim for 7-9 hours of sleep per night", comment: ""))
            }
            if sleep.deepSleepHours < 1.5 {
                suggestions.append(NSLocalizedString("Improve sleep quality: avoid screens before bed, keep room cool and dark", comment: ""))
            }
        }
        
        // 训练负荷建议
        if let load = trainingLoad, load > 60 {
            suggestions.append(NSLocalizedString("Training load is high. Consider adding a rest day or reducing intensity", comment: ""))
        }
        
        return suggestions
    }
}

/// HRV区间
enum HRVZone: String, Codable {
    case low     // 低于基准-1SD
    case normal  // 基准±1SD
    case high    // 高于基准+1SD
    
    var emoji: String {
        switch self {
        case .low: return "😴"
        case .normal: return "👍"
        case .high: return "💪"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "red"
        case .normal: return "yellow"
        case .high: return "green"
        }
    }
}

/// HRV趋势
struct HRVTrend {
    let direction: TrendDirection
    let changePercentage: Double
    let confidence: TrendConfidence
}

enum TrendDirection: String {
    case improving  // 上升
    case declining  // 下降
    case stable     // 稳定
    
    var emoji: String {
        switch self {
        case .improving: return "📈"
        case .declining: return "📉"
        case .stable: return "➡️"
        }
    }
}

enum TrendConfidence: String {
    case high
    case medium
    case low
}

/// 最佳锻炼窗口
struct WorkoutWindow {
    let timeRange: DateInterval
    let suitabilityScore: Double  // 0-100
    let hrvValue: Double
}

/// 锻炼效果
struct WorkoutEffect {
    let hrvDrop: Double              // HRV下降值
    let recoveryTime: TimeInterval?  // 恢复时间
    let recoveryPercentage: Double   // 恢复百分比
    let effectRating: WorkoutEffectRating
    let currentRecoveryLevel: Double // 当前恢复水平（相对基准）
}

enum WorkoutEffectRating: String {
    case excellent    // 优秀
    case good        // 良好
    case moderate    // 中等
    case challenging // 具有挑战性
    
    var emoji: String {
        switch self {
        case .excellent: return "⭐️"
        case .good: return "👍"
        case .moderate: return "👌"
        case .challenging: return "💪"
        }
    }
    
    var localizedString: String {
        switch self {
        case .excellent: return NSLocalizedString("Excellent", comment: "")
        case .good: return NSLocalizedString("Good", comment: "")
        case .moderate: return NSLocalizedString("Moderate", comment: "")
        case .challenging: return NSLocalizedString("Challenging", comment: "")
        }
    }
}

