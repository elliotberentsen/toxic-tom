//
//  RoleCard.swift
//  Toxic Tom
//
//  Medieval-style role card component
//

import SwiftUI

struct RoleCard: View {
    let characterImage: String
    let borderImage: String
    let roleName: String
    let isRevealed: Bool
    
    @State private var isFlipped = false
    
    var body: some View {
        ZStack {
            // Card content
            if isRevealed {
                // Front of card - character revealed
                cardFront
            } else {
                // Back of card - hidden
                cardBack
            }
        }
        .frame(width: 180, height: 270)  // 2:3 aspect ratio matching your images
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Card Front (Character + Border)
    
    private var cardFront: some View {
        ZStack {
            // Character image
            Image(characterImage)
                .resizable()
                .scaledToFill()
                .frame(width: 180, height: 270)
                .clipped()
            
            // Border overlay
            Image(borderImage)
                .resizable()
                .scaledToFill()
                .frame(width: 180, height: 270)
                .clipped()
            
            // Role name at bottom
            VStack {
                Spacer()
                
                Text(roleName.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .tracking(2)
                    .foregroundColor(Color(red: 0.9, green: 0.85, blue: 0.7))
                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.7))
                    )
                    .padding(.bottom, 20)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Card Back (Hidden)
    
    private var cardBack: some View {
        ZStack {
            // Dark background
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.12, blue: 0.1),
                            Color(red: 0.08, green: 0.06, blue: 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Decorative pattern
            VStack(spacing: 0) {
                // Top ornament
                Image(systemName: "laurel.leading")
                    .font(.system(size: 30))
                    .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.35).opacity(0.5))
                    .rotationEffect(.degrees(180))
                
                Spacer()
                
                // Center emblem
                ZStack {
                    Circle()
                        .stroke(Color(red: 0.6, green: 0.5, blue: 0.35).opacity(0.3), lineWidth: 2)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .stroke(Color(red: 0.6, green: 0.5, blue: 0.35).opacity(0.2), lineWidth: 1)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "cross.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.35).opacity(0.6))
                }
                
                Spacer()
                
                // Bottom ornament
                Image(systemName: "laurel.trailing")
                    .font(.system(size: 30))
                    .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.35).opacity(0.5))
            }
            .padding(.vertical, 30)
            
            // Border
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.6, green: 0.5, blue: 0.35),
                            Color(red: 0.4, green: 0.3, blue: 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .padding(2)
        }
    }
}

// MARK: - Animated Card that can flip

struct FlippableRoleCard: View {
    let characterImage: String
    let borderImage: String
    let roleName: String
    @Binding var isRevealed: Bool
    
    var body: some View {
        ZStack {
            // Back of card
            RoleCard(
                characterImage: characterImage,
                borderImage: borderImage,
                roleName: roleName,
                isRevealed: false
            )
            .opacity(isRevealed ? 0 : 1)
            .rotation3DEffect(
                .degrees(isRevealed ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            
            // Front of card
            RoleCard(
                characterImage: characterImage,
                borderImage: borderImage,
                roleName: roleName,
                isRevealed: true
            )
            .opacity(isRevealed ? 1 : 0)
            .rotation3DEffect(
                .degrees(isRevealed ? 0 : -180),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isRevealed.toggle()
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        HStack(spacing: 20) {
            RoleCard(
                characterImage: "man-60",
                borderImage: "border-medeltid",
                roleName: "The Monk",
                isRevealed: true
            )
            
            RoleCard(
                characterImage: "man-60",
                borderImage: "border-medeltid",
                roleName: "Hidden",
                isRevealed: false
            )
        }
    }
}

