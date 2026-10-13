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

import GRPCCore
import GRPCNIOTransportHTTP2Posix
import NIOSSL
import TLSDemo
import Testing
import X509

@Suite("TLS and mTLS handshakes")
struct TLSHandshakeTests {
  // Server-authenticated TLS: the server presents a certificate signed by the demo CA; the
  // client trusts that CA and fully verifies the server's certificate, including its hostname
  // (the certificate's SAN is `localhost`, matching where the client connects).
  @Test("Server-authenticated TLS")
  func tls() async throws {
    // Creates an in-memory certificate authority, server certificate, and private key
    // to use for TLS or mTLS validation.
    let pki = try InMemoryPKI()

    let serverSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .tls(
      certificateChain: [.bytes(pki.server.certificateDER, format: .der)],
      privateKey: .bytes(pki.server.privateKeyDER, format: .der)
    )

    try await withGRPCServer(
      transport: .http2NIOPosix(
        address: .ipv4(host: "127.0.0.1", port: 0),
        transportSecurity: serverSecurity
      ),
      services: [Greeter()]
    ) { server in
      let port = try #require(await server.listeningAddress?.ipv4?.port)

      let clientSecurity: HTTP2ClientTransport.Posix.TransportSecurity = .tls {
        $0.trustRoots = .certificates([.bytes(pki.caCertificateDER, format: .der)])
      }

      let reply = try await withGRPCClient(
        transport: .http2NIOPosix(
          target: .dns(host: "localhost", port: port),
          transportSecurity: clientSecurity
        )
      ) { client in
        let greeter = Helloworld_Greeter.Client(wrapping: client)
        return try await greeter.sayHello(.with { $0.name = "TLS client" })
      }

      #expect(reply.message == "Hello, TLS client! This connection was verified.")
    }
  }

  // Mutual TLS: the server also requires and verifies a client certificate, and the client
  // presents one --- both signed by the same demo CA, so a single `trustRoots` value on each
  // side is enough to verify the other.
  @Test("Mutual TLS")
  func mtls() async throws {
    let pki = try InMemoryPKI()

    let serverSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .mTLS(
      certificateChain: [.bytes(pki.server.certificateDER, format: .der)],
      privateKey: .bytes(pki.server.privateKeyDER, format: .der)
    ) { config in
      config.trustRoots = .certificates([.bytes(pki.caCertificateDER, format: .der)])
    }

    try await withGRPCServer(
      transport: .http2NIOPosix(
        address: .ipv4(host: "127.0.0.1", port: 0),
        transportSecurity: serverSecurity
      ),
      services: [Greeter()]
    ) { server in
      let port = try #require(await server.listeningAddress?.ipv4?.port)

      let clientSecurity: HTTP2ClientTransport.Posix.TransportSecurity = .mTLS(
        certificateChain: [.bytes(pki.client.certificateDER, format: .der)],
        privateKey: .bytes(pki.client.privateKeyDER, format: .der)
      ) { config in
        config.trustRoots = .certificates([.bytes(pki.caCertificateDER, format: .der)])
      }

      let reply = try await withGRPCClient(
        transport: .http2NIOPosix(
          target: .dns(host: "localhost", port: port),
          transportSecurity: clientSecurity
        )
      ) { client in
        let greeter = Helloworld_Greeter.Client(wrapping: client)
        return try await greeter.sayHello(.with { $0.name = "mTLS client" })
      }

      #expect(reply.message == "Hello, mTLS client! This connection was verified.")
    }
  }

