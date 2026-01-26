//
//  ElectionView.swift
//  Toxic Tom
//
//  Election UI for choosing Läkare and Väktare
//

import SwiftUI

// MARK: - Election View

struct ElectionView: View {
    let electionType: PublicRole
    
    @ObservedObject private var firebase = FirebaseMultiplayerManager.shared
    @State private var selectedCandidate: OnlinePlayer?
    @State private var showConfirmation = false
    @State private var isSubmitting = false
    @State private var showResultAnimation = false
    @State private var showHelp = false
    
    var candidates: [OnlinePlayer] {
        firebase.getValidCandidates()
    }
    
    var isRevote: Bool {
        firebase.currentLobby?.tiedCandidates != nil
    }
    
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
            
            VStack(spacing: 0) {
                // Header with election info
                electionHeader
                
                // Candidate grid
                candidateGrid
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
            
            // Vote confirmation overlay
            if showConfirmation, let candidate = selectedCandidate {
                VoteConfirmationOverlay(
                    candidate: candidate,
                    electionType: electionType,
                    isSubmitting: isSubmitting,
                    onConfirm: {
                        Task {
                            await submitVote(for: candidate)
                        }
                    },
                    onCancel: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showConfirmation = false
                            selectedCandidate = nil
                        }
                    }
                )
            }
            
            // Help overlay
            if showHelp {
                HelpOverlay(
                    content: getElectionHelp(),
                    onDismiss: { showHelp = false }
                )
            }
        }
    }
    
    private func getElectionHelp() -> HelpContent {
        let isRattmannen = firebase.getMyRole() == .smittobarare
        
        switch electionType {
        case .lakare:
            if isRattmannen {
                return HelpContent(
                    title: "Val av Läkare",
                    body: "Rösta på den du vill ska bli Läkare. Du kan också bli vald! Om du blir Läkare kan du låtsas bota spelare utan att faktiskt göra det - men var försiktig, folk kanske märker.",
                    tip: "Om du blir Läkare kan du strategiskt 'missa' med dina botförsök."
                )
            } else {
                return HelpContent(
                    title: "Val av Läkare",
                    body: "Rösta på den du vill ska bli Läkare. Läkaren kan bota smittade spelare och göra dem friska igen. Välj någon du litar på!",
                    tip: "Läkaren är viktig - en bra Läkare kan vända hela spelet."
                )
            }
        case .vaktare:
            if isRattmannen {
                return HelpContent(
                    title: "Val av Väktare",
                    body: "Rösta på den du vill ska bli Väktare. Du kan inte bli Väktare eftersom du redan är Läkare (om du valdes). Väktaren skyddar en spelare varje runda.",
                    tip: "Väktaren kan blockera dina smittoförsök - håll koll på vem som skyddas."
                )
            } else {
                return HelpContent(
                    title: "Val av Väktare",
                    body: "Rösta på den du vill ska bli Väktare. Väktaren kan skydda en spelare varje runda från både förvising och smitta.",
                    tip: "Läkaren kan inte bli Väktare. Välj någon du litar på!"
                )
            }
        }
    }
    
    // MARK: - Header
    
    private var electionHeader: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 20)
            
            // Election icon - larger for emphasis
            Image(electionType.iconName)
                .resizable()
                .scaledToFit()
                .frame(height: 100)
            
            Spacer()
                .frame(height: 16)
            
            // Title with ornaments
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
                
                Text(isRevote ? "Omröstning" : electionType.electionTitle)
                    .font(.custom("Georgia-Bold", size: 26))
                    .foregroundColor(AppColors.inkDark)
                
                Text(isRevote ? "Lika röster - rösta igen" : electionType.electionSubtitle)
                    .font(.custom("Georgia-Italic", size: 14))
                    .foregroundColor(AppColors.inkMedium)
                
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
            }
            
            // Vote status
            VStack(spacing: 4) {
                if firebase.hasVoted() {
                    if let votedId = firebase.myVotedCandidateId(),
                       let votedPlayer = firebase.players.first(where: { $0.oderId == votedId }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.oliveGreen)
                            Text("Du röstade på \(votedPlayer.name)")
                                .font(.custom("Georgia", size: 14))
                                .foregroundColor(AppColors.inkMedium)
                        }
                    }
                }
                
                Text("\(firebase.totalVotesCast()) av \(firebase.expectedVoterCount()) har röstat")
                    .font(.custom("Georgia", size: 12))
                    .foregroundColor(AppColors.inkMedium.opacity(0.7))
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Candidate Grid
    
    private var candidateGrid: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = 16
            let spacing: CGFloat = 12
            let availableWidth = geometry.size.width - (horizontalPadding * 2)
            let itemWidth = (availableWidth - spacing) / 2
            
            let columns = [
                GridItem(.fixed(itemWidth), spacing: spacing),
                GridItem(.fixed(itemWidth), spacing: spacing)
            ]
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(candidates) { candidate in
                        ElectionPlayerCard(
                            player: candidate,
                            voteCount: firebase.voteCount(for: candidate.oderId),
                            isSelected: firebase.myVotedCandidateId() == candidate.oderId,
                            isDisabled: firebase.hasVoted() && firebase.myVotedCandidateId() != candidate.oderId,
                            cardWidth: itemWidth,
                            onTap: {
                                guard !firebase.hasVoted() else { return }
                                SoundManager.shared.playClick()
                                selectedCandidate = candidate
                                withAnimation(.spring(response: 0.3)) {
                                    showConfirmation = true
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Submit Vote
    
    private func submitVote(for candidate: OnlinePlayer) async {
        isSubmitting = true
        
        do {
            try await firebase.castVote(forPlayerId: candidate.oderId)
            await MainActor.run {
                SoundManager.shared.playClick()
                withAnimation(.easeOut(duration: 0.3)) {
                    showConfirmation = false
                    isSubmitting = false
                }
            }
        } catch {
            await MainActor.run {
                firebase.errorMessage = "Kunde inte rösta: \(error.localizedDescription)"
                isSubmitting = false
                showConfirmation = false
            }
        }
    }
}

// MARK: - Election Player Card

/// Unified player card for elections using the consistent voting style
struct ElectionPlayerCard: View {
    let player: OnlinePlayer
    let voteCount: Int
    let isSelected: Bool
    let isDisabled: Bool
    let cardWidth: CGFloat
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var cardHeight: CGFloat {
        cardWidth * (1.0 / CharacterAvatar.cardAspectRatio)
    }
    
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
                        .saturation(isDisabled ? 0.5 : 1.0)
                        .opacity(isDisabled ? 0.6 : 1.0)
                }
                
                // Vote count badge (top right)
                if voteCount > 0 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(voteCount)")
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
                
                // Name bar with "Din röst" indicator
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
                    
                    // "Din röst" label - simple text below name
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
            // Subtle warm tint on selection
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        isSelected ? AppColors.warmBrown.opacity(0.6) : Color.clear,
                        lineWidth: 2
                    )
            )
            // Subtle glow effect on selection
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
            guard !isDisabled else { return }
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isDisabled { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Vote Confirmation Full Screen

struct VoteConfirmationOverlay: View {
    let candidate: OnlinePlayer
    let electionType: PublicRole
    let isSubmitting: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Background matching app style
            AppColors.parchment.ignoresSafeArea()
            
            Image("egg-shell")
                .resizable(resizingMode: .tile)
                .ignoresSafeArea()
            
            DustParticlesView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Spacer()
                    
                    Button(action: {
                        if !isSubmitting {
                            SoundManager.shared.playClick()
                            onCancel()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.inkDark.opacity(isSubmitting ? 0.2 : 0.5))
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(AppColors.inkDark.opacity(0.08))
                            )
                    }
                    .disabled(isSubmitting)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Central content
                VStack(spacing: 0) {
                    // Role icon at top
                    Image(electionType.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .opacity(0.6)
                    
                    Spacer()
                        .frame(height: 24)
                    
                    // Candidate card
                    Image(candidate.avatar?.imageName ?? candidate.avatarId)
                        .resizable()
                        .aspectRatio(CharacterAvatar.cardAspectRatio, contentMode: .fit)
                        .frame(width: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    
                    Spacer()
                        .frame(height: 28)
                    
                    // Title with ornaments
                    VStack(spacing: 12) {
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
                        
                        Text(candidate.name)
                            .font(.custom("Georgia-Bold", size: 28))
                            .foregroundColor(AppColors.inkDark)
                        
                        Text("som \(electionType.displayName)")
                            .font(.custom("Georgia-Italic", size: 16))
                            .foregroundColor(AppColors.inkMedium)
                        
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
                        .frame(height: 16)
                    
                    // Warning text
                    Text("Du kan inte ändra din röst")
                        .font(.custom("Georgia-Italic", size: 13))
                        .foregroundColor(AppColors.coralRed.opacity(0.7))
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    // Confirm button (primary)
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        SoundManager.shared.playClick()
                        onConfirm()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "f5edd8"))
                                .shadow(color: .black.opacity(0.12), radius: 4, y: 3)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppColors.warmBrown.opacity(0.6), lineWidth: 1.5)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(AppColors.warmBrown.opacity(0.3), lineWidth: 0.5)
                                .padding(4)
                            
                            // Corner ornaments
                            VStack {
                                HStack {
                                    ElectionCornerOrnament()
                                    Spacer()
                                    ElectionCornerOrnament().rotationEffect(.degrees(90))
                                }
                                Spacer()
                                HStack {
                                    ElectionCornerOrnament().rotationEffect(.degrees(-90))
                                    Spacer()
                                    ElectionCornerOrnament().rotationEffect(.degrees(180))
                                }
                            }
                            .padding(6)
                            
                            if isSubmitting {
                                ProgressView()
                                    .tint(AppColors.inkDark)
                            } else {
                                VStack(spacing: 4) {
                                    Text("Bekräfta Röst")
                                        .font(.custom("Georgia-Bold", size: 18))
                                        .foregroundColor(AppColors.inkDark)
                                    
                                    Text("Rösta på \(candidate.name)")
                                        .font(.custom("Georgia-Italic", size: 12))
                                        .foregroundColor(AppColors.inkMedium)
                                }
                            }
                        }
                        .frame(height: 72)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isSubmitting)
                    
                    // Cancel button (secondary)
                    Button(action: {
                        SoundManager.shared.playClick()
                        onCancel()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "efe7d4"))
                                .shadow(color: .black.opacity(0.08), radius: 2, y: 2)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppColors.warmBrown.opacity(0.35), lineWidth: 1)
                            
                            VStack(spacing: 4) {
                                Text("Avbryt")
                                    .font(.custom("Georgia-Bold", size: 16))
                                    .foregroundColor(AppColors.inkDark)
                                
                                Text("Välj någon annan")
                                    .font(.custom("Georgia-Italic", size: 12))
                                    .foregroundColor(AppColors.inkMedium)
                            }
                        }
                        .frame(height: 56)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isSubmitting)
                    .opacity(isSubmitting ? 0.5 : 1)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

