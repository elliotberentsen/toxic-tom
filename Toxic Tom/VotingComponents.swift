//
//  VotingComponents.swift
//  Toxic Tom
//
//  Reusable voting components used across all voting screens:
//  - Election voting (Läkare, Väktare)
//  - Protection selection (Väktare)
//  - Cure selection (Läkare)
//  - Exile voting (all players)
//

import SwiftUI

// MARK: - Voting Player Card

/// A unified card component for selecting players in any voting context.
/// Uses the medieval portrait style with subtle selection feedback.
struct VotingPlayerCard: View {
    let player: MockPlayer
    let isSelected: Bool
    let voteCount: Int?
    let isDisabled: Bool
    let showVoteLabel: Bool
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    init(
        player: MockPlayer,
        isSelected: Bool = false,
        voteCount: Int? = nil,
        isDisabled: Bool = false,
        showVoteLabel: Bool = true,
        cardWidth: CGFloat = 160,
        cardHeight: CGFloat? = nil,
        onTap: @escaping () -> Void
    ) {
        self.player = player
        self.isSelected = isSelected
        self.voteCount = voteCount
        self.isDisabled = isDisabled
        self.showVoteLabel = showVoteLabel
        self.cardWidth = cardWidth
        // Default aspect ratio based on portrait images
        self.cardHeight = cardHeight ?? (cardWidth * (1.0 / CharacterAvatar.cardAspectRatio))
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Portrait with frame
            ZStack(alignment: .bottom) {
                // Character portrait
                if let avatar = player.avatar {
                    Image(avatar.imageName)
                        .resizable()
                        .aspectRatio(CharacterAvatar.cardAspectRatio, contentMode: .fit)
                        .frame(width: cardWidth, height: cardHeight)
                        .saturation(isDisabled ? 0.5 : 1.0)
                        .opacity(isDisabled ? 0.6 : 1.0)
                }
                
                // Vote count badge (top right)
                if let count = voteCount, count > 0 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(count)")
                                .font(.custom("Georgia-Bold", size: 14))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(AppColors.oliveGreen)
                                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                                )
                                .padding(8)
                        }
                        Spacer()
                    }
                }
                
                // Name bar with gradient background
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Text(player.name)
                            .font(.custom("Georgia-Bold", size: 14))
                            .foregroundColor(.white)
                        if player.isHost {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.warning)
                        }
                    }
                    
                    // "Din röst" label - simple text, no icon
                    if isSelected && showVoteLabel {
                        Text("Din röst")
                            .font(.custom("Georgia-Italic", size: 11))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, isSelected ? 10 : 8)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0), .black.opacity(isSelected ? 0.8 : 0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            // Subtle warm tint on selection instead of harsh border
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        isSelected ? AppColors.warmBrown.opacity(0.6) : Color.clear,
                        lineWidth: 2
                    )
            )
            // Subtle glow effect on selection
            .shadow(
                color: isSelected ? AppColors.warmBrown.opacity(0.3) : .clear,
                radius: 8,
                y: 0
            )
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDisabled else { return }
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isDisabled { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Voting Grid

/// A responsive grid layout for voting cards.
/// Automatically calculates card sizes based on available width.
struct VotingGrid<Content: View>: View {
    let players: [MockPlayer]
    let columns: Int
    let horizontalPadding: CGFloat
    let spacing: CGFloat
    let content: (MockPlayer, CGFloat, CGFloat) -> Content
    
    init(
        players: [MockPlayer],
        columns: Int = 2,
        horizontalPadding: CGFloat = 16,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping (MockPlayer, CGFloat, CGFloat) -> Content
    ) {
        self.players = players
        self.columns = columns
        self.horizontalPadding = horizontalPadding
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - (horizontalPadding * 2)
            let totalSpacing = spacing * CGFloat(columns - 1)
            let itemWidth = (availableWidth - totalSpacing) / CGFloat(columns)
            let cardHeight = itemWidth * (1.0 / CharacterAvatar.cardAspectRatio)
            
            let gridColumns = Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: columns)
            
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: spacing) {
                    ForEach(players) { player in
                        content(player, itemWidth, cardHeight)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Voting Status Header

/// Shows the current voting status (who you voted for, vote count).
struct VotingStatusHeader: View {
    let hasVoted: Bool
    let votedPlayerName: String?
    let currentVotes: Int
    let totalPlayers: Int
    
    var body: some View {
        VStack(spacing: 4) {
            if hasVoted, let name = votedPlayerName {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.oliveGreen)
                    Text("Du röstade på \(name)")
                        .font(.custom("Georgia", size: 14))
                        .foregroundColor(AppColors.inkMedium)
                }
            }
            
            Text("\(currentVotes) av \(totalPlayers) har röstat")
                .font(.custom("Georgia", size: 12))
                .foregroundColor(AppColors.inkMedium.opacity(0.7))
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

// MARK: - Simple Target Card

/// A simpler card for non-election voting (protection, cure).
/// More compact design without vote counts.
struct SimpleTargetCard: View {
    let player: MockPlayer
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(spacing: 8) {
                if let avatar = player.avatar {
                    Image(avatar.imageName)
                        .resizable()
                        .aspectRatio(CharacterAvatar.cardAspectRatio, contentMode: .fit)
                        .frame(width: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .shadow(
                            color: isSelected ? accentColor.opacity(0.4) : .black.opacity(0.1),
                            radius: isSelected ? 8 : 4,
                            y: isSelected ? 0 : 2
                        )
                }
                
                VStack(spacing: 2) {
                    Text(player.name)
                        .font(.custom("Georgia-Bold", size: 14))
                        .foregroundColor(AppColors.inkDark)
                        .lineLimit(1)
                    
                    if isSelected {
                        Text("Vald")
                            .font(.custom("Georgia-Italic", size: 11))
                            .foregroundColor(accentColor)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? accentColor.opacity(0.08) : AppColors.warmBrown.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Action Confirmation Overlay

/// A modal confirmation overlay for voting/selection actions.
struct ActionConfirmationOverlay: View {
    let title: String
    let subtitle: String
    let iconName: String
    let accentColor: Color
    let confirmText: String
    let cancelText: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    init(
        title: String,
        subtitle: String,
        iconName: String,
        accentColor: Color,
        confirmText: String = "Bekräfta",
        cancelText: String = "Avbryt",
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.accentColor = accentColor
        self.confirmText = confirmText
        self.cancelText = cancelText
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
            
            VStack(spacing: 20) {
                Image(systemName: iconName)
                    .font(.system(size: 40))
                    .foregroundColor(accentColor)
                
                Text(title)
                    .font(.custom("Georgia-Bold", size: 22))
                    .foregroundColor(AppColors.inkDark)
                
                Text(subtitle)
                    .font(.custom("Georgia-Italic", size: 14))
                    .foregroundColor(AppColors.inkMedium)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    Button(action: onCancel) {
                        Text(cancelText)
                            .font(.custom("Georgia", size: 16))
                            .foregroundColor(AppColors.inkMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppColors.warmBrown.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Button(action: onConfirm) {
                        Text(confirmText)
                            .font(.custom("Georgia-Bold", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(accentColor)
                            )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.parchment)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            )
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Waiting View

/// Displayed when waiting for another player's action.
struct WaitingForPlayerView: View {
    let waitingMessage: String
    let simulateAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.inkMedium))
                .scaleEffect(1.5)
            
            Text(waitingMessage)
                .font(.custom("Georgia-Italic", size: 16))
                .foregroundColor(AppColors.inkMedium)
            
            Spacer()
            
            if let simulate = simulateAction {
                Button(action: {
                    SoundManager.shared.playClick()
                    simulate()
                }) {
                    Text("Simulera val")
                        .font(.custom("Georgia", size: 14))
                        .foregroundColor(AppColors.inkMedium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(AppColors.warmBrown.opacity(0.1)))
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Vote Complete View

/// Displayed when the player has already voted and is waiting.
struct VoteCompleteView: View {
    let currentVotes: Int
    let totalVotes: Int
    let allVotesIn: Bool
    let onSimulateVotes: () -> Void
    let onShowResults: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(AppColors.success)
            
            Text("Du har röstat")
                .font(.custom("Georgia-Bold", size: 18))
                .foregroundColor(AppColors.inkDark)
            
            Text("Väntar på övriga spelare...")
                .font(.custom("Georgia-Italic", size: 14))
                .foregroundColor(AppColors.inkMedium)
            
            Text("\(currentVotes) / \(totalVotes) har röstat")
                .font(.custom("Georgia", size: 14))
                .foregroundColor(AppColors.warmBrown)
                .padding(.top, 8)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: {
                    SoundManager.shared.playClick()
                    onSimulateVotes()
                }) {
                    Text("Simulera övriga röster")
                        .font(.custom("Georgia", size: 14))
                        .foregroundColor(AppColors.inkMedium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(AppColors.warmBrown.opacity(0.1)))
                }
                
                if allVotesIn {
                    Button(action: {
                        SoundManager.shared.playClick()
                        onShowResults()
                    }) {
                        Text("Visa Resultat")
                            .font(.custom("Georgia-Bold", size: 17))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppColors.royalBlue)
                            )
                    }
                    .padding(.horizontal, 32)
                }
            }
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Ornamental Divider

/// A decorative divider with diamond center, used in headers.
struct OrnamentalDivider: View {
    var lineWidth: CGFloat = 30
    var opacity: Double = 0.3
    
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppColors.warmBrown.opacity(opacity))
                .frame(width: lineWidth, height: 1)
            Rectangle()
                .fill(AppColors.warmBrown.opacity(opacity + 0.1))
                .frame(width: 5, height: 5)
                .rotationEffect(.degrees(45))
            Rectangle()
                .fill(AppColors.warmBrown.opacity(opacity))
                .frame(width: lineWidth, height: 1)
        }
    }
}

// MARK: - Medieval Action Button

/// A styled action button matching the confirmation screen style.
/// Used for primary actions like "Fortsätt till Val", "Nästa Runda", etc.
struct MedievalActionButton: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(title: String, subtitle: String? = nil, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text(title)
                        .font(.custom("Georgia-Bold", size: 18))
                        .foregroundColor(AppColors.inkDark)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.custom("Georgia-Italic", size: 12))
                            .foregroundColor(AppColors.inkMedium)
                    }
                }
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.inkDark)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "f5edd8"))
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 3)
                    
                    // Outer border
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppColors.warmBrown.opacity(0.6), lineWidth: 1.5)
                    
                    // Inner border
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(AppColors.warmBrown.opacity(0.3), lineWidth: 0.5)
                        .padding(4)
                    
                    // Corner ornaments
                    VStack {
                        HStack {
                            ButtonCornerOrnament()
                            Spacer()
                            ButtonCornerOrnament().rotationEffect(.degrees(90))
                        }
                        Spacer()
                        HStack {
                            ButtonCornerOrnament().rotationEffect(.degrees(-90))
                            Spacer()
                            ButtonCornerOrnament().rotationEffect(.degrees(180))
                        }
                    }
                    .padding(6)
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Button Corner Ornament

/// Decorative corner ornament for medieval buttons.
struct ButtonCornerOrnament: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 8))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 8, y: 0))
        }
        .stroke(AppColors.warmBrown.opacity(0.4), lineWidth: 1)
        .frame(width: 8, height: 8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppColors.parchment.ignoresSafeArea()
        
        VStack(spacing: 20) {
            OrnamentalDivider()
            
            Text("Voting Components Preview")
                .font(.custom("Georgia-Bold", size: 20))
            
            OrnamentalDivider()
            
            MedievalActionButton(
                title: "Fortsätt till Val",
                subtitle: "Välj Läkare & Väktare",
                icon: "arrow.right"
            ) {
                print("Tapped!")
            }
            .padding(.horizontal, 24)
        }
    }
}
