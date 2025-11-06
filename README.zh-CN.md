# HRV Run - 智能跑步建议应用

## 📱 项目概述

HRV Run 是一款基于心率变异性(HRV)的智能跑步建议应用。通过分析用户的Apple Watch HRV数据，为用户提供个性化的跑步训练建议。

### 核心功能

- ✅ **今日建议**: 基于当前HRV状态，告诉你今天是否适合跑步
- ⏰ **最佳时间**: 分析每日HRV走势，找到最适合锻炼的时间窗口
- 💪 **训练强度**: 根据恢复状态建议跑步强度和时长
- 📊 **效果分析**: 追踪锻炼后HRV恢复情况，评估训练效果

## 🏗️ 技术架构

### 技术栈
- **平台**: iOS 16.0+
- **语言**: Swift
- **UI框架**: SwiftUI
- **图表**: Swift Charts
- **数据源**: HealthKit
- **国际化**: 中文、英文

### 核心模块

#### 1. HealthKitManager
负责与Apple Health集成，管理HRV数据的读写权限
- 请求和管理HealthKit权限
- 读取HRV历史数据
- 读取锻炼记录
- 保存锻炼数据

#### 2. HRVAnalyzer
HRV数据分析引擎
- **基准建立**: 使用最近30天数据计算个人HRV基准值
- **区间划分**: 
  - 低区间: < (基准 - 1SD)
  - 正常区间: 基准 ± 1SD
  - 高区间: > (基准 + 1SD)
- **趋势分析**: 7天移动平均，识别HRV变化趋势
- **窗口期识别**: 找到每日最佳锻炼时间
- **效果分析**: 评估锻炼后恢复情况

#### 3. WorkoutRecommendationEngine
智能建议系统
- 综合HRV状态和趋势生成适宜度评分(0-100)
- 建议锻炼强度(很轻松/轻松/中等/高强度)
- 建议锻炼时长
- 建议锻炼类型(恢复跑/轻松跑/节奏跑/间歇训练等)
- 提供个性化建议文案

#### 4. HRVViewModel
主视图模型，协调各组件
- 管理数据加载和刷新
- 协调HealthKit、分析器和建议引擎
- 提供UI所需的所有数据

## 📁 文件结构

```
Hrv Run/
├── Hrv_RunApp.swift              # 应用入口
├── ContentView.swift             # 主视图(授权/仪表板切换)
│
├── Managers/
│   └── HealthKitManager.swift    # HealthKit数据管理
│
├── Analyzers/
│   └── HRVAnalyzer.swift         # HRV数据分析引擎
│
├── Recommendation/
│   └── WorkoutRecommendationEngine.swift  # 建议系统
│
├── ViewModels/
│   └── HRVViewModel.swift        # 主视图模型
│
├── Models/
│   ├── AppSettings.swift         # 应用设置管理
│   └── ExplanationContent.swift  # 解释内容模型
│
├── Views/
│   ├── AuthorizationView.swift   # 授权页面
│   ├── MainDashboardView.swift   # 主仪表板
│   ├── SettingsView.swift        # 设置页面
│   └── ExplanationSheet.swift    # 解释抽屉
│
└── Localization/
    ├── en.lproj/
    │   └── Localizable.strings   # 英文文案
    └── zh-Hans.lproj/
        └── Localizable.strings   # 中文文案
```

## 🎨 UI设计

### 设计原则
- **极简主义**: 单一主界面，信息层级清晰
- **自动适配**: 深色/浅色模式跟随系统
- **国际化**: 中英文跟随系统语言设置
- **Apple设计语言**: 使用SF Symbols和系统组件

### 主界面组件

1. **今日建议卡片**
   - 恢复评分(0-100)
   - 评分表盘可视化
   - 锻炼强度、时长、类型
   - 个性化建议文案
   - ❓ 解释按钮

2. **HRV状态卡片**
   - 当前HRV值 vs 基准值
   - HRV区间指示器(低/正常/高)
   - 颜色编码(红/黄/绿)
   - ❓ 解释按钮

3. **7天趋势图表**
   - 使用Swift Charts绘制
   - 显示HRV数据点和连线
   - 显示基准线和区间阈值
   - 支持交互
   - ❓ 解释按钮

4. **趋势卡片**
   - 趋势方向(上升/下降/稳定)
   - 变化百分比
   - 置信度等级
   - ❓ 解释按钮

### 设置页面
- 语言和主题切换
- HealthKit权限管理
- 基准数据查看
- 重新计算基准
- 应用信息和隐私政策

## 📊 数据分析算法

### HRV基准计算
```
mean = Σ(HRV_values) / n
standardDeviation = sqrt(Σ(value - mean)² / n)
lowThreshold = mean - standardDeviation
highThreshold = mean + standardDeviation
```

### 恢复评分算法
- **低区间** (HRV < lowThreshold): 0-50分
- **正常区间** (lowThreshold ≤ HRV ≤ highThreshold): 50-75分
- **高区间** (HRV > highThreshold): 75-100分

