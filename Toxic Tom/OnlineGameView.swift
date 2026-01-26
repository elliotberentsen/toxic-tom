//
//  OnlineGameView.swift
//  Toxic Tom
//
//  Online multiplayer game flow with Firebase
//

import SwiftUI

// MARK: - Online Game Phase

enum OnlineViewPhase {
    case menu              // Choose create or join
    case createLobby       // Enter name/avatar to create
    case joinLobby         // Enter code + name/avatar to join
    case lobby             // In lobby waiting for players
    case roleReveal        // Seeing your role
    case electionLakare    // Voting for Läkare
    case electionVaktare   // Voting for Väktare
    case round             // Active round (protection, cure, voting, resolution)
    case gameOver          // Game finished
}

// MARK: - Main Online Game View

struct OnlineGameView: View {
    let onExit: () -> Void
    
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var phase: OnlineViewPhase = .menu
    @State private var isAuthenticating = false
    @State private var showError = false
    
    var body: some View {
        ZStack {
            switch phase {
            case .menu:
                OnlineMenuView(
                    onCreateLobby: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            phase = .createLobby
                        }
                    },
                    onJoinLobby: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            phase = .joinLobby
                        }
                    },
                    onBack: onExit
                )
                .transition(.opacity)
                
            case .createLobby:
                CreateLobbyView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            phase = .menu
                        }
                    },
                    onLobbyCreated: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            phase = .lobby
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
            case .joinLobby:
                JoinLobbyView(
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            phase = .menu
                        }
                    },
                    onJoined: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            phase = .lobby
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
            case .lobby:
                LobbyWaitingView(
                    onBack: {
                        firebase.leaveLobby()
                        withAnimation(.easeInOut(duration: 0.4)) {
                            phase = .menu
                        }
                    },
                    onGameStart: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            phase = .roleReveal
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
            case .roleReveal:
                OnlineRoleRevealView(
                    onContinue: {
                        // Host starts the election after confirming role
                        if firebase.isHost {
                            Task {
                                try? await firebase.startLakareElection()
                            }
                        }
                        // Phase will transition via Firebase observer
                    }
                )
                .transition(.opacity)
                
            case .electionLakare:
                ElectionView(electionType: .lakare)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
            case .electionVaktare:
                ElectionView(electionType: .vaktare)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
            case .round:
                OnlineRoundView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
            case .gameOver:
                OnlineGameOverView(
                    onPlayAgain: {
                        firebase.leaveLobby()
                        withAnimation(.easeInOut(duration: 0.4)) {
                            phase = .menu
                        }
                    },
                    onExit: {
                        firebase.leaveLobby()
                        withAnimation(.easeInOut(duration: 0.4)) {
                            phase = .menu
                        }
                    }
                )
                .transition(.opacity)
            }
            
            // Loading overlay
            if isAuthenticating || firebase.isLoading {
                LoadingOverlay(message: "Ansluter...")
            }
            
            // Error banner
            if let error = firebase.errorMessage {
                VStack {
                    ErrorBanner(message: error) {
                        firebase.errorMessage = nil
                    }
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .texturedBackground()
        .animation(.easeInOut(duration: 0.4), value: phase)
        .task {
            // Authenticate on appear if not already
            if !firebase.isAuthenticated {
                await authenticateIfNeeded()
            }
        }
        .onChange(of: firebase.currentLobby?.gamePhase) { newPhase in
            // React to game phase changes from Firebase
            guard let newPhase = newPhase else { return }
            
            withAnimation(.easeInOut(duration: 0.4)) {
                switch newPhase {
                case .roleReveal:
                    if phase == .lobby {
                        phase = .roleReveal
                    }
                case .electionLakare:
                    phase = .electionLakare
                case .electionVaktare:
                    phase = .electionVaktare
                case .round:
                    phase = .round
                case .finished:
                    phase = .gameOver
                default:
                    break
                }
            }
        }
    }
    
    private func authenticateIfNeeded() async {
        guard !firebase.isAuthenticated else { return }
        
        await MainActor.run { isAuthenticating = true }
        
        // Add timeout for authentication
        let authTask = Task {
            try await firebase.signInAnonymously()
        }
        
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            authTask.cancel()
        }
        
        do {
            try await authTask.value
            timeoutTask.cancel()
            print("✅ Authentication successful")
        } catch {
            print("❌ Auth failed: \(error)")
            await MainActor.run {
                firebase.errorMessage = "Kunde inte ansluta till servern. Kontrollera din internetanslutning."
            }
        }
        
        await MainActor.run { isAuthenticating = false }
    }
}

// MARK: - Online Menu View

struct OnlineMenuView: View {
    let onCreateLobby: () -> Void
    let onJoinLobby: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            AppColors.parchment
                .ignoresSafeArea()
            
            Image("egg-shell")
                .resizable(resizingMode: .tile)
                .ignoresSafeArea()
            
            DustParticlesView()
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        SoundManager.shared.playClick()
                        onBack()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .medium))
                            Text("Tillbaka")
                                .font(.custom("Georgia", size: 14))
                        }
                        .foregroundColor(AppColors.inkDark.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppColors.inkDark.opacity(0.06))
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Central content area - framed like a manuscript page
                VStack(spacing: 0) {
                    // Smittobarare in a subtle frame
                    ZStack {
                        // Subtle vignette behind image
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [AppColors.warmBrown.opacity(0.08), Color.clear],
                                    center: .center,
                                    startRadius: 60,
                                    endRadius: 160
                                )
                            )
                            .frame(width: 320, height: 320)
                        
                        Image("smittobarare")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 240)
                    }
                    
                    Spacer()
                        .frame(height: 24)
                    
                    // Title - manuscript style
                    VStack(spacing: 12) {
                        // Decorative line above
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(AppColors.warmBrown.opacity(0.3))
                                .frame(width: 40, height: 1)
                            
                            // Diamond ornament
                            Rectangle()
                                .fill(AppColors.warmBrown.opacity(0.4))
                                .frame(width: 6, height: 6)
                                .rotationEffect(.degrees(45))
                            
                            Rectangle()
                                .fill(AppColors.warmBrown.opacity(0.3))
                                .frame(width: 40, height: 1)
                        }
                        
                        Text("Spela Online")
                            .font(.custom("Georgia-Bold", size: 24))
                            .foregroundColor(AppColors.inkDark)
                        
                        // Decorative line below
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(AppColors.warmBrown.opacity(0.3))
                                .frame(width: 40, height: 1)
                            
                            Rectangle()
                                .fill(AppColors.warmBrown.opacity(0.4))
                                .frame(width: 6, height: 6)
                                .rotationEffect(.degrees(45))
                            
                            Rectangle()
                                .fill(AppColors.warmBrown.opacity(0.3))
                                .frame(width: 40, height: 1)
                        }
                    }
                    
                    Spacer()
                        .frame(height: 32)
                    
                    // Action buttons - medieval panel style
                    VStack(spacing: 12) {
                        MedievalPanelButton(
                            title: "Skapa Lobby",
                            subtitle: "Bjud in dina vänner",
                            isPrimary: true,
                            action: onCreateLobby
                        )
                        
                        MedievalPanelButton(
                            title: "Gå med",
                            subtitle: "Ange en lobbykod",
                            isPrimary: false,
                            action: onJoinLobby
                        )
                    }
                    .padding(.horizontal, 32)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Create Lobby View

struct CreateLobbyView: View {
    let onBack: () -> Void
    let onLobbyCreated: () -> Void
    
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var playerName = ""
    @State private var selectedAvatar: CharacterAvatar?
    @State private var previewAvatar: CharacterAvatar?
    @State private var showNameError = false
    @State private var isCreating = false
    @FocusState private var isNameFocused: Bool
    
    // Step in the creation flow
    enum CreateStep {
        case name
        case character
    }
    
    @State private var step: CreateStep = .name
    
