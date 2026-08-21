# ``RPCRouter``

## Topics

### Creating a router

- ``init()``

### Registering and removing handlers

- ``registerHandler(forMethod:deserializer:serializer:handler:)``
- ``removeHandler(forMethod:)``
- ``registerInterceptors(pipeline:)``

### Inspecting registered methods

- ``methods``
- ``count``
- ``hasHandler(forMethod:)``
