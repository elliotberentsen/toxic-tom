//
//  GameSetupView.swift
//  Toxic Tom
//
//  Player setup, ready check, and role reveal views
//

import SwiftUI

// MARK: - Main Game Setup View

struct GameSetupView: View {
    @ObservedObject private var gameManager = GameManager.shared
    @State private var showingAddPlayer = false
    @Binding var showGame: Bool
    
    var body: some View {
        ZStack {
            // Background
            AppColors.parchment
                .ignoresSafeArea()
            
            // Texture
            ParchmentTexture()
            
            switch gameManager.phase {
            case .lobby:
                LobbyView(
                    gameManager: gameManager,
                    showingAddPlayer: $showingAddPlayer,
                    onBack: { showGame = false }
                )
            case .readyCheck:
                ReadyCheckView(gameManager: gameManager)
            case .legacyRoleReveal:
                LegacyRoleRevealView(gameManager: gameManager)
            case .playing:
                // TODO: Main game view
                PlayingPlaceholderView(gameManager: gameManager)
            case .gameOver:
                // TODO: Game over view
                Text("Game Over")
            default:
                // Handle new phases - redirect to home
                Text("Loading...")
                    .onAppear { showGame = false }
            }
            
            // Add player sheet
            if showingAddPlayer {
                AddPlayerOverlay(
                    gameManager: gameManager,
                    isPresented: $showingAddPlayer
                )
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Parchment Texture

struct ParchmentTexture: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<25, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<12, id: \.self) { col in
                        Rectangle()
                            .fill(AppColors.inkDark.opacity(Double.random(in: 0.01...0.04)))
                            .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Lobby View

struct LobbyView: View {
    @ObservedObject var gameManager: GameManager
    @Binding var showingAddPlayer: Bool
    var onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12))
                        Text("Return")
                            .font(.custom("Georgia", size: 14))
                    }
                    .foregroundColor(AppColors.inkLight)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            
            // Title
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    OrnamentLine()
                    OrnamentDiamond()
                    OrnamentLine()
                }
                .frame(width: 160)
                
                Text("Gather Thy Players")
                    .font(.custom("Georgia-Bold", size: 26))
                    .tracking(1)
                    .foregroundColor(AppColors.inkDark)
                
                Text("\(gameManager.players.count) players")
                    .font(.custom("Georgia", size: 14))
                    .foregroundColor(AppColors.inkLight)
            }
            .padding(.top, 20)
            .padding(.bottom, 24)
            
            // Player list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(gameManager.players) { player in
                        PlayerRow(player: player) {
                            gameManager.removePlayer(player)
                        }
                    }
                    
                    // Add player button
                    if gameManager.players.count < gameManager.maxPlayers {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingAddPlayer = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                Text("Add Player")
                                    .font(.custom("Georgia", size: 16))
                            }
                            .foregroundColor(AppColors.burntOrange)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppColors.burntOrange.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 120)
            }
            
            Spacer()
        }
        
        // Start button overlay
        if gameManager.canStartGame() {
            VStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        gameManager.startReadyCheck()
                    }
                }) {
                    Text("BEGIN")
                        .font(.custom("Georgia-Bold", size: 18))
                        .tracking(3)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.burntOrange)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .shadow(color: AppColors.burntOrange.opacity(0.3), radius: 12, y: 4)
            }
        }
    }
}

// MARK: - Player Row

struct PlayerRow: View {
    @ObservedObject var player: Player
    var onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            Image(player.avatar.imageName)
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 50, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: Color.black.opacity(0.15), radius: 3, y: 2)
            
            // Name
            Text(player.name)
                .font(.custom("Georgia", size: 18))
                .foregroundColor(AppColors.inkDark)
            
            Spacer()
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.inkLight.opacity(0.4))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.parchmentLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.inkLight.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Add Player Overlay

struct AddPlayerOverlay: View {
    @ObservedObject var gameManager: GameManager
    @Binding var isPresented: Bool
    
