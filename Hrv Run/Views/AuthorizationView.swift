//
//  AuthorizationView.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//

import SwiftUI

struct AuthorizationView: View {
    @ObservedObject var viewModel: HRVViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Icon
            if let appIconImage = getAppIcon() {
                Image(uiImage: appIconImage)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(radius: 10)
            } else {
                // Fallback icon
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.accentColor.gradient)
            }
            
            // Title
            Text("Welcome to HRV Run")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text("This app analyzes your Heart Rate Variability (HRV) to provide personalized running recommendations.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Permissions List
            VStack(alignment: .leading, spacing: 15) {
                Text("We need access to your Health data to:")
                    .font(.headline)
                
                PermissionRow(
                    icon: "waveform.path.ecg",
                    title: "Read your HRV data"
                )
                
                PermissionRow(
                    icon: "figure.run",
                    title: "Read your workout history"
                )
                
                PermissionRow(
                    icon: "square.and.arrow.down",
                    title: "Save your workout data"
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal)
            
            // Privacy Note
            Text("Your data stays on your device and is never uploaded to any server.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Authorization Button
            Button {
                Task {
                    await viewModel.requestAuthorization()
                }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Grant Access")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(viewModel.isLoading)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    /// 获取App Icon
    private func getAppIcon() -> UIImage? {
        // 尝试从Assets获取
        if let appIcon = UIImage(named: "AppIcon60x60") {
            return appIcon
        }
        
        // 尝试从Bundle获取
        guard let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
              let lastIcon = iconFiles.last else {
            return nil
        }
        
        return UIImage(named: lastIcon)
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            Text(LocalizedStringKey(title))
                .font(.body)
        }
    }
}

#Preview {
    AuthorizationView(viewModel: HRVViewModel())
}

