//
//  GameModel.swift
//  Toxic Tom
//
//  Game state management for Smittobäraren
//

import SwiftUI
import Combine

// MARK: - Game Mode

enum GameMode {
    case local      // Hotseat - one device, pass around
    case online     // Each player on own device (future)
}

// MARK: - Player Role

enum PlayerRole: String, CaseIterable {
    case frisk = "frisk"                    // Healthy
    case smittobarare = "smittobarare"      // The Carrier
    case infekterad = "infekterad"          // Infected (during game)
    
    var displayName: String {
        switch self {
        case .frisk: return "FRISK"
        case .smittobarare: return "SMITTOBÄRAREN"
        case .infekterad: return "INFEKTERAD"
        }
    }
    
    var cardImage: String {
        return self.rawValue
    }
    
    var description: String {
        switch self {
        case .frisk: return "Du är frisk"
        case .smittobarare: return "Du är smittobäraren"
        case .infekterad: return "Du är infekterad"
        }
    }
    
    var objective: String {
        switch self {
        case .frisk: return "Hitta smittobäraren innan det är för sent"
        case .smittobarare: return "Smitta alla utan att bli upptäckt"
        case .infekterad: return "Hjälp de friska att hitta smittobäraren"
        }
    }
}

// MARK: - Character Avatar

struct CharacterAvatar: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let imageName: String
    
    static let allAvatars: [CharacterAvatar] = [
        // Face portraits
        CharacterAvatar(id: "kvinna-30", name: "Helena", imageName: "kvinna-30"),
        CharacterAvatar(id: "kvinna-45", name: "Margareta", imageName: "kvinna-45"),
        CharacterAvatar(id: "kvinna-60", name: "Birgitta", imageName: "kvinna-ansikte-60"),
        CharacterAvatar(id: "man-60", name: "Erik", imageName: "man-60-ansikte"),
        CharacterAvatar(id: "man-65", name: "Gustav", imageName: "man-65"),
        CharacterAvatar(id: "women-20", name: "Kristina", imageName: "women-20"),
        CharacterAvatar(id: "women-45", name: "Ingrid", imageName: "women-45"),
        CharacterAvatar(id: "women-65", name: "Elsa", imageName: "women-65")
    ]
}

// MARK: - Player

class Player: Identifiable, ObservableObject, Equatable {
    let id = UUID()
    let playerNumber: Int          // Player 1, 2, 3, etc.
    @Published var name: String
    @Published var avatar: CharacterAvatar
    @Published var role: PlayerRole
    @Published var isReady: Bool
    @Published var hasSeenRole: Bool
    @Published var isAlive: Bool   // For game state
    
    init(playerNumber: Int, name: String, avatar: CharacterAvatar) {
        self.playerNumber = playerNumber
        self.name = name
        self.avatar = avatar
        self.role = .frisk
        self.isReady = false
        self.hasSeenRole = false
        self.isAlive = true
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Game Phase

enum GamePhase: Equatable {
    // New phases for LocalGameView
    case playerCount            // Select number of players
    case playerSetup(Int)       // Setting up player N (1-indexed)
    case allPlayersReady        // All players added, ready to start
    case roleReveal(Int)        // Player N sees their role (1-indexed)
    case playing                // Main game loop
    case gameOver               // Game ended
    
    // Legacy phases for GameSetupView compatibility
    case lobby                  // Adding players (legacy)
    case readyCheck             // All players confirm ready (legacy)
    case legacyRoleReveal       // Each player sees their role (legacy)
}

// MARK: - Game Manager

class GameManager: ObservableObject {
    static let shared = GameManager()
    
    @Published var players: [Player] = []
    @Published var phase: GamePhase = .playerCount
    @Published var gameMode: GameMode = .local
    @Published var selectedPlayerCount: Int = 4
    @Published var usedAvatars: Set<String> = []
    
    // Minimum players to start
    let minPlayers = 3
    let maxPlayers = 8
    
    private init() {}
    
    // MARK: - Available avatars (excluding used ones)
    
    func availableAvatars() -> [CharacterAvatar] {
        CharacterAvatar.allAvatars.filter { !usedAvatars.contains($0.id) }
    }
    
    // MARK: - Player Setup Flow (Hotseat)
    
    func setPlayerCount(_ count: Int) {
        selectedPlayerCount = min(max(count, minPlayers), maxPlayers)
        phase = .playerSetup(1) // Start with Player 1
    }
    
    func addPlayer(name: String, avatar: CharacterAvatar) {
        let playerNumber = players.count + 1
        let player = Player(playerNumber: playerNumber, name: name, avatar: avatar)
        players.append(player)
        usedAvatars.insert(avatar.id)
        
        if players.count < selectedPlayerCount {
            // More players to add
            phase = .playerSetup(players.count + 1)
        } else {
            // All players added
            phase = .allPlayersReady
        }
    }
    
    func removePlayer(_ player: Player) {
        usedAvatars.remove(player.avatar.id)
        players.removeAll { $0.id == player.id }
    }
    
    func canStartGame() -> Bool {
        return players.count >= minPlayers && players.count == selectedPlayerCount
    }
    
    // MARK: - Game Flow
    
    func startGame() {
        guard canStartGame() else { return }
        assignRoles()
        phase = .roleReveal(1) // Start with Player 1's role reveal
    }
    
    func assignRoles() {
        // Reset all players to healthy
        for player in players {
            player.role = .frisk
            player.hasSeenRole = false
            player.isAlive = true
        }
        
        // Randomly select one player to be the carrier
        if let carrierIndex = players.indices.randomElement() {
            players[carrierIndex].role = .smittobarare
        }
    }
    
    func currentPlayerForReveal() -> Player? {
        if case .roleReveal(let index) = phase {
            guard index >= 1 && index <= players.count else { return nil }
            return players[index - 1]
        }
        return nil
    }
    
    func confirmRoleSeen() {
        if case .roleReveal(let index) = phase {
            if index <= players.count {
                players[index - 1].hasSeenRole = true
            }
            
            if index < players.count {
                // Next player
                phase = .roleReveal(index + 1)
            } else {
                // All players have seen their roles
                phase = .playing
            }
        }
    }
    
    // MARK: - Legacy Methods (for GameSetupView compatibility)
    
    func startReadyCheck() {
        guard players.count >= minPlayers else { return }
        phase = .readyCheck
    }
    
    func markPlayerReady(_ player: Player) {
        player.isReady = true
        
        // Check if all players are ready
        if players.allSatisfy({ $0.isReady }) {
            assignRoles()
            phase = .legacyRoleReveal
        }
    }
    
    func legacyCurrentPlayerForReveal() -> Player? {
        // Find first player who hasn't seen their role
        return players.first { !$0.hasSeenRole }
    }
    
    func legacyConfirmRoleSeen() {
        if let player = legacyCurrentPlayerForReveal() {
            player.hasSeenRole = true
        }
        
        // Check if all players have seen their role
        if players.allSatisfy({ $0.hasSeenRole }) {
            phase = .playing
        }
    }
    
    // MARK: - Reset
    
    func resetGame() {
        for player in players {
            player.isReady = false
            player.hasSeenRole = false
            player.role = .frisk
            player.isAlive = true
        }
        assignRoles()
        phase = .roleReveal(1)
    }
    
    func resetAll() {
        players.removeAll()
        usedAvatars.removeAll()
        phase = .playerCount
        selectedPlayerCount = 4
    }
}
