# Server API

Types for creating and running a gRPC server and handling RPCs.

## Topics

### Entry points

- ``GRPCServer``
- ``withGRPCServer(transport:services:interceptors:isolation:handleServer:)``
- ``withGRPCServer(transport:services:interceptorPipeline:isolation:handleServer:)``
- ``ServerTransport``
- ``GRPCServerContext``
- ``ServerInterceptor``
- ``ServerContext``

### Service definition and routing

- ``RegistrableRPCService``
- ``RPCRouter``

### Requests and responses

- ``ServerRequest``
- ``StreamingServerRequest``
- ``ServerResponse``
- ``StreamingServerResponse``

### Cancellation

- ``withServerContextRPCCancellationHandle(_:)``
- ``withRPCCancellationHandler(operation:onCancelRPC:)``

### Status and metadata

- ``Status``
- ``Metadata``

### RPC descriptors

- ``MethodDescriptor``
- ``ServiceDescriptor``
