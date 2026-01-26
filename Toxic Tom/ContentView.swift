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
    case localGame         // Local hotseat game
    case onlineGame        // Online multiplayer game
    case designMode        // Design mode for testing
    case characterSelect
    case rules
    case diceSimulator
    case cardFlipTest
}

// MARK: - Content View

struct ContentView: View {
    @State private var currentView: AppView = .home
    @State private var selectedCharacter: GameCharacter? = nil
    @State private var diceResult: Int? = nil
    @State private var showDiceResult = false
    @State private var showSettings = false
    
    let characters: [GameCharacter] = [
        // Royalty
        GameCharacter(name: "Kungen", cardImage: "king", description: "Rikets högste härskare"),
        GameCharacter(name: "Drottningen", cardImage: "queen", description: "Av kungligt blod"),
        GameCharacter(name: "Adelsmannen", cardImage: "noble-man", description: "En man av börd"),
        
        // Clergy & Officials
        GameCharacter(name: "Biskopen", cardImage: "bishop", description: "Kyrkans röst"),
        GameCharacter(name: "Domaren", cardImage: "judge", description: "Rättvisans hand"),
        GameCharacter(name: "Riddaren", cardImage: "knight", description: "Svärd och ära"),
        
        // Working Folk
        GameCharacter(name: "Hantverkaren", cardImage: "craftsman", description: "Stadens smed"),
        GameCharacter(name: "Ynglingen", cardImage: "young-man", description: "En ung man"),
        
        // Women
        GameCharacter(name: "Helena", cardImage: "25-women", description: "Bryggarens dotter"),
        GameCharacter(name: "Margareta", cardImage: "women-35", description: "Handelskvinnan"),
        GameCharacter(name: "Birgitta", cardImage: "women-70", description: "Byns kloka kvinna"),
        GameCharacter(name: "Nunnan", cardImage: "women-monk", description: "Klostrets syster"),
        GameCharacter(name: "Spelkvinnan", cardImage: "women-musician", description: "Gatans musikant"),
        
        // Youth
        GameCharacter(name: "Flickan", cardImage: "15-girl", description: "Ung och nyfiken")
    ]
    
