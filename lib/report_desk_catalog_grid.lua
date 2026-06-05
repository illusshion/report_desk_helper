--[[ Адаптивная сетка каталога (скины / транспорт) с виртуальным скроллом ]]
local imgui = require 'mimgui'

local M = {}

local function rowTotalWidth(cols, cellW, gap)
    return cols * cellW + math.max(0, cols - 1) * gap
end

function M.contentWidth(opts)
    opts = opts or {}
    local w = imgui.GetContentRegionAvail().x
    local margin = opts.margin or 6
    if opts.reserveScrollbar ~= false then
        margin = margin + (opts.scrollbarW or 14)
    end
    return math.max(80, w - margin)
end

function M.compute(availW, aspectH, opts)
    opts = opts or {}
    local gap = opts.gap or 6
    local pad = opts.pad or 1
    local minCols = opts.minCols or 2
    local maxCols = opts.maxCols or 12
    local minThumbW = opts.minThumbW or 48
    local maxThumbW = opts.maxThumbW or 128

    availW = math.floor(math.max(availW or 200, minThumbW * minCols + gap * (minCols - 1)))

    local cols, cellW
    for c = maxCols, minCols, -1 do
        local w = math.floor((availW - gap * (c - 1)) / c)
        if w >= minThumbW and w <= maxThumbW then
            cols, cellW = c, w
            break
        end
    end
    if not cols then
        cols = math.max(minCols, math.floor((availW + gap) / (maxThumbW + gap)))
        cols = math.min(maxCols, cols)
        cellW = math.floor((availW - gap * (cols - 1)) / cols)
        if cellW < minThumbW then
            cols = minCols
            cellW = math.floor((availW - gap * (cols - 1)) / cols)
        end
        cellW = math.min(maxThumbW, math.max(minThumbW, cellW))
    end

    while cols > minCols and rowTotalWidth(cols, cellW, gap) > availW do
        cols = cols - 1
        cellW = math.floor((availW - gap * (cols - 1)) / cols)
    end

    local thumbW = math.max(24, math.floor(cellW - pad * 2))
    local thumbH = thumbW * aspectH
    local rowH = thumbH + gap

    return {
        cols = cols,
        gap = gap,
        pad = pad,
        cellW = cellW,
        thumbW = thumbW,
        thumbH = thumbH,
        rowH = rowH,
    }
end

--- Виртуальный скролл: рисуем только видимые строки, полная высота для полосы прокрутки.
function M.drawVirtual(items, layout, drawCell, opts)
    if not items or #items == 0 or not layout or not layout.cols or layout.cols < 1 then
        return
    end
    if not drawCell then return end
    opts = opts or {}

    local cols = layout.cols
    local rowH = math.max(8, layout.rowH or 32)
    local count = #items
    local totalRows = math.ceil(count / cols)
    local totalH = totalRows * rowH
    local overscan = opts.overscanRows or 1

    local scrollY = imgui.GetScrollY()
    local availH = imgui.GetContentRegionAvail().y
    if availH < rowH then availH = rowH end

    local firstRow = math.max(0, math.floor(scrollY / rowH) - overscan)
    local lastRow = math.min(totalRows - 1, math.ceil((scrollY + availH) / rowH) + overscan)

    if opts.onVisible then
        local firstIdx = firstRow * cols + 1
        local lastIdx = math.min(count, (lastRow + 1) * cols)
        pcall(opts.onVisible, firstIdx, lastIdx, items)
    end

    imgui.SetCursorPosY(firstRow * rowH)

    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(layout.gap, layout.gap))
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(0, 0))
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 4)

    for row = firstRow, lastRow do
        local rowOk, rowErr = pcall(function()
            if imgui.PushID then imgui.PushID(row) end
            local rowY = imgui.GetCursorPosY()
            for col = 0, cols - 1 do
                local idx = row * cols + col + 1
                if idx > count then break end
                if col > 0 then imgui.SameLine() end
                pcall(drawCell, items[idx], layout, idx)
            end
            local used = imgui.GetCursorPosY() - rowY
            if used < rowH - 0.5 then
                imgui.Dummy(imgui.ImVec2(1, rowH - used))
            end
            if imgui.PopID then imgui.PopID() end
        end)
        if not rowOk and rowErr then
            print('[Report Desk] grid row: ' .. tostring(rowErr))
            break
        end
    end

    imgui.PopStyleVar(3)

    imgui.SetCursorPosY(totalH)
    imgui.Dummy(imgui.ImVec2(1, 1))
end

function M.draw(items, layout, drawCell, opts)
    M.drawVirtual(items, layout, drawCell, opts)
end

function M.fitPreview(baseW, baseH, maxW)
    maxW = maxW or baseW
    if maxW >= baseW - 4 then
        return baseW, baseH
    end
    local sc = math.max(0.35, (maxW - 8) / baseW)
    return baseW * sc, baseH * sc
end

return M
