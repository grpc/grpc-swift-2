// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: grpc/lookup/v1/rls_config.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

// Copyright 2020 The gRPC Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

/// Extract a key based on a given name (e.g. header name or query parameter
/// name).  The name must match one of the names listed in the "name" field.  If
/// the "required_match" field is true, one of the specified names must be
/// present for the keybuilder to match.
struct Grpc_Lookup_V1_NameMatcher: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// The name that will be used in the RLS key_map to refer to this value.
  /// If required_match is true, you may omit this field or set it to an empty
  /// string, in which case the matcher will require a match, but won't update
  /// the key_map.
  var key: String = String()

  /// Ordered list of names (headers or query parameter names) that can supply
  /// this value; the first one with a non-empty value is used.
  var names: [String] = []

  /// If true, make this extraction required; the key builder will not match
  /// if no value is found.
  var requiredMatch: Bool = false

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

/// A GrpcKeyBuilder applies to a given gRPC service, name, and headers.
struct Grpc_Lookup_V1_GrpcKeyBuilder: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var names: [Grpc_Lookup_V1_GrpcKeyBuilder.Name] = []

  var extraKeys: Grpc_Lookup_V1_GrpcKeyBuilder.ExtraKeys {
    get {return _extraKeys ?? Grpc_Lookup_V1_GrpcKeyBuilder.ExtraKeys()}
    set {_extraKeys = newValue}
  }
  /// Returns true if `extraKeys` has been explicitly set.
  var hasExtraKeys: Bool {return self._extraKeys != nil}
  /// Clears the value of `extraKeys`. Subsequent reads from it will return its default value.
  mutating func clearExtraKeys() {self._extraKeys = nil}

  /// Extract keys from all listed headers.
  /// For gRPC, it is an error to specify "required_match" on the NameMatcher
  /// protos.
  var headers: [Grpc_Lookup_V1_NameMatcher] = []

  /// You can optionally set one or more specific key/value pairs to be added to
  /// the key_map.  This can be useful to identify which builder built the key,
  /// for example if you are suppressing the actual method, but need to
  /// separately cache and request all the matched methods.
  var constantKeys: Dictionary<String,String> = [:]

  var unknownFields = SwiftProtobuf.UnknownStorage()

  /// To match, one of the given Name fields must match; the service and method
  /// fields are specified as fixed strings.  The service name is required and
  /// includes the proto package name.  The method name may be omitted, in
  /// which case any method on the given service is matched.
  struct Name: Sendable {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    var service: String = String()

    var method: String = String()

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
  }

  /// If you wish to include the host, service, or method names as keys in the
  /// generated RouteLookupRequest, specify key names to use in the extra_keys
  /// submessage. If a key name is empty, no key will be set for that value.
  /// If this submessage is specified, the normal host/path fields will be left
  /// unset in the RouteLookupRequest. We are deprecating host/path in the
  /// RouteLookupRequest, so services should migrate to the ExtraKeys approach.
  struct ExtraKeys: Sendable {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    var host: String = String()

    var service: String = String()

    var method: String = String()

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
  }

  init() {}

  fileprivate var _extraKeys: Grpc_Lookup_V1_GrpcKeyBuilder.ExtraKeys? = nil
}

