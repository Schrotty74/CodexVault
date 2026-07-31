import CryptoKit
import Foundation
import Security

struct EncryptedArchiveMetadata: Codable, Sendable {
    let version: Int
    let salt: Data
}

enum EncryptedArchive {
    static let metadataName = "encryption.json"
    static let payloadName = "encrypted-payload.bin"

    static func isEncrypted(packageURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: packageURL.appendingPathComponent(metadataName).path)
    }

    static func encrypt(packageURL: URL, password: String) throws {
        guard !password.isEmpty else { return }
        let manager = FileManager.default
        let temporaryZip = manager.temporaryDirectory.appendingPathComponent("CodexVault-\(UUID().uuidString).zip")
        defer { try? manager.removeItem(at: temporaryZip) }
        try runDitto(arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", packageURL.path, temporaryZip.path])
        let saltLength = 16
        var salt = Data(repeating: 0, count: saltLength)
        let randomStatus = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, saltLength, buffer.baseAddress!)
        }
        guard randomStatus == errSecSuccess else { throw BackupError.verificationFailed }
        let key = derivedKey(password: password, salt: salt)
        let encrypted = try AES.GCM.seal(Data(contentsOf: temporaryZip), using: key).combined!
        try manager.removeItem(at: packageURL)
        try manager.createDirectory(at: packageURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(EncryptedArchiveMetadata(version: 1, salt: salt)).write(to: packageURL.appendingPathComponent(metadataName), options: .atomic)
        try encrypted.write(to: packageURL.appendingPathComponent(payloadName), options: .atomic)
    }

    static func decryptedPackage(from packageURL: URL, password: String) throws -> URL {
        let manager = FileManager.default
        let metadata = try JSONDecoder().decode(EncryptedArchiveMetadata.self, from: Data(contentsOf: packageURL.appendingPathComponent(metadataName)))
        guard metadata.version == 1 else { throw BackupError.invalidBackup }
        let sealedBox = try AES.GCM.SealedBox(combined: Data(contentsOf: packageURL.appendingPathComponent(payloadName)))
        let zipData = try AES.GCM.open(sealedBox, using: derivedKey(password: password, salt: metadata.salt))
        let root = manager.temporaryDirectory.appendingPathComponent("CodexVault-Restore-\(UUID().uuidString)", isDirectory: true)
        let zip = root.appendingPathComponent("payload.zip")
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        try zipData.write(to: zip, options: .atomic)
        try runDitto(arguments: ["-x", "-k", zip.path, root.path])
        try manager.removeItem(at: zip)
        guard let unpacked = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]).first(where: { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }) else { throw BackupError.invalidBackup }
        return unpacked
    }

    private static func derivedKey(password: String, salt: Data) -> SymmetricKey {
        var material = Data(password.utf8) + salt
        for _ in 0..<100_000 { material = Data(SHA256.hash(data: material)) }
        return SymmetricKey(data: material)
    }

    private static func runDitto(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw BackupError.verificationFailed }
    }
}