    // Column definitions will be created dynamically based on screen width
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Fixed header
                HStack {
                    Button(action: {
                        SoundManager.shared.playClick()
                        if step == .character {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                step = .name
                            }
                        } else {
                            onBack()
                        }
                    }) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Tillbaka")
                                .font(AppFonts.bodyMedium())
                        }
                        .foregroundColor(AppColors.warmBrown)
                    }
                    Spacer()
                    
                    // Step indicator
                    Text(step == .name ? "1 / 2" : "2 / 2")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.inkMedium)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(
                            Capsule()
                                .fill(AppColors.warmBrown.opacity(0.1))
                        )
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)
                
                // Content area - MUST fill remaining space
                Group {
                    if step == .name {
                        nameStepView
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        characterStepView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Full-screen character confirmation overlay - covers entire view including header
            if let avatar = previewAvatar {
                CharacterConfirmationOverlay(
                    avatar: avatar,
                    isLoading: isCreating,
                    confirmButtonText: "Skapa Lobby",
                    onConfirm: {
                        selectedAvatar = avatar
                        Task {
                            await createLobby()
                        }
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            previewAvatar = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .onChange(of: playerName) { _ in
            if showNameError { showNameError = false }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }
    
    // MARK: - Step 1: Name
    private var nameStepView: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Spacer to push content down slightly
                    Spacer()
                        .frame(height: geometry.size.height * 0.08)
                    
                    // Small thematic icon - subtle, not dominant
                    Image("smittobarare")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)
                        .opacity(0.9)
                    
                    // Main heading
                    Text("Skapa Lobby")
                        .font(.custom("Georgia-Bold", size: 28))
                        .foregroundColor(AppColors.inkDark)
                        .padding(.top, AppSpacing.lg)
                    
                    // Decorative divider
                    OrnamentDivider(width: 60, color: AppColors.warmBrown.opacity(0.4))
                        .padding(.top, AppSpacing.sm)
                    
                    // The question - prominent
                    Text("Vad heter du?")
                        .font(.custom("Georgia", size: 18))
                        .foregroundColor(AppColors.inkMedium)
                        .padding(.top, AppSpacing.xxl)
                    
                    // Text field - the star of the show
                    TextField("Ditt namn", text: $playerName)
                        .font(.custom("Georgia", size: 28))
                        .foregroundColor(AppColors.inkDark)
                        .multilineTextAlignment(.center)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .focused($isNameFocused)
                        .padding(.vertical, AppSpacing.lg)
                        .padding(.horizontal, AppSpacing.md)
                        .background(
                            VStack(spacing: 0) {
                                Spacer()
                                Rectangle()
                                    .fill(showNameError ? AppColors.coralRed : AppColors.warmBrown.opacity(0.4))
                                    .frame(height: 2)
                            }
                        )
                        .padding(.horizontal, AppSpacing.xxl)
                        .padding(.top, AppSpacing.md)
                    
                    // Error message
                    if showNameError {
                        Text("Ange ditt namn för att fortsätta")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.coralRed)
                            .padding(.top, AppSpacing.sm)
                    }
                    
                    // Spacer to push button down
                    Spacer()
                        .frame(height: geometry.size.height * 0.15)
                }
                .frame(minHeight: geometry.size.height - 100) // Account for button
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Fixed bottom button - medieval panel style
            let hasName = !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            Button(action: {
                let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    showNameError = true
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    return
                }
                SoundManager.shared.playClick()
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                isNameFocused = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = .character
                }
            }) {
                ZStack {
                    // Panel background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hasName ? Color(hex: "f5edd8") : Color(hex: "e8e0d0"))
                        .shadow(color: Color.black.opacity(hasName ? 0.12 : 0.06), radius: 4, y: 3)
                    
                    // Double border
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppColors.warmBrown.opacity(hasName ? 0.6 : 0.3), lineWidth: 1.5)
                    
                    // Inner border
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(AppColors.warmBrown.opacity(hasName ? 0.2 : 0.1), lineWidth: 0.5)
                        .padding(4)
                    
                    // Corner ornaments
                    if hasName {
                        VStack {
                            HStack {
                                CornerOrnamentSmall()
                                Spacer()
                                CornerOrnamentSmall()
                                    .rotationEffect(.degrees(90))
                            }
                            Spacer()
                            HStack {
                                CornerOrnamentSmall()
                                    .rotationEffect(.degrees(-90))
                                Spacer()
                                CornerOrnamentSmall()
                                    .rotationEffect(.degrees(180))
                            }
                        }
                        .padding(6)
                    }
                    
                    // Content
                    HStack(spacing: AppSpacing.sm) {
                        Text("Välj karaktär")
                            .font(.custom("Georgia-Bold", size: 18))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(hasName ? AppColors.inkDark : AppColors.inkMedium)
                }
                .frame(height: 56)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.md)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isNameFocused = true
            }
        }
    }
    
    // MARK: - Step 2: Character Selection
    private var characterStepView: some View {
        VStack(spacing: 0) {
            // Title - compact at top
            VStack(spacing: 4) {
                Text("Välj karaktär")
                    .font(AppFonts.displayMedium())
                    .foregroundColor(AppColors.inkDark)
                
                OrnamentDivider(width: 60, color: AppColors.warmBrown.opacity(0.4))
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
            
            // Character grid - 2 columns with names
            GeometryReader { geometry in
                let spacing: CGFloat = AppSpacing.md
                let horizontalPadding: CGFloat = AppSpacing.lg
                let availableWidth = geometry.size.width - (horizontalPadding * 2)
                let cardWidth = (availableWidth - spacing) / 2
                let cardHeight = cardWidth / CharacterAvatar.cardAspectRatio
                
                let columns = [
                    GridItem(.fixed(cardWidth), spacing: spacing),
                    GridItem(.fixed(cardWidth), spacing: spacing)
                ]
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: AppSpacing.lg) {
                        ForEach(CharacterAvatar.allAvatars) { avatar in
                            VStack(spacing: AppSpacing.xs) {
                                Image(avatar.imageName)
                                    .resizable()
                                    .aspectRatio(CharacterAvatar.cardAspectRatio, contentMode: .fit)
                                    .frame(width: cardWidth, height: cardHeight)
                                    .contentShape(Rectangle())
                                
                                Text(avatar.displayName)
                                    .font(AppFonts.bodySmall())
                                    .foregroundColor(AppColors.inkMedium)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.7)
                            }
                            .onTapGesture {
                                SoundManager.shared.playClick()
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    previewAvatar = avatar
                                }
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 100)
                }
            }
        }
    }
    
    private var canCreate: Bool {
        !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedAvatar != nil
    }
    
    private func createLobby() async {
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showNameError = true
            return
        }
        
        guard let avatar = selectedAvatar else { return }
        
        isCreating = true
        
        // Ensure we're authenticated first
        if !firebase.isAuthenticated {
            do {
                try await firebase.signInAnonymously()
            } catch {
                print("❌ Auth failed: \(error)")
                await MainActor.run {
                    firebase.errorMessage = "Kunde inte ansluta. Kontrollera din internetanslutning."
                    isCreating = false
                }
                return
            }
        }
        
        do {
            _ = try await firebase.createLobby(playerName: trimmedName, avatarId: avatar.id)
            await MainActor.run {
                SoundManager.shared.playClick()
                onLobbyCreated()
            }
        } catch {
            print("❌ Create lobby failed: \(error)")
            await MainActor.run {
                firebase.errorMessage = "Kunde inte skapa lobby: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isCreating = false
        }
    }
}

// MARK: - Join Lobby View

struct JoinLobbyView: View {
    let onBack: () -> Void
    let onJoined: () -> Void
    
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var lobbyCode = ""
    @State private var playerName = ""
    @State private var selectedAvatar: CharacterAvatar?
    @State private var previewAvatar: CharacterAvatar?
    @State private var showCodeError = false
    @State private var showNameError = false
    @State private var isJoining = false
    @FocusState private var focusedField: JoinField?
    
    enum JoinField {
        case code, name
    }
    
    // Step in join flow
    enum JoinStep {
        case codeAndName
        case character
    }
    
    @State private var step: JoinStep = .codeAndName
    
    // Column definitions will be created dynamically based on screen width
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Fixed header
                HStack {
                    Button(action: {
                        SoundManager.shared.playClick()
                        if step == .character {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                step = .codeAndName
                            }
                        } else {
                            onBack()
                        }
                    }) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Tillbaka")
                                .font(AppFonts.bodyMedium())
                        }
                        .foregroundColor(AppColors.warmBrown)
                    }
                    Spacer()
                    
                    // Step indicator
                    Text(step == .codeAndName ? "1 / 2" : "2 / 2")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.inkMedium)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(
                            Capsule()
                                .fill(AppColors.warmBrown.opacity(0.1))
                            )
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)
                
                // Content area - MUST fill remaining space
                Group {
                    if step == .codeAndName {
                        codeAndNameStepView
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        characterStepView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Full-screen character confirmation overlay - covers entire view including header
            if let avatar = previewAvatar {
                CharacterConfirmationOverlay(
                    avatar: avatar,
                    isLoading: isJoining,
                    confirmButtonText: "Gå med",
                    onConfirm: {
                        selectedAvatar = avatar
                        Task {
                            await joinLobby()
                        }
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            previewAvatar = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }
    
    // MARK: - Step 1: Code and Name
    private var codeAndNameStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Visual anchor
                Image("smittobarare")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .padding(.top, AppSpacing.lg)
                
                // Title section
                VStack(spacing: AppSpacing.xs) {
                    Text("Gå med i Lobby")
                        .font(AppFonts.displayMedium())
                        .foregroundColor(AppColors.inkDark)
                    
                    OrnamentDivider(width: 80, color: AppColors.warmBrown.opacity(0.5))
                }
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
                
                // Lobby code input - prominent
                VStack(spacing: AppSpacing.sm) {
                    Text("Lobbykod")
                        .font(.custom("Georgia-Bold", size: 18))
                        .foregroundColor(AppColors.inkDark)
                    
                    TextField("", text: $lobbyCode, prompt: Text("XXXXXX").foregroundColor(AppColors.inkMedium.opacity(0.4)))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.inkDark)
                        .multilineTextAlignment(.center)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .keyboardType(.asciiCapable)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: "f8f4e8"))
                                .shadow(color: AppColors.warmBrown.opacity(0.15), radius: 4, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(showCodeError ? AppColors.coralRed : AppColors.warmBrown.opacity(0.25), lineWidth: 1)
                        )
                        .focused($focusedField, equals: .code)
                        .onChange(of: lobbyCode) { newValue in
                            if newValue.count > 6 {
                                lobbyCode = String(newValue.prefix(6))
                            }
                            if showCodeError { showCodeError = false }
                        }
                    
                    if showCodeError {
                        Text("Ogiltig lobbykod")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.coralRed)
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                
                // Divider between sections
                HStack(spacing: AppSpacing.md) {
                    Rectangle()
                        .fill(AppColors.warmBrown.opacity(0.2))
                        .frame(height: 1)
                    Text("och")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.inkMedium.opacity(0.6))
                    Rectangle()
                        .fill(AppColors.warmBrown.opacity(0.2))
                        .frame(height: 1)
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.vertical, AppSpacing.lg)
                
                // Name input
                VStack(spacing: AppSpacing.sm) {
                    Text("Ditt namn")
                        .font(.custom("Georgia-Bold", size: 18))
                        .foregroundColor(AppColors.inkDark)
                    
                    TextField("", text: $playerName)
                        .font(.custom("Georgia", size: 22))
                        .foregroundColor(AppColors.inkDark)
                        .multilineTextAlignment(.center)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: "f8f4e8"))
                                .shadow(color: AppColors.warmBrown.opacity(0.15), radius: 4, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(showNameError ? AppColors.coralRed : AppColors.warmBrown.opacity(0.25), lineWidth: 1)
                        )
                        .focused($focusedField, equals: .name)
                    
                    if playerName.isEmpty {
                        Text("Skriv ditt namn")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.inkMedium.opacity(0.5))
                    }
                    
                    if showNameError {
                        Text("Du måste ange ett namn")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.coralRed)
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                
                // Context hint
                Text("Välj sedan din karaktär")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.inkMedium.opacity(0.6))
                    .padding(.bottom, AppSpacing.xl)
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Fixed bottom button - medieval panel style
            Button(action: {
                guard lobbyCode.count == 6 else {
                    showCodeError = true
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    return
                }
                let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    showNameError = true
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    return
                }
                SoundManager.shared.playClick()
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                focusedField = nil
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = .character
                }
            }) {
                ZStack {
                    // Panel background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(canProceed ? Color(hex: "f5edd8") : Color(hex: "e8e0d0"))
                        .shadow(color: Color.black.opacity(canProceed ? 0.12 : 0.06), radius: 4, y: 3)
                    
                    // Double border
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppColors.warmBrown.opacity(canProceed ? 0.6 : 0.3), lineWidth: 1.5)
                    
                    // Inner border
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(AppColors.warmBrown.opacity(canProceed ? 0.2 : 0.1), lineWidth: 0.5)
                        .padding(4)
                    
                    // Corner ornaments
                    if canProceed {
                        VStack {
                            HStack {
                                CornerOrnamentSmall()
                                Spacer()
                                CornerOrnamentSmall()
                                    .rotationEffect(.degrees(90))
                            }
                            Spacer()
                            HStack {
                                CornerOrnamentSmall()
                                    .rotationEffect(.degrees(-90))
                                Spacer()
                                CornerOrnamentSmall()
                                    .rotationEffect(.degrees(180))
                            }
                        }
                        .padding(6)
                    }
                    
                    // Content
                    HStack(spacing: AppSpacing.sm) {
                        Text("Fortsätt")
                            .font(.custom("Georgia-Bold", size: 18))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(canProceed ? AppColors.inkDark : AppColors.inkMedium)
                }
                .frame(height: 56)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = .code
            }
        }
    }
    
    private var canProceed: Bool {
        lobbyCode.count == 6 && !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Step 2: Character Selection
    private var characterStepView: some View {
        VStack(spacing: 0) {
            // Title - compact at top
            VStack(spacing: 4) {
                Text("Välj karaktär")
                    .font(AppFonts.displayMedium())
                    .foregroundColor(AppColors.inkDark)
                
                OrnamentDivider(width: 60, color: AppColors.warmBrown.opacity(0.4))
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
            
            // Character grid - 2 columns with names
            GeometryReader { geometry in
                let spacing: CGFloat = AppSpacing.md
                let horizontalPadding: CGFloat = AppSpacing.lg
                let availableWidth = geometry.size.width - (horizontalPadding * 2)
                let cardWidth = (availableWidth - spacing) / 2
                let cardHeight = cardWidth / CharacterAvatar.cardAspectRatio
                
                let columns = [
                    GridItem(.fixed(cardWidth), spacing: spacing),
                    GridItem(.fixed(cardWidth), spacing: spacing)
                ]
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: AppSpacing.lg) {
                        ForEach(CharacterAvatar.allAvatars) { avatar in
                            VStack(spacing: AppSpacing.xs) {
                                Image(avatar.imageName)
                                    .resizable()
                                    .aspectRatio(CharacterAvatar.cardAspectRatio, contentMode: .fit)
                                    .frame(width: cardWidth, height: cardHeight)
                                    .contentShape(Rectangle())
                                
                                Text(avatar.displayName)
                                    .font(AppFonts.bodySmall())
                                    .foregroundColor(AppColors.inkMedium)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.7)
                            }
                            .onTapGesture {
                                SoundManager.shared.playClick()
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    previewAvatar = avatar
                                }
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 100)
                }
            }
        }
    }
    
    private func joinLobby() async {
        guard lobbyCode.count == 6 else {
            showCodeError = true
            return
        }
        
        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showNameError = true
            return
        }
        
        guard let avatar = selectedAvatar else { return }
        
        isJoining = true
        
        // Ensure we're authenticated first
        if !firebase.isAuthenticated {
            do {
                try await firebase.signInAnonymously()
            } catch {
                print("❌ Auth failed: \(error)")
                await MainActor.run {
                    firebase.errorMessage = "Kunde inte ansluta. Kontrollera din internetanslutning."
                    isJoining = false
                }
                return
            }
        }
        
        do {
            try await firebase.joinLobby(code: lobbyCode, playerName: trimmedName, avatarId: avatar.id)
            await MainActor.run {
                SoundManager.shared.playClick()
                onJoined()
            }
        } catch {
            await MainActor.run {
                firebase.errorMessage = "Kunde inte gå med: \(error.localizedDescription)"
                showCodeError = true
            }
            print("❌ Join lobby failed: \(error)")
        }
        
        await MainActor.run {
            isJoining = false
        }
    }
}

