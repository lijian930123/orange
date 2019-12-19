local tonumber = tonumber
local STAT_LOCK = "STAT_LOCK"
local KEY_START_TIME = "START_TIME"
local KEY_IP_REGION = "IP_REGION"
local status = ngx.shared.ip_region
local status_count = ngx.shared.ip_region_stat

local orange_version = require("orange/version")

local _M = {}

local ip_region = {}

local function Split(szFullString, szSeparator)
    local nFindStartIndex = 1
    local nSplitIndex = 1
    local nSplitArray = {}
    while true do
        local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)
        if not nFindLastIndex then
            nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))
            break
        end
        nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)
        nFindStartIndex = nFindLastIndex + 1
        nSplitIndex = nSplitIndex + 1
    end
    return nSplitArray
end

local function print_r(t)
    local print_r_cache = {}
    local function sub_print_r(t, indent)
        if (print_r_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            print_r_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    if (type(val) == "table") then
                        print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
                        print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(t))
            end
        end
    end

    if (type(t) == "table") then
        print(tostring(t) .. " {")
        sub_print_r(t, "  ")
        print("}")
    else
        sub_print_r(t, "  ")
    end
    print()
end

function _M.init(config)
    ngx.log(ngx.INFO, "ip_regoin init worker")
    if ngx.worker.id() == 0 then
        local ok, err = status:add(STAT_LOCK, true)
        if ok then
            status:set(KEY_START_TIME, ngx.time())
            ngx.log(ngx.INFO, "ip_regoin init worker begin")
            ngx.timer.at(0, function()
                -- 查询ip数据
                local result, err = config.store:query({
                    sql = "SELECT * FROM ip_region WHERE 1=1"
                })

                if not err and result and type(result) == "table" and #result > 0 then
                    for k, v in pairs(result) do
                        local ip_begin = v["ip_begin"]
                        local ip_end = v["ip_end"]
                        local ip_section = { Split(ip_begin, "%."), Split(ip_end, "%.") }
                        local ip_section_province = ip_region[v["region"]] or {}
                        table.insert(ip_section_province, ip_section)
                        ip_region[v["region"]] = ip_section_province
                    end
                    --[[for region, ip_section_province in pairs(ip_region) do
                        for index, ip_section in pairs(ip_section_province) do
                            print(ip_section[1][1] .. "." .. ip_section[1][2] .. "." .. ip_section[1][3] .. "." .. ip_section[1][4] .. "-" .. ip_section[2][1] .. "." .. ip_section[2][2] .. "." .. ip_section[2][3] .. "." .. ip_section[2][4])
                        end
                    end]]
                else
                    ngx.log(ngx.ERR, "[FATAL ERROR]select ip_region failed, please check data")
                    return nil
                end
            end)
        end
    end
end

function _M.log()
    local ngx_var = ngx.var
    local ip = "101.236.1.3"
    local ips = Split(ip, "%.")
    if ip_region then
        for region, ip_section_province in pairs(ip_region) do
            local find = false
            if not find then
                for index, ip_section in pairs(ip_section_province) do
                    if (tonumber(ips[1]) >= tonumber(ip_section[1][1]) and tonumber(ips[1]) <= tonumber(ip_section[2][1])
                        and tonumber(ips[2]) >= tonumber(ip_section[1][2]) and tonumber(ips[2]) <= tonumber(ip_section[2][2])
                        and tonumber(ips[3]) >= tonumber(ip_section[1][3]) and tonumber(ips[3]) <= tonumber(ip_section[2][3])
                        and tonumber(ips[4]) >= tonumber(ip_section[1][4]) and tonumber(ips[4]) <= tonumber(ip_section[2][4])) then
                        ngx.log(ngx.ERR, "ip命中，当前省份", region)
                        local count = status_count:get(region)
                        if count then
                            status_count:incr(region, 1)
                        else
                            status_count:set(region, 1)
                        end
                        find = true
                        break
                    end
                end
            else
                break
            end
        end
    end
end

function _M.stat()
    local keys = status_count:get_keys()
    local result = {}
    for k, v in pairs(keys) do
        result[v] = status_count:get(v)
    end
    return result
end


return _M
