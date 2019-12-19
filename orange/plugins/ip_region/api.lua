local stat = require("orange.plugins.ip_region.stat")

local API = {}

API["/ip_stat/status"] = {
    GET = function(store)
	    return function(req, res, next)
		    local stat_result = stat.stat()

		    local result = {
		        success = true,
		        data = stat_result
		    }

		    res:json(result)
		end
	end
}

return API
