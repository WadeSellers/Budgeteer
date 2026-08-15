import SwiftUI

struct TownHallView: View {

    @Environment(ThemeManager.self) private var theme
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var townHallService = TownHallService()
    @State private var audioPlayer = AudioPlayerService()
    @State private var showRecordSheet = false
    @State private var selectedFilter: PostType?

    var body: some View {
        NavigationStack {
            ZStack {
                theme.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Offline banner
                    if !networkMonitor.isConnected {
                        HStack(spacing: 6) {
                            Image(systemName: "wifi.slash")
                                .font(.caption2)
                            Text("Offline — showing cached posts")
                                .font(.caption2)
                        }
                        .foregroundStyle(.orange)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                    }

                    // Category filter chips
                    filterChips

                    // Content
                    if townHallService.isLoading && townHallService.posts.isEmpty {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Spacer()
                    } else if filteredPosts.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredPosts) { post in
                                    PostCardView(
                                        post: post,
                                        userReaction: townHallService.userReaction(for: post.id),
                                        isCurrentlyPlaying: audioPlayer.currentPostID == post.id && audioPlayer.isPlaying,
                                        playbackProgress: audioPlayer.currentPostID == post.id ? audioPlayer.progress : 0,
                                        isOwnPost: townHallService.isOwnPost(post),
                                        onReact: { reaction in
                                            Task { await townHallService.react(to: post, with: reaction) }
                                        },
                                        onPlay: { playPost(post) },
                                        onStop: { audioPlayer.stop() }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 80) // Room for floating button
                        }
                        .refreshable {
                            await townHallService.fetchPosts(filter: selectedFilter)
                        }
                    }
                }

                // Floating record button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        recordButton
                    }
                }
            }
            .navigationTitle("Town Hall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close Town Hall")
                }
            }
        }
        .task {
            await townHallService.fetchPosts()
            await townHallService.flushPendingUploads()
        }
        .sheet(isPresented: $showRecordSheet) {
            TownHallRecordSheet(
                townHallService: townHallService,
                onPosted: {
                    Task { await townHallService.fetchPosts(filter: selectedFilter) }
                }
            )
            .environment(theme)
            .environment(networkMonitor)
        }
    }

    // MARK: - Filter Chips

    private var filteredPosts: [PostRecord] {
        guard let filter = selectedFilter else { return townHallService.posts }
        return townHallService.posts.filter { $0.type == filter }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", type: nil)
                ForEach(PostType.allCases, id: \.self) { type in
                    filterChip(label: type.label, type: type, icon: type.icon, color: type.color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(label: String, type: PostType?, icon: String? = nil, color: Color = BudgeteerColors.green) -> some View {
        let isSelected = selectedFilter == type

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedFilter = type
            }
        } label: {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? color : theme.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by \(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "mic.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(BudgeteerColors.green.opacity(0.4))
                .accessibilityHidden(true)

            Text("Be the first voice!")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text("Record feedback, report bugs, or\nrequest features with your voice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Floating Record Button

    private var recordButton: some View {
        Button { showRecordSheet = true } label: {
            ZStack {
                Circle()
                    .fill(BudgeteerColors.green)
                    .frame(width: 56, height: 56)
                    .shadow(color: BudgeteerColors.green.opacity(0.4), radius: 10)

                Image(systemName: "mic.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .accessibilityLabel("Record a new post")
    }

    // MARK: - Playback

    private func playPost(_ post: PostRecord) {
        Task {
            // Check if already cached
            if let cached = post.cachedAudioURL, FileManager.default.fileExists(atPath: cached.path) {
                audioPlayer.play(url: cached, postID: post.id)
                return
            }

            // Download
            if let url = await townHallService.downloadAudio(for: post) {
                // Update local cache reference
                if let index = townHallService.posts.firstIndex(where: { $0.id == post.id }) {
                    townHallService.posts[index].cachedAudioURL = url
                }
                audioPlayer.play(url: url, postID: post.id)
            }
        }
    }
}