/// An HttpKeyBuilder applies to a given HTTP URL and headers.
///
/// Path and host patterns use the matching syntax from gRPC transcoding to
/// extract named key/value pairs from the path and host components of the URL:
/// https://github.com/googleapis/googleapis/blob/master/google/api/http.proto
///
/// It is invalid to specify the same key name in multiple places in a pattern.
///
/// For a service where the project id can be expressed either as a subdomain or
/// in the path, separate HttpKeyBuilders must be used:
///     host_pattern: 'example.com' path_pattern: '/{id}/{object}/**'
///     host_pattern: '{id}.example.com' path_pattern: '/{object}/**'
/// If the host is exactly 'example.com', the first path segment will be used as
/// the id and the second segment as the object. If the host has a subdomain, the
/// subdomain will be used as the id and the first segment as the object. If
/// neither pattern matches, no keys will be extracted.
struct Grpc_Lookup_V1_HttpKeyBuilder: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// host_pattern is an ordered list of host template patterns for the desired
  /// value.  If any host_pattern values are specified, then at least one must
  /// match, and the last one wins and sets any specified variables.  A host
  /// consists of labels separated by dots. Each label is matched against the
  /// label in the pattern as follows:
  ///   - "*": Matches any single label.
  ///   - "**": Matches zero or more labels (first or last part of host only).
  ///   - "{<name>=...}": One or more label capture, where "..." can be any
  ///      template that does not include a capture.
  ///   - "{<name>}": A single label capture. Identical to {<name>=*}.
  ///
  /// Examples:
  ///   - "example.com": Only applies to the exact host example.com.
  ///   - "*.example.com": Matches subdomains of example.com.
  ///   - "**.example.com": matches example.com, and all levels of subdomains.
  ///   - "{project}.example.com": Extracts the third level subdomain.
  ///   - "{project=**}.example.com": Extracts the third level+ subdomains.
  ///   - "{project=**}": Extracts the entire host.
  var hostPatterns: [String] = []

  /// path_pattern is an ordered list of path template patterns for the desired
  /// value.  If any path_pattern values are specified, then at least one must
  /// match, and the last one wins and sets any specified variables.  A path
  /// consists of segments separated by slashes. Each segment is matched against
  /// the segment in the pattern as follows:
  ///   - "*": Matches any single segment.
  ///   - "**": Matches zero or more segments (first or last part of path only).
  ///   - "{<name>=...}": One or more segment capture, where "..." can be any
  ///      template that does not include a capture.
  ///   - "{<name>}": A single segment capture. Identical to {<name>=*}.
  /// A custom method may also be specified by appending ":" and the custom
  /// method name or "*" to indicate any custom method (including no custom
  /// method).  For example, "/*/projects/{project_id}/**:*" extracts
  /// `{project_id}` for any version, resource and custom method that includes
  /// it.  By default, any custom method will be matched.
  ///
  /// Examples:
  ///   - "/v1/{name=messages/*}": extracts a name like "messages/12345".
  ///   - "/v1/messages/{message_id}": extracts a message_id like "12345".
  ///   - "/v1/users/{user_id}/messages/{message_id}": extracts two key values.
  var pathPatterns: [String] = []

  /// List of query parameter names to try to match.
  /// For example: ["parent", "name", "resource.name"]
  /// We extract all the specified query_parameters (case-sensitively).  If any
  /// are marked as "required_match" and are not present, this keybuilder fails
  /// to match.  If a given parameter appears multiple times (?foo=a&foo=b) we
  /// will report it as a comma-separated string (foo=a,b).
  var queryParameters: [Grpc_Lookup_V1_NameMatcher] = []

  /// List of headers to try to match.
  /// We extract all the specified header values (case-insensitively).  If any
  /// are marked as "required_match" and are not present, this keybuilder fails
  /// to match.  If a given header appears multiple times in the request we will
  /// report it as a comma-separated string, in standard HTTP fashion.
  var headers: [Grpc_Lookup_V1_NameMatcher] = []

  /// You can optionally set one or more specific key/value pairs to be added to
  /// the key_map.  This can be useful to identify which builder built the key,
  /// for example if you are suppressing a lot of information from the URL, but
  /// need to separately cache and request URLs with that content.
  var constantKeys: Dictionary<String,String> = [:]

  /// If specified, the HTTP method/verb will be extracted under this key name.
  var method: String = String()

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

