ngx.header.content_type = "application/json; charset=UTF-8";
local cjson = require "cjson"
local useful = require "useful"
local redis = require "resty.redis"

local sock = ngx.socket.tcp()
local ngx_log = ngx.log
local re_match = ngx.re.match
local util_dict = ngx.shared.util
local shared_dict = {auto_pins='auto_pins', token_str='token_str'}
local redis_dict = {
    auto_pins='auto_pins',
    pin_aps='pin_aps',
    current_reaver_sh_pid='current_reaver_sh_pid',
    current_reaver_pid='current_reaver_pid',
    current_pin_bssid='current_pin_bssid',
    current_percent='current_percent',
    bssid_info={
        bssid='bssid',
        password='password',
        psk='psk',
        pin='pin',
        essid='essid'
    }
}

local red = nil
local prefix = 'bssid:'
local pj_prefix = 'already_pj_bssid'

local args = ngx.req.get_uri_args()
local _M = {}

function _M:execute_auto_pins()
    local red = self:get_redis()
    if red then
        --delete result list
        red:del(redis_dict.auto_pins)
    end
    return self:execute("/data/www/pj/lua/auto_reaver/auto_pins.sh &")
end

function _M:get_redis()
    local red = redis:new()
    red:set_timeout(1000)
    local ok, err = red:connect('127.0.0.1', 6379)
    if not ok then
        ngx_log(ngx.ERR, 'not ok')
        return nil
    end
    return red
end

function _M:get_pin_aps()
    local is_executed = util_dict:get(shared_dict.auto_pins)
    if not is_executed then
        local r = self:execute_auto_pins()
        --util_dict:set(shared_dict.auto_pins, '1', 60)
        --ngx_log(ngx.ERR, r);
        self:get_result(0, r)
    else
        self:get_result(10, '正在执行..')
    end
end


function _M:get_output(cache_id, callback_function)
    local line_d = ''
    local read_line = 100
    local errcode = 0
    local all_json = {}
    red = self:get_redis()
    --sock:setkeepalive(1)
    if not red then
        self:get_result(0, err)
        ngx.exit(200)
        return
    end
    for i=0,read_line do
        local line, err = red:lpop(cache_id)
        if line == ngx.null then
            break
        end
        --scan bssid
        if callback_function then
            split_t = callback_function(line)
            if split_t then
                table.insert(all_json, split_t)
            end
        else
            --~ local current_pin_bssid = self:get_value_from_redis(redis_dict.current_pin_bssid)
            --~ local bssid_cache_id = prefix .. current_pin_bssid
--~ 
            --~ --crack pin
            --~ local m, err = re_match(line, 'WPS PIN[^\']*\'(.*)\'')
            --~ if m then
                --~ red:hset(bssid_cache_id, redis_dict.bssid_info.pin, m[1])
                --~ red:hset(bssid_cache_id, 'ctime', ngx.time())
                --~ --ngx_log(ngx.ERR, 'found pin:' .. m[1])
                --~ red:hset(pj_prefix, current_pin_bssid, '')
            --~ end
            --~ local m, err = re_match(line, 'WPA PSK[^\']*\'(.*)\'')
            --~ if m then
                --~ --ngx_log(ngx.ERR, 'found psk:' .. m[1])
                --~ red:hset(bssid_cache_id, redis_dict.bssid_info.psk, m[1])
                --~ red:hset(pj_prefix, current_pin_bssid, '')
            --~ end
            --~ 
            local m,err = re_match(line,'([0-9]{1,2}\\.[0-9]{2}%) complete')
            if m then
                red:set(redis_dict.current_percent, m[1])
            end
            table.insert(all_json, line)
        end

        if line == '$exit$' then
            util_dict:delete(cache_id)
            errcode = 1
            break
        end
    end
    return errcode, all_json
end

--store aps info to redis
function _M:store_aps_info(t)
    local red = self:get_redis()
    local cache_id = prefix .. t['bssid']
    local ok = red:exists(cache_id)
    local r = nil
    if 0 == ok then
        red:hset(cache_id, redis_dict.bssid_info.essid, t['essid'])
    else
        return red:hgetall(cache_id)
    end
    return r
end

