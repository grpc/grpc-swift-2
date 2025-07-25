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

import XCTest

@testable import GRPCCore

@available(gRPCSwift 2.0, *)
final class ServerRPCExecutorTests: XCTestCase {
  func testEchoNoMessages() async throws {
    let harness = ServerRPCExecutorTestHarness()
    try await harness.execute(handler: .echo) { inbound in
      try await inbound.write(.metadata(["foo": "bar"]))
      await inbound.finish()
    } consumer: { outbound in
      let parts = try await outbound.collect()
      XCTAssertEqual(
        parts,
        [
          .metadata(["foo": "bar"]),
          .status(.ok, [:]),
        ]
      )
    }
  }

  func testEchoSingleMessage() async throws {
    let harness = ServerRPCExecutorTestHarness()
    try await harness.execute(handler: .echo) { inbound in
      try await inbound.write(.metadata(["foo": "bar"]))
      try await inbound.write(.message([0]))
      await inbound.finish()
    } consumer: { outbound in
      let parts = try await outbound.collect()
      XCTAssertEqual(
        parts,
        [
          .metadata(["foo": "bar"]),
          .message([0]),
          .status(.ok, [:]),
        ]
      )
    }
  }

  func testEchoMultipleMessages() async throws {
    let harness = ServerRPCExecutorTestHarness()
    try await harness.execute(handler: .echo) { inbound in
      try await inbound.write(.metadata(["foo": "bar"]))
      try await inbound.write(.message([0]))
      try await inbound.write(.message([1]))
      try await inbound.write(.message([2]))
      await inbound.finish()
    } consumer: { outbound in
      let parts = try await outbound.collect()
      XCTAssertEqual(
        parts,
        [
          .metadata(["foo": "bar"]),
          .message([0]),
          .message([1]),
          .message([2]),
          .status(.ok, [:]),
        ]
      )
    }
  }

  func testEchoSingleJSONMessage() async throws {
    let harness = ServerRPCExecutorTestHarness()
    try await harness.execute(
      bytes: [UInt8].self,
      deserializer: JSONDeserializer<String>(),
      serializer: JSONSerializer<String>()
    ) { request, _ in
      let messages = try await request.messages.collect()
      XCTAssertEqual(messages, ["hello"])
      return StreamingServerResponse(metadata: request.metadata) { writer in
        try await writer.write("hello")
        return [:]
      }
    } producer: { inbound in
      try await inbound.write(.metadata(["foo": "bar"]))
      try await inbound.write(.message(Array("\"hello\"".utf8)))
      await inbound.finish()
    } consumer: { outbound in
      let parts = try await outbound.collect()
      XCTAssertEqual(
        parts,
        [
          .metadata(["foo": "bar"]),
          .message(Array("\"hello\"".utf8)),
          .status(.ok, [:]),
        ]
      )
    }
  }

  func testEchoMultipleJSONMessages() async throws {
    let harness = ServerRPCExecutorTestHarness()
    try await harness.execute(
      bytes: [UInt8].self,
      deserializer: JSONDeserializer<String>(),
      serializer: JSONSerializer<String>()
    ) { request, _ in
      let messages = try await request.messages.collect()
      XCTAssertEqual(messages, ["hello", "world"])
      return StreamingServerResponse(metadata: request.metadata) { writer in
        try await writer.write("hello")
        try await writer.write("world")
        return [:]
      }
    } producer: { inbound in
      try await inbound.write(.metadata(["foo": "bar"]))
      try await inbound.write(.message(Array("\"hello\"".utf8)))
      try await inbound.write(.message(Array("\"world\"".utf8)))
      await inbound.finish()
    } consumer: { outbound in
      let parts = try await outbound.collect()
      XCTAssertEqual(
        parts,
        [
          .metadata(["foo": "bar"]),
          .message(Array("\"hello\"".utf8)),
          .message(Array("\"world\"".utf8)),
          .status(.ok, [:]),
        ]
      )
    }
  }

  func testReturnTrailingMetadata() async throws {
    let harness = ServerRPCExecutorTestHarness()
    try await harness.execute(
      bytes: [UInt8].self,
      deserializer: IdentityDeserializer(),
      serializer: IdentitySerializer()
    ) { request, _ in
      return StreamingServerResponse(metadata: request.metadata) { _ in
        return ["bar": "baz"]
      }
    } producer: { inbound in
      try await inbound.write(.metadata(["foo": "bar"]))
      await inbound.finish()
    } consumer: { outbound in
      let parts = try await outbound.collect()
      XCTAssertEqual(
        parts,
        [
          .metadata(["foo": "bar"]),
          .status(.ok, ["bar": "baz"]),
        ]
      )
    }
  }

  func testEmptyInbound() async throws {
    let harness = ServerRPCExecutorTestHarness()
    try await harness.execute(handler: .echo) { inbound in
      await inbound.finish()
    } consumer: { outbound in
      let part = try await outbound.collect().first
      XCTAssertStatus(part) { status, _ in
        XCTAssertEqual(status.code, .internalError)
      }
    }
  }

