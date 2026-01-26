//
//  DesignSystem.swift
//  Toxic Tom
//
//  Created by Elliot Berentsen on 2026-01-19.
//
//  Comprehensive design system for consistent styling across the app.
//  Based on medieval illuminated manuscript aesthetics.
//

import SwiftUI

// MARK: - Color System

/// Clean parchment palette with strategic accent colors
struct AppColors {
    
    // MARK: - Base Colors
    
    /// Parchment background - warm cream
    static let parchment = Color(hex: "F1E9D2")
    
    /// Slightly darker parchment for depth
    static let parchmentDark = Color(hex: "e5d9c0")
    
    // MARK: - Accent Palette
    
    /// Royal blue - primary actions, important buttons
    static let royalBlue = Color(hex: "3b5fad")
    
    /// Olive/chartreuse - success, healthy states
    static let oliveGreen = Color(hex: "aeb64c")
    
    /// Coral red - danger, infected, warnings
    static let coralRed = Color(hex: "e96a5b")
    
    /// Warm brown - borders, secondary elements, earthy accent
    static let warmBrown = Color(hex: "a37456")
    
    // MARK: - Derived Colors
    
    /// Darker brown for text on parchment
    static let inkDark = Color(hex: "3a2e1f")
    
    /// Medium brown for secondary text
    static let inkMedium = Color(hex: "6b5d4d")
    
    /// Light text (for dark backgrounds like blue buttons)
    static let inkLight = Color(hex: "f5f0e6")
    
    // MARK: - Semantic Colors (By Purpose)
    
    /// Main app background
    static let background = parchment
    
    /// Card and container surfaces
    static let surface = parchment
    
    /// Primary action color (buttons)
    static let primary = royalBlue
    
    /// Secondary action color
    static let secondary = warmBrown
    
    /// Accent/highlight color
    static let accent = warmBrown
    
    /// Error/danger states
    static let error = coralRed
    
    /// Success states
    static let success = oliveGreen
    
    /// Warning states
    static let warning = Color(hex: "d4a84b")
    
    // MARK: - Text Colors
    
    /// Dark text for light backgrounds (ink on parchment)
    static let textOnLight = inkDark
    
    /// Light text for dark backgrounds
    static let textOnDark = inkLight
    
    /// Muted text for secondary information
    static let textMuted = inkMedium
    
    /// Text on primary buttons (white on blue)
    static let textOnPrimary = inkLight
    
    // MARK: - Game-Specific Colors
    
    /// Healthy player state
    static let healthy = oliveGreen
    
    /// Carrier state (secret infected)
    static let carrier = coralRed
    
    /// Infected state
    static let infected = Color(hex: "c45449")
    
    // MARK: - Legacy Aliases (backwards compatibility)
    
    static let cream = parchment
    static let agedParchment = parchmentDark
    static let warmGold = warmBrown
    static let amber = royalBlue // Primary action now blue
    static let ochreGold = warmBrown
    static let burntOrange = coralRed
    static let woodDark = Color(hex: "3a2e1f")
    static let woodMedium = warmBrown
    static let forestGreen = oliveGreen
    static let crimson = coralRed
    static let bloodRed = coralRed
    static let darkRed = coralRed
    static let parchmentLight = parchment
    static let terracotta = warmBrown
}

// MARK: - Spacing System

/// Consistent spacing scale (based on 4pt grid)
struct AppSpacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius

/// Consistent corner radius scale
struct AppRadius {
    /// Small elements: tags, badges
    static let sm: CGFloat = 4
    
    /// Medium elements: buttons, inputs
    static let md: CGFloat = 8
    
    /// Large elements: cards, modals
    static let lg: CGFloat = 12
    
    /// Extra large: major containers
    static let xl: CGFloat = 16
    
    /// Full rounding: pills, circular buttons
    static let full: CGFloat = 999
}

// MARK: - Typography

/// Font styles for the app
struct AppFonts {
    // Display/Title fonts
    static func displayLarge() -> Font {
        .custom("Georgia-Bold", size: 34)
    }
    
    static func displayMedium() -> Font {
        .custom("Georgia-Bold", size: 28)
    }
    
    static func displaySmall() -> Font {
        .custom("Georgia-Bold", size: 24)
    }
    
    // Heading fonts
    static func headingLarge() -> Font {
        .custom("Georgia-Bold", size: 20)
    }
    
    static func headingMedium() -> Font {
        .custom("Georgia-Bold", size: 18)
    }
    
    static func headingSmall() -> Font {
        .custom("Georgia-Bold", size: 16)
    }
    
