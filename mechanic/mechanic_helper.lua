script_author("Sinchan x 4trays SecureCode")
script_version("3.4")
script_name("Mechanic Helper")

require('lib.moonloader')
require('encoding').default = 'CP1251'
local u8 = require('encoding').UTF8
local ffi = require('ffi')
local ev = require('samp.events')
local http = require("socket.http")
local ltn12 = require("ltn12")

if MONET_DPI_SCALE == nil then MONET_DPI_SCALE = 1.0 end

local inicfg = require('inicfg')
local imgui = require('mimgui')
local fa = require('fAwesome6_solid')
local sizeX, sizeY = getScreenResolution()

-- JSON HELPER (no dependency)
local json = {}

local function jsonDecode(s)
    local pos = 1

    local function skipWS()
        while pos <= #s and s:sub(pos,pos):match("%s") do pos = pos + 1 end
    end

    local function parseValue()
        skipWS()
        local c = s:sub(pos,pos)

        if c == '"' then
            pos = pos + 1
            local result = ""
            while pos <= #s do
                local ch = s:sub(pos,pos)
                if ch == '\\' then
                    pos = pos + 1
                    local esc = s:sub(pos,pos)
                    if     esc == '"'  then result = result .. '"'
                    elseif esc == '\\' then result = result .. '\\'
                    elseif esc == '/'  then result = result .. '/'
                    elseif esc == 'n'  then result = result .. '\n'
                    elseif esc == 'r'  then result = result .. '\r'
                    elseif esc == 't'  then result = result .. '\t'
                    else result = result .. esc end
                    pos = pos + 1
                elseif ch == '"' then
                    pos = pos + 1
                    break
                else
                    result = result .. ch
                    pos = pos + 1
                end
            end
            return result

        elseif c:match("[%-0-9]") then
            local numStr = ""
            while pos <= #s and s:sub(pos,pos):match("[0-9%.%-eE%+]") do
                numStr = numStr .. s:sub(pos,pos)
                pos = pos + 1
            end
            return tonumber(numStr)

        elseif s:sub(pos, pos+3) == "true"  then pos = pos + 4; return true
        elseif s:sub(pos, pos+4) == "false" then pos = pos + 5; return false
        elseif s:sub(pos, pos+3) == "null"  then pos = pos + 4; return nil

        elseif c == '[' then
            pos = pos + 1
            local arr = {}
            skipWS()
            if s:sub(pos,pos) == ']' then pos = pos + 1; return arr end
            while true do
                table.insert(arr, parseValue())
                skipWS()
                if s:sub(pos,pos) == ',' then pos = pos + 1
                elseif s:sub(pos,pos) == ']' then pos = pos + 1; break
                else break end
            end
            return arr

        elseif c == '{' then
            pos = pos + 1
            local obj = {}
            skipWS()
            if s:sub(pos,pos) == '}' then pos = pos + 1; return obj end
            while true do
                skipWS()
                local key = parseValue()
                skipWS()
                if s:sub(pos,pos) == ':' then pos = pos + 1 end
                local val = parseValue()
                obj[key] = val
                skipWS()
                if s:sub(pos,pos) == ',' then pos = pos + 1
                elseif s:sub(pos,pos) == '}' then pos = pos + 1; break
                else break end
            end
            return obj
        end
    end

    return parseValue()
end

local function jsonEncode(val, indent, level)
    indent = indent or "    "
    level  = level  or 0
    local t = type(val)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        return tostring(val)
    elseif t == "string" then
        local escaped = val:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')
        return '"' .. escaped .. '"'
    elseif t == "table" then
        local isArr = true
        local n = 0
        for k,_ in pairs(val) do
            n = n + 1
            if type(k) ~= "number" or k ~= math.floor(k) then isArr = false; break end
        end
        if isArr and n > 0 then
            for i = 1, n do if val[i] == nil then isArr = false; break end end
        end
        local pad  = string.rep(indent, level)
        local pad1 = string.rep(indent, level + 1)
        if isArr and n > 0 then
            local items = {}
            for _, v in ipairs(val) do
                table.insert(items, pad1 .. jsonEncode(v, indent, level + 1))
            end
            return "[\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "]"
        else
            local items = {}
            for k, v in pairs(val) do
                table.insert(items, pad1 .. jsonEncode(tostring(k), indent, level+1) .. ": " .. jsonEncode(v, indent, level+1))
            end
            return "{\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "}"
        end
    end
    return "null"
end

json.decode = jsonDecode
json.encode = jsonEncode

-- AUTO UPDATE
local SCRIPT_VERSION = "3.4-july"
local UPDATE_CHECKED = false
local UPDATE_URL = "https://raw.githubusercontent.com/4traysTeam/monetloader-dist/main/mechanic/version.json"

