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

/// A description of a method on a service.
@available(gRPCSwift 2.0, *)
public struct MethodDescriptor: Sendable, Hashable {
  /// A description of the service, including its package name.
  public var service: ServiceDescriptor

  /// The name of the method in the service, excluding the service name.
  public var method: String

  /// The fully qualified method name in the format "package.service/method".
  ///
  /// For example, the fully qualified name of the "SayHello" method of the "Greeter" service in
  /// "helloworld" package is "helloworld.Greeter/SayHelllo".
  public var fullyQualifiedMethod: String {
    "\(self.service)/\(self.method)"
  }

  /// The streaming type of the RPC.
  ///
  /// This will be `nil` if the type is unknown. Versions 2.3.0 and later of this package will
  /// set this value in generated code.
  @available(gRPCSwift 2.3, *)
  public var type: RPCType?

  @available(gRPCSwift 2.3, *)
  @frozen
  public enum RPCType: Hashable, Sendable, CaseIterable {
    /// An RPC with one request and one response message.
    case unary
    /// An RPC where the client streams request messages and the server replies with one response
    /// message.
    case clientStreaming
    /// An RPC where the client sends one request message and the server replies with a stream of
    /// response messages.
    case serverStreaming
    /// An RPC where client and server may send each other a stream of messages.
    case bidirectionalStreaming

    /// Whether the RPC streams request messages.
    public var isRequestStreaming: Bool {
      switch self {
      case .clientStreaming, .bidirectionalStreaming:
        return true
      case .unary, .serverStreaming:
        return false
      }
    }

    /// Whether the RPC streams response messages.
    public var isResponseStreaming: Bool {
      switch self {
      case .serverStreaming, .bidirectionalStreaming:
        return true
      case .unary, .clientStreaming:
        return false
      }
    }
  }

  /// Creates a new method descriptor.
  ///
  /// - Parameters:
  ///   - service: The name of the service, including the package name. For example,
  ///       "helloworld.Greeter".
  ///   - method: The name of the method. For example, "SayHello".
  public init(service: ServiceDescriptor, method: String) {
    self.init(service: service, method: method, type: nil)
  }

  /// Creates a new method descriptor.
  ///
  /// - Parameters:
  ///   - service: The name of the service, including the package name. For example,
  ///       "helloworld.Greeter".
  ///   - method: The name of the method. For example, "SayHello".
  ///   - type: The type of the RPC, or `nil` if it isn't known.
  @available(gRPCSwift 2.3, *)
  public init(service: ServiceDescriptor, method: String, type: RPCType?) {
    self.service = service
    self.method = method
    self.type = type
  }

  /// Creates a new method descriptor.
  ///
  /// - Parameters:
  ///   - fullyQualifiedService: The fully qualified name of the service, including the package
  ///       name. For example, "helloworld.Greeter".
  ///   - method: The name of the method. For example, "SayHello".
  public init(fullyQualifiedService: String, method: String) {
    self.init(fullyQualifiedService: fullyQualifiedService, method: method, type: nil)
  }

  /// Creates a new method descriptor.
  ///
  /// - Parameters:
  ///   - fullyQualifiedService: The fully qualified name of the service, including the package
  ///       name. For example, "helloworld.Greeter".
  ///   - method: The name of the method. For example, "SayHello".
  ///   - type: The type of the RPC, or `nil` if it isn't known.
  @available(gRPCSwift 2.3, *)
  public init(fullyQualifiedService: String, method: String, type: RPCType?) {
    self.service = ServiceDescriptor(fullyQualifiedService: fullyQualifiedService)
    self.method = method
    self.type = type
  }
}

@available(gRPCSwift 2.0, *)
extension MethodDescriptor: CustomStringConvertible {
  public var description: String {
    self.fullyQualifiedMethod
  }
}
