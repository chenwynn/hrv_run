//
//  SettingsView.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: HRVViewModel
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Appearance Section
                Section {
                    // Language Selection
                    Picker(selection: $appSettings.selectedLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            HStack {
                                if language != .system {
                                    Text(language.icon)
                                } else {
                                    Image(systemName: language.icon)
                                }
                                Text(language.displayName)
                            }
                            .tag(language)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(.blue)
                            Text(LocalizedStringKey("Language"))
                        }
                    }
                    
                    // Theme Selection
                    Picker(selection: $appSettings.selectedTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            HStack {
                                Image(systemName: theme.icon)
                                Text(theme.displayName)
                            }
                            .tag(theme)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundStyle(.purple)
                            Text(LocalizedStringKey("Theme"))
                        }
                    }
                    
                } header: {
                    Text(LocalizedStringKey("Appearance"))
                } footer: {
                    Text(LocalizedStringKey("Customize language and theme settings."))
                        .font(.caption)
                }
                
                // Health Permissions Section
                Section {
                    Button {
                        Task {
                            await viewModel.requestAuthorization()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "heart.text.square")
                                .foregroundStyle(.red)
                            Text(LocalizedStringKey("Request Authorization"))
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)
                    
                } header: {
                    Text(LocalizedStringKey("Health Permissions"))
                } footer: {
                    Text(LocalizedStringKey("Grant access to read HRV data and save workout information."))
                        .font(.caption)
                }
                
                // Notifications Section
                Section {
                    Toggle(isOn: $notificationManager.notificationsEnabled) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.orange)
                            Text(LocalizedStringKey("Enable Notifications"))
                        }
                    }
                    .onChange(of: notificationManager.notificationsEnabled) { oldValue, newValue in
                        if newValue {
                            notificationManager.startObservingHealthData()
                            Task {
                                await notificationManager.sendDailyRecommendationNotification()
                            }
                        } else {
                            notificationManager.stopObservingHealthData()
                            notificationManager.cancelDailyNotification()
                        }
                    }
                    
                    if notificationManager.isAuthorized {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(LocalizedStringKey("Notification Permission Granted"))
                        }
                    } else {
                        Button {
                            Task {
                                try? await notificationManager.requestAuthorization()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.orange)
                                Text(LocalizedStringKey("Request Notification Permission"))
                            }
                        }
                    }
                    
                } header: {
                    Text(LocalizedStringKey("Notifications"))
                } footer: {
                    Text(LocalizedStringKey("Receive notifications when your HRV data updates or after workouts with personalized recommendations."))
                        .font(.caption)
                }
                
                // Data Section
                Section {
                    HStack {
                        Text(LocalizedStringKey("Baseline Mean"))
                        Spacer()
                        if let baseline = viewModel.baseline {
                            Text(String(format: "%.1f ms", baseline.mean))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("--")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Sample Count"))
                        Spacer()
                        if let baseline = viewModel.baseline {
                            Text("\(baseline.sampleCount)")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("--")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Baseline Reliable"))
                        Spacer()
                        if let baseline = viewModel.baseline {
                            Image(systemName: baseline.isReliable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(baseline.isReliable ? .green : .red)
                        } else {
                            Text("--")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        Task {
                            await viewModel.recalculateBaseline()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text(LocalizedStringKey("Recalculate Baseline"))
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)
                    
                } header: {
                    Text(LocalizedStringKey("HRV Data"))
                } footer: {
                    Text(LocalizedStringKey("Your baseline is calculated from the last 30 days of HRV data."))
                        .font(.caption)
                }
                
                // About Section
                Section {
                    HStack {
                        Text(LocalizedStringKey("Version"))
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://www.apple.com/healthcare/health-records/")!) {
                        HStack {
                            Text(LocalizedStringKey("Privacy Policy"))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                } header: {
                    Text(LocalizedStringKey("About"))
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("HRV Run analyzes your Heart Rate Variability to provide personalized running recommendations."))
                        Text(LocalizedStringKey("All data is processed locally on your device."))
                    }
                    .font(.caption)
                }
            }
            .navigationTitle(LocalizedStringKey("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: HRVViewModel())
}

