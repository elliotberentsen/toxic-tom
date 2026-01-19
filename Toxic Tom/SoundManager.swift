//
//  SoundManager.swift
//  Toxic Tom
//
//  Created by Elliot Berentsen on 2026-01-19.
//

import AVFoundation
import SwiftUI
import Combine

/// Manages all audio playback in the app with persistent settings
class SoundManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SoundManager()
    
    // MARK: - Audio Players
    
    private var effectPlayer: AVAudioPlayer?
    private var musicPlayer: AVAudioPlayer?
    private var soundCache: [String: AVAudioPlayer] = [:]
    
    // MARK: - Published Settings (for SwiftUI binding)
    
    /// Whether sound effects are enabled
    @Published var soundEffectsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEffectsEnabled, forKey: "soundEffectsEnabled")
        }
    }
    
    /// Whether background music is enabled
    @Published var musicEnabled: Bool {
        didSet {
            UserDefaults.standard.set(musicEnabled, forKey: "musicEnabled")
            if musicEnabled {
                resumeMusic()
            } else {
                pauseMusic()
            }
        }
    }
    
    /// Volume for sound effects (0.0 to 1.0)
    @Published var effectsVolume: Float {
        didSet {
            UserDefaults.standard.set(effectsVolume, forKey: "effectsVolume")
            // Update cached players
            for (_, player) in soundCache {
                player.volume = effectsVolume
            }
        }
    }
    
    /// Volume for background music (0.0 to 1.0)
    @Published var musicVolume: Float {
        didSet {
            UserDefaults.standard.set(musicVolume, forKey: "musicVolume")
            musicPlayer?.volume = musicVolume
        }
    }
    
    // MARK: - File Names
    
    private let backgroundMusicFile = "celtic-background-music"
    private let cardFlipFile = "card-flip-new"
    private let clickSoundFile = "click-sound"
    
    // MARK: - Initialization
    
    private init() {
        // Load saved settings or use defaults
        let defaults = UserDefaults.standard
        
        // First launch detection
        if !defaults.bool(forKey: "hasLaunchedBefore") {
            defaults.set(true, forKey: "hasLaunchedBefore")
            defaults.set(true, forKey: "soundEffectsEnabled")
            defaults.set(true, forKey: "musicEnabled")
            defaults.set(Float(1.0), forKey: "effectsVolume")
            defaults.set(Float(0.3), forKey: "musicVolume")
        }
        
        self.soundEffectsEnabled = defaults.bool(forKey: "soundEffectsEnabled")
        self.musicEnabled = defaults.bool(forKey: "musicEnabled")
        self.effectsVolume = defaults.float(forKey: "effectsVolume")
        self.musicVolume = defaults.float(forKey: "musicVolume")
        
        // Ensure volumes have valid values
        if self.effectsVolume == 0 && defaults.object(forKey: "effectsVolume") == nil {
            self.effectsVolume = 1.0
        }
        if self.musicVolume == 0 && defaults.object(forKey: "musicVolume") == nil {
            self.musicVolume = 0.3
        }
        
        configureAudioSession()
        preloadSounds()
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
    
    private func preloadSounds() {
        // Preload card flip sound
        if let url = Bundle.main.url(forResource: cardFlipFile, withExtension: "mp3") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = effectsVolume
                player.prepareToPlay()
                soundCache[cardFlipFile] = player
            } catch {
                print("Failed to preload \(cardFlipFile): \(error.localizedDescription)")
            }
        }
        
        // Preload click sound
        if let url = Bundle.main.url(forResource: clickSoundFile, withExtension: "mp3") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = effectsVolume
                player.prepareToPlay()
                soundCache[clickSoundFile] = player
            } catch {
                print("Failed to preload \(clickSoundFile): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Sound Effects
    
    func playEffect(_ name: String, type: String = "mp3") {
        guard soundEffectsEnabled else { return }
        
        // Check cache first
        if let cachedPlayer = soundCache[name] {
            cachedPlayer.currentTime = 0
            cachedPlayer.volume = effectsVolume
            cachedPlayer.play()
            return
        }
        
        // Load and play if not cached
        guard let url = Bundle.main.url(forResource: name, withExtension: type) else {
            print("Sound effect not found: \(name).\(type)")
            return
        }
        
        do {
            effectPlayer = try AVAudioPlayer(contentsOf: url)
            effectPlayer?.volume = effectsVolume
            effectPlayer?.prepareToPlay()
            effectPlayer?.play()
        } catch {
            print("Error playing sound effect: \(error.localizedDescription)")
        }
    }
    
    func playCardFlip() {
        playEffect(cardFlipFile)
    }
    
    func playClick() {
        playEffect(clickSoundFile)
    }
    
    func playDiceRoll() {
        playEffect("dice-roll")
    }
    
    // MARK: - Background Music
    
    func playMusic(fadeIn: Bool = true) {
        guard musicEnabled else { return }
        
        if musicPlayer?.isPlaying == true {
            return
        }
        
        guard let url = Bundle.main.url(forResource: backgroundMusicFile, withExtension: "mp3") else {
            print("Music file not found: \(backgroundMusicFile).mp3")
            return
        }
        
        do {
            musicPlayer = try AVAudioPlayer(contentsOf: url)
            musicPlayer?.numberOfLoops = -1
            musicPlayer?.volume = fadeIn ? 0 : musicVolume
            musicPlayer?.prepareToPlay()
            musicPlayer?.play()
            
            if fadeIn {
                fadeInMusic()
            }
        } catch {
            print("Error playing music: \(error.localizedDescription)")
        }
    }
    
    func stopMusic(fadeOut: Bool = true) {
        guard let player = musicPlayer, player.isPlaying else { return }
        
        if fadeOut {
            fadeOutMusic { player.stop() }
        } else {
            player.stop()
        }
    }
    
    func pauseMusic() {
        musicPlayer?.pause()
    }
    
    func resumeMusic() {
        guard musicEnabled else { return }
        if musicPlayer == nil {
            playMusic()
        } else {
            musicPlayer?.play()
        }
    }
    
    var isMusicPlaying: Bool {
        return musicPlayer?.isPlaying ?? false
    }
    
    // MARK: - Fade Effects
    
    private func fadeInMusic() {
        guard let player = musicPlayer else { return }
        
        let fadeSteps = 15
        let fadeInterval = 1.5 / Double(fadeSteps)
        let volumeStep = musicVolume / Float(fadeSteps)
        
        for i in 1...fadeSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeInterval * Double(i)) {
                player.volume = min(volumeStep * Float(i), self.musicVolume)
            }
        }
    }
    
    private func fadeOutMusic(completion: @escaping () -> Void) {
        guard let player = musicPlayer else {
            completion()
            return
        }
        
        let fadeSteps = 10
        let fadeInterval = 1.0 / Double(fadeSteps)
        let currentVolume = player.volume
        let volumeStep = currentVolume / Float(fadeSteps)
        
        for i in 1...fadeSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeInterval * Double(i)) {
                player.volume = max(currentVolume - volumeStep * Float(i), 0)
                if i == fadeSteps {
                    completion()
                }
            }
        }
    }
    
    // MARK: - Utility
    
    func stopAll() {
        effectPlayer?.stop()
        musicPlayer?.stop()
    }
}
