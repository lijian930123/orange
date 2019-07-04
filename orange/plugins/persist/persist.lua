local socket = require("socket")
local status = ngx.shared.status

local KEY_TOTAL_COUNT = "TOTAL_REQUEST_COUNT"
local KEY_TOTAL_SUCCESS_COUNT = "TOTAL_SUCCESS_REQUEST_COUNT"
local KEY_TRAFFIC_READ = "TRAFFIC_READ"
local KEY_TRAFFIC_WRITE = "TRAFFIC_WRITE"
local KEY_TOTAL_REQUEST_TIME = "TOTAL_REQUEST_TIME"

local KEY_REQUEST_2XX = "REQUEST_2XX"
local KEY_REQUEST_3XX = "REQUEST_3XX"
local KEY_REQUEST_4XX = "REQUEST_4XX"
local KEY_REQUEST_5XX = "REQUEST_5XX"


--最后一次落库前数据
local LAST_KEY_TOTAL_COUNT = "LAST_TOTAL_REQUEST_COUNT"
local LAST_KEY_TOTAL_SUCCESS_COUNT = "LAST_TOTAL_SUCCESS_REQUEST_COUNT"
local LAST_KEY_TRAFFIC_READ = "LAST_TRAFFIC_READ"
local LAST_KEY_TRAFFIC_WRITE = "LAST_TRAFFIC_WRITE"
local LAST_KEY_TOTAL_REQUEST_TIME = "LAST_TOTAL_REQUEST_TIME"

local LAST_KEY_REQUEST_2XX = "LAST_REQUEST_2XX"
local LAST_KEY_REQUEST_3XX = "LAST_REQUEST_3XX"
local LAST_KEY_REQUEST_4XX = "LAST_REQUEST_4XX"
local LAST_KEY_REQUEST_5XX = "LAST_REQUEST_5XX"

function toint(x)
    local y = math.ceil(x)
    if y == x then
        return x
    else
        return y - 1
    end
end

local _M = {}

local function setinterval(callback, interval)

    local handler
    handler = function()
        if type(callback) == 'function' then
            callback()
        end

        local ok, err = ngx.timer.at(interval, handler)
        if not ok then
            ngx.log(ngx.ERR, "failed to create the timer: ", err)
            return
        end
    end

    local ok, err = ngx.timer.at(interval, handler)
    if not ok then
        ngx.log(ngx.ERR, "failed to create the timer: ", err)
        return
    end
end

