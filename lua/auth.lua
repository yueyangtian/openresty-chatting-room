local _M = {secretkey = '123ad$%^&*'}

function _M.identify(uid, token)
    return uid ~= nil and token ~= nil and
               ngx.md5('uid:' .. uid .. '&secretkey:' .. _M.secretkey) == token
end

function _M.msg_identify(msgstr)
    local cjson = require "cjson.safe"
    local msg = cjson.decode(msgstr)

    if msg == nil or msg.username == nil or msg.token == nil or msg.uid == nil or
        msg.text == nil or msg.username == "" then return nil end

    if not _M.identify(msg.uid, msg.token) then return nil end
    return msg
end

function _M.gen_token(uid)
    if uid == nil then return nil end
    return ngx.md5('uid:' .. uid .. '&secretkey:' .. _M.secretkey)
end

return _M
