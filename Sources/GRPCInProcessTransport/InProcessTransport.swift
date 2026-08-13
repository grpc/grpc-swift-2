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

public import GRPCCore

@available(gRPCSwift 2.0, *)
public struct InProcessTransport: Sendable {
  /// The server side of this transport pairing.
  ///
  /// Pass this to a `GRPCServer` to accept RPCs that ``client`` makes.
  public let server: Self.Server

  /// The client side of this transport pairing.
  ///
  /// Pass this to a `GRPCClient` to make RPCs that ``server`` handles.
  public let client: Self.Client

  /// Initializes a new ``InProcessTransport`` pairing a ``Client`` and a ``Server``.
  ///
  /// - Parameters:
  ///   - serviceConfig: Configuration describing how to execute methods.
  public init(serviceConfig: ServiceConfig = ServiceConfig()) {
    let peer = System.pid().map { "in-process:\($0)" } ?? "in-process"
    self.server = Self.Server(peer: peer)
    self.client = Self.Client(server: self.server, serviceConfig: serviceConfig, peer: peer)
  }
}
