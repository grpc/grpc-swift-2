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
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf
import TLSDemo

struct Greet: AsyncParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Sends a request to the greeter server")

  @Option(help: "The port to connect to")
  var port: Int = 31415

  @Option(help: "The person to greet")
  var name: String = ""

  @Option(help: "Whether to expect the server to also verify a client certificate")
  var mode: TransportMode = .tls

  @Option(
    help:
      "Directory to read the certificates `generate` wrote from --- must match the directory `generate` (and `serve`) used"
  )
  var pkiDirectory: String = InMemoryPKIFiles.defaultDirectory.path

  @Option(
    help:
      "Workload identity whose pre-generated client certificate to present (mTLS only) --- must match a --client-id previously passed to `generate`"
  )
  var clientID: String = "demo-client"

  @Flag(
    help:
      "Present the client certificate generate --untrusted-ca produced, signed by a CA the server doesn't trust, to demonstrate an mTLS trust failure (mTLS only)"
  )
  var untrustedCA: Bool = false

  func run() async throws {
    let directory = URL(fileURLWithPath: self.pkiDirectory)
    let caCertificatePath = InMemoryPKIFiles.certificatePath(named: "ca", in: directory)
    try requirePKIFilesExist([caCertificatePath])

    let transportSecurity: HTTP2ClientTransport.Posix.TransportSecurity
    switch self.mode {
    case .tls:
      transportSecurity = .tls { config in
        config.trustRoots = .certificates([.file(path: caCertificatePath.path, format: .pem)])
      }

    case .mtls:
      let clientName = self.untrustedCA ? "untrusted-client" : "client-\(self.clientID)"
      let clientCertificatePath = InMemoryPKIFiles.certificatePath(named: clientName, in: directory)
      let clientPrivateKeyPath = InMemoryPKIFiles.privateKeyPath(named: clientName, in: directory)
      try requirePKIFilesExist([clientCertificatePath, clientPrivateKeyPath])

      if self.untrustedCA {
        print("Presenting a client certificate signed by an untrusted CA (expect this to fail)...")
      }

      transportSecurity = .mTLS(
        certificateChain: [.file(path: clientCertificatePath.path, format: .pem)],
        privateKey: .file(path: clientPrivateKeyPath.path, format: .pem)
      ) { config in
        // The client still trusts the real server CA --- only the client's own certificate is
        // (optionally) signed by a CA the server doesn't recognize.
        config.trustRoots = .certificates([.file(path: caCertificatePath.path, format: .pem)])
      }
    }

    do {
      try await withGRPCClient(
        transport: .http2NIOPosix(
          target: .dns(host: "localhost", port: self.port),
          transportSecurity: transportSecurity
        )
      ) { client in
        let greeter = Helloworld_Greeter.Client(wrapping: client)
        let reply = try await greeter.sayHello(.with { $0.name = self.name })
        print(reply.message)
      }
    } catch {
      print("Request failed: \(error)")
    }
  }
}
