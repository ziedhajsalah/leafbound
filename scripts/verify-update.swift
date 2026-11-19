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
let feedVersion = try feed.nodes(forXPath: "/rss/channel/item/*[local-name()='shortVersionString']").first
let feedBuild = try feed.nodes(forXPath: "/rss/channel/item/*[local-name()='version']").first
let enclosure = try feed.nodes(forXPath: "/rss/channel/item/enclosure").first as? XMLElement

guard let version = properties?["CFBundleShortVersionString"] as? String,
      let build = properties?["CFBundleVersion"] as? String,
      feedVersion?.stringValue == version,
      feedBuild?.stringValue == build else {
    fail("The update feed’s version and build must match the app bundle.")
}

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
