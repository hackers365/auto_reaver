ngx.header.content_type = "application/json; charset=UTF-8";
local cjson = require "cjson"
local useful = require "useful"
local redis = require "resty.redis"

local sock = ngx.socket.tcp()
local ngx_log = ngx.log
local re_match = ngx.re.match
local util_dict = ngx.shared.util
local shared_dict = {auto_pins='auto_pins'}
local redis_dict = {
    auto_pins='auto_pins', 
    pin_aps='pin_aps', 
    current_reaver_sh_pid='current_reaver_sh_pid', 
    current_reaver_pid='current_reaver_pid',
    current_pin_mac='current_pin_mac'
}
local red = nil

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
    local read_line = 5
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
        --ngx_log(ngx.ERR, line)
        if callback_function then
            table.insert(all_json, callback_function(line))
        else
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

function _M:get_pin_aps_output()
    local cb_function = function(line)
        local m, err = re_match(line, '(?:[0-9A-Z]{2}:){5}')
        if m then
            local t = split(line)
            return t
        end
        return ''
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
    _M:get_result(errcode, alljson, {current_pin_mac=_M:get_value_from_redis(redis_dict.current_pin_mac)})
elseif args.act == 'stop_pin_aps' then
    _M:stop_pin_aps()
elseif args.act == 'get_status' then
    _M:get_result(0, _M:get_status())
elseif args.act == 'reset_all' then
    _M:reset_all()
    _M:get_result(0, '重置成功')
else
    _M:get_result(0, '')
end
