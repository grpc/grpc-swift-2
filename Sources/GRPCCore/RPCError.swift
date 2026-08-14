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

/// An error representing the outcome of an RPC.
///
/// See also ``Status``.
@available(gRPCSwift 2.0, *)
public struct RPCError: Sendable, Hashable, Error {
  /// A code representing the high-level domain of the error.
  public var code: Code

  /// A message providing additional context about the error.
  public var message: String

  /// Metadata associated with the error.
  ///
  /// If a service throws an error that includes metadata, the client receives that metadata;
  /// conversely, an ``RPCError`` that the client receives may include metadata that a service sent.
  ///
  /// Note that clients and servers may synthesise errors which may not include metadata.
  public var metadata: Metadata

  /// The original error that caused this error.
  public var cause: (any Error)?

  /// Creates a new RPC error that accepts any error as its cause.
  ///
  /// If the given `cause` is also an ``RPCError`` sharing the same `code`,
  /// this initializer flattens them into a single error by merging the messages and metadata.
  ///
  /// - Parameters:
  ///   - code: The status code.
  ///   - message: A message providing additional context about the code.
  ///   - metadata: Any metadata to attach to the error.
  ///   - cause: An underlying error that caused this error.
  public init(
    code: Code,
    message: String,
    metadata: Metadata = [:],
    cause: (any Error)? = nil
  ) {
    if let rpcErrorCause = cause as? RPCError {
      self = .init(
        code: code,
        message: message,
        metadata: metadata,
        cause: rpcErrorCause
      )
    } else {
      self.code = code
      self.message = message
      self.metadata = metadata
      self.cause = cause
    }
  }

  /// Creates a new RPC error that accepts another RPC error as its cause.
  ///
  /// If the given `cause` shares the same `code`, this initializer flattens it
  /// into a single error by merging the messages and metadata.
  ///
  /// - Parameters:
  ///   - code: The status code.
  ///   - message: A message providing additional context about the code.
  ///   - metadata: Any metadata to attach to the error.
  ///   - cause: An underlying ``RPCError`` that caused this error.
  public init(
    code: Code,
    message: String,
    metadata: Metadata = [:],
    cause: RPCError
  ) {
    if cause.code == code {
      self.code = code
      self.message = message + " \(cause.message)"
      var mergedMetadata = metadata
      mergedMetadata.add(contentsOf: cause.metadata)
      self.metadata = mergedMetadata
      self.cause = cause.cause
    } else {
      self.code = code
      self.message = message
      self.metadata = metadata
      self.cause = cause
    }
  }

  /// Creates a new RPC error from a status.
  ///
  /// - Parameters:
  ///   - status: The status to convert.
  ///   - metadata: Any metadata to attach to the error.
  ///
  /// Converts from a ``Status``.
  /// Returns `nil` if the provided ``Status`` has code ``Status/Code-swift.struct/ok``.
  public init?(status: Status, metadata: Metadata = [:]) {
    guard let code = Code(status.code) else { return nil }
    self.init(code: code, message: status.message, metadata: metadata)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.code)
    hasher.combine(self.message)
    hasher.combine(self.metadata)
  }

  public static func == (lhs: RPCError, rhs: RPCError) -> Bool {
    return lhs.code == rhs.code && lhs.message == rhs.message && lhs.metadata == rhs.metadata
  }
}

@available(gRPCSwift 2.0, *)
extension RPCError: CustomStringConvertible {
  public var description: String {
    if let cause = self.cause {
      return "\(self.code): \"\(self.message)\" (cause: \"\(cause)\")"
    } else {
      return "\(self.code): \"\(self.message)\""
    }
  }
}

@available(gRPCSwift 2.0, *)
extension RPCError {
  /// A code representing the high-level classification of an error.
  public struct Code: Hashable, Sendable, CustomStringConvertible {
    /// The numeric value of the error code.
    public var rawValue: Int { Int(self.wrapped.rawValue) }

    internal var wrapped: Status.Code.Wrapped
    private init(code: Status.Code.Wrapped) {
      self.wrapped = code
    }

