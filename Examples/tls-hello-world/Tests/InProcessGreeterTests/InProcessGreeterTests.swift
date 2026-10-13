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
import GRPCInProcessTransport
import TLSDemo
import Testing

// Demonstrates testing service business logic entirely in memory: `InProcessTransport` never
// binds to a socket and never negotiates TLS, so this is the right tool when a test cares about
// what a service *does*, not how a real client would reach it over the network.
@Suite("Greeter over the in-process transport")
struct InProcessGreeterTests {
  @Test("sayHello, with no network binding")
  func sayHello() async throws {
    let inProcess = InProcessTransport()

    try await withGRPCServer(transport: inProcess.server, services: [Greeter()]) { server in
      let reply = try await withGRPCClient(transport: inProcess.client) { client in
        let greeter = Helloworld_Greeter.Client(wrapping: client)
        return try await greeter.sayHello(.with { $0.name = "in-process client" })
      }

      #expect(reply.message == "Hello, in-process client! This connection was verified.")
    }
  }
}
