//
//  ContentView.swift
//  Toxic Tom
//
//  Created by Elliot Berentsen on 2026-01-18.
//

import SwiftUI

// MARK: - Theme Colors (Your Palette)

struct AppColors {
    // Background - soft antique paper (not too saturated)
    static let parchment = Color(hex: "f2ebe0")           // Light antique paper - main background
    
    // Primary palette from your selection
    static let warmGold = Color(hex: "e4be83")            // Accent, decorative elements
    static let burntOrange = Color(hex: "c36439")         // Primary buttons
    static let terracotta = Color(hex: "c96b40")          // Secondary/hover
    static let deepBlue = Color(hex: "3959a2")            // Accent/links
    static let oliveGreen = Color(hex: "97b048")          // Success states
    
    // Derived colors
    static let inkDark = Color(hex: "2a1f14")             // Dark text
    static let inkLight = Color(hex: "5c4a3a")            // Light text
    static let parchmentLight = Color(hex: "faf7f2")      // Lighter areas
    static let parchmentDark = Color(hex: "e5dcd0")       // Subtle borders/dividers
}

// Helper extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

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
    case rules
    case diceSimulator
}

// MARK: - Content View

struct ContentView: View {
    @State private var currentView: AppView = .home
    @State private var selectedCharacter: GameCharacter? = nil
    @State private var diceResult: Int? = nil
    @State private var showDiceResult = false
    
    let characters: [GameCharacter] = [
        GameCharacter(name: "The Monk", cardImage: "man-60", description: "A humble servant of faith"),
        GameCharacter(name: "The Maiden", cardImage: "kvinna-30", description: "A woman of mystery")
    ]
    
    var body: some View {
        ZStack {
            // Background
            AppColors.parchment
                .ignoresSafeArea()
            
            switch currentView {
            case .home:
                homeView
            case .characterSelect:
                characterSelectView
            case .rules:
                rulesView
            case .diceSimulator:
                diceSimulatorView
            }
        }
    }
    
    // MARK: - Home View
    
    private var homeView: some View {
        ZStack {
            // Subtle texture overlay
            VStack(spacing: 0) {
                ForEach(0..<20) { _ in
                    HStack(spacing: 0) {
                        ForEach(0..<10) { _ in
                            Rectangle()
                                .fill(AppColors.inkDark.opacity(Double.random(in: 0.01...0.03)))
                                .frame(width: 40, height: 40)
                        }
                    }
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 100)
                
                // Title Section - More ornate
                VStack(spacing: 16) {
                    // Decorative top flourish
                    HStack(spacing: 8) {
                        OrnamentLine()
                        OrnamentDiamond()
                        OrnamentLine()
                    }
                    .frame(width: 200)
                    
                    // Game Title - Larger, more dramatic
                    VStack(spacing: 4) {
                        Text("SMITTOBÄRAREN")
                            .font(.custom("Georgia-Bold", size: 34))
                            .tracking(3)
                            .foregroundColor(AppColors.inkDark)
                        
                        Text("— The Carrier —")
                            .font(.custom("Georgia-Italic", size: 15))
                            .foregroundColor(AppColors.inkLight)
                    }
                    
                    // Decorative bottom flourish
                    HStack(spacing: 8) {
                        OrnamentLine()
                        OrnamentDiamond()
                        OrnamentLine()
                    }
                    .frame(width: 200)
                }
                
                Spacer()
                
                // Center emblem area - placeholder for your logo
                ZStack {
                    // Outer decorative ring
                    Circle()
                        .stroke(AppColors.inkLight.opacity(0.2), lineWidth: 2)
                        .frame(width: 160, height: 160)
                    
                    // Inner decorative ring with dashes
                    Circle()
                        .stroke(AppColors.inkLight.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .frame(width: 130, height: 130)
                    
                    // Center cross emblem
                    VStack(spacing: 4) {
                        Image(systemName: "cross.fill")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(AppColors.inkLight.opacity(0.4))
                        
                        Text("ANNO")
                            .font(.custom("Georgia", size: 10))
                            .tracking(2)
                            .foregroundColor(AppColors.inkLight.opacity(0.3))
                        Text("MMXXVI")
                            .font(.custom("Georgia", size: 12))
                            .tracking(1)
                            .foregroundColor(AppColors.inkLight.opacity(0.3))
                    }
                }
                
                Spacer()
                
                // Buttons Section - Medieval styled
                VStack(spacing: 14) {
                    // PRIMARY: Start Game - Banner style
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .characterSelect
                        }
                    }) {
                        MedievalButton(
                            text: "BEGIN JOURNEY",
                            style: .primary
                        )
                    }
                    
                    // SECONDARY: How to Play
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .rules
                        }
                    }) {
                        MedievalButton(
                            text: "Rules of Play",
                            style: .secondary
                        )
                    }
                    
                    // TERTIARY: Dice Simulator
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .diceSimulator
                        }
                    }) {
                        MedievalButton(
                            text: "Test the Dice",
                            style: .tertiary
                        )
                    }
                }
                .padding(.horizontal, 50)
                
                Spacer()
                    .frame(height: 30)
                
                // Version - styled
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(AppColors.inkLight.opacity(0.2))
                        .frame(width: 20, height: 1)
                    Text("Version 0.1")
                        .font(.custom("Georgia", size: 10))
                        .foregroundColor(AppColors.inkLight.opacity(0.4))
                    Rectangle()
                        .fill(AppColors.inkLight.opacity(0.2))
                        .frame(width: 20, height: 1)
                }
                .padding(.bottom, 30)
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
            
            // Character Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(characters) { character in
                        CharacterCard(
                            character: character,
                            isSelected: selectedCharacter == character
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                selectedCharacter = selectedCharacter == character ? nil : character
                            }
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 10)
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
        VStack(spacing: 0) {
            // Header
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
    
    private let cardWidth: CGFloat = 140
    private var cardHeight: CGFloat { cardWidth * 1.5 }
    
    var body: some View {
        ZStack {
            Image(character.cardImage)
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: cardWidth, height: cardHeight)
            
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.burntOrange, lineWidth: 4)
                    .frame(width: cardWidth, height: cardHeight)
                
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.burntOrange)
                            .background(Circle().fill(.white).frame(width: 20, height: 20))
                            .offset(x: 8, y: -8)
                    }
                    Spacer()
                }
                .frame(width: cardWidth, height: cardHeight)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(
            color: isSelected ? AppColors.burntOrange.opacity(0.3) : Color.black.opacity(0.15),
            radius: isSelected ? 12 : 4,
            y: isSelected ? 0 : 2
        )
        .scaleEffect(isSelected ? 1.08 : 1.0)
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
                    .foregroundColor(AppColors.burntOrange)
                
                Rectangle()
                    .fill(AppColors.burntOrange.opacity(0.3))
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
                    .foregroundColor(AppColors.inkLight)
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

// MARK: - Preview

#Preview {
    ContentView()
}
