# ``GRPCCore``

A gRPC library for Swift written natively in Swift.

## Overview

### Package structure

gRPC Swift spans multiple Swift packages, each exposing one or more modules.
This module provides the higher-level documentation to provide gRPC clients and services using these collected packages.
The following is a map of the libraries and their documentation:

- **[grpc-swift-2](https://github.com/grpc/grpc-swift-2)** — the core gRPC runtime.
  - `GRPCCore` provides the transport-agnostic gRPC engine with ``GRPCClient``, ``GRPCServer``, call execution, streaming primitives, and the ``ClientTransport``/``ServerTransport`` protocols. It layers with your choice of a transport, with common options available in `grpc-swift-nio-transport` below.
  - [`GRPCInProcessTransport`](https://swiftpackageindex.com/grpc/grpc-swift-2/documentation/GRPCInProcessTransport) — an in-process ``ClientTransport``/``ServerTransport`` implementation with no real networking.
    Use this module for testing service logic or to wire a client and server together in one process without sockets or TLS.
  - [`GRPCCodeGen`](https://swiftpackageindex.com/grpc/grpc-swift-2/documentation/grpccodegen) — a transport and IDL agnostic library for turning a structured service description into Swift source. You only depend on this directly when you create your a code generator for a non-protobuf IDL; most leverage this common module through `grpc-swift-protobuf`.

- **[grpc-swift-nio-transport](https://github.com/grpc/grpc-swift-nio-transport)** — provides two transport libraries for gRPC:
  - [`GRPCNIOTransportHTTP2Posix`](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2posix) — a transport built on SwiftNIO's `NIOPosix`, that uses [NIOSSL](https://swiftpackageindex.com/apple/swift-nio-ssl/documentation/niossl) and [swift-certificates](https://swiftpackageindex.com/apple/swift-certificates/documentation/x509) to provide TLS support. Use when your service code runs on Linux, or on a platform that doesn't require the use of Apple's `Network` framework.
  - [`GRPCNIOTransportHTTP2TransportServices`](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2transportservices) — the backend built on `NIOTransportServices` (Apple's [Network](https://developer.apple.com/documentation/network) framework), a recommended transport for Apple platforms.
  - [`GRPCNIOTransportHTTP2`](https://swiftpackageindex.com/grpc/grpc-swift-nio-transport/documentation/grpcniotransporthttp2) — umbrella module that re-exports both backends. Depend on this module to get `.http2NIOPosix` and `.http2NIOTS` from one package dependency and pick per-platform in code, rather than deciding at the manifest level.

- **[grpc-swift-protobuf](https://github.com/grpc/grpc-swift-protobuf)** — bridges ``GRPCCore`` to Protocol Buffers using [SwiftProtobuf](https://swiftpackageindex.com/apple/swift-protobuf/documentation/swiftprotobuf).
  - [`GRPCProtobuf`](https://swiftpackageindex.com/grpc/grpc-swift-protobuf/documentation/grpcprotobuf) - provides the runtime serialization libraries to work with `GRPCCore`.
  - Also ships the `protoc-gen-grpc-swift-2` plugin for the Protocol Buffers compiler, `protoc`, and two SwiftPM plugins (`GRPCProtobufGenerator`, `generate-grpc-code-from-protos`) that generate code stubs from your Swift package build process. Read [Generating Stubs](https://swiftpackageindex.com/grpc/grpc-swift-protobuf/documentation/grpcprotobuf/generating-stubs) for documentation on creating client and service stubs.

- **[grpc-swift-extras](https://github.com/grpc/grpc-swift-extras)** — independent, opt-in add-ons for convenience when creating and providing gRPC services. Add the depdendencies fpr each feature you want, not as a bundle.
  - [`GRPCHealthService`](https://swiftpackageindex.com/grpc/grpc-swift-extras/documentation/grpchealthservice) — an implementation of the gRPC health-checking protocol that you register on your server. Use it to provide readiness and liveness checks that so load balancers or orchestrators (such as Kubernetes, Envoy, and so on) can probe directly over gRPC instead of side-channel alternatives.
  - [`GRPCReflectionService`](https://swiftpackageindex.com/grpc/grpc-swift-extras/documentation/grpcreflectionservice) — an implementation of gRPC server reflection. Add it for generic tools (such as `grpcurl` or Postman) to discover your services and methods at runtime without you shipping `.proto` files to every caller.
  - [`GRPCOTelTracingInterceptors`](https://swiftpackageindex.com/grpc/grpc-swift-extras/documentation/grpcoteltracinginterceptors) — client *and* server interceptors that emit OpenTelemetry spans per RPC. Add it to instrument distributed tracing across gRPC calls with OTel-convention span attributes, without hand-writing the interceptor plumbing.
  - [`GRPCServiceLifecycle`](https://swiftpackageindex.com/grpc/grpc-swift-extras/documentation/grpcservicelifecycle) — adapts both ``GRPCClient`` and ``GRPCServer`` to the `Service` protocol of [swift-service-lifecycle](https://swiftpackageindex.com/swift-server/swift-service-lifecycle/documentation/servicelifecycle). Add it if your process already runs a `ServiceGroup` and you want gRPC startup/shutdown to participate in the same graceful-shutdown sequence.
  - [`GRPCInteropTests`](https://swiftpackageindex.com/grpc/grpc-swift-extras/documentation/grpcinteroptests) — a shared cross-implementation gRPC interop test suite. Primarily for contributors, skip this unless you're validating a new transport or language implementation against the gRPC interop spec.

## Topics

### Tutorials

- <doc:Hello-World>
- <doc:Route-Guide>

### Essentials

- <doc:Generating-stubs>
- <doc:Error-handling>

### Project information

- <doc:Compatibility>
- <doc:Public-API>
- <doc:Migration-guide>

### Development resources

Resources for developers working on gRPC Swift:

- <doc:Design>
- <doc:Benchmarks>

### Client and server

- ``GRPCClient``
- ``GRPCServer``
- ``withGRPCClient(transport:interceptors:isolation:handleClient:)``
- ``withGRPCClient(transport:interceptorPipeline:isolation:handleClient:)``
- ``withGRPCServer(transport:services:interceptors:isolation:handleServer:)``
- ``withGRPCServer(transport:services:interceptorPipeline:isolation:handleServer:)``
- ``GRPCServerContext``

### Request and response types

- ``ClientRequest``
- ``StreamingClientRequest``
- ``ClientResponse``
- ``StreamingClientResponse``
- ``ServerRequest``
- ``StreamingServerRequest``
- ``ServerResponse``
- ``StreamingServerResponse``
- ``Status``
- ``Metadata``

### Service definition and routing

- ``RegistrableRPCService``
- ``RPCRouter``

### Interceptors

- ``ClientInterceptor``
- ``ServerInterceptor``
- ``ClientContext``
- ``ServerContext``
- ``ConditionalInterceptor``

### RPC descriptors

- ``MethodDescriptor``
- ``ServiceDescriptor``

### Service config

- ``ServiceConfig``
- ``MethodConfig``
- ``HedgingPolicy``
- ``RetryPolicy``
- ``RPCExecutionPolicy``

### Serialization

- ``MessageSerializer``
- ``MessageDeserializer``
- ``CompressionAlgorithm``
- ``CompressionAlgorithmSet``
- ``GRPCContiguousBytes``

### Transport protocols

- ``ClientTransport``
- ``ServerTransport``
- ``RPCStream``
- ``CallOptions``
- ``RetryThrottle``
- ``RPCRequestPart``
- ``RPCResponsePart``

### Streaming primitives

- ``RPCWriterProtocol``
- ``ClosableRPCWriterProtocol``
- ``RPCWriter``
- ``RPCAsyncSequence``

### Cancellation

- ``withServerContextRPCCancellationHandle(_:)``
- ``withRPCCancellationHandler(operation:onCancelRPC:)``

### Errors

- ``RPCError``
- ``RPCErrorConvertible``
- ``RuntimeError``
