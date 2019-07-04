local stat = require("orange.plugins.global_monitor.stat")
local BaseAPI = require("orange.plugins.base_api")
local common_api = require("orange.plugins.common_api")
local ipairs = ipairs

local api = BaseAPI:new("global-monitor-api", 2)

api:merge_apis(common_api("global_monitor"))

api:get("/global_monitor/stat", function(store)
    return function(req, res, next)
        local rule_id = req.query.rule_id
        local statistics = stat.get(rule_id)

        res:json({
            success = true,
            data = statistics
        })
    end
end)

api:get("/global_monitor/list", function(store)
    return function(req, res, next)

        local page = req.query.page
        local size = req.query.size
        local order_type = req.query.order_type
        local sort_type = req.query.sort_type
        local rule_id = req.query.rule_id

        local statistics = {}

        local keys = stat:getTable()

        local usefulkeys = {}

        if rule_id then
            for k,v in ipairs(keys) do
                if string.find(v, rule_id) ~= nil then
                    table.insert(usefulkeys, v)
                end
            end
        else
            usefulkeys = keys
        end

        if order_type and sort_type then
            local uriMap = {}

            for k,v in ipairs(usefulkeys) do
                local monitorData = stat.get(v)
                if order_type == "count" then
                    table.insert(uriMap, {uri = v, count = monitorData["total_count"]})
                elseif order_type == "time" then
                    table.insert(uriMap, {uri = v, count = tonumber(monitorData["average_request_time"]) * 1000})
                end
            end

            table.sort(uriMap , function(a , b)
                if sort_type == "up" then
                    return a.count < b.count
                else
                    return a.count > b.count
                end
            end)

            for i in pairs(uriMap) do
                if i > ((page -1) * size)  and i <= (page * size) then
                    local monitorData = stat.get(uriMap[i].uri)
                    local averageRequestTime = string.format("%.3f", tonumber(monitorData["average_request_time"]) * 1000)
                    table.insert(statistics, {uri = uriMap[i].uri, totalCount = monitorData["total_count"], averageRequestTime = averageRequestTime})
                end
            end
        else
            for k,v in ipairs(usefulkeys) do
                if tonumber(k) > ((page -1) * size)  and tonumber(k) <= (page * size) then
                    local monitorData = stat.get(v)
                    local averageRequestTime = string.format("%.3f", tonumber(monitorData["average_request_time"]) * 1000)
                    table.insert(statistics, {uri = v, totalCount = monitorData["total_count"], averageRequestTime = averageRequestTime})
                end
            end
        end

        local totalPage = math.ceil(#usefulkeys / size)

        res:json({
            success = true,
            data = {
                rules = statistics
            },
            totalPage = totalPage
        })
    end
end)

return api
