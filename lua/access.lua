local auth = require "auth"
if ngx.var.cookie_uid == nil or ngx.var.cookie_token == nil or
    ngx.var.cookie_username == nil then return ngx.exit(403) end

if not auth.identify(ngx.var.cookie_uid, ngx.var.cookie_token) then
    return ngx.exit(403)
end
