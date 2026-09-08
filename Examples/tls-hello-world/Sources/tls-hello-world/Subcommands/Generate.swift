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

import ArgumentParser
import Foundation
import TLSDemo

struct Generate: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract:
      "Generates the demo certificate authority and certificates that `serve` and `greet` use."
  )

  @Option(
    help:
      "Directory to write the generated certificate authority and certificates to; `serve` and `greet` read from the same directory"
  )
  var pkiDirectory: String = InMemoryPKIFiles.defaultDirectory.path

  @Option(
    help:
      "Client identity to mint a certificate for, signed by the demo certificate authority; `greet --client-id` selects it by this same name"
  )
  var clientID: String = "demo-client"

  @Flag(
    help:
      "Also mint a client certificate signed by a separate, untrusted certificate authority, for `greet --untrusted-ca` to demonstrate an mTLS trust failure"
  )
  var untrustedCA: Bool = false

  func run() async throws {
    let directory = URL(fileURLWithPath: self.pkiDirectory)

    let authority: InMemoryPKI.CertificateAuthority
    if InMemoryPKIFiles.certificateAuthorityExists(in: directory) {
      authority = try InMemoryPKIFiles.loadCertificateAuthority(from: directory)
      print("Reusing existing demo CA in \(directory.path)")
    } else {
      authority = try InMemoryPKI.CertificateAuthority.makeDemoAuthority()
      try InMemoryPKIFiles.write(authority, to: directory)
      print("Generated demo CA in \(directory.path)")
    }

    let server = try authority.makeLeafCertificate(
      commonName: "Example Demo Server",
      extendedKeyUsage: .serverAuth,
      subjectAlternativeNames: [.dnsName("localhost")]
    )
    try InMemoryPKIFiles.write(server, named: "server", to: directory)
    print("Generated server certificate for 'localhost'")

    let clientName = "client-\(self.clientID)"
    let identity = "spiffe://tls-hello-world.example/client/\(self.clientID)"
    let client = try authority.makeLeafCertificate(
      commonName: "Example Demo Client (\(self.clientID))",
      extendedKeyUsage: .clientAuth,
      subjectAlternativeNames: [.uniformResourceIdentifier(identity)]
    )
    try InMemoryPKIFiles.write(client, named: clientName, to: directory)
    print("Generated client certificate for '\(self.clientID)' (identity: \(identity))")

    if self.untrustedCA {
      let untrustedAuthority = try InMemoryPKI.CertificateAuthority.makeDemoAuthority(
        commonName: "Untrusted Impostor CA"
      )
      let untrustedClient = try untrustedAuthority.makeLeafCertificate(
        commonName: "Example Demo Client (untrusted)",
        extendedKeyUsage: .clientAuth,
        subjectAlternativeNames: [
          .uniformResourceIdentifier("spiffe://tls-hello-world.example/client/untrusted")
        ]
      )
      try InMemoryPKIFiles.write(untrustedClient, named: "untrusted-client", to: directory)
      print("Generated client certificate signed by an untrusted CA (for greet --untrusted-ca)")
    }
  }
}
