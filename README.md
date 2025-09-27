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
a docker stack.

The `k8s` directory contains an example for a kubernetes deployment.

Both `docker-stack` and `k8s` expect the configuration from
`imapfilter-config`.

## Environment variables

| Environment variable | Type | Description |
| --- | --- | --- |
| `PUID` | string | Process User ID, UID that imapfilter runs as |
| `PGID` | string | Process Group ID, GID that imapfilter runs as |
| `GIT_USER` | string | Username for git |
| `GIT_TOKEN` | string | Path to the file containing the secret for the `GIT_USER` |
| `GIT_TOKEN_RAW` | string | The raw `GIT_TOKEN` to use |
| `GIT_TARGET` | string | Git URI for the imapfilter config repo |
| `IMAPFILTER_CONFIG` | string | The path of the imapfilter config relative to `IMAPFILTER_CONFIG_BASE` |
| `IMAPFILTER_CONFIG_BASE` | string | If config is not git-based path to base of mounted config |
| `IMAPFILTER_LOGFILE` | string | Optional; file name and full path to write log files to |
| `IMAPFILTER_DAEMON` | string <yes/no> | If the imapfilter config is daemonized or not |
| `IMAPFILTER_SLEEP` | integer | How many seconds the entrypoint should sleep between checking the git config for updated or run imapfilter |

[imapfilter]: https://github.com/lefcha/imapfilter