    var body: some View {
        ZStack {
            // Background
            AppColors.parchment
                .ignoresSafeArea()
            
            switch currentView {
            case .home:
                homeView
            case .localGame:
                LocalGameView(onExit: {
                    GameManager.shared.resetAll()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentView = .home
                    }
                })
            case .onlineGame:
                OnlineGameView(onExit: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentView = .home
                    }
                })
            case .designMode:
                DesignModeGameView(onExit: {
                    DesignModeManager.shared.reset()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentView = .home
                    }
                })
            case .characterSelect:
                characterSelectView
            case .rules:
                rulesView
            case .diceSimulator:
                diceSimulatorView
            case .cardFlipTest:
                cardFlipTestView
            }
        }
        .onAppear {
            // Start background music when app appears
            SoundManager.shared.playMusic()
        }
    }
    
    // MARK: - Home View
    
    private var homeView: some View {
        ZStack {
            // Tiled background texture - full screen
            Image("egg-shell")
                .resizable(resizingMode: .tile)
                .ignoresSafeArea()
            
            // Floating dust particles
            DustParticlesView()
                .ignoresSafeArea()
            
            // Settings gear - top right with subtle background
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        SoundManager.shared.playClick()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSettings.toggle()
                        }
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.inkDark.opacity(0.5))
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(AppColors.inkDark.opacity(0.08))
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                Spacer()
            }
            
            // Main content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 80)
                
                // Logo
                Image("icon-colored")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150)
                
                Spacer()
                
                // Menu
                VStack(spacing: 24) {
                    Button(action: { 
                        SoundManager.shared.playClick()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .onlineGame
                        }
                    }) {
                        Text("Play")
                            .font(.custom("Georgia-Bold", size: 28))
                            .foregroundColor(AppColors.inkDark)
                    }
                    
                    VStack(spacing: 20) {
                        Button(action: { 
                            SoundManager.shared.playClick()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentView = .rules
                            }
                        }) {
                            Text("How to Play")
                                .font(.custom("Georgia", size: 18))
                                .foregroundColor(AppColors.inkDark.opacity(0.7))
                        }
                        
                        Button(action: { 
                            SoundManager.shared.playClick()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentView = .cardFlipTest
                            }
                        }) {
                            Text("Card Flip Test")
                                .font(.custom("Georgia", size: 18))
                                .foregroundColor(AppColors.inkDark.opacity(0.7))
                        }
                        
                        Button(action: { 
                            SoundManager.shared.playClick()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentView = .diceSimulator
                            }
                        }) {
                            Text("Dice Simulator")
                                .font(.custom("Georgia", size: 18))
                                .foregroundColor(AppColors.inkDark.opacity(0.7))
                        }
                        
                        Button(action: { 
                            SoundManager.shared.playClick()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentView = .designMode
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "hammer.fill")
                                    .font(.system(size: 12))
                                Text("Design Mode")
                                    .font(.custom("Georgia", size: 18))
                            }
                            .foregroundColor(.orange.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
            }
            
            // Figures image pinned to bottom
            VStack {
                Spacer()
                Image("figures-wide-image")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            .ignoresSafeArea(edges: .bottom)
            
            // Settings overlay
            if showSettings {
                SettingsOverlay(isShowing: $showSettings)
            }
        }
    }
    
    // MARK: - Character Select View
    
    private var characterSelectView: some View {
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
            .padding(.bottom, 30)
            
            // Character Cards - 16 total with medieval woodcut style
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(characters) { character in
                        CharacterCard(
                            character: character,
                            isSelected: selectedCharacter == character
                        )
                        .onTapGesture {
                            SoundManager.shared.playClick()
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                selectedCharacter = selectedCharacter == character ? nil : character
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            
            // Selected info
            VStack(spacing: 8) {
                if let selected = selectedCharacter {
                    Text(selected.name.uppercased())
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(AppColors.inkDark)
                    
                    Text(selected.description)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundColor(AppColors.inkLight)
                        .italic()
                } else {
                    Text("Tap a character to select")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.inkLight.opacity(0.6))
                }
            }
            .frame(height: 60)
            .padding(.top, 24)
            
            Spacer()
            
            // Confirm button
            if selectedCharacter != nil {
                Button(action: {
                    // TODO: Start game with selected character
                }) {
                    MedievalButton(text: "Confirm Selection", style: .primary)
                }
                .frame(width: 220)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .padding(.bottom, 50)
            } else {
                Spacer()
                    .frame(height: 100)
            }
        }
    }
    
    // MARK: - Rules View
    
    private var rulesView: some View {
        ZStack {
            // Tiled background texture - matching home screen
            Image("egg-shell")
                .resizable(resizingMode: .tile)
                .ignoresSafeArea()
            
            // Floating dust particles
            DustParticlesView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar - matching app style
                HStack {
                    Button(action: {
                        SoundManager.shared.playClick()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .home
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .medium))
                            Text("Return")
                                .font(.custom("Georgia", size: 14))
                        }
                        .foregroundColor(AppColors.inkDark.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppColors.inkDark.opacity(0.06))
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Title - simple, matching home aesthetic
                Text("Rules of Play")
                    .font(.custom("Georgia-Bold", size: 26))
                    .foregroundColor(AppColors.inkDark)
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                
                // Rules content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
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
                    .padding(.horizontal, 28)
                    .padding(.top, 10)
                    .padding(.bottom, 50)
                }
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
                // Top bar - matching app style
                HStack {
                    // Back button with subtle background
                    Button(action: {
                        SoundManager.shared.playClick()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .home
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .medium))
                            Text("Return")
                                .font(.custom("Georgia", size: 14))
                        }
                        .foregroundColor(AppColors.parchment.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppColors.parchment.opacity(0.12))
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Result display - medieval parchment style
                if showDiceResult, let result = diceResult {
                    VStack(spacing: 6) {
                        Text(resultLabel(for: result))
                            .font(.custom("Georgia", size: 12))
                            .tracking(2)
                            .foregroundColor(AppColors.parchment.opacity(0.5))
                        
                        Text("\(result)")
                            .font(.custom("Georgia-Bold", size: 64))
                            .foregroundColor(resultColor(for: result))
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "1a1510").opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppColors.parchment.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
                
                Spacer()
                    .frame(height: 60)
                
                // Instruction text - Georgia italic
                if !showDiceResult {
                    Text("Tap anywhere to roll")
                        .font(.custom("Georgia-Italic", size: 14))
                        .foregroundColor(AppColors.parchment.opacity(0.4))
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
    
    @State private var isPressed = false
    
    private let cardSize: CGFloat = 130
    
    var body: some View {
        Image(character.cardImage)
            .resizable()
            .scaledToFit()
            .frame(width: cardSize, height: cardSize)
            // Zoom effect for selection
            .scaleEffect(isSelected ? 1.1 : (isPressed ? 0.95 : 1.0))
            .shadow(
                color: Color.black.opacity(isSelected ? 0.25 : 0.15),
                radius: isSelected ? 10 : 4,
                y: isSelected ? 5 : 3
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

// MARK: - Rule Section

struct RuleSection: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Number - Roman numeral style
            Text(romanNumeral(for: number))
                .font(.custom("Georgia-Bold", size: 20))
                .foregroundColor(AppColors.inkDark.opacity(0.4))
                .frame(width: 32, alignment: .trailing)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.custom("Georgia-Bold", size: 17))
                    .foregroundColor(AppColors.inkDark)
                
                Text(description)
                    .font(.custom("Georgia", size: 15))
                    .foregroundColor(AppColors.inkDark.opacity(0.6))
                    .lineSpacing(4)
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
            .fill(AppColors.inkLight.opacity(0.3))
            .frame(height: 1)
    }
}

struct OrnamentDiamond: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.inkLight.opacity(0.4))
            .frame(width: 6, height: 6)
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
        .stroke(AppColors.inkLight.opacity(0.4), lineWidth: 1.5)
    }
}

