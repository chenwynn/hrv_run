//
//  UserProfileEditView.swift
//  Hrv Run
//
//  Created by AI on 2025/11/7.
//

import SwiftUI

struct UserProfileEditView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var profile: UserProfile
    
    @State private var editingNickname: String
    @State private var selectedEmoji: String
    
    init(profile: UserProfile) {
        self.profile = profile
        _editingNickname = State(initialValue: profile.nickname)
        _selectedEmoji = State(initialValue: profile.avatarEmoji)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 预览区域
                    previewSection
                    
                    // 昵称编辑
                    nicknameSection
                    
                    // 头像选择
                    avatarSection
                }
                .padding()
            }
            .navigationTitle("Edit Profile".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel".localized()) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done".localized()) {
                        saveProfile()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(spacing: 16) {
            Text("Preview".localized())
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Text(selectedEmoji)
                    .font(.system(size: 50))
                    .frame(width: 70, height: 70)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
                
                Text(editingNickname.isEmpty ? "Runner" : editingNickname)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
            )
        }
    }
    
    // MARK: - Nickname Section
    
    private var nicknameSection: some View {
        VStack(spacing: 12) {
            Text("Nickname".localized())
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            TextField("Enter your nickname".localized(), text: $editingNickname)
                .textFieldStyle(.plain)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }
    
    // MARK: - Avatar Section
    
    private var avatarSection: some View {
        VStack(spacing: 16) {
            Text("Choose Avatar".localized())
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(Array(AvatarEmojiCategory.allCategories.enumerated()), id: \.offset) { categoryIndex, category in
                VStack(alignment: .leading, spacing: 12) {
                    Text(category.name.localized())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 50), spacing: 12)
                    ], spacing: 12) {
                        ForEach(Array(category.emojis.enumerated()), id: \.offset) { emojiIndex, emoji in
                            Button {
                                selectedEmoji = emoji
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 32))
                                    .frame(width: 50, height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedEmoji == emoji ? Color.purple.opacity(0.2) : Color(.tertiarySystemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedEmoji == emoji ? Color.purple : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                            .id("\(categoryIndex)-\(emojiIndex)")
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveProfile() {
        profile.nickname = editingNickname.isEmpty ? "Runner" : editingNickname
        profile.avatarEmoji = selectedEmoji
        dismiss()
    }
}

#Preview {
    UserProfileEditView(profile: UserProfile.shared)
}

