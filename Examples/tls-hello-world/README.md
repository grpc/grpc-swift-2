# TLS Hello World

This example demonstrates TLS and mutual TLS (mTLS) on a gRPC service. It uses the same core
logic as the [Hello World example](../hello-world), secured with either a TLS or mTLS connection, with certificates 
backed by an in-memory demo certificate authority generated with the package `swift-certificates`.

## Overview

The `generate` subcommand calls `InMemoryPKI.CertificateAuthority` to generate a throwaway certificate
authority (using the package `swift-certificates`) and can create and sign new leaf (server or client)
certificates on demand. `serve` and `greet` read and use the PEM files it writes.

When `Greeter`, the `Helloworld_Greeter` implementation, talks to a client over mTLS, it reads the
client certificate's Subject Alternative Name from `ServerContext.transportSpecific` and reports it
both in the RPC reply and its console output.

## Usage

Generate the CA, server certificate, and a client certificate for the identity `alice`:

```console
$ swift run tls-hello-world generate --client-id alice
Generated demo CA in /var/folders/.../tls-hello-world-demo-pki
Generated server certificate for 'localhost'
Generated client certificate for 'alice' (identity: spiffe://tls-hello-world.example/client/alice)
```

Start the server in one terminal, pointing at the same directory (the default, so no flag is
needed if you didn't pass `--pki-directory` above):

```console
$ swift run tls-hello-world serve --mode tls
Greeter listening on [ipv4]127.0.0.1:31415 (tls)
```

In another terminal, connect to it. 

### TLS

With plain `--mode tls`, the client secures the connection and only verifies the
server --- there's no client identity to report:

```console
$ swift run tls-hello-world greet --mode tls --name stranger
Hello, stranger! This connection was verified.
```

### mTLS

In the first terminal, restart `serve` and use `--mode mtls` to also require a client certificate.
`greet --client-id` selects which pre-generated client certificate to present; the server reads
the SPIFFE-style identity back off the peer certificate chain and includes it in its reply:

```console
$ swift run tls-hello-world serve --mode mtls
Greeter listening on [ipv4]127.0.0.1:31415 (mtls)

$ swift run tls-hello-world greet --mode mtls --client-id alice --name stranger
Hello, stranger! Verified client identity: spiffe://tls-hello-world.example/client/alice.
```

Generate a second identity into the same directory --- it reuses the CA already there, so the
server (already running, and unchanged) trusts it too --- and greet as `bob`:

```console
$ swift run tls-hello-world generate --client-id bob
Reusing existing demo CA in /var/folders/.../tls-hello-world-demo-pki
Generated server certificate for 'localhost'
Generated client certificate for 'bob' (identity: spiffe://tls-hello-world.example/client/bob)

$ swift run tls-hello-world greet --mode mtls --client-id bob --name stranger
Hello, stranger! Verified client identity: spiffe://tls-hello-world.example/client/bob.
```

`serve` and `greet` agree on the PKI directory by default, so no flags are required;
pass `--pki-directory` to all three subcommands if you want to point them
somewhere else.

> Warning: `generate` writes the demo CA's private key to disk so it can mint more client
> certificates signed by it in later invocations (like `bob`, above). This is not appropriate
> secure behavior, and is set up only to support illustrating the code for how this works. A real
> CA's private key should never leave the CA.

### Forcing mTLS failure: use an untrusted client CA

To see what an mTLS trust failure looks like, generate a client certificate signed by a separate,
untrusted CA with `generate --untrusted-ca`, then present it with `greet --untrusted-ca`.
Everything else about the connection is unchanged:

```console
$ swift run tls-hello-world generate --untrusted-ca
Reusing existing demo CA in /var/folders/.../tls-hello-world-demo-pki
Generated server certificate for 'localhost'
Generated client certificate for 'demo-client' (identity: spiffe://tls-hello-world.example/client/demo-client)
Generated client certificate signed by an untrusted CA (for greet --untrusted-ca)

$ swift run tls-hello-world greet --mode mtls --untrusted-ca --name stranger
Presenting a client certificate signed by an untrusted CA (expect this to fail)...
Request failed: unavailable: "The server accepted the TCP connection but closed the connection
before completing the HTTP/2 connection preface." (cause: "sslError([Error: ... SSL routines:
OPENSSL_internal:TLSV1_ALERT_UNKNOWN_CA ...])")
```

The TCP connection and TLS handshake both start, and the server rejects the client's certificate
mid-handshake because its issuer isn't in the server's `trustRoots.` 
The underlying `TLSV1_ALERT_UNKNOWN_CA` is the standard TLS alert for that failure: mTLS validates 
the whole certificate chain, not just whether a certificate was presented.

## Example Tests

### `Tests/TLSHandshakeTests`

Real TLS over a real socket, using in-memory certificates from `InMemoryPKI`:

1. **TLS**: the server presents a certificate signed by the demo CA; the client trusts that CA
   and fully verifies the server, including its hostname.
2. **mTLS**: the server also requires and verifies a client certificate; the client presents
   one. Both certificates are signed by the same CA, so a single `trustRoots` value on each side
   verifies the other.
3. **mTLS with an on-demand client identity**: the same on-demand certificate `generate
   --client-id` uses: a fresh client certificate with a SPIFFE-style SAN,
   and an assertion that the server reads that exact identity back off the peer certificate chain.
4. **mTLS rejects a client certificate signed by an untrusted CA**: the same failure 
   `generate --untrusted-ca` followed by `greet --untrusted-ca` demonstrates: the handshake itself
   fails, so the request never reaches `Greeter`.

### `Tests/InProcessGreeterTests`

The Hello World `Greeter` service, wired up with `InProcessTransport` so that you can validate 
business logic of the client or server without requiring a network interface. The client and server
talk to each other in memory within the test process.

```console
$ swift test
```
