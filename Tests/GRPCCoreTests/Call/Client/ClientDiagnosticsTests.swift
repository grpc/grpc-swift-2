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

private import Synchronization
import XCTest

@testable import GRPCCore

@available(gRPCSwift 2.0, *)
final class ClientDiagnosticsTests: XCTestCase {
  func testCapturesUnaryLifecycleMetadataAndSerializedMessages() async throws {
    let observer = RecordingClientDiagnosticsObserver()
    let registration = GRPCClientDiagnostics.register(observer)
    defer { registration.cancel() }

    let harness = ClientRPCExecutorTestHarness(server: .echo)
    try await harness.unary(
      request: ClientRequest(message: [1, 2, 3], metadata: ["request": "metadata"])
    ) { response in
      XCTAssertEqual(try response.message, [1, 2, 3])
    }

    let snapshot = observer.snapshot
    XCTAssertEqual(snapshot.messages.count, 2)
    XCTAssertEqual(snapshot.messages[0].direction, .outbound)
    XCTAssertEqual(snapshot.messages[0].sequenceNumber, 0)
    XCTAssertEqual(snapshot.messages[0].bytes, [1, 2, 3])
    XCTAssertEqual(snapshot.messages[1].direction, .inbound)
    XCTAssertEqual(snapshot.messages[1].sequenceNumber, 0)
    XCTAssertEqual(snapshot.messages[1].bytes, [1, 2, 3])

    XCTAssertEqual(snapshot.eventNames.count, 9)
    XCTAssertEqual(
      Array(snapshot.eventNames.prefix(3)),
      [
        "callStarted", "attemptStarted", "streamCreated",
      ]
    )
    XCTAssertEqual(
      Array(snapshot.eventNames.suffix(3)),
      [
        "responseStatus", "attemptFinished", "callFinished",
      ]
    )
    XCTAssertEqual(snapshot.eventNames.filter { $0 == "requestMetadata" }.count, 1)
    XCTAssertEqual(snapshot.eventNames.filter { $0 == "requestFinished" }.count, 1)
    XCTAssertEqual(snapshot.eventNames.filter { $0 == "responseMetadata" }.count, 1)
    XCTAssertEqual(snapshot.attemptsStarted, [1])
    XCTAssertEqual(snapshot.attemptsFinished, [1])
    XCTAssertEqual(snapshot.responseStatusCodes, [.ok])

    let requestMetadata = snapshot.events.compactMap { event -> Metadata? in
      if case .requestMetadata(_, let metadata) = event { return metadata }
      return nil
    }
    XCTAssertEqual(requestMetadata, [["request": "metadata"]])
  }

  func testRetryAttemptsShareCallIDAndHaveDistinctAttemptNumbers() async throws {
    let observer = RecordingClientDiagnosticsObserver()
    let registration = GRPCClientDiagnostics.register(observer)
    defer { registration.cancel() }

    let harness = ClientRPCExecutorTestHarness(
      server: .attemptBased { attempt in
        if attempt < 3 {
          return .reject(
            withError: RPCError(code: .unavailable, message: "retry"),
            consumeInbound: true
          )
        } else {
          return .echo
        }
      }
    )

    let retryPolicy = RetryPolicy(
      maxAttempts: 5,
      initialBackoff: .milliseconds(10),
      maxBackoff: .milliseconds(100),
      backoffMultiplier: 1.6,
      retryableStatusCodes: [.unavailable]
    )
    var options = CallOptions.defaults
    options.executionPolicy = .retry(retryPolicy)

    try await harness.bidirectional(
      request: StreamingClientRequest {
        try await $0.write([42])
      },
      options: options
    ) { response in
      let messages = try await response.messages.collect()
      XCTAssertEqual(messages, [[42]])
    }

    let snapshot = observer.snapshot
    XCTAssertEqual(snapshot.callIDs.count, 1)
    XCTAssertEqual(snapshot.attemptsStarted, [1, 2, 3])
    XCTAssertEqual(snapshot.attemptsFinished.sorted(), [1, 2, 3])
    XCTAssertEqual(snapshot.responseStatusCodes, [.unavailable, .unavailable, .ok])

    let messageAttemptNumbers = snapshot.messages.map { $0.attemptID.attempt }
    XCTAssertEqual(messageAttemptNumbers.filter { $0 == 1 }.count, 1)
    XCTAssertEqual(messageAttemptNumbers.filter { $0 == 2 }.count, 1)
    XCTAssertEqual(messageAttemptNumbers.filter { $0 == 3 }.count, 2)
  }

