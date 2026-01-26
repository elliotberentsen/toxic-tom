//
//  FirebaseMultiplayerManager.swift
//  Toxic Tom
//
//  Handles Firebase authentication, presence, and lobby management
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseDatabase

// MARK: - Online Player Model

struct OnlinePlayer: Identifiable, Codable, Equatable {
    let oderId: String
    var name: String
    var avatarId: String
    var status: PlayerStatus
    var role: String?
    var isHost: Bool
    var lastSeen: TimeInterval
    var isAlive: Bool
    
    var id: String { oderId }
    
    /// Get the avatar for this player
    var avatar: CharacterAvatar? {
        CharacterAvatar.allAvatars.first { $0.id == avatarId }
    }
    
    /// Get the secret role as PlayerRole enum
    var secretRole: PlayerRole? {
        guard let role = role else { return nil }
        return PlayerRole(rawValue: role)
    }
    
    enum PlayerStatus: String, Codable {
        case online = "online"
        case offline = "offline"
        case reconnecting = "reconnecting"
    }
    
    init(oderId: String, name: String, avatarId: String, isHost: Bool = false) {
        self.oderId = oderId
        self.name = name
        self.avatarId = avatarId
        self.status = .online
        self.role = nil
        self.isHost = isHost
        self.lastSeen = Date().timeIntervalSince1970
        self.isAlive = true
    }
    
    init?(from dict: [String: Any], oderId: String) {
        guard let name = dict["name"] as? String,
              let avatarId = dict["avatarId"] as? String else {
            return nil
        }
        
        self.oderId = oderId
        self.name = name
        self.avatarId = avatarId
        self.status = PlayerStatus(rawValue: dict["status"] as? String ?? "offline") ?? .offline
        self.role = dict["role"] as? String
        self.isHost = dict["isHost"] as? Bool ?? false
        self.lastSeen = dict["lastSeen"] as? TimeInterval ?? 0
        self.isAlive = dict["isAlive"] as? Bool ?? true
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "avatarId": avatarId,
            "status": status.rawValue,
            "isHost": isHost,
            "lastSeen": ServerValue.timestamp(),
            "isAlive": isAlive
        ]
        if let role = role {
            dict["role"] = role
        }
        return dict
    }
}

// MARK: - Lobby Model

struct GameLobby: Identifiable {
    let id: String
    let code: String
    var hostId: String
    var players: [OnlinePlayer]
    var gamePhase: OnlineGamePhase
    var maxPlayers: Int
    var createdAt: TimeInterval
    
    // Public roles (elected by players)
    var lakareId: String?
    var vaktareId: String?
    
    // Current election state
    var currentElection: ElectionType?
    var votes: [String: String]  // oderId -> votedForUserId (for elections)
    var tiedCandidates: [String]?  // For re-votes, only these can be voted for
    
    // Game round tracking
    var round: Int
    var roundSubPhase: RoundSubPhase
    
    // Round state
    var protectedPlayerId: String?  // Who Väktare is protecting
    var cureTargetId: String?  // Who Läkare chose to cure
    var cureResult: String?  // "success" or "noEffect"
    var roundVotes: [String: String]  // oderId -> targetId (for exile voting)
    var rattmannenTarget: String?  // Who Råttmannen is infecting (hidden)
    var exiledPlayerId: String?  // Who got exiled this round
    
    // Dice state
    var currentRollerId: String?  // Who rolls this round
    var diceResult: Int?  // 2-12
    var diceEvent: DiceEventType?  // The event that occurred
    var diceEventResolved: Bool  // Has the event been handled?
    var quarantinedPlayerIds: [String]  // Players in quarantine this round
    var prophecyType: String?  // "count" or "investigate"
    var prophecyTarget: String?  // Player ID being investigated
    var prophecyResult: String?  // The prophecy answer (only visible to roller)
    var epidemicVictimId: String?  // Who got infected by epidemic
    var skipCurePhase: Bool  // True if Blackout (9-10)
    
    // Win condition
    var gameResult: String?  // "friskaWin" or "rattmannenWin"
    
    enum OnlineGamePhase: String, Codable {
        case waiting = "waiting"
        case starting = "starting"
        case roleReveal = "roleReveal"
        case electionLakare = "electionLakare"
        case electionVaktare = "electionVaktare"
        case round = "round"  // Active round (uses roundSubPhase)
        case finished = "finished"
    }
    
    enum RoundSubPhase: String, Codable {
        case diceRoll = "diceRoll"  // Dice roll animation
        case diceEvent = "diceEvent"  // Handle the dice event
        case protection = "protection"  // Väktare chooses who to protect
        case cure = "cure"  // Läkare chooses who to cure
        case voting = "voting"  // Everyone votes for exile
        case resolution = "resolution"  // Show results
    }
    
    enum DiceEventType: String, Codable {
        case antidote = "antidote"  // 2-3: Extra cure
        case prophecy = "prophecy"  // 4-5: Learn info
        case quarantine = "quarantine"  // 6-8: Silence 2 players
        case blackout = "blackout"  // 9-10: Skip cure phase
        case epidemic = "epidemic"  // 11-12: Random infection
        
        static func from(roll: Int) -> DiceEventType {
            switch roll {
            case 2...3: return .antidote
            case 4...5: return .prophecy
            case 6...8: return .quarantine
            case 9...10: return .blackout
            case 11...12: return .epidemic
            default: return .quarantine  // Fallback (most common)
            }
        }
        
        var displayName: String {
            switch self {
            case .antidote: return "Motgift Funnet"
            case .prophecy: return "Spådom"
            case .quarantine: return "Karantän"
            case .blackout: return "Midnatt"
            case .epidemic: return "Epidemi"
            }
        }
        
        var description: String {
            switch self {
            case .antidote: return "Ett motgift har hittats! Du får bota en valfri spelare omedelbart."
            case .prophecy: return "En profetisk uppenbarelse! Välj att lära dig antalet smittade ELLER undersöka en spelare."
            case .quarantine: return "Panik! Välj två spelare som sätts i karantän och inte får prata eller rösta denna runda."
            case .blackout: return "Mörker faller över byn! Ingen botning sker denna runda."
            case .epidemic: return "Pesten muterar! En slumpmässig frisk spelare har smittats."
            }
        }
    }
    
