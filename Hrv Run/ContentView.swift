//
//  ContentView.swift
//  Hrv Run
//
//  Created by 陈吟书 on 2025/11/6.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HRVViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        Group {
            // 只在第一次访问时显示授权界面
            if !hasCompletedOnboarding && viewModel.needsAuthorization {
                AuthorizationView(viewModel: viewModel)
                    .onAppear {
                        // 授权完成后标记为已完成引导
                        if !viewModel.needsAuthorization {
                            hasCompletedOnboarding = true
                        }
                    }
                    .onChange(of: viewModel.needsAuthorization) { oldValue, newValue in
                        if !newValue {
                            hasCompletedOnboarding = true
                        }
                    }
            } else {
                // 使用简化的主界面
                SimplifiedMainDashboardView(viewModel: viewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
