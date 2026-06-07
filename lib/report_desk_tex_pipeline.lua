--[[ Модуль: async IO + budgeted GPU upload текстур. ]]
local texLoad = require 'report_desk_tex_loader'

local M = {}

local nsOrder = {}
local nsState = {}
local ioWorkerStarted = false
local useSyncIo = false
local pipelineDead = false

local DEFAULT_IO_IDLE_MS = 12
local DEFAULT_GPU_BUDGET = 5

local ioIdleMs = DEFAULT_IO_IDLE_MS
local gpuBudget = DEFAULT_GPU_BUDGET
local activeImgui = nil

-- Ns Key
local function nsKey(ns)
    return tostring(ns or '')
end

-- Ensure Ns
local function ensureNs(ns)
    ns = nsKey(ns)
    if nsState[ns] then return nsState[ns] end
    local st = {
        active = false,
        pathForId = nil,
        releaseFn = nil,
        onUploaded = nil,
        wanted = {},
        ioQueue = {},
        ioSet = {},
        uploadQueue = {},
        uploadSet = {},
    }
    nsState[ns] = st
    nsOrder[#nsOrder + 1] = ns
    return st
end

-- Публичный API модуля.
function M.configure(opts)
    opts = opts or {}
    if opts.ioIdleMs then
        ioIdleMs = math.max(5, math.min(200, math.floor(opts.ioIdleMs)))
    end
    if opts.gpuBudget then
        gpuBudget = math.max(1, math.min(24, math.floor(opts.gpuBudget)))
    end
    texLoad.configure({
        stagingMax = opts.stagingMax,
        maxBytes = opts.maxBytes,
    })
end

-- Публичный API модуля.
function M.registerNs(ns, opts)
    opts = opts or {}
    local st = ensureNs(nsKey(ns))
    if opts.pathForId then st.pathForId = opts.pathForId end
    if opts.releaseFn then st.releaseFn = opts.releaseFn end
    if opts.onUploaded then st.onUploaded = opts.onUploaded end
end

-- Публичный API модуля.
function M.activate(ns)
    if pipelineDead then return end
    local st = ensureNs(nsKey(ns))
    st.active = true
    M.ensureIoWorker()
end

-- Публичный API модуля.
function M.deactivate(ns, deskTex)
    ns = nsKey(ns)
    local st = nsState[ns]
    if not st then return end
    st.active = false
    st.wanted = {}
    st.ioQueue = {}
    st.ioSet = {}
    st.uploadQueue = {}
    st.uploadSet = {}
    texLoad.clearStaging(ns)
    if deskTex and st.releaseFn then
        deskTex.releaseAll(ns, st.releaseFn, true)
    end
    texLoad.clearNamespace(ns)
end

-- Публичный API модуля.
function M.deactivateAll(deskTex)
    for ns in pairs(nsState) do
        M.deactivate(ns, deskTex)
    end
end

-- Публичный API модуля.
function M.isDead()
    return pipelineDead
end

-- Публичный API модуля.
function M.requestDeferredFlush()
    if type(deskCache) == 'table' then
        deskCache.catalogTexFlushPending = true
    end
end

-- Публичный API модуля.
function M.flushDeferred(deskTex, imgui, maxCount)
    imgui = imgui or activeImgui
    if imgui and imgui.SwitchContext then pcall(imgui.SwitchContext) end
    if deskTex and deskTex.flushPendingRelease then
        pcall(deskTex.flushPendingRelease, maxCount)
    end
end

-- Публичный API модуля.
function M.halt(deskTex)
    for ns in pairs(nsState) do
        M.deactivate(ns, deskTex)
    end
    texLoad.clearAll()
    M.requestDeferredFlush()
end

-- Публичный API модуля.
function M.shutdown(deskTex, imgui)
    pipelineDead = true
    M.halt(deskTex)
    M.flushDeferred(deskTex, imgui)
end

-- Prune Io Queue
local function pruneIoQueue(st, want)
    local kept, keptSet = {}, {}
    for _, job in ipairs(st.ioQueue) do
        if job and job.id and want[job.id] then
            kept[#kept + 1] = job
            keptSet[job.id] = true
        end
    end
    st.ioQueue = kept
    st.ioSet = keptSet
end

-- Prune Upload Queue Ns
local function pruneUploadQueueNs(ns, st, want)
    local kept, keptSet = {}, {}
    for _, id in ipairs(st.uploadQueue) do
        if id and want[id] then
            kept[#kept + 1] = id
            keptSet[id] = true
        else
            texLoad.dropStaging(ns, id)
        end
    end
    st.uploadQueue = kept
    st.uploadSet = keptSet
end

-- Enqueue Io
local function enqueueIo(ns, st, id, path, meta)
    if st.ioSet[id] or st.uploadSet[id] or texLoad.hasStaging(ns, id) then
        return false
    end
    st.ioQueue[#st.ioQueue + 1] = { id = id, path = path, meta = meta }
    st.ioSet[id] = true
    return true
end

-- Promote Io
local function promoteIo(st, id)
    for i, job in ipairs(st.ioQueue) do
        if job and job.id == id then
            table.remove(st.ioQueue, i)
            table.insert(st.ioQueue, 1, job)
            return
        end
    end
end

-- Enqueue Upload
local function enqueueUpload(st, id, front)
    if st.uploadSet[id] then
        if front then
            for i, uid in ipairs(st.uploadQueue) do
                if uid == id then
                    table.remove(st.uploadQueue, i)
                    break
                end
            end
            table.insert(st.uploadQueue, 1, id)
        end
        return
    end
    if front then
        table.insert(st.uploadQueue, 1, id)
    else
        st.uploadQueue[#st.uploadQueue + 1] = id
    end
    st.uploadSet[id] = true
end

-- Публичный API модуля.
function M.syncVisible(ns, ids, deskTex, opts)
    if pipelineDead or not deskTex then return end
    ns = nsKey(ns)
    local st = nsState[ns]
    if not st or not st.active or not st.pathForId then return end
    opts = opts or {}

    local want = {}
    for _, rawId in ipairs(opts.priority or {}) do
        local id = tonumber(rawId) or rawId
        if id then want[id] = true end
    end
    for _, rawId in ipairs(ids or {}) do
        local id = tonumber(rawId) or rawId
        if id then want[id] = true end
    end
    st.wanted = want

    pruneIoQueue(st, want)
    pruneUploadQueueNs(ns, st, want)

    local function requestId(id, front)
        if not id or deskTex.has(ns, id) or deskTex.isFailed(ns, id) then return end
        if texLoad.hasStaging(ns, id) then
            enqueueUpload(st, id, front)
            return
        end
        if st.ioSet[id] then
            if front then promoteIo(st, id) end
            return
        end
        local path, meta = st.pathForId(id)
        if path then
            enqueueIo(ns, st, id, path, meta)
            if front then promoteIo(st, id) end
        end
    end

    for _, rawId in ipairs(opts.priority or {}) do
        requestId(tonumber(rawId) or rawId, true)
    end
    for _, rawId in ipairs(ids or {}) do
        requestId(tonumber(rawId) or rawId, false)
    end
end

-- Pop Io Job
local function popIoJob()
    for _, ns in ipairs(nsOrder) do
        local st = nsState[ns]
        if st and st.active and #st.ioQueue > 0 then
            local job = table.remove(st.ioQueue, 1)
            if job and job.id then
                st.ioSet[job.id] = nil
                return ns, st, job
            end
        end
    end
    return nil, nil, nil
end

-- Run Io Job
local function runIoJob(ns, st, job)
    if pipelineDead or not st or not job or not job.id or not job.path then return false end
    if not st.active or not st.wanted[job.id] then return true end
    local data = texLoad.readFileBytes(job.path)
    if data then
        texLoad.storeStaging(ns, job.id, data, job.meta)
        enqueueUpload(st, job.id, false)
    end
    return true
end

-- Process Sync Io
local function processSyncIo(budget)
    budget = math.max(1, tonumber(budget) or 2)
    local n = 0
    while n < budget do
        local ns, st, job = popIoJob()
        if not job then break end
        runIoJob(ns, st, job)
        n = n + 1
    end
end

-- Публичный API модуля.
function M.ensureIoWorker()
    if pipelineDead or ioWorkerStarted or useSyncIo then return end
    if not lua_thread or not lua_thread.create then
        useSyncIo = true
        return
    end
    ioWorkerStarted = true
    lua_thread.create(function()
        while not pipelineDead do
            local ns, st, job = popIoJob()
            if ns and job then
                runIoJob(ns, st, job)
                wait(0)
            else
                wait(ioIdleMs)
            end
        end
    end)
end

-- Pop Upload
local function popUpload(st)
    while #st.uploadQueue > 0 do
        local id = table.remove(st.uploadQueue, 1)
        if id then st.uploadSet[id] = nil end
        if id then return id end
    end
    return nil
end

-- Публичный API модуля.
function M.tick(imgui, deskTex, budget)
    activeImgui = imgui
    if pipelineDead or not imgui or not deskTex then return end
    budget = math.max(0, tonumber(budget) or gpuBudget)
    if budget <= 0 then return end

    if useSyncIo then
        processSyncIo(math.max(1, math.floor(budget * 0.4)))
    end

    if imgui.SwitchContext then pcall(imgui.SwitchContext) end

    local uploaded = 0
    local rounds = 0
    local maxRounds = budget * math.max(1, #nsOrder) * 3

    while uploaded < budget and rounds < maxRounds do
        rounds = rounds + 1
        local progressed = false
        for _, ns in ipairs(nsOrder) do
            if uploaded >= budget then break end
            local st = nsState[ns]
            if not st or not st.active or not st.releaseFn then goto continue_ns end
            local id = popUpload(st)
            if not id then goto continue_ns end
            if deskTex.has(ns, id) or deskTex.isFailed(ns, id) then
                texLoad.dropStaging(ns, id)
                progressed = true
                goto continue_ns
            end
            local data, meta = texLoad.takeStaging(ns, id)
            if not data then goto continue_ns end
            local tex = texLoad.decodeTexture(imgui, data, meta)
            if tex then
                deskTex.adopt(ns, id, tex, st.releaseFn)
                if st.onUploaded then pcall(st.onUploaded, id, meta) end
                uploaded = uploaded + 1
            elseif deskTex.markFailed then
                deskTex.markFailed(ns, id)
            end
            progressed = true
            ::continue_ns::
        end
        if not progressed then break end
    end
end

-- Публичный API модуля.
function M.pendingCount(ns)
    ns = nsKey(ns)
    local st = nsState[ns]
    if not st or not st.active then return 0 end
    return #st.ioQueue + #st.uploadQueue
end

-- Публичный API модуля.
function M.anyPending()
    for _, st in pairs(nsState) do
        if st.active and (#st.ioQueue > 0 or #st.uploadQueue > 0) then
            return true
        end
    end
    return false
end

return M
