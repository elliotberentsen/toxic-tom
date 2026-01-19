//
//  ContentView.swift
//  Toxic Tom
//
//  Created by Elliot Berentsen on 2026-01-18.
//

import SwiftUI

// MARK: - Character Model

struct GameCharacter: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let cardImage: String
    let description: String
    
    static func == (lhs: GameCharacter, rhs: GameCharacter) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - App Views

enum AppView {
    case home
    case characterSelect
    case localGame        // New local/hotseat game flow
    case gameSetup
    case rules
    case diceSimulator
    case cardFlipTest
    case settings
}

// MARK: - Content View

struct ContentView: View {
    @State private var currentView: AppView = .home
    @State private var selectedCharacter: GameCharacter? = nil
    @State private var diceResult: Int? = nil
    @State private var showDiceResult = false
    @State private var hasStartedMusic = false
    
    let characters: [GameCharacter] = [
        GameCharacter(name: "Woman 30", cardImage: "kvinna-30", description: ""),
        GameCharacter(name: "Woman 45", cardImage: "kvinna-45", description: ""),
        GameCharacter(name: "Woman 60", cardImage: "kvinna-ansikte-60", description: ""),
        GameCharacter(name: "Man 60", cardImage: "man-60-ansikte", description: "")
    ]
    
    var body: some View {
        ZStack {
            switch currentView {
            case .home:
                homeView
            case .characterSelect:
                characterSelectView
            case .localGame:
                LocalGameView(onExit: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        GameManager.shared.resetAll()
                        currentView = .home
                    }
                })
            case .gameSetup:
                GameSetupView(showGame: Binding(
                    get: { currentView == .gameSetup },
                    set: { if !$0 { currentView = .home } }
                ))
            case .rules:
                rulesView
            case .diceSimulator:
                diceSimulatorView
            case .cardFlipTest:
                cardFlipTestView
            case .settings:
                SettingsView(onBack: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentView = .home
                    }
                })
            }
        }
        .texturedBackground()
        .onAppear {
            // Start background music when app launches (only once)
            if !hasStartedMusic {
                hasStartedMusic = true
                SoundManager.shared.playMusic()
            }
        }
    }
    
    // MARK: - Home View
    
    @ObservedObject private var gameCenterManager = GameCenterManager.shared
    
    private var homeView: some View {
        VStack(spacing: 0) {
            // Top bar with Game Center status and settings
            HStack {
                // Game Center status
                Button(action: {
                    SoundManager.shared.playClick()
                    if gameCenterManager.isAuthenticated {
                        gameCenterManager.showDashboard()
                    } else {
                        gameCenterManager.authenticate()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: gameCenterManager.isAuthenticated ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark")
                            .font(.system(size: 16))
                        Text(gameCenterManager.isAuthenticated ? gameCenterManager.playerName : "Sign In")
                            .font(.custom("Georgia", size: 12))
                    }
                    .foregroundColor(gameCenterManager.isAuthenticated ? AppColors.oliveGreen : AppColors.coralRed)
                }
                
                Spacer()
                
                Button(action: {
                    SoundManager.shared.playClick()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentView = .settings
                    }
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.inkMedium)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 50)
            
            Spacer()
                .frame(height: 40)
            
            // Title Section
            VStack(spacing: 16) {
                // Decorative top flourish
                OrnamentDivider(width: 180, color: AppColors.warmBrown)
                
                // Game Title
                VStack(spacing: 6) {
                    Text("SMITTOBÄRAREN")
                        .font(AppFonts.displayLarge())
                        .tracking(3)
                        .foregroundColor(AppColors.inkDark)
                    
                    Text("— The Carrier —")
                        .font(AppFonts.bodyItalic())
                        .foregroundColor(AppColors.warmBrown)
                }
                
                // Decorative bottom flourish
                OrnamentDivider(width: 180, color: AppColors.warmBrown)
            }
            
            Spacer()
            
            // Center emblem area
            ZStack {
                // Outer decorative ring
                Circle()
                    .stroke(AppColors.warmBrown.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 140, height: 140)
                
                // Inner decorative ring with dashes
                Circle()
                    .stroke(AppColors.warmBrown.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .frame(width: 110, height: 110)
                
                // Center cross emblem
                VStack(spacing: 4) {
                    Image(systemName: "cross.fill")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(AppColors.warmBrown.opacity(0.5))
                    
                    Text("ANNO")
                        .font(.custom("Georgia", size: 9))
                        .tracking(2)
                        .foregroundColor(AppColors.warmBrown.opacity(0.4))
                    Text("MMXXVI")
                        .font(.custom("Georgia", size: 11))
                        .tracking(1)
                        .foregroundColor(AppColors.warmBrown.opacity(0.4))
                }
            }
            
            Spacer()
                
            // Buttons Section
            VStack(spacing: AppSpacing.md) {
                // PRIMARY: Start Game (Local/Hotseat mode)
                Button(action: { 
                    SoundManager.shared.playClick()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        GameManager.shared.resetAll()
                        currentView = .localGame
                    }
                }) {
                    Text("BEGIN JOURNEY")
                }
                .buttonStyle(.primary)
                
                // Card Flip Test
                Button(action: { 
                    SoundManager.shared.playClick()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentView = .cardFlipTest
                    }
                }) {
                    Text("Test Card Flip")
                }
                .buttonStyle(.secondary)
                
                // SECONDARY: How to Play
                Button(action: { 
                    SoundManager.shared.playClick()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentView = .rules
                    }
                }) {
                    Text("Rules of Play")
                }
                .buttonStyle(.tertiary)
                
                // TERTIARY: Dice Simulator
                Button(action: { 
                    SoundManager.shared.playClick()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentView = .diceSimulator
                    }
                }) {
                    Text("Test the Dice")
                }
                .buttonStyle(.tertiary)
            }
            .padding(.horizontal, 40)
                
            Spacer()
                .frame(height: 30)
            
            // Version - styled
            Text("Version 0.1")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.inkMedium.opacity(0.5))
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Character Select View
    
    private var characterSelectView: some View {
        ZStack {
            // Subtle texture overlay for aged feel
            VStack(spacing: 0) {
                ForEach(0..<25, id: \.self) { _ in
                    HStack(spacing: 0) {
                        ForEach(0..<12, id: \.self) { _ in
                            Rectangle()
                                .fill(AppColors.inkDark.opacity(Double.random(in: 0.01...0.04)))
                                .frame(width: 36, height: 36)
                        }
                    }
                }
            }
            .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                // Header with back button
                HStack {
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .home
                        }
                    }) {
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
                
                // Title with ornaments
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        OrnamentLine()
                        OrnamentDiamond()
                        OrnamentLine()
                    }
                    .frame(width: 160)
                    
                    Text("Choose Thy Character")
                        .font(.custom("Georgia-Bold", size: 26))
                        .tracking(1)
                        .foregroundColor(AppColors.inkDark)
                    
                    HStack(spacing: 8) {
                        OrnamentLine()
                        OrnamentDiamond()
                        OrnamentLine()
                    }
                    .frame(width: 160)
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Character Cards - 2 column grid
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 2),
                        GridItem(.flexible(), spacing: 2)
                    ], spacing: 2) {
                        ForEach(characters) { character in
                            CharacterCard(
                                character: character,
                                isSelected: false
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedCharacter = character
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 20)
                }
            }
            
            // Confirmation overlay
            if let selected = selectedCharacter {
                CharacterConfirmationOverlay(
                    character: selected,
                    onConfirm: {
                        // TODO: Start game with selected character
                    },
                    onClose: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCharacter = nil
                        }
                    }
                )
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Rules View
    
    private var rulesView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { 
                    SoundManager.shared.playClick()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentView = .home
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12))
                        Text("Return")
                            .font(.custom("Georgia", size: 14))
                    }
                    .foregroundColor(AppColors.inkMedium)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            
            // Title with ornaments
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    OrnamentLine()
                    OrnamentDiamond()
                    OrnamentLine()
                }
                .frame(width: 140)
                
                Text("Rules of Play")
                    .font(.custom("Georgia-Bold", size: 28))
                    .tracking(1)
                    .foregroundColor(AppColors.inkDark)
                
                HStack(spacing: 8) {
                    OrnamentLine()
                    OrnamentDiamond()
                    OrnamentLine()
                }
                .frame(width: 140)
            }
            .padding(.top, 20)
            
            // Rules content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    RuleSection(
                        number: "1",
                        title: "Setup",
                        description: "Each player receives a secret role. One player is secretly The Carrier - infected with the plague."
                    )
                    
                    RuleSection(
                        number: "2",
                        title: "Gameplay",
                        description: "Players take turns interacting. Each interaction requires a dice roll to determine if infection spreads."
                    )
                    
                    RuleSection(
                        number: "3",
                        title: "The Dice",
                        description: "Roll the D20. Low numbers mean infection risk. High numbers are safe. A natural 1 is automatic infection!"
                    )
                    
                    RuleSection(
                        number: "4",
                        title: "Victory",
                        description: "Healthy players win by identifying The Carrier. The Carrier wins by infecting everyone without being caught."
                    )
                }
                .padding(.horizontal, 30)
                .padding(.top, 30)
                .padding(.bottom, 50)
            }
        }
    }
    
    // MARK: - Dice Simulator View
    
    private var diceSimulatorView: some View {
        ZStack {
            // Dark background for dice contrast
            Color(hex: "1a1510")
                .ignoresSafeArea()
            
            DiceSceneView(
                onResult: { value in
                    withAnimation(.easeOut(duration: 0.3)) {
                        diceResult = value
                        showDiceResult = true
                    }
                },
                onRollStart: {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showDiceResult = false
                    }
                }
            )
            .ignoresSafeArea()
            
            VStack {
                // Back button
                HStack {
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .home
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.parchment)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
                
                // Result
                if showDiceResult, let result = diceResult {
                    VStack(spacing: 8) {
                        Text(resultLabel(for: result))
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .tracking(2)
                            .foregroundColor(AppColors.parchment.opacity(0.6))
                        
                        Text("\(result)")
                            .font(.system(size: 72, weight: .light, design: .serif))
                            .foregroundColor(resultColor(for: result))
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                    )
                }
                
                Spacer()
                    .frame(height: 80)
                
                if !showDiceResult {
                    Text("Tap anywhere to roll")
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(AppColors.parchment.opacity(0.3))
                        .padding(.bottom, 40)
                }
            }
        }
    }
    
    // MARK: - Card Flip Test View
    
    private var cardFlipTestView: some View {
        CardFlipDemoView(
            onBack: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentView = .home
                }
            }
        )
    }
    
    // MARK: - Helpers
    
    private func resultLabel(for value: Int) -> String {
        switch value {
        case 20: return "CRITICAL SUCCESS"
        case 1: return "CRITICAL FAIL"
        default: return "RESULT"
        }
    }
    
    private func resultColor(for value: Int) -> Color {
        switch value {
        case 20: return AppColors.oliveGreen
        case 1: return Color(hex: "c94040")
        default: return AppColors.parchment
        }
    }
}

