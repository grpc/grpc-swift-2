# Errors

Learn about the different error mechanisms in gRPC and how to use them.

## Overview

gRPC has a well-defined error model for RPCs and a common extension to provide
richer errors when using Protocol Buffers. This article explains both mechanisms
and offers advice on using and handling RPC errors for service authors and
clients.

### Error models

gRPC has two widely used error models:

1. A “standard” error model supported by all client/server gRPC libraries.
2. A “rich” error model providing more detailed error information via serialized
   Protocol Buffers messages.

#### Standard error model

In gRPC, a status made up of a code and a message represents the outcome of
every RPC. gRPC propagates the status from the server to the client in the
metadata as the final part of an RPC indicating the outcome of the RPC.

You can find more information about the error codes in ``RPCError/Code`` and in
the status codes guide on the
[gRPC website](https://grpc.io/docs/guides/status-codes/).

This mechanism is part of the gRPC protocol, and all client/server gRPC libraries
support it regardless of the data format (for example, Protocol Buffers) you use
for messages.

#### Rich error model

The standard error model is quite limited and doesn't include the ability to
communicate details about the error. If you're using the Protocol Buffers data
format for messages, then you may wish to use the “rich” error model.

Google developed and used the model, which the
[gRPC error guide](https://grpc.io/docs/guides/error/) and
[Google AIP-193](https://google.aip.dev/193) describe in more detail.

While not officially part of gRPC, it's a widely used convention with support in
various client/server gRPC libraries, including gRPC Swift.

It specifies a standard set of error message types covering the most common
situations. The rich error model encodes the error details as protobuf messages in the trailing
metadata of an RPC. Clients are able to deserialize and access the details as
type-safe structured messages should they need to.

### User guide

Learn how to use both models in gRPC Swift.

#### Service authors

The gRPC runtime catches errors your RPC handler throws and turns them into
a status. You have two options to ensure that the gRPC runtime sends an appropriate status to
the client if your RPC handler throws an error:

1. Throw an ``RPCError`` that explicitly sets the desired status code and
   message.
2. Throw an error conforming to ``RPCErrorConvertible`` that the gRPC runtime
   will use to create an ``RPCError``.

Any errors thrown that don't fall into these categories cause the gRPC runtime to send a status
code of `unknown` to the client.

Generally speaking, you should consider expected failure scenarios as part of
the API contract and document each RPC accordingly.

#### Clients

Clients should catch ``RPCError`` if they are interested in the failures from an
RPC. This is a manifestation of the error the server sends, but in some cases
the client may synthesize it locally. For example, if a client-side timeout fires
before the RPC completes, the client throws an ``RPCError`` with code
``RPCError/Code-swift.struct/deadlineExceeded``. If the calling `Task` is
cancelled, the client may instead throw an ``RPCError`` with code `unknown`
wrapping the underlying `CancellationError` as its `cause` — check `cause` if
you need to distinguish cancellation from other failures reported as `unknown`.

Failures to serialize a request or deserialize a response also surface as an
``RPCError``; the exact code and message depend on the serializer/deserializer
in use. For example, the Protobuf codec provided by `grpc-swift-protobuf` uses
``RPCError/Code-swift.struct/invalidArgument`` when it can't
serialize or deserialize a message.

If the transport receives a non-200 HTTP status without an accompanying gRPC
status (for example because the RPC failed before reaching a gRPC-aware peer),
gRPC Swift synthesizes the HTTP status into a ``Status`` for you to catch as an
``RPCError``.

For clients using the rich error model, you can catch the ``RPCError`` and
extract a detailed error from it using `unpackGoogleRPCStatus()`.

See [`error-details`](https://github.com/grpc/grpc-swift-2/tree/main/Examples/error-details) for an example.