    @State private var playerName: String = ""
    @State private var selectedAvatar: CharacterAvatar? = nil
    @FocusState private var nameFieldFocused: Bool
    
    private var usedAvatars: Set<String> {
        Set(gameManager.players.map { $0.avatar.id })
    }
    
    private var availableAvatars: [CharacterAvatar] {
        CharacterAvatar.allAvatars.filter { !usedAvatars.contains($0.id) }
    }
    
    private var canAdd: Bool {
        !playerName.trimmingCharacters(in: .whitespaces).isEmpty && selectedAvatar != nil
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { isPresented = false }
                }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("New Player")
                        .font(.custom("Georgia-Bold", size: 20))
                        .foregroundColor(AppColors.inkDark)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation { isPresented = false }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.inkLight)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
                
                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("NAME")
                        .font(.custom("Georgia", size: 11))
                        .tracking(2)
                        .foregroundColor(AppColors.inkLight)
                    
                    TextField("Enter name", text: $playerName)
                        .font(.custom("Georgia", size: 18))
                        .foregroundColor(AppColors.inkDark)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.inkLight.opacity(0.2), lineWidth: 1)
                        )
                        .focused($nameFieldFocused)
                }
                .padding(.horizontal, 24)
                
                // Avatar selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("CHARACTER")
                        .font(.custom("Georgia", size: 11))
                        .tracking(2)
                        .foregroundColor(AppColors.inkLight)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(availableAvatars) { avatar in
                                AvatarOption(
                                    avatar: avatar,
                                    isSelected: selectedAvatar == avatar
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedAvatar = avatar
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer()
                
                // Add button
                Button(action: {
                    if canAdd, let avatar = selectedAvatar {
                        gameManager.addPlayer(
                            name: playerName.trimmingCharacters(in: .whitespaces),
                            avatar: avatar
                        )
                        withAnimation { isPresented = false }
                    }
                }) {
                    Text("ADD PLAYER")
                        .font(.custom("Georgia-Bold", size: 16))
                        .tracking(2)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(canAdd ? AppColors.burntOrange : AppColors.inkLight.opacity(0.3))
                        )
                }
                .disabled(!canAdd)
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .frame(maxHeight: 420)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.parchment)
            )
            .padding(.horizontal, 20)
        }
        .onAppear {
            nameFieldFocused = true
            // Pre-select first available avatar
            if selectedAvatar == nil {
                selectedAvatar = availableAvatars.first
            }
        }
    }
}

// MARK: - Avatar Option

struct AvatarOption: View {
    let avatar: CharacterAvatar
    let isSelected: Bool
    
    @State private var isPressed = false
    
    var body: some View {
        Image(avatar.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: 80, height: 80)
            // Zoom effect for selection
            .scaleEffect(isSelected ? 1.1 : (isPressed ? 0.95 : 1.0))
            .shadow(
                color: Color.black.opacity(isSelected ? 0.25 : 0.1),
                radius: isSelected ? 6 : 2,
                y: isSelected ? 3 : 1
            )
            .opacity(isSelected ? 1.0 : 0.85)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - Ready Check View

struct ReadyCheckView: View {
    @ObservedObject var gameManager: GameManager
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 80)
            
            // Title
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    OrnamentLine()
                    OrnamentDiamond()
                    OrnamentLine()
                }
                .frame(width: 160)
                
                Text("Ready Thyselves")
                    .font(.custom("Georgia-Bold", size: 26))
                    .tracking(1)
                    .foregroundColor(AppColors.inkDark)
                
