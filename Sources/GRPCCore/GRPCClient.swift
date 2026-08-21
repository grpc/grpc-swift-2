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

private import Synchronization

/// A gRPC client.
///
/// A ``GRPCClient`` communicates to a server via a ``ClientTransport``.
///
/// You can start RPCs to the server by calling the corresponding method:
/// - ``unary(request:descriptor:serializer:deserializer:options:onResponse:)``
/// - ``clientStreaming(request:descriptor:serializer:deserializer:options:onResponse:)``
/// - ``serverStreaming(request:descriptor:serializer:deserializer:options:onResponse:)``
/// - ``bidirectionalStreaming(request:descriptor:serializer:deserializer:options:onResponse:)``
///
/// However, in most cases you should prefer wrapping the ``GRPCClient`` with a generated stub.
///
/// ## Creating a client
///
/// You can create and run a client using ``withGRPCClient(transport:interceptors:isolation:handleClient:)``
/// or ``withGRPCClient(transport:interceptorPipeline:isolation:handleClient:)`` which creates, configures, and
/// runs the client, providing scoped access to it through the `handleClient` closure. The client will
/// begin gracefully shutting down when the closure returns.
///
/// ```swift
/// let transport: any ClientTransport = ...
/// try await withGRPCClient(transport: transport) { client in
///   // ...
/// }
/// ```
///
/// Within the closure, create service-specific clients to access any gRPC services available at the server that the transport connects to.
/// For example, a client for a service called `Api` could be created using the related generated code:
/// ```swift
/// let apiClient = Grpc_Api.Client(wrapping: client)
/// ```
///
/// You can use a single `GRPCClient` instance to connect to as many services as the endpoint provides.
///
/// ## Creating a client manually
///
/// If the `with`-style methods for creating clients aren't suitable for your application then you
/// can create and run a client manually. This requires you to call the ``runConnections()`` method in a task
/// which instructs the client to start connecting to the server.
///
/// The ``runConnections()`` method won't return until the client has finished handling all requests. You can
/// signal to the client that it should stop creating new request streams by calling ``beginGracefulShutdown()``.
/// This gives the client enough time to drain any requests already in flight. To stop the client
/// more abruptly you can cancel the task running your client.
///
/// If your application requires additional resources that need their lifecycles managed,
/// consider managing the client and its resources with [Swift Service
/// Lifecycle](https://github.com/swift-server/swift-service-lifecycle).
/// Use the [GRPCServiceLifecycle](https://swiftpackageindex.com/grpc/grpc-swift-extras/documentation/grpcservicelifecycle) module
/// of [grpc-swift-extras](https://swiftpackageindex.com/grpc/grpc-swift-extras) to conform a `GRPCClient` to the `Service` protocol, and use it directly
/// within a [ServiceGroup](https://swiftpackageindex.com/swift-server/swift-service-lifecycle/documentation/servicelifecycle/servicegroup).
/// Read [Adopting ServiceLifecycle in applications](https://swiftpackageindex.com/swift-server/swift-service-lifecycle/documentation/servicelifecycle/adopting-servicelifecycle-in-applications) or
/// [Adopting ServiceLifecycle in libraries](https://swiftpackageindex.com/swift-server/swift-service-lifecycle/documentation/servicelifecycle/adopting-servicelifecycle-in-libraries) for more detail.
///
/// Once the client stops, it can't be restarted. If you call ``runConnections()`` again,
/// the client throws a ``RuntimeError``.
/// Create a new ``GRPCClient`` (and a new transport) if you need to reconnect.
@available(gRPCSwift 2.0, *)
public final class GRPCClient<Transport: ClientTransport>: Sendable {
  /// The transport which provides a bidirectional communication channel with the server.
  private let transport: Transport

  /// The current state of the client.
  private let stateMachine: Mutex<StateMachine>

  /// The state of the client.
  private enum State: Sendable {

    /// The client hasn't started yet. Can transition to `running` or `stopped`.
    case notStarted
    /// The client is running and can send RPCs. Can transition to `stopping`.
    case running
    /// The client is stopping and won't send new RPCs. Existing RPCs may run to
    /// completion. May transition to `stopped`.
    case stopping
    /// The client has stopped: no RPCs are in flight and it won't accept any more. This state
    /// is terminal.
    case stopped

    mutating func run() throws {
      switch self {
      case .notStarted:
        self = .running

      case .running:
        throw RuntimeError(
          code: .clientIsAlreadyRunning,
          message: "The client is already running and can only be started once."
        )

      case .stopping, .stopped:
        throw RuntimeError(
          code: .clientIsStopped,
          message: """
            Can't call 'runConnections()' as the client is stopped (or is stopping). \
            This can happen if the you call 'runConnections()' after shutting the \
            client down or if you used 'withGRPCClient' with an empty body.
            """
        )
      }
    }

