//
//  LocalGameView.swift
//  Toxic Tom
//
//  Complete game flow for local/hotseat mode
//

import SwiftUI

// MARK: - Main Local Game View

struct LocalGameView: View {
    let onExit: () -> Void
    
    @ObservedObject var gameManager = GameManager.shared
    
    var body: some View {
        ZStack {
            switch gameManager.phase {
            case .playerCount:
                PlayerCountView()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                
            case .playerSetup(let playerNumber):
                PlayerSetupView(playerNumber: playerNumber)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id("setup-\(playerNumber)") // Force new view for animation
                
            case .allPlayersReady:
                AllPlayersReadyView()
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                
            case .roleReveal(let playerNumber):
                LocalRoleRevealView(playerNumber: playerNumber)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id("reveal-\(playerNumber)")
                
            case .playing:
                GamePlayingView()
                    .transition(.opacity)
                
            case .gameOver:
                Text("Game Over")
                    .font(AppFonts.displayMedium())
                    .foregroundColor(AppColors.inkDark)
                
            // Legacy phases - redirect to player count
            case .lobby, .readyCheck, .legacyRoleReveal:
                Text("Loading...")
                    .onAppear {
                        gameManager.resetAll()
                    }
            }
        }
        .texturedBackground()
        .animation(.easeInOut(duration: 0.4), value: gameManager.phase)
    }
}

// MARK: - Player Count Selection

struct PlayerCountView: View {
    @ObservedObject var gameManager = GameManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Title
            VStack(spacing: AppSpacing.sm) {
                OrnamentDivider(width: 140, color: AppColors.warmBrown)
                
                Text("Antal Spelare")
                    .font(AppFonts.displayMedium())
                    .foregroundColor(AppColors.inkDark)
                
                Text("Välj hur många som ska spela")
                    .font(AppFonts.bodyMedium())
                    .foregroundColor(AppColors.inkMedium)
                
                OrnamentDivider(width: 140, color: AppColors.warmBrown)
            }
            
            Spacer()
                .frame(height: AppSpacing.xxl)
            
            // Player count selector
            HStack(spacing: AppSpacing.lg) {
                // Decrease button
                Button(action: {
                    SoundManager.shared.playClick()
                    if gameManager.selectedPlayerCount > gameManager.minPlayers {
                        gameManager.selectedPlayerCount -= 1
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(gameManager.selectedPlayerCount > gameManager.minPlayers ? AppColors.warmBrown : AppColors.inkMedium.opacity(0.3))
                }
                .disabled(gameManager.selectedPlayerCount <= gameManager.minPlayers)
                
                // Count display
                VStack(spacing: AppSpacing.xs) {
                    Text("\(gameManager.selectedPlayerCount)")
                        .font(.system(size: 72, weight: .bold, design: .serif))
                        .foregroundColor(AppColors.inkDark)
                    
                    Text("spelare")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.inkMedium)
                }
                .frame(width: 120)
                
                // Increase button
                Button(action: {
                    SoundManager.shared.playClick()
                    if gameManager.selectedPlayerCount < gameManager.maxPlayers {
                        gameManager.selectedPlayerCount += 1
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(gameManager.selectedPlayerCount < gameManager.maxPlayers ? AppColors.royalBlue : AppColors.inkMedium.opacity(0.3))
                }
                .disabled(gameManager.selectedPlayerCount >= gameManager.maxPlayers)
            }
            
            Spacer()
                .frame(height: AppSpacing.md)
            
            // Player count hints
            Text("\(gameManager.minPlayers)-\(gameManager.maxPlayers) spelare")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.inkMedium.opacity(0.7))
            
            Spacer()
            
            // Continue button
            Button(action: {
                SoundManager.shared.playClick()
                withAnimation(.easeInOut(duration: 0.4)) {
                    gameManager.setPlayerCount(gameManager.selectedPlayerCount)
                }
            }) {
                HStack {
                    Text("Fortsätt")
                        .font(AppFonts.headingSmall())
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(AppColors.royalBlue)
                        .shadow(color: AppColors.inkDark.opacity(0.2), radius: 4, y: 2)
                )
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxl)
        }
    }
}

// MARK: - Player Setup View

struct PlayerSetupView: View {
    let playerNumber: Int
    
    @ObservedObject var gameManager = GameManager.shared
    @State private var playerName: String = ""
    @State private var selectedAvatar: CharacterAvatar?
    @State private var showNameError = false
    @FocusState private var isNameFocused: Bool
    