### 趋势分析
- 比较前半段和后半段的平均值
- 变化 > 5%: 上升趋势
- 变化 < -5%: 下降趋势
- 其他: 稳定

### 适宜度评分
```
适宜度评分 = 基础评分 + 趋势调整
```

## 🔒 隐私保护

- ✅ 所有数据本地处理，不上传服务器
- ✅ 使用Apple HealthKit标准权限机制
- ✅ 用户完全控制数据访问权限
- ✅ 符合GDPR和健康数据隐私要求

## 🚀 开始使用

### 前置要求
- iOS 16.0 或更高版本
- Apple Watch (用于收集HRV数据)
- Xcode 14.0 或更高版本

### 配置项目

1. **添加HealthKit Capability**
   - 在Xcode中打开项目
   - 选择Target → Signing & Capabilities
   - 点击 "+ Capability"
   - 添加 "HealthKit"

2. **配置Info.plist** (已完成)
   - NSHealthShareUsageDescription
   - NSHealthUpdateUsageDescription

3. **构建和运行**
   ```bash
   # 在Xcode中打开项目
   open "Hrv Run.xcodeproj"
   
   # 选择目标设备或模拟器
   # 点击Run (⌘R)
   ```

### 首次使用

1. **授权Health数据访问**
   - 首次启动应用会显示授权页面
   - 点击"授予访问权限"
   - 在系统弹窗中允许访问HRV数据

2. **等待数据收集**
   - 应用需要至少20个HRV数据点才能建立可靠基准
   - 正常佩戴Apple Watch约7-10天即可
   - 在此期间会显示"数据不足"提示

3. **查看建议**
   - 有足够数据后，应用会自动计算基准
   - 主界面显示今日建议和HRV状态
   - 下拉刷新获取最新数据

## 📝 使用说明

### 解读恢复评分

- **85-100分** 🌟: 状态极佳，可进行高强度训练
- **70-84分** ✅: 状态良好，适合中等强度训练
- **50-69分** ⚠️: 状态一般，建议轻度锻炼
- **0-49分** 🛑: 需要休息，避免高强度训练

### HRV区间含义

- **高区间** 💪 (绿色): 恢复良好，身体状态好
- **正常区间** 👍 (黄色): 正常范围，可按计划训练
- **低区间** 😴 (红色): 疲劳状态，需要休息

### 锻炼强度说明

- **很轻松**: 恢复配速，可以轻松交谈
- **轻松**: 舒适配速，呼吸自然
- **中等**: 稳定配速，呼吸略急促
- **高强度**: 快速配速，呼吸困难

### 使用解释功能 ❓

每个数据卡片右上角都有问号按钮：
- 点击查看该数据的详细解释
- 了解数据的含义
- 查看好坏的判断标准
- 获取针对性建议

## 🎨 个性化设置

### 语言设置
- **跟随系统**: 自动使用系统语言
- **简体中文**: 强制使用中文界面
- **English**: 强制使用英文界面

### 主题设置
- **跟随系统**: 自动跟随系统深浅色模式
- **浅色**: 强制使用浅色主题
- **深色**: 强制使用深色主题

### 主题色
- **灰紫色**: 优雅专业的灰紫色主题
- 浅色模式: #9682B5
- 深色模式: #A894C7

## 🔧 开发计划

### 当前版本 (v1.0.0)
- ✅ HealthKit集成
- ✅ HRV基准计算
- ✅ 趋势分析
- ✅ 智能建议系统
- ✅ 数据可视化(Swift Charts)
- ✅ 中英文国际化
- ✅ 深浅色模式
- ✅ 语言和主题切换
- ✅ 数据解释功能

### 未来版本计划

#### v1.1.0 - 通知功能
- [ ] 最佳锻炼时间提醒
- [ ] 恢复完成通知
- [ ] 周总结报告

#### v1.2.0 - Apple Watch应用
- [ ] Watch独立应用
- [ ] 实时HRV显示
- [ ] 快速查看建议
- [ ] Complications支持

#### v1.3.0 - 高级分析
- [ ] 月度趋势报告
- [ ] 锻炼效果历史追踪
- [ ] 个性化训练计划
- [ ] 数据导出功能

## 🐛 已知问题

- 模拟器无法访问HealthKit数据，需要真机测试
- 需要实际的Apple Watch HRV数据

## 📖 相关文档

- [PROJECT_INIT.md](PROJECT_INIT.md) - 项目初始化文档
- [QUICK_START.md](QUICK_START.md) - 快速开始指南
- [EXAMPLES.md](EXAMPLES.md) - 使用示例
- [BUILD_FIX.md](BUILD_FIX.md) - 编译问题修复

## 📄 许可证

MIT License

## 👨‍💻 作者

HRV Run Development Team

---

**注意**: 本应用仅供参考，不能替代专业医疗建议。如有健康问题，请咨询医疗专业人士。

