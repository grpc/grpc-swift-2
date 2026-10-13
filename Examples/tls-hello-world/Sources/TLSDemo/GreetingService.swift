/*
 * Copyright 2026, gRPC Authors All rights reserved.
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
import GRPCNIOTransportHTTP2
import X509

package struct Greeter: Helloworld_Greeter.SimpleServiceProtocol {
  package init() {}

  package func sayHello(
    request: Helloworld_HelloRequest,
    context: ServerContext
  ) async throws -> Helloworld_HelloReply {
    guard let identity = Self.verifiedClientIdentity(from: context) else {
      return .with { $0.message = "Hello, \(request.name)! This connection was verified." }
    }

    print("Verified client identity: \(identity)")
    return .with {
      $0.message = "Hello, \(request.name)! Verified client identity: \(identity)."
    }
  }

  /// Reads a SPIFFE-style `uniformResourceIdentifier` SAN off the peer's certificate, if this
  /// is an mTLS connection and the presented client certificate has one.
  private static func verifiedClientIdentity(from context: ServerContext) -> String? {
    guard
      let posixContext = context.transportSpecific as? HTTP2ServerTransport.Posix.Context,
      let peerCertificate = posixContext.peerCertificate,
      let subjectAlternativeNames = try? peerCertificate.extensions.subjectAlternativeNames
    else {
      return nil
    }

    for name in subjectAlternativeNames {
      if case .uniformResourceIdentifier(let uri) = name {
        return uri
      }
    }
    return nil
  }
}
