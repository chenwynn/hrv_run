//
//  LaunchScreenView.swift
//  Hrv Run
//
//  Created by AI on 2025/11/7.
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.1),
                    Color.purple.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // App Icon
                if let appIconImage = getAppIcon() {
                    Image(uiImage: appIconImage)
                        .resizable()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .shadow(color: .purple.opacity(0.3), radius: 20, y: 10)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                } else {
                    // Fallback icon
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(.purple.gradient)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                }
                
                // App Name
                Text("HRV Run")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                    .opacity(isAnimating ? 1.0 : 0.0)
                
                // Tagline
                Text("Adaptive Running Training".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .opacity(isAnimating ? 1.0 : 0.0)
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
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

#Preview {
    LaunchScreenView()
}

