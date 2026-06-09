--[[ Report Desk — pure Lua SHA256 (file + string, no external processes) ]]
local M = {}

local Bit
do
    local ok, mod = pcall(require, 'bit')
    if not ok then
        error('report_desk_sha256 requires LuaJIT bit library')
    end
    Bit = mod
    if Bit.rol and not Bit.lrotate then Bit.lrotate = Bit.rol end
    if Bit.ror and not Bit.rrotate then Bit.rrotate = Bit.ror end
end

local AND = Bit.band
local OR = Bit.bor
local NOT = Bit.bnot
local XOR = Bit.bxor
local RROT = Bit.rrotate
local LSHIFT = Bit.lshift
local RSHIFT = Bit.rshift

local CONSTANTS = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function bytes2word(b0, b1, b2, b3)
    local i = b0
    i = LSHIFT(i, 8)
    i = OR(i, b1)
    i = LSHIFT(i, 8)
    i = OR(i, b2)
    i = LSHIFT(i, 8)
    i = OR(i, b3)
    return i
end

local function word2bytes(word)
    local b3 = AND(word, 0xFF)
    word = RSHIFT(word, 8)
    local b2 = AND(word, 0xFF)
    word = RSHIFT(word, 8)
    local b1 = AND(word, 0xFF)
    word = RSHIFT(word, 8)
    local b0 = AND(word, 0xFF)
    return b0, b1, b2, b3
end

local function bytes2dword(b0, b1, b2, b3, b4, b5, b6, b7)
    local i = bytes2word(b0, b1, b2, b3)
    local j = bytes2word(b4, b5, b6, b7)
    return (i * 0x100000000) + j
end

local function dword2bytes(i)
    local b4, b5, b6, b7 = word2bytes(i)
    local b0, b1, b2, b3 = word2bytes(math.floor(i / 0x100000000))
    return b0, b1, b2, b3, b4, b5, b6, b7
end

local function makeQueue()
    local queue = {}
    local tail = 0
    local head = 0
    return {
        push = function(b)
            queue[head] = b
            head = head + 1
        end,
        pop = function()
            if tail >= head then return nil end
            local b = queue[tail]
            queue[tail] = nil
            tail = tail + 1
            return b
        end,
        size = function()
            return head - tail
        end,
    }
end

local function digestBytes(bytes)
    local queue = makeQueue()
    local h0 = 0x6a09e667
    local h1 = 0xbb67ae85
    local h2 = 0x3c6ef372
    local h3 = 0xa54ff53a
    local h4 = 0x510e527f
    local h5 = 0x9b05688c
    local h6 = 0x1f83d9ab
    local h7 = 0x5be0cd19

    local totalBytes = 0

    local function processBlock()
        local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
        local w = {}
        for i = 0, 15 do
            w[i] = bytes2word(queue.pop(), queue.pop(), queue.pop(), queue.pop())
        end
        for i = 16, 63 do
            local s0 = XOR(RROT(w[i - 15], 7), XOR(RROT(w[i - 15], 18), RSHIFT(w[i - 15], 3)))
            local s1 = XOR(RROT(w[i - 2], 17), XOR(RROT(w[i - 2], 19), RSHIFT(w[i - 2], 10)))
            w[i] = AND(w[i - 16] + s0 + w[i - 7] + s1, 0xFFFFFFFF)
        end
        for i = 0, 63 do
            local s1 = XOR(RROT(e, 6), XOR(RROT(e, 11), RROT(e, 25)))
            local ch = XOR(AND(e, f), AND(NOT(e), g))
            local temp1 = h + s1 + ch + CONSTANTS[i + 1] + w[i]
            local s0 = XOR(RROT(a, 2), XOR(RROT(a, 13), RROT(a, 22)))
            local maj = XOR(AND(a, b), XOR(AND(a, c), AND(b, c)))
            local temp2 = s0 + maj
            h = g
            g = f
            f = e
            e = d + temp1
            d = c
            c = b
            b = a
            a = temp1 + temp2
        end
        h0 = AND(h0 + a, 0xFFFFFFFF)
        h1 = AND(h1 + b, 0xFFFFFFFF)
        h2 = AND(h2 + c, 0xFFFFFFFF)
        h3 = AND(h3 + d, 0xFFFFFFFF)
        h4 = AND(h4 + e, 0xFFFFFFFF)
        h5 = AND(h5 + f, 0xFFFFFFFF)
        h6 = AND(h6 + g, 0xFFFFFFFF)
        h7 = AND(h7 + h, 0xFFFFFFFF)
    end

    for i = 1, #bytes do
        queue.push(string.byte(bytes, i))
        totalBytes = totalBytes + 1
        if queue.size() >= 64 then
            processBlock()
        end
    end

    local bits = totalBytes * 8
    queue.push(0x80)
    while ((queue.size() + 7) % 64) < 63 do
        queue.push(0x00)
    end
    local b0, b1, b2, b3, b4, b5, b6, b7 = dword2bytes(bits)
    queue.push(b0)
    queue.push(b1)
    queue.push(b2)
    queue.push(b3)
    queue.push(b4)
    queue.push(b5)
    queue.push(b6)
    queue.push(b7)
    while queue.size() > 0 do
        processBlock()
    end

    local w0, w1, w2, w3 = word2bytes(h0)
    local w4, w5, w6, w7 = word2bytes(h1)
    local w8, w9, w10, w11 = word2bytes(h2)
    local w12, w13, w14, w15 = word2bytes(h3)
    local w16, w17, w18, w19 = word2bytes(h4)
    local w20, w21, w22, w23 = word2bytes(h5)
    local w24, w25, w26, w27 = word2bytes(h6)
    local w28, w29, w30, w31 = word2bytes(h7)
    return string.format(
        '%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x',
        w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15,
        w16, w17, w18, w19, w20, w21, w22, w23, w24, w25, w26, w27, w28, w29, w30, w31
    )
end

function M.hash(data)
    return digestBytes(tostring(data or ''))
end

function M.hashFile(path)
    path = tostring(path or '')
    if path == '' or not doesFileExist or not doesFileExist(path) then
        return nil
    end
    local f = io.open(path, 'rb')
    if not f then return nil end
    local data = f:read('*a')
    f:close()
    if not data then return nil end
    return digestBytes(data)
end

assert(M.hash('') == 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    'report_desk_sha256 self-test failed')

return M
