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

import GRPCCore

@available(gRPCSwift 2.0, *)
extension ServerInterceptor where Self == RejectAllServerInterceptor {
  static func rejectAll(with error: RPCError) -> Self {
    return RejectAllServerInterceptor(reject: error)
  }

  static func throwError(_ error: any Error) -> Self {
    RejectAllServerInterceptor(throw: error)
  }

  static func throwInProducer(_ error: any Error) -> Self {
    RejectAllServerInterceptor(throwInProducer: error)
  }

  static func throwInMessageSequence(_ error: any Error) -> Self {
    RejectAllServerInterceptor(throwInMessageSequence: error)
  }
}

@available(gRPCSwift 2.0, *)
extension ServerInterceptor where Self == RequestCountingServerInterceptor {
  static func requestCounter(_ counter: AtomicCounter) -> Self {
    RequestCountingServerInterceptor(counter: counter)
  }
}

/// Rejects all RPCs with the provided error.
@available(gRPCSwift 2.0, *)
struct RejectAllServerInterceptor: ServerInterceptor {
  enum Mode: Sendable {
    /// Throw the error rather.
    case `throw`(any Error)
    /// Reject the RPC with a given error.
    case reject(RPCError)
    /// Throw in the producer closure returned.
    case throwInProducer(any Error)
    /// Throw in the async sequence that stream inbound messages.
    case throwInMessageSequence(any Error)
  }

  private enum TimeoutResult {
    case `throw`(any Error)
    case cancelled
    case result(Metadata)
  }

  let mode: Mode

  init(throw error: any Error) {
    self.mode = .throw(error)
  }

  init(reject error: RPCError) {
    self.mode = .reject(error)
  }

  init(throwInProducer error: any Error) {
    self.mode = .throwInProducer(error)
  }

  init(throwInMessageSequence error: any Error) {
    self.mode = .throwInMessageSequence(error)
  }

  func intercept<Input: Sendable, Output: Sendable>(
    request: StreamingServerRequest<Input>,
    context: ServerContext,
    next: @Sendable (
      StreamingServerRequest<Input>,
      ServerContext
    ) async throws -> StreamingServerResponse<Output>
  ) async throws -> StreamingServerResponse<Output> {
    switch self.mode {
    case .throw(let error):
      throw error
    case .reject(let error):
      return StreamingServerResponse(error: error)
    case .throwInProducer(let error):
      var response = try await next(request, context)
      switch response.accepted {
      case .success(var success):
        let wrappedProducer = success.producer
        success.producer = { writer in
          try await withThrowingTaskGroup(of: Metadata.self) { group in
            group.addTask {
              try await wrappedProducer(writer)
            }

            group.cancelAll()
            _ = try await group.next()!
            throw error
          }
        }

        response.accepted = .success(success)
        return response
      case .failure:
        return response
      }
    case .throwInMessageSequence(let error):
      let stream = AsyncThrowingStream<Input, any Error>.makeStream()
      stream.continuation.finish(throwing: error)

      var request = request
      request.messages = RPCAsyncSequence(wrapping: stream.stream)

      return try await next(request, context)
    }
  }
}

@available(gRPCSwift 2.0, *)
struct RequestCountingServerInterceptor: ServerInterceptor {
  /// The number of requests made.
  let counter: AtomicCounter

  init(counter: AtomicCounter) {
    self.counter = counter
  }

  func intercept<Input: Sendable, Output: Sendable>(
    request: StreamingServerRequest<Input>,
    context: ServerContext,
    next: @Sendable (
      StreamingServerRequest<Input>,
      ServerContext
    ) async throws -> StreamingServerResponse<Output>
  ) async throws -> StreamingServerResponse<Output> {
    self.counter.increment()
    return try await next(request, context)
  }
}
