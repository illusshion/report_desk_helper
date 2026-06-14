--[[ Модуль: централизованный реестр SAMP hooks (точечный reinstall). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

HookRegistry = HookRegistry or { entries = {}, missCount = 0, lastWarnAt = 0 }

function HookRegistry.register(id, event, checker, installer)
    if not id or not event or not installer then return end
    HookRegistry.entries[id] = {
        event = event,
        checker = checker,
        installer = installer,
    }
end

function HookRegistry.ensure(id)
    local e = HookRegistry.entries[id]
    if not e or not sampev then return false end
    local ok = true
    if type(e.checker) == 'function' then
        ok = e.checker() == true
    elseif e.handler and sampev[e.event] then
        ok = sampev[e.event] == e.handler
    end
    if ok then return true end
    pcall(e.installer)
    return false
end

function HookRegistry.ensureAll()
    if not sampev then return 0 end
    local misses = 0
    for id in pairs(HookRegistry.entries) do
        if not HookRegistry.ensure(id) then
            misses = misses + 1
        end
    end
    if misses > 0 then
        HookRegistry.missCount = (HookRegistry.missCount or 0) + misses
        local now = os.clock()
        if HookRegistry.missCount >= 3 and now - (HookRegistry.lastWarnAt or 0) >= 60.0 then
            print(string.format('[Report Desk] hook registry: %d reinstall(s) (%d total misses)',
                misses, HookRegistry.missCount))
            HookRegistry.lastWarnAt = now
        end
    end
    if type(installDeskSpMenuRpcBlock) == 'function' then pcall(installDeskSpMenuRpcBlock) end
    if type(installDeskCheckerRpcProbe) == 'function' then pcall(installDeskCheckerRpcProbe) end
    return misses
end

function HookRegistry.bindHandler(id, handler)
    local e = HookRegistry.entries[id]
    if e then e.handler = handler end
end
