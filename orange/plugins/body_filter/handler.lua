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
    --ngx.log(ngx.INFO, "替换以后的值：", target)
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
            local pass = judge_util.judge_rule(rule, "body_filter")

            -- handle阶段
            if pass then
                if selector.handle and selector.handle.log == true then
                    ngx.log(ngx.INFO, "==[BodyFilter][rule name:", rule.name, "][rule id:", rule.id, ']')
                    ngx.log(ngx.INFO, "返回值原文：", ngx.arg[1])
                end
                local newContent, n, err = ngx.re.gsub(ngx.arg[1], rule.source, delTargetStr(rule.target))
                if newContent then
                    ngx.arg[1] = newContent
                    if selector.handle and selector.handle.log == true then
                        ngx.log(ngx.INFO, "处理后的返回值：", ngx.arg[1])
                    end
                else
                    ngx.log(ngx.ERR, "正则替换失败：", err)
                end
                --return true
            end
        end
    end

    return true
end

local BodyFilterHandler = BasePlugin:extend()
BodyFilterHandler.PRIORITY = 2000

function BodyFilterHandler:new(store)
    BodyFilterHandler.super.new(self, "body-filter-plugin")
    self.store = store
end

function BodyFilterHandler:body_filter(conf)
    BodyFilterHandler.super.body_filter(self)

    local enable = orange_db.get("body_filter.enable")
    local meta = orange_db.get_json("body_filter.meta")
    local selectors = orange_db.get_json("body_filter.selectors")
    local ordered_selectors = meta and meta.selectors

    if not enable or enable ~= true or not meta or not ordered_selectors or not selectors then
        return
    end

    local ngx_var_uri = ngx.var.uri
    for i, sid in ipairs(ordered_selectors) do
        local selector = selectors[sid]
        --ngx.log(ngx.INFO, "==[BodyFilter][START SELECTOR:", sid, ",NAME:",selector.name,']')
        if selector and selector.enable == true then
            local selector_pass
            if selector.type == 0 then -- 全流量选择器
                selector_pass = true
            else
                selector_pass = judge_util.judge_selector(selector, "body_filter") -- selector judge
            end

            if selector_pass then
                if selector.handle and selector.handle.log == true then
                    ngx.log(ngx.INFO, "[BodyFilter][PASS-SELECTOR:", sid, "] ", ngx_var_uri)
                end

                local stop = filter_rules(sid, "body_filter", ngx_var_uri)
                if stop then -- 不再执行此插件其他逻辑
                    return
                end
            else
                if selector.handle and selector.handle.log == true then
                    ngx.log(ngx.INFO, "[BodyFilter][NOT-PASS-SELECTOR:", sid, "] ", ngx_var_uri)
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

return BodyFilterHandler
