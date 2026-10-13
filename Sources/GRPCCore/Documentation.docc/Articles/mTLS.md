# Mutual TLS

Authenticate the client as well as the server, using a private certificate authority instead of
a public trust store.

## Overview

Mutual TLS (mTLS) extends the idea of TLS to validate the client, in addition to validating the server.
mTLS is commonly used to ensure that the network connection is both from and to an expected client.
It's used as an alternative to, or alongside, token-based authentication systems, often for service-to-service authentication.

Using mTLS requires more logistical overhead.
Every client authenticating with mTLS requires its own certificate and key, issued by a certificate authority (CA) that both the client and server trust.
To maintain a good security posture, keys and certificates need to be rotated on a regular basis and handled securely.

## Configure transport security using mTLS-specific API

The available transports both offer `.mTLS` options to configure transport security.

Like `.tls`, the types for client and server transport security are distinct, but intentionally aligned across both transports. The following table links to each factory method's documentation:

| Transport | Client | Server |
|---|---|---|
| POSIX | [.mTLS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix/grpcniotransportcore/http2clienttransport/posix/transportsecurity/mtls(certificatechain:privatekey:configure:)) | [.mTLS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix/grpcniotransportcore/http2servertransport/posix/transportsecurity/mtls(certificatechain:privatekey:configure:)) |
| TransportServices | [.mTLS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2transportservices/grpcniotransportcore/http2clienttransport/transportservices/transportsecurity/mtls(identityprovider:configure:)) | [.mTLS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2transportservices/grpcniotransportcore/http2servertransport/transportservices/transportsecurity/mtls(identityprovider:configure:)) |

The parameters for these configurations typically expect a list of certificates (`certificateChain`), the private key corresponding to the certificate (`privateKey`), and a closure that you use to configure the TLS settings (`configure`).

> Tip: When you configure the CA certificate chain for mTLS validation with Transport Services, the API expects the certificates to be encoded with `.der` encoding. The `Posix` transport allows either `.pem` or `.der` encoding.

### Use the same certificate authority for both sides

In addition to providing the certificate and private key, ensure that you provide the certificate authority in the TLS configuration to both the client and server configuration.

The following code illustrates configuring the transport security for a `Posix` server transport:

```swift
let mTLSServerSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .mTLS(
  certificateChain: [
    .file(path: "path/to/server-cert.pem", format: .pem)
  ],
  privateKey: .file(path: "path/to/server-key.pem", format: .pem)
) { config in
  config.trustRoots = .certificates([
    .file(path: "path/to/ca-cert.pem", format: .pem)
  ])
}
```

The next example illustrates the matching client configuration, using the same `trustRoots` configuration as the server.

```swift
let mTLSClientSecurity: HTTP2ClientTransport.Posix.TransportSecurity = .mTLS(
  certificateChain: [
    .file(path: "path/to/client-cert.pem", format: .pem)
  ],
  privateKey: .file(path: "path/to/client-key.pem", format: .pem)
) { config in
  config.trustRoots = .certificates([
    .file(path: "path/to/ca-cert.pem", format: .pem)
  ])
}
```

The default verification for TLS within the `.mTLS` configuration uses [noHostnameVerification](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransportcore/tlsconfig/certificateverification/nohostnameverification),
because common use of mTLS identifies services, not DNS entries.

## Reload certificates for certificate rotation

In mTLS, both client and server must prove their identity cryptographically.
Certificate rotation strengthens security because it limits the lifespan of a credential.
Shorter periods reduce the time an attacker can use a compromised key.

If a client certificate leaks, an attacker can impersonate a legitimate user.
If a server certificate leaks, an attacker can intercept and decrypt private traffic.
Rotating both credentials ensures that a stolen identity does not grant permanent access.
Use code to regularly update both client and server certificates and keys to maintain security.

