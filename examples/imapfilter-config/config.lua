-- Do not automatically create mailboxes - prevents typos from creating
-- unwanted mailboxes.
options.create = false

-- Automatically subscribe to newly created mailboxes.
options.subscribe = true

-- This allows :enter_idle to wake up from any event, not just
-- new mail, e.g. when setting a flag on a message.
-- options.wakeonany = true

-- A function to filter spam.
function spam(account, mbox)
    -- Setting a default mailbox if none is provided.
    if mbox == nil then mbox = "INBOX" end

    -- Explicitly creating the Spam mailbox if it does not exist.
    account:create_mailbox('Spam')

    -- Gathering a number of messages, X-Spam_bar is usually set by
    -- spamassassin.
    result = account[mbox]:contain_field('X-Spam_bar', '++++') +
       account[mbox]:contain_field('X-Spam_bar', '+++') +
       account[mbox]:contain_field('X-Spam_bar', '++') +
       account[mbox]:contain_field('X-Spam_bar', '+')
    -- Moving the gathered messages to the Spam mailbox.
    result:move_messages(account['Spam'])
end

-- A function to archive old emails.
function archive(account, mbox)
    if mbox == nil then mbox = "INBOX" end
    account:create_mailbox("Archive")
    -- Moving messages older than 365 days to the Archive mailbox.
    account[mbox]:is_older(365):move_messages(account["Archive"])
end

-- The configuration for the email account.
account = IMAP {
    -- The values here are for a test imap server running in docker,
    -- adjust according to your email provider.
    server = 'imapmemserver',
    port = 143,
    username = 'user',
    -- Instead of hardcoding the password should be provided in a secure way.
    -- e.g. setting it as an environment variable and reading it here:
    -- password = os.getenv('IMAPFILTER_PASS'),
    password= 'user',
    -- ssl should be set to 'auto' (or better 'tls1.3') to
    -- ensure a secure connection. The test setup however doesn't have
    -- TLS so it is disabled.
}

if os.getenv('IMAPFILTER_DAEMON') == 'yes' then
    -- docker-imapfilter supports daemon mode. If in daemon mode the
    -- imapfilter lua script is run once, expecting it to enter idle.
    -- The script then periodically checks for updates to the
    -- configuration and restarts the script if any changes are
    -- detected.
    --
    -- Daemon mode is generally better as it keeps the imap connection
    -- alive and responds faster to new mail.
    while true do
        spam(account)
        archive(account)
        account["INBOX"]:enter_idle()
    end
else
    -- The non-daemon mode simply runs the filtering once. In this case
    -- the docker-imapfilter script loops by itself, waiting
    -- IMAPFILTER_SLEEP seconds between runs.
    spam(account)
    archive(account)
end
