# 🔧 Sheet冲突问题修复

## 🎯 问题

**错误信息**:
```
Currently, only presenting a single sheet is supported.
The next sheet will be presented when the currently presented sheet gets dismissed.
```

**现象**: 点击某个workout没有反应

---

## 🔍 问题原因

### SwiftUI的限制
**SwiftUI不支持同时展示多个sheet**

### 原来的逻辑（有问题）
```
主界面
  ↓ .sheet(isPresented: $showWorkoutsList)
  打开训练列表Sheet
    ↓ .sheet(item: $viewModel.selectedWorkoutForEvaluation)
    想打开评估Sheet ❌ 冲突！
      ↓
      报错：只能同时显示一个sheet
```

**问题**：
- 训练列表是一个sheet
- 评估界面又是另一个sheet
- 从一个sheet中打开另一个sheet会冲突

---

## ✅ 解决方案

### 修改后的逻辑
```
主界面
  ↓ .sheet(isPresented: $showWorkoutsList)
  打开训练列表Sheet
    ↓ 用户点击某个训练
    ↓ 回调：onWorkoutSelected(workout)
    ↓ 关闭训练列表Sheet (showWorkoutsList = false)
    ↓ 准备数据 (evaluationData = ...)
  ↓ .sheet(isPresented: $showEvaluationSheet)
  打开评估Sheet ✅ 成功！
```

**改进**：
- ✅ 同一时间只显示一个sheet
- ✅ 通过回调传递选择的workout
- ✅ 先关闭列表sheet，再打开评估sheet
- ✅ 流畅的用户体验

---

## 🔧 代码对比

### 修改前（冲突）❌
```swift
.sheet(isPresented: $showWorkoutsList) {
    RecentWorkoutsListView(viewModel: viewModel)
    // 在这个sheet内部又尝试打开另一个sheet
}
.sheet(item: $viewModel.selectedWorkoutForEvaluation) { workout in
    PostWorkoutEvaluationView(...)  // ❌ 冲突
}
```

### 修改后（正确）✅
```swift
.sheet(isPresented: $showWorkoutsList) {
    WorkoutSelectionSheet(
        viewModel: viewModel,
        onWorkoutSelected: { workout in
            // 准备数据
            Task {
                let hrvData = await viewModel.getPostWorkoutHRVData(for: workout)
                // ...
                evaluationData = (workout, pre, post)
                
                // 先关闭当前sheet
                showWorkoutsList = false
                
                // 再打开新sheet
                showEvaluationSheet = true
            }
        }
    )
}
.sheet(isPresented: $showEvaluationSheet) {
    // 这个sheet在第一个sheet关闭后才打开 ✅
    if let data = evaluationData {
        PostWorkoutEvaluationView(...)
    }
}
```

---

## 📱 用户体验流程

### 修复后的流程
```
1. 用户点击"评估训练"
   ↓
2. 弹出训练列表
   ┌─────────────────────────┐
   │ 最近的训练              │
   │ • 跑步 40分钟           │  ← 用户点击
   │ • 骑行 1小时            │
   └─────────────────────────┘
   ↓
3. 训练列表自动关闭
   ↓
4. 加载HRV数据
   ↓
5. 弹出评估界面
   ┌─────────────────────────┐
   │ 训练后评估              │
   │ HRV变化: ↓12.7%        │
   │ 你的感受如何？          │
   └─────────────────────────┘
   ↓
6. 用户完成评估
   ↓
7. 保存并关闭
```

**流畅无冲突！** ✅

---

## 🎯 关键改进

### 1. 使用回调模式
```swift
WorkoutSelectionSheet(
    viewModel: viewModel,
    onWorkoutSelected: { workout in  // ✅ 回调
        // 处理选择
    }
)
```

### 2. 顺序控制
```swift
// 先关闭
showWorkoutsList = false

// 再打开
showEvaluationSheet = true
```

### 3. 数据准备
```swift
// 异步获取HRV数据
Task {
    let hrvData = await viewModel.getPostWorkoutHRVData(for: workout)
    evaluationData = (workout, pre, post)
}
```

---

## ✅ 完成状态

- ✅ 修复sheet冲突
- ✅ 改为回调模式
- ✅ 顺序控制sheet显示
- ✅ 编译成功
- ✅ 点击workout正常工作

---

**更新时间**: 2025年11月7日 01:00  
**状态**: ✅ Sheet冲突修复完成  

**🎉 现在点击workout可以正常打开评估界面了！**