// MARK: - Lobby Waiting View

struct LobbyWaitingView: View {
    let onBack: () -> Void
    let onGameStart: () -> Void
    
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var showCopiedFeedback = false
    @State private var isStarting = false
    
    var body: some View {
        ZStack {
            // Background - matching home/menu screens
            AppColors.parchment
                .ignoresSafeArea()
            
            Image("egg-shell")
                .resizable(resizingMode: .tile)
                .ignoresSafeArea()
            
            DustParticlesView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header - matching menu style
                HStack {
                    Button(action: {
                        SoundManager.shared.playClick()
                        onBack()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .medium))
                            Text("Lämna")
                                .font(.custom("Georgia", size: 14))
                        }
                        .foregroundColor(AppColors.inkDark.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppColors.inkDark.opacity(0.06))
                        )
                    }
                    
                    Spacer()
                    
                    // Connection status - subtle manuscript style
                    HStack(spacing: 6) {
                        Circle()
                            .fill(firebase.connectionState == .connected ? AppColors.oliveGreen : AppColors.warning)
                            .frame(width: 6, height: 6)
                        Text(firebase.connectionState.displayText)
                            .font(.custom("Georgia", size: 12))
                            .foregroundColor(AppColors.inkMedium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppColors.inkDark.opacity(0.04))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Lobby Code Section - medieval manuscript style
                VStack(spacing: 16) {
                    // Decorative header
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(AppColors.warmBrown.opacity(0.3))
                                .frame(width: 30, height: 1)
                            
                            Rectangle()
                                .fill(AppColors.warmBrown.opacity(0.4))
                                .frame(width: 5, height: 5)
                                .rotationEffect(.degrees(45))
                            
                            Rectangle()
                                .fill(AppColors.warmBrown.opacity(0.3))
                                .frame(width: 30, height: 1)
                        }
                        
                        Text("Lobbykod")
                            .font(.custom("Georgia", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                    }
                    
                    // Code display - parchment card style
                    Button(action: {
                        if let code = firebase.currentLobby?.code {
                            UIPasteboard.general.string = code
                            SoundManager.shared.playClick()
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCopiedFeedback = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showCopiedFeedback = false
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text(firebase.currentLobby?.code ?? "------")
                                .font(.custom("Georgia-Bold", size: 32))
                                .foregroundColor(AppColors.inkDark)
                                .tracking(6)
                            
                            Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(showCopiedFeedback ? AppColors.oliveGreen : AppColors.warmBrown.opacity(0.6))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.parchment)
                                .shadow(color: AppColors.inkDark.opacity(0.08), radius: 8, y: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(AppColors.warmBrown.opacity(0.25), lineWidth: 1)
                                )
                        )
                    }
                    
                    Text(showCopiedFeedback ? "Kopierad!" : "Tryck för att kopiera")
                        .font(.custom("Georgia-Italic", size: 12))
                        .foregroundColor(showCopiedFeedback ? AppColors.oliveGreen : AppColors.inkMedium.opacity(0.6))
                }
                .padding(.top, 24)
                
                // Disconnected players warning
                if !firebase.disconnectedPlayers.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Väntar på \(firebase.disconnectedPlayers.joined(separator: ", "))...")
                            .font(.custom("Georgia-Italic", size: 12))
                            .foregroundColor(AppColors.warning)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.warning.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.top, 12)
                }
                
                // Player section header with ornaments
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(AppColors.warmBrown.opacity(0.2))
                            .frame(height: 1)
                        
                        Text("Spelare")
                            .font(.custom("Georgia-Bold", size: 18))
                            .foregroundColor(AppColors.inkDark)
                        
                        Text("\(firebase.players.count)/8")
                            .font(.custom("Georgia", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                        
                        Rectangle()
                            .fill(AppColors.warmBrown.opacity(0.2))
                            .frame(height: 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 16)
                
                // Player grid
                GeometryReader { geometry in
                    let horizontalPadding: CGFloat = 16
                    let spacing: CGFloat = 12
                    let availableWidth = geometry.size.width - (horizontalPadding * 2)
                    let itemWidth = (availableWidth - spacing) / 2
                    let cardHeight = itemWidth * (1.0 / CharacterAvatar.cardAspectRatio)
                    
                    let columns = [
                        GridItem(.fixed(itemWidth), spacing: spacing),
                        GridItem(.fixed(itemWidth), spacing: spacing)
                    ]
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: spacing) {
                            ForEach(firebase.players) { player in
                                LobbyPlayerCard(
                                    player: player,
                                    isMe: player.oderId == firebase.userId,
                                    cardWidth: itemWidth,
                                    cardHeight: cardHeight,
                                    canKick: firebase.isHost && player.oderId != firebase.userId,
                                    onKick: {
                                        firebase.kickPlayer(player)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, 100) // Space for bottom button
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                // Start button (host only)
                if firebase.isHost {
                    VStack(spacing: 8) {
                        if firebase.players.count < 2 {
                            Text("Minst 2 spelare krävs")
                                .font(.custom("Georgia-Italic", size: 12))
                                .foregroundColor(AppColors.inkMedium)
                        }
                        
                        Button(action: {
                            SoundManager.shared.playClick()
                            Task {
                                await startGame()
                            }
                        }) {
                            HStack(spacing: 8) {
                                if isStarting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14))
                                    Text("Starta Spelet")
                                        .font(.custom("Georgia-Bold", size: 17))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(firebase.players.count >= 2 ? AppColors.warmBrown : AppColors.inkMedium.opacity(0.3))
                                    .shadow(color: AppColors.inkDark.opacity(0.15), radius: 4, y: 2)
                            )
                        }
                        .disabled(firebase.players.count < 2 || isStarting)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                } else {
                    // Waiting message for non-hosts
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Väntar på att värden startar...")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                    }
                    .padding(.vertical, 16)
                }
            }
            .background(
                // Gradient fade from transparent at top to parchment at bottom
                LinearGradient(
                    stops: [
                        .init(color: AppColors.parchment.opacity(0), location: 0),
                        .init(color: AppColors.parchment.opacity(0.9), location: 0.3),
                        .init(color: AppColors.parchment, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
    
    private func startGame() async {
        isStarting = true
        
        do {
            try await firebase.startGame()
            // The game start will be detected via the lobby observer
        } catch {
            print("❌ Start game failed: \(error)")
        }
        
        isStarting = false
    }
}

// MARK: - Character Confirmation View (Full Screen)

struct CharacterConfirmationOverlay: View {
    let avatar: CharacterAvatar
    let isLoading: Bool
    let confirmButtonText: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var imageScale: CGFloat = 0.85
    @State private var imageOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Full screen parchment background
            AppColors.parchment
                .ignoresSafeArea(.all)
            
            // Subtle texture
            Image("egg-shell")
                .resizable(resizingMode: .tile)
                .opacity(0.4)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Close button at top right
                HStack {
                    Spacer()
                    
                    Button(action: {
                        if !isLoading {
                            withAnimation(.easeOut(duration: 0.2)) {
                                imageScale = 0.85
                                imageOpacity = 0
                                contentOpacity = 0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                onCancel()
                            }
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.inkMedium)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(AppColors.warmBrown.opacity(0.1))
                            )
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xl)
                .opacity(contentOpacity)
                
                Spacer()
                
                // Character image - centered and prominent
                Image(avatar.imageName)
                    .resizable()
                    .aspectRatio(CharacterAvatar.cardAspectRatio, contentMode: .fit)
                    .frame(maxWidth: 280)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    .scaleEffect(imageScale)
                    .opacity(imageOpacity)
                
                Spacer()
                    .frame(height: AppSpacing.xxl)
                
                // Character name
                Text(avatar.displayName)
                    .font(AppFonts.displayLarge())
                    .foregroundColor(AppColors.inkDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                    .opacity(contentOpacity)
                
                Spacer()
                    .frame(height: AppSpacing.md)
                
                OrnamentDivider(width: 100, color: AppColors.warmBrown.opacity(0.4))
                    .opacity(contentOpacity)
                
                Spacer()
                
                // Confirm button - medieval panel style
                Button(action: onConfirm) {
                    ZStack {
                        // Panel background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "f5edd8"))
                            .shadow(color: Color.black.opacity(0.12), radius: 4, y: 3)
                        
                        // Double border
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AppColors.warmBrown.opacity(0.6), lineWidth: 1.5)
                        
                        // Inner border
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(AppColors.warmBrown.opacity(0.2), lineWidth: 0.5)
                            .padding(4)
                        
                        // Corner ornaments
                        VStack {
                            HStack {
                                CornerOrnamentSmall()
                                Spacer()
                                CornerOrnamentSmall()
                                    .rotationEffect(.degrees(90))
                            }
                            Spacer()
                            HStack {
                                CornerOrnamentSmall()
                                    .rotationEffect(.degrees(-90))
                                Spacer()
                                CornerOrnamentSmall()
                                    .rotationEffect(.degrees(180))
                            }
                        }
                        .padding(6)
                        
                        // Content
                        HStack(spacing: AppSpacing.sm) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.inkDark))
                            } else {
                                Text(confirmButtonText)
                                    .font(.custom("Georgia-Bold", size: 18))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundColor(AppColors.inkDark)
                    }
                    .frame(height: 56)
                }
                .disabled(isLoading)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
                .opacity(contentOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                imageScale = 1.0
                imageOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                contentOpacity = 1.0
            }
        }
    }
}

// MARK: - Online Player Card

// MARK: - Lobby Player Card (Grid Style)

struct LobbyPlayerCard: View {
    let player: OnlinePlayer
    let isMe: Bool
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let canKick: Bool
    let onKick: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Character card image
            ZStack(alignment: .topTrailing) {
                Image(player.avatar?.imageName ?? player.avatarId)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
                    .saturation(player.status == .online ? 1.0 : 0.4)
                    .opacity(player.status == .online ? 1.0 : 0.7)
                
                // Kick button for host (top right corner)
                if canKick {
                    Button(action: {
                        SoundManager.shared.playClick()
                        onKick()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.coralRed)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 16, height: 16)
                            )
                    }
                    .offset(x: -6, y: 6)
                }
            }
            
            // Player info below card
            VStack(spacing: 3) {
                // Name row
                HStack(spacing: 4) {
                    Text(player.name)
                        .font(.custom("Georgia-Bold", size: 14))
                        .foregroundColor(AppColors.inkDark)
                        .lineLimit(1)
                    
                    if isMe {
                        Text("(du)")
                            .font(.custom("Georgia", size: 11))
                            .foregroundColor(AppColors.inkMedium)
                    }
                    
                    if player.isHost {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.warning)
                    }
                }
                
                // Status row
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5, height: 5)
                    Text(statusText)
                        .font(.custom("Georgia", size: 11))
                        .foregroundColor(AppColors.inkMedium)
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch player.status {
        case .online: return AppColors.oliveGreen
        case .reconnecting: return AppColors.warning
        case .offline: return AppColors.inkMedium
        }
    }
    
    private var statusText: String {
        switch player.status {
        case .online: return "Online"
        case .reconnecting: return "Återansluter..."
        case .offline: return "Offline"
        }
    }
}

