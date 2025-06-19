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
extension ClientInterceptor where Self == RejectAllClientInterceptor {
  static func rejectAll(with error: RPCError) -> Self {
    return RejectAllClientInterceptor(reject: error)
  }

  static func throwError(_ error: any Error) -> Self {
    return RejectAllClientInterceptor(throw: error)
  }

  static func throwInBodyParts(_ error: any Error) -> Self {
    return RejectAllClientInterceptor(throwInBodyParts: error)
  }

  static func throwInProducer(_ error: any Error) -> Self {
    return RejectAllClientInterceptor(throwInProducer: error)
  }
}

@available(gRPCSwift 2.0, *)
extension ClientInterceptor where Self == RequestCountingClientInterceptor {
  static func requestCounter(_ counter: AtomicCounter) -> Self {
    return RequestCountingClientInterceptor(counter: counter)
  }
}

/// Rejects all RPCs with the provided error.
@available(gRPCSwift 2.0, *)
struct RejectAllClientInterceptor: ClientInterceptor {
  enum Mode: Sendable {
    /// Throw the error rather.
    case `throw`(any Error)
    /// Reject the RPC with a given error.
    case reject(RPCError)
    /// Throw an error in the body parts sequence.
    case throwInBodyParts(any Error)
    /// Throw an error in the message producer closure.
    case throwInProducer(any Error)
  }

  let mode: Mode

  init(throw error: any Error) {
    self.mode = .throw(error)
  }

  init(reject error: RPCError) {
    self.mode = .reject(error)
  }

  init(throwInBodyParts error: any Error) {
    self.mode = .throwInBodyParts(error)
  }

  init(throwInProducer error: any Error) {
    self.mode = .throwInProducer(error)
  }

  func intercept<Input: Sendable, Output: Sendable>(
    request: StreamingClientRequest<Input>,
    context: ClientContext,
    next: (
      StreamingClientRequest<Input>,
      ClientContext
    ) async throws -> StreamingClientResponse<Output>
  ) async throws -> StreamingClientResponse<Output> {
    switch self.mode {
    case .throw(let error):
      throw error
    case .reject(let error):
      return StreamingClientResponse(error: error)
    case .throwInBodyParts(let error):
      var response = try await next(request, context)
      switch response.accepted {
      case .success(var success):
        let stream = AsyncThrowingStream<
          StreamingClientResponse<Output>.Contents.BodyPart, any Error
        >.makeStream()
        stream.continuation.finish(throwing: error)

        success.bodyParts = RPCAsyncSequence(wrapping: stream.stream)
        response.accepted = .success(success)
        return response
      case .failure:
        return response
      }
    case .throwInProducer(let error):
      let wrappedProducer = request.producer

      var request = request
      request.producer = { writer in
        try await wrappedProducer(writer)
        throw error
      }

      return try await next(request, context)
    }
  }
}

@available(gRPCSwift 2.0, *)
struct RequestCountingClientInterceptor: ClientInterceptor {
  /// The number of requests made.
  let counter: AtomicCounter

  init(counter: AtomicCounter) {
    self.counter = counter
  }

  func intercept<Input: Sendable, Output: Sendable>(
    request: StreamingClientRequest<Input>,
    context: ClientContext,
    next: (
      StreamingClientRequest<Input>,
      ClientContext
    ) async throws -> StreamingClientResponse<Output>
  ) async throws -> StreamingClientResponse<Output> {
    self.counter.increment()
    return try await next(request, context)
  }
}