struct Grpc_Lookup_V1_RouteLookupConfig: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// Ordered specifications for constructing keys for HTTP requests.  Last
  /// match wins.  If no HttpKeyBuilder matches, an empty key_map will be sent to
  /// the lookup service; it should likely reply with a global default route
  /// and raise an alert.
  var httpKeybuilders: [Grpc_Lookup_V1_HttpKeyBuilder] = []

  /// Unordered specifications for constructing keys for gRPC requests.  All
  /// GrpcKeyBuilders on this list must have unique "name" fields so that the
  /// client is free to prebuild a hash map keyed by name.  If no GrpcKeyBuilder
  /// matches, an empty key_map will be sent to the lookup service; it should
  /// likely reply with a global default route and raise an alert.
  var grpcKeybuilders: [Grpc_Lookup_V1_GrpcKeyBuilder] = []

  /// The name of the lookup service as a gRPC URI.  Typically, this will be
  /// a subdomain of the target, such as "lookup.datastore.googleapis.com".
  var lookupService: String = String()

  /// Configure a timeout value for lookup service requests.
  /// Defaults to 10 seconds if not specified.
  var lookupServiceTimeout: SwiftProtobuf.Google_Protobuf_Duration {
    get {return _lookupServiceTimeout ?? SwiftProtobuf.Google_Protobuf_Duration()}
    set {_lookupServiceTimeout = newValue}
  }
  /// Returns true if `lookupServiceTimeout` has been explicitly set.
  var hasLookupServiceTimeout: Bool {return self._lookupServiceTimeout != nil}
  /// Clears the value of `lookupServiceTimeout`. Subsequent reads from it will return its default value.
  mutating func clearLookupServiceTimeout() {self._lookupServiceTimeout = nil}

  /// How long are responses valid for (like HTTP Cache-Control).
  /// If omitted or zero, the longest valid cache time is used.
  /// This value is clamped to 5 minutes to avoid unflushable bad responses.
  var maxAge: SwiftProtobuf.Google_Protobuf_Duration {
    get {return _maxAge ?? SwiftProtobuf.Google_Protobuf_Duration()}
    set {_maxAge = newValue}
  }
  /// Returns true if `maxAge` has been explicitly set.
  var hasMaxAge: Bool {return self._maxAge != nil}
  /// Clears the value of `maxAge`. Subsequent reads from it will return its default value.
  mutating func clearMaxAge() {self._maxAge = nil}

  /// After a response has been in the client cache for this amount of time
  /// and is re-requested, start an asynchronous RPC to re-validate it.
  /// This value should be less than max_age by at least the length of a
  /// typical RTT to the Route Lookup Service to fully mask the RTT latency.
  /// If omitted, keys are only re-requested after they have expired.
  var staleAge: SwiftProtobuf.Google_Protobuf_Duration {
    get {return _staleAge ?? SwiftProtobuf.Google_Protobuf_Duration()}
    set {_staleAge = newValue}
  }
  /// Returns true if `staleAge` has been explicitly set.
  var hasStaleAge: Bool {return self._staleAge != nil}
  /// Clears the value of `staleAge`. Subsequent reads from it will return its default value.
  mutating func clearStaleAge() {self._staleAge = nil}

  /// Rough indicator of amount of memory to use for the client cache.  Some of
  /// the data structure overhead is not accounted for, so actual memory consumed
  /// will be somewhat greater than this value.  If this field is omitted or set
  /// to zero, a client default will be used.  The value may be capped to a lower
  /// amount based on client configuration.
  var cacheSizeBytes: Int64 = 0

  /// This is a list of all the possible targets that can be returned by the
  /// lookup service.  If a target not on this list is returned, it will be
  /// treated the same as an unhealthy target.
  var validTargets: [String] = []

  /// This value provides a default target to use if needed.  If set, it will be
  /// used if RLS returns an error, times out, or returns an invalid response.
  /// Note that requests can be routed only to a subdomain of the original
  /// target, e.g. "us_east_1.cloudbigtable.googleapis.com".
  var defaultTarget: String = String()

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _lookupServiceTimeout: SwiftProtobuf.Google_Protobuf_Duration? = nil
  fileprivate var _maxAge: SwiftProtobuf.Google_Protobuf_Duration? = nil
  fileprivate var _staleAge: SwiftProtobuf.Google_Protobuf_Duration? = nil
}

