local BasePlugin = require("orange.plugins.base_handler")
local stat = require("orange.plugins.ip_region.stat")

local IpRegionHandler = BasePlugin:extend()

IpRegionHandler.PRIORITY = 1999

function IpRegionHandler:new(store)
    IpRegionHandler.super.new(self, "ip-region-plugin")
    self.store = store
end

function IpRegionHandler:init_worker()
    IpRegionHandler.super.init_worker(self)
    stat.init(self)
end

function IpRegionHandler:log()
    stat.log()
end

return IpRegionHandler