    mutating func stopped() {
      self = .stopped
    }

    mutating func beginGracefulShutdown() -> Bool {
      switch self {
      case .notStarted:
        self = .stopped
        return false
      case .running:
        self = .stopping
        return true
      case .stopping, .stopped:
        return false
      }
    }

    func checkExecutable() throws {
      switch self {
      case .notStarted, .running:
        // Allow .notStarted as making a request can race with 'runConnections()'. Transports should tolerate
        // queuing the request if not yet started.
        ()
      case .stopping, .stopped:
        throw RuntimeError(
          code: .clientIsStopped,
          message: "Client has been stopped. Can't make any more RPCs."
        )
      }
    }
  }

  private struct StateMachine {
    var state: State

    private let interceptorPipeline: [ConditionalInterceptor<any ClientInterceptor>]

    /// A collection of interceptors providing cross-cutting functionality to each accepted RPC, keyed by the method to which they apply.
    ///
    /// This type computes the list of interceptors for each method from `interceptorPipeline` the
    /// first time a caller invokes that method, and caches the result to avoid recomputing the
    /// applicable interceptors for each request.
    ///
    /// The order in which you add interceptors determines the order in which they run. The first
    /// interceptor added is the first interceptor to intercept each request. The last interceptor
    /// added is the final interceptor to intercept each request before calling the appropriate
    /// handler.
    var interceptorsPerMethod: [MethodDescriptor: [any ClientInterceptor]]

    init(interceptorPipeline: [ConditionalInterceptor<any ClientInterceptor>]) {
      self.state = .notStarted
      self.interceptorPipeline = interceptorPipeline
      self.interceptorsPerMethod = [:]
    }

    mutating func checkExecutableAndGetApplicableInterceptors(
      for method: MethodDescriptor
    ) throws -> [any ClientInterceptor] {
      try self.state.checkExecutable()

      guard let applicableInterceptors = self.interceptorsPerMethod[method] else {
        let applicableInterceptors = self.interceptorPipeline
          .filter { $0.applies(to: method) }
          .map { $0.interceptor }
        self.interceptorsPerMethod[method] = applicableInterceptors
        return applicableInterceptors
      }

      return applicableInterceptors
    }
  }

  /// Creates a new client that applies the given interceptors to every RPC.
  ///
  /// - Parameters:
  ///   - transport: The transport used to establish a communication channel with a server.
  ///   - interceptors: A collection of ``ClientInterceptor``s providing cross-cutting functionality to each
  ///       accepted RPC. The order in which you add interceptors determines the order in which they
  ///       run. The first interceptor added is the first interceptor to intercept each
  ///       request. The last interceptor added is the final interceptor to intercept each
  ///       request before calling the appropriate handler.
  convenience public init(
    transport: Transport,
    interceptors: [any ClientInterceptor] = []
  ) {
    self.init(
      transport: transport,
      interceptorPipeline: interceptors.map { .apply($0, to: .all) }
    )
  }

  /// Creates a new client that applies interceptors selectively to the RPCs each one targets.
  ///
  /// - Parameters:
  ///   - transport: The transport used to establish a communication channel with a server.
  ///   - interceptorPipeline: A collection of ``ConditionalInterceptor``s providing cross-cutting
  ///       functionality to each accepted RPC. This applies only the interceptors from the
  ///       pipeline that apply to each RPC. The order in which you add interceptors determines
  ///       the order in which they run. The first interceptor added is the first interceptor
  ///       to intercept each request. The last interceptor added is the final interceptor to
  ///       intercept each request before calling the appropriate handler.
  public init(
    transport: Transport,
    interceptorPipeline: [ConditionalInterceptor<any ClientInterceptor>]
  ) {
    self.transport = transport
    self.stateMachine = Mutex(StateMachine(interceptorPipeline: interceptorPipeline))
  }

  /// Starts the client.
  ///
  /// This returns once you've called ``beginGracefulShutdown()`` and all in-flight RPCs have finished executing.
  /// If you need to abruptly stop all work you should cancel the task executing this method.
  ///
  /// Call this function at most once per client. If the client is already
  /// running, or you've already closed it, this function throws a ``RuntimeError``.
  public func runConnections() async throws {
    try self.stateMachine.withLock { try $0.state.run() }

    // When this function exits the client must have stopped.
    defer {
      self.stateMachine.withLock { $0.state.stopped() }
    }

    do {
      try await self.transport.connect()
    } catch {
      throw RuntimeError(
        code: .transportError,
        message: "The transport threw an error while connected.",
        cause: error
      )
    }
  }

