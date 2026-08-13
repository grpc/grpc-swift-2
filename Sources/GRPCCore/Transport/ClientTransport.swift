/*
 * Copyright 2023, gRPC Authors All rights reserved.
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

/// A type that provides a long-lived bidirectional communication channel to a server.
///
/// The client transport is responsible for providing streams to a backend that the client can
/// use to execute an RPC. A typical transport implementation will establish and maintain
/// connections to a server (or servers) and manage these over time, potentially closing idle
/// connections and creating new ones on demand. As such transports can be expensive to create,
/// use them as long-lived objects that exist for the lifetime of your application.
///
/// gRPC provides an in-process transport in the `GRPCInProcessTransport` module and an HTTP/2
/// transport built on top of SwiftNIO in the https://github.com/grpc/grpc-swift-nio-transport
/// package.
@available(gRPCSwift 2.0, *)
public protocol ClientTransport<Bytes>: Sendable {
  /// The bag-of-bytes type used by the transport.
  associatedtype Bytes: GRPCContiguousBytes & Sendable

  typealias Inbound = RPCAsyncSequence<RPCResponsePart<Bytes>, any Error>
  typealias Outbound = RPCWriter<RPCRequestPart<Bytes>>.Closable

  /// Returns a throttle which gRPC uses to determine whether it can execute retries.
  ///
  /// Client transports don't need to implement the throttle or interact with it beyond its
  /// creation. gRPC will record the results of requests to determine whether it can perform
  /// retries.
  var retryThrottle: RetryThrottle? { get }

  /// Establishes and maintains a connection to the remote destination.
  ///
  /// Maintains a long-lived connection, or set of connections, to a remote destination. The
  /// implementation may add or remove connections over time, based on the demand for streams
  /// from the client.
  ///
  /// Implementations of this function will typically create a long-lived task group that
  /// maintains connections. The function exits either when all open streams have closed and
  /// the caller no longer requires new connections — signaled by calling
  /// ``beginGracefulShutdown()`` — or when the caller cancels the task this function runs in.
  func connect() async throws

  /// Signals to the transport to stop creating new streams.
  ///
  /// Existing streams may run to completion naturally, but calling
  /// ``ClientTransport/withStream(descriptor:options:_:)`` should throw an ``RPCError`` with
  /// code ``RPCError/Code/failedPrecondition``.
  ///
  /// If you want to forcefully cancel all active streams, then cancel the task
  /// running ``connect()``.
  func beginGracefulShutdown()

  /// Opens a stream using the transport, and uses it as input to a user-provided closure alongside the given context.
  ///
  /// - Important: This function closes the opened stream after the closure finishes.
  ///
  /// Transport implementations should throw an ``RPCError`` with the following error codes:
  /// - ``RPCError/Code/failedPrecondition`` if the transport is closing or is already closed.
  /// - ``RPCError/Code/unavailable`` if it's temporarily not possible to create a stream and it
  ///   may be possible after some backoff period.
  ///
  /// - Parameters:
  ///   - descriptor: A description of the method to open a stream for.
  ///   - options: Options specific to the stream.
  ///   - closure: A closure that takes the opened stream and the client context as its parameters.
  /// - Returns: The value that `closure` returns.
  func withStream<T: Sendable>(
    descriptor: MethodDescriptor,
    options: CallOptions,
    _ closure: (_ stream: RPCStream<Inbound, Outbound>, _ context: ClientContext) async throws -> T
  ) async throws -> T

  /// Returns the configuration for a given method.
  ///
  /// - Parameter descriptor: The method to look up configuration for.
  /// - Returns: Configuration for the method, if it exists.
  func config(forMethod descriptor: MethodDescriptor) -> MethodConfig?
}