// MARK: - Online Player Card (Legacy - Row Style)

struct OnlinePlayerCard: View {
    let player: OnlinePlayer
    let isMe: Bool
    let canKick: Bool
    let onKick: () -> Void
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar
            Image(player.avatar?.imageName ?? player.avatarId)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                .opacity(player.status == .online ? 1 : 0.5)
            
            // Player info
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: AppSpacing.xs) {
                    Text(player.name)
                        .font(AppFonts.headingMedium())
                        .foregroundColor(AppColors.inkDark)
                    
                    if isMe {
                        Text("(du)")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.inkMedium)
                    }
                    
                    if player.isHost {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.warning)
                    }
                }
                
                // Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.inkMedium)
                }
            }
            
            Spacer()
            
            // Kick button (host only)
            if canKick {
                Button(action: {
                    SoundManager.shared.playClick()
                    onKick()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.coralRed.opacity(0.7))
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(Color.white.opacity(isMe ? 0.6 : 0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(isMe ? AppColors.royalBlue.opacity(0.3) : AppColors.warmBrown.opacity(0.2), lineWidth: isMe ? 2 : 1)
                )
        )
    }
    
    private var statusColor: Color {
        switch player.status {
        case .online: return AppColors.oliveGreen
        case .reconnecting: return AppColors.warning
        case .offline: return AppColors.inkMedium
        }
    }
    
    private var statusText: String {
        switch player.status {
        case .online: return "Online"
        case .reconnecting: return "Återansluter..."
        case .offline: return "Offline"
        }
    }
}

// MARK: - Online Role Reveal View

struct OnlineRoleRevealView: View {
    let onContinue: () -> Void
    
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var isCardFlipped = false
    @State private var showingCard = false
    @State private var showHelp = false
    
    var myRole: PlayerRole {
        firebase.getMyRole() ?? .frisk
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Title
                VStack(spacing: AppSpacing.sm) {
                    Text("Din Roll")
                        .font(AppFonts.displayMedium())
                        .foregroundColor(AppColors.inkDark)
                    
                    OrnamentDivider(width: 120, color: AppColors.warmBrown)
                }
                .padding(.top, AppSpacing.xxl * 1.5)
                
                Spacer()
                
                // Card area
                if showingCard {
                    RoleFlipCard(
                        role: myRole,
                        isFlipped: $isCardFlipped
                    )
                } else {
                    // Tap to reveal
                    VStack(spacing: AppSpacing.lg) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.warmBrown)
                        
                        Text("Tryck för att se din roll")
                            .font(AppFonts.headingMedium())
                            .foregroundColor(AppColors.inkMedium)
                        
                        Text("Endast du kan se detta")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.inkMedium.opacity(0.7))
                    }
                    .onTapGesture {
                        SoundManager.shared.playClick()
                        withAnimation(.spring(response: 0.5)) {
                            showingCard = true
                        }
                    }
                }
                
                Spacer()
                
                // Continue button - medieval style
                if isCardFlipped {
                    Button(action: {
                        SoundManager.shared.playClick()
                        onContinue()
                    }) {
                        HStack {
                            Text("Jag Förstår")
                                .font(.custom("Georgia-Bold", size: 16))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(AppColors.warmBrown)
                                .shadow(color: AppColors.inkDark.opacity(0.2), radius: 4, y: 2)
                        )
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                Spacer()
                    .frame(height: AppSpacing.xxl)
            }
            
            // Help button
            VStack {
                HStack {
                    Spacer()
                    HelpButton(showHelp: $showHelp)
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                }
                Spacer()
            }
            
            // Help overlay
            if showHelp {
                HelpOverlay(
                    content: getRoleRevealHelp(),
                    onDismiss: { showHelp = false }
                )
            }
        }
    }
    
    private func getRoleRevealHelp() -> HelpContent {
        switch myRole {
        case .smittobarare:
            return HelpContent(
                title: "Du är Råttmannen",
                body: "Du bär på pesten och ditt mål är att smitta alla andra spelare utan att bli avslöjad. Under röstningen väljer du vem du vill smitta - din röst räknas inte för uträkning!",
                tip: "Agera som om du vore frisk. Rösta och diskutera som alla andra. Misstänkliggör andra för att avleda uppmärksamheten."
            )
        case .frisk:
            return HelpContent(
                title: "Du är Frisk",
                body: "Ditt mål är att identifiera och förvisa Råttmannen innan alla blir smittade. Diskutera med andra och rösta ut den du misstänker mest.",
                tip: "Håll koll på vem som agerar misstänkt. Samarbeta med andra friska för att hitta Råttmannen."
            )
        case .infekterad:
            return HelpContent(
                title: "Du är Smittad",
                body: "Du har blivit smittad av Råttmannen, men du spelar fortfarande för de friskas lag. Om Läkaren botar dig blir du frisk igen.",
                tip: "Försök få Läkaren att bota dig utan att avslöja för Råttmannen att du vet."
            )
        }
    }
}

// MARK: - Online Playing View

struct OnlinePlayingView: View {
    let onExit: () -> Void
    
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Spelet Pågår!")
                .font(AppFonts.displayMedium())
                .foregroundColor(AppColors.inkDark)
            
            OrnamentDivider(width: 140, color: AppColors.warmBrown)
            
            Text("Spelmekaniken kommer snart...")
                .font(AppFonts.bodyMedium())
                .foregroundColor(AppColors.inkMedium)
            
            Spacer()
                .frame(height: AppSpacing.xxl)
            
            // Player overview
            VStack(spacing: AppSpacing.md) {
                ForEach(firebase.players) { player in
                    HStack {
                        Image(player.avatar?.imageName ?? player.avatarId)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                        
                        Text(player.name)
                            .font(AppFonts.bodyMedium())
                            .foregroundColor(AppColors.inkDark)
                        
                        if player.oderId == firebase.userId {
                            Text("(du)")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.inkMedium)
                        }
                        
                        Spacer()
                        
                        // Status indicator
                        Circle()
                            .fill(player.status == .online ? AppColors.oliveGreen : AppColors.warning)
                            .frame(width: 12, height: 12)
                    }
                    .padding(AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .fill(Color.white.opacity(0.3))
                    )
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            
            Spacer()
            
            // Exit button
            Button(action: {
                SoundManager.shared.playClick()
                onExit()
            }) {
                Text("Lämna Spelet")
                    .font(AppFonts.headingSmall())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .fill(AppColors.coralRed)
                    )
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxl)
        }
    }
}

// MARK: - Medieval Panel Button

struct MedievalPanelButton: View {
    let title: String
    let subtitle: String
    let isPrimary: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    // Parchment-like colors, not white
    private var panelColor: Color {
        isPrimary ? Color(hex: "f5edd8") : Color(hex: "efe7d4")
    }
    
    private var borderColor: Color {
        isPrimary ? AppColors.warmBrown.opacity(0.6) : AppColors.warmBrown.opacity(0.35)
    }
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            SoundManager.shared.playClick()
            action()
        }) {
            ZStack {
                // Panel background - subtle inner shadow for depth
                RoundedRectangle(cornerRadius: 4)
                    .fill(panelColor)
                    .shadow(
                        color: Color.black.opacity(isPressed ? 0.08 : 0.12),
                        radius: isPressed ? 1 : 4,
                        x: 0,
                        y: isPressed ? 1 : 3
                    )
                
                // Double border for manuscript feel
                RoundedRectangle(cornerRadius: 4)
                    .stroke(borderColor, lineWidth: isPrimary ? 1.5 : 1)
                
                // Inner border (inset)
                RoundedRectangle(cornerRadius: 2)
                    .stroke(borderColor.opacity(0.3), lineWidth: 0.5)
                    .padding(4)
                
                // Corner ornaments for primary
                if isPrimary {
                    // Top-left corner
                    VStack {
                        HStack {
                            CornerOrnamentSmall()
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(6)
                    
                    // Top-right corner
                    VStack {
                        HStack {
                            Spacer()
                            CornerOrnamentSmall()
                                .rotationEffect(.degrees(90))
                        }
                        Spacer()
                    }
                    .padding(6)
                    
                    // Bottom-left corner
                    VStack {
                        Spacer()
                        HStack {
                            CornerOrnamentSmall()
                                .rotationEffect(.degrees(-90))
                            Spacer()
                        }
                    }
                    .padding(6)
                    
                    // Bottom-right corner
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            CornerOrnamentSmall()
                                .rotationEffect(.degrees(180))
                        }
                    }
                    .padding(6)
                }
                
                // Content
                VStack(spacing: 4) {
                    Text(title)
                        .font(.custom("Georgia-Bold", size: isPrimary ? 18 : 16))
                        .foregroundColor(AppColors.inkDark)
                    
                    Text(subtitle)
                        .font(.custom("Georgia-Italic", size: 12))
                        .foregroundColor(AppColors.inkMedium)
                }
                .padding(.vertical, isPrimary ? 20 : 16)
            }
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// Small corner ornament for buttons
struct CornerOrnamentSmall: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 10, y: 0))
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 10))
        }
        .stroke(AppColors.warmBrown.opacity(0.4), lineWidth: 1)
        .frame(width: 10, height: 10)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: AppSpacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(AppColors.inkDark)
                
                Text(message)
                    .font(AppFonts.bodyMedium())
                    .foregroundColor(AppColors.inkDark)
            }
            .padding(AppSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(AppColors.parchment)
                    .shadow(color: .black.opacity(0.2), radius: 20)
            )
        }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            
            Text(message)
                .font(AppFonts.bodySmall())
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(AppColors.coralRed)
        )
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xxl)
    }
}

// MARK: - Online Round View

struct OnlineRoundView: View {
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var showHelp = false
    