// MARK: - Settings Overlay

struct SettingsOverlay: View {
    @Binding var isShowing: Bool
    @ObservedObject private var soundManager = SoundManager.shared
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isShowing = false
                    }
                }
            
            // Settings panel
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.custom("Georgia-Bold", size: 24))
                        .foregroundColor(AppColors.inkDark)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isShowing = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.inkDark.opacity(0.6))
                    }
                }
                
                // Music toggle and volume
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: soundManager.musicEnabled ? "music.note" : "music.note.slash")
                            .foregroundColor(AppColors.inkDark.opacity(0.7))
                        Text("Music")
                            .font(.custom("Georgia", size: 16))
                            .foregroundColor(AppColors.inkDark)
                        
                        Spacer()
                        
                        Toggle("", isOn: $soundManager.musicEnabled)
                            .labelsHidden()
                            .tint(AppColors.inkDark.opacity(0.6))
                    }
                    
                    if soundManager.musicEnabled {
                        Slider(value: Binding(
                            get: { Double(soundManager.musicVolume) },
                            set: { soundManager.musicVolume = Float($0) }
                        ), in: 0...1)
                            .tint(AppColors.inkDark.opacity(0.6))
                    }
                }
                
                // Sound effects toggle and volume
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: soundManager.soundEffectsEnabled ? "speaker.wave.2" : "speaker.slash")
                            .foregroundColor(AppColors.inkDark.opacity(0.7))
                        Text("Sound Effects")
                            .font(.custom("Georgia", size: 16))
                            .foregroundColor(AppColors.inkDark)
                        
                        Spacer()
                        
                        Toggle("", isOn: $soundManager.soundEffectsEnabled)
                            .labelsHidden()
                            .tint(AppColors.inkDark.opacity(0.6))
                    }
                    
                    if soundManager.soundEffectsEnabled {
                        Slider(value: Binding(
                            get: { Double(soundManager.effectsVolume) },
                            set: { soundManager.effectsVolume = Float($0) }
                        ), in: 0...1)
                            .tint(AppColors.inkDark.opacity(0.6))
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "f5f0e6"))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            )
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }
}

// MARK: - Dust Particles View

struct DustParticlesView: View {
    @State private var particles: [DustParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(AppColors.inkDark.opacity(particle.opacity))
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .blur(radius: 0.5)
                }
            }
            .onAppear {
                // Create initial particles
                for _ in 0..<15 {
                    particles.append(DustParticle.random(in: geometry.size))
                }
                
                // Animate particles
                animateParticles(in: geometry.size)
            }
        }
    }
    
    private func animateParticles(in size: CGSize) {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            for i in particles.indices {
                // Slow upward drift with slight horizontal movement
                particles[i].position.y -= particles[i].speed
                particles[i].position.x += sin(particles[i].position.y * 0.01) * 0.3
                
                // Reset particle when it goes off screen
                if particles[i].position.y < -20 {
                    particles[i] = DustParticle.random(in: size, startAtBottom: true)
                }
            }
        }
    }
}

