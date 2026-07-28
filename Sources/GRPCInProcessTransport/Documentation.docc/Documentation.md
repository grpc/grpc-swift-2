# ``GRPCInProcessTransport``

This module contains an in-process transport.

## Overview

The in-process transport allows you to run a gRPC client and server within the same process
without using a networking stack. This is great for testing but is also suitable for production
use cases.

## Topics

### Transport pair

- ``InProcessTransport``
- ``InProcessTransport/init(serviceConfig:)``

### Client transport

- ``InProcessTransport/Client``
- ``InProcessTransport/Client/connect()``
- ``InProcessTransport/Client/withStream(descriptor:options:_:)``
- ``InProcessTransport/Client/beginGracefulShutdown()``
- ``InProcessTransport/Client/config(forMethod:)``
- ``InProcessTransport/Client/retryThrottle``

### Server transport

- ``InProcessTransport/Server``
- ``InProcessTransport/Server/listen(streamHandler:)``
- ``InProcessTransport/Server/beginGracefulShutdown()``