function checkUpdate()
        if UPDATE_CHECKED then
        return
    end

    UPDATE_CHECKED = true

    local response = {}

    local _, code = http.request{
        url = UPDATE_URL,
        sink = ltn12.sink.table(response)
    }

    if code ~= 200 then
        sampAddChatMessage("[Mechanic] Gagal mengecek update.", 0xFF6666)
        return
    end

    local raw = table.concat(response)

    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" then
        sampAddChatMessage("[Mechanic] Version.json invalid.", 0xFF6666)
        return
    end

    if not data.version or not data.url then
        sampAddChatMessage("[Mechanic] Data update tidak lengkap.", 0xFF6666)
        return
    end

    if data.version ~= SCRIPT_VERSION then
        sampAddChatMessage(
            string.format(
                "[Mechanic] Update ditemukan! %s -> %s",
                SCRIPT_VERSION,
                data.version
            ),
            0x4D94FF
        )

        local scriptResponse = {}

        local _, scriptCode = http.request{
            url = data.url,
            sink = ltn12.sink.table(scriptResponse)
        }

        if scriptCode ~= 200 then
            sampAddChatMessage("[Mechanic] Gagal download update.", 0xFF6666)
            return
        end

        local newScript = table.concat(scriptResponse)

        if newScript == "" or #newScript < 1000 then
            sampAddChatMessage("[Mechanic] File update corrupt/kosong.", 0xFF6666)
            return
        end

        local scriptPath = thisScript().path
        local backupPath = scriptPath .. ".bak"
        local tempPath   = scriptPath .. ".tmp"

        -- backup lama
        local oldFile = io.open(scriptPath, "r")
        if oldFile then
            local oldData = oldFile:read("*a")
            oldFile:close()

            local backup = io.open(backupPath, "w")
            if backup then
                backup:write(oldData)
                backup:close()
            end
        end

        -- save temp
        local tempFile = io.open(tempPath, "w")
        if not tempFile then
            sampAddChatMessage("[Mechanic] Gagal membuat file temporary.", 0xFF6666)
            return
        end

        tempFile:write(newScript)
        tempFile:close()

        -- replace original
        os.remove(scriptPath)
        os.rename(tempPath, scriptPath)

        sampAddChatMessage(
            "[Mechanic] Update berhasil! Script akan reload otomatis...",
            0x33CC77
        )

        lua_thread.create(function()
    wait(2000)

    sampAddChatMessage(
        "[Mechanic] Reloading script...",
        0xAAAAAA
    )

    thisScript():reload()
end)
    else
        sampAddChatMessage(
            "[Mechanic] Script sudah versi terbaru.",
            0x33CC77
        )
    end
end

-- FILE PATHS
local SCRIPT_DIR    = getWorkingDirectory() .. "/config/"
local SERVICES_FILE = SCRIPT_DIR .. "mechanic_services.json"
local AUTORP_FILE   = SCRIPT_DIR .. "mechanic_autorp.json"

-- DEFAULT DATA
local DEFAULT_SERVICES = {
    { name = "Spray",           price = 500  },
    { name = "Paintjob",        price = 515  },
    { name = "Velg",            price = 300  },
    { name = "Spoiler",         price = 300  },
    { name = "Hood",            price = 340  },
    { name = "Vents",           price = 335  },
    { name = "Lights",          price = 290  },
    { name = "Exhausts",        price = 250  },
    { name = "Bumper depan",    price = 350  },
    { name = "Bumper belakang", price = 350  },
    { name = "Roofs",           price = 350  },
    { name = "Side Skirts",     price = 300  },
    { name = "Bullbars",        price = 245  },
    { name = "Stereo",          price = 300  },
    { name = "Hydraulics",      price = 500  },
    { name = "Nitro 1",         price = 425  },
    { name = "Nitro 2",         price = 470  },
    { name = "Nitro 3",         price = 520  },
    { name = "Neon",            price = 520  },
    { name = "Up Body",         price = 6000 },
    { name = "Up Tanki",        price = 6000 },
    { name = "Reset Modif",     price = 2700 },
}