/// RouteLookupClusterSpecifier is used in xDS to represent a cluster specifier
/// plugin for RLS.
struct Grpc_Lookup_V1_RouteLookupClusterSpecifier: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// The RLS config for this cluster specifier plugin instance.
  var routeLookupConfig: Grpc_Lookup_V1_RouteLookupConfig {
    get {return _routeLookupConfig ?? Grpc_Lookup_V1_RouteLookupConfig()}
    set {_routeLookupConfig = newValue}
  }
  /// Returns true if `routeLookupConfig` has been explicitly set.
  var hasRouteLookupConfig: Bool {return self._routeLookupConfig != nil}
  /// Clears the value of `routeLookupConfig`. Subsequent reads from it will return its default value.
  mutating func clearRouteLookupConfig() {self._routeLookupConfig = nil}

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _routeLookupConfig: Grpc_Lookup_V1_RouteLookupConfig? = nil
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "grpc.lookup.v1"

extension Grpc_Lookup_V1_NameMatcher: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".NameMatcher"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "key"),
    2: .same(proto: "names"),
    3: .standard(proto: "required_match"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.key) }()
      case 2: try { try decoder.decodeRepeatedStringField(value: &self.names) }()
      case 3: try { try decoder.decodeSingularBoolField(value: &self.requiredMatch) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.key.isEmpty {
      try visitor.visitSingularStringField(value: self.key, fieldNumber: 1)
    }
    if !self.names.isEmpty {
      try visitor.visitRepeatedStringField(value: self.names, fieldNumber: 2)
    }
    if self.requiredMatch != false {
      try visitor.visitSingularBoolField(value: self.requiredMatch, fieldNumber: 3)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Grpc_Lookup_V1_NameMatcher, rhs: Grpc_Lookup_V1_NameMatcher) -> Bool {
    if lhs.key != rhs.key {return false}
    if lhs.names != rhs.names {return false}
    if lhs.requiredMatch != rhs.requiredMatch {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Grpc_Lookup_V1_GrpcKeyBuilder: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".GrpcKeyBuilder"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "names"),
    3: .standard(proto: "extra_keys"),
    2: .same(proto: "headers"),
    4: .standard(proto: "constant_keys"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeRepeatedMessageField(value: &self.names) }()
      case 2: try { try decoder.decodeRepeatedMessageField(value: &self.headers) }()
      case 3: try { try decoder.decodeSingularMessageField(value: &self._extraKeys) }()
      case 4: try { try decoder.decodeMapField(fieldType: SwiftProtobuf._ProtobufMap<SwiftProtobuf.ProtobufString,SwiftProtobuf.ProtobufString>.self, value: &self.constantKeys) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    if !self.names.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.names, fieldNumber: 1)
    }
    if !self.headers.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.headers, fieldNumber: 2)
    }
    try { if let v = self._extraKeys {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 3)
    } }()
    if !self.constantKeys.isEmpty {
      try visitor.visitMapField(fieldType: SwiftProtobuf._ProtobufMap<SwiftProtobuf.ProtobufString,SwiftProtobuf.ProtobufString>.self, value: self.constantKeys, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Grpc_Lookup_V1_GrpcKeyBuilder, rhs: Grpc_Lookup_V1_GrpcKeyBuilder) -> Bool {
    if lhs.names != rhs.names {return false}
    if lhs._extraKeys != rhs._extraKeys {return false}
    if lhs.headers != rhs.headers {return false}
    if lhs.constantKeys != rhs.constantKeys {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Grpc_Lookup_V1_GrpcKeyBuilder.Name: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = Grpc_Lookup_V1_GrpcKeyBuilder.protoMessageName + ".Name"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "service"),
    2: .same(proto: "method"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.service) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.method) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.service.isEmpty {
      try visitor.visitSingularStringField(value: self.service, fieldNumber: 1)
    }
    if !self.method.isEmpty {
      try visitor.visitSingularStringField(value: self.method, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Grpc_Lookup_V1_GrpcKeyBuilder.Name, rhs: Grpc_Lookup_V1_GrpcKeyBuilder.Name) -> Bool {
    if lhs.service != rhs.service {return false}
    if lhs.method != rhs.method {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Grpc_Lookup_V1_GrpcKeyBuilder.ExtraKeys: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = Grpc_Lookup_V1_GrpcKeyBuilder.protoMessageName + ".ExtraKeys"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "host"),
    2: .same(proto: "service"),
    3: .same(proto: "method"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.host) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.service) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.method) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.host.isEmpty {
      try visitor.visitSingularStringField(value: self.host, fieldNumber: 1)
    }
    if !self.service.isEmpty {
      try visitor.visitSingularStringField(value: self.service, fieldNumber: 2)
    }
    if !self.method.isEmpty {
      try visitor.visitSingularStringField(value: self.method, fieldNumber: 3)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Grpc_Lookup_V1_GrpcKeyBuilder.ExtraKeys, rhs: Grpc_Lookup_V1_GrpcKeyBuilder.ExtraKeys) -> Bool {
    if lhs.host != rhs.host {return false}
    if lhs.service != rhs.service {return false}
    if lhs.method != rhs.method {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Grpc_Lookup_V1_HttpKeyBuilder: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".HttpKeyBuilder"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .standard(proto: "host_patterns"),
    2: .standard(proto: "path_patterns"),
    3: .standard(proto: "query_parameters"),
    4: .same(proto: "headers"),
    5: .standard(proto: "constant_keys"),
    6: .same(proto: "method"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeRepeatedStringField(value: &self.hostPatterns) }()
      case 2: try { try decoder.decodeRepeatedStringField(value: &self.pathPatterns) }()
      case 3: try { try decoder.decodeRepeatedMessageField(value: &self.queryParameters) }()
      case 4: try { try decoder.decodeRepeatedMessageField(value: &self.headers) }()
      case 5: try { try decoder.decodeMapField(fieldType: SwiftProtobuf._ProtobufMap<SwiftProtobuf.ProtobufString,SwiftProtobuf.ProtobufString>.self, value: &self.constantKeys) }()
      case 6: try { try decoder.decodeSingularStringField(value: &self.method) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.hostPatterns.isEmpty {
      try visitor.visitRepeatedStringField(value: self.hostPatterns, fieldNumber: 1)
    }
    if !self.pathPatterns.isEmpty {
      try visitor.visitRepeatedStringField(value: self.pathPatterns, fieldNumber: 2)
    }
    if !self.queryParameters.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.queryParameters, fieldNumber: 3)
    }
    if !self.headers.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.headers, fieldNumber: 4)
    }
    if !self.constantKeys.isEmpty {
      try visitor.visitMapField(fieldType: SwiftProtobuf._ProtobufMap<SwiftProtobuf.ProtobufString,SwiftProtobuf.ProtobufString>.self, value: self.constantKeys, fieldNumber: 5)
    }
    if !self.method.isEmpty {
      try visitor.visitSingularStringField(value: self.method, fieldNumber: 6)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Grpc_Lookup_V1_HttpKeyBuilder, rhs: Grpc_Lookup_V1_HttpKeyBuilder) -> Bool {
    if lhs.hostPatterns != rhs.hostPatterns {return false}
    if lhs.pathPatterns != rhs.pathPatterns {return false}
    if lhs.queryParameters != rhs.queryParameters {return false}
    if lhs.headers != rhs.headers {return false}
    if lhs.constantKeys != rhs.constantKeys {return false}
    if lhs.method != rhs.method {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Grpc_Lookup_V1_RouteLookupConfig: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".RouteLookupConfig"
  static let _protobuf_nameMap = SwiftProtobuf._NameMap(
      reservedNames: ["request_processing_strategy"],
      reservedRanges: [10..<11],
      numberNameMappings: [
        1: .standard(proto: "http_keybuilders"),
        2: .standard(proto: "grpc_keybuilders"),
        3: .standard(proto: "lookup_service"),
        4: .standard(proto: "lookup_service_timeout"),
        5: .standard(proto: "max_age"),
        6: .standard(proto: "stale_age"),
        7: .standard(proto: "cache_size_bytes"),
        8: .standard(proto: "valid_targets"),
        9: .standard(proto: "default_target"),
  ])

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeRepeatedMessageField(value: &self.httpKeybuilders) }()
      case 2: try { try decoder.decodeRepeatedMessageField(value: &self.grpcKeybuilders) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.lookupService) }()
      case 4: try { try decoder.decodeSingularMessageField(value: &self._lookupServiceTimeout) }()
      case 5: try { try decoder.decodeSingularMessageField(value: &self._maxAge) }()
      case 6: try { try decoder.decodeSingularMessageField(value: &self._staleAge) }()
      case 7: try { try decoder.decodeSingularInt64Field(value: &self.cacheSizeBytes) }()
      case 8: try { try decoder.decodeRepeatedStringField(value: &self.validTargets) }()
      case 9: try { try decoder.decodeSingularStringField(value: &self.defaultTarget) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    if !self.httpKeybuilders.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.httpKeybuilders, fieldNumber: 1)
    }
    if !self.grpcKeybuilders.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.grpcKeybuilders, fieldNumber: 2)
    }
    if !self.lookupService.isEmpty {
      try visitor.visitSingularStringField(value: self.lookupService, fieldNumber: 3)
    }
    try { if let v = self._lookupServiceTimeout {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 4)
    } }()
    try { if let v = self._maxAge {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 5)
    } }()
    try { if let v = self._staleAge {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 6)
    } }()
    if self.cacheSizeBytes != 0 {
      try visitor.visitSingularInt64Field(value: self.cacheSizeBytes, fieldNumber: 7)
    }
    if !self.validTargets.isEmpty {
      try visitor.visitRepeatedStringField(value: self.validTargets, fieldNumber: 8)
    }
    if !self.defaultTarget.isEmpty {
      try visitor.visitSingularStringField(value: self.defaultTarget, fieldNumber: 9)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Grpc_Lookup_V1_RouteLookupConfig, rhs: Grpc_Lookup_V1_RouteLookupConfig) -> Bool {
    if lhs.httpKeybuilders != rhs.httpKeybuilders {return false}
    if lhs.grpcKeybuilders != rhs.grpcKeybuilders {return false}
    if lhs.lookupService != rhs.lookupService {return false}
    if lhs._lookupServiceTimeout != rhs._lookupServiceTimeout {return false}
    if lhs._maxAge != rhs._maxAge {return false}
    if lhs._staleAge != rhs._staleAge {return false}
    if lhs.cacheSizeBytes != rhs.cacheSizeBytes {return false}
    if lhs.validTargets != rhs.validTargets {return false}
    if lhs.defaultTarget != rhs.defaultTarget {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Grpc_Lookup_V1_RouteLookupClusterSpecifier: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".RouteLookupClusterSpecifier"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .standard(proto: "route_lookup_config"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularMessageField(value: &self._routeLookupConfig) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    try { if let v = self._routeLookupConfig {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Grpc_Lookup_V1_RouteLookupClusterSpecifier, rhs: Grpc_Lookup_V1_RouteLookupClusterSpecifier) -> Bool {
    if lhs._routeLookupConfig != rhs._routeLookupConfig {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
