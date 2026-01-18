//
//  ContentView.swift
//  Toxic Tom
//
//  Created by Elliot Berentsen on 2026-01-18.
//

import SwiftUI

struct ContentView: View {
    @State private var shouldRoll = false
    @State private var isRolling = false
    @State private var diceResult: Int? = nil
    
    var body: some View {
        ZStack {
            // Background - deep dark
            Color(red: 0.06, green: 0.06, blue: 0.08)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Title
                Text("DICE PROTOTYPE")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                    .padding(.top, 20)
                
                // 3D Dice Scene
                DiceSceneView(
                    shouldRoll: $shouldRoll,
                    isRolling: $isRolling,
                    result: $diceResult
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Result display
                VStack(spacing: 16) {
                    if let result = diceResult {
                        Text("Result")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                        
                        Text("\(result)")
                            .font(.system(size: 72, weight: .light, design: .serif))
                            .foregroundColor(Color(red: 0.95, green: 0.93, blue: 0.88))
                            .animation(.easeOut(duration: 0.3), value: result)
                    } else {
                        Text("Tap to roll")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                    }
                }
                .frame(height: 120)
                
                // Roll button
                Button(action: {
                    if !isRolling {
                        diceResult = nil
                        shouldRoll = true
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                isRolling
                                    ? Color(red: 0.2, green: 0.2, blue: 0.22)
                                    : Color(red: 0.95, green: 0.93, blue: 0.88)
                            )
                            .frame(height: 56)
                        
                        HStack(spacing: 12) {
                            if isRolling {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.6, green: 0.6, blue: 0.65)))
                                    .scaleEffect(0.9)
                                
                                Text("ROLLING...")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .tracking(2)
                                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.65))
                            } else {
                                Image(systemName: "dice.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                                
                                Text("ROLL DICE")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .tracking(2)
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.12))
                            }
                        }
                    }
                }
                .disabled(isRolling)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    ContentView()
}
