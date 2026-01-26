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

// MARK: - Public Role (Elected by players)

enum PublicRole: String, CaseIterable {
    case lakare = "lakare"      // Doctor - can cure one player per day
    case vaktare = "vaktare"    // Guard - can protect one player per night
    
    var displayName: String {
        switch self {
        case .lakare: return "LÄKARE"
        case .vaktare: return "VÄKTARE"
        }
    }
    
    var iconName: String {
        switch self {
        case .lakare: return "doctor"
        case .vaktare: return "guard"
        }
    }
    
    var description: String {
        switch self {
        case .lakare: return "Kan ge motgift till en spelare varje dag"
        case .vaktare: return "Kan skydda en spelare varje natt"
        }
    }
    
    var electionTitle: String {
        switch self {
        case .lakare: return "Välj Läkare"
        case .vaktare: return "Välj Väktare"
        }
    }
    
    var electionSubtitle: String {
        switch self {
        case .lakare: return "Vem ska ha makten att bota?"
        case .vaktare: return "Vem ska vakta byn om natten?"
        }
    }
}

// MARK: - Player Role

enum PlayerRole: String, CaseIterable {
    case frisk = "frisk"                    // Healthy
    case smittobarare = "smittobarare"      // The Carrier
    case infekterad = "infekterad"          // Infected (during game)
    
    var displayName: String {
        switch self {
        case .frisk: return "FRISK"
        case .smittobarare: return "DR. PLAGUE"
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
    let imageName: String
    let displayName: String
    
    /// Card aspect ratio (780 × 1150)
    static let cardAspectRatio: CGFloat = 780.0 / 1150.0
    
    /// All 18 avatars arranged as pairs (good on left, evil on right) for 2-column grid display
    static let allAvatars: [CharacterAvatar] = [
        // Row 1: Wizard
        CharacterAvatar(id: "good-wizard", imageName: "good-wizard", displayName: "Wizard"),
        CharacterAvatar(id: "evil-wizard", imageName: "evil-wizard", displayName: "Dark Wizard"),
        // Row 2: Princess
        CharacterAvatar(id: "good-princess", imageName: "good-princess", displayName: "Princess"),
        CharacterAvatar(id: "evil-princess", imageName: "evil-princess", displayName: "False Princess"),
        // Row 3: Bar Keeper
        CharacterAvatar(id: "good-bar-keeper", imageName: "good-bar-keeper", displayName: "Bar Keeper"),
        CharacterAvatar(id: "evil-bar-keeper", imageName: "evil-bar-keeper", displayName: "Twisted Bar Keeper"),
        // Row 4: Jester
        CharacterAvatar(id: "good-jester", imageName: "good-jester", displayName: "Jester"),
        CharacterAvatar(id: "evil-jester", imageName: "evil-jester", displayName: "Mischievous Jester"),
        // Row 5: Goblin
        CharacterAvatar(id: "good-goblin", imageName: "good-goblin", displayName: "Goblin"),
        CharacterAvatar(id: "evil-goblin", imageName: "evil-goblin", displayName: "Ravenous Goblin"),
        // Row 6: Judge
        CharacterAvatar(id: "good-judge", imageName: "good-judge", displayName: "Judge"),
        CharacterAvatar(id: "evil-judge", imageName: "evil-judge", displayName: "Corrupted Judge"),
        // Row 7: Elf
        CharacterAvatar(id: "good-elf", imageName: "good-elf", displayName: "Elf"),
        CharacterAvatar(id: "evil-elf", imageName: "evil-elf", displayName: "Dark Elf"),
        // Row 8: Relic Keeper
        CharacterAvatar(id: "good-relic-guy", imageName: "good-relic-guy", displayName: "Relic Keeper"),
        CharacterAvatar(id: "evil-relic-guy", imageName: "evil-relic-guy", displayName: "Unlawful Relic Keeper"),
        // Row 9: Ogre
        CharacterAvatar(id: "good-troll", imageName: "good-troll", displayName: "Ogre"),
        CharacterAvatar(id: "evil-troll", imageName: "evil-troll", displayName: "Perverted Ogre")
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
    
    // Minimum players to start (2 for testing, should be 4+ in production)
    let minPlayers = 2
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
