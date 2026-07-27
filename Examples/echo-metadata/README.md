# Echo-Metadata

This example demonstrates how to interact with `Metadata` on RPCs: how to set and read it on unary 
and streaming requests, as well as how to set and read both initial and trailing metadata on unary 
and streaming responses. This is done using a simple `echo` server and client, and the SwiftNIO-based 
HTTP/2 transport.

## Overview

An `echo-metadata` command line tool that uses generated stubs for the `echo`
service, which allows you to start a server and to make requests against it. 

You can use any of the client’s subcommands (`get`, `collect`, `expand`, and `update`) to send the
provided `message` as both the request’s message and as the value for the `echo-message` key in
the request’s metadata.

The server will then echo back the message and the metadata’s `echo-message` key-value pair sent
by the client. The request’s metadata will be echoed in both the initial and the trailing metadata.

The tool uses the [SwiftNIO](https://github.com/grpc/grpc-swift-nio-transport) HTTP/2 transport.

## Usage

Build and run the server using the CLI:

```console
$ swift run echo-metadata serve
Echo-Metadata listening on [ipv4]127.0.0.1:1234
```

Use the CLI to run the client and make a `get` (unary) request:

```console
$ swift run echo-metadata get --message "hello"
get → metadata: [("echo-message", "hello")]
get → message: hello
get ← initial metadata: [("echo-message", "hello")]
get ← message: hello
get ← trailing metadata: [("echo-message", "hello")]
```

Get help with the CLI by running:

```console
$ swift run echo-metadata --help
```