// MARK: - Character Card

struct CharacterCard: View {
    let character: GameCharacter
    let isSelected: Bool
    
    var body: some View {
        Image(character.cardImage)
            .resizable()
            .aspectRatio(2/3, contentMode: .fit)
            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
    }
}

// MARK: - Character Confirmation Overlay

struct CharacterConfirmationOverlay: View {
    let character: GameCharacter
    let onConfirm: () -> Void
    let onClose: () -> Void
    
    @State private var cardAppeared = false
    @State private var contentAppeared = false
    
    var body: some View {
        ZStack {
            // Parchment background
            AppColors.parchment
                .ignoresSafeArea()
            
            // Subtle texture
            VStack(spacing: 0) {
                ForEach(0..<25, id: \.self) { _ in
                    HStack(spacing: 0) {
                        ForEach(0..<12, id: \.self) { _ in
                            Rectangle()
                                .fill(AppColors.inkDark.opacity(Double.random(in: 0.01...0.04)))
                                .frame(width: 36, height: 36)
                        }
                    }
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Back option
                HStack {
                    Button(action: onClose) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12))
                            Text("Choose Another")
                                .font(.custom("Georgia", size: 14))
                        }
                        .foregroundColor(AppColors.inkLight)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .opacity(contentAppeared ? 1 : 0)
                
                Spacer()
                
                // Title with ornaments
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        OrnamentLine()
                        OrnamentDiamond()
                        OrnamentLine()
                    }
                    .frame(width: 160)
                    
                    Text("THY CHAMPION")
                        .font(.custom("Georgia-Bold", size: 14))
                        .tracking(4)
                        .foregroundColor(AppColors.inkLight)
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 10)
                