The `Posix` transport offers an mTLS configuration that uses a type that conforms to [CertificateReloader](https://swiftpackageindex.com/apple/swift-nio-extras/documentation/niocertificatereloading/certificatereloader), from [swift-nio-extras](https://github.com/apple/swift-nio-extras).
The `swift-nio-extras` package provides a [TimedCertificateReloader](https://swiftpackageindex.com/apple/swift-nio-extras/documentation/niocertificatereloading/timedcertificatereloader) that reloads certificates on a configurable, regular basis.

> Note: If you create a TimedCertificateReloader, ensure you start with an existing valid certificate.

The `Posix` transport offers an mTLS factory method overload that takes a `CertificateReloader`. The following table links to each factory method's documentation.

| Client | Server |
|---|---|
| [.mTLS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix/grpcniotransportcore/http2clienttransport/posix/transportsecurity/mtls(certificatereloader:configure:)) | [.mTLS](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix/grpcniotransportcore/http2servertransport/posix/transportsecurity/mtls(certificatereloader:configure:)) |

## Provide custom mTLS verification

If your mTLS infrastructure uses a workload identity, identifying the service or workflow with a mechanism like [SPIFFE](https://spiffe.io),
then you may need to do additional, custom validation of the client certificates when the request is being accepted on the server.
For example, you may need to read the identity from the provided certificate and validate it.
You can configure custom client and server verification callbacks that gRPC invokes when validating the TLS connection.

To use the custom verification callback that the gRPC Swift transport provides,
set `customVerificationCallback` when you configure the transport.
The following example illustrates providing a custom callback:

```swift
let serverSecurity: HTTP2ServerTransport.Posix.TransportSecurity = .mTLS(
  certificateChain: [.bytes(pki.server.certificateDER, format: .der)],
  privateKey: .bytes(pki.server.privateKeyDER, format: .der)
) { config in
  config.trustRoots = .certificates([
    .bytes(pki.caCertificateDER, format: .der)
  ])
  config.customVerificationCallback = { certificates, promise in
    // Convert from an NIOSSLCertificate into a Certificate type  
    // (https://swiftpackageindex.com/apple/swift-certificates/documentation/x509/certificate)
    // from swift-certificates to more easily access the distinguished
    // name (unique identity) of the subject of the certificate.
    let presented = try! Certificate(derEncoded: certificates[0].toDERBytes())

    // In a SPIFFE-style workload validation, the client will have 
    // its unique identity encoded in the certificate's Subject
    // Alternative Name (SAN), accessible from the `subject`, which
    // is an instance of `DistinguishedName`.
    // (https://swiftpackageindex.com/apple/swift-certificates/documentation/x509/distinguishedname)
    print(presented.subject.description)

    // Add your validation logic, checking the certificates provided.
    promise.succeed(
      .certificateVerified(
        VerificationMetadata(
          ValidatedCertificateChain(certificates)
        )
      )
    )
  }
}
```

> Note: The above example shows how to access the certificate data in a callback, but does not do any validation. 

The callback receives a list of [NIOSSLCertificate](https://swiftpackageindex.com/apple/swift-nio-ssl/documentation/niossl/niosslcertificate)
that you can then process to extract the workload identity and validate it.
Ensure that you call `promise.succeed()` or `promise.fail()` to complete the callback after the verification.

> Warning: When you configure TLS for the transport, leaving `serverCertificateVerification` set to `.noVerification` means the transport doesn't call the validation callback you provide.
> Leave the default setting of `.noHostnameVerification`, or use `.fullVerification`, to ensure that the transport invokes the validation callback.

## Create a private CA for mTLS testing

The [tls-hello-world example code](https://github.com/grpc/grpc-swift-2/tree/main/Examples/tls-hello-world) in the `grpc-swift-2` repository
includes an example of setting up a short-lived CA and the relevant client and server credentials to test business logic working with mTLS.

It builds that information in memory, and allows your test code to validate that the client and server certificates
are signed by the same certificate authority.
