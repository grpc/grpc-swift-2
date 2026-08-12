# Design

This article provides a high-level overview of the design of gRPC Swift.

The library has three broad layers:
1. Transport,
2. Call, and
3. Stub.

The _transport_ layer provides (typically) long-lived bidirectional
communication between two peers and provides streams of request and response
parts. On top of the transport is the _call_ layer, which is responsible for
mapping a call onto a stream and dealing with serialization. The highest level
of abstraction is the _stub_ layer, which provides client and server interfaces
generated from an interface definition language (IDL).

## Overview

### Transport

The transport layer provides a typically long-lived, bidirectional communication
channel with a remote peer.

Transports have two main interfaces:
1. Streams, used by the call layer.
2. The transport-specific communication with its corresponding remote peer.

The most common transport in gRPC is HTTP/2. However others such as gRPC-Web,
HTTP/3 and in-process also exist. (gRPC Swift has transports for HTTP/2 built on
top of Swift NIO and also provides an in-process transport.)

You shouldn't think of a transport as a single connection, they're more
abstract. For example, a transport may maintain a set of connections to a
collection of remote endpoints that change over time. By extension, client
transports are also responsible for balancing load across multiple connections
where applicable.

Each peer (client and server) has their own transport protocol; in gRPC Swift, these are:
1. ``ServerTransport``, and
2. ``ClientTransport``.

The vast majority of users won't need to implement either of these protocols.
However, many users will need to create instances of types conforming to these
protocols to create a server or client, respectively.

#### Server transport

The ``ServerTransport`` is responsible for the server half of a transport. It
listens for new gRPC streams and then processes them. The
``ServerTransport/listen(streamHandler:)`` requirement achieves this.

The gRPC server passes a handler, which it provides, into the `listen` method.
It's responsible for routing and handling the stream. The server transport executes the
stream in its own context — that is, the `listen` method
is an ancestor task of all RPCs the server handles.

Note that the server transport doesn't include the idea of a “connection”. While
an HTTP/2 server transport will in all likelihood have multiple connections open
at any given time, this abstraction doesn't surface that detail.

#### Client transport

While the server is responsible for handling streams, the ``ClientTransport`` is
responsible for creating them. Client transports will typically maintain a
number of connections that may change over a period of time. The client transport maintains these
connections and does other background work in the ``ClientTransport/connect()``
method. Cancelling the task running this method will result in the transport
abruptly closing. You can shut down the transport gracefully by calling
``ClientTransport/beginGracefulShutdown()``.

You create streams using ``ClientTransport/withStream(descriptor:options:_:)``,
and the closure limits the stream's lifetime. A gRPC client will provide the handler passed to
the method, which will ultimately include the
caller's code to send request messages and process response messages. Cancelling
the task abruptly closes the stream, although the transport should ensure that
doing this doesn't leave the other side waiting indefinitely.

