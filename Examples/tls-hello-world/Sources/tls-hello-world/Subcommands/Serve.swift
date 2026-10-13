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
import TLSDemo

struct Serve: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Starts a greeter server secured with TLS or mTLS."
  )

  @Option(help: "The port to listen on")
  var port: Int = 31415

  @Option(help: "Whether to require and verify a client certificate")
  var mode: TransportMode = .tls

  @Option(
    help:
      "Directory to read the certificates `generate` wrote from --- must match the directory `generate` (and, for mTLS, `greet`) used"
  )
  var pkiDirectory: String = InMemoryPKIFiles.defaultDirectory.path

  func run() async throws {
    let directory = URL(fileURLWithPath: self.pkiDirectory)
    let serverCertificatePath = InMemoryPKIFiles.certificatePath(named: "server", in: directory)
    let serverPrivateKeyPath = InMemoryPKIFiles.privateKeyPath(named: "server", in: directory)
    try requirePKIFilesExist([serverCertificatePath, serverPrivateKeyPath])

    let transportSecurity: HTTP2ServerTransport.Posix.TransportSecurity
    switch self.mode {
    case .tls:
      transportSecurity = .tls(
        certificateChain: [.file(path: serverCertificatePath.path, format: .pem)],
        privateKey: .file(path: serverPrivateKeyPath.path, format: .pem)
      )

    case .mtls:
      let caCertificatePath = InMemoryPKIFiles.certificatePath(named: "ca", in: directory)
      try requirePKIFilesExist([caCertificatePath])

      transportSecurity = .mTLS(
        certificateChain: [.file(path: serverCertificatePath.path, format: .pem)],
        privateKey: .file(path: serverPrivateKeyPath.path, format: .pem)
      ) { config in
        config.trustRoots = .certificates([.file(path: caCertificatePath.path, format: .pem)])
      }
    }

    let grpcServer = GRPCServer(
      transport: .http2NIOPosix(
        address: .ipv4(host: "127.0.0.1", port: self.port),
        transportSecurity: transportSecurity
      ),
      services: [Greeter()]
    )

    try await withThrowingDiscardingTaskGroup { group in
      group.addTask { try await grpcServer.serve() }
      if let address = try await grpcServer.listeningAddress {
        print("Greeter listening on \(address) (\(self.mode.rawValue))")
      }
    }
  }
}
