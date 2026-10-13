/*
 * Copyright 2026, gRPC Authors All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Crypto
import Foundation
import SwiftASN1
import X509

/// Generates a throwaway, in-memory combination of a short-lived certificate authority,
/// along with a server certificate and a client certificate to use for validating mTLS logic for gRPC
/// without writing a certificate or private key to disk.
///
/// A new combination of all three is generated when `InMemoryPKI` is initialized. This follows the
/// pattern used by tests in the package `grpc-swift-nio-transport`, but in this setup
/// the client and server certificates are signed by the same CA, a little more aligned to validating
/// mTLS.
///
/// The `tls-hello-world` CLI doesn't use this all-at-once initializer directly --- `serve` and
/// `greet` are separate processes, so they instead share a ``CertificateAuthority`` persisted to
/// disk by `InMemoryPKIFiles`.
package struct InMemoryPKI {
  package struct KeyPair {
    package let certificateDER: [UInt8]
    package let privateKeyDER: [UInt8]
  }

  package let caCertificateDER: [UInt8]
  package let caPrivateKeyDER: [UInt8]
  package let server: KeyPair
  package let client: KeyPair

  package init() throws {
    let ca = try CertificateAuthority.makeDemoAuthority()

    self.caCertificateDER = ca.certificateDER
    self.caPrivateKeyDER = ca.privateKeyDER
    self.server = try ca.makeLeafCertificate(
      commonName: "Example Demo Server",
      extendedKeyUsage: .serverAuth,
      subjectAlternativeNames: [.dnsName("localhost")]
    )
    self.client = try ca.makeLeafCertificate(
      commonName: "Example Demo Client",
      extendedKeyUsage: .clientAuth
    )
  }
}

extension InMemoryPKI {
  /// A demo certificate authority that can mint new leaf certificates on demand.
  ///
  /// Unlike a real CA, this type exposes its own private key (``privateKeyDER``) so that it can
  /// be written to disk by one process (`serve`) and loaded back by another (`greet`) to mint a
  /// fresh, CA-signed client certificate per invocation. Do this only with a short-lived,
  /// throwaway demo CA like this one --- a real CA's private key should never leave the CA.
  package struct CertificateAuthority {
    package let certificateDER: [UInt8]
    package let privateKeyDER: [UInt8]

    fileprivate let certificate: Certificate
    fileprivate let privateKey: Certificate.PrivateKey

    /// Reconstructs a certificate authority from its DER-encoded certificate and private key,
    /// as previously produced by ``makeDemoAuthority(commonName:)`` (directly, or round-tripped
    /// through `InMemoryPKIFiles`).
    package init(certificateDER: [UInt8], privateKeyDER: [UInt8]) throws {
      self.certificateDER = certificateDER
      self.privateKeyDER = privateKeyDER
      self.certificate = try Certificate(derEncoded: certificateDER)
      self.privateKey = try Certificate.PrivateKey(derBytes: privateKeyDER)
    }

    /// Generates a fresh, self-signed, short-lived demo certificate authority.
    package static func makeDemoAuthority(
      commonName: String = "Example Demo CA"
    ) throws -> CertificateAuthority {
      let privateKey = Certificate.PrivateKey(P256.Signing.PrivateKey())
      let subjectName = try DistinguishedName { CommonName(commonName) }
      let now = Date()

      let certificate = try Certificate(
        version: .v3,
        serialNumber: Certificate.SerialNumber(),
        publicKey: privateKey.publicKey,
        notValidBefore: now.addingTimeInterval(-60 * 60),
        notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 7),
        issuer: subjectName,
        subject: subjectName,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try Certificate.Extensions {
          Critical(BasicConstraints.isCertificateAuthority(maxPathLength: nil))
          Critical(KeyUsage(keyCertSign: true, cRLSign: true))
        },
        issuerPrivateKey: privateKey
      )

      var serializer = DER.Serializer()
      try serializer.serialize(certificate)

      return try CertificateAuthority(
        certificateDER: serializer.serializedBytes,
        privateKeyDER: privateKey.serializeAsPEM().derBytes
      )
    }

    /// Mints a new leaf certificate signed by this authority.
    ///
    /// - Parameters:
    ///   - commonName: The leaf certificate subject's common name.
    ///   - extendedKeyUsage: Whether this leaf is for server or client authentication.
    ///   - subjectAlternativeNames: Additional SANs to bind to the subject, such as a
    ///     SPIFFE-style `uniformResourceIdentifier` workload identity for a client certificate.
    package func makeLeafCertificate(
      commonName: String,
      extendedKeyUsage: ExtendedKeyUsage.Usage,
      subjectAlternativeNames: [GeneralName] = []
    ) throws -> InMemoryPKI.KeyPair {
      let leafPrivateKey = Certificate.PrivateKey(P256.Signing.PrivateKey())
      let subjectName = try DistinguishedName { CommonName(commonName) }
      let now = Date()

      let extensions = try Certificate.Extensions {
        Critical(BasicConstraints.notCertificateAuthority)
        Critical(KeyUsage(digitalSignature: true, keyEncipherment: true))
        Critical(try ExtendedKeyUsage([extendedKeyUsage]))
        if !subjectAlternativeNames.isEmpty {
          SubjectAlternativeNames(subjectAlternativeNames)
        }
      }

      let certificate = try Certificate(
        version: .v3,
        serialNumber: Certificate.SerialNumber(),
        publicKey: leafPrivateKey.publicKey,
        notValidBefore: now.addingTimeInterval(-60 * 60),
        notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 7),
        issuer: self.certificate.subject,
        subject: subjectName,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: extensions,
        issuerPrivateKey: self.privateKey
      )

      var serializer = DER.Serializer()
      try serializer.serialize(certificate)

      return InMemoryPKI.KeyPair(
        certificateDER: serializer.serializedBytes,
        privateKeyDER: try leafPrivateKey.serializeAsPEM().derBytes
      )
    }
  }
}
