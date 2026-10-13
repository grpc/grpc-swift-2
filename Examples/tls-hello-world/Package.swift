// swift-tools-version:6.1
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

import PackageDescription

let package = Package(
  name: "tls-hello-world",
  platforms: [.macOS(.v15)],
  dependencies: [
    .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.0.0"),
    .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "2.4.0"),
    .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-certificates.git", from: "1.14.0"),
    .package(url: "https://github.com/apple/swift-asn1.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
  ],
  targets: [
    .target(
      name: "TLSDemo",
      dependencies: [
        .product(name: "GRPCCore", package: "grpc-swift-2"),
        .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
        .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
        .product(name: "X509", package: "swift-certificates"),
        .product(name: "SwiftASN1", package: "swift-asn1"),
      ],
      plugins: [
        .plugin(name: "GRPCProtobufGenerator", package: "grpc-swift-protobuf")
      ]
    ),
    .executableTarget(
      name: "tls-hello-world",
      dependencies: [
        .target(name: "TLSDemo"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),
        .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
        .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .testTarget(
      name: "TLSHandshakeTests",
      dependencies: [
        .target(name: "TLSDemo"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),
        .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
      ]
    ),
    .testTarget(
      name: "InProcessGreeterTests",
      dependencies: [
        .target(name: "TLSDemo"),
        .product(name: "GRPCCore", package: "grpc-swift-2"),
        .product(name: "GRPCInProcessTransport", package: "grpc-swift-2"),
      ]
    ),
  ]
)