  func testCapturesBidirectionalStreamingMessageSequences() async throws {
    let observer = RecordingClientDiagnosticsObserver()
    let registration = GRPCClientDiagnostics.register(observer)
    defer { registration.cancel() }

    let harness = ClientRPCExecutorTestHarness(server: .echo)
    try await harness.bidirectional(
      request: StreamingClientRequest {
        try await $0.write([0])
        try await $0.write([1])
        try await $0.write([2])
      }
    ) { response in
      let messages = try await response.messages.collect()
      XCTAssertEqual(messages, [[0], [1], [2]])
    }

    let messages = observer.snapshot.messages
    let outbound = messages.filter { $0.direction == .outbound }
    let inbound = messages.filter { $0.direction == .inbound }
    XCTAssertEqual(outbound.map(\.sequenceNumber), [0, 1, 2])
    XCTAssertEqual(outbound.map(\.bytes), [[0], [1], [2]])
    XCTAssertEqual(inbound.map(\.sequenceNumber), [0, 1, 2])
    XCTAssertEqual(inbound.map(\.bytes), [[0], [1], [2]])
  }

  func testHedgedAttemptsHaveDistinctAttemptNumbersAndTerminalEvents() async throws {
    let observer = RecordingClientDiagnosticsObserver()
    let registration = GRPCClientDiagnostics.register(observer)
    defer { registration.cancel() }

    let harness = ClientRPCExecutorTestHarness(
      server: .attemptBased { attempt in
        if attempt == 3 {
          return .echo
        } else {
          return .sleepFor(
            duration: .seconds(60),
            then: .reject(withError: RPCError(code: .unavailable, message: "hedged"))
          )
        }
      }
    )
    let policy = HedgingPolicy(
      maxAttempts: 3,
      hedgingDelay: .milliseconds(5),
      nonFatalStatusCodes: [.unavailable]
    )
    var options = CallOptions.defaults
    options.executionPolicy = .hedge(policy)

    try await harness.bidirectional(
      request: StreamingClientRequest {
        try await $0.write([7])
      },
      options: options
    ) { response in
      let messages = try await response.messages.collect()
      XCTAssertEqual(messages, [[7]])
    }

    let snapshot = observer.snapshot
    XCTAssertEqual(snapshot.callIDs.count, 1)
    XCTAssertEqual(snapshot.attemptsStarted, [1, 2, 3])
    XCTAssertEqual(snapshot.attemptsFinished.sorted(), [1, 2, 3])
    XCTAssertEqual(snapshot.eventNames.filter { $0 == "attemptFinished" }.count, 3)
    XCTAssertEqual(snapshot.responseStatusCodes, [.ok])
  }