    var body: some View {
        ZStack {
            // Background
            AppColors.parchment
                .ignoresSafeArea()
            
            Image("egg-shell")
                .resizable(resizingMode: .tile)
                .ignoresSafeArea()
            
            DustParticlesView()
                .ignoresSafeArea()
            
            // Content based on round sub-phase
            switch firebase.currentLobby?.roundSubPhase ?? .diceRoll {
            case .diceRoll:
                OnlineDiceRollView()
            case .diceEvent:
                OnlineDiceEventView()
            case .protection:
                OnlineProtectionPhaseView()
            case .cure:
                // Skip if blackout
                if firebase.currentLobby?.skipCurePhase == true {
                    OnlineBlackoutSkipView()
                } else {
                    OnlineCurePhaseView()
                }
            case .voting:
                OnlineVotingPhaseView()
            case .resolution:
                OnlineResolutionPhaseView()
            }
            
            // Help button
            VStack {
                HStack {
                    Spacer()
                    HelpButton(showHelp: $showHelp)
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                }
                Spacer()
            }
            
            // Help overlay
            if showHelp {
                HelpOverlay(
                    content: getHelpContent(),
                    onDismiss: { showHelp = false }
                )
            }
        }
    }
    
    private func getHelpContent() -> HelpContent {
        let subPhase = firebase.currentLobby?.roundSubPhase ?? .protection
        let isRattmannen = firebase.isRattmannen
        
        switch subPhase {
        case .diceRoll:
            return HelpContent(
                title: "Tärningskast",
                body: "Tärningarna kastas för att avgöra vilken händelse som påverkar denna runda.",
                tip: "Vänta på resultatet."
            )
            
        case .diceEvent:
            return HelpContent(
                title: "Tärningshändelse",
                body: "En speciell händelse aktiveras baserat på tärningsresultatet. Detta kan påverka rundan på olika sätt.",
                tip: "Läs händelsen noggrant."
            )
            
        case .protection:
            if firebase.isVaktare {
                return HelpContent(
                    title: "Skydda En Spelare",
                    body: "Du är Väktaren. Välj en spelare att skydda denna runda. Den skyddade spelaren kan inte röstas ut och kan inte smittas av Råttmannen.",
                    tip: "Du kan inte skydda dig själv. Skyddet gäller bara denna runda."
                )
            } else {
                return HelpContent(
                    title: "Väktarens Val",
                    body: "Väktaren väljer vem som ska skyddas denna runda. Den skyddade spelaren kan varken röstas ut eller smittas.",
                    tip: "Vänta på Väktarens beslut."
                )
            }
            
        case .cure:
            if firebase.isLakare {
                return HelpContent(
                    title: "Bota En Spelare",
                    body: "Du är Läkaren. Du kan välja att bota en spelare som du misstänker är smittad. Om boten lyckas blir spelaren frisk igen.",
                    tip: "Du kan inte bota dig själv. Du kan också hoppa över."
                )
            } else if isRattmannen {
                return HelpContent(
                    title: "Läkarens Val",
                    body: "Läkaren väljer vem som ska botas. Om de botar en av dina smittade... blir den spelaren frisk igen. Hoppas de väljer fel!"
                )
            } else {
                return HelpContent(
                    title: "Läkarens Val",
                    body: "Läkaren väljer om någon ska botas denna runda. Om läkaren väljer rätt spelare kan en smittad person bli frisk igen.",
                    tip: "Vänta på Läkarens beslut."
                )
            }
            
        case .voting:
            if isRattmannen {
                return HelpContent(
                    title: "Infektera & Rösta",
                    body: "Din röst räknas INTE för uträkning. Istället blir den du 'röstar' på smittad! Välj strategiskt - försök inte infektera någon som ändå kommer röstas ut.",
                    tip: "Du kan inte smitta den skyddade spelaren. Överväg vem som har störst chans att överleva."
                )
            } else {
                return HelpContent(
                    title: "Rösta Ut En Spelare",
                    body: "Rösta för vem du vill ska förvisas från byn. Den med flest röster förvisas. Vid lika röster förvisas ingen.",
                    tip: "Den skyddade spelaren kan inte röstas ut. Försök identifiera Råttmannen."
                )
            }
            
        case .resolution:
            return HelpContent(
                title: "Rundans Resultat",
                body: "Se vad som hände denna runda. Vem förvisades? Lyckades läkarens bot? Fortsätt sedan till nästa runda."
            )
        }
    }
}

// MARK: - Protection Phase View

struct OnlineProtectionPhaseView: View {
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var selectedPlayer: OnlinePlayer?
    @State private var showConfirmation = false
    @State private var isSubmitting = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            phaseHeader
            
            if firebase.isVaktare {
                // Väktare selects protection target
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        Text("Välj vem du vill skydda")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                        
                        OnlineVotingGrid(
                            players: firebase.protectionTargets,
                            selectedId: selectedPlayer?.oderId,
                            onSelect: { player in
                                selectedPlayer = player
                                showConfirmation = true
                            }
                        )
                        .padding(.horizontal)
                    }
                    .padding(.vertical, AppSpacing.lg)
                }
            } else {
                // Other players wait
                VStack(spacing: AppSpacing.lg) {
                    Spacer()
                    
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppColors.warmBrown)
                    
                    Text("Väktaren väljer...")
                        .font(.custom("Georgia", size: 16))
                        .foregroundColor(AppColors.inkMedium)
                    
                    if let vaktare = firebase.getVaktare() {
                        Text("\(vaktare.name) bestämmer vem som ska skyddas")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundColor(AppColors.inkMedium.opacity(0.7))
                    }
                    
                    Spacer()
                }
            }
        }
        .overlay {
            if showConfirmation, let player = selectedPlayer {
                OnlineActionConfirmation(
                    title: "Skydda \(player.name)?",
                    subtitle: "Denna spelare skyddas från förvising och smitta denna runda",
                    player: player,
                    iconName: "guard",
                    confirmText: "Skydda",
                    isSubmitting: isSubmitting,
                    onConfirm: {
                        Task {
                            isSubmitting = true
                            try? await firebase.vaktareProtect(playerId: player.oderId)
                            isSubmitting = false
                            showConfirmation = false
                        }
                    },
                    onCancel: {
                        showConfirmation = false
                        selectedPlayer = nil
                    }
                )
            }
        }
    }
    
    private var phaseHeader: some View {
        VStack(spacing: 8) {
            Text("Runda \(firebase.currentLobby?.round ?? 1)")
                .font(.custom("Georgia", size: 14))
                .foregroundColor(AppColors.inkMedium)
            
            Image("guard")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
            
            OrnamentalDivider()
            
            Text("Väktarens Val")
                .font(.custom("Georgia-Bold", size: 24))
                .foregroundColor(AppColors.inkDark)
            
            Text("Skydda en bybo")
                .font(.custom("Georgia-Italic", size: 14))
                .foregroundColor(AppColors.inkMedium)
            
            OrnamentalDivider()
        }
        .padding(.top, AppSpacing.lg)
    }
}

// MARK: - Cure Phase View

struct OnlineCurePhaseView: View {
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var selectedPlayer: OnlinePlayer?
    @State private var showConfirmation = false
    @State private var isSubmitting = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            phaseHeader
            
            // Show who is protected
            if let protectedName = firebase.currentLobby?.protectedPlayerId,
               let protectedPlayer = firebase.players.first(where: { $0.oderId == protectedName }) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.oliveGreen)
                    Text("\(protectedPlayer.name) är skyddad")
                        .font(.custom("Georgia-Italic", size: 13))
                        .foregroundColor(AppColors.oliveGreen)
                }
                .padding(.vertical, 8)
            }
            
            if firebase.isLakare {
                // Läkare selects cure target
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        Text("Välj vem du vill försöka bota")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                        
                        OnlineVotingGrid(
                            players: firebase.cureTargets,
                            selectedId: selectedPlayer?.oderId,
                            onSelect: { player in
                                selectedPlayer = player
                                showConfirmation = true
                            }
                        )
                        .padding(.horizontal)
                        
                        // Skip button
                        Button(action: {
                            Task {
                                try? await firebase.lakareSkip()
                            }
                        }) {
                            Text("Hoppa över")
                                .font(.custom("Georgia", size: 14))
                                .foregroundColor(AppColors.inkMedium)
                                .underline()
                        }
                        .padding(.top, AppSpacing.md)
                    }
                    .padding(.vertical, AppSpacing.lg)
                }
            } else {
                // Other players wait
                VStack(spacing: AppSpacing.lg) {
                    Spacer()
                    
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppColors.warmBrown)
                    
                    Text("Läkaren väljer...")
                        .font(.custom("Georgia", size: 16))
                        .foregroundColor(AppColors.inkMedium)
                    
                    if let lakare = firebase.getLakare() {
                        Text("\(lakare.name) bestämmer om någon ska botas")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundColor(AppColors.inkMedium.opacity(0.7))
                    }
                    
                    Spacer()
                }
            }
        }
        .overlay {
            if showConfirmation, let player = selectedPlayer {
                OnlineActionConfirmation(
                    title: "Bota \(player.name)?",
                    subtitle: "Om spelaren är smittad blir den frisk. Annars händer inget.",
                    player: player,
                    iconName: "doctor",
                    confirmText: "Bota",
                    isSubmitting: isSubmitting,
                    onConfirm: {
                        Task {
                            isSubmitting = true
                            try? await firebase.lakareCure(playerId: player.oderId)
                            isSubmitting = false
                            showConfirmation = false
                        }
                    },
                    onCancel: {
                        showConfirmation = false
                        selectedPlayer = nil
                    }
                )
            }
        }
    }
    
    private var phaseHeader: some View {
        VStack(spacing: 8) {
            Text("Runda \(firebase.currentLobby?.round ?? 1)")
                .font(.custom("Georgia", size: 14))
                .foregroundColor(AppColors.inkMedium)
            
            Image("doctor")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
            
            OrnamentalDivider()
            
            Text("Läkarens Val")
                .font(.custom("Georgia-Bold", size: 24))
                .foregroundColor(AppColors.inkDark)
            
            Text("Bota en bybo")
                .font(.custom("Georgia-Italic", size: 14))
                .foregroundColor(AppColors.inkMedium)
            
            OrnamentalDivider()
        }
        .padding(.top, AppSpacing.lg)
    }
}

// MARK: - Voting Phase View

struct OnlineVotingPhaseView: View {
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var selectedPlayer: OnlinePlayer?
    @State private var showConfirmation = false
    @State private var isSubmitting = false
    
    var hasVoted: Bool {
        firebase.hasVotedInRound()
    }
    
