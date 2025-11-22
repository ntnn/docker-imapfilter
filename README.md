# imapfilter

Docker image to run imapfilter as a daemon: [ntnn/imapfilter](https://hub.docker.com/r/ntnn/imapfilter)

Can also be used to access an up-to-date imapfilter docker image:

```bash
> docker run -it --rm --entrypoint imapfilter ntnn/imapfilter -V
IMAPFilter 2.8.1  Copyright (c) 2001-2023 Eleftherios Chatzimparmpas
```

The intended way to use this image is to have your imapfilter
configuration in a git repo, which will then be pulled in the
entrypoint.

## Image tags

The repository builds two versions of the image:

1. The `latest`/`main` tagged version, which is always build from the
   main branches of both [lefcha/imapfilter][imapfilter] and this
   repository.

2. The `latest-tag`/`vX.Y.Z` tagged version, which is always build from
   the main branch of this repository and the latest tag of the
   [lefcha/imapfilter][imapfilter] repository.

## Examples

See the examples in the `examples` directory.

The `imapfilter-config` directory contains an example imapfilter
configuration.

The `docker-stack` directory contains an arguably dated example for
a docker stack or docker-compose deployment.

The `k8s` directory contains an example for a kubernetes deployment.
This is largely based on the git-based example from the `docker-stack`
directory.

## Environment variables

### imapfilter

#### `IMAPFILTER_CONFIG` and `IMAPFILTER_CONFIG_BASE`

`IMAPFILTER_CONFIG` is the path of the imapfilter config relative to
`IMAPFILTER_CONFIG_BASE`.

E.g. if the imapfilter config is called `config.lua` and the directory
is mounted into the container at `/configs`:

```bash
IMAPFILTER_CONFIG=config.lua
IMAPFILTER_CONFIG_BASE=/configs
```

In a git-based setup `IMAPFILTER_CONFIG_BASE` is not needed. In this
case `IMAPFILTER_CONFIG` must be relative to the root of the git repo.

> [!WARNING]
> When using multiple config files use relative imports, otherwise the
> imports will break in the container.

Defaults:

```bash
IMAPFILTER_CONFIG_BASE=/opts/imapfilter/config
IMAPFILTER_CONFIG=
```

#### `IMAPFILTER_DAEMON` and `IMAPFILTER_SLEEP`

If `IMAPFILTER_DAEMON` is set to `yes`, docker-imapfilter expects the
configuration to enter idle mode. See the example configuration on how
to accomplish this.

If `IMAPFILTER_DAEMON` is not set to `yes`, the entrypoint will run in
a loop, sleeping for `IMAPFILTER_SLEEP` seconds between runs of
imapfilter.

Defaults:

```bash
IMAPFILTER_DAEMON=
IMAPFILTER_SLEEP=30
```

#### `IMAPFILTER_LOGFILE`

If `IMAPFILTER_LOGFILE` is set, imapfilter will write its log output
to the specified file instead of standard output.

Default:

```bash
IMAPFILTER_LOGFILE=
```

### git

To use a git-based configuration configure at least `GIT_TARGET` to the
endpoint of your git repository.

E.g. if your git repository is at `https://my.git.com/user/repo.git`, set:

```bash
GIT_TARGET=httsp://my.git.com/user/repo
# (the .git suffix is optional)
```

To authenticate set `GIT_USER` if your git server requires a username
for your method of authentication.

The password to authenticate with can be either set in a file pointed to
by `GIT_TOKEN`, or directly in the `GIT_TOKEN_RAW` variable.

Note that git server authentication methods vary between the different
providers. See your git provider's documentation for details.

Generally if you use token-based authentication set:

```bash
GIT_TOKEN_RAW=your-access-token
GIT_TARGET=my.git.com/user/repo
```

If you use username/password-based authentication set:

```bash
GIT_USER=your-username
GIT_TOKEN_RAW=your-password
GIT_TARGET=my.git.com/user/repo
```

Substitute `GIT_TOKEN_RAW` with `GIT_TOKEN` if you want to read the
token from a file.

[imapfilter]: https://github.com/lefcha/imapfilter