local DEFAULT_AUTORP = {
    { label = "Check Engine",   me = "mengeluarkan alat diagnostik lalu mulai memeriksa kondisi mesin kendaraan di depannya.", do1 = "Proses pemeriksaan mesin sedang berlangsung...", do2 = "Pemeriksaan mesin selesai, kondisi mesin telah dicatat." },
    { label = "Bumper Depan",   me = "mengambil bumper depan lalu mulai memasangnya pada kendaraan pelanggan.",                do1 = "Proses pemasangan bumper depan sedang berlangsung...",   do2 = "Bumper depan berhasil terpasang dengan rapi." },
    { label = "Bumper Belakang",me = "mengambil bumper belakang lalu mulai memasangnya pada kendaraan pelanggan.",             do1 = "Proses pemasangan bumper belakang sedang berlangsung...", do2 = "Bumper belakang berhasil terpasang dengan rapi." },
    { label = "Hydraulics",     me = "menyiapkan kit hidrolik lalu mulai memasang sistem hidrolik pada kendaraan.",            do1 = "Proses pemasangan sistem hidrolik sedang berlangsung...", do2 = "Sistem hidrolik berhasil terpasang dan berfungsi normal." },
    { label = "Install Exhaust",me = "mengambil knalpot dari gudang lalu mulai memasangnya pada kendaraan.",                   do1 = "Proses pemasangan knalpot sedang berlangsung...",          do2 = "Knalpot berhasil terpasang dan telah dicek kebocorannya." },
    { label = "Install Spoiler",me = "mengambil spoiler dari gudang lalu mulai memasangnya di bagian belakang kendaraan.",     do1 = "Proses pemasangan spoiler sedang berlangsung...",          do2 = "Spoiler berhasil terpasang dengan kuat dan rapi." },
    { label = "Neon",           me = "menyiapkan lampu neon lalu mulai memasangnya di bagian bawah kendaraan.",               do1 = "Proses pemasangan lampu neon sedang berlangsung...",       do2 = "Lampu neon berhasil terpasang dan menyala normal." },
    { label = "Nitro 1",        me = "mengeluarkan tabung nitro tingkat 1 lalu mulai memasang sistemnya pada kendaraan.",      do1 = "Proses pemasangan Nitro 1 sedang berlangsung...",          do2 = "Nitro tingkat 1 berhasil terpasang dan tekanan sudah dicek." },
    { label = "Nitro 2",        me = "mengeluarkan tabung nitro tingkat 2 lalu mulai memasang sistemnya pada kendaraan.",      do1 = "Proses pemasangan Nitro 2 sedang berlangsung...",          do2 = "Nitro tingkat 2 berhasil terpasang dan tekanan sudah dicek." },
    { label = "Nitro 3",        me = "mengeluarkan tabung nitro tingkat 3 lalu mulai memasang sistemnya pada kendaraan.",      do1 = "Proses pemasangan Nitro 3 sedang berlangsung...",          do2 = "Nitro tingkat 3 berhasil terpasang dan tekanan sudah dicek." },
    { label = "Paint",          me = "menyiapkan spray gun dan cat pilihan lalu mulai melakukan pengecatan kustom pada kendaraan.", do1 = "Proses pengecatan kustom sedang berlangsung...",      do2 = "Pengecatan kustom selesai, hasil sudah dipoles hingga mengkilap." },
    { label = "Paintjob",       me = "menyiapkan template paintjob lalu mulai mengaplikasikannya pada body kendaraan.",        do1 = "Proses aplikasi paintjob sedang berlangsung...",           do2 = "Paintjob berhasil diaplikasikan dan hasilnya memuaskan." },
    { label = "Repair Body",    me = "memeriksa kerusakan body lalu mulai melakukan perbaikan pada panel-panel yang penyok.",   do1 = "Proses perbaikan body kendaraan sedang berlangsung...",    do2 = "Perbaikan body selesai, semua panel kembali ke kondisi normal." },
    { label = "Repair Engine",  me = "membuka kap mesin lalu mulai melakukan diagnosis dan perbaikan pada mesin kendaraan.",   do1 = "Proses perbaikan mesin sedang berlangsung...",             do2 = "Perbaikan mesin selesai, mesin sudah dicoba dan berjalan normal." },
    { label = "Stereo",         me = "menyiapkan unit stereo dan kabel lalu mulai memasang sistem audio pada kendaraan.",      do1 = "Proses instalasi sistem audio sedang berlangsung...",      do2 = "Sistem audio berhasil terinstal dan sudah dicek kualitas suaranya." },
    { label = "Up Body Action", me = "menyiapkan kit upgrade body lalu mulai melakukan modifikasi bodi kendaraan.",            do1 = "Proses upgrade body action sedang berlangsung...",         do2 = "Upgrade body action selesai, tampilan kendaraan jauh lebih sporty." },
    { label = "Up Gas Tank",    me = "membuka bagian tangki lalu mulai melakukan upgrade sistem tangki bahan bakar.",          do1 = "Proses upgrade tangki bahan bakar sedang berlangsung...",  do2 = "Upgrade tangki selesai, kapasitas tangki kini lebih besar." },
    { label = "Up Mesin",       me = "membuka kap mesin dan menyiapkan part upgrade lalu mulai melakukan upgrade mesin.",      do1 = "Proses upgrade mesin sedang berlangsung...",               do2 = "Upgrade mesin selesai, performa kendaraan meningkat signifikan." },
    { label = "Exhausts",       me = "mengambil exhaust baru dari rak lalu mulai memasang sistem exhaust pada kendaraan.",     do1 = "Proses pemasangan sistem exhaust sedang berlangsung...",   do2 = "Sistem exhaust baru berhasil terpasang dan sudah dicek kebocorannya." },
    { label = "Full Up",        me = "menyiapkan semua part upgrade lalu mulai melakukan full upgrade pada kendaraan.",        do1 = "Proses full upgrade kendaraan sedang berlangsung, harap tunggu...", do2 = "Full upgrade selesai, kendaraan kini berada di performa terbaiknya." },
    { label = "Velg",           me = "menyiapkan velg baru dan kunci roda lalu mulai mengganti velg kendaraan.",              do1 = "Proses penggantian velg sedang berlangsung...",            do2 = "Semua velg berhasil diganti dan mur roda sudah dikencangkan." },
    { label = "Wheels",         me = "menyiapkan roda baru dan jack mobil lalu mulai mengganti roda kendaraan.",              do1 = "Proses penggantian roda sedang berlangsung...",            do2 = "Semua roda berhasil diganti dan tekanan ban sudah dicek." },
}

