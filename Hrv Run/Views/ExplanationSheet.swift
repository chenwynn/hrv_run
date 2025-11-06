//
//  ExplanationSheet.swift
//  Hrv Run
//
//  Created by AI on 2025/11/6.
//

import SwiftUI

struct ExplanationSheet: View {
    let type: ExplanationType
    @Environment(\.dismiss) private var dismiss
    
    var content: ExplanationContent {
        type.content
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("What is this?"))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text(content.description)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    Divider()
                    
                    // Range Indicators
                    VStack(alignment: .leading, spacing: 16) {
                        Text(LocalizedStringKey("Understanding the Ranges"))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        // Good Range
                        RangeCard(
                            emoji: content.goodRange.emoji,
                            range: content.goodRange.range,
                            title: "Excellent",
                            description: content.goodRange.description,
                            color: .green
                        )
                        
                        // Normal Range (if exists)
                        if let normalRange = content.normalRange {
                            RangeCard(
                                emoji: normalRange.emoji,
                                range: normalRange.range,
                                title: "Good",
                                description: normalRange.description,
                                color: .blue
                            )
                        }
                        
                        // Bad Range
                        RangeCard(
                            emoji: content.badRange.emoji,
                            range: content.badRange.range,
                            title: "Needs Attention",
                            description: content.badRange.description,
                            color: .orange
                        )
                    }
                    
                    Divider()
                    
                    // Recommendations
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStringKey("Recommendations"))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        ForEach(Array(content.recommendations.enumerated()), id: \.offset) { index, recommendation in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 28, height: 28)
                                    
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.accentColor)
                                }
                                
                                Text(recommendation)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                .padding()
            }
            .navigationTitle(content.title)
            .navigationBarTitleDisplayMode(.large)
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

// MARK: - Range Card

struct RangeCard: View {
    let emoji: String
    let range: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Emoji and Range
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.largeTitle)
                
                Text(range)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80)
            
            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                
                Text(description)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    ExplanationSheet(type: .recoveryScore)
}