  /// Closes the client.
  ///
  /// This begins closing the transport, giving it enough time for
  /// in-flight RPCs to finish executing, but it won't accept new RPCs. To abruptly stop
  /// in-flight RPCs, cancel the task executing ``runConnections()``.
  public func beginGracefulShutdown() {
    let wasRunning = self.stateMachine.withLock { $0.state.beginGracefulShutdown() }
    if wasRunning {
      self.transport.beginGracefulShutdown()
    }
  }

  /// Executes a unary RPC.
  ///
  /// - Note: You mustn't have called ``beginGracefulShutdown()``. You don't need to have called
  /// ``runConnections()`` first — a request made before the client starts running is queued — but
  /// if you have called it, it must still be executing.
  ///
  /// - Parameters:
  ///   - request: The unary request.
  ///   - descriptor: The method descriptor for which to execute this request.
  ///   - serializer: A request serializer.
  ///   - deserializer: A response deserializer.
  ///   - options: Call specific options.
  ///   - handleResponse: A unary response handler.
  ///
  /// - Returns: The return value from the `handleResponse`.
  public func unary<Request, Response, ReturnValue: Sendable>(
    request: ClientRequest<Request>,
    descriptor: MethodDescriptor,
    serializer: some MessageSerializer<Request>,
    deserializer: some MessageDeserializer<Response>,
    options: CallOptions,
    onResponse handleResponse:
      @Sendable @escaping (
        _ response: ClientResponse<Response>
      ) async throws -> ReturnValue
  ) async throws -> ReturnValue {
    try await self.bidirectionalStreaming(
      request: StreamingClientRequest(single: request),
      descriptor: descriptor,
      serializer: serializer,
      deserializer: deserializer,
      options: options
    ) { stream in
      let singleResponse = await ClientResponse(stream: stream)
      return try await handleResponse(singleResponse)
    }
  }

  /// Starts a client-streaming RPC.
  ///
  /// - Note: You mustn't have called ``beginGracefulShutdown()``. You don't need to have called
  /// ``runConnections()`` first — a request made before the client starts running is queued — but
  /// if you have called it, it must still be executing.
  ///
  /// - Parameters:
  ///   - request: The request stream.
  ///   - descriptor: The method descriptor for which to execute this request.
  ///   - serializer: A request serializer.
  ///   - deserializer: A response deserializer.
  ///   - options: Call specific options.
  ///   - handleResponse: A unary response handler.
  ///
  /// - Returns: The return value from the `handleResponse`.
  public func clientStreaming<Request, Response, ReturnValue: Sendable>(
    request: StreamingClientRequest<Request>,
    descriptor: MethodDescriptor,
    serializer: some MessageSerializer<Request>,
    deserializer: some MessageDeserializer<Response>,
    options: CallOptions,
    onResponse handleResponse:
      @Sendable @escaping (
        _ response: ClientResponse<Response>
      ) async throws -> ReturnValue
  ) async throws -> ReturnValue {
    try await self.bidirectionalStreaming(
      request: request,
      descriptor: descriptor,
      serializer: serializer,
      deserializer: deserializer,
      options: options
    ) { stream in
      let singleResponse = await ClientResponse(stream: stream)
      return try await handleResponse(singleResponse)
    }
  }

  /// Starts a server-streaming RPC.
  ///
  /// - Note: You mustn't have called ``beginGracefulShutdown()``. You don't need to have called
  /// ``runConnections()`` first — a request made before the client starts running is queued — but
  /// if you have called it, it must still be executing.
  ///
  /// - Parameters:
  ///   - request: The unary request.
  ///   - descriptor: The method descriptor for which to execute this request.
  ///   - serializer: A request serializer.
  ///   - deserializer: A response deserializer.
  ///   - options: Call specific options.
  ///   - handleResponse: A response stream handler.
  ///
  /// - Returns: The return value from the `handleResponse`.
  public func serverStreaming<Request, Response, ReturnValue: Sendable>(
    request: ClientRequest<Request>,
    descriptor: MethodDescriptor,
    serializer: some MessageSerializer<Request>,
    deserializer: some MessageDeserializer<Response>,
    options: CallOptions,
    onResponse handleResponse:
      @Sendable @escaping (
        _ response: StreamingClientResponse<Response>
      ) async throws -> ReturnValue
  ) async throws -> ReturnValue {
    try await self.bidirectionalStreaming(
      request: StreamingClientRequest(single: request),
      descriptor: descriptor,
      serializer: serializer,
      deserializer: deserializer,
      options: options,
      onResponse: handleResponse
    )
  }

