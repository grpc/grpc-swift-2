/*
 * Copyright 2024, gRPC Authors All rights reserved.
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

/// Describes the conditions under which an interceptor should be applied.
///
/// You can configure interceptors to be applied to:
/// - all RPCs and services;
/// - requests directed only to specific services; or
/// - requests directed only to specific methods (of a specific service); or
/// - requests directed only to specific services or methods (of a specific service); or
/// - all requests excluding requests directed to specific services or methods (of a specific service); or
/// - requests whose ``MethodDescriptor`` satisfies a predicate.
///
/// - SeeAlso: ``ClientInterceptor`` and ``ServerInterceptor`` for more information on client and
///   server interceptors, respectively.
@available(gRPCSwift 2.0, *)
public struct ConditionalInterceptor<Interceptor: Sendable>: Sendable {
  public struct Subject: Sendable {

    private let predicate: @Sendable (_ descriptor: MethodDescriptor) -> Bool

    /// An operation subject specifying an interceptor that applies to all RPCs across all services will be registered with this client.
    public static var all: Self {
      Self { _ in true }
    }

    /// An operation subject specifying an interceptor that will be applied only to RPCs directed to the specified services.
    ///
    /// - Parameters:
    ///   - services: The list of service descriptors for which this interceptor should intercept RPCs.
    public static func services(_ services: Set<ServiceDescriptor>) -> Self {
      Self { descriptor in
        services.contains(descriptor.service)
      }
    }

    /// An operation subject specifying an interceptor that will be applied only to RPCs directed to the specified service methods.
    ///
    /// - Parameters:
    ///   - methods: The list of method descriptors for which this interceptor should intercept RPCs.
    public static func methods(_ methods: Set<MethodDescriptor>) -> Self {
      Self { descriptor in
        methods.contains(descriptor)
      }
    }

    /// An operation subject specifying an interceptor that will be applied only to RPCs directed to the specified services or service methods.
    ///
    /// - Parameters:
    ///   - services: The list of service descriptors for which this interceptor should intercept RPCs.
    ///   - methods: The list of method descriptors for which this interceptor should intercept RPCs.
    @available(gRPCSwift 2.2, *)
    public static func only(
      services: Set<ServiceDescriptor>,
      methods: Set<MethodDescriptor>
    ) -> Self {
      Self { descriptor in
        services.contains(descriptor.service) || methods.contains(descriptor)
      }
    }

    /// An operation subject specifying an interceptor that will be applied to all RPCs across all services for this client excluding the specified services or service methods.
    ///
    /// - Parameters:
    ///   - services: The list of service descriptors for which this interceptor should **not** intercept RPCs.
    ///   - methods: The list of method descriptors for which this interceptor should **not** intercept RPCs.
    @available(gRPCSwift 2.2, *)
    public static func allExcluding(
      services: Set<ServiceDescriptor>,
      methods: Set<MethodDescriptor>
    ) -> Self {
      Self { descriptor in
        !(services.contains(descriptor.service) || methods.contains(descriptor))
      }
    }

    /// An operation subject specifying an interceptor that will be applied to RPCs whose ``MethodDescriptor`` satisfies a `predicate`.
    ///
    /// - Important: The result of `predicate` is **cached per `MethodDescriptor`** by the client.
    ///   The predicate is evaluated the first time a given method is encountered, and that result
    ///   is reused for subsequent RPCs of the same method for the lifetime of the client.
    ///   As a consequence, the `predicate` closure should be **deterministic**.
    ///   Do **not** base it on dynamic state (time, session, feature flags, etc.).
    ///   If you need per-call decisions, put that logic inside the interceptor itself.
    ///
    /// - Parameters:
    ///   - predicate: A `@Sendable` closure evaluated per RPC. Return `true` to intercept.
    @available(gRPCSwift 2.2, *)
    public static func allMatching(
      _ predicate: @Sendable @escaping (_ descriptor: MethodDescriptor) -> Bool
    ) -> Self {
      Self(predicate: predicate)
    }

    @usableFromInline
    package func applies(to descriptor: MethodDescriptor) -> Bool {
      self.predicate(descriptor)
    }
  }

  /// The interceptor.
  public let interceptor: Interceptor

  @usableFromInline
  internal let subject: Subject

  fileprivate init(interceptor: Interceptor, subject: Subject) {
    self.interceptor = interceptor
    self.subject = subject
  }

  /// Returns whether this ``ClientInterceptorPipelineOperation`` applies to the given `descriptor`.
  /// - Parameter descriptor: A ``MethodDescriptor`` for which to test whether this interceptor applies.
  /// - Returns: `true` if this interceptor applies to the given `descriptor`, or `false` otherwise.
  @inlinable
  internal func applies(to descriptor: MethodDescriptor) -> Bool {
    self.subject.applies(to: descriptor)
  }
}

@available(gRPCSwift 2.0, *)
extension ConditionalInterceptor where Interceptor == any ClientInterceptor {
  /// Create an operation, specifying which ``ClientInterceptor`` to apply and to which ``Subject``.
  /// - Parameters:
  ///   - interceptor: The ``ClientInterceptor`` to register with the client.
  ///   - subject: The ``Subject`` to which the `interceptor` applies.
  public static func apply(
    _ interceptor: any ClientInterceptor,
    to subject: Subject
  ) -> Self {
    Self(interceptor: interceptor, subject: subject)
  }
}

@available(gRPCSwift 2.0, *)
extension ConditionalInterceptor where Interceptor == any ServerInterceptor {
  /// Create an operation, specifying which ``ServerInterceptor`` to apply and to which ``Subject``.
  /// - Parameters:
  ///   - interceptor: The ``ServerInterceptor`` to register with the server.
  ///   - subject: The ``Subject`` to which the `interceptor` applies.
  public static func apply(
    _ interceptor: any ServerInterceptor,
    to subject: Subject
  ) -> Self {
    Self(interceptor: interceptor, subject: subject)
  }
}