    var amIQuarantined: Bool {
        firebase.amIQuarantined
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            phaseHeader
            
            // Show quarantined players
            if !(firebase.currentLobby?.quarantinedPlayerIds.isEmpty ?? true) {
                let quarantinedNames = firebase.currentLobby?.quarantinedPlayerIds.compactMap { id in
                    firebase.players.first { $0.oderId == id }?.name
                } ?? []
                HStack(spacing: 6) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.warning)
                    Text("I karantän: \(quarantinedNames.joined(separator: ", "))")
                        .font(.custom("Georgia-Italic", size: 13))
                        .foregroundColor(AppColors.warning)
                }
                .padding(.vertical, 4)
            }
            
            // Show protected player
            if let protectedId = firebase.currentLobby?.protectedPlayerId,
               let protectedPlayer = firebase.players.first(where: { $0.oderId == protectedId }) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.oliveGreen)
                    Text("\(protectedPlayer.name) är skyddad och kan inte röstas ut")
                        .font(.custom("Georgia-Italic", size: 13))
                        .foregroundColor(AppColors.oliveGreen)
                }
                .padding(.vertical, 8)
            }
            
            // Show cure result (if not skipped due to blackout)
            if firebase.currentLobby?.skipCurePhase != true,
               let cureResult = firebase.currentLobby?.cureResult,
               let cureTargetId = firebase.currentLobby?.cureTargetId,
               let curedPlayer = firebase.players.first(where: { $0.oderId == cureTargetId }) {
                HStack(spacing: 6) {
                    Image(systemName: cureResult == "success" ? "checkmark.circle.fill" : "xmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(cureResult == "success" ? AppColors.oliveGreen : AppColors.inkMedium)
                    Text(cureResult == "success" 
                         ? "\(curedPlayer.name) botades!"
                         : "Läkaren försökte bota \(curedPlayer.name) - inget hände")
                        .font(.custom("Georgia-Italic", size: 13))
                        .foregroundColor(cureResult == "success" ? AppColors.oliveGreen : AppColors.inkMedium)
                }
                .padding(.vertical, 4)
            }
            
            // Check if quarantined
            if amIQuarantined {
                // Quarantined view
                VStack(spacing: AppSpacing.lg) {
                    Spacer()
                    
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 64))
                        .foregroundColor(AppColors.warning.opacity(0.7))
                    
                    Text("Du är i karantän")
                        .font(.custom("Georgia-Bold", size: 24))
                        .foregroundColor(AppColors.inkDark)
                    
                    Text("Du får inte prata eller rösta denna runda")
                        .font(.custom("Georgia-Italic", size: 14))
                        .foregroundColor(AppColors.inkMedium)
                        .multilineTextAlignment(.center)
                    
                    // Vote progress
                    let totalVotes = firebase.currentLobby?.roundVotes.count ?? 0
                    let expectedVotes = firebase.eligibleVoters.count
                    Text("\(totalVotes) av \(expectedVotes) har röstat")
                        .font(.custom("Georgia", size: 12))
                        .foregroundColor(AppColors.inkMedium.opacity(0.7))
                        .padding(.top, AppSpacing.md)
                    
                    Spacer()
                }
            } else if hasVoted {
                // Waiting for others
                VStack(spacing: AppSpacing.lg) {
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.oliveGreen)
                    
                    Text("Din röst är lagd")
                        .font(.custom("Georgia-Bold", size: 20))
                        .foregroundColor(AppColors.inkDark)
                    
                    Text("Väntar på övriga spelare...")
                        .font(.custom("Georgia-Italic", size: 14))
                        .foregroundColor(AppColors.inkMedium)
                    
                    // Vote progress (use eligible voters, not all alive)
                    let totalVotes = firebase.currentLobby?.roundVotes.count ?? 0
                    let expectedVotes = firebase.eligibleVoters.count
                    Text("\(totalVotes) av \(expectedVotes) har röstat")
                        .font(.custom("Georgia", size: 12))
                        .foregroundColor(AppColors.inkMedium.opacity(0.7))
                    
                    Spacer()
                }
            } else {
                // Vote selection
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        if firebase.isRattmannen {
                            Text("Välj vem du vill smittas")
                                .font(.custom("Georgia-Italic", size: 14))
                                .foregroundColor(AppColors.error)
                        } else {
                            Text("Välj vem som ska förvisas")
                                .font(.custom("Georgia-Italic", size: 14))
                                .foregroundColor(AppColors.inkMedium)
                        }
                        
                        OnlineVotingGrid(
                            players: firebase.votableTargets,
                            selectedId: selectedPlayer?.oderId,
                            onSelect: { player in
                                selectedPlayer = player
                                showConfirmation = true
                            }
                        )
                        .padding(.horizontal)
                    }
                    .padding(.vertical, AppSpacing.lg)
                }
            }
        }
        .overlay {
            if showConfirmation, let player = selectedPlayer {
                OnlineActionConfirmation(
                    title: firebase.isRattmannen ? "Smitta \(player.name)?" : "Rösta ut \(player.name)?",
                    subtitle: firebase.isRattmannen 
                        ? "Din röst räknas inte för uträkning - istället smittas denna spelare"
                        : "Du röstar för att förvisa denna spelare från byn",
                    player: player,
                    iconName: firebase.isRattmannen ? "smittobarare" : nil,
                    confirmText: firebase.isRattmannen ? "Smitta" : "Rösta",
                    isSubmitting: isSubmitting,
                    onConfirm: {
                        Task {
                            isSubmitting = true
                            try? await firebase.castRoundVote(forPlayerId: player.oderId)
                            isSubmitting = false
                            showConfirmation = false
                        }
                    },
                    onCancel: {
                        showConfirmation = false
                        selectedPlayer = nil
                    }
                )
            }
        }
    }
    
    private var phaseHeader: some View {
        VStack(spacing: 8) {
            Text("Runda \(firebase.currentLobby?.round ?? 1)")
                .font(.custom("Georgia", size: 14))
                .foregroundColor(AppColors.inkMedium)
            
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.warmBrown)
            
            OrnamentalDivider()
            
            Text(firebase.isRattmannen ? "Infektera" : "Förvisning")
                .font(.custom("Georgia-Bold", size: 24))
                .foregroundColor(AppColors.inkDark)
            
            Text(firebase.isRattmannen ? "Välj ditt offer" : "Rösta ut en misstänkt")
                .font(.custom("Georgia-Italic", size: 14))
                .foregroundColor(AppColors.inkMedium)
            
            OrnamentalDivider()
        }
        .padding(.top, AppSpacing.lg)
    }
}

// MARK: - Resolution Phase View

struct OnlineResolutionPhaseView: View {
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var showResults = false
    @State private var isStartingNextRound = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Runda \(firebase.currentLobby?.round ?? 1)")
                    .font(.custom("Georgia", size: 14))
                    .foregroundColor(AppColors.inkMedium)
                
                Image(systemName: "scroll.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.warmBrown)
                
                OrnamentalDivider()
                
                Text("Resultat")
                    .font(.custom("Georgia-Bold", size: 24))
                    .foregroundColor(AppColors.inkDark)
                
                OrnamentalDivider()
            }
            .padding(.top, AppSpacing.lg)
            
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Vote results
                    VStack(spacing: AppSpacing.md) {
                        Text("Röstresultat")
                            .font(.custom("Georgia-Bold", size: 18))
                            .foregroundColor(AppColors.inkDark)
                        
                        let voteCounts = firebase.getVoteCounts()
                        ForEach(voteCounts, id: \.player.oderId) { item in
                            HStack {
                                if let avatar = item.player.avatar {
                                    Image(avatar.imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                }
                                
                                Text(item.player.name)
                                    .font(.custom("Georgia", size: 16))
                                    .foregroundColor(AppColors.inkDark)
                                
                                Spacer()
                                
                                Text("\(item.count) röst\(item.count == 1 ? "" : "er")")
                                    .font(.custom("Georgia-Bold", size: 14))
                                    .foregroundColor(
                                        item.player.oderId == firebase.currentLobby?.exiledPlayerId
                                            ? AppColors.error
                                            : AppColors.inkMedium
                                    )
                            }
                            .padding(.horizontal)
                        }
                        
                        if voteCounts.isEmpty {
                            Text("Ingen fick några röster")
                                .font(.custom("Georgia-Italic", size: 14))
                                .foregroundColor(AppColors.inkMedium)
                        }
                    }
                    
                    // Exile result
                    if let exiledId = firebase.currentLobby?.exiledPlayerId,
                       let exiledPlayer = firebase.players.first(where: { $0.oderId == exiledId }) {
                        VStack(spacing: AppSpacing.sm) {
                            Text("Förvisad")
                                .font(.custom("Georgia-Bold", size: 16))
                                .foregroundColor(AppColors.error)
                            
                            if let avatar = exiledPlayer.avatar {
                                Image(avatar.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(AppColors.error.opacity(0.5), lineWidth: 3)
                                    )
                                    .saturation(0.5)
                            }
                            
                            Text(exiledPlayer.name)
                                .font(.custom("Georgia-Bold", size: 18))
                                .foregroundColor(AppColors.inkDark)
                            
                            // Show their role
                            if let role = exiledPlayer.secretRole {
                                Text("var \(role == .smittobarare ? "Råttmannen!" : (role == .infekterad ? "Smittad" : "Frisk"))")
                                    .font(.custom("Georgia-Italic", size: 14))
                                    .foregroundColor(role == .smittobarare ? AppColors.error : AppColors.inkMedium)
                            }
                        }
                    } else {
                        Text("Ingen förvisades denna runda")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                            .padding(.vertical, AppSpacing.md)
                    }
                    
                    // Continue button (host only)
                    if firebase.isHost {
                        Button(action: {
                            Task {
                                isStartingNextRound = true
                                // First resolve round (apply infection, check win)
                                try? await firebase.resolveRound()
                                // Then start next round if game continues
                                if firebase.currentLobby?.gamePhase == .round {
                                    try? await firebase.startNextRound()
                                }
                                isStartingNextRound = false
                            }
                        }) {
                            HStack(spacing: 8) {
                                if isStartingNextRound {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text("Fortsätt")
                                    .font(.custom("Georgia-Bold", size: 16))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(AppColors.warmBrown)
                            )
                        }
                        .disabled(isStartingNextRound)
                        .padding(.top, AppSpacing.lg)
                    } else {
                        Text("Väntar på att värden fortsätter...")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                            .padding(.top, AppSpacing.lg)
                    }
                }
                .padding(.vertical, AppSpacing.xl)
            }
        }
    }
}

// MARK: - Online Dice Roll View

struct OnlineDiceRollView: View {
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var diceResult: Int? = nil
    @State private var isRolling = false
    @State private var showResult = false
    