gRPC has mechanisms to deliver method-specific configuration at the transport
layer which can also change dynamically (see [gRFC A2: ServiceConfig in
DNS](https://github.com/grpc/proposal/blob/0e1807a6e30a1a915c0dcadc873bca92b9fa9720/A2-service-configs-in-dns.md)).
gRPC uses this configuration to determine how clients should interact with servers
and how the call layer should execute methods, such as the conditions under which it
may retry them. The ``ClientTransport`` protocol exposes some of this as
``ClientTransport/retryThrottle`` and
``ClientTransport/config(forMethod:)``.

#### Streams

Both client and server transport protocols use ``RPCStream`` to represent
streams of information. You can think of each RPC as having two logical
streams: a request stream where information flows from client to server,
and a response stream where information flows from server to client.
Each ``RPCStream`` has inbound and outbound types corresponding to one end of
each stream.

Inbound types are `AsyncSequence`s (specifically ``RPCAsyncSequence``) of stream
parts, and the outbound types are writer objects (``RPCWriter``) of stream parts.

GRPCCore defines the stream parts as:
- ``RPCRequestPart``, and
- ``RPCResponsePart``.

A client stream has its outbound type as ``RPCRequestPart`` and its inbound type
as ``RPCResponsePart``. The server stream has its inbound type as ``RPCRequestPart``
and its outbound type as ``RPCResponsePart``.

The ``RPCRequestPart`` is made up of ``Metadata`` and messages (as `[UInt8]`). The
``RPCResponsePart`` extends this to include a final ``Status`` and ``Metadata``.

``Metadata`` contains information about an RPC in the form of a list of
key-value pairs. Keys are strings and values may be strings or binary data (but are
typically strings). Keys for binary values have a “-bin” suffix. The transport
layer may use metadata to propagate transport-specific information about the call to
its peer. The call layer may attach gRPC-specific metadata such as call timeout
information. Users may also make use of metadata to propagate app-specific information
to the remote peer.

Each message part contains the binary data; typically this would be the serialized
representation of a Protocol Buffers message.

The combined ``Status`` and ``Metadata`` part only appears in the ``RPCResponsePart``
and indicates the final outcome of an RPC. It includes a ``Status/Code-swift.struct``
and a string describing the final outcome, while the ``Metadata`` may contain additional
information about the RPC.

### Call

The “call” layer builds on top of the transport layer to map higher-level RPC calls onto
streams. It also implements transport-agnostic functionality, like serialization
and deserialization, retries, hedging, and deadlines.

Serialization is pluggable: you have control over the type of messages used although
most users will use Protocol Buffers. The serialization interface is small; there are
two protocols:
1. ``MessageSerializer`` for serializing messages to bytes, and
2. ``MessageDeserializer`` for deserializing messages from bytes.

The [grpc/grpc-swift-protobuf](https://github.com/grpc/grpc-swift-protobuf) package
provides support for [SwiftProtobuf](https://github.com/apple/swift-protobuf) by
implementing serializers and a code generator for the Protocol Buffers
compiler, `protoc`.

#### Interceptors

This layer also provides client and server interceptors allowing you to modify requests
and responses between the caller and the network. The call layer implements these as
``ClientInterceptor`` and ``ServerInterceptor``, respectively.

As all RPC types are special cases of bidirectional streaming RPCs, the interceptor
APIs follow the shape of the respective client and server bidirectional streaming APIs.
Naturally, the interceptor APIs are `async`.

You register interceptors directly with the ``GRPCClient`` and ``GRPCServer``, and
you can apply them to all RPCs or to specific services.

#### Client

The call layer includes a concrete ``GRPCClient``, which provides API to execute all
four types of RPC against a ``ClientTransport``. These methods are:

- ``GRPCClient/unary(request:descriptor:serializer:deserializer:options:onResponse:)``,
- ``GRPCClient/clientStreaming(request:descriptor:serializer:deserializer:options:onResponse:)``,
- ``GRPCClient/serverStreaming(request:descriptor:serializer:deserializer:options:onResponse:)``, and
- ``GRPCClient/bidirectionalStreaming(request:descriptor:serializer:deserializer:options:onResponse:)``.

As lower-level methods, they require you to pass in a serializer and
deserializer, as well as the descriptor of the method you're calling. Each method
has a response-handling closure to process the response from the server, and the
method won't return until the handler has returned. This enforces structured
concurrency.

Most users won't use ``GRPCClient`` to execute RPCs directly; instead, they will
use the generated client stubs that wrap the ``GRPCClient``. Users are
responsible for creating the client and running it (which starts and runs the
underlying transport). You do this by calling ``GRPCClient/runConnections()``. You
can shut down the client gracefully by calling ``GRPCClient/beginGracefulShutdown()``,
which stops new RPCs from starting (by failing them with
``RPCError/Code-swift.struct/unavailable``) but lets existing ones continue.
You can stop existing work more abruptly by cancelling the task where
``GRPCClient/runConnections()`` is executing.

#### Server

The call layer provides ``GRPCServer`` to host services for a given
transport. Beyond creating the server, it has a very limited API surface: it has
a ``GRPCServer/serve()`` method, which runs the underlying transport and is the
task under which all accepted streams run. Much like the client, you
can initiate graceful shutdown by calling ``GRPCServer/beginGracefulShutdown()``,
which will stop the server from handling new RPCs but will let existing RPCs run to
completion. Cancelling the task will close the server more abruptly.

### Stub

The stub layer is the layer that most users interact with. It provides service-specific interfaces generated from an interface definition language (IDL) such
as Protobuf. For clients, this includes a concrete type per service for invoking
the methods provided by that service. For services, this includes a protocol
that the service owner implements with the business logic for their service.

The purpose of the stub layer is to reduce boilerplate: users generate stubs
from a single source of truth into native Swift types to remove errors that would
otherwise arise from writing them manually.

However, the stub layer is optional; users may choose not to use it and
construct clients and services manually. A gRPC proxy, for example, would not
use the stub layer.

#### Server stubs

Users implement services by conforming a type to a generated service `protocol`.
Each service has three protocols generated for it:
1. A “simple” service protocol,
2. A “regular” service protocol, and
3. A “streaming” service protocol.

The streaming service protocol is the root `protocol`. Most users won't need to
implement this protocol directly. It treats each of the four RPC types as a
bidirectional streaming RPC: this allows users to have the most flexibility over
how they implement their RPCs at the cost of a harder-to-use API. The following
code shows how the streaming service protocol would look for a service:

```swift
protocol ServiceName.StreamingServiceProtocol {
  func unaryRPC(
    request: StreamingServerRequest<InputName>,
    context: ServerContext
  ) async throws -> StreamingServerResponse<OutputName>

  // client-, server-, and bidirectional-streaming are exactly the same as
  // unary.
}
```

An example of where this is useful is when a user wants to implement a unary
method that first sends the initial metadata and then does some other processing
before sending a message.

Many users won't need this much fidelity and will use the “regular” service
protocol that provides APIs that are more appropriate for the type of RPC. The
following code shows how the regular service protocol would look:

```swift
protocol ServiceName.ServiceProtocol: ServiceName.StreamingServiceProtocol {
  func unaryRPC(
    request: ServerRequest<InputName>,
    context: ServerContext
  ) async throws -> ServerResponse<OutputName>

  func clientStreamingRPC(
    request: StreamingServerRequest<InputName>,
    context: ServerContext
  ) async throws -> ServerResponse<OutputName>

  func serverStreamingRPC(
    request: ServerRequest<InputName>,
    context: ServerContext
  ) async throws -> StreamingServerResponse<OutputName>

  func bidirectionalStreamingRPC(
    request: StreamingServerRequest<InputName>,
    context: ServerContext
  ) async throws -> StreamingServerResponse<OutputName>
}
```

gRPC Swift generates and implements the conformance to `StreamingServiceProtocol` in
terms of the requirements of `ServiceProtocol`. This allows users to use the
higher-level API where possible but can implement the fully-streamed version
per-RPC if necessary.

Some users also won't need access to metadata and will only be interested in the
messages sent and received on an RPC. gRPC Swift provides a higher-level “simple” service protocol
for this use case:

```swift
protocol ServiceName.SimpleServiceProtocol: ServiceName.ServiceProtocol {
  func unaryRPC(
    request: InputName,
    context: ServerContext
  ) async throws -> OutputName

  func clientStreamingRPC(
    request: RPCAsyncSequence<InputName, any Error>,
    context: ServerContext
  ) async throws -> OutputName

  func serverStreamingRPC(
    request: InputName,
    response: RPCWriter<OutputName>,
    context: ServerContext
  ) async throws

  func bidirectionalStreamingRPC(
    request: RPCAsyncSequence<InputName, any Error>,
    response: RPCWriter<OutputName>,
    context: ServerContext
  ) async throws
}
```

Much like the “regular” protocol, the “simple” version refines another service
protocol. In this case it refines the “regular” `ServiceProtocol` for which it
also has a default implementation.

The root of the protocol hierarchy, the `StreamingServiceProtocol`, also
refines the ``RegistrableRPCService`` protocol. This `protocol` has a single
requirement for registering methods with an ``RPCRouter``. gRPC Swift also
provides a default implementation of this method.

#### Client stubs

gRPC Swift splits generated client code into a `protocol` and a concrete `struct`
implementing the `protocol`. An example of the client protocol is:

```swift
protocol ServiceName.ClientProtocol {
  func unaryRPC<R>(
    request: ClientRequest<InputName>,
    serializer: some MessageSerializer<InputName>,
    deserializer: some MessageDeserializer<OutputName>,
    options: CallOptions,
    _ body: @Sendable @escaping (ClientResponse<OutputName>) async throws -> R
  ) async throws -> R where R: Sendable

  func clientStreamingRPC<R>(
    request: StreamingClientRequest<InputName>,
    serializer: some MessageSerializer<InputName>,
    deserializer: some MessageDeserializer<OutputName>,
    options: CallOptions,
    _ body: @Sendable @escaping (ClientResponse<OutputName>) async throws -> R
  ) async throws -> R where R: Sendable

  func serverStreamingRPC<R>(
    request: ClientRequest<InputName>,
    serializer: some MessageSerializer<InputName>,
    deserializer: some MessageDeserializer<OutputName>,
    options: CallOptions,
    _ body: @Sendable @escaping (StreamingClientResponse<OutputName>) async throws -> R
  ) async throws -> R where R: Sendable

  func bidirectionalStreamingRPC<R>(
    request: StreamingClientRequest<InputName>,
    serializer: some MessageSerializer<InputName>,
    deserializer: some MessageDeserializer<OutputName>,
    options: CallOptions,
    _ body: @Sendable @escaping (StreamingClientResponse<OutputName>) async throws -> R
  ) async throws -> R where R: Sendable
}
```

Each method takes a request appropriate for its RPC type, a serializer, a
deserializer, a set of options, and a handler for processing the response. The
function doesn't return until the response handler has returned and gRPC Swift has cleaned up all
resources associated with the RPC.

gRPC Swift also generates an extension to the protocol, which provides an appropriate
serializer and deserializer, defaults the options to `.defaults`, and, for RPCs
with a single response message, defaults the closure to returning the response
message:

```swift
extension ServiceName.ClientProtocol {
  func unaryRPC<R>(
    request: ClientRequest<InputName>,
    options: CallOptions = .defaults,
    _ body: @Sendable @escaping (ClientResponse<OutputName>) async throws -> R = { try $0.message }
  ) async throws -> R where R: Sendable {
    // ...
  }

  func clientStreamingRPC<R>(
    request: StreamingClientRequest<InputName>,
    options: CallOptions = .defaults,
    _ body: @Sendable @escaping (ClientResponse<OutputName>) async throws -> R = { try $0.message }
  ) async throws -> R where R: Sendable {
    // ...
  }

  func serverStreamingRPC<R>(
    request: ClientRequest<InputName>,
    options: CallOptions = .defaults,
    _ body: @Sendable @escaping (StreamingClientResponse<OutputName>) async throws -> R
  ) async throws -> R where R: Sendable {
    // ...
  }

  func bidirectionalStreamingRPC<R>(
    request: StreamingClientRequest<InputName>,
    options: CallOptions = .defaults,
    _ body: @Sendable @escaping (StreamingClientResponse<OutputName>) async throws -> R
  ) async throws -> R where R: Sendable {
    // ...
  }
}
```

gRPC Swift also generates an additional extension providing even higher-level APIs.
These let the user avoid creating the request types themselves, since the
extension creates them on behalf of the user. For unary RPCs, this API distils
down to message-in, message-out; for bidirectional streaming, it distils down
to two closures, one for sending messages, one for handling response messages.

```swift
extension ServiceName.ClientProtocol {
  func unaryRPC<Result>(
    _ message: InputName,
    metadata: Metadata = [:],
    options: CallOptions = .defaults,
    onResponse handleResponse: @Sendable @escaping (ClientResponse<OutputName>) async throws -> Result = { try $0.message }
  ) async throws -> Result where Result: Sendable {
    // ...
  }

  func clientStreamingRPC<Result>(
    metadata: Metadata = [:],
    options: CallOptions = .defaults,
    requestProducer: @Sendable @escaping (RPCWriter<InputName>) async throws -> Void,
    onResponse handleResponse: @Sendable @escaping (ClientResponse<OutputName>) async throws -> Result = { try $0.message }
  ) async throws -> Result where Result: Sendable {
    // ...
  }

  func serverStreamingRPC<Result>(
    _ message: InputName,
    metadata: Metadata = [:],
    options: CallOptions = .defaults,
    onResponse handleResponse: @Sendable @escaping (StreamingClientResponse<OutputName>) async throws -> Result
  ) async throws -> Result where Result: Sendable {
    // ...
  }

  func bidirectionalStreamingRPC<Result>(
    metadata: Metadata = [:],
    options: CallOptions = .defaults,
    requestProducer: @Sendable @escaping (RPCWriter<InputName>) async throws -> Void,
    onResponse handleResponse: @Sendable @escaping (StreamingClientResponse<OutputName>) async throws -> Result
  ) async throws -> Result where Result: Sendable {
    // ...
  }
}
```

To see this in use, refer to the <doc:Hello-World> or <doc:Route-Guide> tutorials
or the examples in the [grpc/grpc-swift-2](https://github.com/grpc/grpc-swift-2)
repository on GitHub.
