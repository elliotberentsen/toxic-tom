//
//  GameCenterManager.swift
//  Toxic Tom
//
//  Handles Game Center authentication and multiplayer
//

import GameKit
import SwiftUI
import Combine

class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()
    
    // MARK: - Published State
    
    @Published var isAuthenticated = false
    @Published var playerName: String = "Not signed in"
    @Published var authenticationError: String?
    
    // For multiplayer (we'll add more later)
    @Published var isMatchmaking = false
    @Published var currentMatch: GKMatch?
    @Published var connectedPlayers: [GKPlayer] = []
    @Published var connectionStatus: String = ""
    
    // MARK: - Init
    
    private override init() {
        super.init()
    }
    
    // MARK: - Authentication
    
    /// Call this when the app launches to authenticate with Game Center
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                if let error = error {
                    // Authentication failed
                    self?.authenticationError = error.localizedDescription
                    self?.isAuthenticated = false
                    self?.playerName = "Not signed in"
                    print("❌ Game Center auth failed: \(error.localizedDescription)")
                    return
                }
                
                if let viewController = viewController {
                    // Need to present Game Center login UI
                    self?.presentAuthenticationViewController(viewController)
                    return
                }
                
                if GKLocalPlayer.local.isAuthenticated {
                    // Successfully authenticated!
                    self?.isAuthenticated = true
                    self?.playerName = GKLocalPlayer.local.displayName
                    self?.authenticationError = nil
                    print("✅ Game Center authenticated: \(GKLocalPlayer.local.displayName)")
                } else {
                    // Player is not authenticated and no view controller was provided
                    self?.isAuthenticated = false
                    self?.playerName = "Not signed in"
                    print("⚠️ Game Center: Not authenticated, no login UI provided")
                }
            }
        }
    }
    
    private func presentAuthenticationViewController(_ viewController: UIViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Could not find root view controller to present Game Center login")
            return
        }
        
        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        topController.present(viewController, animated: true)
    }
    
    // MARK: - Access Dashboard
    
    /// Shows the Game Center dashboard overlay
    func showDashboard() {
        guard isAuthenticated else {
            print("Cannot show dashboard - not authenticated")
            return
        }
        
        let dashboard = GKGameCenterViewController(state: .dashboard)
        dashboard.gameCenterDelegate = self
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(dashboard, animated: true)
        }
    }
}

// MARK: - GKGameCenterControllerDelegate

extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}

// MARK: - Preview Helper

#if DEBUG
extension GameCenterManager {
    static var preview: GameCenterManager {
        let manager = GameCenterManager()
        manager.isAuthenticated = true
        manager.playerName = "TestPlayer123"
        return manager
    }
}
#endif
