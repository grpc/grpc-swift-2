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

/// An identifier for a logical client RPC.
@available(gRPCSwift 2.5, *)
public struct GRPCClientCallID: Hashable, Sendable, CustomStringConvertible {
  /// The process-local numeric value of this identifier.
  public var rawValue: UInt64

  /// Creates a call identifier from its process-local numeric value.
  public init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  public var description: String {
    String(self.rawValue)
  }
}

/// An identifier for one physical attempt of a logical client RPC.
@available(gRPCSwift 2.5, *)
public struct GRPCClientAttemptID: Hashable, Sendable, CustomStringConvertible {
  /// The logical call containing this attempt.
  public var callID: GRPCClientCallID

  /// The one-based attempt number within the logical call.
  public var attempt: Int

  /// Creates an attempt identifier.
  public init(callID: GRPCClientCallID, attempt: Int) {
    self.callID = callID
    self.attempt = attempt
  }

  public var description: String {
    "\(self.callID).\(self.attempt)"
  }
}

/// A stable, sendable description of an error observed while executing an RPC.
@available(gRPCSwift 2.5, *)
public struct GRPCClientDiagnosticsError: Hashable, Sendable {
  /// The gRPC error code, when the error could be represented as an ``RPCError``.
  public var code: RPCError.Code?

  /// A human-readable description of the error.
  public var message: String

  /// Metadata attached to an ``RPCError``.
  public var metadata: Metadata

  /// Creates a diagnostics error.
  public init(code: RPCError.Code?, message: String, metadata: Metadata = [:]) {
    self.code = code
    self.message = message
    self.metadata = metadata
  }

  @usableFromInline
  init(_ error: any Error) {
    if let error = error as? RPCError {
      self.init(code: error.code, message: error.message, metadata: error.metadata)
    } else {
      self.init(code: nil, message: String(describing: error))
    }
  }
}

/// The terminal outcome of one physical RPC attempt.
@available(gRPCSwift 2.5, *)
public enum GRPCClientAttemptOutcome: Hashable, Sendable {
  /// The transport produced a final gRPC status and trailing metadata.
  case status(Status, trailingMetadata: Metadata)

  /// The attempt failed before producing a final gRPC status.
  case failed(GRPCClientDiagnosticsError)

  /// The attempt was cancelled before producing a final gRPC status.
  case cancelled
}

/// The terminal outcome of a logical client RPC.
@available(gRPCSwift 2.5, *)
public enum GRPCClientCallOutcome: Hashable, Sendable {
  /// The RPC and the response handler completed.
  case completed

  /// RPC execution or the response handler failed.
  case failed(GRPCClientDiagnosticsError)

  /// The logical RPC was cancelled.
  case cancelled
}

/// A non-message event observed while executing a client RPC.
@available(gRPCSwift 2.5, *)
public enum GRPCClientDiagnosticsEvent: Sendable {
  /// A logical call began after the current observer snapshot was taken.
  case callStarted(callID: GRPCClientCallID, descriptor: MethodDescriptor)

  /// A physical attempt began.
  case attemptStarted(attemptID: GRPCClientAttemptID, descriptor: MethodDescriptor)

  /// The transport created a stream for an attempt.
  case streamCreated(attemptID: GRPCClientAttemptID, context: ClientContext)

  /// Request metadata was accepted by the transport writer.
  case requestMetadata(attemptID: GRPCClientAttemptID, metadata: Metadata)

  /// The client half-closed its request stream.
  case requestFinished(attemptID: GRPCClientAttemptID)

  /// Initial response metadata was received from the transport.
  case responseMetadata(attemptID: GRPCClientAttemptID, metadata: Metadata)

  /// The final status and trailing response metadata were received.
  case responseStatus(
    attemptID: GRPCClientAttemptID,
    status: Status,
    trailingMetadata: Metadata
  )

  /// A physical attempt ended. This event is emitted exactly once for each started attempt.
  case attemptFinished(attemptID: GRPCClientAttemptID, outcome: GRPCClientAttemptOutcome)