--get aps out
function _M:get_pin_aps_output()
    local cb_function = function(line)
        local red = _M:get_redis()
        local m, err = re_match(line, '^(?:[0-9A-Z]{2}:){5}')
        if m then
            local t = split(line)
            local ssid = table.concat(t, '', 6)
            local new_t = {
                bssid=t[1],
                channel=t[2],
                rssi=t[3],
                wps_version=t[4],
                wps_locked=t[5],
                essid=ssid
            }
            local t_store = self:store_aps_info(new_t)
            if t_store then
                new_t = extend_table(new_t, red:array_to_hash(t_store))
            end
            return new_t
        end
        return nil
    end
    local errcode, all_json = self:get_output(redis_dict.auto_pins, cb_function)
    self:get_result(errcode, all_json)
end

function _M:execute(cmd)
    return os.execute(cmd)
end

function _M:get_result(errcode, msg, extra_data)
    if type(msg) == 'table' then
        ngx.say(cjson.encode({errcode=errcode, data_list=msg, extra_data=extra_data}))
    else
        ngx.say(cjson.encode({errcode=errcode, msg=msg, extra_data=extra_data}))
    end
end

function _M:force_stop_pins()
    local pid = util_dict:get(shared_dict.auto_pins)
    self:kill_pid(pid)
end

function _M:kill_pid(pids)
    if pids then
        self:execute('kill -9 ' .. pids)
    end
end

function _M:get_value_from_redis(cache_id)
    local red = self:get_redis()
    if red then
        local res, err = red:get(cache_id)
        if not res then
            return nil
        end
        return res
    end
    return nil
end

function _M:stop_pin_aps()
    local current_reaver_pid = self:get_value_from_redis(redis_dict.current_reaver_pid)
    local current_reaver_sh_pid = self:get_value_from_redis(redis_dict.current_reaver_sh_pid)
    if current_reaver_pid ~= ngx.null then
        self:kill_pid(current_reaver_pid)
    end
    local red = self:get_redis()
    self:get_result(0, '杀死成功.')
end

function _M:foce_pin_aps(mac_addr)
    self:stop_pid_aps()
    self:start_pid_aps(mac_addr)
end

function _M:get_status()
    local status_t = {
        current_reaver_pid = self:get_value_from_redis(redis_dict.current_reaver_pid),
        current_reaver_sh_pid = self:get_value_from_redis(redis_dict.current_reaver_sh_pid),
        auto_pin_pids = util_dict:get(redis_dict.auto_pins)
    }
    return status_t
end

function _M:start_pin_aps(mac_addr)
    local current_reaver_pid = self:get_value_from_redis(redis_dict.current_reaver_pid)
    local current_reaver_sh_pid = self:get_value_from_redis(redis_dict.current_reaver_sh_pid)
    if current_reaver_pid ~= ngx.null and current_reaver_sh_pid ~= ngx.null then
        --current reaver is running
        self:get_result(10, 'current reaver is running')
        return
    end

    local cmd = "/data/www/pj/lua/auto_reaver/auto_reaver.sh '" .. mac_addr .. "' &"
    ngx_log(ngx.ERR, cmd)
    local r = self:execute(cmd)
    local red = self:get_redis()
    red:del(redis_dict.pin_aps)

    self:get_result(0, '执行成功.')
end

function _M:reset_all()
    local status_t = self:get_status()
    local pids_t = {}
    for i,v in pairs(status_t)
    do
        if ngx.null ~= v then
            table.insert(pids_t, v)
        end
    end
    if next(pids_t) ~= nil then
        --kill pids
        self:kill_pid(table.concat(pids_t, ' '))
    end
    --clear pid
    local red = self:get_redis()
    red:del(redis_dict.current_reaver_pid)
    red:del(redis_dict.current_reaver_sh_pid)
    util_dict:delete(shared_dict.auto_pins)
end

function _M:set_token(token_str)
    return util_dict:set(shared_dict.token_str, token_str)
end

function _M:get_token()
    return util_dict:get(shared_dict.token_str)
end

function _M:is_allow_visit(token_str)
    local token = self:get_token()
    return token == token_str or args.i_am_cmd
end