  // Creates a client certificate the same way as `generate --client-id alice`: a
  // fresh leaf certificate signed by the CA with a SPIFFE-style URI SAN embedded.
  // The server then reads the identity from the peer certificate chain using
  // `ServerContext.transportSpecific`.
  @Test("mTLS with an on-demand client identity")
  func mtlsWithOnDemandClientIdentity() async throws {
    let authority = try InMemoryPKI.CertificateAuthority.makeDemoAuthority()
    let server = try authority.makeLeafCertificate(
      commonName: "Example Demo Server",
      extendedKeyUsage: .serverAuth,
      subjectAlternativeNames: [.dnsName("localhost")]
    )

    let serverSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .mTLS(
      certificateChain: [.bytes(server.certificateDER, format: .der)],
      privateKey: .bytes(server.privateKeyDER, format: .der)
    ) { config in
      config.trustRoots = .certificates([.bytes(authority.certificateDER, format: .der)])
    }

    try await withGRPCServer(
      transport: .http2NIOPosix(
        address: .ipv4(host: "127.0.0.1", port: 0),
        transportSecurity: serverSecurity
      ),
      services: [Greeter()]
    ) { grpcServer in
      let port = try #require(await grpcServer.listeningAddress?.ipv4?.port)

      let identity = "spiffe://tls-hello-world.example/client/alice"
      let client = try authority.makeLeafCertificate(
        commonName: "Example Demo Client (alice)",
        extendedKeyUsage: .clientAuth,
        subjectAlternativeNames: [.uniformResourceIdentifier(identity)]
      )

      let clientSecurity: HTTP2ClientTransport.Posix.TransportSecurity = .mTLS(
        certificateChain: [.bytes(client.certificateDER, format: .der)],
        privateKey: .bytes(client.privateKeyDER, format: .der)
      ) { config in
        config.trustRoots = .certificates([.bytes(authority.certificateDER, format: .der)])
      }

      let reply = try await withGRPCClient(
        transport: .http2NIOPosix(
          target: .dns(host: "localhost", port: port),
          transportSecurity: clientSecurity
        )
      ) { client in
        let greeter = Helloworld_Greeter.Client(wrapping: client)
        return try await greeter.sayHello(.with { $0.name = "alice" })
      }

      #expect(reply.message == "Hello, alice! Verified client identity: \(identity).")
    }
  }