    // Body fonts
    static func bodyLarge() -> Font {
        .custom("Georgia", size: 16)
    }
    
    static func bodyMedium() -> Font {
        .custom("Georgia", size: 14)
    }
    
    static func bodySmall() -> Font {
        .custom("Georgia", size: 12)
    }
    
    // Caption/Label fonts
    static func caption() -> Font {
        .custom("Georgia", size: 11)
    }
    
    static func label() -> Font {
        .custom("Georgia-Bold", size: 12)
    }
    
    // Italic variants
    static func bodyItalic() -> Font {
        .custom("Georgia-Italic", size: 14)
    }
}

// MARK: - Shadows

/// Consistent shadow styles
struct AppShadows {
    /// Subtle shadow for flat elements
    static let subtle = Shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    
    /// Medium shadow for cards
    static let card = Shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    
    /// Strong shadow for elevated elements
    static let elevated = Shadow(color: .black.opacity(0.25), radius: 16, y: 8)
    
    /// Glow effect for selected items
    static let glow = Shadow(color: AppColors.ochreGold.opacity(0.6), radius: 12, y: 0)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}

// MARK: - Background View Modifier

/// Clean parchment background with subtle texture
struct TexturedBackground: ViewModifier {
    var showTexture: Bool = true
    var showVignette: Bool = true
    
    func body(content: Content) -> some View {
        ZStack {
            // Base parchment color
            AppColors.parchment
                .ignoresSafeArea()
            
            // Subtle egg-shell texture (tiled)
            if showTexture {
                Image("egg-shell")
                    .resizable(resizingMode: .tile)
                    .opacity(0.5)
                    .ignoresSafeArea()
            }
            
            // Very subtle vignette for depth
            if showVignette {
                RadialGradient(
                    colors: [
                        .clear,
                        AppColors.inkDark.opacity(0.08)
                    ],
                    center: .center,
                    startRadius: UIScreen.main.bounds.height * 0.3,
                    endRadius: UIScreen.main.bounds.height * 0.7
                )
                .ignoresSafeArea()
            }
            
            content
        }
    }
}

extension View {
    /// Apply the standard parchment textured background
    func texturedBackground(
        showTexture: Bool = true,
        showVignette: Bool = true
    ) -> some View {
        modifier(TexturedBackground(
            showTexture: showTexture,
            showVignette: showVignette
        ))
    }
    
    /// Apply plain parchment background (no texture)
    func parchmentBackground() -> some View {
        self.background(AppColors.parchment.ignoresSafeArea())
    }
}

// MARK: - Button Styles

/// Primary button style (royal blue, clean and bold)
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.headingSmall())
            .foregroundColor(AppColors.textOnPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(configuration.isPressed ? AppColors.royalBlue.opacity(0.85) : AppColors.royalBlue)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(
                color: AppColors.royalBlue.opacity(0.3),
                radius: configuration.isPressed ? 2 : 6,
                y: configuration.isPressed ? 1 : 3
            )
    }
}

/// Secondary button style (warm brown, earthy)
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.bodyMedium())
            .foregroundColor(AppColors.textOnPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(configuration.isPressed ? AppColors.warmBrown.opacity(0.85) : AppColors.warmBrown)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(
                color: AppColors.warmBrown.opacity(0.25),
                radius: 4,
                y: 2
            )
    }
}

/// Tertiary button style (outlined, subtle)
struct TertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.bodyItalic())
            .foregroundColor(AppColors.inkMedium)
            .frame(height: 44)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == TertiaryButtonStyle {
    static var tertiary: TertiaryButtonStyle { TertiaryButtonStyle() }
}

// MARK: - Decorative Elements

/// Ornamental divider line with warm brown color
struct OrnamentDivider: View {
    var width: CGFloat = 160
    var color: Color = AppColors.warmBrown
    
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color.opacity(0.5))
                .frame(height: 1)
            
            Rectangle()
                .fill(color.opacity(0.7))
                .frame(width: 5, height: 5)
                .rotationEffect(.degrees(45))
            
            Rectangle()
                .fill(color.opacity(0.5))
                .frame(height: 1)
        }
        .frame(width: width)
    }
}

/// Back button for navigation
struct BackButton: View {
    let title: String
    let action: () -> Void
    var color: Color = AppColors.inkMedium
    
    var body: some View {
        Button(action: {
            SoundManager.shared.playClick()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 12))
                Text(title)
                    .font(AppFonts.bodyMedium())
            }
            .foregroundColor(color)
        }
    }
}

// MARK: - Color Extension (Hex Support)

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
