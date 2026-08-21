# ``Status/Code-swift.struct``

## Topics

### Getting the success code

- ``ok``

### Handling invalid or conflicting requests

- ``invalidArgument``
- ``outOfRange``
- ``notFound``
- ``alreadyExists``
- ``failedPrecondition``

### Handling authorization failures

- ``unauthenticated``
- ``permissionDenied``

### Handling timing and cancellation

- ``deadlineExceeded``
- ``cancelled``

### Handling concurrency and capacity limits

- ``aborted``
- ``resourceExhausted``
- ``unavailable``

### Handling server and protocol errors

- ``unknown``
- ``unimplemented``
- ``internalError``
- ``dataLoss``

### Creating a code

- ``init(_:)``
- ``init(rawValue:)``

### Reading a code

- ``rawValue``
- ``description``
