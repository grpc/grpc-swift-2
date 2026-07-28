# Benchmarks

This article discusses benchmarking in `grpc-swift`.

## Overview

Benchmarks for this package are in a separate Swift Package in the `IntegrationTests/Benchmarks`
subdirectory of the repository.

They use the [`package-benchmark`](https://github.com/ordo-one/package-benchmark) plugin.
Benchmarks depend on the [`jemalloc`](https://jemalloc.net) memory allocation library, which is
used by `package-benchmark` to capture memory allocation statistics.

An installation guide can be found in the [Getting Started article](https://swiftpackageindex.com/ordo-one/package-benchmark/documentation/benchmark/gettingstarted)
for `package-benchmark`.

### Running the benchmarks

You can run the benchmarks CLI by going to the `IntegrationTests/Benchmarks` subdirectory
(for example, `cd IntegrationTests/Benchmarks`) and invoking:

```
swift package benchmark
```

Profiling benchmarks, or building them in release mode in Xcode, isn't currently
supported with `jemalloc` enabled. Disable `jemalloc` to do either.

Quit Xcode, then open it from the command line with the `BENCHMARK_DISABLE_JEMALLOC=true`
environment variable set:

```
BENCHMARK_DISABLE_JEMALLOC=true xed .
```

For more information, please refer to `swift package benchmark --help` or the [documentation
of `package-benchmark`](https://swiftpackageindex.com/ordo-one/package-benchmark/documentation/benchmark).
