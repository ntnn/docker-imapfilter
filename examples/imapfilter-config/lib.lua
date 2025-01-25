-- lib.lua contains common functions and settings for all imapfilter
-- scripts. Only useful if using imapfilter for multiple email accounts
-- or to have one-off scripts to run manually

options.create = false
options.subscribe = true
options.timeout = 120
options.keeplive = 1
options.wakeonany = true

function spam(account, mbox)
    if mbox == nil then mbox = "INBOX" end

    log('Filtering spam ' .. mbox)
    account:create_mailbox('Spam')

    result = account[mbox]:contain_field('X-Spam_bar', '++++') +
       account[mbox]:contain_field('X-Spam_bar', '+++') +
       account[mbox]:contain_field('X-Spam_bar', '++') +
       account[mbox]:contain_field('X-Spam_bar', '+')
    result:move_messages(account['Spam'])
end

function archive(account, mbox)
    if mbox == nil then mbox = "INBOX" end
    log('Archiving ' .. mbox)
    account:create_mailbox("Archive")
    account[mbox]:is_older(365):move_messages(account["Archive"])
end

email1 = IMAP {
    server = 'mail.server.one',
    port = 993,
    username = 'user1',
    password = os.getenv('IMAPFILTER_EMAIL1_PASS'),
    ssl = 'tls1.3',
}
