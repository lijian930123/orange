local ipairs = ipairs
local orange_db = require("orange.store.orange_db")
local stat = require("orange.plugins.global_monitor.stat")
local judge_util = require("orange.utils.judge")
local BasePlugin = require("orange.plugins.base_handler")


local function filter_rules(plugin, ngx_var_uri)
    stat.count(ngx_var_uri)
    return true
end


local GlobalURLMonitorHandler = BasePlugin:extend()
GlobalURLMonitorHandler.PRIORITY = 2000

function GlobalURLMonitorHandler:new(store)
    GlobalURLMonitorHandler.super.new(self, "global-monitor-plugin")
    self.store = store
end

function GlobalURLMonitorHandler:log(conf)
    GlobalURLMonitorHandler.super.log(self)

    local enable = orange_db.get("global_monitor.enable")

    if not enable or enable ~= true then
        return
    end

    local ngx_var_uri = ngx.var.uri
    filter_rules("monitor", ngx_var_uri)

end


return GlobalURLMonitorHandler