    var isMyTurn: Bool {
        firebase.isCurrentRoller
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Runda \(firebase.currentLobby?.round ?? 1)")
                    .font(.custom("Georgia", size: 14))
                    .foregroundColor(AppColors.inkMedium)
                
                Image(systemName: "dice.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.warmBrown)
                
                OrnamentalDivider()
                
                Text("Ödet Avgör")
                    .font(.custom("Georgia-Bold", size: 24))
                    .foregroundColor(AppColors.inkDark)
                
                if let roller = firebase.currentRoller {
                    Text(isMyTurn ? "Du kastar tärningarna" : "\(roller.name) kastar tärningarna")
                        .font(.custom("Georgia-Italic", size: 14))
                        .foregroundColor(AppColors.inkMedium)
                }
                
                OrnamentalDivider()
            }
            .padding(.top, AppSpacing.lg)
            
            Spacer()
            
            // Dice area
            if isMyTurn {
                // Show 3D dice for roller
                DiceSceneView(
                    onResult: { result in
                        diceResult = result
                        showResult = true
                        // Submit result to Firebase
                        Task {
                            try? await firebase.submitDiceResult(result: result)
                        }
                    },
                    onRollStart: {
                        isRolling = true
                        showResult = false
                    }
                )
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, AppSpacing.lg)
                
                Text("Tryck för att kasta")
                    .font(.custom("Georgia-Italic", size: 14))
                    .foregroundColor(AppColors.inkMedium)
                    .padding(.top, AppSpacing.sm)
            } else {
                // Show waiting message for others
                VStack(spacing: AppSpacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppColors.warmBrown)
                    
                    Text("Väntar på tärningskast...")
                        .font(.custom("Georgia", size: 16))
                        .foregroundColor(AppColors.inkMedium)
                    
                    if let roller = firebase.currentRoller {
                        if let avatar = roller.avatar {
                            Image(avatar.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Text(roller.name)
                            .font(.custom("Georgia-Bold", size: 16))
                            .foregroundColor(AppColors.inkDark)
                    }
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Online Dice Event View

struct OnlineDiceEventView: View {
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    
    var diceEvent: GameLobby.DiceEventType? {
        firebase.currentLobby?.diceEvent
    }
    
    var body: some View {
        if let event = diceEvent {
            switch event {
            case .antidote:
                OnlineAntidoteEventView()
            case .prophecy:
                OnlineProphecyEventView()
            case .quarantine:
                OnlineQuarantineEventView()
            case .blackout:
                OnlineBlackoutEventView()
            case .epidemic:
                OnlineEpidemicEventView()
            }
        } else {
            // Fallback - should not happen
            VStack {
                Text("Laddar händelse...")
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(AppColors.inkMedium)
            }
        }
    }
}

// MARK: - Antidote Event View (2-3)

struct OnlineAntidoteEventView: View {
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var selectedPlayer: OnlinePlayer?
    @State private var showConfirmation = false
    @State private var isSubmitting = false
    @State private var cureResult: String?
    
    var isResolved: Bool {
        firebase.currentLobby?.diceEventResolved ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            diceEventHeader(
                icon: "cross.vial.fill",
                title: "Motgift Funnet!",
                subtitle: "Tärningarna visade \(firebase.currentLobby?.diceResult ?? 0)"
            )
            
            if firebase.isCurrentRoller && !isResolved {
                // Roller selects who to cure
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        Text("Välj en spelare att bota omedelbart")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                        
                        OnlineVotingGrid(
                            players: firebase.alivePlayers,
                            selectedId: selectedPlayer?.oderId,
                            onSelect: { player in
                                selectedPlayer = player
                                showConfirmation = true
                            }
                        )
                        .padding(.horizontal)
                    }
                    .padding(.vertical, AppSpacing.lg)
                }
            } else if isResolved {
                // Show result
                VStack(spacing: AppSpacing.lg) {
                    Spacer()
                    
                    let result = firebase.currentLobby?.prophecyResult
                    Image(systemName: result == "success" ? "checkmark.circle.fill" : "xmark.circle")
                        .font(.system(size: 64))
                        .foregroundColor(result == "success" ? AppColors.oliveGreen : AppColors.inkMedium)
                    
                    Text(result == "success" ? "Boten lyckades!" : "Spelaren var inte smittad")
                        .font(.custom("Georgia-Bold", size: 20))
                        .foregroundColor(AppColors.inkDark)
                    
                    // Continue button
                    if firebase.isCurrentRoller || firebase.isHost {
                        continueButton()
                    } else {
                        Text("Väntar...")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                    }
                    
                    Spacer()
                }
            } else {
                // Others wait
                waitingView(message: "väntar på att motgiftet används...")
            }
        }
        .overlay {
            if showConfirmation, let player = selectedPlayer {
                OnlineActionConfirmation(
                    title: "Bota \(player.name)?",
                    subtitle: "Motgiftet kommer användas omedelbart",
                    player: player,
                    iconName: "doctor",
                    confirmText: "Bota",
                    isSubmitting: isSubmitting,
                    onConfirm: {
                        Task {
                            isSubmitting = true
                            try? await firebase.handleAntidoteEvent(targetPlayerId: player.oderId)
                            isSubmitting = false
                            showConfirmation = false
                        }
                    },
                    onCancel: {
                        showConfirmation = false
                        selectedPlayer = nil
                    }
                )
            }
        }
    }
}

// MARK: - Prophecy Event View (4-5)

struct OnlineProphecyEventView: View {
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var selectedChoice: String?
    @State private var selectedPlayer: OnlinePlayer?
    @State private var isSubmitting = false
    
    var isResolved: Bool {
        firebase.currentLobby?.diceEventResolved ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            diceEventHeader(
                icon: "eye.fill",
                title: "Spådom",
                subtitle: "Tärningarna visade \(firebase.currentLobby?.diceResult ?? 0)"
            )
            
            if firebase.isCurrentRoller && !isResolved {
                // Roller chooses prophecy type
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        Text("Välj din insikt")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                        
                        if selectedChoice == nil {
                            // Choice selection
                            VStack(spacing: AppSpacing.md) {
                                prophecyChoiceButton(
                                    title: "Räkna Smittade",
                                    description: "Lär dig hur många spelare som är smittade just nu",
                                    action: {
                                        Task {
                                            isSubmitting = true
                                            try? await firebase.handleProphecyChoice(type: "count")
                                            isSubmitting = false
                                        }
                                    }
                                )
                                
                                prophecyChoiceButton(
                                    title: "Undersök En Person",
                                    description: "Ta reda på om en specifik spelare är smittad",
                                    action: {
                                        selectedChoice = "investigate"
                                    }
                                )
                            }
                            .padding(.horizontal)
                        } else {
                            // Player selection for investigate
                            Text("Välj vem du vill undersöka")
                                .font(.custom("Georgia-Italic", size: 14))
                                .foregroundColor(AppColors.inkMedium)
                            
                            OnlineVotingGrid(
                                players: firebase.alivePlayers.filter { $0.oderId != firebase.userId },
                                selectedId: selectedPlayer?.oderId,
                                onSelect: { player in
                                    Task {
                                        isSubmitting = true
                                        try? await firebase.handleProphecyChoice(type: "investigate", targetPlayerId: player.oderId)
                                        isSubmitting = false
                                    }
                                }
                            )
                            .padding(.horizontal)
                            
                            Button("Tillbaka") {
                                selectedChoice = nil
                            }
                            .font(.custom("Georgia", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                        }
                    }
                    .padding(.vertical, AppSpacing.lg)
                }
            } else if isResolved && firebase.isCurrentRoller {
                // Show result only to roller
                VStack(spacing: AppSpacing.lg) {
                    Spacer()
                    
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(AppColors.warmBrown)
                    
                    if firebase.currentLobby?.prophecyType == "count" {
                        Text("Antal smittade:")
                            .font(.custom("Georgia", size: 16))
                            .foregroundColor(AppColors.inkMedium)
                        Text(firebase.currentLobby?.prophecyResult ?? "?")
                            .font(.custom("Georgia-Bold", size: 48))
                            .foregroundColor(AppColors.inkDark)
                    } else {
                        if let targetId = firebase.currentLobby?.prophecyTarget,
                           let target = firebase.players.first(where: { $0.oderId == targetId }) {
                            Text("\(target.name) är:")
                                .font(.custom("Georgia", size: 16))
                                .foregroundColor(AppColors.inkMedium)
                            Text(firebase.currentLobby?.prophecyResult == "ja" ? "SMITTAD" : "FRISK")
                                .font(.custom("Georgia-Bold", size: 32))
                                .foregroundColor(firebase.currentLobby?.prophecyResult == "ja" ? AppColors.error : AppColors.oliveGreen)
                        }
                    }
                    
                    Text("Denna information är bara synlig för dig")
                        .font(.custom("Georgia-Italic", size: 12))
                        .foregroundColor(AppColors.inkMedium.opacity(0.7))
                        .padding(.top, AppSpacing.sm)
                    
                    continueButton()
                    
                    Spacer()
                }
            } else if isResolved {
                // Others see that prophecy was used
                VStack(spacing: AppSpacing.lg) {
                    Spacer()
                    
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 64))
                        .foregroundColor(AppColors.inkMedium.opacity(0.5))
                    
                    Text("Spådomen är hemlig")
                        .font(.custom("Georgia-Bold", size: 20))
                        .foregroundColor(AppColors.inkDark)
                    
                    if let roller = firebase.currentRoller {
                        Text("\(roller.name) har fått en uppenbarelse")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                    }
                    
                    Text("Väntar...")
                        .font(.custom("Georgia-Italic", size: 14))
                        .foregroundColor(AppColors.inkMedium)
                        .padding(.top, AppSpacing.lg)
                    
                    Spacer()
                }
            } else {
                waitingView(message: "väntar på spådomen...")
            }
        }
    }
    
    private func prophecyChoiceButton(title: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.custom("Georgia-Bold", size: 18))
                    .foregroundColor(AppColors.inkDark)
                Text(description)
                    .font(.custom("Georgia", size: 13))
                    .foregroundColor(AppColors.inkMedium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.parchment)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.warmBrown.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isSubmitting)
    }
}

// MARK: - Quarantine Event View (6-8)

struct OnlineQuarantineEventView: View {
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var selectedPlayers: [OnlinePlayer] = []
    @State private var isSubmitting = false
    
    var isResolved: Bool {
        firebase.currentLobby?.diceEventResolved ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            diceEventHeader(
                icon: "lock.fill",
                title: "Karantän!",
                subtitle: "Tärningarna visade \(firebase.currentLobby?.diceResult ?? 0)"
            )
            
            if firebase.isCurrentRoller && !isResolved {
                // Roller selects 2 players
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        Text("Välj 2 spelare att sätta i karantän")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                        
                        Text("Valda: \(selectedPlayers.count)/2")
                            .font(.custom("Georgia-Bold", size: 16))
                            .foregroundColor(selectedPlayers.count == 2 ? AppColors.oliveGreen : AppColors.inkMedium)
                        
                        OnlineVotingGrid(
                            players: firebase.alivePlayers.filter { $0.oderId != firebase.userId },
                            selectedId: nil,
                            onSelect: { player in
                                if let index = selectedPlayers.firstIndex(where: { $0.oderId == player.oderId }) {
                                    selectedPlayers.remove(at: index)
                                } else if selectedPlayers.count < 2 {
                                    selectedPlayers.append(player)
                                }
                            }
                        )
                        .padding(.horizontal)
                        
                        // Show selected players
                        if !selectedPlayers.isEmpty {
                            HStack {
                                ForEach(selectedPlayers) { player in
                                    Text(player.name)
                                        .font(.custom("Georgia-Bold", size: 14))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(AppColors.warmBrown))
                                }
                            }
                        }
                        
                        // Confirm button
                        if selectedPlayers.count == 2 {
                            Button(action: {
                                Task {
                                    isSubmitting = true
                                    try? await firebase.handleQuarantineSelection(
                                        playerIds: selectedPlayers.map { $0.oderId }
                                    )
                                    isSubmitting = false
                                }
                            }) {
                                Text("Bekräfta Karantän")
                                    .font(.custom("Georgia-Bold", size: 16))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .background(Capsule().fill(AppColors.warmBrown))
                            }
                            .disabled(isSubmitting)
                        }
                    }
                    .padding(.vertical, AppSpacing.lg)
                }
            } else if isResolved {
                // Show quarantined players
                VStack(spacing: AppSpacing.lg) {
                    Spacer()
                    
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 64))
                        .foregroundColor(AppColors.warning)
                    
                    Text("I Karantän")
                        .font(.custom("Georgia-Bold", size: 20))
                        .foregroundColor(AppColors.inkDark)
                    
                    // Show quarantined players
                    HStack(spacing: AppSpacing.md) {
                        ForEach(firebase.currentLobby?.quarantinedPlayerIds ?? [], id: \.self) { playerId in
                            if let player = firebase.players.first(where: { $0.oderId == playerId }) {
                                VStack {
                                    if let avatar = player.avatar {
                                        Image(avatar.imageName)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 75)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                            .saturation(0.5)
                                    }
                                    Text(player.name)
                                        .font(.custom("Georgia", size: 14))
                                        .foregroundColor(AppColors.inkMedium)
                                }
                            }
                        }
                    }
                    
                    Text("Dessa spelare får inte prata eller rösta denna runda")
                        .font(.custom("Georgia-Italic", size: 13))
                        .foregroundColor(AppColors.inkMedium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if firebase.isCurrentRoller || firebase.isHost {
                        continueButton()
                    } else {
                        Text("Väntar...")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                    }
                    
                    Spacer()
                }
            } else {
                waitingView(message: "väntar på karantänval...")
            }
        }
    }
}

