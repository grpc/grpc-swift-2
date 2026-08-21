# ``GRPCClient``

## Topics

### Creating a client

- ``init(transport:interceptors:)``
- ``init(transport:interceptorPipeline:)``

### Running the client

- ``runConnections()``
- ``beginGracefulShutdown()``

### Making RPCs

- ``unary(request:descriptor:serializer:deserializer:options:onResponse:)``
- ``clientStreaming(request:descriptor:serializer:deserializer:options:onResponse:)``
- ``serverStreaming(request:descriptor:serializer:deserializer:options:onResponse:)``
- ``bidirectionalStreaming(request:descriptor:serializer:deserializer:options:onResponse:)``
