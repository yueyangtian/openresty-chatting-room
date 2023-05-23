local _M = {}
local cjson = require "cjson.safe"
function _M.msg_reply(msgstr)
    local msg = cjson.decode(msgstr)
    msg.token = nil
    msg.uid = nil
    return cjson.encode(msg)
end

function _M.msg_too_many_request()
    local msg = {username = 'system', text = 'too many request'}
    return cjson.encode(msg)
end

function _M.msg_join_notify(user)
    local msg = {username = 'system', text = user .. ' join in channel'}
    return cjson.encode(msg)
end

return _M