  /// Starts a bidirectional streaming RPC.
  ///
  /// - Note: You mustn't have called ``beginGracefulShutdown()``. You don't need to have called
  /// ``runConnections()`` first — a request made before the client starts running is queued — but
  /// if you have called it, it must still be executing.
  ///
  /// - Parameters:
  ///   - request: The streaming request.
  ///   - descriptor: The method descriptor for which to execute this request.
  ///   - serializer: A request serializer.
  ///   - deserializer: A response deserializer.
  ///   - options: Call specific options.
  ///   - handleResponse: A response stream handler.
  ///
  /// - Returns: The return value from the `handleResponse`.
  public func bidirectionalStreaming<Request, Response, ReturnValue: Sendable>(
    request: StreamingClientRequest<Request>,
    descriptor: MethodDescriptor,
    serializer: some MessageSerializer<Request>,
    deserializer: some MessageDeserializer<Response>,
    options: CallOptions,
    onResponse handleResponse:
      @Sendable @escaping (
        _ response: StreamingClientResponse<Response>
      ) async throws -> ReturnValue
  ) async throws -> ReturnValue {
    let applicableInterceptors = try self.stateMachine.withLock {
      try $0.checkExecutableAndGetApplicableInterceptors(for: descriptor)
    }
    let methodConfig = self.transport.config(forMethod: descriptor)
    var options = options
    options.formUnion(with: methodConfig)

    return try await ClientRPCExecutor.execute(
      request: request,
      method: descriptor,
      options: options,
      serializer: serializer,
      deserializer: deserializer,
      transport: self.transport,
      interceptors: applicableInterceptors,
      handler: handleResponse
    )
  }
}

/// Creates and runs a new client with the given transport, applying the given interceptors to every RPC.
///
/// - Parameters:
///   - transport: The transport used to establish a communication channel with a server.
///   - interceptors: A collection of ``ClientInterceptor``s providing cross-cutting functionality to each
///       accepted RPC. The order in which you add interceptors determines the order in which they
///       run. The first interceptor added is the first interceptor to intercept each
///       request. The last interceptor added is the final interceptor to intercept each
///       request before calling the appropriate handler.
///   - isolation: A reference to the actor to which the enclosing code is isolated, or nil if the
///       code is nonisolated.
///   - handleClient: A closure which is called with the client. When the closure returns, the
///       client shuts down gracefully.
@available(gRPCSwift 2.0, *)
public func withGRPCClient<Transport: ClientTransport, Result: Sendable>(
  transport: Transport,
  interceptors: [any ClientInterceptor] = [],
  isolation: isolated (any Actor)? = #isolation,
  handleClient: (GRPCClient<Transport>) async throws -> Result
) async throws -> Result {
  try await withGRPCClient(
    transport: transport,
    interceptorPipeline: interceptors.map { .apply($0, to: .all) },
    isolation: isolation,
    handleClient: handleClient
  )
}

/// Creates and runs a new client with the given transport, applying interceptors selectively to the RPCs each one targets.
///
/// - Parameters:
///   - transport: The transport used to establish a communication channel with a server.
///   - interceptorPipeline: A collection of ``ConditionalInterceptor``s providing cross-cutting
///       functionality to each accepted RPC. This applies only the interceptors from the pipeline
///       that apply to each RPC. The order in which you add interceptors determines the order in
///       which they run. The first interceptor added is the first interceptor to intercept each request.
///       The last interceptor added is the final interceptor to intercept each request before calling the appropriate handler.
///   - isolation: A reference to the actor to which the enclosing code is isolated, or nil if the
///       code is nonisolated.
///   - handleClient: A closure which is called with the client. When the closure returns, the
///       client shuts down gracefully.
/// - Returns: The result of the `handleClient` closure.
@available(gRPCSwift 2.0, *)
public func withGRPCClient<Transport: ClientTransport, Result: Sendable>(
  transport: Transport,
  interceptorPipeline: [ConditionalInterceptor<any ClientInterceptor>],
  isolation: isolated (any Actor)? = #isolation,
  handleClient: (GRPCClient<Transport>) async throws -> Result
) async throws -> Result {
  try await withThrowingDiscardingTaskGroup { group in
    let client = GRPCClient(transport: transport, interceptorPipeline: interceptorPipeline)
    group.addTask {
      try await client.runConnections()
    }

    let result = try await handleClient(client)
    client.beginGracefulShutdown()
    return result
  }
}
