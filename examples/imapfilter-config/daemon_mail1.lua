-- daemon_email1.lua is only the entrypoint for a container running
-- imapfilter for the email1 account. Every additionaly email acocunt
-- would need its own entry file.
-- This could probably be done with a table storing the email accounts
-- and a lookup from an env variable but for a handful of accounts this
-- is enough.

require "daemon"

daemon(email1)