-- JSON LOAD / SAVE HELPERS
local function fileExists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function writeFile(path, content)
    local dir = path:match("^(.*[/\\])")
    if dir then os.execute('mkdir -p "' .. dir .. '"') end
    local f = io.open(path, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

local function loadServicesFromJSON()
    local list = {}
    local data = nil
    if fileExists(SERVICES_FILE) then
        local raw = readFile(SERVICES_FILE)
        if raw then
            local ok, result = pcall(json.decode, raw)
            if ok and type(result) == "table" then data = result end
        end
    end
    if not data then
        data = DEFAULT_SERVICES
        writeFile(SERVICES_FILE, json.encode(data))
    end
    for _, item in ipairs(data) do
        table.insert(list, {
            name     = tostring(item.name  or "Service"),
            price    = tonumber(item.price or 0),
            selected = imgui.new.bool(false),
        })
    end
    return list
end

local function loadAutoRPFromJSON()
    local list = {}
    local data = nil
    if fileExists(AUTORP_FILE) then
        local raw = readFile(AUTORP_FILE)
        if raw then
            local ok, result = pcall(json.decode, raw)
            if ok and type(result) == "table" then data = result end
        end
    end
    if not data then
        data = DEFAULT_AUTORP
        writeFile(AUTORP_FILE, json.encode(data))
    end
    for _, item in ipairs(data) do
        table.insert(list, {
            label = tostring(item.label or "Action"),
            me    = tostring(item.me   or ""),
            do1   = tostring(item.do1  or ""),
            do2   = tostring(item.do2  or ""),
        })
    end
    return list
end

-- CONFIG
local configIni = inicfg.load({
    window = {
        posX   = sizeX / 2 - 250,
        posY   = sizeY / 2 - 300,
        locked = false
    },
    settings = {
        currency_symbol = "$"
    }
}, 'mechanic_helper')

-- WINDOW STATE
local MainWindow     = imgui.new.bool(false)
local positionLocked = imgui.new.bool(configIni.window.locked or false)
local currentTab     = 1

local windowWidth  = 480 * MONET_DPI_SCALE
local windowHeight = 510 * MONET_DPI_SCALE

-- SETTINGS BUFFERS
local cfg_currency = imgui.new.char[16](configIni.settings.currency_symbol or "$")

-- LOAD DATA AWAL
serviceList   = {}
autoRPButtons = {}

-- KASIR STATE
local kasirCustomerName = imgui.new.char[128]()
local kasirTotal        = 0
local kasirGrandTotal   = 0

-- KALKULATOR STATE
local calcDisplay   = "0"
local calcBuffer    = ""
local calcOperator  = ""
local calcNewNumber = true
local calcResult    = 0
local calcHistory   = {}

-- COLOR PALETTE
local C = {
    bg          = imgui.ImVec4(0.08, 0.09, 0.11, 0.97),
    titleBg     = imgui.ImVec4(0.05, 0.06, 0.08, 1.00),
    accent      = imgui.ImVec4(0.18, 0.52, 0.90, 1.00),
    accentHover = imgui.ImVec4(0.25, 0.60, 1.00, 1.00),
    accentDark  = imgui.ImVec4(0.12, 0.38, 0.70, 1.00),
    accentDim   = imgui.ImVec4(0.18, 0.52, 0.90, 0.20),
    text        = imgui.ImVec4(0.90, 0.90, 0.92, 1.00),
    textMuted   = imgui.ImVec4(0.55, 0.55, 0.60, 1.00),
    textDark    = imgui.ImVec4(0.35, 0.35, 0.40, 1.00),
    success     = imgui.ImVec4(0.20, 0.75, 0.45, 1.00),
    danger      = imgui.ImVec4(0.85, 0.25, 0.25, 1.00),
    warning     = imgui.ImVec4(0.95, 0.70, 0.15, 1.00),
    yellow      = imgui.ImVec4(1.00, 0.85, 0.00, 1.00),
    btn         = imgui.ImVec4(0.14, 0.16, 0.20, 1.00),
    btnHover    = imgui.ImVec4(0.20, 0.22, 0.28, 1.00),
    btnActive   = imgui.ImVec4(0.25, 0.28, 0.35, 1.00),
    input       = imgui.ImVec4(0.10, 0.11, 0.14, 1.00),
    separator   = imgui.ImVec4(0.18, 0.52, 0.90, 0.30),
    tabActive   = imgui.ImVec4(0.18, 0.52, 0.90, 0.25),
    tabInactive = imgui.ImVec4(0.10, 0.11, 0.14, 0.80),
    childBg     = imgui.ImVec4(0.06, 0.07, 0.09, 0.70),
    popupBg     = imgui.ImVec4(0.09, 0.10, 0.13, 0.98),
    rowEven     = imgui.ImVec4(0.10, 0.11, 0.14, 0.60),
    rowOdd      = imgui.ImVec4(0.08, 0.09, 0.12, 0.60),
    rowSelected = imgui.ImVec4(0.18, 0.52, 0.90, 0.30),
    calcBtn     = imgui.ImVec4(0.15, 0.17, 0.21, 1.00),
    calcOp      = imgui.ImVec4(0.18, 0.52, 0.90, 0.80),
    calcEq      = imgui.ImVec4(0.20, 0.75, 0.45, 1.00),
    calcClear   = imgui.ImVec4(0.75, 0.20, 0.20, 1.00),
    black0      = imgui.ImVec4(0.00, 0.00, 0.00, 0.00),
}

-- HELPERS
local function formatCurrency(amount)
    local sym = ffi.string(cfg_currency)
    if sym == "" then sym = "$" end
    local str = tostring(math.floor(amount))
    local result = ""
    local count = 0
    for i = #str, 1, -1 do
        count = count + 1
        result = str:sub(i, i) .. result
        if count % 3 == 0 and i > 1 then
            result = "." .. result
        end
    end
    return sym .. " " .. result
end

local function recalcTotal()
    kasirTotal = 0
    for _, svc in ipairs(serviceList) do
        if svc.selected[0] then
            kasirTotal = kasirTotal + svc.price
        end
    end
    kasirGrandTotal = kasirTotal
end

local function getSelectedServices()
    local list = {}
    for _, svc in ipairs(serviceList) do
        if svc.selected[0] then table.insert(list, svc) end
    end
    return list
end

local function clearAllServices()
    for _, svc in ipairs(serviceList) do svc.selected[0] = false end
    recalcTotal()
end

-- reloadAllJSON
local function reloadAllJSON()
    local prevSelected = {}
    for _, svc in ipairs(serviceList) do
        if svc.selected[0] then prevSelected[svc.name] = true end
    end
    serviceList   = loadServicesFromJSON()
    autoRPButtons = loadAutoRPFromJSON()
    for _, svc in ipairs(serviceList) do
        if prevSelected[svc.name] then svc.selected[0] = true end
    end
    recalcTotal()
    sampAddChatMessage("[Mechanic] Data di-reload dari JSON!", 0x4D94FF)
end

-- Prefix hardcode /me dan /do
local function getRPPrefix()   return "/me" end
local function getChatPrefix() return "/do" end

-- CALCULATOR LOGIC
local function calcInput(char)
    if calcNewNumber then
        calcDisplay = (char == ".") and "0." or char
        calcNewNumber = false
    else
        if char == "." and calcDisplay:find("%.") then return end
        if calcDisplay == "0" and char ~= "." then
            calcDisplay = char
        else
            if #calcDisplay < 12 then calcDisplay = calcDisplay .. char end
        end
    end
end

local function calcDoOperation(op)
    local num = tonumber(calcDisplay) or 0
    if calcBuffer == "" then
        calcBuffer = calcDisplay
        calcResult = num
    else
        local prev = tonumber(calcBuffer) or 0
        if calcOperator == "+" then calcResult = prev + num
        elseif calcOperator == "-" then calcResult = prev - num
        elseif calcOperator == "x" then calcResult = prev * num
        elseif calcOperator == "/" then
            calcResult = (num ~= 0) and (prev / num) or 0
        end
        calcDisplay = tostring(calcResult)
        if calcDisplay:find("%.") then
            calcDisplay = calcDisplay:gsub("0+$",""):gsub("%.$","")
        end
        calcBuffer = calcDisplay
        table.insert(calcHistory, 1, tostring(prev).." "..calcOperator.." "..tostring(num).." = "..calcDisplay)
        if #calcHistory > 8 then table.remove(calcHistory) end
    end
    calcOperator = op
    calcNewNumber = true
end

local function calcEquals()
    if calcOperator == "" then return end
    calcDoOperation("=")
    calcBuffer   = ""
    calcOperator = ""
end

local function calcClear()
    calcDisplay   = "0"
    calcBuffer    = ""
    calcOperator  = ""
    calcNewNumber = true
    calcResult    = 0
end

local function calcBackspace()
    if calcDisplay == "0" or calcNewNumber then return end
    if #calcDisplay <= 1 then calcDisplay = "0"; calcNewNumber = true
    else calcDisplay = calcDisplay:sub(1, -2) end
end

local function calcNegate()
    local n = -(tonumber(calcDisplay) or 0)
    calcDisplay = tostring(n)
    if calcDisplay:find("%.") then calcDisplay = calcDisplay:gsub("0+$",""):gsub("%.$","") end
end

local function calcPercent()
    local n = (tonumber(calcDisplay) or 0) / 100
    calcDisplay = tostring(n)
    if calcDisplay:find("%.") then calcDisplay = calcDisplay:gsub("0+$",""):gsub("%.$","") end
end

-- IMGUI STYLE
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    fa.Init(18 * MONET_DPI_SCALE)
    local style = imgui.GetStyle()
    local clr   = imgui.Col
    local sc    = style.Colors

    style.ScrollbarSize = 18.0

    sc[clr.WindowBg]             = imgui.ImVec4(0.08, 0.09, 0.11, 0.97)
    sc[clr.TitleBg]              = imgui.ImVec4(0.05, 0.06, 0.08, 1.00)
    sc[clr.TitleBgActive]        = imgui.ImVec4(0.05, 0.06, 0.08, 1.00)
    sc[clr.Button]               = imgui.ImVec4(0.14, 0.16, 0.20, 1.00)
    sc[clr.ButtonHovered]        = imgui.ImVec4(0.20, 0.22, 0.28, 1.00)
    sc[clr.ButtonActive]         = imgui.ImVec4(0.25, 0.28, 0.35, 1.00)
    sc[clr.Text]                 = imgui.ImVec4(0.90, 0.90, 0.92, 1.00)
    sc[clr.FrameBg]              = imgui.ImVec4(0.10, 0.11, 0.14, 1.00)
    sc[clr.FrameBgHovered]       = imgui.ImVec4(0.14, 0.15, 0.19, 1.00)
    sc[clr.FrameBgActive]        = imgui.ImVec4(0.18, 0.20, 0.25, 1.00)
    sc[clr.Separator]            = imgui.ImVec4(0.18, 0.52, 0.90, 0.30)
    sc[clr.Border]               = imgui.ImVec4(0.18, 0.52, 0.90, 0.20)
    sc[clr.ChildBg]              = imgui.ImVec4(0.06, 0.07, 0.09, 0.70)
    sc[clr.Header]               = imgui.ImVec4(0.18, 0.52, 0.90, 0.25)
    sc[clr.HeaderHovered]        = imgui.ImVec4(0.18, 0.52, 0.90, 0.40)
    sc[clr.HeaderActive]         = imgui.ImVec4(0.18, 0.52, 0.90, 0.60)
    sc[clr.ScrollbarBg]          = imgui.ImVec4(0.05, 0.06, 0.07, 1.00)
    sc[clr.ScrollbarGrab]        = imgui.ImVec4(0.18, 0.52, 0.90, 0.50)
    sc[clr.ScrollbarGrabHovered] = imgui.ImVec4(0.25, 0.60, 1.00, 0.70)
    sc[clr.CheckMark]            = imgui.ImVec4(0.18, 0.52, 0.90, 1.00)
    sc[clr.SliderGrab]           = imgui.ImVec4(0.18, 0.52, 0.90, 0.80)
    sc[clr.SliderGrabActive]     = imgui.ImVec4(0.25, 0.60, 1.00, 1.00)

    style.WindowRounding    = 10.0
    style.FrameRounding     = 5.0
    style.ScrollbarRounding = 5.0
    style.GrabRounding      = 5.0
    style.PopupRounding     = 6.0
    style.ItemSpacing       = imgui.ImVec2(8, 5)
    style.ItemInnerSpacing  = imgui.ImVec2(6, 4)
    style.WindowPadding     = imgui.ImVec2(12, 10)
    style.FramePadding      = imgui.ImVec2(8, 5)
end)

