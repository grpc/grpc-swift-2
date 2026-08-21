# Service Lifecycle

This example demonstrates gRPC Swift’s integration with Swift Service Lifecycle,
which the gRPC Swift Extras package provides.

## Overview

A `service-lifecycle` command line tool that uses generated stubs for a
`Greeter` service, which starts an in-process client and server orchestrated
using Swift Service Lifecycle. The client makes requests against the server,
which periodically changes its greeting.

## Usage

Build and run the server using the CLI:

```console
$ swift run service-lifecycle
Здравствуйте, request-1!
नमस्ते, request-2!
你好, request-3!
Bonjour, request-4!
Olá, request-5!
Hola, request-6!
Hello, request-7!
Hello, request-8!
नमस्ते, request-9!
Hello, request-10!
```
