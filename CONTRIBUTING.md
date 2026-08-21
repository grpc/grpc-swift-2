# How to contribute

We definitely welcome patches and contributions to grpc-swift! Please read the gRPC
organization's [governance rules](https://github.com/grpc/grpc-community/blob/main/governance.md)
and [contribution guidelines](https://github.com/grpc/grpc-community/blob/main/CONTRIBUTING.md) before proceeding.

Here are some guidelines and information about how to participate.

## Getting started

### Legal requirements

In order to protect both you and ourselves, you will need to sign the
[Contributor License Agreement](https://identity.linuxfoundation.org/projects/cncf).

### Technical requirements

Please see the [main gRPC repository](https://github.com/grpc/grpc) for
more information about gRPC.

### Run CI checks locally

You can run the GitHub Actions workflows locally using [act](https://github.com/nektos/act) or, in some cases, calling scripts directly. For detailed steps on how to do this, please see [https://github.com/swiftlang/github-workflows?tab=readme-ov-file#running-workflows-locally](https://github.com/swiftlang/github-workflows?tab=readme-ov-file#running-workflows-locally).

## AI tools

Human discourse is an essential part of open source development. To encourage
productive collaboration between contributors and maintainers, please refrain
from using AI tools for the following:

- Issues: titles, bodies, and comments.
- Pull requests: titles, descriptions, and comments.

Contributors who feel more comfortable writing in another language may use
automated translation tools, but must include their original content in their
preferred language.

## Contributing a pull request

> [!IMPORTANT]
> To ensure productive use of contributor and maintainer time and resources,
> contributors must first agree their proposed change with a maintainer in an
> issue. Pull requests opened without prior discussion may be closed without
> review.

If there is no issue already tracking the problem or feature request, please
file a new one using your own voice (see "AI tools" usage above).

Once an issue is assigned to you, follow these steps:

- Prepare your change, keeping in mind that a good patch is:
  - Concise, and contains as few changes as needed to achieve the end result.
  - Tested, ensuring that any tests provided failed before the patch and pass
    after it.
  - Documented, adding API documentation as needed to cover new functions and
    properties.
  - Accompanied by a great commit message.
- Open a pull request and wait for code review by the maintainers.
