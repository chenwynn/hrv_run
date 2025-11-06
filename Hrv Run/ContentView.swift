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
            if viewModel.needsAuthorization {
                AuthorizationView(viewModel: viewModel)
            } else {
                MainDashboardView(viewModel: viewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