                Spacer()
                    .frame(height: 24)
                
                // The card - animated entrance
                Image(character.cardImage)
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fit)
                    .frame(maxWidth: 240)
                    .shadow(color: Color.black.opacity(0.25), radius: 16, y: 8)
                    .scaleEffect(cardAppeared ? 1 : 0.85)
                    .opacity(cardAppeared ? 1 : 0)
                
                Spacer()
                
                // Continue button
                Button(action: onConfirm) {
                    Text("CONTINUE")
                        .font(.custom("Georgia-Bold", size: 16))
                        .tracking(3)
                        .foregroundColor(AppColors.parchment)
                        .frame(width: 200, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.burntOrange)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(AppColors.warmGold.opacity(0.4), lineWidth: 1)
                                .padding(3)
                        )
                }
                .shadow(color: AppColors.burntOrange.opacity(0.4), radius: 12, y: 4)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 20)
                
                Spacer()
                    .frame(height: 60)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                cardAppeared = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                contentAppeared = true
            }
        }
    }
}

// MARK: - Card Flip Demo View

struct CardFlipDemoView: View {
    let onBack: () -> Void
    
    @State private var isFlipped = false
    @State private var showButton = false
    
    // Card takes up most of screen - using exact image ratio (1136:1962)
    private let cardWidth: CGFloat = 280
    private var cardHeight: CGFloat { cardWidth * (1962.0 / 1136.0) }
    
