ngx.header.content_type = "application/json; charset=UTF-8";
local redis = require "resty.redis"

local line = '[+] 5.44% complete @ 2014-05-15 12:06:56 (10 seconds/pin)'

local m,err = ngx.re.match(line,'([0-9]\\.[0-9]{2}%) complete')

ngx.print(m[0])
ngx.print(m[1])

--~ 
--~ for i,v in pairs(m)
--~ do
    --~ ngx.print(i,v)
--~ end

--~ local red = redis:new()
--~ red:set_timeout(1000)
--~ local ok, err = red:connect('127.0.0.1', 6379)
--~ if not ok then
    --~ ngx_log(ngx.ERR, 'not ok')
--~ end
--~ local m, err = red:hgetall('bssid:A8:57:4E:B8:4A:BA')
--~ local h_m = red:array_to_hash(m)
--~ 
--~ for i,v in pairs(h_m)
--~ do
    --~ ngx.print(i,v, "\n")
--~ end