// Corner ornament for election buttons
struct ElectionCornerOrnament: View {
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

// MARK: - Election Result Announcement

struct ElectionResultView: View {
    let winner: OnlinePlayer
    let electionType: PublicRole
    let onContinue: () -> Void
    
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Background
            AppColors.parchment
                .ignoresSafeArea()
            
            Image("egg-shell")
                .resizable(resizingMode: .tile)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Role icon
                Image(electionType.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                
                Spacer()
                    .frame(height: 16)
                
                // Announcement text
                Text("Byns \(electionType.displayName)")
                    .font(.custom("Georgia", size: 16))
                    .foregroundColor(AppColors.inkMedium)
                    .opacity(showContent ? 1 : 0)
                
                Spacer()
                    .frame(height: 24)
                
                // Winner card
                Image(winner.avatar?.imageName ?? winner.avatarId)
                    .resizable()
                    .aspectRatio(CharacterAvatar.cardAspectRatio, contentMode: .fit)
                    .frame(width: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                    .scaleEffect(showContent ? 1 : 0.8)
                    .opacity(showContent ? 1 : 0)
                
                Spacer()
                    .frame(height: 20)
                
                // Winner name
                Text(winner.name.uppercased())
                    .font(.custom("Georgia-Bold", size: 28))
                    .tracking(3)
                    .foregroundColor(AppColors.inkDark)
                    .opacity(showContent ? 1 : 0)
                
                Spacer()
                    .frame(height: 8)
                
                // Role description
                Text(electionType.description)
                    .font(.custom("Georgia-Italic", size: 14))
                    .foregroundColor(AppColors.inkMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(showContent ? 1 : 0)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    SoundManager.shared.playClick()
                    onContinue()
                }) {
                    Text("Fortsätt")
                        .font(.custom("Georgia-Bold", size: 17))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.warmBrown)
                                .shadow(color: AppColors.inkDark.opacity(0.15), radius: 4, y: 2)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .opacity(showContent ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                showContent = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ElectionView(electionType: .lakare)
}