    // Test with "frisk" (healthy) role
    private let testRole: PlayerRole = .frisk
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                BackButton(title: "Return", action: onBack)
                Spacer()
                
                // Reset button
                if isFlipped {
                    Button(action: {
                        SoundManager.shared.playClick()
                        withAnimation(.easeInOut(duration: 0.4)) {
                            isFlipped = false
                            showButton = false
                        }
                    }) {
                        Text("Reset")
                            .font(AppFonts.bodyMedium())
                            .foregroundColor(AppColors.coralRed)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            
            Spacer()
            
            // Title
            if !isFlipped {
                VStack(spacing: 12) {
                    OrnamentDivider(width: 180, color: AppColors.warmBrown)
                    
                    Text("Tap to Reveal Thy Fate")
                        .font(AppFonts.headingLarge())
                        .tracking(1)
                        .foregroundColor(AppColors.inkDark)
                    
                    OrnamentDivider(width: 180, color: AppColors.warmBrown)
                }
                .transition(.opacity)
            }
            
            Spacer()
                .frame(height: 30)
                
                // Card deck and flippable card
                ZStack {
                    // Deck underneath (stacked cards)
                    DemoCardDeck(cardWidth: cardWidth, cardHeight: cardHeight, cardCount: 5)
                        .offset(y: 16)
                    
                    // Flippable top card
                    DemoFlippableCard(
                        role: testRole,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        isFlipped: $isFlipped
                    )
                    .onTapGesture {
                        if !isFlipped {
                            // Play card flip sound
                            SoundManager.shared.playCardFlip()
                            
                            withAnimation(.easeInOut(duration: 0.6)) {
                                isFlipped = true
                            }
                            // Show button after flip
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showButton = true
                                }
                            }
                        }
                    }
                }
                .frame(width: cardWidth, height: cardHeight + 20)
                
                Spacer()
                
            // Continue button (appears after flip)
            if showButton {
                Button(action: {
                    SoundManager.shared.playClick()
                    // Would continue to next player or game phase
                    print("Continue tapped")
                }) {
                    Text("I UNDERSTAND")
                }
                .buttonStyle(.primary)
                .frame(width: 220)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            Spacer()
                .frame(height: 40)
        }
    }
}

// MARK: - Demo Card Deck

struct DemoCardDeck: View {
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let cardCount: Int
    
    var body: some View {
        ZStack {
            ForEach(0..<cardCount, id: \.self) { index in
                DemoCardBack(width: cardWidth, height: cardHeight)
                    .offset(y: CGFloat(cardCount - 1 - index) * 3)
            }
        }
    }
}

// MARK: - Demo Card Back

struct DemoCardBack: View {
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        Image("card-back")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
}

// MARK: - Demo Card Front (with text inside)

struct DemoCardFront: View {
    let role: PlayerRole
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        ZStack {
            // Card frame background
            Image("card-frame")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
            
            // Content inside card
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: height * 0.08)
                
                // Role icon
                Image(role.cardImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: width * 0.45)
                
                Spacer()
                    .frame(height: height * 0.03)
                
                // Role name
                Text(role.displayName)
                    .font(.custom("Georgia-Bold", size: width * 0.08))
                    .tracking(2)
                    .foregroundColor(AppColors.inkDark)
                
                Spacer()
                    .frame(height: height * 0.04)
                
                // Divider
                Rectangle()
                    .fill(AppColors.inkLight.opacity(0.2))
                    .frame(width: width * 0.5, height: 1)
                
                Spacer()
                    .frame(height: height * 0.03)
                
                // Role description text INSIDE the card
                VStack(spacing: 4) {
                    Text(roleTitle(for: role))
                        .font(.custom("Georgia-Italic", size: width * 0.055))
                        .foregroundColor(AppColors.inkDark)
                    
                    Text(roleSubtitle(for: role))
                        .font(.custom("Georgia", size: width * 0.045))
                        .foregroundColor(AppColors.inkLight)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, width * 0.1)
                
