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
    case playing           // Game in progress
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
                        withAnimation(.easeInOut(duration: 0.4)) {
                            phase = .playing
                        }
                    }
                )
                .transition(.opacity)
                
            case .playing:
                OnlinePlayingView(
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
            if newPhase == .roleReveal && phase == .lobby {
                withAnimation(.easeInOut(duration: 0.4)) {
                    phase = .roleReveal
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
        .onChange(of: playerName) { _ in
            if showNameError { showNameError = false }
        }
        .scrollDismissesKeyboard(.interactively)
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
            // Fixed bottom button
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
                HStack(spacing: AppSpacing.sm) {
                    Text("Välj karaktär")
                        .font(AppFonts.headingSmall())
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(!playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppColors.warmBrown : AppColors.inkMedium.opacity(0.3))
                        .shadow(color: AppColors.inkDark.opacity(0.15), radius: 4, y: 2)
                )
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
            .padding(.bottom, 28)
            
            // Character grid with precise spacing
            GeometryReader { geometry in
                let horizontalPadding: CGFloat = 16
                let spacing: CGFloat = 12
                let availableWidth = geometry.size.width - (horizontalPadding * 2)
                let itemWidth = (availableWidth - spacing) / 2
                let itemHeight = itemWidth * (1413.0 / 1143.0)
                
                let columns = [
                    GridItem(.fixed(itemWidth), spacing: spacing),
                    GridItem(.fixed(itemWidth), spacing: spacing)
                ]
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(CharacterAvatar.allAvatars) { avatar in
                            let isSelected = selectedAvatar?.id == avatar.id
                            let hasSelection = selectedAvatar != nil
                            
                            Image(avatar.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: itemWidth, height: itemHeight)
                                .clipped()
                                .saturation(hasSelection && !isSelected ? 0.7 : 1.0)
                                .opacity(hasSelection && !isSelected ? 0.85 : 1.0)
                                .scaleEffect(isSelected ? 1.03 : 1.0)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    SoundManager.shared.playClick()
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedAvatar = avatar
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 16)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Fixed bottom button with gradient blur background
            VStack(spacing: 0) {
                Button(action: {
                    Task {
                        await createLobby()
                    }
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                            Text("Skapa Lobby")
                                .font(AppFonts.headingSmall())
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .fill(selectedAvatar != nil ? AppColors.warmBrown : AppColors.inkMedium.opacity(0.3))
                            .shadow(color: AppColors.inkDark.opacity(0.15), radius: 4, y: 2)
                    )
                }
                .disabled(selectedAvatar == nil || isCreating)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)
            }
            .background(
                // Gradient fade from transparent at top to solid at bottom
                LinearGradient(
                    stops: [
                        .init(color: AppColors.parchment.opacity(0), location: 0),
                        .init(color: AppColors.parchment.opacity(0.85), location: 0.4),
                        .init(color: AppColors.parchment, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
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
        .scrollDismissesKeyboard(.interactively)
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
            // Fixed bottom button
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
                HStack(spacing: AppSpacing.sm) {
                    Text("Fortsätt")
                        .font(AppFonts.headingSmall())
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(canProceed ? AppColors.warmBrown : AppColors.inkMedium.opacity(0.3))
                        .shadow(color: AppColors.inkDark.opacity(0.15), radius: 4, y: 2)
                )
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
            .padding(.bottom, 28)
            
            // Character grid with precise spacing
            GeometryReader { geometry in
                let horizontalPadding: CGFloat = 16
                let spacing: CGFloat = 12
                let availableWidth = geometry.size.width - (horizontalPadding * 2)
                let itemWidth = (availableWidth - spacing) / 2
                let itemHeight = itemWidth * (1413.0 / 1143.0)
                
                let columns = [
                    GridItem(.fixed(itemWidth), spacing: spacing),
                    GridItem(.fixed(itemWidth), spacing: spacing)
                ]
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(CharacterAvatar.allAvatars) { avatar in
                            let isSelected = selectedAvatar?.id == avatar.id
                            let hasSelection = selectedAvatar != nil
                            
                            Image(avatar.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: itemWidth, height: itemHeight)
                                .clipped()
                                .saturation(hasSelection && !isSelected ? 0.7 : 1.0)
                                .opacity(hasSelection && !isSelected ? 0.85 : 1.0)
                                .scaleEffect(isSelected ? 1.03 : 1.0)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    SoundManager.shared.playClick()
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedAvatar = avatar
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 16)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Fixed bottom button with gradient blur background
            VStack(spacing: 0) {
                Button(action: {
                    Task {
                        await joinLobby()
                    }
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        if isJoining {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 18))
                            Text("Gå med")
                                .font(AppFonts.headingSmall())
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .fill(selectedAvatar != nil ? AppColors.warmBrown : AppColors.inkMedium.opacity(0.3))
                            .shadow(color: AppColors.inkDark.opacity(0.15), radius: 4, y: 2)
                    )
                }
                .disabled(selectedAvatar == nil || isJoining)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)
            }
            .background(
                // Gradient fade from transparent at top to solid at bottom
                LinearGradient(
                    stops: [
                        .init(color: AppColors.parchment.opacity(0), location: 0),
                        .init(color: AppColors.parchment.opacity(0.85), location: 0.4),
                        .init(color: AppColors.parchment, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
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
                    let cardHeight = itemWidth * (1413.0 / 1143.0)
                    
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
                        if firebase.players.count < 3 {
                            Text("Minst 3 spelare krävs")
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
                                    .fill(firebase.players.count >= 3 ? AppColors.warmBrown : AppColors.inkMedium.opacity(0.3))
                                    .shadow(color: AppColors.inkDark.opacity(0.15), radius: 4, y: 2)
                            )
                        }
                        .disabled(firebase.players.count < 3 || isStarting)
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
                Image(player.avatarId)
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
            Image(player.avatarId)
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
    
    var myRole: PlayerRole {
        firebase.getMyRole() ?? .frisk
    }
    
    var body: some View {
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
            
            // Continue button
            if isCardFlipped {
                Button(action: {
                    SoundManager.shared.playClick()
                    onContinue()
                }) {
                    HStack {
                        Text("Jag Förstår")
                            .font(AppFonts.headingSmall())
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .fill(AppColors.royalBlue)
                            .shadow(color: AppColors.inkDark.opacity(0.2), radius: 4, y: 2)
                    )
                }
                .padding(.horizontal, AppSpacing.xl)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            Spacer()
                .frame(height: AppSpacing.xxl)
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
                        Image(player.avatarId)
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

// MARK: - Preview

#Preview {
    OnlineGameView(onExit: {})
}
