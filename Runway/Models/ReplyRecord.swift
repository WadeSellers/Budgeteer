import CloudKit
import Foundation

struct ReplyRecord: Identifiable, Codable {
    let id: String                      // CKRecord.ID.recordName
    let postID: String                  // parent post's recordName
    let transcript: String
    let title: String
    var waveformSamples: [Float]
    let createdAt: Date

    // Local-only
    var cachedAudioURL: URL?

    // MARK: - CloudKit

    static let recordType = "TownHallReply"

    init(
        id: String = UUID().uuidString,
        postID: String,
        transcript: String,
        title: String,
        waveformSamples: [Float] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.postID = postID
        self.transcript = transcript
        self.title = title
        self.waveformSamples = waveformSamples
        self.createdAt = createdAt
    }

    init(from record: CKRecord) {
        self.id = record.recordID.recordName
        if let ref = record["postRef"] as? CKRecord.Reference {
            self.postID = ref.recordID.recordName
        } else {
            self.postID = ""
        }
        self.transcript = record["transcript"] as? String ?? ""
        self.title = record["title"] as? String ?? ""
        self.createdAt = record["createdAt"] as? Date ?? record.creationDate ?? .now

        if let data = record["waveformData"] as? Data {
            self.waveformSamples = data.withUnsafeBytes {
                Array($0.bindMemory(to: Float.self))
            }
        } else {
            self.waveformSamples = []
        }
    }

    func toCKRecord(audioURL: URL) -> CKRecord {
        let record = CKRecord(recordType: Self.recordType)
        record["transcript"] = transcript
        record["title"] = title
        record["createdAt"] = createdAt
        record["audio"] = CKAsset(fileURL: audioURL)

        let postRecordID = CKRecord.ID(recordName: postID)
        record["postRef"] = CKRecord.Reference(recordID: postRecordID, action: .deleteSelf)

        let waveData = waveformSamples.withUnsafeBufferPointer { Data(buffer: $0) }
        record["waveformData"] = waveData

        return record
    }
}