  func testStreamCreationFailureFinishesAttemptAndCallExactlyOnce() async throws {
    let observer = RecordingClientDiagnosticsObserver()
    let registration = GRPCClientDiagnostics.register(observer)
    defer { registration.cancel() }

    let harness = ClientRPCExecutorTestHarness(
      transport: .throwsOnStreamCreation(code: .aborted),
      server: .failTest
    )

    await XCTAssertThrowsRPCErrorAsync {
      try await harness.unary(request: ClientRequest(message: [1])) { _ in }
    } errorHandler: { error in
      XCTAssertEqual(error.code, .aborted)
    }

    let snapshot = observer.snapshot
    XCTAssertEqual(snapshot.attemptsStarted, [1])
    XCTAssertEqual(snapshot.attemptsFinished, [1])
    XCTAssertEqual(snapshot.eventNames.filter { $0 == "callFinished" }.count, 1)

    let attemptOutcomes = snapshot.events.compactMap { event -> GRPCClientAttemptOutcome? in
      if case .attemptFinished(_, let outcome) = event { return outcome }
      return nil
    }
    guard case .failed(let error) = attemptOutcomes.first else {
      return XCTFail("Expected a failed attempt")
    }
    XCTAssertEqual(error.code, .aborted)
  }

  func testCancelledRegistrationDoesNotObserveNewCalls() async throws {
    let observer = RecordingClientDiagnosticsObserver()
    let registration = GRPCClientDiagnostics.register(observer)
    registration.cancel()

    let harness = ClientRPCExecutorTestHarness(server: .echo)
    try await harness.unary(request: ClientRequest(message: [1])) { response in
      XCTAssertEqual(try response.message, [1])
    }

    XCTAssertTrue(observer.snapshot.events.isEmpty)
    XCTAssertTrue(observer.snapshot.messages.isEmpty)
  }
}

@available(gRPCSwift 2.0, *)
private final class RecordingClientDiagnosticsObserver: GRPCClientDiagnosticsObserver, Sendable {
  struct Message: Sendable {
    var attemptID: GRPCClientAttemptID
    var direction: GRPCClientDiagnosticsMessageDirection
    var sequenceNumber: Int
    var bytes: [UInt8]
  }

  struct Snapshot: Sendable {
    var events: [GRPCClientDiagnosticsEvent]
    var messages: [Message]

    var eventNames: [String] {
      self.events.map { event in
        switch event {
        case .callStarted: "callStarted"
        case .attemptStarted: "attemptStarted"
        case .streamCreated: "streamCreated"
        case .requestMetadata: "requestMetadata"
        case .requestFinished: "requestFinished"
        case .responseMetadata: "responseMetadata"
        case .responseStatus: "responseStatus"
        case .attemptFinished: "attemptFinished"
        case .callFinished: "callFinished"
        }
      }
    }

    var callIDs: Set<GRPCClientCallID> {
      Set(
        self.events.compactMap { event in
          switch event {
          case .callStarted(let callID, _), .callFinished(let callID, _):
            callID
          default:
            nil
          }
        }
      )
    }

    var attemptsStarted: [Int] {
      self.events.compactMap { event in
        if case .attemptStarted(let attemptID, _) = event { return attemptID.attempt }
        return nil
      }
    }

    var attemptsFinished: [Int] {
      self.events.compactMap { event in
        if case .attemptFinished(let attemptID, _) = event { return attemptID.attempt }
        return nil
      }
    }

    var responseStatusCodes: [Status.Code] {
      self.events.compactMap { event in
        if case .responseStatus(_, let status, _) = event { return status.code }
        return nil
      }
    }
  }

  private struct State: Sendable {
    var events: [GRPCClientDiagnosticsEvent] = []
    var messages: [Message] = []
  }

  private let state = Mutex(State())

  var snapshot: Snapshot {
    self.state.withLock { state in
      Snapshot(events: state.events, messages: state.messages)
    }
  }

  func observe(_ event: GRPCClientDiagnosticsEvent) {
    self.state.withLock { $0.events.append(event) }
  }

  func observe<Bytes: GRPCContiguousBytes>(
    message: borrowing Bytes,
    context: GRPCClientDiagnosticsMessageContext
  ) {
    let bytes = message.withUnsafeBytes { Array($0) }
    self.state.withLock { state in
      state.messages.append(
        Message(
          attemptID: context.attemptID,
          direction: context.direction,
          sequenceNumber: context.sequenceNumber,
          bytes: bytes
        )
      )
    }
  }
}
