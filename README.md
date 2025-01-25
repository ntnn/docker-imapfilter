# imapfilter

Docker image to run imapfilter as a daemon: [ntnn/imapfilter](https://hub.docker.com/r/ntnn/imapfilter)

Can also be used to access an up-to-date imapfilter docker image:

```bash
> docker run -it --rm --entrypoint imapfilter ntnn/imapfilter -V
IMAPFilter 2.8.1  Copyright (c) 2001-2023 Eleftherios Chatzimparmpas
```

The best way to use this image is to have your imapfilter configuration
in a git repo.

## Image tags

The repository builds to versions of the image:

1. The `latest`/`main` tagged version, which is always build from the
   main branches of both [lefcha/imapfilter][imapfilter] and this
   repository.

2. The `latest-tag`/`vX.Y.Z` tagged version, which is always build from
   the main branch of this repository and the latest tag of the
   [lefcha/imapfilter][imapfilter].

## Example

This is how it could be run as a stack:

```yaml
---
version: '3.4'

secrets:
  imapfilter-git_token:
    external: true
  # contains the password for the email
  imapfilter-<email>:
    external: true

services:
  <email>:
    image: ntnn/imapfilter
    environment:
      GIT_TARGET: <git uri>
      IMAPFILTER_CONFIG: entry_<email>.lua
      IMAPFILTER_DAEMON: 'yes'
      GIT_USER: <git tool user>
      GIT_TOKEN: /secrets/imapfilter-token
    secrets:
      - source: imapfilter-git_token
        target: /secrets/imapfilter-token
      - source: imapfilter-<email>:
        target: /secrets/imapfilter-<email>
    deploy:
      mode: global
```

The imapfilter config is stored in a repository where `entry_<email>.lua` is
the entry point, which then retrieves the passwords for the email
address.

The filtering is invoked in a function `do_<email>`, which results in
this code running the daemonized imapfilter:

```lua
do_<email>()
while true do
    email.INBOX:enter_idle()
    do_<email>()
end
```

I suggest to use multiple instances for multiple email addresses with
different entrypoints (`IMAPFILTER_CONFIG`).

## Environment variables

| Environment variable | Type | Description |
| --- | --- | --- |
| `GIT_USER` | string | Username for git |
| `GIT_TOKEN` | string | Path to the file containing the secret for the `GIT_USER` |
| `GIT_TOKEN_RAW` | string | The raw `GIT_TOKEN` to use |
| `GIT_TARGET` | string | Git URI for the imapfilter config repo |
| `IMAPFILTER_CONFIG` | string | For git-based configs the entrypoint within the repository, otherwise absolute path to config |
| `IMAPFILTER_CONFIG_BASE` | string | If config is not git-based path to base of mounted config |
| `IMAPFILTER_LOGFILE` | string | Optional; file name and full path to write log files to |
| `IMAPFILTER_DAEMON` | string <yes/no> | If the imapfilter config is daemonized or not |
| `IMAPFILTER_SLEEP` | integer | How many seconds the entrypoint should sleep between checking the git config for updated or run imapfilter |

[imapfilter]: https://github.com/lefcha/imapfilter