  func testInboundStreamMissingMetadata() async throws {
    let harness = ServerRPCExecutorTestHarness()
    try await harness.execute(handler: .echo) { inbound in
      try await inbound.write(.message([0]))
      await inbound.finish()
    } consumer: { outbound in
      let part = try await outbound.collect().first
      XCTAssertStatus(part) { status, _ in
        XCTAssertEqual(status.code, .internalError)
      }
    }
  }

  func testInboundStreamThrows() async throws {
    let harness = ServerRPCExecutorTestHarness()
    try await harness.execute(handler: .echo) { inbound in
      await inbound.finish(throwing: RPCError(code: .aborted, message: ""))
    } consumer: { outbound in
      let part = try await outbound.collect().first
      XCTAssertStatus(part) { status, _ in
        XCTAssertEqual(status.code, .unknown)
      }
    }
  }

  func testHandlerThrowsAnyError() async throws {
    struct SomeError: Error {}
    let harness = ServerRPCExecutorTestHarness()
    try await harness.execute(handler: .throwing(SomeError())) { inbound in
      try await inbound.write(.metadata([:]))
      await inbound.finish()
    } consumer: { outbound in
      let part = try await outbound.collect().first
      XCTAssertStatus(part) { status, _ in
        XCTAssertEqual(status.code, .unknown)
      }
    }
  }

  func testHandlerThrowsRPCError() async throws {
    let error = RPCError(code: .aborted, message: "RPC aborted", metadata: ["foo": "bar"])
    let harness = ServerRPCExecutorTestHarness()
    try await harness.execute(handler: .throwing(error)) { inbound in
      try await inbound.write(.metadata([:]))
      await inbound.finish()
    } consumer: { outbound in
      let part = try await outbound.collect().first
      XCTAssertStatus(part) { status, metadata in
        XCTAssertEqual(status.code, .aborted)
        XCTAssertEqual(status.message, "RPC aborted")
        XCTAssertEqual(metadata, ["foo": "bar"])
      }
    }
  }

  func testHandlerRespectsTimeout() async throws {
    let harness = ServerRPCExecutorTestHarness()
    try await harness.execute(
      bytes: [UInt8].self,
      deserializer: IdentityDeserializer(),
      serializer: IdentitySerializer()
    ) { request, context in
      try await context.cancellation.cancelled
      throw RPCError(code: .cancelled, message: "Cancelled from server handler")
    } producer: { inbound in
      try await inbound.write(.metadata(["grpc-timeout": "1000n"]))
      await inbound.finish()
    } consumer: { outbound in
      let part = try await outbound.collect().first
      XCTAssertStatus(part) { status, _ in
        XCTAssertEqual(status.code, .cancelled)
        XCTAssertEqual(status.message, "Cancelled from server handler")
      }
    }
  }

  func testShortCircuitInterceptor() async throws {
    let error = RPCError(
      code: .unauthenticated,
      message: "Unauthenticated",
      metadata: ["foo": "bar"]
    )

    // The interceptor skips the handler altogether.
    let harness = ServerRPCExecutorTestHarness(interceptors: [.rejectAll(with: error)])
    try await harness.execute(
      bytes: [UInt8].self,
      deserializer: IdentityDeserializer(),
      serializer: IdentitySerializer()
    ) { request, _ in
      XCTFail("Unexpected request")
      return StreamingServerResponse(
        of: [UInt8].self,
        error: RPCError(code: .failedPrecondition, message: "")
      )
    } producer: { inbound in
      try await inbound.write(.metadata([:]))
      await inbound.finish()
    } consumer: { outbound in
      let part = try await outbound.collect().first
      XCTAssertStatus(part) { status, metadata in
        XCTAssertEqual(status.code, .unauthenticated)
        XCTAssertEqual(status.message, "Unauthenticated")
        XCTAssertEqual(metadata, ["foo": "bar"])
      }
    }
  }

  func testMultipleInterceptorsAreCalled() async throws {
    let counter1 = AtomicCounter()
    let counter2 = AtomicCounter()

    // The interceptor skips the handler altogether.
    let harness = ServerRPCExecutorTestHarness(
      interceptors: [
        .requestCounter(counter1),
        .requestCounter(counter2),
      ]
    )

    try await harness.execute(handler: .echo) { inbound in
      try await inbound.write(.metadata([:]))
      await inbound.finish()
    } consumer: { outbound in
      let parts = try await outbound.collect()
      XCTAssertEqual(parts, [.metadata([:]), .status(.ok, [:])])
    }

    XCTAssertEqual(counter1.value, 1)
    XCTAssertEqual(counter2.value, 1)
  }