-- TAB HELPER
local function drawTab(label, tabNum, width)
    local isActive = (currentTab == tabNum)
    if isActive then
        imgui.PushStyleColor(imgui.Col.Button, C.tabActive)
        imgui.PushStyleColor(imgui.Col.Text, C.accent)
    else
        imgui.PushStyleColor(imgui.Col.Button, C.tabInactive)
        imgui.PushStyleColor(imgui.Col.Text, C.textMuted)
    end
    local clicked = imgui.Button(label, imgui.ImVec2(width, 28 * MONET_DPI_SCALE))
    imgui.PopStyleColor(2)
    return clicked
end

-- TAB 1: KASIR
local function drawKasirTab()
    local ww = imgui.GetWindowWidth()

    imgui.PushStyleColor(imgui.Col.Text, C.accent)
    imgui.Text(fa.ID_BADGE .. "  ID Pelanggan")
    imgui.PopStyleColor()

    imgui.PushItemWidth(ww - 24)
    imgui.InputTextWithHint("##custName", "@ID  (contoh: @10)", kasirCustomerName, 128)
    imgui.PopItemWidth()

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.Text, C.accent)
    imgui.Text(fa.WRENCH .. "  Pilih Jenis Service")
    imgui.PopStyleColor()

    imgui.SameLine(ww - 110)
    imgui.PushStyleColor(imgui.Col.Text, C.textMuted)
    local selCount = 0
    for _, s in ipairs(serviceList) do if s.selected[0] then selCount = selCount + 1 end end
    imgui.Text(tostring(selCount) .. " dipilih")
    imgui.PopStyleColor()

    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.ChildBg, C.childBg)
    local listH = 230 * MONET_DPI_SCALE
    if imgui.BeginChild("##serviceList", imgui.ImVec2(0, listH), true) then
        local gap  = 12 * MONET_DPI_SCALE
        local colW = (ww - 40 - gap) / 2
        for i, svc in ipairs(serviceList) do
            if (i % 2) ~= 1 then imgui.SameLine(colW + gap) end

            local isSelected = svc.selected[0]
            if isSelected then
                imgui.PushStyleColor(imgui.Col.ChildBg, C.rowSelected)
            elseif math.floor(i / 2) % 2 == 0 then
                imgui.PushStyleColor(imgui.Col.ChildBg, C.rowEven)
            else
                imgui.PushStyleColor(imgui.Col.ChildBg, C.rowOdd)
            end

            if imgui.BeginChild("##svc"..i, imgui.ImVec2(colW, 36), false, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse) then
                imgui.SetCursorPosY(imgui.GetCursorPosY() + 4)
                if imgui.Checkbox("##chk"..i, svc.selected) then recalcTotal() end
                imgui.SameLine(0, 6)
                imgui.PushStyleColor(imgui.Col.Text, isSelected and C.text or C.textMuted)
                imgui.SetCursorPosY(imgui.GetCursorPosY() + 2)
                imgui.Text(svc.name)
                imgui.PopStyleColor()
                imgui.SameLine(colW - 72)
                imgui.PushStyleColor(imgui.Col.Text, isSelected and C.yellow or C.textDark)
                imgui.SetCursorPosY(imgui.GetCursorPosY() + 2)
                imgui.Text(formatCurrency(svc.price))
                imgui.PopStyleColor()
            end
            imgui.EndChild()
            imgui.PopStyleColor()
        end
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.Spacing()
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.06, 0.08, 0.12, 0.90))
    if imgui.BeginChild("##totalArea", imgui.ImVec2(0, 68), true, imgui.WindowFlags.NoScrollbar) then
        local tw = imgui.GetWindowWidth()
        imgui.SetCursorPosX(12)
        imgui.PushStyleColor(imgui.Col.Text, C.textMuted)
        imgui.Text("Subtotal")
        imgui.PopStyleColor()
        imgui.SameLine(tw - 110)
        imgui.PushStyleColor(imgui.Col.Text, C.text)
        imgui.Text(formatCurrency(kasirTotal))
        imgui.PopStyleColor()
        imgui.Separator()
        imgui.SetCursorPosX(12)
        imgui.PushStyleColor(imgui.Col.Text, C.yellow)
        imgui.Text(fa.MONEY_BILL_WAVE .. "  Total Tagihan:")
        imgui.PopStyleColor()
        imgui.SameLine(tw - 110)
        imgui.PushStyleColor(imgui.Col.Text, C.yellow)
        imgui.Text(formatCurrency(kasirGrandTotal))
        imgui.PopStyleColor()
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.Spacing()
    imgui.Spacing()

    local btnW = (ww - 36) / 3

    imgui.PushStyleColor(imgui.Col.Button, C.accentDark)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, C.accent)
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1,1,1,1))
    if imgui.Button(fa.PAPER_PLANE .. " Kirim Invoice", imgui.ImVec2(btnW, 30)) then
        local custId = ffi.string(kasirCustomerName)
        if custId == "" then custId = "@?" end
        if #getSelectedServices() > 0 then
            sampSendChat("/me menunjukkan tablet invoice kepada " .. custId .. ", total tagihan: " .. formatCurrency(kasirGrandTotal) .. ".")
            sampAddChatMessage("[Mechanic] Invoice terkirim ke " .. custId .. "!", 0x4D94FF)
        else
            sampAddChatMessage("[Mechanic] Pilih setidaknya satu service!", 0xFF6666)
        end
    end
    imgui.PopStyleColor(3)

    imgui.SameLine()

    imgui.PushStyleColor(imgui.Col.Button, C.success)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.25, 0.85, 0.55, 1.0))
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0,0,0,1))
    if imgui.Button(fa.CHECK .. " Terima Bayar", imgui.ImVec2(btnW, 30)) then
        local custId = ffi.string(kasirCustomerName)
        if custId == "" then custId = "@?" end
        if kasirGrandTotal > 0 then
            sampSendChat("/me menerima pembayaran sebesar " .. formatCurrency(kasirGrandTotal) .. " dari " .. custId .. ".")
            sampAddChatMessage("[Mechanic] Pembayaran diterima dari " .. custId .. "!", 0x33CC77)
            clearAllServices()
            kasirCustomerName = imgui.new.char[128]()
        else
            sampAddChatMessage("[Mechanic] Tidak ada tagihan!", 0xFF6666)
        end
    end
    imgui.PopStyleColor(3)

    imgui.SameLine()

    imgui.PushStyleColor(imgui.Col.Button, C.danger)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1.0, 0.3, 0.3, 1.0))
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1,1,1,1))
    if imgui.Button(fa.TRASH .. " Reset", imgui.ImVec2(btnW, 30)) then
        clearAllServices()
        kasirCustomerName = imgui.new.char[128]()
        sampAddChatMessage("[Mechanic] Keranjang direset.", 0xAAAAAA)
    end
    imgui.PopStyleColor(3)
    imgui.Spacing()
