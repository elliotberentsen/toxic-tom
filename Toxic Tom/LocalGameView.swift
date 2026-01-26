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
    @State private var previewAvatar: CharacterAvatar?
    @State private var showNameError = false
    @FocusState private var isNameFocused: Bool
    
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
                    
                    // Character selection - 2 column grid with names
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Välj karaktär")
                            .font(AppFonts.label())
                            .foregroundColor(AppColors.inkMedium)
                            .padding(.horizontal, AppSpacing.lg)
                        
                        GeometryReader { geometry in
                            let spacing: CGFloat = AppSpacing.md
                            let horizontalPadding: CGFloat = AppSpacing.lg
                            let availableWidth = geometry.size.width - (horizontalPadding * 2)
                            let cardWidth = (availableWidth - spacing) / 2
                            let cardHeight = cardWidth / CharacterAvatar.cardAspectRatio
                            
                            let columns = [
                                GridItem(.fixed(cardWidth), spacing: spacing),
                                GridItem(.fixed(cardWidth), spacing: spacing)
                            ]
                            
                            LazyVGrid(columns: columns, spacing: AppSpacing.lg) {
                                ForEach(gameManager.availableAvatars()) { avatar in
                                    VStack(spacing: AppSpacing.xs) {
                                        Image(avatar.imageName)
                                            .resizable()
                                            .aspectRatio(CharacterAvatar.cardAspectRatio, contentMode: .fit)
                                            .frame(width: cardWidth, height: cardHeight)
                                            .contentShape(Rectangle())
                                        
                                        Text(avatar.displayName)
                                            .font(AppFonts.bodySmall())
                                            .foregroundColor(AppColors.inkMedium)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .onTapGesture {
                                        SoundManager.shared.playClick()
                                        isNameFocused = false
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            previewAvatar = avatar
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                        }
                        .frame(height: 1600) // Height for 9 rows of cards with names
                    }
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)
                }
            }
        }
        .overlay {
            // Full-screen character confirmation overlay
            if let avatar = previewAvatar {
                LocalCharacterConfirmationOverlay(
                    avatar: avatar,
                    playerName: playerName,
                    confirmButtonText: playerNumber == gameManager.selectedPlayerCount ? "Klar" : "Nästa spelare",
                    showNameError: $showNameError,
                    onConfirm: {
                        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty else {
                            showNameError = true
                            return
                        }
                        selectedAvatar = avatar
                        withAnimation(.easeInOut(duration: 0.4)) {
                            gameManager.addPlayer(name: trimmedName, avatar: avatar)
                        }
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            previewAvatar = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .onChange(of: playerName) { _ in
            if showNameError { showNameError = false }
        }
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
            .aspectRatio(CharacterAvatar.cardAspectRatio, contentMode: .fit)
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .opacity(isSelected ? 1.0 : 0.9)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            .padding(2.5)
            .contentShape(Rectangle())
            .onTapGesture {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                onTap()
            }
    }
}

// MARK: - Local Character Confirmation View (Full Screen)

struct LocalCharacterConfirmationOverlay: View {
    let avatar: CharacterAvatar
    let playerName: String
    let confirmButtonText: String
    @Binding var showNameError: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var imageScale: CGFloat = 0.85
    @State private var imageOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Full screen parchment background
            AppColors.parchment
                .ignoresSafeArea(.all)
            
            // Subtle texture
            Image("egg-shell")
                .resizable(resizingMode: .tile)
                .opacity(0.4)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Close button at top right
                HStack {
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            imageScale = 0.85
                            imageOpacity = 0
                            contentOpacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onCancel()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.inkMedium)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(AppColors.warmBrown.opacity(0.1))
                            )
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xl)
                .opacity(contentOpacity)
                
                Spacer()
                
                // Character image - centered and prominent
                Image(avatar.imageName)
                    .resizable()
                    .aspectRatio(CharacterAvatar.cardAspectRatio, contentMode: .fit)
                    .frame(maxWidth: 280)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    .scaleEffect(imageScale)
                    .opacity(imageOpacity)
                
                Spacer()
                    .frame(height: AppSpacing.xxl)
                
                // Character name
                Text(avatar.displayName)
                    .font(AppFonts.displayLarge())
                    .foregroundColor(AppColors.inkDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                    .opacity(contentOpacity)
                
                Spacer()
                    .frame(height: AppSpacing.md)
                
                OrnamentDivider(width: 100, color: AppColors.warmBrown.opacity(0.4))
                    .opacity(contentOpacity)
                
                // Name validation error
                if showNameError {
                    Text("Ange ett namn först")
                        .font(AppFonts.bodyMedium())
                        .foregroundColor(AppColors.coralRed)
                        .padding(.top, AppSpacing.lg)
                        .opacity(contentOpacity)
                }
                
                Spacer()
                
                // Confirm button - medieval panel style
                Button(action: onConfirm) {
                    ZStack {
                        // Panel background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "f5edd8"))
                            .shadow(color: Color.black.opacity(0.12), radius: 4, y: 3)
                        
                        // Double border
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AppColors.warmBrown.opacity(0.6), lineWidth: 1.5)
                        
                        // Inner border
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(AppColors.warmBrown.opacity(0.2), lineWidth: 0.5)
                            .padding(4)
                        
                        // Corner ornaments
                        VStack {
                            HStack {
                                CornerOrnamentSmall()
                                Spacer()
                                CornerOrnamentSmall()
                                    .rotationEffect(.degrees(90))
                            }
                            Spacer()
                            HStack {
                                CornerOrnamentSmall()
                                    .rotationEffect(.degrees(-90))
                                Spacer()
                                CornerOrnamentSmall()
                                    .rotationEffect(.degrees(180))
                            }
                        }
                        .padding(6)
                        
                        // Content
                        HStack(spacing: AppSpacing.sm) {
                            Text(confirmButtonText)
                                .font(.custom("Georgia-Bold", size: 18))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(AppColors.inkDark)
                    }
                    .frame(height: 56)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
                .opacity(contentOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                imageScale = 1.0
                imageOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                contentOpacity = 1.0
            }
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
            // Avatar (show good variant)
            Image(player.avatar.imageName)
                .resizable()
                .aspectRatio(CharacterAvatar.cardAspectRatio, contentMode: .fill)
                .frame(width: 50, height: 74)
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
            // Card deck underneath - using actual card images like the demo
            ForEach(0..<3, id: \.self) { index in
                Image("card-back")
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .offset(y: CGFloat(3 - index) * 3)
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            }
            
            // Main flippable card
            ZStack {
                // Back of card
                CardBackContent()
                    .frame(width: cardWidth, height: cardHeight)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                    .opacity(isFlipped ? 0 : 1)
                
                // Front of card
                RoleCardContent(role: role, width: cardWidth, height: cardHeight)
                    .rotation3DEffect(
                        .degrees(isFlipped ? 0 : -180),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                    .opacity(isFlipped ? 1 : 0)
            }
            .offset(y: -6) // Slight offset so deck peeks at bottom
            .shadow(color: .black.opacity(isFlipped ? 0.2 : 0.12), radius: isFlipped ? 8 : 4, y: isFlipped ? 6 : 3)
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
    var width: CGFloat = 260
    var height: CGFloat = 390
    
    var body: some View {
        ZStack {
            // Card front background (parchment) - matching DemoCardFront
            Image("card-front")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
            
            // Content inside card
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: height * 0.08)
                
                // Role icon - prominent size as main focus
                Image(role.cardImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: width * 0.65)
                
                Spacer()
                    .frame(height: height * 0.03)
                
                // Role name
                Text(role.displayName)
                    .font(.custom("Georgia-Bold", size: width * 0.09))
                    .foregroundColor(AppColors.inkDark)
                
                Spacer()
                    .frame(height: height * 0.02)
                
                // Divider
                Rectangle()
                    .fill(AppColors.warmBrown.opacity(0.3))
                    .frame(width: width * 0.4, height: 1)
                
                Spacer()
                    .frame(height: height * 0.02)
                
                // Role description text INSIDE the card
                VStack(spacing: 4) {
                    Text(roleTitle(for: role))
                        .font(.custom("Georgia-Italic", size: width * 0.055))
                        .foregroundColor(AppColors.inkDark)
                    
                    Text(roleSubtitle(for: role))
                        .font(.custom("Georgia", size: width * 0.045))
                        .foregroundColor(AppColors.inkMedium)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, width * 0.1)
                
                Spacer()
                    .frame(height: height * 0.06)
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }
    
    private func roleTitle(for role: PlayerRole) -> String {
        switch role {
        case .frisk: return "Du är frisk."
        case .smittobarare: return "Du är smittobäraren."
        case .infekterad: return "Du är infekterad."
        }
    }
    
    private func roleSubtitle(for role: PlayerRole) -> String {
        switch role {
        case .frisk: return "Hitta smittobäraren."
        case .smittobarare: return "Smitta dem alla."
        case .infekterad: return "Sök ett botemedel."
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
                            .aspectRatio(CharacterAvatar.cardAspectRatio, contentMode: .fill)
                            .frame(width: 40, height: 59)
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