struct DustParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
    var speed: CGFloat
    
    static func random(in size: CGSize, startAtBottom: Bool = false) -> DustParticle {
        DustParticle(
            position: CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: startAtBottom ? size.height + 20 : CGFloat.random(in: 0...size.height)
            ),
            size: CGFloat.random(in: 2...4),
            opacity: Double.random(in: 0.08...0.2),
            speed: CGFloat.random(in: 0.15...0.4)
        )
    }
}

// MARK: - Card Flip Demo View

struct CardFlipDemoView: View {
    let onBack: () -> Void
    
    @State private var isFlipped = false
    @State private var showButton = false
    @State private var currentRoleIndex = 0
    
    // Card takes up most of screen - using exact image ratio (805:1172)
    private let cardWidth: CGFloat = 260
    private var cardHeight: CGFloat { cardWidth * (1172.0 / 805.0) }
    
    // Roles to cycle through - first Frisk, then Smittobärare
    private let roles: [PlayerRole] = [.frisk, .smittobarare]
    
    private var currentRole: PlayerRole {
        roles[currentRoleIndex % roles.count]
    }
    
    var body: some View {
        ZStack {
            // Tiled background texture - matching home screen
            Image("egg-shell")
                .resizable(resizingMode: .tile)
                .ignoresSafeArea()
            
            // Floating dust particles - matching home screen
            DustParticlesView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar - matching home style
                HStack {
                    // Back button with subtle background
                    Button(action: {
                        SoundManager.shared.playClick()
                        onBack()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .medium))
                            Text("Return")
                                .font(.custom("Georgia", size: 14))
                        }
                        .foregroundColor(AppColors.inkDark.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppColors.inkDark.opacity(0.06))
                        )
                    }
                    
                    Spacer()
                    
                    // Reset button - advances to next role
                    if isFlipped {
                        Button(action: {
                            SoundManager.shared.playClick()
                            withAnimation(.easeInOut(duration: 0.4)) {
                                isFlipped = false
                                showButton = false
                            }
                            // Advance to next role after card closes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                currentRoleIndex += 1
                            }
                        }) {
                            Text("Reset")
                                .font(.custom("Georgia", size: 14))
                                .foregroundColor(AppColors.inkDark.opacity(0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(AppColors.inkDark.opacity(0.06))
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Title - simpler, matching home aesthetic
                if !isFlipped {
                    Text("Tap to Reveal Thy Fate")
                        .font(.custom("Georgia-Italic", size: 16))
                        .foregroundColor(AppColors.inkDark.opacity(0.6))
                        .transition(.opacity)
                }
                
                Spacer()
                    .frame(height: 24)
                    
                // Card deck and flippable card
                ZStack {
                    // Deck underneath - peek out only at bottom edge
                    DemoCardDeck(cardWidth: cardWidth, cardHeight: cardHeight, cardCount: 5)
                    
                    // Flippable top card - aligned exactly with deck's top card
                    DemoFlippableCard(
                        role: currentRole,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        isFlipped: $isFlipped
                    )
                    .offset(y: -6) // Slight offset up so deck peeks at bottom
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
                .frame(width: cardWidth, height: cardHeight + 12)
                
                Spacer()
                
                // Continue button (appears after flip) - resets and advances to next role
                if showButton {
                    Button(action: {
                        SoundManager.shared.playClick()
                        // Reset card and advance to next role
                        withAnimation(.easeInOut(duration: 0.4)) {
                            isFlipped = false
                            showButton = false
                        }
                        // Advance to next role after card closes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            currentRoleIndex += 1
                        }
                    }) {
                        Text("I Understand")
                            .font(.custom("Georgia-Bold", size: 20))
                            .foregroundColor(AppColors.inkDark)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                Spacer()
                    .frame(height: 50)
            }
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
            // Card front background (parchment)
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
                    .tracking(2)
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

// MARK: - Menu Button

struct MenuButton: View {
    let title: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Georgia", size: 20))
                .foregroundColor(AppColors.inkDark)
                .frame(width: 200)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        // Subtle parchment fill
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.4))
                        
                        // Border
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppColors.inkDark.opacity(0.2), lineWidth: 1)
                    }
                )
                .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
