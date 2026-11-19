import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard CommandLine.arguments.count == 4 else {
    fail("Usage: verify-update.swift Info.plist appcast.xml update.zip")
}

let appInfo = URL(fileURLWithPath: CommandLine.arguments[1])
let appcast = URL(fileURLWithPath: CommandLine.arguments[2])
let archive = URL(fileURLWithPath: CommandLine.arguments[3])
let properties = try PropertyListSerialization.propertyList(
    from: Data(contentsOf: appInfo), format: nil
) as? [String: Any]
let feed = try XMLDocument(contentsOf: appcast)
let enclosure = try feed.nodes(forXPath: "/rss/channel/item/enclosure").first as? XMLElement

guard let publicKey = properties?["SUPublicEDKey"] as? String,
      let keyBytes = Data(base64Encoded: publicKey),
      let signature = enclosure?.attribute(forName: "sparkle:edSignature")?.stringValue,
      let signatureBytes = Data(base64Encoded: signature) else {
    fail("The app’s public update key or the archive signature is missing.")
}

let verifier = try Curve25519.Signing.PublicKey(rawRepresentation: keyBytes)
guard verifier.isValidSignature(signatureBytes, for: try Data(contentsOf: archive, options: .mappedIfSafe)) else {
    fail("The release archive signature does not match the app’s public update key.")
}