    // 2-column grid for character selection
    // Grid columns created dynamically in the view
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header with back button
            HStack {
                Button(action: {
                    SoundManager.shared.playClick()
                    withAnimation(.easeInOut(duration: 0.4)) {
                        if playerNumber == 1 {
                            gameManager.phase = .playerCount
                        } else {
                            if let lastPlayer = gameManager.players.last {
                                gameManager.removePlayer(lastPlayer)
                            }
                            gameManager.phase = .playerSetup(playerNumber - 1)
                        }
                    }
                }) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Tillbaka")
                            .font(AppFonts.bodyMedium())
                    }
                    .foregroundColor(AppColors.warmBrown)
                }
                
                Spacer()
                
                // Progress indicator
                Text("\(playerNumber) / \(gameManager.selectedPlayerCount)")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.inkMedium)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(
                        Capsule()
                            .fill(AppColors.warmBrown.opacity(0.1))
                    )
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
            
            // Scrollable content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Title section
                    VStack(spacing: AppSpacing.sm) {
                        Text("Spelare \(playerNumber)")
                            .font(AppFonts.displayMedium())
                            .foregroundColor(AppColors.inkDark)
                        
                        OrnamentDivider(width: 100, color: AppColors.warmBrown)
                    }
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xxl)
                    
                    // Name input
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Namn")
                            .font(AppFonts.label())
                            .foregroundColor(AppColors.inkMedium)
                        
                        TextField("Ange ditt namn", text: $playerName)
                            .font(AppFonts.bodyMedium())
                            .foregroundColor(AppColors.inkDark)
                            .padding(AppSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .fill(Color.white.opacity(0.6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.sm)
                                            .stroke(showNameError ? AppColors.coralRed : AppColors.warmBrown.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                            .focused($isNameFocused)
                        
                        if showNameError {
                            Text("Ange ett namn")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.coralRed)
                        }
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    
                    // Character selection - 2 column grid with precise spacing
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Välj karaktär")
                            .font(AppFonts.label())
                            .foregroundColor(AppColors.inkMedium)
                            .padding(.horizontal, 5)
                        
                        GeometryReader { geometry in
                            let horizontalPadding: CGFloat = 16
                            let spacing: CGFloat = 12
                            let availableWidth = geometry.size.width - (horizontalPadding * 2)
                            let itemWidth = (availableWidth - spacing) / 2
                            let itemHeight = itemWidth * (1413.0 / 1143.0)
                            
                            let gridColumns = [
                                GridItem(.fixed(itemWidth), spacing: spacing),
                                GridItem(.fixed(itemWidth), spacing: spacing)
                            ]
                            
                            LazyVGrid(columns: gridColumns, spacing: spacing) {
                                ForEach(gameManager.availableAvatars()) { avatar in
                                    let isSelected = selectedAvatar?.id == avatar.id
                                    let hasSelection = selectedAvatar != nil
                                    
                                    Image(avatar.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: itemWidth, height: itemHeight)
                                        .clipped()
                                        .saturation(hasSelection && !isSelected ? 0.7 : 1.0)
                                        .opacity(hasSelection && !isSelected ? 0.85 : 1.0)
                                        .scaleEffect(isSelected ? 1.03 : 1.0)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            SoundManager.shared.playClick()
                                            isNameFocused = false
                                            withAnimation(.spring(response: 0.3)) {
                                                selectedAvatar = avatar
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                        }
                        .frame(height: 500) // Give GeometryReader a height context
                    }
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)
                }
            }
            
            // Fixed bottom button
            VStack(spacing: 0) {
                Divider()
                    .background(AppColors.warmBrown.opacity(0.2))
                
                Button(action: {
                    SoundManager.shared.playClick()
                    
                    let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else {
                        showNameError = true
                        return
                    }
                    
                    guard let avatar = selectedAvatar else { return }
                    
                    withAnimation(.easeInOut(duration: 0.4)) {
                        gameManager.addPlayer(name: trimmedName, avatar: avatar)
                    }
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        Text(playerNumber == gameManager.selectedPlayerCount ? "Klar" : "Nästa spelare")
                            .font(AppFonts.headingSmall())
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .fill(selectedAvatar != nil ? AppColors.warmBrown : AppColors.inkMedium.opacity(0.3))
                            .shadow(color: AppColors.inkDark.opacity(0.15), radius: 4, y: 2)
                    )
                }
                .disabled(selectedAvatar == nil)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.parchment.opacity(0.95))
        }
        .onChange(of: playerName) { _ in
            if showNameError { showNameError = false }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Avatar Selection Card

struct AvatarSelectionCard: View {
    let avatar: CharacterAvatar
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Image(avatar.imageName)
            .resizable()
            .aspectRatio(1326/1990, contentMode: .fit)
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .opacity(isSelected ? 1.0 : 0.9)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            .padding(2.5) // Half of 5px on each side = 5px total gap between cards
            .contentShape(Rectangle())
            .onTapGesture {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                onTap()
            }
    }
}