  // The mirror image of the previous test, using `generate --untrusted-ca`, then
  // `greet --mode mtls --untrusted-ca` to demonstrate mTLS trust failure. The client
  // certificate is signed by a CA the server never trusted, so the handshake fails.
  @Test("mTLS rejects a client certificate signed by an untrusted CA")
  func mtlsRejectsUntrustedClientCA() async throws {
    let authority = try InMemoryPKI.CertificateAuthority.makeDemoAuthority()
    let server = try authority.makeLeafCertificate(
      commonName: "Example Demo Server",
      extendedKeyUsage: .serverAuth,
      subjectAlternativeNames: [.dnsName("localhost")]
    )

    let serverSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .mTLS(
      certificateChain: [.bytes(server.certificateDER, format: .der)],
      privateKey: .bytes(server.privateKeyDER, format: .der)
    ) { config in
      config.trustRoots = .certificates([.bytes(authority.certificateDER, format: .der)])
    }

    try await withGRPCServer(
      transport: .http2NIOPosix(
        address: .ipv4(host: "127.0.0.1", port: 0),
        transportSecurity: serverSecurity
      ),
      services: [Greeter()]
    ) { grpcServer in
      let port = try #require(await grpcServer.listeningAddress?.ipv4?.port)

      // Signed by a CA the server has never heard of, rather than `authority`.
      let untrustedAuthority = try InMemoryPKI.CertificateAuthority.makeDemoAuthority(
        commonName: "Untrusted Impostor CA"
      )
      let client = try untrustedAuthority.makeLeafCertificate(
        commonName: "Example Demo Client (mallory)",
        extendedKeyUsage: .clientAuth,
        subjectAlternativeNames: [
          .uniformResourceIdentifier("spiffe://tls-hello-world.example/client/mallory")
        ]
      )

      let clientSecurity: HTTP2ClientTransport.Posix.TransportSecurity = .mTLS(
        certificateChain: [.bytes(client.certificateDER, format: .der)],
        privateKey: .bytes(client.privateKeyDER, format: .der)
      ) { config in
        config.trustRoots = .certificates([.bytes(authority.certificateDER, format: .der)])
      }

      await #expect(throws: RPCError.self) {
        try await withGRPCClient(
          transport: .http2NIOPosix(
            target: .dns(host: "localhost", port: port),
            transportSecurity: clientSecurity
          )
        ) { client in
          let greeter = Helloworld_Greeter.Client(wrapping: client)
          _ = try await greeter.sayHello(.with { $0.name = "mallory" })
        }
      }
    }
  }

  // Custom server-side verification example

  // Instead of one of the built-in verification modes, this example runs its own
  // logic to validate the client's certificate chain.
  //
  // The callback receives that certificate chain and a promise it must fulfill with the
  // verification outcome. It's only invoked because `clientCertificateVerification` here is
  // `noHostnameVerification` (set by `.mTLS`'s defaults) rather than `.noVerification`.
  @Test("Custom server-side verification callback")
  func customServerVerificationCallback() async throws {
    let pki = try InMemoryPKI()

    try await confirmation(expectedCount: 1) { calledCustomCallback in
      let serverSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .mTLS(
        certificateChain: [.bytes(pki.server.certificateDER, format: .der)],
        privateKey: .bytes(pki.server.privateKeyDER, format: .der)
      ) { config in
        config.trustRoots = .certificates([.bytes(pki.caCertificateDER, format: .der)])
        config.customVerificationCallback = { certificates, promise in
          // What the callback has access to: the peer's presented certificate chain (just the
          // client's leaf certificate here, since InMemoryPKI signs it directly with the CA), and a
          // promise that must be fulfilled with the verification outcome.

          // Convert from an NIOSSLCertificate into a swift-certificates Certificate
          // (https://swiftpackageindex.com/apple/swift-certificates/documentation/x509/certificate)
          // to more easily access the distinguished name (unique identity) of the subject of the certificate.
          let presented = try! Certificate(derEncoded: certificates[0].toDERBytes())

          // In a SPIFFE-style workload validation, the client will have its unique identity
          // encoded in the certificate's Subject Alternative Name (SAN), accessible
          // from the `subject`, which is an instance of `DistinguishedName`.
          // (https://swiftpackageindex.com/apple/swift-certificates/documentation/x509/distinguishedname)
          #expect(presented.subject.description.contains("Example Demo Client"))

          calledCustomCallback.confirm()
          promise.succeed(
            .certificateVerified(
              VerificationMetadata(
                ValidatedCertificateChain(certificates)
              )
            )
          )
        }
      }

      try await withGRPCServer(
        transport: .http2NIOPosix(
          address: .ipv4(host: "127.0.0.1", port: 0),
          transportSecurity: serverSecurity
        ),
        services: [Greeter()]
      ) { server in
        let port = try #require(await server.listeningAddress?.ipv4?.port)

        let clientSecurity: HTTP2ClientTransport.Posix.TransportSecurity = .mTLS(
          certificateChain: [.bytes(pki.client.certificateDER, format: .der)],
          privateKey: .bytes(pki.client.privateKeyDER, format: .der)
        ) { config in
          config.trustRoots = .certificates([.bytes(pki.caCertificateDER, format: .der)])
        }

        let reply = try await withGRPCClient(
          transport: .http2NIOPosix(
            target: .dns(host: "localhost", port: port),
            transportSecurity: clientSecurity
          )
        ) { client in
          let greeter = Helloworld_Greeter.Client(wrapping: client)
          return try await greeter.sayHello(.with { $0.name = "mTLS client" })
        }

        #expect(reply.message == "Hello, mTLS client! This connection was verified.")
      }
    }
  }

  // Custom client-side verification: the mirror image of the server-side case above, but
  // gated on `serverCertificateVerification` instead. The callback again receives the presented
  // certificate chain --- the server's leaf certificate --- and a promise to fulfill.
  @Test("Custom client-side verification callback")
  func customClientVerificationCallback() async throws {
    let pki = try InMemoryPKI()

    let serverSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .tls(
      certificateChain: [.bytes(pki.server.certificateDER, format: .der)],
      privateKey: .bytes(pki.server.privateKeyDER, format: .der)
    )

    try await confirmation(expectedCount: 1) { calledCustomCallback in
      try await withGRPCServer(
        transport: .http2NIOPosix(
          address: .ipv4(host: "127.0.0.1", port: 0),
          transportSecurity: serverSecurity
        ),
        services: [Greeter()]
      ) { server in
        let port = try #require(await server.listeningAddress?.ipv4?.port)

        let clientSecurity: HTTP2ClientTransport.Posix.TransportSecurity = .tls {
          $0.trustRoots = .certificates([.bytes(pki.caCertificateDER, format: .der)])
          $0.customVerificationCallback = { certificates, promise in
            let presented = try! Certificate(derEncoded: certificates[0].toDERBytes())
            #expect(presented.subject.description.contains("Example Demo Server"))

            calledCustomCallback.confirm()
            promise.succeed(
              .certificateVerified(
                VerificationMetadata(
                  ValidatedCertificateChain(certificates)
                )
              )
            )
          }
        }

        let reply = try await withGRPCClient(
          transport: .http2NIOPosix(
            target: .dns(host: "localhost", port: port),
            transportSecurity: clientSecurity
          )
        ) { client in
          let greeter = Helloworld_Greeter.Client(wrapping: client)
          return try await greeter.sayHello(.with { $0.name = "TLS client" })
        }

        #expect(reply.message == "Hello, TLS client! This connection was verified.")
      }
    }
  }
}