    enum ElectionType: String, Codable {
        case lakare = "lakare"
        case vaktare = "vaktare"
    }
    
    init(id: String, code: String, hostId: String, maxPlayers: Int = 8) {
        self.id = id
        self.code = code
        self.hostId = hostId
        self.players = []
        self.gamePhase = .waiting
        self.maxPlayers = maxPlayers
        self.createdAt = Date().timeIntervalSince1970
        self.lakareId = nil
        self.vaktareId = nil
        self.currentElection = nil
        self.votes = [:]
        self.tiedCandidates = nil
        self.round = 0
        self.roundSubPhase = .diceRoll
        self.protectedPlayerId = nil
        self.cureTargetId = nil
        self.cureResult = nil
        self.roundVotes = [:]
        self.rattmannenTarget = nil
        self.exiledPlayerId = nil
        // Dice state
        self.currentRollerId = nil
        self.diceResult = nil
        self.diceEvent = nil
        self.diceEventResolved = false
        self.quarantinedPlayerIds = []
        self.prophecyType = nil
        self.prophecyTarget = nil
        self.prophecyResult = nil
        self.epidemicVictimId = nil
        self.skipCurePhase = false
        self.gameResult = nil
    }
    
    init?(from dict: [String: Any], id: String) {
        guard let code = dict["code"] as? String,
              let hostId = dict["hostId"] as? String else {
            return nil
        }
        
        self.id = id
        self.code = code
        self.hostId = hostId
        self.gamePhase = OnlineGamePhase(rawValue: dict["gamePhase"] as? String ?? "waiting") ?? .waiting
        self.maxPlayers = dict["maxPlayers"] as? Int ?? 8
        self.createdAt = dict["createdAt"] as? TimeInterval ?? 0
        self.round = dict["round"] as? Int ?? 0
        self.roundSubPhase = RoundSubPhase(rawValue: dict["roundSubPhase"] as? String ?? "protection") ?? .protection
        
        // Parse public roles
        if let publicRoles = dict["publicRoles"] as? [String: Any] {
            self.lakareId = publicRoles["lakare"] as? String
            self.vaktareId = publicRoles["vaktare"] as? String
        } else {
            self.lakareId = nil
            self.vaktareId = nil
        }
        
        // Parse current election state
        if let electionString = dict["currentElection"] as? String {
            self.currentElection = ElectionType(rawValue: electionString)
        } else {
            self.currentElection = nil
        }
        
        // Parse election votes
        if let votesDict = dict["votes"] as? [String: String] {
            self.votes = votesDict
        } else {
            self.votes = [:]
        }
        
        // Parse tied candidates for re-votes
        if let tied = dict["tiedCandidates"] as? [String] {
            self.tiedCandidates = tied
        } else {
            self.tiedCandidates = nil
        }
        
        // Parse round state
        if let roundState = dict["roundState"] as? [String: Any] {
            self.protectedPlayerId = roundState["protectedPlayerId"] as? String
            self.cureTargetId = roundState["cureTargetId"] as? String
            self.cureResult = roundState["cureResult"] as? String
            self.rattmannenTarget = roundState["rattmannenTarget"] as? String
            self.exiledPlayerId = roundState["exiledPlayerId"] as? String
            
            if let roundVotesDict = roundState["votes"] as? [String: String] {
                self.roundVotes = roundVotesDict
            } else {
                self.roundVotes = [:]
            }
        } else {
            self.protectedPlayerId = nil
            self.cureTargetId = nil
            self.cureResult = nil
            self.roundVotes = [:]
            self.rattmannenTarget = nil
            self.exiledPlayerId = nil
        }
        
        // Parse dice state
        if let diceState = dict["diceState"] as? [String: Any] {
            self.currentRollerId = diceState["currentRollerId"] as? String
            self.diceResult = diceState["diceResult"] as? Int
            if let eventString = diceState["diceEvent"] as? String {
                self.diceEvent = DiceEventType(rawValue: eventString)
            } else {
                self.diceEvent = nil
            }
            self.diceEventResolved = diceState["diceEventResolved"] as? Bool ?? false
            self.quarantinedPlayerIds = diceState["quarantinedPlayerIds"] as? [String] ?? []
            self.prophecyType = diceState["prophecyType"] as? String
            self.prophecyTarget = diceState["prophecyTarget"] as? String
            self.prophecyResult = diceState["prophecyResult"] as? String
            self.epidemicVictimId = diceState["epidemicVictimId"] as? String
            self.skipCurePhase = diceState["skipCurePhase"] as? Bool ?? false
        } else {
            self.currentRollerId = nil
            self.diceResult = nil
            self.diceEvent = nil
            self.diceEventResolved = false
            self.quarantinedPlayerIds = []
            self.prophecyType = nil
            self.prophecyTarget = nil
            self.prophecyResult = nil
            self.epidemicVictimId = nil
            self.skipCurePhase = false
        }
        
        // Parse game result
        self.gameResult = dict["gameResult"] as? String
        
        // Parse players
        var parsedPlayers: [OnlinePlayer] = []
        if let playersDict = dict["players"] as? [String: [String: Any]] {
            for (oderId, playerData) in playersDict {
                if let player = OnlinePlayer(from: playerData, oderId: oderId) {
                    parsedPlayers.append(player)
                }
            }
        }
        // Sort by oderId for stable ordering (prevents UI jumping when lastSeen updates)
        self.players = parsedPlayers.sorted { $0.oderId < $1.oderId }
    }
}

// MARK: - Connection State

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    
    var displayText: String {
        switch self {
        case .disconnected: return "Frånkopplad"
        case .connecting: return "Ansluter..."
        case .connected: return "Ansluten"
        case .reconnecting: return "Återansluter..."
        }
    }
}

// MARK: - Firebase Multiplayer Manager

class FirebaseMultiplayerManager: ObservableObject {
    static let shared = FirebaseMultiplayerManager()
    
    // MARK: - Published State
    
    @Published var isAuthenticated = false
    @Published var userId: String?
    @Published var connectionState: ConnectionState = .disconnected
    
