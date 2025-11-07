# 🔍 HealthKit授权检查策略

## 🎯 核心问题

**HealthKit的隐私保护机制**：
- 对于**读取权限**，`authorizationStatus(for:)` 总是返回 `.notDetermined`
- 应用无法直接知道用户是否授权了读取权限
- 这是Apple的隐私保护设计

---

## 📋 可用的授权检查方案

### 方案1: 尝试读取数据（当前使用）⚠️

```swift
// 尝试读取数据来判断
do {
    let _ = try await fetchHRVData(from: yesterday, to: today)
    isAuthorized = true  // 读取成功 = 已授权
} catch {
    isAuthorized = false  // 读取失败 = 未授权
}
```

**问题**:
- ❌ 如果用户授权了但没有HRV数据，仍会失败
- ❌ 异步检查有延迟
- ❌ 可能误判

---

### 方案2: 使用UserDefaults记录（推荐）✅

```swift
// 在用户授权成功后记录
func requestAuthorization() async {
    try await healthStore.requestAuthorization(...)
    
    // 授权成功后记录
    UserDefaults.standard.set(true, forKey: "hasGrantedHealthKitAccess")
    isAuthorized = true
}

// 启动时检查
init() {
    let hasGranted = UserDefaults.standard.bool(forKey: "hasGrantedHealthKitAccess")
    isAuthorized = hasGranted
}
```

**优势**:
- ✅ 立即可用，无延迟
- ✅ 准确可靠
- ✅ 不会误判

**缺点**:
- ⚠️ 如果用户在系统设置中撤销授权，应用不知道
- ⚠️ 卸载重装后会丢失记录

---

### 方案3: 混合方案（最佳）⭐⭐⭐

```swift
init() {
    // 1. 先检查本地记录（快速）
    let hasGranted = UserDefaults.standard.bool(forKey: "hasGrantedHealthKitAccess")
    isAuthorized = hasGranted
    
    // 2. 异步验证真实授权状态
    Task {
        do {
            let _ = try await fetchHRVData(from: yesterday, to: today)
            await MainActor.run {
                isAuthorized = true
                UserDefaults.standard.set(true, forKey: "hasGrantedHealthKitAccess")
            }
        } catch {
            await MainActor.run {
                isAuthorized = false
                UserDefaults.standard.set(false, forKey: "hasGrantedHealthKitAccess")
            }
        }
    }
}
```

**优势**:
- ✅ 启动快速（使用缓存）
- ✅ 后台验证（更新真实状态）
- ✅ 能检测到权限撤销

---

### 方案4: 首次授权标记（最简单）⭐⭐⭐⭐⭐

```swift
// 策略：只在真正第一次使用时显示授权界面

@AppStorage("hasCompletedInitialSetup") private var hasCompletedInitialSetup = false

var body: some View {
    if !hasCompletedInitialSetup {
        // 首次使用，显示授权界面
        AuthorizationView()
            .onDisappear {
                hasCompletedInitialSetup = true
            }
    } else {
        // 已完成初始设置，直接显示主界面
        MainDashboardView()
    }
}
```

**优势**:
- ✅ 最简单
- ✅ 最可靠
- ✅ 无延迟
- ✅ 用户体验最好

**理念**:
- 授权界面只在首次显示一次
- 如果用户撤销权限，在使用时会提示错误
- 可以在设置中重新授权

---

## 💡 推荐实现

### 采用方案4（最简单可靠）

**修改ContentView.swift**:
```swift
struct ContentView: View {
    @StateObject private var viewModel = HRVViewModel()
    @AppStorage("hasCompletedInitialSetup") private var hasCompletedInitialSetup = false
    @State private var showLaunchScreen = true
    
    var body: some View {
        ZStack {
            Group {
                if !hasCompletedInitialSetup {
                    // 首次使用，显示授权界面
                    AuthorizationView(viewModel: viewModel)
                        .onDisappear {
                            hasCompletedInitialSetup = true
                        }
                } else {
                    // 已完成初始设置，直接显示主界面
                    SimplifiedMainDashboardView(viewModel: viewModel)
                }
            }
            .opacity(showLaunchScreen ? 0 : 1)
            
            if showLaunchScreen {
                LaunchScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeOut(duration: 0.5)) {
                showLaunchScreen = false
            }
        }
    }
}
```

**工作流程**:
```
首次安装:
  hasCompletedInitialSetup = false
  → 显示授权界面
  → 用户授权
  → 设置 hasCompletedInitialSetup = true
  → 进入主界面

后续打开:
  hasCompletedInitialSetup = true
  → 直接显示主界面 ✅

卸载重装:
  hasCompletedInitialSetup = false (重置)
  → 显示授权界面
  → 但HealthKit授权保留
  → 授权界面点击后立即成功
```

---

## 🎯 处理权限撤销

### 如果用户在系统设置中撤销了权限

**检测方式**:
```swift
func loadData() async {
    do {
        let samples = try await healthKitManager.fetchHRVData(...)
        // 成功
    } catch {
        // 失败 - 可能是权限被撤销
        if error is HealthKitError {
            // 显示错误提示
            needsAuthorization = true
        }
    }
}
```

**用户体验**:
```
1. 用户在系统设置中撤销权限
2. 打开应用（显示主界面）
3. 尝试加载数据
4. 失败，显示错误提示
5. 提示："健康数据访问被拒绝，请在设置中重新授权"
6. 用户可以在设置界面重新授权
```

---

## ✅ 推荐方案总结

### 最佳实践

**启动流程**:
```
1. 显示开屏画面（1.5秒）
2. 检查 hasCompletedInitialSetup
   ├─ false → 显示授权界面（首次）
   └─ true → 显示主界面
3. 在主界面加载数据时检测权限
4. 如果权限被撤销，显示错误并引导重新授权
```

**设置界面**:
```
健康权限
├─ 已授权 → 显示 "✓ 已授权"
└─ 未授权 → 显示 "请求授权" 按钮
```

---

**创建时间**: 2025年11月7日 03:00  
**状态**: 📋 策略文档

