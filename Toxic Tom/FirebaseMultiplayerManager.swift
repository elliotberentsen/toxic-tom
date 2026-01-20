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
    
    var id: String { oderId }
    
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
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "avatarId": avatarId,
            "status": status.rawValue,
            "isHost": isHost,
            "lastSeen": ServerValue.timestamp()
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
    
    enum OnlineGamePhase: String, Codable {
        case waiting = "waiting"
        case starting = "starting"
        case roleReveal = "roleReveal"
        case playing = "playing"
        case finished = "finished"
    }
    
    init(id: String, code: String, hostId: String, maxPlayers: Int = 8) {
        self.id = id
        self.code = code
        self.hostId = hostId
        self.players = []
        self.gamePhase = .waiting
        self.maxPlayers = maxPlayers
        self.createdAt = Date().timeIntervalSince1970
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
        
        // Parse players
        var parsedPlayers: [OnlinePlayer] = []
        if let playersDict = dict["players"] as? [String: [String: Any]] {
            for (oderId, playerData) in playersDict {
                if let player = OnlinePlayer(from: playerData, oderId: oderId) {
                    parsedPlayers.append(player)
                }
            }
        }
        self.players = parsedPlayers.sorted { $0.lastSeen < $1.lastSeen }
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
                self.currentLobby = lobby
                self.players = lobby.players
                
                // Track disconnected players
                self.disconnectedPlayers = lobby.players
                    .filter { $0.status != .online }
                    .map { $0.name }
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
        
        guard lobby.players.count >= 3 else {
            throw NSError(domain: "Firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Minst 3 spelare krävs"])
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
