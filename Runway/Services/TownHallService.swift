import CloudKit
import Observation
import UIKit

@Observable
final class TownHallService {

    var posts: [PostRecord] = []
    var isLoading = false
    var error: String?

    private let container = CKContainer(identifier: "iCloud.com.wadesellers.Budgeteer")
    private var database: CKDatabase { container.publicCloudDatabase }

    let deviceID: String = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

    // Local reaction tracking (persisted in UserDefaults)
    private var reactedPosts: [String: String] = [:]  // [postID: reactionType]

    // Offline pending uploads
    private var pendingPosts: [PendingPost] = []

    private static let reactionsKey = "townhall_reactions"
    private static let pendingKey   = "townhall_pending"

    // MARK: - Init

    init() {
        loadLocalState()
    }

    // MARK: - Fetch Posts

    func fetchPosts(filter: PostType? = nil) async {
        isLoading = true
        error = nil

        do {
            var predicates: [NSPredicate] = [
                NSPredicate(format: "status != %@", "hidden")
            ]
            if let filter {
                predicates.append(NSPredicate(format: "type == %@", filter.rawValue))
            }

            let compound = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            let query = CKQuery(recordType: PostRecord.recordType, predicate: compound)
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            let (results, _) = try await database.records(matching: query, resultsLimit: 100)

            var fetched: [PostRecord] = []
            for (_, result) in results {
                if let record = try? result.get() {
                    fetched.append(PostRecord(from: record))
                }
            }

            // Fetch replies for posts that have them
            await fetchReplies(for: &fetched)

            await MainActor.run {
                self.posts = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "Couldn't load posts. Pull to retry."
                self.isLoading = false
                print("[Budgeteer] TownHall fetch error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Create Post

    func createPost(
        audioURL: URL,
        transcript: String,
        title: String,
        summary: String,
        type: PostType,
        waveformSamples: [Float]
    ) async throws {
        let post = PostRecord(
            transcript: transcript,
            title: title,
            summary: summary,
            type: type,
            reactions: Reactions(meToo: 0, greatIdea: 0, pleaseFix: 0),
            deviceID: deviceID,
            waveformSamples: waveformSamples
        )

        let record = post.toCKRecord(audioURL: audioURL)

        do {
            let saved = try await database.save(record)
            let newPost = PostRecord(from: saved)
            await MainActor.run {
                self.posts.insert(newPost, at: 0)
            }
        } catch {
            // Queue for later if offline
            queuePendingPost(
                audioURL: audioURL,
                transcript: transcript,
                title: title,
                summary: summary,
                type: type,
                waveformSamples: waveformSamples
            )
            throw error
        }
    }

    // MARK: - Reactions

    func react(to post: PostRecord, with reaction: ReactionType) async {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let existingReaction = reactedPosts[post.id]

        // If already reacted with the same type, remove the reaction
        if existingReaction == reaction.rawValue {
            reactedPosts.removeValue(forKey: post.id)
            decrementReaction(at: index, type: reaction)
        } else {
            // Remove old reaction if switching
            if let old = existingReaction, let oldType = ReactionType(rawValue: old) {
                decrementReaction(at: index, type: oldType)
            }
            reactedPosts[post.id] = reaction.rawValue
            incrementReaction(at: index, type: reaction)
        }
        saveLocalState()

        // Sync to CloudKit
        await syncReaction(postID: post.id, reaction: reactedPosts[post.id])
    }

    func userReaction(for postID: String) -> ReactionType? {
        guard let raw = reactedPosts[postID] else { return nil }
        return ReactionType(rawValue: raw)
    }

    func isOwnPost(_ post: PostRecord) -> Bool {
        post.deviceID == deviceID
    }

    // MARK: - Audio Download

    func downloadAudio(for post: PostRecord) async -> URL? {
        // Check cache first
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TownHall", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let cachedURL = cacheDir.appendingPathComponent("\(post.id).caf")
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }

        // Download from CloudKit
        do {
            let recordID = CKRecord.ID(recordName: post.id)
            let record = try await database.record(for: recordID)

            guard let asset = record["audio"] as? CKAsset,
                  let assetURL = asset.fileURL else { return nil }

            try FileManager.default.copyItem(at: assetURL, to: cachedURL)
            return cachedURL
        } catch {
            print("[Budgeteer] Audio download failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Replies

    func createReply(
        for post: PostRecord,
        audioURL: URL,
        transcript: String,
        title: String,
        waveformSamples: [Float]
    ) async throws {
        let reply = ReplyRecord(
            postID: post.id,
            transcript: transcript,
            title: title,
            waveformSamples: waveformSamples
        )

        let record = reply.toCKRecord(audioURL: audioURL)
        _ = try await database.save(record)

        // Update the post's status to "replied"
        let postRecordID = CKRecord.ID(recordName: post.id)
        let postRecord = try await database.record(for: postRecordID)
        postRecord["status"] = "replied"
        postRecord["hasDevReply"] = Int64(1)
        _ = try await database.save(postRecord)

        // Update local state
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            await MainActor.run {
                self.posts[index].status = .replied
                self.posts[index].reply = reply
            }
        }
    }

    func downloadReplyAudio(for reply: ReplyRecord) async -> URL? {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TownHall", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let cachedURL = cacheDir.appendingPathComponent("reply_\(reply.id).caf")
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }

        do {
            let recordID = CKRecord.ID(recordName: reply.id)
            let record = try await database.record(for: recordID)

            guard let asset = record["audio"] as? CKAsset,
                  let assetURL = asset.fileURL else { return nil }

            try FileManager.default.copyItem(at: assetURL, to: cachedURL)
            return cachedURL
        } catch {
            print("[Budgeteer] Reply audio download failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Admin — Hide/Unhide Posts

    func setPostStatus(_ post: PostRecord, status: PostStatus) async throws {
        let recordID = CKRecord.ID(recordName: post.id)
        let record = try await database.record(for: recordID)
        record["status"] = status.rawValue
        _ = try await database.save(record)

        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            await MainActor.run {
                if status == .hidden {
                    self.posts.remove(at: index)
                } else {
                    self.posts[index].status = status
                }
            }
        }
    }

    // MARK: - Offline Queue

    func flushPendingUploads() async {
        guard !pendingPosts.isEmpty else { return }
        var remaining: [PendingPost] = []

        for pending in pendingPosts {
            let audioURL = URL(fileURLWithPath: pending.localAudioPath)
            guard FileManager.default.fileExists(atPath: audioURL.path) else { continue }

            do {
                try await createPost(
                    audioURL: audioURL,
                    transcript: pending.transcript,
                    title: pending.title,
                    summary: pending.summary,
                    type: pending.type,
                    waveformSamples: pending.waveformSamples
                )
                // Clean up local file after successful upload
                try? FileManager.default.removeItem(at: audioURL)
            } catch {
                remaining.append(pending)
            }
        }

        pendingPosts = remaining
        saveLocalState()
    }

    // MARK: - Private Helpers

    private func fetchReplies(for posts: inout [PostRecord]) async {
        let repliedIDs = posts.enumerated().compactMap { (i, p) ->
            (Int, CKRecord.ID)? in
            p.status == .replied ? (i, CKRecord.ID(recordName: p.id)) : nil
        }
        guard !repliedIDs.isEmpty else { return }

        for (index, postRecordID) in repliedIDs {
            let predicate = NSPredicate(
                format: "postRef == %@",
                CKRecord.Reference(recordID: postRecordID, action: .none)
            )
            let query = CKQuery(recordType: ReplyRecord.recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            if let (results, _) = try? await database.records(matching: query, resultsLimit: 1),
               let first = results.first,
               let record = try? first.1.get() {
                posts[index].reply = ReplyRecord(from: record)
            }
        }
    }

    private func incrementReaction(at index: Int, type: ReactionType) {
        switch type {
        case .meToo:     posts[index].reactions.meToo += 1
        case .greatIdea: posts[index].reactions.greatIdea += 1
        case .pleaseFix: posts[index].reactions.pleaseFix += 1
        }
    }

    private func decrementReaction(at index: Int, type: ReactionType) {
        switch type {
        case .meToo:     posts[index].reactions.meToo = max(0, posts[index].reactions.meToo - 1)
        case .greatIdea: posts[index].reactions.greatIdea = max(0, posts[index].reactions.greatIdea - 1)
        case .pleaseFix: posts[index].reactions.pleaseFix = max(0, posts[index].reactions.pleaseFix - 1)
        }
    }

    private func syncReaction(postID: String, reaction: String?) async {
        do {
            let recordID = CKRecord.ID(recordName: postID)
            let postRecord = try await database.record(for: recordID)

            // Update counts from local state
            if let index = posts.firstIndex(where: { $0.id == postID }) {
                postRecord["reactionMeToo"] = Int64(posts[index].reactions.meToo)
                postRecord["reactionGreatIdea"] = Int64(posts[index].reactions.greatIdea)
                postRecord["reactionPleaseFix"] = Int64(posts[index].reactions.pleaseFix)
            }

            _ = try await database.save(postRecord)
        } catch {
            print("[Budgeteer] Reaction sync failed: \(error.localizedDescription)")
        }
    }

    private func queuePendingPost(
        audioURL: URL,
        transcript: String,
        title: String,
        summary: String,
        type: PostType,
        waveformSamples: [Float]
    ) {
        // Copy audio to a persistent location
        let pendingDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TownHallPending", isDirectory: true)
        try? FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)

        let id = UUID().uuidString
        let destURL = pendingDir.appendingPathComponent("\(id).caf")
        try? FileManager.default.copyItem(at: audioURL, to: destURL)

        let pending = PendingPost(
            id: id,
            localAudioPath: destURL.path,
            transcript: transcript,
            title: title,
            summary: summary,
            type: type,
            waveformSamples: waveformSamples,
            createdAt: .now
        )

        pendingPosts.append(pending)
        saveLocalState()
    }

    // MARK: - Persistence

    private func loadLocalState() {
        if let data = UserDefaults.standard.data(forKey: Self.reactionsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            reactedPosts = decoded
        }

        if let data = UserDefaults.standard.data(forKey: Self.pendingKey),
           let decoded = try? JSONDecoder().decode([PendingPost].self, from: data) {
            pendingPosts = decoded
        }
    }

    private func saveLocalState() {
        if let data = try? JSONEncoder().encode(reactedPosts) {
            UserDefaults.standard.set(data, forKey: Self.reactionsKey)
        }
        if let data = try? JSONEncoder().encode(pendingPosts) {
            UserDefaults.standard.set(data, forKey: Self.pendingKey)
        }
    }
}
