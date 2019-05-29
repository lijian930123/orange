local pairs = pairs
local ipairs = ipairs
local ngx_re_sub = ngx.re.sub
local ngx_re_find = ngx.re.find
local string_sub = string.sub
local orange_db = require("orange.store.orange_db")
local judge_util = require("orange.utils.judge")
local extractor_util = require("orange.utils.extractor")
local handle_util = require("orange.utils.handle")
local BasePlugin = require("orange.plugins.base_handler")
local ngx_set_uri_args = ngx.req.set_uri_args
local ngx_decode_args = ngx.decode_args
local cjson = require("cjson")

local function eval(equation)
    if (type(equation) == "string") then
        equation = string.gsub(equation, "${", "")
        equation = string.gsub(equation, "}", "")
        local eval = loadstring("return ngx.var." .. equation);
        if (type(eval) == "function") then
            --setfenv(eval, variables or {});
            return eval();
        end
    end
end

local function delTargetStr(target)
    for w in string.gmatch(target, "%$%{%a+%}") do
        ngx.log(ngx.INFO, "匹配到的值：", w)
        local replaceVal = eval(w)
        if replaceVal then
            target = string.gsub(target, w, replaceVal)
        end
    end
    ngx.log(ngx.INFO, "替换以后的值：", target)
    return target
end

local function filter_rules(sid, plugin, ngx_var_uri)
    local rules = orange_db.get_json(plugin .. ".selector." .. sid .. ".rules")

    if not rules or type(rules) ~= "table" or #rules <= 0 then
        return false
    end

    for i, rule in ipairs(rules) do
        if rule.enable == true then
            -- judge阶段
            local pass = judge_util.judge_rule(rule, "header_filter")

            -- handle阶段
            if pass then
                if selector.handle and selector.handle.log == true then
                    ngx.log(ngx.INFO, "==[HeaderFilter][rule name:", rule.name, "][rule id:", rule.id, ']')
                end
                if rule.source and rule.target then
                    ngx.header[rule.source] = rule.target
                end
                --return true
            end
        end
    end

    return true
end

local HeaderFilterHandler = BasePlugin:extend()
HeaderFilterHandler.PRIORITY = 2000

function HeaderFilterHandler:new(store)
    HeaderFilterHandler.super.new(self, "header-filter-plugin")
    self.store = store
end

function HeaderFilterHandler:header_filter(conf)
    HeaderFilterHandler.super.header_filter(self)

    local enable = orange_db.get("header_filter.enable")
    local meta = orange_db.get_json("header_filter.meta")
    local selectors = orange_db.get_json("header_filter.selectors")
    local ordered_selectors = meta and meta.selectors

    if not enable or enable ~= true or not meta or not ordered_selectors or not selectors then
        return
    end

    local ngx_var_uri = ngx.var.uri
    for i, sid in ipairs(ordered_selectors) do
        local selector = selectors[sid]
        --ngx.log(ngx.INFO, "==[HeaderFilter][START SELECTOR:", sid, ",NAME:",selector.name,']')
        if selector and selector.enable == true then
            local selector_pass
            if selector.type == 0 then -- 全流量选择器
                selector_pass = true
            else
                selector_pass = judge_util.judge_selector(selector, "header_filter") -- selector judge
            end

            if selector_pass then
                if selector.handle and selector.handle.log == true then
                    ngx.log(ngx.INFO, "[HeaderFilter][PASS-SELECTOR:", sid, "] ", ngx_var_uri)
                end

                local stop = filter_rules(sid, "header_filter", ngx_var_uri)
                if stop then -- 不再执行此插件其他逻辑
                    return
                end
            else
                if selector.handle and selector.handle.log == true then
                    ngx.log(ngx.INFO, "[HeaderFilter][NOT-PASS-SELECTOR:", sid, "] ", ngx_var_uri)
                end
            end

            -- if continue or break the loop
            if selector.handle and selector.handle.continue == true then
                -- continue next selector
            else
                break
            end
        end
    end
end

return HeaderFilterHandler
