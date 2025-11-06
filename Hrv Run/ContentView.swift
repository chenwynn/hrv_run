//
//  ContentView.swift
//  Hrv Run
//
//  Created by 陈吟书 on 2025/11/6.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HRVViewModel()
    
    var body: some View {
        Group {
            // 只在真正需要授权时显示授权界面
            if viewModel.needsAuthorization {
                AuthorizationView(viewModel: viewModel)
            } else {
                // 已授权，直接显示主界面
                SimplifiedMainDashboardView(viewModel: viewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
