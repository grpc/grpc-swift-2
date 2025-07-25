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

import GRPCInProcessTransport
import XCTest

@testable import GRPCCore

/// A test harness for the ``ClientRPCExecutor``.
///
/// It provides different hooks for controlling the transport implementation and the behaviour
/// of the server to allow for flexible testing scenarios with minimal boilerplate. The harness
/// also tracks how many streams the client has opened, how many streams the server accepted, and
/// how many streams the client failed to open.
@available(gRPCSwift 2.0, *)
struct ClientRPCExecutorTestHarness {
  private let server: ServerStreamHandler
  private let clientTransport: StreamCountingClientTransport
  private let serverTransport: StreamCountingServerTransport
  private let interceptors: [any ClientInterceptor]

  var clientStreamsOpened: Int {
    self.clientTransport.streamsOpened
  }

  var clientStreamOpenFailures: Int {
    self.clientTransport.streamFailures
  }

  var serverStreamsAccepted: Int {
    self.serverTransport.acceptedStreamsCount
  }

  init(
    transport: Transport = .inProcess,
    server: ServerStreamHandler,
    interceptors: [any ClientInterceptor] = []
  ) {
    self.server = server
    self.interceptors = interceptors

    switch transport {
    case .inProcess:
      let server = InProcessTransport.Server(peer: "in-process:1234")
      let client = server.spawnClientTransport()
      self.serverTransport = StreamCountingServerTransport(wrapping: server)
      self.clientTransport = StreamCountingClientTransport(wrapping: client)

    case .throwsOnStreamCreation(let code):
      let server = InProcessTransport.Server(peer: "in-process:1234")  // Will never be called.
      let client = ThrowOnStreamCreationTransport(code: code)
      self.serverTransport = StreamCountingServerTransport(wrapping: server)
      self.clientTransport = StreamCountingClientTransport(wrapping: client)
    }
  }

  enum Transport {
    case inProcess
    case throwsOnStreamCreation(code: RPCError.Code)
  }

  func unary(
    request: ClientRequest<[UInt8]>,
    options: CallOptions = .defaults,
    handler: @escaping @Sendable (ClientResponse<[UInt8]>) async throws -> Void
  ) async throws {
    try await self.bidirectional(
      request: StreamingClientRequest(single: request),
      options: options
    ) { response in
      try await handler(ClientResponse(stream: response))
    }
  }

  func clientStreaming(
    request: StreamingClientRequest<[UInt8]>,
    options: CallOptions = .defaults,
    handler: @escaping @Sendable (ClientResponse<[UInt8]>) async throws -> Void
  ) async throws {
    try await self.bidirectional(request: request, options: options) { response in
      try await handler(ClientResponse(stream: response))
    }
  }

  func serverStreaming(
    request: ClientRequest<[UInt8]>,
    options: CallOptions = .defaults,
    handler: @escaping @Sendable (StreamingClientResponse<[UInt8]>) async throws -> Void
  ) async throws {
    try await self.bidirectional(
      request: StreamingClientRequest(single: request),
      options: options
    ) { response in
      try await handler(response)
    }
  }

  func bidirectional(
    request: StreamingClientRequest<[UInt8]>,
    options: CallOptions = .defaults,
    handler: @escaping @Sendable (StreamingClientResponse<[UInt8]>) async throws -> Void
  ) async throws {
    try await self.execute(
      request: request,
      serializer: IdentitySerializer(),
      deserializer: IdentityDeserializer(),
      options: options,
      handler: handler
    )
  }

  private func execute<Input, Output>(
    request: StreamingClientRequest<Input>,
    serializer: some MessageSerializer<Input>,
    deserializer: some MessageDeserializer<Output>,
    options: CallOptions,
    handler: @escaping @Sendable (StreamingClientResponse<Output>) async throws -> Void
  ) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        try await self.serverTransport.listen { stream, context in
          do {
            try await self.server.handle(stream: stream)
          } catch {
            await stream.outbound.finish(throwing: error)
          }
        }
      }

      group.addTask {
        try await self.clientTransport.connect()
      }

      // Execute the request.
      try await ClientRPCExecutor.execute(
        request: request,
        method: MethodDescriptor(fullyQualifiedService: "foo", method: "bar"),
        options: options,
        serializer: serializer,
        deserializer: deserializer,
        transport: self.clientTransport,
        interceptors: self.interceptors,
        handler: handler
      )

      // Close the client so the server can finish.
      self.clientTransport.beginGracefulShutdown()
      self.serverTransport.beginGracefulShutdown()
      group.cancelAll()
    }
  }
}