// MARK: - All Players Ready View

struct AllPlayersReadyView: View {
    @ObservedObject var gameManager = GameManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Title
            VStack(spacing: AppSpacing.sm) {
                OrnamentDivider(width: 160, color: AppColors.warmBrown)
                
                Text("Alla Spelare Redo")
                    .font(AppFonts.displayMedium())
                    .foregroundColor(AppColors.inkDark)
                
                OrnamentDivider(width: 160, color: AppColors.warmBrown)
            }
            
            Spacer()
                .frame(height: AppSpacing.xl)
            
            // Player list
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    ForEach(gameManager.players) { player in
                        PlayerReadyCard(player: player)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
            
            Spacer()
            
            // Warning text
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.warmBrown)
                
                Text("Varje spelare kommer se sin roll privat")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.inkMedium)
                    .multilineTextAlignment(.center)
                
                Text("Ge telefonen till Spelare 1 när du trycker starta")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.inkMedium)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.xl)
            
            Spacer()
                .frame(height: AppSpacing.lg)
            
            // Start button
            Button(action: {
                SoundManager.shared.playClick()
                withAnimation(.easeInOut(duration: 0.4)) {
                    gameManager.startGame()
                }
            }) {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                    Text("Starta Spelet")
                        .font(AppFonts.headingSmall())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(AppColors.oliveGreen)
                        .shadow(color: AppColors.inkDark.opacity(0.2), radius: 4, y: 2)
                )
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxl)
        }
    }
}

// MARK: - Player Ready Card

struct PlayerReadyCard: View {
    @ObservedObject var player: Player
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar
            Image(player.avatar.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            
            // Player info
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Spelare \(player.playerNumber)")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.inkMedium)
                
                Text(player.name)
                    .font(AppFonts.headingMedium())
                    .foregroundColor(AppColors.inkDark)
            }
            
            Spacer()
            
            // Ready indicator
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(AppColors.oliveGreen)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(Color.white.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.warmBrown.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Local Role Reveal View

struct LocalRoleRevealView: View {
    let playerNumber: Int
    
    @ObservedObject var gameManager = GameManager.shared
    @State private var isCardFlipped = false
    @State private var showingCard = false
    
    var player: Player? {
        gameManager.currentPlayerForReveal()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Player indicator
            VStack(spacing: AppSpacing.sm) {
                Text("Ge telefonen till")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.inkMedium)
                
                Text(player?.name ?? "Spelare \(playerNumber)")
                    .font(AppFonts.displayMedium())
                    .foregroundColor(AppColors.inkDark)
                
                OrnamentDivider(width: 120, color: AppColors.warmBrown)
            }
            .padding(.top, AppSpacing.xxl * 1.5)
            
            Spacer()
            
            // Card area
            if showingCard {
                RoleFlipCard(
                    role: player?.role ?? .frisk,
                    isFlipped: $isCardFlipped
                )
            } else {
                // Tap to reveal instruction
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.warmBrown)
                    
                    Text("Tryck för att se din roll")
                        .font(AppFonts.headingMedium())
                        .foregroundColor(AppColors.inkMedium)
                    
                    Text("Endast du ska se detta")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.inkMedium.opacity(0.7))
                }
                .onTapGesture {
                    SoundManager.shared.playClick()
                    withAnimation(.spring(response: 0.5)) {
                        showingCard = true
                    }
                }
            }
            
            Spacer()
            
            // Continue button (only show after card is flipped)
            if isCardFlipped {
                Button(action: {
                    SoundManager.shared.playClick()
                    withAnimation(.easeInOut(duration: 0.4)) {
                        gameManager.confirmRoleSeen()
                    }
                }) {
                    HStack {
                        Text(playerNumber == gameManager.players.count ? "Starta Spelet" : "Ge till nästa spelare")
                            .font(AppFonts.headingSmall())
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .fill(AppColors.royalBlue)
                            .shadow(color: AppColors.inkDark.opacity(0.2), radius: 4, y: 2)
                    )
                }
                .padding(.horizontal, AppSpacing.xl)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            Spacer()
                .frame(height: AppSpacing.xxl)
        }
        .onAppear {
            // Reset state for new player
            isCardFlipped = false
            showingCard = false
        }
    }
}