                Text("Each player must confirm")
                    .font(.custom("Georgia", size: 14))
                    .foregroundColor(AppColors.inkLight)
            }
            .padding(.bottom, 32)
            
            // Player ready grid
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(gameManager.players) { player in
                        ReadyPlayerCard(player: player) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                gameManager.markPlayerReady(player)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Ready Player Card

struct ReadyPlayerCard: View {
    @ObservedObject var player: Player
    var onTap: () -> Void
    
    var body: some View {
        Button(action: {
            if !player.isReady {
                onTap()
            }
        }) {
            VStack(spacing: 8) {
                // Avatar
                ZStack {
                    Image(player.avatar.imageName)
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fit)
                        .opacity(player.isReady ? 0.5 : 1.0)
                    
                    if player.isReady {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.oliveGreen)
                    }
                }
                
                // Name
                Text(player.name)
                    .font(.custom("Georgia", size: 14))
                    .foregroundColor(player.isReady ? AppColors.inkLight : AppColors.inkDark)
                
                // Status
                Text(player.isReady ? "READY" : "TAP TO READY")
                    .font(.custom("Georgia", size: 10))
                    .tracking(1)
                    .foregroundColor(player.isReady ? AppColors.oliveGreen : AppColors.burntOrange)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(player.isReady ? AppColors.parchmentLight : AppColors.parchment)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(player.isReady ? AppColors.oliveGreen.opacity(0.3) : AppColors.inkLight.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Legacy Role Reveal View

struct LegacyRoleRevealView: View {
    @ObservedObject var gameManager: GameManager
    @State private var showingRole = false
    
    var currentPlayer: Player? {
        gameManager.legacyCurrentPlayerForReveal()
    }
    
    var body: some View {
        ZStack {
            if let player = currentPlayer {
                    if showingRole {
                        // Show the role
                        RoleCardReveal(player: player) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingRole = false
                                gameManager.legacyConfirmRoleSeen()
                            }
                        }
                        .transition(.opacity)
                } else {
                    // Pass device prompt
                    PassDeviceView(player: player) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showingRole = true
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - Pass Device View

struct PassDeviceView: View {
    let player: Player
    var onReveal: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Player avatar
            Image(player.avatar.imageName)
                .resizable()
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: 120)
                .shadow(color: Color.black.opacity(0.2), radius: 12, y: 6)
            
            // Instructions
            VStack(spacing: 12) {
                Text("Pass to")
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(AppColors.inkLight)
                
                Text(player.name.uppercased())
                    .font(.custom("Georgia-Bold", size: 28))
                    .tracking(2)
                    .foregroundColor(AppColors.inkDark)
                
                Text("Only this player should see the next screen")
                    .font(.custom("Georgia", size: 14))
                    .foregroundColor(AppColors.inkLight)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Reveal button
            Button(action: onReveal) {
                Text("REVEAL MY ROLE")
                    .font(.custom("Georgia-Bold", size: 16))
                    .tracking(2)
                    .foregroundColor(.white)
                    .frame(width: 220, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.burntOrange)
                    )
            }
            .shadow(color: AppColors.burntOrange.opacity(0.3), radius: 12, y: 4)
            .padding(.bottom, 60)
        }
    }
}

// MARK: - Card Back View

struct CardBackView: View {
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        Image("card-back")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
    }
}

// MARK: - Card Front View (role icon + name inside card frame)

struct CardFrontView: View {
    let roleIcon: String
    let roleName: String
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        ZStack {
            // Card front background (parchment)
            Image("card-front")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
            
            // Content overlay
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: height * 0.08)
                
                // Role icon
                Image(roleIcon)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: width * 0.6)
                
                Spacer()
                
                // Role name
                Text(roleName)
                    .font(.custom("Georgia-Bold", size: width * 0.085))
                    .tracking(2)
                    .foregroundColor(AppColors.inkDark)
                    .padding(.bottom, height * 0.1)
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

// MARK: - Deck of Cards

struct CardDeck: View {
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let cardCount: Int
    
    var body: some View {
        ZStack {
            ForEach(0..<cardCount, id: \.self) { index in
                CardBackView(width: cardWidth, height: cardHeight)
                    .offset(y: CGFloat(cardCount - 1 - index) * 4)
                    .shadow(color: Color.black.opacity(0.08), radius: 2, y: 2)
            }
        }
    }
}

// MARK: - Flippable Card (with 3D rotation)

struct FlippableCard: View {
    let roleIcon: String
    let roleName: String
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    @Binding var isFlipped: Bool
    
    var body: some View {
        ZStack {
            // BACK of card
            CardBackView(width: cardWidth, height: cardHeight)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .opacity(isFlipped ? 0 : 1)
            
            // FRONT of card (starts rotated away)
            CardFrontView(
                roleIcon: roleIcon,
                roleName: roleName,
                width: cardWidth,
                height: cardHeight
            )
            .rotation3DEffect(
                .degrees(isFlipped ? 0 : -180),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .opacity(isFlipped ? 1 : 0)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipped()
    }
}

// MARK: - Role Card Reveal

struct RoleCardReveal: View {
    let player: Player
    var onContinue: () -> Void
    
    @State private var isFlipped: Bool = false
    @State private var showContent: Bool = false
    @State private var canTap: Bool = true
    
    // Card dimensions using new aspect ratio (805:1172)
    private let cardWidth: CGFloat = 220
    private var cardHeight: CGFloat { cardWidth * (1172.0 / 805.0) }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Instructions
            if !isFlipped {
                Text("Tap the card to reveal your role")
                    .font(.custom("Georgia-Italic", size: 14))
                    .foregroundColor(AppColors.inkLight)
                    .padding(.bottom, 20)
                    .transition(.opacity)
            }
            
            // Card deck with flippable top card
            ZStack {
                // Deck underneath (5 card backs)
                CardDeck(cardWidth: cardWidth, cardHeight: cardHeight, cardCount: 5)
                    .offset(y: 16)
                
                // Top card (flippable) - same position as top of deck
                FlippableCard(
                    roleIcon: player.role.cardImage,
                    roleName: player.role.displayName,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    isFlipped: $isFlipped
                )
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: 8,
                    y: 5
                )
                .onTapGesture {
                    if canTap && !isFlipped {
                        canTap = false
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isFlipped = true
                        }
                        // Show content after flip
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showContent = true
                            }
                        }
                    }
                }
            }
            .frame(width: cardWidth, height: cardHeight + 20)
            
            Spacer()
                .frame(height: 30)
            
            // Message (appears after flip)
            VStack(spacing: 8) {
                if player.role == .smittobarare {
                    Text("You are the Carrier.")
                        .font(.custom("Georgia-Italic", size: 17))
                        .foregroundColor(AppColors.inkDark)
                    Text("Infect them all.")
                        .font(.custom("Georgia", size: 14))
                        .foregroundColor(AppColors.inkLight)
                } else {
                    Text("You are healthy.")
                        .font(.custom("Georgia-Italic", size: 17))
                        .foregroundColor(AppColors.inkDark)
                    Text("Find the Carrier.")
                        .font(.custom("Georgia", size: 14))
                        .foregroundColor(AppColors.inkLight)
                }
            }
            .frame(height: 60)
            .opacity(showContent ? 1 : 0)
            
            Spacer()
            
            // Continue button (appears after flip)
            Button(action: onContinue) {
                Text("I UNDERSTAND")
                    .font(.custom("Georgia-Bold", size: 16))
                    .tracking(2)
                    .foregroundColor(.white)
                    .frame(width: 200, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.burntOrange)
                    )
            }
            .shadow(color: AppColors.burntOrange.opacity(0.3), radius: 8, y: 4)
            .opacity(showContent ? 1 : 0)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Playing Placeholder

struct PlayingPlaceholderView: View {
    @ObservedObject var gameManager: GameManager
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("All roles revealed!")
                .font(.custom("Georgia-Bold", size: 24))
                .foregroundColor(AppColors.inkDark)
            
            Text("Game would continue here...")
                .font(.custom("Georgia", size: 16))
                .foregroundColor(AppColors.inkLight)
            
            Spacer()
            
            Button(action: {
                gameManager.resetAll()
            }) {
                Text("RETURN TO LOBBY")
                    .font(.custom("Georgia-Bold", size: 14))
                    .tracking(2)
                    .foregroundColor(AppColors.burntOrange)
            }
            .padding(.bottom, 60)
        }
    }
}

// MARK: - Preview

#Preview {
    GameSetupView(showGame: .constant(true))
}
