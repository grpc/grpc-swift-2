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

import Foundation
import SwiftASN1
import X509

/// Persists a ``InMemoryPKI/CertificateAuthority`` and the leaf certificates it signs to disk
/// as PEM files, and loads them back.
///
/// `generate`, `serve`, and `greet` are separate invocations, so they need a shared
/// directory: `generate` creates the demo CA (reusing one already on disk, if
/// present), a server certificate, and any client certificates and writes them to disk.
/// `serve` and `greet` read from the directory.
///
/// Writing the CA's private key to disk only IS NOT SECURE, and is meant only to showcase
/// this demonstration. A real certificate authority's private key should never leave the CA.
package enum InMemoryPKIFiles {
  /// The default directory that hosts CA and PKI files.
  package static var defaultDirectory: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      "tls-hello-world-demo-pki",
      isDirectory: true
    )
  }

  /// The certificate location for the name of certificate you provide.
  ///
  /// The path `named(_:)` writes/reads a certificate at, for example `"server"` for
  /// `server-cert.pem` or `"client-alice"` for `client-alice-cert.pem`.
  package static func certificatePath(named name: String, in directory: URL) -> URL {
    directory.appendingPathComponent("\(name)-cert.pem")
  }

  /// The private key location for the name of the private key you provide.
  ///
  /// The path `named(_:)` writes/reads a private key at, e.g. `"server"` for
  /// `server-key.pem` or `"client-alice"` for `client-alice-key.pem`.
  package static func privateKeyPath(named name: String, in directory: URL) -> URL {
    directory.appendingPathComponent("\(name)-key.pem")
  }

  private static func writeCertificate(derEncoded certificateDER: [UInt8], to path: URL) throws {
    let certificate = try Certificate(derEncoded: certificateDER)
    let certificatePEM = try certificate.serializeAsPEM().pemString
    try Data(certificatePEM.utf8).write(to: path)
  }

  private static func writePrivateKey(derEncoded privateKeyDER: [UInt8], to path: URL) throws {
    let privateKey = try Certificate.PrivateKey(derBytes: privateKeyDER)
    let privateKeyPEM = try privateKey.serializeAsPEM().pemString
    try Data(privateKeyPEM.utf8).write(to: path)
  }

  /// Whether a demo certificate authority previously written by ``write(_:to:)`` exists in
  /// `directory`, so callers (like `generate`) can decide whether to mint a new one or reuse it.
  package static func certificateAuthorityExists(in directory: URL) -> Bool {
    let fileManager = FileManager.default
    return fileManager.fileExists(atPath: certificatePath(named: "ca", in: directory).path)
      && fileManager.fileExists(atPath: privateKeyPath(named: "ca", in: directory).path)
  }

  /// Writes `authority`'s certificate and private key to `directory` as PEM files.
  package static func write(_ authority: InMemoryPKI.CertificateAuthority, to directory: URL) throws
  {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try writeCertificate(
      derEncoded: authority.certificateDER,
      to: certificatePath(named: "ca", in: directory)
    )
    try writePrivateKey(
      derEncoded: authority.privateKeyDER,
      to: privateKeyPath(named: "ca", in: directory)
    )
  }

  /// Writes `keyPair`'s certificate and private key to `directory` as PEM files, using `name`
  /// as the file name stem --- see ``certificatePath(named:in:)`` and ``privateKeyPath(named:in:)``.
  package static func write(
    _ keyPair: InMemoryPKI.KeyPair,
    named name: String,
    to directory: URL
  )
    throws
  {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try writeCertificate(
      derEncoded: keyPair.certificateDER,
      to: certificatePath(named: name, in: directory)
    )
    try writePrivateKey(
      derEncoded: keyPair.privateKeyDER,
      to: privateKeyPath(named: name, in: directory)
    )
  }

  /// Loads a demo certificate authority previously written by ``write(_:to:)``.
  package static func loadCertificateAuthority(
    from directory: URL
  ) throws -> InMemoryPKI.CertificateAuthority {
    let certificatePEMData = try Data(contentsOf: certificatePath(named: "ca", in: directory))
    let privateKeyPEMData = try Data(contentsOf: privateKeyPath(named: "ca", in: directory))

    let certificate = try Certificate(
      pemEncoded: String(decoding: certificatePEMData, as: UTF8.self)
    )
    let privateKey = try Certificate.PrivateKey(
      pemEncoded: String(decoding: privateKeyPEMData, as: UTF8.self)
    )

    var serializer = DER.Serializer()
    try serializer.serialize(certificate)

    return try InMemoryPKI.CertificateAuthority(
      certificateDER: serializer.serializedBytes,
      privateKeyDER: privateKey.serializeAsPEM().derBytes
    )
  }
}
