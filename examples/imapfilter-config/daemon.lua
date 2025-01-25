-- daemon.lib contains functions to be used for daemonized imapfilter
-- runs. Useful if all email accounts are to be filtered in the same
-- way.

require "lib"

function apply_rules(account)
    spam(account)
    archive(account)
end

function daemon(account)
    apply_rules(account)
    while true do
        account["INBOX"]:enter_idle()
        apply_rules(account)
    end
end