  func testInterceptorsAreCalledInOrder() async throws {
    let counter1 = AtomicCounter()
    let counter2 = AtomicCounter()

    // The interceptor skips the handler altogether.
    let harness = ServerRPCExecutorTestHarness(
      interceptors: [
        .requestCounter(counter1),
        .rejectAll(with: RPCError(code: .unavailable, message: "")),
        .requestCounter(counter2),
      ]
    )

    try await harness.execute(handler: .echo) { inbound in
      try await inbound.write(.metadata([:]))
      await inbound.finish()
    } consumer: { outbound in
      let parts = try await outbound.collect()
      XCTAssertEqual(parts, [.status(Status(code: .unavailable, message: ""), [:])])
    }

    XCTAssertEqual(counter1.value, 1)
    // Zero because the RPC should've been rejected by the second interceptor.
    XCTAssertEqual(counter2.value, 0)
  }

  func testThrowingInterceptor() async throws {
    let harness = ServerRPCExecutorTestHarness(
      interceptors: [
        .throwError(RPCError(code: .unavailable, message: "Unavailable"))
      ]
    )

    try await harness.execute(handler: .echo) { inbound in
      try await inbound.write(.metadata([:]))
      await inbound.finish()
    } consumer: { outbound in
      let parts = try await outbound.collect()
      XCTAssertEqual(parts, [.status(Status(code: .unavailable, message: "Unavailable"), [:])])
    }
  }

  func testErrorConversion() async throws {
    struct CustomError: RPCErrorConvertible, Error {
      var rpcErrorCode: RPCError.Code { .alreadyExists }
      var rpcErrorMessage: String { "foobar" }
      var rpcErrorMetadata: Metadata { ["error": "yes"] }
    }

    let harness = ServerRPCExecutorTestHarness()
    try await harness.execute(handler: .throwing(CustomError())) { inbound in
      try await inbound.write(.metadata(["foo": "bar"]))
      try await inbound.write(.message([0]))
      await inbound.finish()
    } consumer: { outbound in
      let parts = try await outbound.collect()
      XCTAssertEqual(
        parts,
        [
          .status(Status(code: .alreadyExists, message: "foobar"), ["error": "yes"])
        ]
      )
    }
  }

  func testInterceptorErrorConversion() async throws {
    struct CustomError: RPCErrorConvertible, Error {
      var rpcErrorCode: RPCError.Code { .alreadyExists }
      var rpcErrorMessage: String { "foobar" }
      var rpcErrorMetadata: Metadata { ["error": "yes"] }
    }

    let harness = ServerRPCExecutorTestHarness(interceptors: [.throwError(CustomError())])
    try await harness.execute(handler: .throwing(CustomError())) { inbound in
      try await inbound.write(.metadata(["foo": "bar"]))
      await inbound.finish()
    } consumer: { outbound in
      let parts = try await outbound.collect()
      let status = Status(code: .alreadyExists, message: "foobar")
      let metadata: Metadata = ["error": "yes"]
      XCTAssertEqual(parts, [.status(status, metadata)])
    }
  }

  func testInterceptorProducerErrorConversion() async throws {
    struct CustomError: RPCErrorConvertible, Error {
      var rpcErrorCode: RPCError.Code { .alreadyExists }
      var rpcErrorMessage: String { "foobar" }
      var rpcErrorMetadata: Metadata { ["error": "yes"] }
    }

    let harness = ServerRPCExecutorTestHarness(
      interceptors: [.throwInProducer(CustomError())]
    )
    try await harness.execute(handler: .echo) { inbound in
      try await inbound.write(.metadata(["foo": "bar"]))
      try await inbound.write(.message([0]))
    } consumer: { outbound in
      let parts = try await outbound.collect()
      let status = Status(code: .alreadyExists, message: "foobar")
      let metadata: Metadata = ["error": "yes"]
      XCTAssertEqual(parts, [.metadata(["foo": "bar"]), .message([0]), .status(status, metadata)])
    }
  }

  func testInterceptorMessagesErrorConversion() async throws {
    struct CustomError: RPCErrorConvertible, Error {
      var rpcErrorCode: RPCError.Code { .alreadyExists }
      var rpcErrorMessage: String { "foobar" }
      var rpcErrorMetadata: Metadata { ["error": "yes"] }
    }

    let harness = ServerRPCExecutorTestHarness(interceptors: [
      .throwInMessageSequence(CustomError())
    ])
    try await harness.execute(handler: .echo) { inbound in
      try await inbound.write(.metadata(["foo": "bar"]))
      // the sequence throws instantly, this should not arrive
      try await inbound.write(.message([0]))
      await inbound.finish()
    } consumer: { outbound in
      let parts = try await outbound.collect()
      let status = Status(code: .alreadyExists, message: "foobar")
      let metadata: Metadata = ["error": "yes"]
      XCTAssertEqual(parts, [.metadata(["foo": "bar"]), .status(status, metadata)])
    }
  }
}
