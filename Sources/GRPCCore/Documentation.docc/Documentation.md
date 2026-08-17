# ``GRPCCore``

A gRPC library for Swift written natively in Swift.

## Overview

### Package structure

gRPC Swift spans multiple Swift packages, each exposing one or more modules.
This module provides the higher-level documentation to provide gRPC clients and services using these collected packages.
The following is a map of the libraries and their documentation:

- term **[grpc-swift-2](https://github.com/grpc/grpc-swift-2)**: The core gRPC runtime that provides ``GRPCClient``, ``GRPCServer``, and the protocols for the transport (``ClientTransport`` and ``ServerTransport``). When creating a client or server instance, choose a transport over which the communication flows, such as `GRPCNIOTransportHTTP2Posix` or `GRPCNIOTransportHTTP2TransportServices` from the package `grpc-swift-nio-transport`. The module [`GRPCInProcessTransport`](https://swiftpackageindex.com/grpc/grpc-swift-2/documentation/GRPCInProcessTransport) provides an in-process transport implementation with no real networking for testing service logic or to wire a client and server together in one process without sockets or TLS.
- term **[grpc-swift-nio-transport](https://github.com/grpc/grpc-swift-nio-transport)**: A package that provides two transport libraries for gRPC clients and servers, and an umbrella module ([`GRPCNIOTransportHTTP2`](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2)) that re-exports both backends. Use the umbrella module to get `.http2NIOPosix` and `.http2NIOTS` from one package dependency and pick per-platform in code, rather than deciding at the manifest level.

  - term [`GRPCNIOTransportHTTP2Posix`](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix): A gRPC transport built on SwiftNIO's `NIOPosix`, that uses [NIOSSL](https://swiftpackageindex.com/apple/swift-nio-ssl/documentation/niossl) and [swift-certificates](https://swiftpackageindex.com/apple/swift-certificates/documentation/x509) to provide TLS support. Use when your service code runs on Linux, or on a platform that doesn't require the use of Apple's `Network` framework.
  - term [`GRPCNIOTransportHTTP2TransportServices`](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2transportservices): A gRPC transport built on Apple's [Network](https://developer.apple.com/documentation/network) framework, a recommended transport for Apple platforms.

- term **[grpc-swift-protobuf](https://github.com/grpc/grpc-swift-protobuf)**: Bridges the gRPC core to [SwiftProtobuf](https://swiftpackageindex.com/apple/swift-protobuf/documentation/swiftprotobuf) using [`GRPCProtobuf`](https://swiftpackageindex.com/grpc/grpc-swift-protobuf/documentation/grpcprotobuf) for runtime serialization libraries.
  The package also provides the `protoc-gen-grpc-swift-2` plugin for the Protocol Buffers compiler, `protoc`, and two SwiftPM plugins (`GRPCProtobufGenerator`, `generate-grpc-code-from-protos`) that generate code stubs from your Swift package build process. Read [Generating Stubs](https://swiftpackageindex.com/grpc/grpc-swift-protobuf/documentation/grpcprotobuf/generating-stubs) for details on creating client and service stubs.

- term **[grpc-swift-extras](https://github.com/grpc/grpc-swift-extras)**: Opt-in add-ons for convenience when creating and providing gRPC services. Add the depdendencies fpr each feature you want, not as a bundle:
  - [`GRPCHealthService`](https://swiftpackageindex.com/grpc/grpc-swift-extras/documentation/grpchealthservice) — an implementation of the gRPC health-checking protocol that you register on your server. Use it to provide readiness and liveness checks that so load balancers or orchestrators (such as Kubernetes, Envoy, and so on) can probe directly over gRPC instead of side-channel alternatives.
  - [`GRPCReflectionService`](https://swiftpackageindex.com/grpc/grpc-swift-extras/documentation/grpcreflectionservice) — an implementation of gRPC server reflection. Add it for generic tools (such as `grpcurl` or Postman) to discover your services and methods at runtime without you shipping `.proto` files to every caller.
  - [`GRPCOTelTracingInterceptors`](https://swiftpackageindex.com/grpc/grpc-swift-extras/documentation/grpcoteltracinginterceptors) — client *and* server interceptors that emit OpenTelemetry spans per RPC. Add it to instrument distributed tracing across gRPC calls with OTel-convention span attributes, without hand-writing the interceptor plumbing.
  - [`GRPCServiceLifecycle`](https://swiftpackageindex.com/grpc/grpc-swift-extras/documentation/grpcservicelifecycle) — adapts both ``GRPCClient`` and ``GRPCServer`` to the `Service` protocol of [swift-service-lifecycle](https://swiftpackageindex.com/swift-server/swift-service-lifecycle/documentation/servicelifecycle). Add it if your process already runs a `ServiceGroup` and you want gRPC startup/shutdown to participate in the same graceful-shutdown sequence.
  - [`GRPCInteropTests`](https://swiftpackageindex.com/grpc/grpc-swift-extras/documentation/grpcinteroptests) — a shared cross-implementation gRPC interop test suite. Primarily for contributors, skip this unless you're validating a new transport or language implementation against the gRPC interop spec.

When you create a gRPC client or server that build from .proto files in your project,
include 3 of the packages above as dependencies:

```swift
  dependencies: [
    // ...
    .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.0.0"),
    .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "2.4.0"),
    .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "2.0.0"),
  ],
```

Set the dependencies for your internal based on your choice of transport, or use the umbrella library from the `grpc-swift-nio-transport` to choose in code.

In your code, you often import multiple gRPC modules. For example, when creating a gRPC client, you may include the following imports:

```swift
import GRPCCore 
import GRPCNIOTransportHTTP2 // transport and its configuration
import GRPCProtobuf // for message (de)serialization and error details
```

## Topics

### Essentials

- <doc:Hello-World>
- <doc:Route-Guide>
- <doc:Generating-stubs>
- <doc:client>
- <doc:server>


### Streaming primitives

- ``RPCStream``
- ``RPCRequestPart``
- ``RPCResponsePart``
- ``RPCWriterProtocol``
- ``ClosableRPCWriterProtocol``
- ``RPCWriter``
- ``RPCAsyncSequence``

### Serialization

- ``MessageSerializer``
- ``MessageDeserializer``
- ``CompressionAlgorithm``
- ``CompressionAlgorithmSet``
- ``GRPCContiguousBytes``

### Errors

- <doc:Error-handling>
- ``RPCError``
- ``RPCErrorConvertible``
- ``RuntimeError``

### Project information

- <doc:Compatibility>
- <doc:Migration-guide>

### Development resources

Resources for developers working on gRPC Swift:

- <doc:Design>
- <doc:Benchmarks>
- <doc:Public-API>
