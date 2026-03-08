//
//  CertificatePinning.swift
//  scentboxd
//
//  Public-key (SPKI) pinning for MITM protection on untrusted networks.
//  Pins are validated against the server's certificate chain during TLS handshake.
//

import Foundation
import CommonCrypto

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
        // TODO: Add correct SPKI hashes for your Supabase project.
        // Pinning is disabled while this set is empty (see isEnabled).
    ]

    /// When `true`, pinning is enforced and connections with non-matching
    /// certificates are rejected. Set to `false` to disable during development.
    static let isEnabled: Bool = !pinnedHashes.isEmpty
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
               let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? {
                let hash = sha256(data: publicKeyData)
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
