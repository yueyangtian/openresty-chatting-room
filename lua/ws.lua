-- simple chat with redis
local server = require "resty.websocket.server"
local redis = require "resty.redis"
local message = require "msg"

-- genarate channel id
local uri = ngx.var.request_uri
local len = string.len(uri)
local channel_id = string.sub(uri, len + 1, -1)
local channel_name = "chat_" .. tostring(channel_id)

-- create connection
local wb, err = server:new{timeout = 10000, max_payload_len = 65535}

-- create success
if not wb then
    ngx.log(ngx.ERR, "failed to new websocket: ", err)
    return ngx.exit(444)
end

-- create msg rate limit
local limit_req = require "resty.limit.req"
local lim, err = limit_req.new("ws_msg_limit_store", tonumber(ngx.var.chatting_room_msg_rate_limit), 0)
if not lim then
    ngx.log(ngx.ERR, "failed to install resty.limit.conn object ", err)
    return ngx.exit(500)
end

local push = function()
    -- --create redis
    local red = redis:new()
    red:set_timeout(5000)
    local ok, err = red:connect(ngx.var.chatting_room_redis_host, ngx.var.chatting_room_redis_port)
    if not ok then
        ngx.log(ngx.ERR, "failed to connect redis: ", err)
        wb:send_close()
        return
    end

    -- sub
    local res, err = red:subscribe(channel_name)
    if not res then
        ngx.log(ngx.ERR, "failed to sub redis: ", err)
        wb:send_close()
        return
    end

    -- loop : read from redis
    while true do
        local res, err = red:read_reply()
        if res then
            local item = res[3]
            local bytes, err = wb:send_text(message.msg_reply(item))
            if not bytes then
                -- better error handling
                ngx.log(ngx.ERR, "failed to send text: ", err)
                return ngx.exit(444)
            end
        end
    end
end

local co = ngx.thread.spawn(push)

-- redis pub client init
local red2 = redis:new()
red2:set_timeout(1000) -- 1 sec
local ok, err = red2:connect(ngx.var.chatting_room_redis_host, ngx.var.chatting_room_redis_port)
if not ok then
    ngx.log(ngx.ERR, "failed to connect redis: ", err)
    return ngx.exit(444)
end

-- main loop
while true do
    -- 获取数据
    local data, typ, err = wb:recv_frame()

    ngx.log(ngx.INFO, "ws recv data ", data, " type ", typ, " err ", err)

    -- 如果连接损坏 退出
    if wb.fatal then
        ngx.log(ngx.ERR, "failed to receive frame: ", err)
        return ngx.exit(444)
    end

    if not data then
        local bytes, err = wb:send_ping()
        if not bytes then
            ngx.log(ngx.ERR, "failed to send ping: ", err)
            return ngx.exit(444)
        end
        -- ngx.log(ngx.ERR, "send ping: ", data)
    elseif typ == "close" then
        break
    elseif typ == "ping" then
        local bytes, err = wb:send_pong()
        if not bytes then
            ngx.log(ngx.ERR, "failed to send pong: ", err)
            return ngx.exit(444)
        end
    elseif typ == "pong" then
        -- ngx.log(ngx.ERR, "client ponged")
    elseif typ == "text" then

        -- msg auth
        local auth = require "auth"
        local msg = auth.msg_identify(data)
        if msg == nil then
            ngx.log(ngx.INFO, "data not auth skip ", data)
            break
        end

        -- msg rate limit
        local delay, err = lim:incoming(msg.username, true)
        if not delay then
            if err == "rejected" then
                wb:send_text(message.msg_too_many_request())
            end
            ngx.log(ngx.ERR, "failed to limit username: ", msg.username)
            goto continue
        end

        -- notify join the channel
        if msg.text == "notify" then
            local res, err = red2:publish(channel_name,
                                          message.msg_join_notify(msg.username))
            if not res then
                ngx.log(ngx.ERR, "failed to publish notify redis: ", err)
                return ngx.exit(444)
            end
            goto continue
        end

        -- send to redis
        local res, err = red2:publish(channel_name, data)
        if not res then
            ngx.log(ngx.ERR, "failed to publish msg redis: ", err)
        end
    end
    ::continue::
end

wb:send_close()
ngx.thread.wait(co)