  /// A logical call ended. This event is emitted exactly once for each started call.
  case callFinished(callID: GRPCClientCallID, outcome: GRPCClientCallOutcome)
}

/// The direction of a serialized message observed by client diagnostics.
@available(gRPCSwift 2.5, *)
public enum GRPCClientDiagnosticsMessageDirection: String, Hashable, Sendable {
  /// A message sent by the client.
  case outbound

  /// A message received by the client.
  case inbound
}

/// Context associated with a serialized request or response message.
@available(gRPCSwift 2.5, *)
public struct GRPCClientDiagnosticsMessageContext: Hashable, Sendable {
  /// The attempt which sent or received this message.
  public var attemptID: GRPCClientAttemptID

  /// The message direction.
  public var direction: GRPCClientDiagnosticsMessageDirection

  /// The zero-based sequence number for this direction within the attempt.
  public var sequenceNumber: Int

  /// Creates message context.
  public init(
    attemptID: GRPCClientAttemptID,
    direction: GRPCClientDiagnosticsMessageDirection,
    sequenceNumber: Int
  ) {
    self.attemptID = attemptID
    self.direction = direction
    self.sequenceNumber = sequenceNumber
  }
}

/// An observer of process-wide client RPC diagnostics.
///
/// Callbacks run synchronously on RPC execution tasks. Implementations should return quickly and
/// move expensive processing to their own executor. Message bytes are borrowed and are only valid
/// for the duration of ``observe(message:context:)``; copy them during the callback if needed.
@available(gRPCSwift 2.5, *)
public protocol GRPCClientDiagnosticsObserver: AnyObject, Sendable {
  /// Observe a non-message lifecycle event.
  func observe(_ event: GRPCClientDiagnosticsEvent)

  /// Observe serialized message bytes before they enter or after they leave the transport.
  func observe<Bytes: GRPCContiguousBytes>(
    message: borrowing Bytes,
    context: GRPCClientDiagnosticsMessageContext
  )
}

@available(gRPCSwift 2.5, *)
extension GRPCClientDiagnosticsObserver {
  public func observe(_ event: GRPCClientDiagnosticsEvent) {}

  public func observe<Bytes: GRPCContiguousBytes>(
    message: borrowing Bytes,
    context: GRPCClientDiagnosticsMessageContext
  ) {}
}

/// A registration in the process-wide client diagnostics registry.
@available(gRPCSwift 2.5, *)
public final class GRPCClientDiagnosticsRegistration: Sendable {
  private let isCancelled: Mutex<Bool>
  private let cancellation: @Sendable () -> Void

  fileprivate init(cancellation: @escaping @Sendable () -> Void) {
    self.isCancelled = Mutex(false)
    self.cancellation = cancellation
  }

  /// Stop including the observer in snapshots for new logical calls.
  ///
  /// Calls which already captured the observer continue to deliver their remaining events.
  public func cancel() {
    let shouldCancel = self.isCancelled.withLock { isCancelled in
      if isCancelled {
        return false
      } else {
        isCancelled = true
        return true
      }
    }

    if shouldCancel {
      self.cancellation()
    }
  }

  deinit {
    self.cancel()
  }
}

/// Process-wide registration point for client RPC diagnostics observers.
///
/// Observers receive metadata and serialized message contents from every client RPC which starts
/// while they are registered. Only register trusted observers and avoid enabling payload capture
/// in environments where that data must not be exposed to another component in the process.
@available(gRPCSwift 2.5, *)
public enum GRPCClientDiagnostics {
  private struct State: Sendable {
    var nextRegistrationID: UInt64 = 0
    var nextCallID: UInt64 = 0
    var observers: [UInt64: any GRPCClientDiagnosticsObserver] = [:]
  }

  private static let state = Mutex(State())
  private static let hasObservers = Atomic(false)