    /// Creates an error code from a status code, if the status wasn't successful.
    ///
    /// - Parameter code: The status code to create this ``RPCError/Code-swift.struct`` from.
    ///
    /// Converts from ``Status/Code-swift.struct``.
    /// Returns `nil` if `code` is ``Status/Code-swift.struct/ok``, since that isn't a valid error.
    public init?(_ code: Status.Code) {
      if code == .ok {
        return nil
      } else {
        self.wrapped = code.wrapped
      }
    }

    public var description: String {
      String(describing: self.wrapped)
    }

    package static let all: [Self] = [
      .cancelled,
      .unknown,
      .invalidArgument,
      .deadlineExceeded,
      .notFound,
      .alreadyExists,
      .permissionDenied,
      .resourceExhausted,
      .failedPrecondition,
      .aborted,
      .outOfRange,
      .unimplemented,
      .internalError,
      .unavailable,
      .dataLoss,
      .unauthenticated,
    ]
  }
}

@available(gRPCSwift 2.0, *)
extension RPCError.Code {
  /// The caller typically cancelled the operation.
  public static let cancelled = Self(code: .cancelled)

  /// Unknown error.
  ///
  /// The system may return this error if a
  /// Status value it received from another address space belongs to an error-space
  /// this address space doesn't know about. The system may also convert errors that
  /// APIs raise without returning enough error information into this error.
  public static let unknown = Self(code: .unknown)

  /// Client specified an invalid argument.
  ///
  /// Note that this differs from
  /// ``failedPrecondition``. ``invalidArgument`` indicates arguments that are
  /// problematic regardless of the state of the system (for example, a malformed file
  /// name).
  public static let invalidArgument = Self(code: .invalidArgument)

  /// Deadline expired before operation could complete.
  ///
  /// For operations that
  /// change the state of the system, this error may occur even if the
  /// operation has completed successfully. For example, the network could delay a
  /// successful response from a server long enough for the deadline to
  /// expire.
  public static let deadlineExceeded = Self(code: .deadlineExceeded)

  /// The server couldn't find the requested entity (for example, a file or directory).
  public static let notFound = Self(code: .notFound)

  /// Some entity that we attempted to create (for example, file or directory) already
  /// exists.
  public static let alreadyExists = Self(code: .alreadyExists)

  /// The caller does not have permission to execute the specified operation.
  ///
  /// Don't use ``permissionDenied`` for rejections caused by exhausting
  /// some resource (use ``resourceExhausted`` instead for those errors).
  /// Don't use ``permissionDenied`` if the caller cannot be identified
  /// (use ``unauthenticated`` instead for those errors).
  public static let permissionDenied = Self(code: .permissionDenied)

  /// Some resource has been exhausted, perhaps a per-user quota, or perhaps the
  /// entire file system is out of space.
  public static let resourceExhausted = Self(code: .resourceExhausted)

  /// The system rejected the operation because it wasn't in a state required for
  /// the operation's execution.
  ///
  /// For example, the directory you want to delete may be
  /// non-empty, or you apply an rmdir operation to a non-directory, etc.
  ///
  /// A litmus test that may help a service implementor in deciding
  /// between ``failedPrecondition``, ``aborted``, and ``unavailable``:
  /// - Use ``unavailable`` if the client can retry just the failing call.
  /// - Use ``aborted`` if the client should retry at a higher-level
  ///   (for example, restarting a read-modify-write sequence).
  /// - Use ``failedPrecondition`` if the client should not retry until
  ///   it has explicitly fixed the system state. For example, if an "rmdir"
  ///   fails because the directory is non-empty, the server should return
  ///   ``failedPrecondition`` since the client should not retry unless
  ///   they have first fixed up the directory by deleting files from it.
  /// - Use ``failedPrecondition`` if the client performs conditional
  ///   REST Get/Update/Delete on a resource and the resource on the
  ///   server does not match the condition. For example, conflicting
  ///   read-modify-write on the same resource.
  public static let failedPrecondition = Self(code: .failedPrecondition)

  /// A concurrency issue, such as sequencer check failures or transaction aborts, typically
  /// aborts the operation.
  ///
  /// See litmus test above for deciding between ``failedPrecondition``, ``aborted``,
  /// and ``unavailable``.
  public static let aborted = Self(code: .aborted)

