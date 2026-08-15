import SwiftUI

struct PostCardView: View {

    let post: PostRecord
    let userReaction: ReactionType?
    let isCurrentlyPlaying: Bool
    let playbackProgress: Double
    let isOwnPost: Bool
    let onReact: (ReactionType) -> Void
    let onPlay: () -> Void
    let onStop: () -> Void

    @Environment(ThemeManager.self) private var theme

    @State private var showFullSummary = false
    @State private var showReply = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: type badge + title + play button
            HStack(alignment: .top, spacing: 12) {
                // Type badge
                ZStack {
                    Circle()
                        .fill(post.type.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: post.type.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(post.type.color)
                }
                .accessibilityHidden(true)

                // Title + timestamp
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(post.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Play button with progress ring
                playButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // AI Summary
            Text(post.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(showFullSummary ? nil : 2)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .onTapGesture { showFullSummary.toggle() }
                .animation(.easeOut(duration: 0.2), value: showFullSummary)

            // Developer reply indicator
            if post.status == .replied, let reply = post.reply {
                developerReplySection(reply)
            }

            // Reactions
            reactionsRow
                .padding(.horizontal, 16)
                .padding(.top, 10)

            // Waveform border
            if !post.waveformSamples.isEmpty {
                WaveformView(
                    samples: post.waveformSamples,
                    progress: isCurrentlyPlaying ? playbackProgress : 0,
                    isPlaying: isCurrentlyPlaying,
                    barColor: post.type.color.opacity(0.2),
                    activeColor: post.type.color.opacity(0.6),
                    ballColor: post.type.color,
                    height: 20
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)
            } else {
                Spacer().frame(height: 12)
            }
        }
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(post.type.label): \(post.title). \(post.summary)")
    }

    // MARK: - Play Button

    private var playButton: some View {
        Button(action: isCurrentlyPlaying ? onStop : onPlay) {
            ZStack {
                Circle()
                    .fill(theme.surface)
                    .frame(width: 40, height: 40)

                if isCurrentlyPlaying {
                    Circle()
                        .trim(from: 0, to: playbackProgress)
                        .stroke(post.type.color, lineWidth: 2.5)
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "stop.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(post.type.color)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(post.type.color)
                        .offset(x: 1)
                }
            }
        }
        .accessibilityLabel(isCurrentlyPlaying ? "Stop playback" : "Play recording")
    }

    // MARK: - Reactions

    private var reactionsRow: some View {
        HStack(spacing: 16) {
            reactionButton(.meToo)
            reactionButton(.greatIdea)
            reactionButton(.pleaseFix)
            Spacer()
        }
    }

    private func reactionButton(_ type: ReactionType) -> some View {
        let isSelected = userReaction == type
        let count: Int = {
            switch type {
            case .meToo:     return post.reactions.meToo
            case .greatIdea: return post.reactions.greatIdea
            case .pleaseFix: return post.reactions.pleaseFix
            }
        }()

        return Button {
            SoundManager.shared.playReactionTap()
            onReact(type)
        } label: {
            HStack(spacing: 4) {
                Text(type.emoji)
                    .font(.system(size: 13))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(isSelected ? AnyShapeStyle(post.type.color) : AnyShapeStyle(.tertiary))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? post.type.color.opacity(0.12) : theme.surface)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.0 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .accessibilityLabel("\(type.label), \(count)")
        .accessibilityHint(isSelected ? "Tap to remove reaction" : "Tap to react")
    }

    // MARK: - Developer Reply

    @ViewBuilder
    private func developerReplySection(_ reply: ReplyRecord) -> some View {
        Button { showReply.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(BudgeteerColors.green)
                Text("Developer replied")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(BudgeteerColors.green)
                Image(systemName: showReply ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(BudgeteerColors.green.opacity(0.6))
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 10)

        if showReply {
            VStack(alignment: .leading, spacing: 6) {
                Text(reply.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(reply.transcript)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
