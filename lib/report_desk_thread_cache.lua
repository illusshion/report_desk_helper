--[[ Модуль: кеш тредов и фильтра списка. ]]

function invalidateUiCaches()
    deskCache.filterKeys = nil
    deskCache.filterSig = ''
    deskCache.quickBtn = {}
    deskCache.quickBtnGen = -1
    deskCache.scenarioBtnSig = nil
    deskCache.scenarioBtnIdx = nil
    deskCache.wrapTextSpaceW = nil
    if type(deskCache.intentResolve) == 'table' then
        deskCache.intentResolve = {}
    end
end

function markUiCacheDirty()
    deskCache.uiCacheDirty = true
end

function invalidateFilterCache()
    deskCache.filterKeys = nil
    deskCache.filterSig = ''
end

function bumpThreadStructRev()
    deskCache.threadStructRev = (deskCache.threadStructRev or 0) + 1
    deskCache.threadRev = deskCache.threadStructRev
    invalidateFilterCache()
end

function bumpThreadMsgRev()
    deskCache.threadMsgRev = (deskCache.threadMsgRev or 0) + 1
end

function syncThreadCount()
    local n = 0
    for _ in pairs(threads) do n = n + 1 end
    threadCount = n
end

function rebuildNickIndex()
    deskCache.nickKeys = {}
    for key, t in pairs(threads) do
        local nk = nickKey(t.nick)
        if nk ~= '' and not deskCache.nickKeys[nk] then
            deskCache.nickKeys[nk] = key
        end
    end
end