  /// The client attempted an operation past the valid range.
  ///
  /// For example, seeking or reading
  /// past end of file.
  ///
  /// Unlike ``invalidArgument``, this error indicates a problem that may be fixed
  /// if the system state changes. For example, a 32-bit file system will
  /// generate ``invalidArgument`` if the caller asks it to read at an offset that is not in the
  /// range [0,2^32-1], but it will generate ``outOfRange`` if the caller asks it to read from
  /// an offset past the current file size.
  ///
  /// There is a fair bit of overlap between ``failedPrecondition`` and
  /// ``outOfRange``. We recommend using ``outOfRange`` (the more specific error)
  /// when it applies so that callers who are iterating through a space can
  /// easily look for an ``outOfRange`` error to detect when they are done.
  public static let outOfRange = Self(code: .outOfRange)

  /// The service doesn't implement, support, or enable this operation.
  public static let unimplemented = Self(code: .unimplemented)

  /// Internal errors.
  ///
  /// This means something has broken invariants that the underlying system expects. If you see
  /// one of these errors, something is very broken.
  public static let internalError = Self(code: .internalError)

  /// The service is currently unavailable.
  ///
  /// This is most likely a transient
  /// condition, and retrying with a backoff may correct it.
  ///
  /// See litmus test above for deciding between ``failedPrecondition``, ``aborted``,
  /// and ``unavailable``.
  public static let unavailable = Self(code: .unavailable)

  /// Unrecoverable data loss or corruption.
  public static let dataLoss = Self(code: .dataLoss)

  /// The request does not have valid authentication credentials for the
  /// operation.
  public static let unauthenticated = Self(code: .unauthenticated)
}

/// A value that can be converted to an error.
///
/// Converts to an ``RPCError``.
/// You can conform types to this protocol to have more control over the status codes and
/// error information that a service provides to clients when it throws an error.
@available(gRPCSwift 2.0, *)
public protocol RPCErrorConvertible {
  /// The error code to terminate the RPC with.
  var rpcErrorCode: RPCError.Code { get }

  /// A message providing additional context about the error.
  var rpcErrorMessage: String { get }

  /// Metadata associated with the error.
  ///
  /// If a service throws an error that includes metadata, the client receives that metadata;
  /// conversely, an ``RPCError`` that the client receives may include metadata that a service sent.
  ///
  /// Note that clients and servers may synthesise errors which may not include metadata.
  var rpcErrorMetadata: Metadata { get }

  /// The original error that caused this error.
  var rpcErrorCause: (any Error)? { get }
}

@available(gRPCSwift 2.0, *)
extension RPCErrorConvertible {
  /// Metadata associated with the error.
  ///
  /// If a service throws an error that includes metadata, the client receives that metadata;
  /// conversely, an ``RPCError`` that the client receives may include metadata that a service sent.
  ///
  /// Note that clients and servers may synthesise errors which may not include metadata.
  public var rpcErrorMetadata: Metadata {
    [:]
  }

  /// By default, a value has no original error.
  public var rpcErrorCause: (any Error)? {
    nil
  }
}

@available(gRPCSwift 2.0, *)
extension RPCErrorConvertible where Self: Error {
  /// When a value is itself an error, it serves as its own original error.
  public var rpcErrorCause: (any Error)? {
    self
  }
}

@available(gRPCSwift 2.0, *)
extension RPCError {
  /// Creates a new error by converting the given value.
  public init(_ convertible: some RPCErrorConvertible) {
    self.code = convertible.rpcErrorCode
    self.message = convertible.rpcErrorMessage
    self.metadata = convertible.rpcErrorMetadata
    self.cause = convertible.rpcErrorCause
  }
}

@available(gRPCSwift 2.1, *)
extension RPCError: RPCErrorConvertible {
  public var rpcErrorCode: Code {
    self.code
  }

  public var rpcErrorMessage: String {
    self.message
  }

  public var rpcErrorMetadata: Metadata {
    self.metadata
  }

  public var rpcErrorCause: (any Error)? {
    self.cause
  }
}
