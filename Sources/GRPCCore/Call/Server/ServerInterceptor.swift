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

/// A type that intercepts requests and responses for a server.
///
/// Interceptors allow you to inspect and modify requests and responses. The server intercepts
/// requests after the transport receives them, and intercepts responses after a service returns
/// them. You typically use interceptors for cross-cutting concerns like filtering requests,
/// validating messages, logging additional data, and tracing.
///
/// Register interceptors with the server either directly or via ``ConditionalInterceptor``s.
/// You may register them for all services registered with a server, for RPCs directed to specific services, or
/// for RPCs directed to specific methods. If you need to modify the behavior of an interceptor on a
/// per-RPC basis in more detail, then you can use the ``ServerContext/descriptor`` to determine
/// which RPC the client is calling and conditionalise behavior accordingly.
///
/// ## RPC filtering
///
/// A common use of server-side interceptors is to filter requests from clients. Interceptors can
/// reject invalid requests without calling service code. The following example
/// demonstrates this.
///
/// ```swift
/// struct AuthServerInterceptor: ServerInterceptor {
///   let isAuthorized: @Sendable (String, MethodDescriptor) async throws -> Void
///
///   func intercept<Input: Sendable, Output: Sendable>(
///     request: StreamingServerRequest<Input>,
///     context: ServerContext,
///     next: @Sendable (
///       _ request: StreamingServerRequest<Input>,
///       _ context: ServerContext
///     ) async throws -> StreamingServerResponse<Output>
///   ) async throws -> StreamingServerResponse<Output> {
///     // Extract the auth token.
///     guard let token = request.metadata[stringValues: "authorization"].first(where: { _ in true }) else {
///       throw RPCError(code: .unauthenticated, message: "Not authenticated")
///     }
///
///     // Check whether it's valid.
///     try await self.isAuthorized(token, context.descriptor)
///
///     // Forward the request.
///     return try await next(request, context)
///   }
/// }
/// ```
///
/// For client-side interceptors, see ``ClientInterceptor``.
@available(gRPCSwift 2.0, *)
public protocol ServerInterceptor: Sendable {
  /// Intercept a request object.
  ///
  /// - Parameters:
  ///   - request: The request object.
  ///   - context: Additional context about the request, including a descriptor
  ///       of the method being called.
  ///   - next: A closure to invoke to hand off the request and context to the next
  ///       interceptor in the chain.
  /// - Returns: A response object.
  func intercept<Input: Sendable, Output: Sendable>(
    request: StreamingServerRequest<Input>,
    context: ServerContext,
    next:
      @Sendable (
        _ request: StreamingServerRequest<Input>,
        _ context: ServerContext
      ) async throws -> StreamingServerResponse<Output>
  ) async throws -> StreamingServerResponse<Output>
}