    @Published var currentLobby: GameLobby?
    @Published var players: [OnlinePlayer] = []
    @Published var disconnectedPlayers: [String] = []
    
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    // MARK: - Private Properties
    
    private var database: DatabaseReference
    private var lobbyRef: DatabaseReference?
    private var playersRef: DatabaseReference?
    private var connectedRef: DatabaseReference?
    private var presenceRef: DatabaseReference?
    
    private var lobbyObserverHandle: DatabaseHandle?
    private var playersObserverHandle: DatabaseHandle?
    private var connectedObserverHandle: DatabaseHandle?
    
    private var heartbeatTimer: Timer?
    
    // MARK: - Init
    
    private init() {
        database = Database.database().reference()
    }
    
    // MARK: - Authentication
    
    /// Sign in anonymously to Firebase
    func signInAnonymously() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().signInAnonymously()
            await MainActor.run {
                self.userId = result.user.uid
                self.isAuthenticated = true
                self.setupConnectionMonitoring()
            }
            print("✅ Firebase Auth: Signed in as \(result.user.uid)")
        } catch {
            await MainActor.run {
                self.errorMessage = "Kunde inte ansluta: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    /// Sign out from Firebase
    func signOut() {
        do {
            try Auth.auth().signOut()
            userId = nil
            isAuthenticated = false
            leaveLobby()
        } catch {
            print("❌ Firebase Auth: Sign out failed: \(error)")
        }
    }
    
    // MARK: - Connection Monitoring
    
    private func setupConnectionMonitoring() {
        guard let userId = userId else { return }
        
        connectedRef = database.child(".info/connected")
        presenceRef = database.child("presence/\(userId)")
        
        connectedObserverHandle = connectedRef?.observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            if let connected = snapshot.value as? Bool, connected {
                DispatchQueue.main.async {
                    self.connectionState = .connected
                }
                
                // Set online status
                self.presenceRef?.setValue([
                    "online": true,
                    "lastSeen": ServerValue.timestamp()
                ])
                
                // When we disconnect, server will set this automatically
                self.presenceRef?.onDisconnectSetValue([
                    "online": false,
                    "lastSeen": ServerValue.timestamp()
                ])
                
                // Also update player status in lobby if we're in one
                if let lobbyId = self.currentLobby?.id {
                    let playerStatusRef = self.database.child("lobbies/\(lobbyId)/players/\(userId)/status")
                    playerStatusRef.setValue("online")
                    playerStatusRef.onDisconnectSetValue("reconnecting")
                }
                
            } else {
                DispatchQueue.main.async {
                    if self.connectionState == .connected {
                        self.connectionState = .reconnecting
                    }
                }
            }
        }
    }
    
    // MARK: - Lobby Creation
    
    /// Generate a unique 6-character lobby code
    private func generateLobbyCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Removed confusing chars
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    /// Create a new lobby and become the host
    func createLobby(playerName: String, avatarId: String) async throws -> String {
        guard let userId = userId else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Inte inloggad"])
        }
        
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        let lobbyCode = generateLobbyCode()
        let lobbyId = database.child("lobbies").childByAutoId().key ?? UUID().uuidString
        
        // Create lobby data
        let lobbyData: [String: Any] = [
            "code": lobbyCode,
            "hostId": userId,
            "gamePhase": "waiting",
            "maxPlayers": 8,
            "createdAt": ServerValue.timestamp(),
            "players": [
                userId: [
                    "name": playerName,
                    "avatarId": avatarId,
                    "status": "online",
                    "isHost": true,
                    "lastSeen": ServerValue.timestamp()
                ] as [String: Any]
            ] as [String: Any]
        ]
        
        // Also store lobby code mapping for easy lookup
        let codeMapping: [String: Any] = [
            "lobbyId": lobbyId
        ]
        
        do {
            try await database.child("lobbies/\(lobbyId)").setValue(lobbyData)
            try await database.child("lobbyCodes/\(lobbyCode)").setValue(codeMapping)
            
            await MainActor.run {
                self.observeLobby(lobbyId: lobbyId)
            }
            
            print("✅ Lobby created: \(lobbyCode)")
            return lobbyCode
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Kunde inte skapa lobby: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    // MARK: - Lobby Joining
    
    /// Join an existing lobby by code
    func joinLobby(code: String, playerName: String, avatarId: String) async throws {
        guard let userId = userId else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Inte inloggad"])
        }
        
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Look up lobby ID from code
        let codeSnapshot = try await database.child("lobbyCodes/\(normalizedCode)").getData()
        
        guard let codeData = codeSnapshot.value as? [String: Any],
              let lobbyId = codeData["lobbyId"] as? String else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Lobbykoden finns inte"])
        }
        
        // Check if lobby exists and is in waiting state
        let lobbySnapshot = try await database.child("lobbies/\(lobbyId)").getData()
        
        guard let lobbyData = lobbySnapshot.value as? [String: Any],
              let gamePhase = lobbyData["gamePhase"] as? String else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Lobbyn finns inte längre"])
        }
        
        if gamePhase != "waiting" {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Spelet har redan startat"])
        }
        
        // Check player count
        let playersDict = lobbyData["players"] as? [String: Any] ?? [:]
        let maxPlayers = lobbyData["maxPlayers"] as? Int ?? 8
        
        if playersDict.count >= maxPlayers {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Lobbyn är full"])
        }
        
        // Add player to lobby
        let playerData: [String: Any] = [
            "name": playerName,
            "avatarId": avatarId,
            "status": "online",
            "isHost": false,
            "lastSeen": ServerValue.timestamp()
        ]
        
        try await database.child("lobbies/\(lobbyId)/players/\(userId)").setValue(playerData)
        
        await MainActor.run {
            self.observeLobby(lobbyId: lobbyId)
        }
        
        // Setup presence for this lobby
        let playerStatusRef = database.child("lobbies/\(lobbyId)/players/\(userId)/status")
        playerStatusRef.onDisconnectSetValue("reconnecting") { _, _ in }
        
        print("✅ Joined lobby: \(normalizedCode)")
    }
    
    // MARK: - Lobby Observation
    
    private func observeLobby(lobbyId: String) {
        lobbyRef = database.child("lobbies/\(lobbyId)")
        
        lobbyObserverHandle = lobbyRef?.observe(.value) { [weak self] snapshot in
            guard let self = self,
                  let data = snapshot.value as? [String: Any],
                  let lobby = GameLobby(from: data, id: lobbyId) else {
                return
            }
            
            DispatchQueue.main.async {
                let previousVoteCount = self.currentLobby?.votes.count ?? 0
                let newVoteCount = lobby.votes.count
                
                self.currentLobby = lobby
                self.players = lobby.players
                
                // Track disconnected players
                self.disconnectedPlayers = lobby.players
                    .filter { $0.status != .online }
                    .map { $0.name }
                
                // Check if all election votes are in (host only)
                // Trigger when vote count changes and we're in an election phase
                if newVoteCount > previousVoteCount,
                   lobby.gamePhase == .electionLakare || lobby.gamePhase == .electionVaktare,
                   self.isHost {
                    Task {
                        await self.checkAndResolveElection()
                    }
                }
                
                // Check if all round votes are in (host only)
                if lobby.gamePhase == .round && lobby.roundSubPhase == .voting && self.isHost {
                    // Expected votes excludes quarantined players
                    let alivePlayers = lobby.players.filter { $0.isAlive }
                    let expectedVotes = alivePlayers.filter { !lobby.quarantinedPlayerIds.contains($0.oderId) }.count
                    if lobby.roundVotes.count >= expectedVotes {
                        Task {
                            await self.checkAndResolveRound()
                        }
                    }
                }
            }
        }
        
        // Start heartbeat
        startHeartbeat(lobbyId: lobbyId)
    }
    
    // MARK: - Heartbeat System
    
    private func startHeartbeat(lobbyId: String) {
        guard let userId = userId else { return }
        
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Update lastSeen timestamp
            self.database.child("lobbies/\(lobbyId)/players/\(userId)/lastSeen")
                .setValue(ServerValue.timestamp())
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    // MARK: - Lobby Actions
    
    /// Leave the current lobby
    func leaveLobby() {
        guard let lobbyId = currentLobby?.id,
              let oderId = userId else { return }
        
        // Remove observers
        if let handle = lobbyObserverHandle {
            lobbyRef?.removeObserver(withHandle: handle)
        }
        
        stopHeartbeat()
        
        // Remove player from lobby
        database.child("lobbies/\(lobbyId)/players/\(userId)").removeValue()
        
        // If we're the host and there are other players, transfer host
        if let lobby = currentLobby, lobby.hostId == userId {
            let remainingPlayers = lobby.players.filter { $0.oderId != oderId }
            if let newHost = remainingPlayers.first {
                database.child("lobbies/\(lobbyId)/hostId").setValue(newHost.oderId)
                database.child("lobbies/\(lobbyId)/players/\(newHost.oderId)/isHost").setValue(true)
            } else {
                // No players left, delete lobby
                database.child("lobbies/\(lobbyId)").removeValue()
                if let code = lobby.code as String? {
                    database.child("lobbyCodes/\(code)").removeValue()
                }
            }
        }
        
        DispatchQueue.main.async {
            self.currentLobby = nil
            self.players = []
            self.disconnectedPlayers = []
        }
        
        print("✅ Left lobby")
    }
    
    /// Kick a player (host only)
    func kickPlayer(_ player: OnlinePlayer) {
        guard let lobbyId = currentLobby?.id,
              let lobby = currentLobby,
              lobby.hostId == userId else { return }
        
        database.child("lobbies/\(lobbyId)/players/\(player.oderId)").removeValue()
        print("✅ Kicked player: \(player.name)")
    }
    
    // MARK: - Game Actions
    
    /// Start the game (host only)
    func startGame() async throws {
        guard let lobbyId = currentLobby?.id,
              let lobby = currentLobby,
              lobby.hostId == userId else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endast värden kan starta spelet"])
        }
        
        guard lobby.players.count >= 2 else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Minst 2 spelare krävs"])
        }
        
        // Assign roles
        var playerRoles: [String: String] = [:]
        let playerIds = lobby.players.map { $0.oderId }
        
        // Randomly select carrier
        let carrierIndex = Int.random(in: 0..<playerIds.count)
        
        for (index, playerId) in playerIds.enumerated() {
            playerRoles[playerId] = index == carrierIndex ? "smittobarare" : "frisk"
        }
        
        // Update lobby with roles and game phase
        var updates: [String: Any] = [
            "gamePhase": "roleReveal"
        ]
        
        for (playerId, role) in playerRoles {
            updates["players/\(playerId)/role"] = role
        }
        
        try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        
        print("✅ Game started with \(lobby.players.count) players")
    }
    
    /// Get my role in the current game
    func getMyRole() -> PlayerRole? {
        guard let userId = userId,
              let player = players.first(where: { $0.oderId == userId }),
              let roleString = player.role else {
            return nil
        }
        
        return PlayerRole(rawValue: roleString)
    }
    
    // MARK: - Election Methods
    
    /// Start the Läkare election (called after all players have seen their roles)
    func startLakareElection() async throws {
        guard let lobbyId = currentLobby?.id,
              isHost else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endast värden kan starta val"])
        }
        
        let updates: [String: Any] = [
            "gamePhase": "electionLakare",
            "currentElection": "lakare",
            "votes": [:] as [String: String],
            "tiedCandidates": NSNull()
        ]
        
        try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        print("✅ Läkare election started")
    }
    
    /// Cast a vote in the current election
    func castVote(forPlayerId candidateId: String) async throws {
        guard let lobbyId = currentLobby?.id,
              let oderId = userId else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Inte i en lobby"])
        }
        
        // Verify the candidate is valid
        guard let lobby = currentLobby else { return }
        
        // Check if we're in a re-vote with limited candidates
        if let tiedCandidates = lobby.tiedCandidates {
            guard tiedCandidates.contains(candidateId) else {
                throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Denna kandidat är inte med i omröstningen"])
            }
        } else {
            // Normal election - check valid candidates
            let validCandidates = getValidCandidates()
            guard validCandidates.contains(where: { $0.oderId == candidateId }) else {
                throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ogiltig kandidat"])
            }
        }
        
        // Cast the vote
        try await database.child("lobbies/\(lobbyId)/votes/\(oderId)").setValue(candidateId)
        print("✅ Vote cast for \(candidateId)")
        
        // Check if all votes are in
        await checkAndResolveElection()
    }
    
    /// Get valid candidates for the current election
    func getValidCandidates() -> [OnlinePlayer] {
        guard let lobby = currentLobby else { return [] }
        
        // If we're in a re-vote, only tied candidates are valid
        if let tiedCandidates = lobby.tiedCandidates {
            return players.filter { tiedCandidates.contains($0.oderId) }
        }
        
        // For Väktare election, exclude the elected Läkare
        if lobby.gamePhase == .electionVaktare, let lakareId = lobby.lakareId {
            return players.filter { $0.oderId != lakareId }
        }
        
        // For Läkare election, all players are valid
        return players
    }
    
    /// Check if my vote has been cast
    func hasVoted() -> Bool {
        guard let oderId = userId,
              let lobby = currentLobby else { return false }
        return lobby.votes[oderId] != nil
    }
    
    /// Get the candidate I voted for
    func myVotedCandidateId() -> String? {
        guard let oderId = userId,
              let lobby = currentLobby else { return nil }
        return lobby.votes[oderId]
    }
    
    /// Get vote count for a candidate
    func voteCount(for candidateId: String) -> Int {
        guard let lobby = currentLobby else { return 0 }
        return lobby.votes.values.filter { $0 == candidateId }.count
    }
    
    /// Get total votes cast
    func totalVotesCast() -> Int {
        return currentLobby?.votes.count ?? 0
    }
    
    /// Get number of voters expected
    func expectedVoterCount() -> Int {
        return players.count
    }
    
    /// Check if all votes are in and resolve the election
    private func checkAndResolveElection() async {
        guard let lobby = currentLobby,
              isHost else { return }  // Only host resolves
        
        // Check if all players have voted
        let expectedVotes = players.count
        let actualVotes = lobby.votes.count
        
        guard actualVotes >= expectedVotes else {
            print("⏳ Waiting for more votes: \(actualVotes)/\(expectedVotes)")
            return
        }
        
        // Tally votes
        var voteCounts: [String: Int] = [:]
        for candidateId in lobby.votes.values {
            voteCounts[candidateId, default: 0] += 1
        }
        
        // Find winner(s)
        let maxVotes = voteCounts.values.max() ?? 0
        let winners = voteCounts.filter { $0.value == maxVotes }.map { $0.key }
        
        if winners.count == 1 {
            // Clear winner - resolve election
            let winnerId = winners[0]
            await resolveElection(winnerId: winnerId)
        } else {
            // Tie - trigger re-vote
            await triggerRevote(tiedCandidates: winners)
        }
    }
    
    /// Resolve an election with a winner
    private func resolveElection(winnerId: String) async {
        guard let lobbyId = currentLobby?.id,
              let lobby = currentLobby else { return }
        
        var updates: [String: Any] = [
            "votes": [:] as [String: String],
            "tiedCandidates": NSNull()
        ]
        
        if lobby.gamePhase == .electionLakare {
            // Läkare elected - move to Väktare election
            updates["publicRoles/lakare"] = winnerId
            updates["gamePhase"] = "electionVaktare"
            updates["currentElection"] = "vaktare"
            print("✅ Läkare elected: \(winnerId), moving to Väktare election")
        } else if lobby.gamePhase == .electionVaktare {
            // Väktare elected - move to round phase (start with dice roll)
            updates["publicRoles/vaktare"] = winnerId
            updates["gamePhase"] = "round"
            updates["roundSubPhase"] = "diceRoll"
            updates["currentElection"] = NSNull()
            updates["round"] = 1
            // Reset round state
            updates["roundState"] = [
                "protectedPlayerId": NSNull(),
                "cureTargetId": NSNull(),
                "cureResult": NSNull(),
                "votes": [:] as [String: String],
                "rattmannenTarget": NSNull(),
                "exiledPlayerId": NSNull()
            ] as [String: Any]
            // Initialize dice state - host rolls first
            updates["diceState"] = [
                "currentRollerId": lobby.hostId,
                "diceResult": NSNull(),
                "diceEvent": NSNull(),
                "diceEventResolved": false,
                "quarantinedPlayerIds": [] as [String],
                "prophecyType": NSNull(),
                "prophecyTarget": NSNull(),
                "prophecyResult": NSNull(),
                "epidemicVictimId": NSNull(),
                "skipCurePhase": false
            ] as [String: Any]
            print("✅ Väktare elected: \(winnerId), starting round 1")
        }
        
        do {
            try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        } catch {
            print("❌ Failed to resolve election: \(error)")
        }
    }
    
    /// Trigger a re-vote with only the tied candidates
    private func triggerRevote(tiedCandidates: [String]) async {
        guard let lobbyId = currentLobby?.id else { return }
        
        let updates: [String: Any] = [
            "votes": [:] as [String: String],
            "tiedCandidates": tiedCandidates
        ]
        
        do {
            try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
            print("🔄 Re-vote triggered with candidates: \(tiedCandidates)")
        } catch {
            print("❌ Failed to trigger re-vote: \(error)")
        }
    }
    
    /// Get the elected Läkare player
    func getLakare() -> OnlinePlayer? {
        guard let lakareId = currentLobby?.lakareId else { return nil }
        return players.first { $0.oderId == lakareId }
    }
    
    /// Get the elected Väktare player
    func getVaktare() -> OnlinePlayer? {
        guard let vaktareId = currentLobby?.vaktareId else { return nil }
        return players.first { $0.oderId == vaktareId }
    }
    
    /// Check if current user is the Läkare
    var isLakare: Bool {
        guard let userId = userId,
              let lakareId = currentLobby?.lakareId else { return false }
        return userId == lakareId
    }
    
    /// Check if current user is the Väktare
    var isVaktare: Bool {
        guard let userId = userId,
              let vaktareId = currentLobby?.vaktareId else { return false }
        return userId == vaktareId
    }
    
    /// Check if current user is the host
    var isHost: Bool {
        guard let userId = userId,
              let lobby = currentLobby else { return false }
        return lobby.hostId == userId
    }
    
    /// Get current user's player data
    var myPlayer: OnlinePlayer? {
        guard let userId = userId else { return nil }
        return players.first { $0.oderId == userId }
    }
    
    /// Check if current user is Råttmannen
    var isRattmannen: Bool {
        return myPlayer?.secretRole == .smittobarare
    }
    
    // MARK: - Round Helper Properties
    
    /// Get all alive players
    var alivePlayers: [OnlinePlayer] {
        players.filter { $0.isAlive }
    }
    
    /// Get players that can be voted for (excludes protected player)
    var votableTargets: [OnlinePlayer] {
        alivePlayers.filter { $0.oderId != currentLobby?.protectedPlayerId }
    }
    
    /// Get players that Läkare can cure (excludes self)
    var cureTargets: [OnlinePlayer] {
        guard let lakareId = currentLobby?.lakareId else { return alivePlayers }
        return alivePlayers.filter { $0.oderId != lakareId }
    }
    
    /// Get players that Väktare can protect (excludes self)
    var protectionTargets: [OnlinePlayer] {
        guard let vaktareId = currentLobby?.vaktareId else { return alivePlayers }
        return alivePlayers.filter { $0.oderId != vaktareId }
    }
    
    /// Get the protected player's name
    var protectedPlayerName: String {
        guard let protectedId = currentLobby?.protectedPlayerId,
              let player = players.first(where: { $0.oderId == protectedId }) else {
            return "?"
        }
        return player.name
    }
    
    /// Check if all round votes are in
    var allRoundVotesIn: Bool {
        guard let lobby = currentLobby else { return false }
        return lobby.roundVotes.count >= alivePlayers.count
    }
    
    /// Check if current user has voted in this round
    func hasVotedInRound() -> Bool {
        guard let oderId = userId,
              let lobby = currentLobby else { return false }
        return lobby.roundVotes[oderId] != nil
    }
    
    // MARK: - Round Actions
    
    /// Väktare selects who to protect
    func vaktareProtect(playerId: String) async throws {
        guard let lobbyId = currentLobby?.id,
              isVaktare else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endast Väktaren kan skydda"])
        }
        
        // Verify target is valid (alive, not self)
        guard protectionTargets.contains(where: { $0.oderId == playerId }) else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ogiltig spelare"])
        }
        
        let updates: [String: Any] = [
            "roundState/protectedPlayerId": playerId,
            "roundSubPhase": "cure"  // Move to cure phase
        ]
        
        try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        print("✅ Väktare protected: \(playerId)")
    }
    
    /// Läkare cures a player
    func lakareCure(playerId: String) async throws {
        guard let lobbyId = currentLobby?.id,
              isLakare else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endast Läkaren kan bota"])
        }
        
        // Verify target is valid (alive, not self)
        guard cureTargets.contains(where: { $0.oderId == playerId }) else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ogiltig spelare"])
        }
        
        // Check if target is infected
        let targetPlayer = players.first { $0.oderId == playerId }
        let wasInfected = targetPlayer?.secretRole == .infekterad
        let cureResult = wasInfected ? "success" : "noEffect"
        
        var updates: [String: Any] = [
            "roundState/cureTargetId": playerId,
            "roundState/cureResult": cureResult,
            "roundSubPhase": "voting"  // Move to voting phase
        ]
        
        // If successful, change player's role back to frisk
        if wasInfected {
            updates["players/\(playerId)/role"] = "frisk"
        }
        
        try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        print("✅ Läkare cured \(playerId), result: \(cureResult)")
    }
    
    /// Läkare skips cure
    func lakareSkip() async throws {
        guard let lobbyId = currentLobby?.id,
              isLakare else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endast Läkaren kan hoppa över"])
        }
        
        let updates: [String: Any] = [
            "roundState/cureTargetId": NSNull(),
            "roundState/cureResult": "skipped",
            "roundSubPhase": "voting"  // Move to voting phase
        ]
        
        try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        print("✅ Läkare skipped cure")
    }
    
    /// Cast a vote for exile (or infection for Råttmannen)
    func castRoundVote(forPlayerId targetId: String) async throws {
        guard let lobbyId = currentLobby?.id,
              let oderId = userId else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Inte i en lobby"])
        }
        
        // Verify target is valid (alive, not protected)
        guard votableTargets.contains(where: { $0.oderId == targetId }) else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Denna spelare kan inte röstas på"])
        }
        
        // Store the vote
        var updates: [String: Any] = [
            "roundState/votes/\(oderId)": targetId
        ]
        
        // If Råttmannen, also store the infection target (hidden from others)
        if isRattmannen {
            updates["roundState/rattmannenTarget"] = targetId
        }
        
        try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        print("✅ Vote cast for \(targetId)")
        
        // Check if all votes are in
        await checkAndResolveRound()
    }
    
    /// Check if all votes are in and resolve the round (host only)
    private func checkAndResolveRound() async {
        guard let lobby = currentLobby,
              isHost else { return }
        
        // Check if all alive players have voted
        let expectedVotes = alivePlayers.count
        let actualVotes = lobby.roundVotes.count
        
        guard actualVotes >= expectedVotes else {
            print("⏳ Waiting for more votes: \(actualVotes)/\(expectedVotes)")
            return
        }
        
        // Move to resolution phase
        do {
            try await database.child("lobbies/\(lobby.id)/roundSubPhase").setValue("resolution")
        } catch {
            print("❌ Failed to move to resolution: \(error)")
        }
    }
    
    /// Resolve the round - determine exile, apply infection, check win conditions
    func resolveRound() async throws {
        guard let lobbyId = currentLobby?.id,
              let lobby = currentLobby,
              isHost else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endast värden kan avsluta rundan"])
        }
        
        // Tally votes (excluding Råttmannen's vote which doesn't count for exile)
        var voteCounts: [String: Int] = [:]
        for (voterId, targetId) in lobby.roundVotes {
            // Check if voter is Råttmannen - their vote doesn't count for exile
            let voter = players.first { $0.oderId == voterId }
            if voter?.secretRole != .smittobarare {
                voteCounts[targetId, default: 0] += 1
            }
        }
        
        // Find the player with most votes
        let maxVotes = voteCounts.values.max() ?? 0
        let topVoted = voteCounts.filter { $0.value == maxVotes }.map { $0.key }
        
        var updates: [String: Any] = [:]
        var exiledId: String? = nil
        
        // Only exile if there's a clear winner (no tie) and at least 1 vote
        if topVoted.count == 1 && maxVotes > 0 {
            exiledId = topVoted[0]
            updates["roundState/exiledPlayerId"] = exiledId!
            updates["players/\(exiledId!)/isAlive"] = false
            print("⚖️ Exiled: \(exiledId!)")
        } else {
            updates["roundState/exiledPlayerId"] = NSNull()
            print("⚖️ No one exiled (tie or no votes)")
        }
        
        // Apply Råttmannen's infection (if target wasn't exiled)
        if let infectionTarget = lobby.rattmannenTarget,
           infectionTarget != exiledId {
            // Check if target is protected
            if infectionTarget != lobby.protectedPlayerId {
                // Infect the target (change role to infekterad, unless they're Råttmannen)
                let target = players.first { $0.oderId == infectionTarget }
                if target?.secretRole != .smittobarare {
                    updates["players/\(infectionTarget)/role"] = "infekterad"
                    print("🐀 Infected: \(infectionTarget)")
                }
            } else {
                print("🛡️ Infection blocked by protection")
            }
        }
        
        try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        
        // Check win conditions
        await checkWinConditions()
    }
    
    /// Check if the game has ended
    private func checkWinConditions() async {
        guard let lobbyId = currentLobby?.id,
              isHost else { return }
        
        // Reload players to get updated roles
        let alivePlayers = self.alivePlayers
        
        // Check if Råttmannen was exiled
        let rattmannenAlive = alivePlayers.contains { $0.secretRole == .smittobarare }
        if !rattmannenAlive {
            // Friska win!
            do {
                try await database.child("lobbies/\(lobbyId)").updateChildValues([
                    "gamePhase": "finished",
                    "gameResult": "friskaWin"
                ])
                print("🏆 Game Over: Friska Win!")
            } catch {
                print("❌ Failed to set game result: \(error)")
            }
            return
        }
        
        // Check if all remaining alive players are infected or Råttmannen
        let healthyPlayers = alivePlayers.filter { $0.secretRole == .frisk }
        if healthyPlayers.isEmpty {
            // Råttmannen wins!
            do {
                try await database.child("lobbies/\(lobbyId)").updateChildValues([
                    "gamePhase": "finished",
                    "gameResult": "rattmannenWin"
                ])
                print("🏆 Game Over: Råttmannen Win!")
            } catch {
                print("❌ Failed to set game result: \(error)")
            }
            return
        }
        
        // Game continues
        print("🎮 Game continues - \(alivePlayers.count) alive, \(healthyPlayers.count) healthy")
    }
    
    /// Start the next round
    func startNextRound() async throws {
        guard let lobbyId = currentLobby?.id,
              let lobby = currentLobby,
              isHost else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endast värden kan starta nästa runda"])
        }
        
        let nextRound = lobby.round + 1
        
        // Determine next roller (rotate through alive players by join order)
        let nextRollerId = getNextRoller(currentRollerId: lobby.currentRollerId)
        
        let updates: [String: Any] = [
            "round": nextRound,
            "roundSubPhase": "diceRoll",
            "roundState": [
                "protectedPlayerId": NSNull(),
                "cureTargetId": NSNull(),
                "cureResult": NSNull(),
                "votes": [:] as [String: String],
                "rattmannenTarget": NSNull(),
                "exiledPlayerId": NSNull()
            ] as [String: Any],
            "diceState": [
                "currentRollerId": nextRollerId,
                "diceResult": NSNull(),
                "diceEvent": NSNull(),
                "diceEventResolved": false,
                "quarantinedPlayerIds": [] as [String],
                "prophecyType": NSNull(),
                "prophecyTarget": NSNull(),
                "prophecyResult": NSNull(),
                "epidemicVictimId": NSNull(),
                "skipCurePhase": false
            ] as [String: Any]
        ]
        
        try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        print("✅ Started round \(nextRound), roller: \(nextRollerId)")
    }
    
    /// Get the next roller in rotation (by player order)
    private func getNextRoller(currentRollerId: String?) -> String {
        let alivePlayers = self.alivePlayers
        guard !alivePlayers.isEmpty else { return currentLobby?.hostId ?? "" }
        
        // If no current roller, start with host
        guard let currentId = currentRollerId else {
            return currentLobby?.hostId ?? alivePlayers[0].oderId
        }
        
        // Find current roller's index
        if let currentIndex = alivePlayers.firstIndex(where: { $0.oderId == currentId }) {
            // Get next player (wrap around)
            let nextIndex = (currentIndex + 1) % alivePlayers.count
            return alivePlayers[nextIndex].oderId
        } else {
            // Current roller not found (maybe died), start from beginning
            return alivePlayers[0].oderId
        }
    }
    
    /// Get vote counts for resolution display
    func getVoteCounts() -> [(player: OnlinePlayer, count: Int)] {
        guard let lobby = currentLobby else { return [] }
        
        var counts: [String: Int] = [:]
        for (voterId, targetId) in lobby.roundVotes {
            // Exclude Råttmannen's vote from count
            let voter = players.first { $0.oderId == voterId }
            if voter?.secretRole != .smittobarare {
                counts[targetId, default: 0] += 1
            }
        }
        
        return counts.compactMap { id, count in
            guard let player = players.first(where: { $0.oderId == id }) else { return nil }
            return (player, count)
        }.sorted { $0.count > $1.count }
    }
    
    // MARK: - Dice Methods
    
    /// Check if current user is the dice roller this round
    var isCurrentRoller: Bool {
        guard let oderId = userId,
              let rollerId = currentLobby?.currentRollerId else { return false }
        return oderId == rollerId
    }
    
    /// Get the current roller player
    var currentRoller: OnlinePlayer? {
        guard let rollerId = currentLobby?.currentRollerId else { return nil }
        return players.first { $0.oderId == rollerId }
    }
    
    /// Check if player is quarantined
    func isQuarantined(playerId: String) -> Bool {
        return currentLobby?.quarantinedPlayerIds.contains(playerId) ?? false
    }
    
    /// Check if current user is quarantined
    var amIQuarantined: Bool {
        guard let oderId = userId else { return false }
        return isQuarantined(playerId: oderId)
    }
    
    /// Submit the dice roll result (roller only)
    func submitDiceResult(result: Int) async throws {
        guard let lobbyId = currentLobby?.id,
              isCurrentRoller else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endast tärningskastaren kan skicka resultatet"])
        }
        
        let event = GameLobby.DiceEventType.from(roll: result)
        
        var updates: [String: Any] = [
            "diceState/diceResult": result,
            "diceState/diceEvent": event.rawValue,
            "roundSubPhase": "diceEvent"
        ]
        
        // For Blackout, set skipCurePhase immediately
        if event == .blackout {
            updates["diceState/skipCurePhase"] = true
        }
        
        // For Epidemic, select a random victim immediately
        if event == .epidemic {
            let healthyPlayers = alivePlayers.filter { $0.secretRole == .frisk }
            if let victim = healthyPlayers.randomElement() {
                updates["diceState/epidemicVictimId"] = victim.oderId
                updates["players/\(victim.oderId)/role"] = "infekterad"
            }
        }
        
        try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        print("✅ Dice result: \(result) - Event: \(event.displayName)")
    }
    
    /// Handle Antidote event - cure a player immediately (roller only)
    func handleAntidoteEvent(targetPlayerId: String) async throws {
        guard let lobbyId = currentLobby?.id,
              isCurrentRoller else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endast tärningskastaren kan använda motgiftet"])
        }
        
        // Check if target is infected
        let target = players.first { $0.oderId == targetPlayerId }
        let wasInfected = target?.secretRole == .infekterad
        let cureResult = wasInfected ? "success" : "noEffect"
        
        var updates: [String: Any] = [
            "diceState/diceEventResolved": true,
            "diceState/prophecyResult": cureResult  // Reusing this field to store antidote result
        ]
        
        // If successful, change role back to frisk
        if wasInfected {
            updates["players/\(targetPlayerId)/role"] = "frisk"
        }
        
        try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        print("✅ Antidote used on \(targetPlayerId), result: \(cureResult)")
    }
    
    /// Handle Prophecy event - choose count or investigate (roller only)
    func handleProphecyChoice(type: String, targetPlayerId: String? = nil) async throws {
        guard let lobbyId = currentLobby?.id,
              isCurrentRoller else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endast tärningskastaren kan använda spådomen"])
        }
        
        var updates: [String: Any] = [
            "diceState/prophecyType": type,
            "diceState/diceEventResolved": true
        ]
        
        if type == "count" {
            // Count infected players (including Råttmannen)
            let infectedCount = alivePlayers.filter { 
                $0.secretRole == .smittobarare || $0.secretRole == .infekterad 
            }.count
            updates["diceState/prophecyResult"] = "\(infectedCount)"
        } else if type == "investigate", let targetId = targetPlayerId {
            // Check if target is infected or Råttmannen
            let target = players.first { $0.oderId == targetId }
            let isInfected = target?.secretRole == .smittobarare || target?.secretRole == .infekterad
            updates["diceState/prophecyTarget"] = targetId
            updates["diceState/prophecyResult"] = isInfected ? "ja" : "nej"
        }
        
        try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        print("✅ Prophecy used: \(type)")
    }
    
    /// Handle Quarantine event - select 2 players to silence (roller only)
    func handleQuarantineSelection(playerIds: [String]) async throws {
        guard let lobbyId = currentLobby?.id,
              isCurrentRoller else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endast tärningskastaren kan välja karantän"])
        }
        
        guard playerIds.count == 2 else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Du måste välja exakt 2 spelare"])
        }
        
        let updates: [String: Any] = [
            "diceState/quarantinedPlayerIds": playerIds,
            "diceState/diceEventResolved": true
        ]
        
        try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        print("✅ Quarantine: \(playerIds)")
    }
    
    /// Proceed from dice event to next phase (roller or host)
    func proceedFromDiceEvent() async throws {
        guard let lobbyId = currentLobby?.id,
              let lobby = currentLobby,
              isCurrentRoller || isHost else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Endast tärningskastaren kan fortsätta"])
        }
        
        // Mark event as resolved if not already
        var updates: [String: Any] = [
            "diceState/diceEventResolved": true
        ]
        
        // Move to protection phase
        updates["roundSubPhase"] = "protection"
        
        try await database.child("lobbies/\(lobbyId)").updateChildValues(updates)
        print("✅ Proceeding from dice event to protection phase")
    }
    
    /// Get eligible voters (excludes quarantined players)
    var eligibleVoters: [OnlinePlayer] {
        alivePlayers.filter { !isQuarantined(playerId: $0.oderId) }
    }
    
    /// Skip cure phase and go to voting (used for Blackout)
    func skipToVotingPhase() async throws {
        guard let lobbyId = currentLobby?.id,
              isHost else { return }
        
        try await database.child("lobbies/\(lobbyId)/roundSubPhase").setValue("voting")
        print("✅ Skipped to voting phase (Blackout)")
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        leaveLobby()
        
        if let handle = connectedObserverHandle {
            connectedRef?.removeObserver(withHandle: handle)
        }
        
        presenceRef?.removeValue()
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - Preview Helper

#if DEBUG
extension FirebaseMultiplayerManager {
    static var preview: FirebaseMultiplayerManager {
        let manager = FirebaseMultiplayerManager()
        manager.isAuthenticated = true
        manager.userId = "preview-user-123"
        manager.connectionState = .connected
        manager.players = [
            OnlinePlayer(oderId: "1", name: "Erik", avatarId: "man-65", isHost: true),
            OnlinePlayer(oderId: "2", name: "Helena", avatarId: "kvinna-30"),
            OnlinePlayer(oderId: "3", name: "Gustav", avatarId: "man-60")
        ]
        return manager
    }
}
#endif
