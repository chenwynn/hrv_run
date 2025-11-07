//
//  UserProfile.swift
//  Hrv Run
//
//  Created by AI on 2025/11/7.
//

import Foundation

class UserProfile: ObservableObject {
    static let shared = UserProfile()
    
    @Published var nickname: String {
        didSet {
            UserDefaults.standard.set(nickname, forKey: "userNickname")
        }
    }
    
    @Published var avatarEmoji: String {
        didSet {
            UserDefaults.standard.set(avatarEmoji, forKey: "userAvatarEmoji")
        }
    }
    
    init() {
        self.nickname = UserDefaults.standard.string(forKey: "userNickname") ?? "Runner"
        self.avatarEmoji = UserDefaults.standard.string(forKey: "userAvatarEmoji") ?? "🏃‍♂️"
    }
}

// MARK: - Avatar Emoji Categories

struct AvatarEmojiCategory {
    let name: String
    let emojis: [String]
}

extension AvatarEmojiCategory {
    static let allCategories: [AvatarEmojiCategory] = [
        AvatarEmojiCategory(
            name: "People",
            emojis: [
                "🏃‍♂️", "🏃‍♀️", "🚴‍♂️", "🚴‍♀️", "🏊‍♂️", "🏊‍♀️",
                "🧘‍♂️", "🧘‍♀️", "🤸‍♂️", "🤸‍♀️", "⛹️‍♂️", "⛹️‍♀️",
                "👨", "👩", "🧑", "👦", "👧", "🧒",
                "👨‍💼", "👩‍💼", "👨‍🎓", "👩‍🎓", "👨‍⚕️", "👩‍⚕️"
            ]
        ),
        AvatarEmojiCategory(
            name: "Animals",
            emojis: [
                "🐶", "🐱", "🐭", "🐹", "🐰", "🦊",
                "🐻", "🐼", "🐨", "🐯", "🦁", "🐮",
                "🐷", "🐸", "🐵", "🐔", "🐧", "🐦",
                "🦅", "🦉", "🦆", "🦢", "🦜", "🦩"
            ]
        ),
        AvatarEmojiCategory(
            name: "Nature",
            emojis: [
                "🌸", "🌺", "🌻", "🌷", "🌹", "🌼",
                "🌲", "🌳", "🌴", "🌵", "🌾", "🌿",
                "🍀", "🍁", "🍂", "🍃", "🌙", "⭐",
                "✨", "🌟", "💫", "☀️", "🌈", "⚡"
            ]
        ),
        AvatarEmojiCategory(
            name: "Sports",
            emojis: [
                "⚽", "🏀", "🏈", "⚾", "🎾", "🏐",
                "🏉", "🥏", "🎱", "🏓", "🏸", "🏒",
                "🥊", "🥋", "⛳", "🏹", "🎣", "🥌",
                "🛹", "🛼", "🏆", "🥇", "🥈", "🥉"
            ]
        ),
        AvatarEmojiCategory(
            name: "Food",
            emojis: [
                "🍎", "🍊", "🍋", "🍌", "🍉", "🍇",
                "🍓", "🫐", "🍒", "🍑", "🥭", "🍍",
                "🥥", "🥝", "🍅", "🥑", "🥦", "🥕",
                "🌽", "🥔", "🥐", "🥖", "🧀", "🍕"
            ]
        )
    ]
}