                Spacer()
                    .frame(height: height * 0.08)
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .clipped()
    }
    
    private func roleTitle(for role: PlayerRole) -> String {
        switch role {
        case .frisk: return "You are healthy."
        case .smittobarare: return "You are the Carrier."
        case .infekterad: return "You are infected."
        }
    }
    
    private func roleSubtitle(for role: PlayerRole) -> String {
        switch role {
        case .frisk: return "Find the Carrier."
        case .smittobarare: return "Infect them all."
        case .infekterad: return "Seek a cure."
        }
    }
}

// MARK: - Demo Flippable Card

struct DemoFlippableCard: View {
    let role: PlayerRole
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    @Binding var isFlipped: Bool
    
    var body: some View {
        ZStack {
            // Back of card
            DemoCardBack(width: cardWidth, height: cardHeight)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .opacity(isFlipped ? 0 : 1)
            
            // Front of card
            DemoCardFront(role: role, width: cardWidth, height: cardHeight)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .opacity(isFlipped ? 1 : 0)
        }
        .frame(width: cardWidth, height: cardHeight)
        .shadow(color: .black.opacity(isFlipped ? 0.3 : 0.2), radius: isFlipped ? 12 : 6, y: isFlipped ? 8 : 4)
    }
}

// MARK: - Rule Section

struct RuleSection: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number - Roman numeral style
            VStack {
                Text(romanNumeral(for: number))
                    .font(.custom("Georgia-Bold", size: 22))
                    .foregroundColor(AppColors.royalBlue)
                
                Rectangle()
                    .fill(AppColors.royalBlue.opacity(0.3))
                    .frame(width: 1, height: 40)
            }
            .frame(width: 36)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.custom("Georgia-Bold", size: 18))
                    .foregroundColor(AppColors.inkDark)
                
                Text(description)
                    .font(.custom("Georgia", size: 15))
                    .foregroundColor(AppColors.inkMedium)
                    .lineSpacing(5)
            }
        }
    }
    
    private func romanNumeral(for number: String) -> String {
        switch number {
        case "1": return "I"
        case "2": return "II"
        case "3": return "III"
        case "4": return "IV"
        case "5": return "V"
        default: return number
        }
    }
}

// MARK: - Medieval Button Style

enum MedievalButtonStyle {
    case primary
    case secondary
    case tertiary
}

struct MedievalButton: View {
    let text: String
    let style: MedievalButtonStyle
    
    var body: some View {
        ZStack {
            switch style {
            case .primary:
                // Primary: Banner-like with decorative ends
                ZStack {
                    // Main banner shape
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.burntOrange)
                        .frame(height: 52)
                    
                    // Inner border
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(AppColors.warmGold.opacity(0.5), lineWidth: 1)
                        .padding(3)
                        .frame(height: 52)
                    
                    // Banner text
                    Text(text.uppercased())
                        .font(.custom("Georgia-Bold", size: 17))
                        .tracking(3)
                        .foregroundColor(.white)
                }
                .shadow(color: AppColors.burntOrange.opacity(0.4), radius: 8, y: 4)
                
            case .secondary:
                // Secondary: Outlined with subtle fill
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.parchmentLight)
                        .frame(height: 46)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppColors.inkDark.opacity(0.4), lineWidth: 1.5)
                        .frame(height: 46)
                    
                    // Corner decorations
                    HStack {
                        CornerOrnament()
                            .frame(width: 8, height: 8)
                        Spacer()
                        CornerOrnament()
                            .frame(width: 8, height: 8)
                            .rotationEffect(.degrees(90))
                    }
                    .padding(.horizontal, 8)
                    
                    Text(text)
                        .font(.custom("Georgia", size: 15))
                        .tracking(1)
                        .foregroundColor(AppColors.inkDark)
                }
                
            case .tertiary:
                // Tertiary: Minimal, text-like
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(AppColors.inkLight.opacity(0.3))
                        .frame(width: 12, height: 1)
                    
                    Text(text)
                        .font(.custom("Georgia-Italic", size: 15))
                        .foregroundColor(AppColors.inkLight)
                    
                    Rectangle()
                        .fill(AppColors.inkLight.opacity(0.3))
                        .frame(width: 12, height: 1)
                }
                .frame(height: 44)
            }
        }
    }
}

// MARK: - Decorative Elements

struct OrnamentLine: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.warmBrown.opacity(0.5))
            .frame(height: 1)
    }
}

struct OrnamentDiamond: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.warmBrown.opacity(0.7))
            .frame(width: 5, height: 5)
            .rotationEffect(.degrees(45))
    }
}

struct CornerOrnament: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 8, y: 0))
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 8))
        }
        .stroke(AppColors.warmGold.opacity(0.6), lineWidth: 1.5)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