function _M:get_already_pj_info()
    local red = self:get_redis()
    local bssid_arr, err = red:hgetall(pj_prefix)
    local bssid_info = {}
    local info_row = {}
    if bssid_arr then
        local bssid_hash = red:array_to_hash(bssid_arr)
        for bssid,v in pairs(bssid_hash)
        do
            info_row = red:array_to_hash(red:hgetall(prefix .. bssid))
            info_row.bssid = bssid
            table.insert(bssid_info, info_row)
        end
    end
    self:get_result(0, bssid_info)
end

--cmd client api start
function _M:set_ap_info()
    local info_table = {
        psk=args.psk,
        pin=args.pin
    }
    local cache_id = prefix .. args.bssid
    local red = self:get_redis()
    red:hmset(cache_id, info_table)
end

function _M:already_pj_bssid()
    local red = self:get_redis()
    local num, err = red:hexists(pj_prefix, args.bssid)

    if num == 0 then
        ngx.print('fail')
    else
        ngx.print('success')
    end
    --~ if info_table then
        --~ self:get_result(0, 'success')
    --~ else
        --~ self:get_result(1, 'fail')
    --~ end
end

function _M:set_current_pin_bssid()
    local red = self:get_redis()
    red:set(redis_dict.current_pin_bssid, args.bssid)
    self:get_result(0, 'success')
end

function _M:set_pin_psk()
    local red = self:get_redis()
    if args.bssid and args.key and args.value then
        local cache_id = prefix .. args.bssid
        red:hset(pj_prefix, args.bssid, '')
        red:hset(cache_id, args.key, args.value)
        red:hsetnx(cache_id, 'ctime', ngx.time())
    end
    self:get_result(0, 'success')
end

--end cmd client api
if args.act == 'set_token' then
    _M:set_token(args.token_str)
    _M:get_result(0, '设置成功.')
    return
end

local is_allow = _M:is_allow_visit(args.token_str)
if not is_allow then
    _M:get_result(-1, 'token_str过期')
    return
end

if args.act == 'start_get_pin' then
    _M:get_pin_aps()
elseif args.act == 'get_result' then
    _M:get_pin_aps_output()
elseif args.act == 'set_auto_pin_pid' then
    ngx_log(ngx.ERR, args.pid)
    if args.type == 'set' then
        util_dict:set(shared_dict.auto_pins, args.pid, 80)
    end
    --ngx.say('ok');
elseif args.act == 'force_stop_auto_pin' then
    _M:force_stop_pins()
    _M:get_result(0, 'success')
elseif args.act == 'force_auto_pin' then
    _M:force_stop_pins()
    _M:execute_auto_pins()
    _M:get_result(0, '成功')
elseif args.act == 'pin_aps' then
    _M:start_pin_aps(args.mac_addr)
elseif args.act == 'force_pin_aps' then
    _M:force_pin_aps(args.mac_addr)
elseif args.act == 'pin_aps_result' then
    local errcode, alljson = _M:get_output(redis_dict.pin_aps)
    local current_pin_bssid = _M:get_value_from_redis(redis_dict.current_pin_bssid);
    local red = _M:get_redis()
    local cache_id = prefix .. current_pin_bssid
    local essid = red:hget(cache_id, redis_dict.bssid_info.essid)
    if essid == 0 then
        essid = ''
    end
    _M:get_result(errcode, alljson, {
        current_pin_bssid=_M:get_value_from_redis(redis_dict.current_pin_bssid),
        current_percent=_M:get_value_from_redis(redis_dict.current_percent),
        current_pin_essid=essid
    })
elseif args.act == 'stop_pin_aps' then
    _M:stop_pin_aps()
elseif args.act == 'get_status' then
    _M:get_result(0, _M:get_status())
elseif args.act == 'reset_all' then
    _M:reset_all()
    _M:get_result(0, '重置成功')
elseif args.act == 'set_ap_info' then
    _M:set_ap_info()
elseif args.act == 'already_pj_bssid' then
    _M:already_pj_bssid()
elseif args.act == 'set_current_pin_bssid' then
    _M:set_current_pin_bssid()
elseif args.act == 'get_already_pj_info' then
    _M:get_already_pj_info()
elseif args.act == 'set_pin_psk' then
    _M:set_pin_psk()
else
    _M:get_result(0, '')
end
