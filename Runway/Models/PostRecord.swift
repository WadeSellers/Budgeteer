import CloudKit
import SwiftUI

// MARK: - Post Type

enum PostType: String, CaseIterable, Codable {
    case bug, feature, feedback

    var label: String {
        switch self {
        case .bug:      "Bug"
        case .feature:  "Feature"
        case .feedback: "Feedback"
        }
    }

    var icon: String {
        switch self {
        case .bug:      "ladybug.fill"
        case .feature:  "lightbulb.fill"
        case .feedback: "bubble.left.fill"
        }
    }

    var color: Color {
        switch self {
        case .bug:      Color.orange
        case .feature:  Color.blue
        case .feedback: BudgeteerColors.green
        }
    }

    var prompt: String {
        switch self {
        case .bug:      "What went wrong?"
        case .feature:  "What would make Budgeteer better?"
        case .feedback: "What's on your mind?"
        }
    }
}

// MARK: - Post Status

enum PostStatus: String, Codable {
    case active, replied, hidden
}

// MARK: - Reactions

struct Reactions: Codable, Equatable {
    var meToo: Int = 0
    var greatIdea: Int = 0
    var pleaseFix: Int = 0

    var total: Int { meToo + greatIdea + pleaseFix }
}

enum ReactionType: String, CaseIterable, Codable {
    case meToo     = "metoo"
    case greatIdea = "greatidea"
    case pleaseFix = "pleasefix"

    var emoji: String {
        switch self {
        case .meToo:     "🙋"
        case .greatIdea: "💡"
        case .pleaseFix: "🔧"
        }
    }

    var label: String {
        switch self {
        case .meToo:     "Me too"
        case .greatIdea: "Great idea"
        case .pleaseFix: "Please fix"
        }
    }
}

// MARK: - Post Record

struct PostRecord: Identifiable, Codable {
    let id: String                      // CKRecord.ID.recordName
    let transcript: String
    let title: String
    let summary: String
    let type: PostType
    var reactions: Reactions
    let deviceID: String
    var status: PostStatus
    var waveformSamples: [Float]
    let createdAt: Date
    var reply: ReplyRecord?

    // Local-only state (not persisted to CloudKit)
    var localAudioURL: URL?
    var cachedAudioURL: URL?

    // MARK: - CloudKit Mapping

    static let recordType = "TownHallPost"

    init(
        id: String = UUID().uuidString,
        transcript: String,
        title: String,
        summary: String,
        type: PostType,
        reactions: Reactions = Reactions(),
        deviceID: String,
        status: PostStatus = .active,
        waveformSamples: [Float] = [],
        createdAt: Date = .now,
        reply: ReplyRecord? = nil
    ) {
        self.id = id
        self.transcript = transcript
        self.title = title
        self.summary = summary
        self.type = type
        self.reactions = reactions
        self.deviceID = deviceID
        self.status = status
        self.waveformSamples = waveformSamples
        self.createdAt = createdAt
        self.reply = reply
    }

    init(from record: CKRecord) {
        self.id = record.recordID.recordName
        self.transcript = record["transcript"] as? String ?? ""
        self.title = record["title"] as? String ?? "Voice note"
        self.summary = record["summary"] as? String ?? ""
        self.type = PostType(rawValue: record["type"] as? String ?? "feedback") ?? .feedback
        self.reactions = Reactions(
            meToo: Int(record["reactionMeToo"] as? Int64 ?? 0),
            greatIdea: Int(record["reactionGreatIdea"] as? Int64 ?? 0),
            pleaseFix: Int(record["reactionPleaseFix"] as? Int64 ?? 0)
        )
        self.deviceID = record["deviceID"] as? String ?? ""
        self.status = PostStatus(rawValue: record["status"] as? String ?? "active") ?? .active
        self.createdAt = record["createdAt"] as? Date ?? record.creationDate ?? .now

        // Decode waveform from Data
        if let data = record["waveformData"] as? Data {
            self.waveformSamples = data.withUnsafeBytes {
                Array($0.bindMemory(to: Float.self))
            }
        } else {
            self.waveformSamples = []
        }

        self.reply = nil
    }

    func toCKRecord(audioURL: URL? = nil) -> CKRecord {
        let record = CKRecord(recordType: Self.recordType)
        record["transcript"] = transcript
        record["title"] = title
        record["summary"] = summary
        record["type"] = type.rawValue
        record["reactionMeToo"] = Int64(reactions.meToo)
        record["reactionGreatIdea"] = Int64(reactions.greatIdea)
        record["reactionPleaseFix"] = Int64(reactions.pleaseFix)
        record["deviceID"] = deviceID
        record["status"] = status.rawValue
        record["createdAt"] = createdAt

        // Encode waveform as Data
        let waveData = waveformSamples.withUnsafeBufferPointer { Data(buffer: $0) }
        record["waveformData"] = waveData

        // Audio asset
        if let url = audioURL ?? localAudioURL {
            record["audio"] = CKAsset(fileURL: url)
        }

        return record
    }
}

// MARK: - Pending Post (offline queue)

struct PendingPost: Codable {
    let id: String
    let localAudioPath: String
    let transcript: String
    let title: String
    let summary: String
    let type: PostType
    let waveformSamples: [Float]
    let createdAt: Date
}
