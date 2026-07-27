# ``GRPCCodeGen``

Transport-agnostic Swift source generation for gRPC services.

## Overview

``GRPCCodeGen`` generates Swift client and server code for RPC services described by a
language-neutral intermediate representation. It builds a structured Swift representation of
the generated code and renders that representation to text; it doesn't itself parse any
interface definition language (IDL), such as Protocol Buffers.

Consumers construct a ``CodeGenerationRequest`` describing the services, methods, and
dependencies parsed from an IDL file, and pass it to ``CodeGenerator/generate(_:)`` to produce
a ``SourceFile`` containing the generated Swift source. For example, `protoc-gen-grpc-swift-2`
in [`grpc-swift-protobuf`](https://github.com/grpc/grpc-swift-protobuf) parses `.proto` files
and uses this module to generate the corresponding Swift source.

``CodeGenerator/generate(_:)`` throws a ``CodeGenError`` if the request is invalid, for
example if a service or method name isn't unique within its scope.

## Topics

### Code generation

- ``CodeGenerator``
- ``CodeGenerator/Config``
- ``CodeGenerator/Config/AccessLevel``
- ``CodeGenerator/Config/AvailabilityAnnotations``
- ``CodeGenerator/Config/AvailabilityAnnotations/Platform``
- ``SourceFile``

### Service descriptors

- ``CodeGenerationRequest``
- ``ServiceDescriptor``
- ``MethodDescriptor``
- ``ServiceName``
- ``MethodName``
- ``Dependency``
- ``Dependency/Item``
- ``Dependency/Item/Kind``
- ``Dependency/PreconcurrencyRequirement``

### Errors

- ``CodeGenError``
- ``CodeGenError/Code``

### Deprecated

- ``SourceGenerator``
- ``Name``
