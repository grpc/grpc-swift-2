# TLS

Encrypt gRPC connections and authenticate the server using the transport's TLS configuration.

## Overview

gRPC Swift provides an abstraction that supports multiple kinds of network connections and their configuration.
Other gRPC transports provide their own configuration options.

Begin by choosing the transport to use, then import either the umbrella [GRPCNIOTransportHTTP2](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2)
product or the platform-specific [GRPCNIOTransportHTTP2Posix](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix) or [GRPCNIOTransportHTTP2TransportServices](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2transportservices) directly.

With the dependency added, specify the transport and choose the security posture with the `transportSecurity:` parameter that you pass into the factory methods for the transports. Use `TransportServices` only on Apple platforms. The following table links to each factory method's documentation:

| Transport | Client | Server |
|---|---|---|
| POSIX | [.http2NIOPosix](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix/grpcniotransportcore/http2clienttransport/posix/http2nioposix(target:transportsecurity:config:resolverregistry:serviceconfig:eventloopgroup:)) | [.http2NIOPosix](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix/grpcniotransportcore/http2servertransport/posix/http2nioposix(address:transportsecurity:config:eventloopgroup:)) |
| TransportServices | [.http2NIOTS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2transportservices/grpcniotransportcore/http2clienttransport/transportservices/http2niots(target:transportsecurity:config:resolverregistry:serviceconfig:eventloopgroup:)) | [.http2NIOTS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2transportservices/grpcniotransportcore/http2servertransport/transportservices/http2niots(address:transportsecurity:config:eventloopgroup:)) |

The gRPC Swift API provides specific types for each transport, with separate server and client transport types.
Each transport type provides its own `TransportSecurity` type that offers the choice between:

- `.plaintext`: no encryption or verification
- `.tls`: encrypt and authenticate the server
- `.mTLS`: encrypt and authenticate both the client and the server

The remainder of this article covers configuring TLS connections.
Read <doc:mTLS> for more information on configuring mutual TLS.

### Choose and configure a transport security mode

When you choose `.tls`, you can use the system defaults, which verify the host certificate against the system's trusted certificates.
You can also fully control the TLS configuration, including the certificate chain, the [trust roots or their locations](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransportcore/tlsconfig/trustrootssource), and the [level of certificate validation](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransportcore/tlsconfig/certificateverification) that the API provides.

Configure the security for the transport when you create the client.
The following example shows a default `.tls` configuration for connecting to an external host by its DNS name:

```swift
let reply = try await withGRPCClient(
  transport: .http2NIOPosix(
    target: .dns(host: "your-gRPC-service.com"),
    transportSecurity: .tls
  )
) { client in
  // ...
}
```

The same pattern works on Apple platforms with `TransportServices`, which builds on Apple's [Network](https://developer.apple.com/documentation/network) framework.
The following example uses the `TransportServices` factory method to create the transport:

```swift
let reply = try await withGRPCClient(
  transport: .http2NIOTS(
    target: .dns(host: "your-gRPC-service.com"),
    transportSecurity: .tls
  )
) { client in
  // ...
}
```

You can create a TLS configuration and use it across multiple client instances, or use `.tls(configure:)` to adjust the default configuration.
For example, the following code disables hostname verification during TLS validation:

```swift
let reply = try await withGRPCClient(
  transport: .http2NIOPosix(
    target: .dns(host: "your-gRPC-service.com"),
    transportSecurity: .tls { config in
      config.serverCertificateVerification = .noHostnameVerification
    }
  )
) { client in
  // ...
}
```

Code for gRPC Swift spans multiple packages and modules.
The transport packages define distinct `TLSConfig` and `TransportSecurity` types per transport.
The POSIX and TransportServices variants share case names for convenience, but they're separate types with their own initializers and factory methods.

### Create self-signed certificates for local testing

When you intend to use TLS, it can be convenient to create temporary, self-signed certificates for local testing.
You can create a temporary certificate authority, server certificate, and private key to use locally.

The following example illustrates using `openssl` to:
- Create the private key and certificate for a certificate authority.
- Create a server key and certificate request.
- Sign the certificate request to create a server certificate.

```bash
# Generate CA certificate - ca-key.pem, ca-cert.pem
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout ca-key.pem -out ca-cert.pem -days 28

# Generate server certificate - server-key.pem, server-req.pem
openssl req -newkey rsa:4096 -nodes \
  -keyout server-key.pem -out server-req.pem

# Sign server certificate with CA - server-cert.pem
openssl x509 -req -in server-req.pem -days 28 \
  -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
  -out server-cert.pem
```

With the `Posix` transport, use [.tls(certificateChain:privateKey:configure:)](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix/grpcniotransportcore/http2servertransport/posix/transportsecurity/tls(certificatechain:privatekey:configure:)) for the server's TLS configuration.
Use [TLSConfig.CertificateSource.file(path:format:)](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransportcore/tlsconfig/certificatesource/file(path:format:)) to reference your generated server certificate, and
[TLSConfig.PrivateKeySource.file(path:format:)](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransportcore/tlsconfig/privatekeysource/file(path:format:)) to reference your generated server key.
For example:

```swift
let testingTransportSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .tls(
  certificateChain: [.file(path: "path/to/server-cert.pem", format: .pem)],
  privateKey: .file(path: "path/to/server-key.pem", format: .pem)
)
```

The example above identifies the encoding format of the certificates that you load from the file system.
The gRPC Swift API provides support for both `.der` and `.pem` encoded content using [SerializationFormat](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransportcore/tlsconfig/serializationformat).

The `TransportServices` transport loads identities from the Keychain using Apple's [Security](https://developer.apple.com/documentation/security/) framework, specifically [SecIdentity](https://developer.apple.com/documentation/security/secidentity).

When you create a client to interact with the self-signed certificates in a gRPC server, provide the certificate authority's certificate (`ca-cert.pem`) so the client can validate the server's certificate.
The following example illustrates a client configured to access the same host it runs on (`localhost`) on port `8765`:

```swift
let client = GRPCClient(
  transport: try .http2NIOPosix(
    target: .ipv4(address: "127.0.0.1", port: 8765),
    transportSecurity: .tls { config in
      config.trustRoots = .certificates([
        .file(path: "certs/ca-cert.pem", format: .pem)
      ])
    }
  )
)
```

> Tip: Trust-root certificates for TransportServices must use `.der` encoding, while `Posix` transports support either `.pem` or `.der` encoding.

You can transform a local CA certificate into `.der` encoding using the following command:

```bash
openssl x509 -in ca-cert.pem -outform der -out ca-cert.der
```