end

-- TAB 2: AUTO RP
local function drawAutoRPTab()
    local ww = imgui.GetWindowWidth()

    imgui.PushStyleColor(imgui.Col.Text, C.accent)
    imgui.Text(fa.SCREWDRIVER_WRENCH .. "  Auto RP Kerja")
    imgui.PopStyleColor()

    imgui.SameLine(ww - 150)
    imgui.PushStyleColor(imgui.Col.Text, C.textMuted)
    imgui.Text("Prefix: /me & /do")
    imgui.PopStyleColor()

    imgui.Separator()
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.ChildBg, C.childBg)
    if imgui.BeginChild("##arpList", imgui.ImVec2(0, 430 * MONET_DPI_SCALE), true) then
        local colW = (ww - 44) / 2
        for i, btn in ipairs(autoRPButtons) do
            if (i % 2 == 0) then imgui.SameLine(colW + 22) end

            imgui.PushStyleColor(imgui.Col.Button, C.accentDim)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, C.accent)
            imgui.PushStyleColor(imgui.Col.ButtonActive, C.accentDark)
            imgui.PushStyleColor(imgui.Col.Text, C.text)

            if imgui.Button(btn.label .. "##arp" .. i, imgui.ImVec2(colW, 28)) then
                local me_msg  = btn.me
                local do1_msg = btn.do1
                local do2_msg = btn.do2
                lua_thread.create(function()
                    sampSendChat("/me " .. me_msg)
                    wait(2500)
                    sampSendChat("/do " .. do1_msg)
                    wait(3000)
                    sampSendChat("/do " .. do2_msg)
                end)
                sampAddChatMessage("[AutoRP] " .. btn.label .. " dimulai...", 0x4D94FF)
            end

            imgui.PopStyleColor(4)
        end
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

