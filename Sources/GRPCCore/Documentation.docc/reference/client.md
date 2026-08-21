# Client API

Types for creating and configuring a gRPC client and making RPCs.

## Topics

### Entry points

- ``GRPCClient``
- ``withGRPCClient(transport:interceptors:isolation:handleClient:)``
- ``withGRPCClient(transport:interceptorPipeline:isolation:handleClient:)``
- ``ClientTransport``
- ``CallOptions``
- ``RetryThrottle``
- ``ClientInterceptor``
- ``ClientContext``

### Requests and responses

- ``ClientRequest``
- ``StreamingClientRequest``
- ``ClientResponse``
- ``StreamingClientResponse``

### Service configuration

- ``ServiceConfig``
- ``MethodConfig``
- ``HedgingPolicy``
- ``RetryPolicy``
- ``RPCExecutionPolicy``

### Status and metadata

- ``Status``
- ``Metadata``

### RPC descriptors

- ``MethodDescriptor``
- ``ServiceDescriptor``
