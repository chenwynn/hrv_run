//
//  ContentView.swift
//  Hrv Run
//
//  Created by 陈吟书 on 2025/11/6.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HRVViewModel()
    @AppStorage("hasCompletedInitialSetup") private var hasCompletedInitialSetup = false
    @State private var showLaunchScreen = true
    
    var body: some View {
        ZStack {
            // 主内容
            Group {
                if !hasCompletedInitialSetup {
                    // 首次使用，显示授权界面
                    AuthorizationView(viewModel: viewModel)
                        .onChange(of: viewModel.needsAuthorization) { oldValue, newValue in
                            // 授权完成后标记为已完成初始设置
                            if !newValue {
                                hasCompletedInitialSetup = true
                            }
                        }
                } else {
                    // 已完成初始设置，直接显示主界面
                    SimplifiedMainDashboardView(viewModel: viewModel)
                }
            }
            .opacity(showLaunchScreen ? 0 : 1)
            
            // 开屏画面
            if showLaunchScreen {
                LaunchScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            // 显示开屏画面1.5秒
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeOut(duration: 0.5)) {
                showLaunchScreen = false
            }
        }
    }
}

#Preview {
    ContentView()
}