-- TAB 3: KALKULATOR
local function drawKalkulatorTab()
    local ww = imgui.GetWindowWidth()
    local pad = 12
    local bw  = (ww - pad * 2 - 8 * 3) / 4
    local bh  = 36

    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.05, 0.06, 0.08, 1.0))
    if imgui.BeginChild("##calcDisplay", imgui.ImVec2(0, 60), true) then
        if calcBuffer ~= "" and calcOperator ~= "" then
            imgui.PushStyleColor(imgui.Col.Text, C.textDark)
            imgui.SetCursorPosX(8)
            imgui.Text(calcBuffer .. " " .. calcOperator)
            imgui.PopStyleColor()
        else
            imgui.Spacing()
        end
        imgui.PushStyleColor(imgui.Col.Text, C.yellow)
        local ts = imgui.CalcTextSize(calcDisplay)
        imgui.SetCursorPosX(imgui.GetWindowWidth() - ts.x - 12)
        imgui.SetCursorPosY(imgui.GetCursorPosY() - 4)
        imgui.Text(calcDisplay)
        imgui.PopStyleColor()
    end
    imgui.EndChild()
    imgui.PopStyleColor()

    imgui.Spacing()

    local row0 = {
        { label = "C",            color = C.calcClear, action = calcClear     },
        { label = fa.DELETE_LEFT, color = C.calcBtn,   action = calcBackspace },
        { label = "+/-",          color = C.calcBtn,   action = calcNegate    },
        { label = "%",            color = C.calcOp,    action = calcPercent   },
    }
    for i, btn in ipairs(row0) do
        if i > 1 then imgui.SameLine(0, 8) end
        imgui.PushStyleColor(imgui.Col.Button, btn.color)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, C.accentHover)
        if btn.color == C.calcOp or btn.color == C.calcClear then
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1,1,1,1))
        end
        if imgui.Button(btn.label.."##r0"..i, imgui.ImVec2(bw, bh)) then btn.action() end
        if btn.color == C.calcOp or btn.color == C.calcClear then
            imgui.PopStyleColor(3)
        else
            imgui.PopStyleColor(2)
        end
    end

    imgui.Spacing()

    local rows = {
        { {"7","d"}, {"8","d"}, {"9","d"}, {"/","o"} },
        { {"4","d"}, {"5","d"}, {"6","d"}, {"x","o"} },
        { {"1","d"}, {"2","d"}, {"3","d"}, {"-","o"} },
        { {"0","d"}, {".","d"}, {"=","e"}, {"+","o"} },
    }
    for ri, row in ipairs(rows) do
        for ci, cell in ipairs(row) do
            if ci > 1 then imgui.SameLine(0, 8) end
            local lbl, typ = cell[1], cell[2]
            local col = (typ=="d") and C.calcBtn or (typ=="o") and C.calcOp or C.calcEq
            imgui.PushStyleColor(imgui.Col.Button, col)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, C.accentHover)
            if typ == "o" or typ == "e" then
                imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1,1,1,1))
            end
            if imgui.Button(lbl.."##r"..ri.."c"..ci, imgui.ImVec2(bw, bh)) then
                if typ == "d" then calcInput(lbl)
                elseif typ == "o" then calcDoOperation(lbl)
                elseif typ == "e" then calcEquals() end
            end
            if typ == "o" or typ == "e" then imgui.PopStyleColor(3)
            else imgui.PopStyleColor(2) end
        end
        imgui.Spacing()
    end

    imgui.Separator()
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.Text, C.textMuted)
    imgui.Text(fa.CLOCK_ROTATE_LEFT .. " Riwayat")
    imgui.PopStyleColor()

    imgui.PushStyleColor(imgui.Col.ChildBg, C.childBg)
    if imgui.BeginChild("##calcHistory", imgui.ImVec2(0, 70), true) then
        if #calcHistory == 0 then
            imgui.PushStyleColor(imgui.Col.Text, C.textDark)
            imgui.Text("Belum ada riwayat.")
            imgui.PopStyleColor()
        else
            for _, h in ipairs(calcHistory) do
                imgui.PushStyleColor(imgui.Col.Text, C.textMuted)
                imgui.Text(h)
                imgui.PopStyleColor()
            end
        end
    end
    imgui.EndChild()
    imgui.PopStyleColor()
end

