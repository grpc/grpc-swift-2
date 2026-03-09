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
import Testing

struct RPCRouterTests {
  @Test
  @available(gRPCSwift 2.0, *)
  func emptyRouter() async throws {
    var router = RPCRouter<NoServerTransport>()
    #expect(router.count == 0)
    #expect(router.methods.isEmpty)
    #expect(
      !router.hasHandler(forMethod: MethodDescriptor(fullyQualifiedService: "foo", method: "bar"))
    )

    let wasRemoved = router.removeHandler(
      forMethod: MethodDescriptor(fullyQualifiedService: "foo", method: "bar")
    )
    #expect(!wasRemoved)
  }

  @Test
  @available(gRPCSwift 2.0, *)
  func registerMethod() async throws {
    var router = RPCRouter<NoServerTransport>()
    let method = MethodDescriptor(fullyQualifiedService: "foo", method: "bar")
    router.registerHandler(
      forMethod: method,
      deserializer: IdentityDeserializer(),
      serializer: IdentitySerializer()
    ) { _, _ in
      throw RPCError(code: .failedPrecondition, message: "Shouldn't be called")
    }

    #expect(router.count == 1)
    #expect(router.methods == [method])
    #expect(router.hasHandler(forMethod: method))
  }

  @Test
  @available(gRPCSwift 2.0, *)
  func hasHandlerIgnoreRPCType() async throws {
    var router = RPCRouter<NoServerTransport>()
    var method = MethodDescriptor(fullyQualifiedService: "foo", method: "bar", type: .unary)
    router.registerHandler(
      forMethod: method,
      deserializer: IdentityDeserializer(),
      serializer: IdentitySerializer()
    ) { _, _ in
      throw RPCError(code: .failedPrecondition, message: "Shouldn't be called")
    }

    #expect(router.count == 1)
    #expect(router.methods == [method])

    #expect(router.hasHandler(forMethod: method))
    method.type = nil
    #expect(router.hasHandler(forMethod: method))
  }

  @Test
  @available(gRPCSwift 2.0, *)
  func removeMethod() async throws {
    var router = RPCRouter<NoServerTransport>()
    let method = MethodDescriptor(fullyQualifiedService: "foo", method: "bar")
    router.registerHandler(
      forMethod: method,
      deserializer: IdentityDeserializer(),
      serializer: IdentitySerializer()
    ) { _, _ in
      throw RPCError(code: .failedPrecondition, message: "Shouldn't be called")
    }

    let wasRemoved = router.removeHandler(forMethod: method)
    #expect(wasRemoved)
    #expect(!router.hasHandler(forMethod: method))
    #expect(router.count == 0)
    #expect(router.methods.isEmpty)
  }
}

@available(gRPCSwift 2.0, *)
struct NoServerTransport: ServerTransport {
  typealias Bytes = [UInt8]

  func listen(
    streamHandler:
      @escaping @Sendable (
        GRPCCore.RPCStream<Inbound, Outbound>,
        GRPCCore.ServerContext
      ) async -> Void
  ) async throws {
  }

  func beginGracefulShutdown() {
  }
}
