//
//  SettingsView.swift
//  Toxic Tom
//
//  Created by Elliot Berentsen on 2026-01-19.
//

import SwiftUI

struct SettingsView: View {
    let onBack: () -> Void
    
    @ObservedObject private var soundManager = SoundManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                BackButton(title: "Return", action: onBack)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            
            // Title
            VStack(spacing: 12) {
                OrnamentDivider(width: 140, color: AppColors.warmBrown)
                
                Text("Settings")
                    .font(AppFonts.displayMedium())
                    .tracking(1)
                    .foregroundColor(AppColors.inkDark)
                
                OrnamentDivider(width: 140, color: AppColors.warmBrown)
            }
            .padding(.top, 20)
            
            Spacer()
                .frame(height: 50)
                
                // Settings content
                VStack(spacing: 32) {
                    // Music Section
                    AudioSettingSection(
                        title: "Background Music",
                        icon: "music.note",
                        isEnabled: $soundManager.musicEnabled,
                        volume: Binding(
                            get: { Double(soundManager.musicVolume) },
                            set: { soundManager.musicVolume = Float($0) }
                        )
                    )
                    
                    // Divider
                    Rectangle()
                        .fill(AppColors.warmBrown.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                    
                    // Sound Effects Section
                    AudioSettingSection(
                        title: "Sound Effects",
                        icon: "speaker.wave.2",
                        isEnabled: $soundManager.soundEffectsEnabled,
                        volume: Binding(
                            get: { Double(soundManager.effectsVolume) },
                            set: { soundManager.effectsVolume = Float($0) }
                        ),
                        onTestSound: {
                            soundManager.playCardFlip()
                        }
                    )
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Version info
                Text("Version 0.1")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.inkMedium.opacity(0.5))
                .padding(.bottom, 40)
            }
        .texturedBackground()
    }
}

// MARK: - Audio Setting Section

struct AudioSettingSection: View {
    let title: String
    let icon: String
    @Binding var isEnabled: Bool
    @Binding var volume: Double
    var onTestSound: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with toggle
            HStack {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isEnabled ? AppColors.royalBlue : AppColors.inkMedium.opacity(0.4))
                    .frame(width: 28)
                
                // Title
                Text(title)
                    .font(AppFonts.headingMedium())
                    .foregroundColor(AppColors.inkDark)
                
                Spacer()
                
                // Toggle
                Toggle("", isOn: $isEnabled)
                    .toggleStyle(MedievalToggleStyle())
            }
            
            // Volume slider (only shown when enabled)
            if isEnabled {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.inkMedium.opacity(0.6))
                        
                        // Custom slider
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Track background
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.warmBrown.opacity(0.2))
                                    .frame(height: 8)
                                
                                // Filled track
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.royalBlue)
                                    .frame(width: geometry.size.width * volume, height: 8)
                                
                                // Thumb
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                                    .overlay(
                                        Circle()
                                            .stroke(AppColors.royalBlue, lineWidth: 2)
                                    )
                                    .offset(x: (geometry.size.width - 24) * volume)
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let newValue = min(max(value.location.x / geometry.size.width, 0), 1)
                                        volume = newValue
                                    }
                            )
                        }
                        .frame(height: 24)
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.inkMedium.opacity(0.6))
                    }
                    
                    // Test button for sound effects
                    if let testSound = onTestSound {
                        Button(action: testSound) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                                Text("Test Sound")
                                    .font(AppFonts.bodySmall())
                            }
                            .foregroundColor(AppColors.royalBlue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .stroke(AppColors.royalBlue, lineWidth: 1)
                            )
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.leading, 36)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - Medieval Toggle Style

struct MedievalToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            ZStack {
                // Track
                RoundedRectangle(cornerRadius: 12)
                    .fill(configuration.isOn ? AppColors.royalBlue : AppColors.warmBrown.opacity(0.3))
                    .frame(width: 50, height: 28)
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .offset(x: configuration.isOn ? 11 : -11)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

#Preview {
    SettingsView(onBack: {})
}
