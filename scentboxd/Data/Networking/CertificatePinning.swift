//
//  CertificatePinning.swift
//  scentboxd
//
//  Public-key (SPKI) pinning for MITM protection on untrusted networks.
//  Pins are validated against the server's certificate chain during TLS handshake.
//

import Foundation
import CommonCrypto
import Security

// MARK: - Configuration

/// Public-key hashes (SHA-256, base64-encoded) of trusted certificates in the chain.
///
/// **How to obtain these pins:**
/// Run the following in Terminal (replace with your Supabase project URL):
/// ```
/// openssl s_client -connect YOUR_PROJECT.supabase.co:443 -servername YOUR_PROJECT.supabase.co </dev/null 2>/dev/null \
///   | openssl x509 -pubkey -noout \
///   | openssl pkey -pubin -outform DER \
///   | openssl dgst -sha256 -binary \
///   | base64
/// ```
/// Include at least 2 pins: the current leaf/intermediate + a backup.
enum CertificatePinningConfig {
    /// The host to pin (e.g. "xyzproject.supabase.co").
    /// Extracted at runtime from the configured SUPABASE_URL.
    static var pinnedHost: String? {
        URL(string: AppConfig.supabaseURL)?.host
    }

    /// SHA-256 SPKI hashes of trusted public keys.
    /// Include the intermediate CA pin for resilience against leaf certificate rotation.
    static let pinnedHashes: Set<String> = [
        // supabase.co leaf (EC 256 / SHA256withECDSA)
        "GU2W4j1P24T3sqlI+o6YTnidzz0PI8fB/Gvd2ITfSZE=",
        // WE1 intermediate (EC 256 / SHA384withECDSA)
        "kIdp6NNEd8wsugYyyIYFsi1ylMCED3hZbSR8ZFsa/A4=",
        // GTS Root R4 (EC 384 / SHA384withECDSA)
        "mEflZT5enoR1FuXLgYYGqnVEoZvmf9c2bVBpiOjYQ0c="
    ]

    /// When `true`, pinning is enforced and connections with non-matching
    /// certificates are rejected. Set to `false` to disable during development.
    static let isEnabled = true
}

// MARK: - Pinning Delegate

/// URLSession delegate that validates server certificates against pinned SPKI hashes.
/// Rejects connections if no public key in the server's certificate chain matches a known pin.
final class CertificatePinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard CertificatePinningConfig.isEnabled else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let pinnedHost = CertificatePinningConfig.pinnedHost,
              challenge.protectionSpace.host == pinnedHost
        else {
            // Not our pinned host or not a server trust challenge — use default
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Evaluate the server trust
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Check each certificate in the chain for a matching SPKI hash
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        for cert in certificateChain {
            if let publicKey = SecCertificateCopyKey(cert),
               let spkiData = subjectPublicKeyInfoData(for: publicKey) {
                let hash = sha256(data: spkiData)
                let base64Hash = hash.base64EncodedString()
                if CertificatePinningConfig.pinnedHashes.contains(base64Hash) {
                    completionHandler(.useCredential, URLCredential(trust: serverTrust))
                    return
                }
            }
        }

        // No matching pin found — reject the connection
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    // MARK: - Helpers

    private func sha256(data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }

    private func subjectPublicKeyInfoData(for key: SecKey) -> Data? {
        guard let publicKeyData = SecKeyCopyExternalRepresentation(key, nil) as Data? else {
            return nil
        }

        guard let attributes = SecKeyCopyAttributes(key) as? [CFString: Any],
              let keyType = attributes[kSecAttrKeyType] as? String,
              let keySizeBits = attributes[kSecAttrKeySizeInBits] as? Int else {
            return nil
        }

        guard let algorithmIdentifier = algorithmIdentifier(for: keyType, keySizeBits: keySizeBits) else {
            return nil
        }

        let bitString = derBitString(publicKeyData)
        return derSequence(algorithmIdentifier + bitString)
    }

    private func algorithmIdentifier(for keyType: String, keySizeBits: Int) -> Data? {
        let rsaKeyType = kSecAttrKeyTypeRSA as String
        let ecKeyType = kSecAttrKeyTypeECSECPrimeRandom as String

        switch (keyType, keySizeBits) {
        case (rsaKeyType, _):
            return Data([
                0x30, 0x0D,
                0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01,
                0x05, 0x00
            ])

        case (ecKeyType, 256):
            return Data([
                0x30, 0x13,
                0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01,
                0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07
            ])

        case (ecKeyType, 384):
            return Data([
                0x30, 0x10,
                0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01,
                0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x22
            ])

        default:
            return nil
        }
    }

    private func derSequence(_ data: Data) -> Data {
        Data([0x30]) + derLength(data.count) + data
    }

    private func derBitString(_ data: Data) -> Data {
        Data([0x03]) + derLength(data.count + 1) + Data([0x00]) + data
    }

    private func derLength(_ length: Int) -> Data {
        if length < 0x80 {
            return Data([UInt8(length)])
        }

        var value = length
        var bytes: [UInt8] = []
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }

        return Data([0x80 | UInt8(bytes.count)] + bytes)
    }
}

// MARK: - Pinned URLSession Factory

enum PinnedURLSession {
    /// Creates a URLSession with certificate pinning enabled.
    /// Falls back to `.shared` if pinning is not configured.
    static func makeSession() -> URLSession {
        guard CertificatePinningConfig.isEnabled else {
            return .shared
        }
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(
            configuration: configuration,
            delegate: CertificatePinningDelegate(),
            delegateQueue: nil
        )
    }
}