// MARK: - Blackout Event View (9-10)

struct OnlineBlackoutEventView: View {
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 80))
                .foregroundColor(AppColors.inkDark)
            
            VStack(spacing: 8) {
                Text("Midnatt")
                    .font(.custom("Georgia-Bold", size: 32))
                    .foregroundColor(AppColors.inkDark)
                
                Text("Tärningarna visade \(firebase.currentLobby?.diceResult ?? 0)")
                    .font(.custom("Georgia", size: 14))
                    .foregroundColor(AppColors.inkMedium)
            }
            
            OrnamentalDivider()
            
            Text("Ett mystiskt mörker faller över byn!\nIngen botning sker denna runda.")
                .font(.custom("Georgia", size: 16))
                .foregroundColor(AppColors.inkMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            
            if firebase.isCurrentRoller || firebase.isHost {
                continueButton()
                    .padding(.top, AppSpacing.xl)
            } else {
                Text("Väntar...")
                    .font(.custom("Georgia-Italic", size: 14))
                    .foregroundColor(AppColors.inkMedium)
                    .padding(.top, AppSpacing.xl)
            }
            
            Spacer()
        }
    }
}

// MARK: - Epidemic Event View (11-12)

struct OnlineEpidemicEventView: View {
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    
    var amIVictim: Bool {
        firebase.currentLobby?.epidemicVictimId == firebase.userId
    }
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            Image(systemName: "allergens")
                .font(.system(size: 80))
                .foregroundColor(AppColors.error)
            
            VStack(spacing: 8) {
                Text("Epidemi!")
                    .font(.custom("Georgia-Bold", size: 32))
                    .foregroundColor(AppColors.error)
                
                Text("Tärningarna visade \(firebase.currentLobby?.diceResult ?? 0)")
                    .font(.custom("Georgia", size: 14))
                    .foregroundColor(AppColors.inkMedium)
            }
            
            OrnamentalDivider()
            
            if amIVictim {
                // Only victim sees this
                Text("Du har blivit smittad av pesten!")
                    .font(.custom("Georgia-Bold", size: 18))
                    .foregroundColor(AppColors.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                
                Text("Ingen annan vet om detta. Hjälp de friska att hitta Råttmannen!")
                    .font(.custom("Georgia-Italic", size: 14))
                    .foregroundColor(AppColors.inkMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            } else {
                Text("Pesten muterar och sprids i det tysta.\nNågon i byn har smittats...")
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(AppColors.inkMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            
            if firebase.isCurrentRoller || firebase.isHost {
                continueButton()
                    .padding(.top, AppSpacing.xl)
            } else {
                Text("Väntar...")
                    .font(.custom("Georgia-Italic", size: 14))
                    .foregroundColor(AppColors.inkMedium)
                    .padding(.top, AppSpacing.xl)
            }
            
            Spacer()
        }
    }
}

// MARK: - Blackout Skip View (for cure phase)

struct OnlineBlackoutSkipView: View {
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var hasProceeded = false
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 64))
                .foregroundColor(AppColors.inkMedium.opacity(0.5))
            
            Text("Ingen Botning")
                .font(.custom("Georgia-Bold", size: 24))
                .foregroundColor(AppColors.inkDark)
            
            Text("På grund av mörkret hoppas botfasen över")
                .font(.custom("Georgia-Italic", size: 14))
                .foregroundColor(AppColors.inkMedium)
            
            // Auto-proceed after delay
            ProgressView()
                .tint(AppColors.warmBrown)
                .padding(.top, AppSpacing.lg)
            
            Spacer()
        }
        .onAppear {
            // Auto-proceed to voting after 2 seconds
            guard !hasProceeded else { return }
            hasProceeded = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if firebase.isHost {
                    Task {
                        try? await firebase.skipToVotingPhase()
                    }
                }
            }
        }
    }
}

// MARK: - Dice View Helpers

private func diceEventHeader(icon: String, title: String, subtitle: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon)
            .font(.system(size: 48))
            .foregroundColor(AppColors.warmBrown)
        
        OrnamentalDivider()
        
        Text(title)
            .font(.custom("Georgia-Bold", size: 24))
            .foregroundColor(AppColors.inkDark)
        
        Text(subtitle)
            .font(.custom("Georgia", size: 14))
            .foregroundColor(AppColors.inkMedium)
        
        OrnamentalDivider()
    }
    .padding(.top, AppSpacing.lg)
}

private func waitingView(message: String) -> some View {
    VStack(spacing: AppSpacing.lg) {
        Spacer()
        
        ProgressView()
            .scaleEffect(1.2)
            .tint(AppColors.warmBrown)
        
        Text(message.capitalized)
            .font(.custom("Georgia", size: 16))
            .foregroundColor(AppColors.inkMedium)
        
        Spacer()
    }
}

private func continueButton() -> some View {
    Button(action: {
        Task {
            try? await FirebaseMultiplayerManager.shared.proceedFromDiceEvent()
        }
    }) {
        Text("Fortsätt")
            .font(.custom("Georgia-Bold", size: 16))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(Capsule().fill(AppColors.warmBrown))
    }
}

// MARK: - Online Game Over View

struct OnlineGameOverView: View {
    let onPlayAgain: () -> Void
    let onExit: () -> Void
    
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    
    var friskaWin: Bool {
        firebase.currentLobby?.gameResult == "friskaWin"
    }
    
    var body: some View {
        ZStack {
            // Background
            (friskaWin ? AppColors.parchment : Color(hex: "1a1510"))
                .ignoresSafeArea()
            
            if friskaWin {
                Image("egg-shell")
                    .resizable(resizingMode: .tile)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: AppSpacing.xl) {
                Spacer()
                
                // Result icon
                Image(systemName: friskaWin ? "sun.max.fill" : "moon.stars.fill")
                    .font(.system(size: 80))
                    .foregroundColor(friskaWin ? AppColors.warning : AppColors.parchment.opacity(0.6))
                
                // Result title
                Text(friskaWin ? "De Friska Vann!" : "Råttmannen Segrade!")
                    .font(.custom("Georgia-Bold", size: 28))
                    .foregroundColor(friskaWin ? AppColors.inkDark : AppColors.parchment)
                    .multilineTextAlignment(.center)
                
                OrnamentalDivider()
                    .colorMultiply(friskaWin ? AppColors.warmBrown : AppColors.parchment)
                
                // Description
                Text(friskaWin 
                     ? "Råttmannen har förvisats och byn är säker igen."
                     : "Alla i byn har smittats. Mörkret har segrat.")
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(friskaWin ? AppColors.inkMedium : AppColors.parchment.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                
                // Stats
                VStack(spacing: 8) {
                    Text("Rundor spelade: \(firebase.currentLobby?.round ?? 0)")
                        .font(.custom("Georgia", size: 14))
                        .foregroundColor(friskaWin ? AppColors.inkMedium : AppColors.parchment.opacity(0.6))
                    
                    Text("Spelare: \(firebase.players.count)")
                        .font(.custom("Georgia", size: 14))
                        .foregroundColor(friskaWin ? AppColors.inkMedium : AppColors.parchment.opacity(0.6))
                }
                .padding(.top, AppSpacing.md)
                
                Spacer()
                
                // Buttons
                VStack(spacing: AppSpacing.md) {
                    Button(action: onExit) {
                        Text("Tillbaka till Meny")
                            .font(.custom("Georgia-Bold", size: 16))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(AppColors.warmBrown)
                            )
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
    }
}

// MARK: - Online Voting Components

/// Voting grid for online players
struct OnlineVotingGrid: View {
    let players: [OnlinePlayer]
    let selectedId: String?
    let onSelect: (OnlinePlayer) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(players) { player in
                OnlineVotingCard(
                    player: player,
                    isSelected: player.oderId == selectedId,
                    onTap: { onSelect(player) }
                )
            }
        }
    }
}

/// Portrait-style player card for online voting
struct OnlineVotingCard: View {
    let player: OnlinePlayer
    let isSelected: Bool
    let voteCount: Int?
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    init(
        player: OnlinePlayer,
        isSelected: Bool = false,
        voteCount: Int? = nil,
        onTap: @escaping () -> Void
    ) {
        self.player = player
        self.isSelected = isSelected
        self.voteCount = voteCount
        self.onTap = onTap
    }
    
    private var cardWidth: CGFloat { 160 }
    private var cardHeight: CGFloat { cardWidth * (1.0 / CharacterAvatar.cardAspectRatio) }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                // Character portrait
                if let avatar = player.avatar {
                    Image(avatar.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                }
                
                // Vote count badge
                if let count = voteCount, count > 0 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(count)")
                                .font(.custom("Georgia-Bold", size: 14))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(AppColors.oliveGreen)
                                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                                )
                                .padding(8)
                        }
                        Spacer()
                    }
                }
                
                // Name bar
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Text(player.name)
                            .font(.custom("Georgia-Bold", size: 14))
                            .foregroundColor(.white)
                        if player.isHost {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.warning)
                        }
                    }
                    
                    if isSelected {
                        Text("Din röst")
                            .font(.custom("Georgia-Italic", size: 11))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, isSelected ? 10 : 8)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0), .black.opacity(isSelected ? 0.8 : 0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        isSelected ? AppColors.warmBrown.opacity(0.6) : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: isSelected ? AppColors.warmBrown.opacity(0.3) : .clear,
                radius: 8,
                y: 0
            )
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

/// Action confirmation overlay for online mode
struct OnlineActionConfirmation: View {
    let title: String
    let subtitle: String
    let player: OnlinePlayer
    let iconName: String?
    let confirmText: String
    let isSubmitting: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
            
            // Modal
            VStack(spacing: AppSpacing.lg) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.inkMedium)
                            .padding(12)
                            .background(Circle().fill(AppColors.inkDark.opacity(0.1)))
                    }
                }
                
                // Icon
                if let iconName = iconName {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                }
                
                // Player portrait
                if let avatar = player.avatar {
                    Image(avatar.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppColors.warmBrown.opacity(0.3), lineWidth: 2))
                }
                
                // Title
                Text(title)
                    .font(.custom("Georgia-Bold", size: 20))
                    .foregroundColor(AppColors.inkDark)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text(subtitle)
                    .font(.custom("Georgia", size: 14))
                    .foregroundColor(AppColors.inkMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Buttons
                HStack(spacing: AppSpacing.md) {
                    Button(action: onCancel) {
                        Text("Avbryt")
                            .font(.custom("Georgia", size: 14))
                            .foregroundColor(AppColors.inkMedium)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .stroke(AppColors.inkMedium.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Button(action: onConfirm) {
                        HStack(spacing: 6) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Text(confirmText)
                                .font(.custom("Georgia-Bold", size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(AppColors.warmBrown)
                        )
                    }
                    .disabled(isSubmitting)
                }
                .padding(.top, AppSpacing.sm)
            }
            .padding(AppSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.parchment)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            )
            .padding(.horizontal, AppSpacing.lg)
        }
    }
}

// MARK: - Preview

#Preview {
    OnlineGameView(onExit: {})
}