// MARK: - Role Flip Card

struct RoleFlipCard: View {
    let role: PlayerRole
    @Binding var isFlipped: Bool
    
    let cardWidth: CGFloat = 260
    let cardHeight: CGFloat = 390
    
    var body: some View {
        ZStack {
            // Card stack effect (back cards)
            ForEach(0..<2) { i in
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(Color(hex: "2C1810"))
                    .frame(width: cardWidth - CGFloat(i * 6), height: cardHeight - CGFloat(i * 6))
                    .offset(y: CGFloat((2 - i) * 4))
                    .opacity(0.5 + Double(i) * 0.2)
            }
            
            // Main card
            ZStack {
                // Back of card
                CardBackContent()
                    .frame(width: cardWidth, height: cardHeight)
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(isFlipped ? -180 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                
                // Front of card
                RoleCardContent(role: role)
                    .frame(width: cardWidth, height: cardHeight)
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 0 : 180),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
            }
            .onTapGesture {
                if !isFlipped {
                    SoundManager.shared.playCardFlip()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isFlipped = true
                    }
                }
            }
        }
    }
}

// MARK: - Card Back Content

struct CardBackContent: View {
    var body: some View {
        Image("card-back")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }
}

// MARK: - Role Card Content

struct RoleCardContent: View {
    let role: PlayerRole
    
    var roleColor: Color {
        switch role {
        case .frisk: return AppColors.oliveGreen
        case .smittobarare: return AppColors.coralRed
        case .infekterad: return AppColors.coralRed.opacity(0.7)
        }
    }
    
    var body: some View {
        ZStack {
            // Card frame
            Image("card-frame")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            
            // Role content
            VStack(spacing: AppSpacing.md) {
                Spacer()
                
                // Role icon
                Image(role.cardImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                
                // Role name
                Text(role.displayName)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(roleColor)
                
                // Divider
                OrnamentDivider(width: 100, color: roleColor.opacity(0.5))
                
                // Description
                Text(role.description)
                    .font(AppFonts.bodyMedium())
                    .foregroundColor(AppColors.inkDark)
                    .multilineTextAlignment(.center)
                
                // Objective
                Text(role.objective)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.inkMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
                
                Spacer()
            }
            .padding(AppSpacing.lg)
        }
    }
}

// MARK: - Game Playing View (Placeholder)

struct GamePlayingView: View {
    @ObservedObject var gameManager = GameManager.shared
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Spelet Börjar!")
                .font(AppFonts.displayMedium())
                .foregroundColor(AppColors.inkDark)
            
            OrnamentDivider(width: 140, color: AppColors.warmBrown)
            
            Text("Spelmekaniken kommer snart...")
                .font(AppFonts.bodyMedium())
                .foregroundColor(AppColors.inkMedium)
            
            Spacer()
                .frame(height: AppSpacing.xxl)
            
            // Player overview
            VStack(spacing: AppSpacing.md) {
                ForEach(gameManager.players) { player in
                    HStack {
                        Image(player.avatar.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                        
                        Text(player.name)
                            .font(AppFonts.bodyMedium())
                            .foregroundColor(AppColors.inkDark)
                        
                        Spacer()
                        
                        // Status indicator (hidden in real game)
                        Circle()
                            .fill(AppColors.oliveGreen)
                            .frame(width: 12, height: 12)
                    }
                    .padding(AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .fill(Color.white.opacity(0.3))
                    )
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            
            Spacer()
            
            // Restart button
            Button(action: {
                SoundManager.shared.playClick()
                withAnimation {
                    gameManager.resetAll()
                }
            }) {
                Text("Avsluta Spelet")
                    .font(AppFonts.headingSmall())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .fill(AppColors.coralRed)
                    )
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxl)
        }
    }
}

#Preview {
    LocalGameView(onExit: {})
}