local function write_data(config)

    -- 暂存
    local request_2xx = status:get(KEY_REQUEST_2XX)
    local request_3xx = status:get(KEY_REQUEST_3XX)
    local request_4xx = status:get(KEY_REQUEST_4XX)
    local request_5xx = status:get(KEY_REQUEST_5XX)
    local total_count = status:get(KEY_TOTAL_COUNT)
    local total_success_count = status:get(KEY_TOTAL_SUCCESS_COUNT)
    local traffic_read = status:get(KEY_TRAFFIC_READ)
    local traffic_write = status:get(KEY_TRAFFIC_WRITE)
    local total_request_time = status:get(KEY_TOTAL_REQUEST_TIME)

    local last_request_2xx = status:get(LAST_KEY_REQUEST_2XX) or 0
    local last_request_3xx = status:get(LAST_KEY_REQUEST_3XX) or 0
    local last_request_4xx = status:get(LAST_KEY_REQUEST_4XX) or 0
    local last_request_5xx = status:get(LAST_KEY_REQUEST_5XX) or 0
    local last_total_count = status:get(LAST_KEY_TOTAL_COUNT) or 0
    local last_total_success_count = status:get(LAST_KEY_TOTAL_SUCCESS_COUNT) or 0
    local last_traffic_read = status:get(LAST_KEY_TRAFFIC_READ) or 0
    local last_traffic_write = status:get(LAST_KEY_TRAFFIC_WRITE) or 0
    local last_total_request_time = status:get(LAST_KEY_TOTAL_REQUEST_TIME) or 0

    -- 记录历史
    status:set(LAST_KEY_REQUEST_2XX, request_2xx)
    status:set(LAST_KEY_REQUEST_3XX, request_3xx)
    status:set(LAST_KEY_REQUEST_4XX, request_4xx)
    status:set(LAST_KEY_REQUEST_5XX, request_5xx)
    status:set(LAST_KEY_TOTAL_COUNT, total_count)
    status:set(LAST_KEY_TOTAL_SUCCESS_COUNT, total_success_count)
    status:set(LAST_KEY_TRAFFIC_READ, traffic_read)
    status:set(LAST_KEY_TRAFFIC_WRITE, traffic_write)
    status:set(LAST_KEY_TOTAL_REQUEST_TIME, total_request_time)

    -- 存储统计
    local node_ip = _M.get_ip()

    local now = ngx.now()
    local date_now = os.date('*t', now)
    local min = date_now.min

    local stat_time = string.format('%d-%d-%d %d:%d:00',
        date_now.year, date_now.month, date_now.day, date_now.hour, min)

    local result, err
    local table_name = 'persist_log'

    -- 是否存在
    result, err = config.store:query({
        sql = "SELECT stat_time FROM " .. table_name .. " WHERE stat_time = ? AND ip = ? LIMIT 1",
        params = { stat_time, node_ip }
    })

    if not result or err then
        ngx.log(ngx.ERR, " query has error ", err)
    else

        local params = {
            tonumber(request_2xx - last_request_2xx),
            tonumber(request_3xx - last_request_3xx),
            tonumber(request_4xx - last_request_4xx),
            tonumber(request_5xx - last_request_5xx),
            tonumber(total_count - last_total_count),
            tonumber(total_success_count - last_total_success_count),
            tonumber(traffic_read - last_traffic_read),
            tonumber(traffic_write - last_traffic_write),
            tonumber(total_request_time - last_total_request_time),
            stat_time,
            node_ip
        }

        if result and #result == 1 then
            result, err = config.store:query({
                sql = "UPDATE " .. table_name .. " SET " ..
                    " request_2xx = request_2xx + ?, " ..
                    " request_3xx = request_3xx + ?, " ..
                    " request_4xx = request_4xx + ?, " ..
                    " request_5xx = request_5xx + ?, " ..
                    " total_request_count = total_request_count + ?, " ..
                    " total_success_request_count = total_success_request_count + ?, " ..
                    " traffic_read = traffic_read + ?, " ..
                    " traffic_write = traffic_write + ?, " ..
                    " total_request_time = total_request_time + ? " ..
                    " WHERE stat_time = ? AND ip = ? ",
                params = params,
            })
        else
            result, err = config.store:query({
                sql = "INSERT " .. table_name .. " " ..
                    " (request_2xx, request_3xx, request_4xx, request_5xx, total_request_count, total_success_request_count, traffic_read, traffic_write, total_request_time, stat_time, ip) " ..
                    " VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                params = params
            })
        end

        if not result or err then
            ngx.log(ngx.ERR, " query has error ", err)
        end
    end
end

local function delete_data(config)
    local now = ngx.now()
    local offset = 60 * 60 * 24 * 60
    local date_now = os.date('*t', now - offset)
    local min = date_now.min

    local stat_time = string.format('%d-%d-%d %d:%d:00',
        date_now.year, date_now.month, date_now.day, date_now.hour, min)

    --ngx.log(ngx.ERR, " 删除数据开始时间 ", stat_time)
    local result, err
    local table_name = 'persist_log'

    -- 是否存在
    result, err = config.store:query({
        sql = "DELETE FROM " .. table_name .. " WHERE stat_time < ? ",
        params = { stat_time }
    })

    if not result or err then
        ngx.log(ngx.ERR, " delete history data has error ", err)
    end
end

-- 获取 IP
local function get_ip_by_hostname(hostname)
    local _, resolved = socket.dns.toip(hostname)
    local list_tab = {}
    for _, v in ipairs(resolved.ip) do
        table.insert(list_tab, v)
    end
    return unpack(list_tab)
end

function _M.init(config)
    ngx.log(ngx.INFO, "persist init worker")

    local interval = 60
    -- 一天执行一次删除
    local delete_interval = 60 * 60 * 24

    -- 单进程，只执行一次
    if ngx.worker.id() == 0 then

        local date_now = os.date('*t', ngx.time())
        local second = date_now.sec

        if second > 0 then
            -- 矫正统计写入
            ngx.timer.at(interval - 1 - second, function()

                write_data(config)

                -- 定时保存
                setinterval(function()
                    write_data(config)
                end, interval)

                -- 定时删除
                setinterval(function()
                    delete_data(config)
                end, delete_interval)
            end)
        else
            -- 定时保存
            setinterval(function()
                write_data(config)
            end, interval)

            -- 定时删除
            setinterval(function()
                delete_data(config)
            end, delete_interval)
        end
    end
end

function _M.log(config)

end

function _M.get_ip()
    if not _M.ip then
        _M.ip = get_ip_by_hostname(socket.dns.gethostname())
    end
    return _M.ip
end

return _M