-- TAB 4: SETTINGS
local function drawSettingsTab()
    local ww = imgui.GetWindowWidth()

    imgui.PushStyleColor(imgui.Col.Text, C.accent)
    imgui.Text(fa.GEAR .. "  Pengaturan")
    imgui.PopStyleColor()
    imgui.Separator()
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.Text, C.textMuted)
    imgui.Text(fa.SACK_DOLLAR .. " Mata Uang")
    imgui.PopStyleColor()
    imgui.Spacing()

    imgui.Text("Simbol Mata Uang:")
    imgui.SameLine(160)
    imgui.PushItemWidth(80)
    imgui.InputTextWithHint("##cfg_cur", "$", cfg_currency, 16)
    imgui.PopItemWidth()

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.Text, C.textMuted)
    imgui.Text(fa.LOCK .. " Window")
    imgui.PopStyleColor()
    imgui.Spacing()
    imgui.Checkbox("Kunci posisi window", positionLocked)

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.Button, C.accent)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, C.accentHover)
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1,1,1,1))
    if imgui.Button(fa.FLOPPY_DISK .. "  Simpan Pengaturan", imgui.ImVec2(ww - 24, 32)) then
        configIni.settings.currency_symbol = ffi.string(cfg_currency)
        configIni.window.locked            = positionLocked[0]
        inicfg.save(configIni, 'mechanic_helper')
        sampAddChatMessage("[Mechanic] Pengaturan disimpan!", 0x4D94FF)
        recalcTotal()
    end
    imgui.PopStyleColor(3)

    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.12, 0.38, 0.22, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.55, 0.32, 1.0))
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1,1,1,1))
    if imgui.Button(fa.ROTATE .. "  Reload Service & AutoRP dari JSON", imgui.ImVec2(ww - 24, 28)) then
        reloadAllJSON()
    end
    imgui.PopStyleColor(3)

    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.3, 0.3, 0.35, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, C.danger)
    imgui.PushStyleColor(imgui.Col.Text, C.textMuted)
    if imgui.Button(fa.ROTATE_LEFT .. "  Reset Keranjang", imgui.ImVec2(ww - 24, 28)) then
        clearAllServices()
        kasirCustomerName = imgui.new.char[128]()
        sampAddChatMessage("[Mechanic] Keranjang direset.", 0xAAAAAA)
    end
    imgui.PopStyleColor(3)

    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.Text, C.textDark)
    imgui.TextWrapped(fa.FILE_CODE .. " Services List : " .. SERVICES_FILE)
    imgui.Spacing()
    imgui.TextWrapped(fa.FILE_CODE .. " AutoRP   : " .. AUTORP_FILE)
    imgui.Spacing()
    imgui.Spacing()
    imgui.TextWrapped(fa.INFO .. " /mekanikhelper or /mh = buka/tutup   |   /mekareload = reload JSON")
    imgui.PopStyleColor()
end

-- MAIN IMGUI FRAME
imgui.OnFrame(
    function() return MainWindow[0] end,
    function(player)
        imgui.SetNextWindowPos(
            imgui.ImVec2(configIni.window.posX, configIni.window.posY),
            imgui.Cond.FirstUseEver
        )
        imgui.SetNextWindowSize(
            imgui.ImVec2(windowWidth, windowHeight),
            imgui.Cond.Always
        )

        local flags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar
        if positionLocked[0] then flags = flags + imgui.WindowFlags.NoMove end

        imgui.Begin("Sinchan x 4trays##main", MainWindow, flags)

        if not positionLocked[0] then
            local cp = imgui.GetWindowPos()
            if math.abs(cp.x - configIni.window.posX) > 1 or
               math.abs(cp.y - configIni.window.posY) > 1 then
                configIni.window.posX = cp.x
                configIni.window.posY = cp.y
                inicfg.save(configIni, 'mechanic_helper')
            end
        end

        local ww = imgui.GetWindowWidth()
        imgui.PushStyleColor(imgui.Col.Text, C.accent)
        local titleStr = fa.SCREWDRIVER_WRENCH .. "  Mechanic Helper"
        imgui.SetCursorPosX((ww - imgui.CalcTextSize(titleStr).x) / 2)
        imgui.Text(titleStr)
        imgui.PopStyleColor()

        imgui.PushStyleColor(imgui.Col.Text, C.textMuted)
        imgui.Separator()
        imgui.Spacing()

        local tabW = (ww - 28) / 4
        if drawTab(fa.CASH_REGISTER .. " Kasir",  1, tabW) then currentTab = 1 end
        imgui.SameLine()
        if drawTab(fa.WRENCH .. " Auto RP",        2, tabW) then currentTab = 2 end
        imgui.SameLine()
        if drawTab(fa.CALCULATOR .. " Kalkulator", 3, tabW) then currentTab = 3 end
        imgui.SameLine()
        if drawTab(fa.GEAR .. " Settings",         4, tabW) then currentTab = 4 end

        imgui.Separator()
        imgui.Spacing()

        if     currentTab == 1 then drawKasirTab()
        elseif currentTab == 2 then drawAutoRPTab()
        elseif currentTab == 3 then drawKalkulatorTab()
        elseif currentTab == 4 then drawSettingsTab()
        end

        imgui.End()
    end
)

-- MAIN
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end
    if not UPDATE_CHECKED then
    lua_thread.create(checkUpdate)
end

    serviceList   = loadServicesFromJSON()
    autoRPButtons = loadAutoRPFromJSON()
    recalcTotal()

    sampRegisterChatCommand("mekanikhelper", function()
        MainWindow[0] = not MainWindow[0]
    end)

    sampRegisterChatCommand("mh", function()
        MainWindow[0] = not MainWindow[0]
    end)

    sampRegisterChatCommand("mekalock", function()
        positionLocked[0] = not positionLocked[0]
        configIni.window.locked = positionLocked[0]
        inicfg.save(configIni, 'mechanic_helper')
        local s = positionLocked[0] and "terkunci" or "tidak terkunci"
        sampAddChatMessage("[Mechanic] Posisi window " .. s, 0x4D94FF)
    end)

    sampRegisterChatCommand("mekareload", function()
        reloadAllJSON()
    end)

    sampAddChatMessage("[Mechanic Helper] {FFFFFF}Loaded! Ketik {4D94FF}/mekanikhelper {FFFFFF}atau {4D94FF}/mh {FFFFFF}untuk membuka.", 0x4D94FF)
    sampAddChatMessage("[Mechanic Helper] {FFFFFF}Ketik {4D94FF}/mekareload {FFFFFF}setelah edit JSON untuk apply tanpa restart.", 0x4D94FF)

    while true do wait(0) end
end
