local cjson = require "cjson.safe"

local http_method = ngx.req.get_method()
local http_bodydata = ngx.req.get_body_data()

local body = cjson.decode(http_bodydata)
local username = body["username"]
local code = 0

if http_method == "POST" and http_bodydata ~= nil and body ~= nil and username ~=
    nil and username ~= "" then
    local auth = require "auth"
    local uid = ngx.time()
    local token = auth.gen_token(uid)
    ngx.header['Set-Cookie'] = {
        "uid=" .. uid, "token=" .. token, "username=" .. username
    }
else
    code = -1
end

ngx.say(cjson.encode({code = code}))

-- ngx.redirect('/ws.html')