  /// Register an observer for logical calls which start after this method returns.
  ///
  /// Retain the returned registration for as long as observation should remain active.
  public static func register(
    _ observer: any GRPCClientDiagnosticsObserver
  ) -> GRPCClientDiagnosticsRegistration {
    let registrationID = self.state.withLock { state in
      let registrationID = state.nextRegistrationID
      state.nextRegistrationID &+= 1
      state.observers[registrationID] = observer
      self.hasObservers.store(true, ordering: .releasing)
      return registrationID
    }

    return GRPCClientDiagnosticsRegistration {
      self.state.withLock { state in
        state.observers.removeValue(forKey: registrationID)
        if state.observers.isEmpty {
          self.hasObservers.store(false, ordering: .releasing)
        }
      }
    }
  }

  @usableFromInline
  static func _beginCall(
    descriptor: MethodDescriptor
  ) -> GRPCClientDiagnosticsRecorder? {
    // Keep the disabled path to one atomic load: it is paid by every RPC in the process.
    guard self.hasObservers.load(ordering: .acquiring) else { return nil }

    let snapshot = self.state.withLock {
      state -> (
        GRPCClientCallID,
        [any GRPCClientDiagnosticsObserver]
      ) in
      let callID = GRPCClientCallID(rawValue: state.nextCallID)
      state.nextCallID &+= 1
      return (callID, Array(state.observers.values))
    }

    guard !snapshot.1.isEmpty else { return nil }
    return GRPCClientDiagnosticsRecorder(
      callID: snapshot.0,
      descriptor: descriptor,
      observers: snapshot.1
    )
  }
}

@available(gRPCSwift 2.5, *)
@usableFromInline
final class GRPCClientDiagnosticsRecorder: Sendable {
  @usableFromInline
  let callID: GRPCClientCallID

  @usableFromInline
  let descriptor: MethodDescriptor

  @usableFromInline
  let observers: [any GRPCClientDiagnosticsObserver]

  private let isFinished: Mutex<Bool>

  @usableFromInline
  init(
    callID: GRPCClientCallID,
    descriptor: MethodDescriptor,
    observers: [any GRPCClientDiagnosticsObserver]
  ) {
    self.callID = callID
    self.descriptor = descriptor
    self.observers = observers
    self.isFinished = Mutex(false)
    self.emit(.callStarted(callID: callID, descriptor: descriptor))
  }

  @usableFromInline
  func beginAttempt(_ attempt: Int) -> GRPCClientAttemptDiagnosticsRecorder {
    let attemptID = GRPCClientAttemptID(callID: self.callID, attempt: attempt)
    self.emit(.attemptStarted(attemptID: attemptID, descriptor: self.descriptor))
    return GRPCClientAttemptDiagnosticsRecorder(attemptID: attemptID, observers: self.observers)
  }

  @usableFromInline
  func finish() {
    self.finish(with: .completed)
  }

  @usableFromInline
  func finish(throwing error: any Error) {
    if error is CancellationError || (error as? RPCError)?.code == .cancelled {
      self.finish(with: .cancelled)
    } else {
      self.finish(with: .failed(GRPCClientDiagnosticsError(error)))
    }
  }

  private func finish(with outcome: GRPCClientCallOutcome) {
    let shouldEmit = self.isFinished.withLock { isFinished in
      if isFinished {
        return false
      } else {
        isFinished = true
        return true
      }
    }

    if shouldEmit {
      self.emit(.callFinished(callID: self.callID, outcome: outcome))
    }
  }

  private func emit(_ event: GRPCClientDiagnosticsEvent) {
    for observer in self.observers {
      observer.observe(event)
    }
  }
}

@available(gRPCSwift 2.5, *)
@usableFromInline
final class GRPCClientAttemptDiagnosticsRecorder: Sendable {
  private struct State: Sendable {
    var nextOutboundSequence = 0
    var nextInboundSequence = 0
    var pendingOutcome: GRPCClientAttemptOutcome?
    var hasResponseStatus = false
    var isFinished = false
  }

  @usableFromInline
  let attemptID: GRPCClientAttemptID

  @usableFromInline
  let observers: [any GRPCClientDiagnosticsObserver]

  private let state: Mutex<State>

  @usableFromInline
  init(
    attemptID: GRPCClientAttemptID,
    observers: [any GRPCClientDiagnosticsObserver]
  ) {
    self.attemptID = attemptID
    self.observers = observers
    self.state = Mutex(State())
  }

  @usableFromInline
  func streamCreated(_ context: ClientContext) {
    self.emit(.streamCreated(attemptID: self.attemptID, context: context))
  }

  @usableFromInline
  func requestMetadata(_ metadata: Metadata) {
    self.emit(.requestMetadata(attemptID: self.attemptID, metadata: metadata))
  }

  @usableFromInline
  func requestMessage<Bytes: GRPCContiguousBytes>(_ bytes: borrowing Bytes) {
    guard let sequence = self.nextSequence(for: .outbound) else { return }
    let context = GRPCClientDiagnosticsMessageContext(
      attemptID: self.attemptID,
      direction: .outbound,
      sequenceNumber: sequence
    )
    for observer in self.observers {
      observer.observe(message: bytes, context: context)
    }
  }

  @usableFromInline
  func requestFinished() {
    self.emit(.requestFinished(attemptID: self.attemptID))
  }

  @usableFromInline
  func responseMetadata(_ metadata: Metadata) {
    self.emit(.responseMetadata(attemptID: self.attemptID, metadata: metadata))
  }

  @usableFromInline
  func responseMessage<Bytes: GRPCContiguousBytes>(_ bytes: borrowing Bytes) {
    guard let sequence = self.nextSequence(for: .inbound) else { return }
    let context = GRPCClientDiagnosticsMessageContext(
      attemptID: self.attemptID,
      direction: .inbound,
      sequenceNumber: sequence
    )
    for observer in self.observers {
      observer.observe(message: bytes, context: context)
    }
  }

  @usableFromInline
  func responseStatus(_ status: Status, trailingMetadata: Metadata) {
    let shouldEmit = self.state.withLock { state in
      guard !state.isFinished && !state.hasResponseStatus else { return false }
      state.hasResponseStatus = true
      state.pendingOutcome = .status(status, trailingMetadata: trailingMetadata)
      return true
    }
    guard shouldEmit else { return }
    self.emit(
      .responseStatus(
        attemptID: self.attemptID,
        status: status,
        trailingMetadata: trailingMetadata
      )
    )
  }

  @usableFromInline
  func recordFailure(_ error: any Error) {
    let outcome: GRPCClientAttemptOutcome
    if error is CancellationError || (error as? RPCError)?.code == .cancelled {
      outcome = .cancelled
    } else {
      outcome = .failed(GRPCClientDiagnosticsError(error))
    }
    self.state.withLock { state in
      if !state.isFinished && state.pendingOutcome == nil {
        state.pendingOutcome = outcome
      }
    }
  }

  @usableFromInline
  func finish(throwing error: any Error) {
    self.recordFailure(error)
    self.finishWithoutStatus()
  }

  @usableFromInline
  func finishWithoutStatus() {
    let outcome = self.state.withLock { state -> GRPCClientAttemptOutcome? in
      if state.isFinished {
        return nil
      } else {
        state.isFinished = true
        return state.pendingOutcome ?? .cancelled
      }
    }
    if let outcome {
      self.emit(.attemptFinished(attemptID: self.attemptID, outcome: outcome))
    }
  }

  private func nextSequence(
    for direction: GRPCClientDiagnosticsMessageDirection
  ) -> Int? {
    self.state.withLock { state in
      guard !state.isFinished else { return nil }
      switch direction {
      case .outbound:
        defer { state.nextOutboundSequence &+= 1 }
        return state.nextOutboundSequence
      case .inbound:
        defer { state.nextInboundSequence &+= 1 }
        return state.nextInboundSequence
      }
    }
  }

  private func emit(_ event: GRPCClientDiagnosticsEvent) {
    for observer in self.observers {
      observer.observe(event)
    }
  }
}
