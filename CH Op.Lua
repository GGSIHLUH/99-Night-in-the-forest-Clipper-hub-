--[[
    SENAR HUB  |  99 Nights in the Forest
    Alur : loading 2 menit (ada animasi) -> UI terbuka otomatis. Floating icon untuk buka/tutup UI.

    TAB
      Home                 : Mode God, Bring Speed, Bring To, Auto Get Child, Auto Bring All Child, Auto Farming Clutis
      Source & Information : Bring Source, Bring All Item, Bring Food, Bring Rabbit Legs, Bring Fuel, Bring Coal, Informations
      Player               : Speed Walk, Jump Power, Infinite Jump, Auto Cure (Bandage)
      Auto Chest           : Force ke Chest + buka, Auto Bring Item, Anti Waiting Loading Map
      Common Mele          : Kill Aura (+300), Kill Aura Work, Kill Aura Tree, Instant Kill Rabbit, Heal Player Range 10,
                             Anti Trap, Anti Trap Bear, Deer Chase TP, Infinite Tree, Infinite Ammo Gun
      Teleport             : Campfire, Stronghold, Random Player
      Cosmetic Server      : Saturnus Wood, Black Hole Metal, Bring Player To Trap Bear
      Server               : Server Hop, Server Hop Big Days

    CATATAN
      Nama objek & remote game dideteksi otomatis lewat daftar kata (lihat KW dan PAT di bawah).
      Kalau ada yang tidak terdeteksi, ubah daftar katanya.
      Big Days otomatis lanjut setelah pindah server kalau script disimpan sebagai
      SenarHub_99.lua di folder workspace executor (dipakai queue_on_teleport).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

---------------------------------------------------------------- CONFIG
local HUB_NAME     = "SENAR HUB"
local HUB_SUB      = "99 Nights in the Forest"
local DISCORD_LINK = "https://discord.gg/6VeEjrRYy"
local DISCORD_CODE = "6VeEjrRYy"
local ICON_ASSET   = "rbxassetid://96018079825546"
local PLACE_ID     = game.PlaceId
local HOP_FILE     = "SenarHub99_Hop.json"
local SCRIPT_FILE  = "SenarHub_99.lua"
local UNLOCK_WAIT  = 120                      -- detik (2 menit)
local UNLOCK_FILE  = "SenarHub99_Unlock.txt"
local UNLOCK_TTL   = 1800                     -- tidak perlu tunggu lagi selama 30 menit setelah terbuka
local CAMP_MAX_LEVEL = 4                      -- level maksimum api unggun (ubah kalau beda)

-- daftar kata nama item (huruf kecil)
local KW = {
    wood    = { "log", "wood" },
    metal   = { "metal", "scrap", "bolt", "sheet", "gear", "radio", "tyre", "tire", "washing", "fan", "microwave", "ufo" },
    diamond = { "diamond" },
    meat    = { "morsel", "meat" },
    steak   = { "steak" },
    carrot  = { "carrot" },
    corn    = { "corn" },
    foodAll = { "morsel", "meat", "steak", "carrot", "corn", "berry", "apple", "pumpkin", "chili", "cake", "stew", "soup" },
    rabbit  = { "rabbit foot", "rabbit leg", "bunny foot", "bunny leg", "rabbit" },
    bandage = { "bandage", "medkit", "med kit" },
    chest   = { "chest" },
    weapon  = { "sword", "katana", "spear", "machete", "knife", "axe", "club", "bat", "hammer", "pickaxe" },
    axe     = { "axe", "chainsaw", "pickaxe" },
    tree    = { "tree" },
    bunny   = { "bunny", "rabbit" },
    child   = { "lost child", "child", "kid" },
    fuel    = { "fuel", "canister", "biofuel", "oil" },
    coal    = { "coal" },
    trap    = { "trap" },
    bearTrap = { "bear trap", "beartrap" },
    deer    = { "deer" },
    cultist = { "cultist" },
    seed    = { "sapling", "seed" },
    gun     = { "revolver", "rifle", "gun", "pistol", "shotgun", "musket" },
}

-- daftar kata nama remote (huruf kecil)
local PAT = {
    dragStart = { "startdragging", "startdrag" },
    dragStop  = { "stopdragging", "stopdrag" },
    damage    = { "tooldamageobject", "tooldamage", "damageobject" },
    godHeal   = { "damageplayer" },
    chest     = { "openitemchest", "openchest" },
    consume   = { "consumeitem", "useitem", "eatitem" },
    child     = { "savechild", "rescuechild", "takechild", "pickupchild", "rescue" },
    heal      = { "healplayer", "healother" },
    plant     = { "plantitem", "plant" },
}

---------------------------------------------------------------- CLEANUP
local env = (getgenv and getgenv()) or _G
if env.__Senar99Cleanup then pcall(env.__Senar99Cleanup) end

---------------------------------------------------------------- GUI ROOT
local function randName(n)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local t = {}
    for i = 1, n do local k = math.random(1, #chars); t[i] = chars:sub(k, k) end
    return table.concat(t)
end

local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function corner(o, r) return make("UICorner", { CornerRadius = UDim.new(0, r) }, o) end

local gui = make("ScreenGui", {
    Name = randName(14), ResetOnSpawn = false, DisplayOrder = 999,
    IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(gui) elseif protectgui then protectgui(gui) end
end)
do
    local ok = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
    if not ok or not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end

local conns = {}
local hookLive = true
local function alive() return gui.Parent ~= nil end
local notify = function(text) end

---------------------------------------------------------------- STATE
local S = {
    god = false, bringSpeed = "Smooth", bringTo = "Campfire", child = false,
    srcType = "Wood", foodType = "Meat",
    speedOn = false, speed = 32, jumpOn = false, jump = 100, infJump = false,
    cure = false, cureBelow = 60,
    chestForce = false, chestBring = false, antiLoading = false, chestSpeed = 600,
    aura = false, aura300 = false, auraRange = 25, treeAura = false, treeRange = 30,
    killRabbit = false, healRange = false,
    tpCamp = false, tpStrong = false, tpRandom = false, tpInterval = 5,
    hopMinDay = 10,
    farmCultist = false, childAll = false, antiTrap = false, antiTrapBear = false, deerTp = false,
    auraWork = false, infTree = false, infAmmo = false, saturn = false, blackHole = false,
    cosCenter = "Above Me", cosHeight = 20, cosRadius = 10, cosCount = 60, cosSpeed = 3,
    trapTarget = "All Players",
}
local CTL = {} -- kontrol UI berdasarkan key (untuk set dari kode)

---------------------------------------------------------------- UTIL
local function lowerHas(name, list)
    local n = name:lower()
    for _, w in ipairs(list) do
        if n:find(w, 1, true) then return true end
    end
    return false
end
local function hum() local ch = LocalPlayer.Character; return ch and ch:FindFirstChildOfClass("Humanoid") end
local function hrp() local ch = LocalPlayer.Character; return ch and ch:FindFirstChild("HumanoidRootPart") end

local function rootOf(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    if inst:IsA("Tool") then return inst:FindFirstChild("Handle") or inst:FindFirstChildWhichIsA("BasePart", true) end
    return inst:FindFirstChildWhichIsA("BasePart", true)
end
local function posOf(inst)
    local p = rootOf(inst)
    return p and p.Position or nil
end
local function dist(a, b) return (a - b).Magnitude end

local function setPos(pos)
    local h = hrp()
    if h then
        h.CFrame = CFrame.new(pos)
        h.AssemblyLinearVelocity = Vector3.zero
    end
end
local function streamAround(pos)
    pcall(function() LocalPlayer:RequestStreamAroundAsync(pos, 1.5) end)
end
local function tp(pos, stream)
    if stream then streamAround(pos) end
    setPos(pos + Vector3.new(0, 4, 0))
end

local function fireAllPrompts(inst)
    if not inst then return end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            pcall(function()
                d.HoldDuration = 0
                d.RequiresLineOfSight = false
                if d.MaxActivationDistance < 30 then d.MaxActivationDistance = 30 end
            end)
            if fireproximityprompt then pcall(fireproximityprompt, d) end
        end
    end
end

---------------------------------------------------------------- REMOTE
local remoteCache, remoteMiss = {}, {}
local function findRemote(key, pats)
    local c = remoteCache[key]
    if c and c.Parent then return c end
    if remoteMiss[key] and os.clock() - remoteMiss[key] < 5 then return nil end
    remoteMiss[key] = os.clock()
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            local n = d.Name:lower()
            for _, p in ipairs(pats) do
                if n:find(p, 1, true) then
                    remoteCache[key] = d
                    return d
                end
            end
        end
    end
    return nil
end
local function callRemote(r, ...)
    if not r then return false end
    local args = table.pack(...)
    return pcall(function()
        if r:IsA("RemoteFunction") then
            return r:InvokeServer(table.unpack(args, 1, args.n))
        else
            r:FireServer(table.unpack(args, 1, args.n))
        end
    end)
end

-- tangkap format id damage dari serangan asli game (kalau executor mendukung hook)
local capturedId
if hookmetamethod and getnamecallmethod then
    pcall(function()
        local old
        local function handler(self, ...)
            if hookLive then
                local m = getnamecallmethod()
                if (m == "InvokeServer" or m == "FireServer") and typeof(self) == "Instance"
                    and self.Name:lower():find("tooldamage", 1, true)
                    and not (checkcaller and checkcaller()) then
                    local a = { ... }
                    if type(a[3]) == "string" then capturedId = a[3] end
                end
            end
            return old(self, ...)
        end
        old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(handler) or handler)
    end)
end
local function dmgId() return capturedId or ("1_" .. tostring(LocalPlayer.UserId)) end

---------------------------------------------------------------- SCAN LOKASI & ITEM
local cache = {}
local function cached(key, ttl, fn)
    local c = cache[key]
    if c and os.clock() - c.t < ttl then return c.v end
    local v = fn()
    cache[key] = { t = os.clock(), v = v }
    return v
end

local function scanFor(names, roots)
    local n = 0
    for _, root in ipairs(roots) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                n += 1
                if n % 4000 == 0 then task.wait() end
                if d:IsA("Model") or d:IsA("BasePart") then
                    if lowerHas(d.Name, names) then return d end
                end
            end
        end
    end
    return nil
end

local function mapRoots()
    local map = workspace:FindFirstChild("Map")
    local cg = map and map:FindFirstChild("Campground")
    return { cg, map, workspace }
end

local function spawnPos()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("SpawnLocation") then return d.Position end
    end
    return Vector3.new(0, 10, 0)
end

local function campInst()
    return cached("campInst", 15, function()
        return scanFor({ "mainfire", "campfire" }, mapRoots())
    end)
end
local function campPos()
    return cached("camp", 15, function()
        local p = posOf(campInst())
        return p or spawnPos()
    end)
end
local function campMaxed()
    local inst = campInst()
    if inst then
        local lv, mx
        for k, v in pairs(inst:GetAttributes()) do
            local kk = k:lower()
            if type(v) == "number" and kk:find("level", 1, true) then
                if kk:find("max", 1, true) then mx = v else lv = v end
            end
        end
        if lv and mx then return lv >= mx end
        if lv then return lv >= CAMP_MAX_LEVEL end
    end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") and d.Visible then
                local t = d.Text:lower()
                if t:find("max level", 1, true) or t:find("level max", 1, true) or t:find("max lvl", 1, true) then
                    return true
                end
            end
        end
    end
    return false
end
local function grinderPos()
    return cached("grinder", 15, function()
        local inst = scanFor({ "scrapper", "grinder" }, mapRoots())
        return posOf(inst)
    end)
end
local function strongholdPos()
    return cached("stronghold", 15, function()
        local inst = scanFor({ "stronghold" }, { workspace:FindFirstChild("Map"), workspace })
        return posOf(inst)
    end)
end

local function itemsRoot() return workspace:FindFirstChild("Items") or workspace end
local function isItemObj(i) return i:IsA("Model") or i:IsA("BasePart") or i:IsA("Tool") end

local function listItems(names, excludeNames)
    local out = {}
    for _, it in ipairs(itemsRoot():GetChildren()) do
        if isItemObj(it) and not Players:GetPlayerFromCharacter(it) then
            local nm = it.Name
            if (not names or lowerHas(nm, names)) and not (excludeNames and lowerHas(nm, excludeNames)) then
                out[#out + 1] = it
            end
        end
    end
    return out
end

---------------------------------------------------------------- BRING
local bringToken = 0

local function bringTarget()
    local t = S.bringTo
    if t == "Campfire" then return campPos() end
    if t == "Grinder" then return grinderPos() or campPos() end
    local pl = Players:FindFirstChild(t)
    if pl and pl.Character then
        local h = pl.Character:FindFirstChild("HumanoidRootPart")
        if h then return h.Position end
    end
    local h = hrp()
    return h and h.Position or campPos()
end

local function setPivot(item, pos)
    pcall(function()
        if item:IsA("Model") then item:PivotTo(CFrame.new(pos))
        elseif item:IsA("BasePart") then item.CFrame = CFrame.new(pos)
        elseif item:IsA("Tool") then
            local h = item:FindFirstChild("Handle")
            if h then h.CFrame = CFrame.new(pos) end
        end
    end)
end
local function zeroVel(item)
    pcall(function()
        if item:IsA("BasePart") then item.AssemblyLinearVelocity = Vector3.zero; item.AssemblyAngularVelocity = Vector3.zero end
        for _, d in ipairs(item:GetDescendants()) do
            if d:IsA("BasePart") then d.AssemblyLinearVelocity = Vector3.zero; d.AssemblyAngularVelocity = Vector3.zero end
        end
    end)
end

local function bringOne(item, my)
    local target = bringTarget()
    local from = posOf(item)
    if not (target and from) then return end
    target = target + Vector3.new(math.random(-40, 40) / 10, 4, math.random(-40, 40) / 10)
    local startR = findRemote("dragStart", PAT.dragStart)
    local stopR = findRemote("dragStop", PAT.dragStop)
    if startR then callRemote(startR, item) end
    local mode = S.bringSpeed
    if mode == "Instant" then
        setPivot(item, target)
    elseif mode == "Fast" then
        local steps = math.max(1, math.ceil(dist(from, target) / 150))
        for i = 1, steps do
            if my and my ~= bringToken then break end
            setPivot(item, from:Lerp(target, i / steps))
            task.wait(0.03)
        end
    else
        for i = 1, 16 do
            if my and my ~= bringToken then break end
            setPivot(item, from:Lerp(target, i / 16))
            task.wait(0.03)
        end
    end
    zeroVel(item)
    if stopR then callRemote(stopR, item) end
end

local function bringList(list, label)
    bringToken += 1
    local my = bringToken
    if #list == 0 then notify(label .. ": item tidak ditemukan"); return end
    notify(label .. ": " .. #list .. " item")
    task.spawn(function()
        local idx, active, total = 0, 0, #list
        while idx < total and my == bringToken and alive() do
            if active < 6 then
                idx += 1
                local it = list[idx]
                active += 1
                task.spawn(function()
                    if it.Parent then pcall(bringOne, it, my) end
                    active -= 1
                end)
            else
                task.wait(0.03)
            end
        end
        while active > 0 do task.wait(0.05) end
        if my == bringToken then notify(label .. " selesai") end
    end)
end

local function foodList(t)
    local map = { Meat = KW.meat, Steak = KW.steak, Carrot = KW.carrot, Corn = KW.corn, All = KW.foodAll }
    return listItems(map[t] or KW.foodAll)
end
local function sourceList(t)
    if t == "Wood" then return listItems(KW.wood) end
    if t == "Metal" then return listItems(KW.metal) end
    if t == "Diamond" then return listItems(KW.diamond) end
    local out = {}
    for _, group in ipairs({ KW.wood, KW.metal, KW.diamond }) do
        for _, it in ipairs(listItems(group)) do out[#out + 1] = it end
    end
    return out
end

---------------------------------------------------------------- GERAK PAKSA
local function forceMove(target, speed, keep)
    local h, hm = hrp(), hum()
    if not h then return false end
    local att = Instance.new("Attachment")
    att.Parent = h
    local lv = Instance.new("LinearVelocity")
    lv.Attachment0 = att
    lv.MaxForce = 1e9
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VectorVelocity = Vector3.zero
    lv.Parent = h
    local noclip = RunService.Stepped:Connect(function()
        local ch = LocalPlayer.Character
        if ch then
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end)
    if hm then pcall(function() hm:ChangeState(Enum.HumanoidStateType.Physics) end) end
    local t0, arrived = os.clock(), false
    while keep() and alive() and os.clock() - t0 < 30 do
        h = hrp()
        if not h then break end
        local d = target - h.Position
        if d.Magnitude <= math.max(4, speed * 0.02) then arrived = true; break end
        lv.VectorVelocity = d.Unit * math.min(speed, d.Magnitude / 0.05)
        task.wait()
    end
    noclip:Disconnect()
    lv:Destroy()
    att:Destroy()
    h = hrp()
    if h and arrived then
        h.CFrame = CFrame.new(target)
        h.AssemblyLinearVelocity = Vector3.zero
    end
    if hm then pcall(function() hm:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
    return arrived
end

---------------------------------------------------------------- TOOL & SERANGAN
local function pickTool(names)
    local ch, bp, hm = LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack"), hum()
    for _, w in ipairs(names) do
        for _, root in ipairs({ ch, bp }) do
            if root then
                for _, t in ipairs(root:GetChildren()) do
                    if t:IsA("Tool") and t.Name:lower():find(w, 1, true) then
                        if t.Parent ~= ch and hm then pcall(function() hm:EquipTool(t) end) end
                        return t
                    end
                end
            end
        end
    end
    if ch then
        for _, t in ipairs(ch:GetChildren()) do
            if t:IsA("Tool") then return t end
        end
    end
    return nil
end

local sigIndex -- format argumen damage yang terbukti bekerja (hasil kalibrasi)
local function damageCall(r, target, tool, part, idx)
    local id = dmgId()
    local uid = tostring(LocalPlayer.UserId)
    if idx == 1 then return callRemote(r, target, tool, id, part.CFrame)
    elseif idx == 2 then return callRemote(r, target, tool, "1_" .. uid, part.CFrame)
    elseif idx == 3 then return callRemote(r, target, tool, "2_" .. uid, part.CFrame)
    elseif idx == 4 then return callRemote(r, target, tool, id)
    elseif idx == 5 then return callRemote(r, target, tool)
    else return callRemote(r, target) end
end

local function hitTarget(target, tool)
    local r = findRemote("damage", PAT.damage)
    local part = rootOf(target)
    if not (r and part and tool) then return false end
    task.spawn(function() damageCall(r, target, tool, part, sigIndex or 1) end)
    return true
end

local function mobsInRange(range, names)
    local out = {}
    local h = hrp()
    if not h then return out end
    local chars = workspace:FindFirstChild("Characters")
    for _, m in ipairs((chars or workspace):GetChildren()) do
        if m:IsA("Model") and not Players:GetPlayerFromCharacter(m) and m ~= LocalPlayer.Character then
            local nm = m.Name
            local isChild = lowerHas(nm, KW.child)
            local okName = true
            if names then okName = lowerHas(nm, names) end
            if okName and (names or not isChild) then
                local hm = m:FindFirstChildOfClass("Humanoid")
                if not hm or hm.Health > 0 then
                    local p = posOf(m)
                    if p and dist(p, h.Position) <= range then out[#out + 1] = m end
                end
            end
        end
    end
    return out
end

---------------------------------------------------------------- FITUR: HOME
local function godLoop()
    while S.god and alive() do
        local hm = hum()
        if hm then
            if hm.Health < hm.MaxHealth then pcall(function() hm.Health = hm.MaxHealth end) end
            local r = findRemote("godHeal", PAT.godHeal)
            if r then pcall(function() r:FireServer(-1e9) end) end
        end
        task.wait(0.3)
    end
end

local function childLoop()
    while S.child and alive() do
        local h = hrp()
        local kids = {}
        local chars = workspace:FindFirstChild("Characters")
        if h and chars then
            for _, m in ipairs(chars:GetChildren()) do
                if m:IsA("Model") and lowerHas(m.Name, KW.child) and not Players:GetPlayerFromCharacter(m) then
                    local p = posOf(m)
                    if p then kids[#kids + 1] = { m = m, d = dist(p, h.Position) } end
                end
            end
        end
        table.sort(kids, function(a, b) return a.d < b.d end)
        local k = kids[1]
        if not k then
            task.wait(2)
        else
            notify("Mengambil child...")
            tp(posOf(k.m), true)
            task.wait(0.35)
            for _ = 1, 2 do
                if not k.m.Parent then break end
                fireAllPrompts(k.m)
                local r = findRemote("child", PAT.child)
                if r then callRemote(r, k.m) end
                task.wait(0.4)
            end
            local cp = campPos()
            if cp then tp(cp, true) end
            task.wait(1)
        end
    end
end

---------------------------------------------------------------- FITUR: HOME (TAMBAHAN)
local function listKids()
    local h = hrp()
    local kids = {}
    local chars = workspace:FindFirstChild("Characters")
    if h and chars then
        for _, m in ipairs(chars:GetChildren()) do
            if m:IsA("Model") and lowerHas(m.Name, KW.child) and not Players:GetPlayerFromCharacter(m) then
                local p = posOf(m)
                if p then kids[#kids + 1] = { m = m, d = dist(p, h.Position) } end
            end
        end
    end
    table.sort(kids, function(a, b) return a.d < b.d end)
    return kids
end

local function rescueChild(m)
    local p = posOf(m)
    if not p then return end
    tp(p, true)
    task.wait(0.35)
    for _ = 1, 2 do
        if not m.Parent then break end
        fireAllPrompts(m)
        local r = findRemote("child", PAT.child)
        if r then callRemote(r, m) end
        task.wait(0.4)
    end
    local cp = campPos()
    if cp then tp(cp, true) end
    task.wait(0.8)
end

local function childAllLoop()
    while S.childAll and alive() do
        if not campMaxed() then
            notify("Api unggun belum level max, Auto Bring All Child berhenti")
            S.childAll = false
            if CTL.childAll then CTL.childAll.set(false, true) end
            break
        end
        local kids = listKids()
        if #kids == 0 then
            task.wait(2)
        else
            notify("Bring all child: " .. #kids)
            for _, k in ipairs(kids) do
                if not S.childAll or not alive() then break end
                if k.m.Parent then pcall(rescueChild, k.m) end
            end
        end
    end
end

local lastNoCultist = 0
local function cultistLoop()
    while S.farmCultist and alive() do
        local h = hrp()
        local tool = pickTool(KW.weapon)
        local best, bd = nil, math.huge
        if h then
            for _, m in ipairs(mobsInRange(100000, KW.cultist)) do
                local p = posOf(m)
                if p then
                    local d = dist(p, h.Position)
                    if d < bd then best, bd = m, d end
                end
            end
        end
        if not best then
            if os.clock() - lastNoCultist > 15 then
                lastNoCultist = os.clock()
                notify("Cultist tidak ada (tunggu raid)")
            end
            task.wait(1.5)
        else
            if bd > 12 then tp(posOf(best) + Vector3.new(0, 2, 6), true) end
            if tool then
                hitTarget(best, tool)
                hitTarget(best, tool)
            else
                notify("Senjata tidak ditemukan")
                task.wait(2)
            end
            task.wait(0.12)
        end
    end
end

---------------------------------------------------------------- FITUR: PLAYER
local defaults = { speed = nil, jump = nil, useJump = nil }
table.insert(conns, RunService.Heartbeat:Connect(function()
    local hm = hum()
    if not hm then return end
    if S.speedOn then
        if defaults.speed == nil then defaults.speed = hm.WalkSpeed end
        hm.WalkSpeed = S.speed
    elseif defaults.speed ~= nil then
        hm.WalkSpeed = defaults.speed
        defaults.speed = nil
    end
    if S.jumpOn then
        if defaults.jump == nil then defaults.jump = hm.JumpPower; defaults.useJump = hm.UseJumpPower end
        hm.UseJumpPower = true
        hm.JumpPower = S.jump
    elseif defaults.jump ~= nil then
        hm.UseJumpPower = defaults.useJump ~= false
        hm.JumpPower = defaults.jump
        defaults.jump = nil
    end
end))
table.insert(conns, UserInputService.JumpRequest:Connect(function()
    if S.infJump then
        local hm = hum()
        if hm then hm:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

local function findBandage()
    local ch, bp = LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack")
    local inv = LocalPlayer:FindFirstChild("Inventory")
    for _, root in ipairs({ ch, bp, inv }) do
        if root then
            for _, t in ipairs(root:GetChildren()) do
                if lowerHas(t.Name, KW.bandage) then return t end
            end
        end
    end
    return nil
end

local lastNoBandage = 0
local function useBandage()
    local b = findBandage()
    local hm = hum()
    if b then
        if b:IsA("Tool") and hm then
            pcall(function() hm:EquipTool(b) end)
            task.wait(0.15)
            pcall(function() b:Activate() end)
        end
        local r = findRemote("consume", PAT.consume)
        if r then callRemote(r, b) end
        return true
    end
    -- tidak ada di inventory: ambil bandage terdekat dari dunia
    local h = hrp()
    if h then
        local best, bd = nil, math.huge
        for _, it in ipairs(listItems(KW.bandage)) do
            local p = posOf(it)
            if p then
                local d = dist(p, h.Position)
                if d < bd then best, bd = it, d end
            end
        end
        if best then
            local old = S.bringTo
            S.bringTo = LocalPlayer.Name
            pcall(function()
                local r = Players:FindFirstChild(LocalPlayer.Name)
                setPivot(best, h.Position + Vector3.new(0, 2, 0))
                fireAllPrompts(best)
            end)
            S.bringTo = old
            return true
        end
    end
    if os.clock() - lastNoBandage > 15 then
        lastNoBandage = os.clock()
        notify("Bandage tidak ditemukan")
    end
    return false
end

local function cureLoop()
    while S.cure and alive() do
        local hm = hum()
        if hm and hm.Health > 0 and hm.MaxHealth > 0 and (hm.Health / hm.MaxHealth) * 100 < S.cureBelow then
            useBandage()
            task.wait(1.2)
        else
            task.wait(0.3)
        end
    end
end

---------------------------------------------------------------- FITUR: AUTO CHEST
local openedChests = {}
local broughtSet = setmetatable({}, { __mode = "k" })

local function listChests()
    local out = {}
    local h = hrp()
    for _, it in ipairs(itemsRoot():GetChildren()) do
        if isItemObj(it) and lowerHas(it.Name, KW.chest) and it:GetAttribute("Opened") ~= true then
            local p = posOf(it)
            if p then out[#out + 1] = { inst = it, pos = p, d = h and dist(p, h.Position) or 0 } end
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

local function openChest(chest)
    fireAllPrompts(chest)
    local r = findRemote("chest", PAT.chest)
    if r then callRemote(r, chest) end
end

local function chestForceLoop()
    while S.chestForce and alive() do
        local target
        for _, c in ipairs(listChests()) do
            local t = openedChests[c.inst]
            if not t or os.clock() - t.time > 120 then target = c; break end
        end
        if not target then
            notify("Chest tidak ditemukan")
            task.wait(3)
        else
            if S.antiLoading then streamAround(target.pos) end
            local arrived = forceMove(target.pos + Vector3.new(0, 3, 0), S.chestSpeed, function() return S.chestForce end)
            if arrived then
                for _ = 1, 3 do
                    openChest(target.inst)
                    task.wait(0.25)
                end
                openedChests[target.inst] = { time = os.clock(), pos = target.pos }
            else
                openedChests[target.inst] = { time = os.clock(), pos = target.pos }
            end
            task.wait(0.4)
        end
    end
end

local function chestBringLoop()
    while S.chestBring and alive() do
        local centers = {}
        for _, v in pairs(openedChests) do
            if os.clock() - v.time < 45 then centers[#centers + 1] = v.pos end
        end
        local h = hrp()
        if h then
            for _, c in ipairs(listChests()) do
                if c.d <= 25 then centers[#centers + 1] = c.pos end
            end
        end
        if #centers > 0 then
            for _, it in ipairs(itemsRoot():GetChildren()) do
                if isItemObj(it) and not lowerHas(it.Name, KW.chest) and not broughtSet[it] then
                    local p = posOf(it)
                    if p then
                        for _, c in ipairs(centers) do
                            if dist(p, c) <= 18 then
                                broughtSet[it] = true
                                local my = bringToken
                                task.spawn(function() pcall(bringOne, it, my) end)
                                break
                            end
                        end
                    end
                end
            end
        end
        task.wait(1)
    end
end

---------------------------------------------------------------- FITUR: MELEE
local function auraLoop()
    while (S.aura or S.aura300) and alive() do
        local range = S.aura300 and 300 or S.auraRange
        local tool = pickTool(KW.weapon)
        if tool then
            local list = mobsInRange(range)
            for i = 1, math.min(#list, 8) do hitTarget(list[i], tool) end
        end
        task.wait(0.12)
    end
end

local treeList, treeStamp = {}, 0
local function refreshTrees()
    if os.clock() - treeStamp < 6 then return end
    treeStamp = os.clock()
    local out, n = {}, 0
    local root = workspace:FindFirstChild("Map") or workspace
    for _, d in ipairs(root:GetDescendants()) do
        n += 1
        if n % 4000 == 0 then task.wait() end
        if d:IsA("Model") and lowerHas(d.Name, KW.tree) and not Players:GetPlayerFromCharacter(d) then
            out[#out + 1] = d
        end
    end
    treeList = out
end

local function treeLoop()
    while S.treeAura and alive() do
        refreshTrees()
        local tool = pickTool(KW.axe)
        local h = hrp()
        if tool and h then
            local c = 0
            for _, t in ipairs(treeList) do
                if t.Parent then
                    local p = posOf(t)
                    if p and dist(p, h.Position) <= S.treeRange then
                        hitTarget(t, tool)
                        c += 1
                        if c >= 6 then break end
                    end
                end
            end
        end
        task.wait(0.15)
    end
end

local function rabbitLoop()
    while S.killRabbit and alive() do
        local tool = pickTool(KW.weapon)
        if tool then
            for _, m in ipairs(mobsInRange(300, KW.bunny)) do
                for _ = 1, 3 do hitTarget(m, tool) end
            end
        end
        task.wait(0.2)
    end
end

local noHealRemote = 0
local function healRangeLoop()
    while S.healRange and alive() do
        local h = hrp()
        local r = findRemote("heal", PAT.heal)
        if h and r then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LocalPlayer and pl.Character then
                    local ph = pl.Character:FindFirstChild("HumanoidRootPart")
                    local phm = pl.Character:FindFirstChildOfClass("Humanoid")
                    if ph and phm and phm.Health < phm.MaxHealth and dist(ph.Position, h.Position) <= 10 then
                        callRemote(r, pl)
                        callRemote(r, pl.Character)
                    end
                end
            end
        elseif not r and os.clock() - noHealRemote > 20 then
            noHealRemote = os.clock()
            notify("Remote heal tidak ditemukan")
        end
        task.wait(0.5)
    end
end

---------------------------------------------------------------- FITUR: MELEE (TAMBAHAN)
local function calibrateDamage(tool)
    local r = findRemote("damage", PAT.damage)
    if not r then notify("Remote damage tidak ditemukan"); return end
    local h = hrp()
    local best, bd = nil, math.huge
    if h then
        for _, m in ipairs(mobsInRange(S.aura300 and 300 or math.max(S.auraRange, 60))) do
            local p = posOf(m)
            if p then
                local d = dist(p, h.Position)
                if d < bd then best, bd = m, d end
            end
        end
    end
    if not best then notify("Dekati mob untuk kalibrasi serangan"); return end
    local hm = best:FindFirstChildOfClass("Humanoid")
    local part = rootOf(best)
    if not (hm and part) then sigIndex = 1; return end
    for idx = 1, 6 do
        local before = hm.Health
        task.spawn(function() damageCall(r, best, tool, part, idx) end)
        task.wait(0.3)
        if not best.Parent or hm.Health < before then
            sigIndex = idx
            notify("Format serangan cocok: #" .. idx)
            return
        end
    end
    notify("Kalibrasi gagal, pakai format default")
    sigIndex = 1
end

local function auraWorkLoop()
    while S.auraWork and alive() do
        local tool = pickTool(KW.weapon)
        if not tool then
            notify("Senjata tidak ditemukan")
            task.wait(2)
        else
            if not sigIndex then calibrateDamage(tool) end
            local range = S.aura300 and 300 or S.auraRange
            local list = mobsInRange(range)
            for i = 1, math.min(#list, 10) do hitTarget(list[i], tool) end
            task.wait(0.1)
        end
    end
end

local trapSet = setmetatable({}, { __mode = "k" })
local function neutralizeTrap(t)
    if trapSet[t] then return end
    trapSet[t] = true
    for _, d in ipairs(t:GetDescendants()) do
        if d:IsA("BasePart") then pcall(function() d.CanTouch = false end) end
        if d:IsA("TouchTransmitter") then pcall(function() d:Destroy() end) end
    end
    if t:IsA("BasePart") then pcall(function() t.CanTouch = false end) end
    local p = posOf(t)
    if p then
        local startR, stopR = findRemote("dragStart", PAT.dragStart), findRemote("dragStop", PAT.dragStop)
        task.spawn(function()
            if startR then callRemote(startR, t) end
            setPivot(t, p + Vector3.new(0, 400, 0))
            zeroVel(t)
            if stopR then callRemote(stopR, t) end
        end)
    end
end

local function antiTrapLoop()
    while (S.antiTrap or S.antiTrapBear) and alive() do
        local h = hrp()
        if h then
            local names = {}
            if S.antiTrap then for _, w in ipairs(KW.trap) do names[#names + 1] = w end end
            if S.antiTrapBear then for _, w in ipairs(KW.bearTrap) do names[#names + 1] = w end end
            for _, root in ipairs({ itemsRoot(), workspace:FindFirstChild("Map") }) do
                if root then
                    for _, it in ipairs(root:GetChildren()) do
                        if isItemObj(it) and lowerHas(it.Name, names) then
                            local p = posOf(it)
                            if p and dist(p, h.Position) <= 80 then neutralizeTrap(it) end
                        end
                    end
                end
            end
            local hm = hum()
            if hm and (hm.PlatformStand or hm.WalkSpeed < 1) then
                pcall(function()
                    hm.PlatformStand = false
                    h.Anchored = false
                    hm.WalkSpeed = defaults.speed or 16
                end)
            end
        end
        task.wait(0.4)
    end
end

local lastDeerTp = 0
local function deerLoop()
    while S.deerTp and alive() do
        local h = hrp()
        if h and os.clock() - lastDeerTp > 4 then
            for _, m in ipairs(mobsInRange(45, KW.deer)) do
                local r = rootOf(m)
                if r then
                    local toMe = h.Position - r.Position
                    local vel = r.AssemblyLinearVelocity
                    if vel.Magnitude > 5 and toMe.Magnitude > 0 and vel.Unit:Dot(toMe.Unit) > 0.3 then
                        lastDeerTp = os.clock()
                        local cp = campPos()
                        if cp then
                            tp(cp, true)
                            notify("Deer mengejar, TP ke Campfire")
                        end
                        break
                    end
                end
            end
        end
        task.wait(0.25)
    end
end

local function findSeedItem()
    for _, root in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack"), LocalPlayer:FindFirstChild("Inventory") }) do
        if root then
            for _, t in ipairs(root:GetChildren()) do
                if lowerHas(t.Name, KW.seed) then return t end
            end
        end
    end
    return nil
end

local lastPlantMsg = 0
local function plantLoop()
    while S.infTree and alive() do
        local r = findRemote("plant", PAT.plant)
        local seed = findSeedItem()
        local h = hrp()
        if not r then
            notify("Remote tanam tidak ditemukan")
            task.wait(5)
        elseif not seed then
            if os.clock() - lastPlantMsg > 10 then
                lastPlantMsg = os.clock()
                notify("Sapling/seed tidak ada di inventory")
            end
            task.wait(2)
        elseif h then
            local base = h.Position - Vector3.new(0, 2.5, 0)
            for i = 1, 100 do
                if not S.infTree then break end
                local pos = base + Vector3.new(math.random(-60, 60) / 10, 0, math.random(-60, 60) / 10)
                task.spawn(function()
                    callRemote(r, seed, pos)
                    callRemote(r, seed, CFrame.new(pos))
                end)
                if i % 10 == 0 then task.wait(0.05) end
            end
            notify("100 tanam dikirim")
            task.wait(3)
        else
            task.wait(1)
        end
    end
end

local function ammoLoop()
    while S.infAmmo and alive() do
        for _, root in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }) do
            if root then
                for _, t in ipairs(root:GetChildren()) do
                    if t:IsA("Tool") and lowerHas(t.Name, KW.gun) then
                        for k, v in pairs(t:GetAttributes()) do
                            if k:lower():find("ammo", 1, true) and type(v) == "number" then
                                pcall(function() t:SetAttribute(k, 999) end)
                            end
                        end
                        for _, d in ipairs(t:GetDescendants()) do
                            if (d:IsA("IntValue") or d:IsA("NumberValue")) and d.Name:lower():find("ammo", 1, true) then
                                pcall(function() d.Value = 999 end)
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.15)
    end
end

---------------------------------------------------------------- FITUR: TELEPORT
local function offOthers(except)
    for _, k in ipairs({ "tpCamp", "tpStrong", "tpRandom" }) do
        if k ~= except and CTL[k] and CTL[k].get() then CTL[k].set(false) end
    end
end

local function tpCampLoop()
    while S.tpCamp and alive() do
        local p, h = campPos(), hrp()
        if p and h and dist(h.Position, p) > 25 then tp(p, true) end
        task.wait(1)
    end
end
local function tpStrongLoop()
    while S.tpStrong and alive() do
        local p, h = strongholdPos(), hrp()
        if not p then
            notify("Stronghold tidak ditemukan")
            task.wait(3)
        else
            if h and dist(h.Position, p) > 25 then tp(p, true) end
            task.wait(1)
        end
    end
end
local function tpRandomLoop()
    while S.tpRandom and alive() do
        local list = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then list[#list + 1] = pl end
        end
        if #list == 0 then
            notify("Tidak ada player lain")
            task.wait(3)
        else
            local pl = list[math.random(1, #list)]
            tp(pl.Character.HumanoidRootPart.Position, true)
            local t0 = os.clock()
            while S.tpRandom and alive() and os.clock() - t0 < S.tpInterval do task.wait(0.2) end
        end
    end
end

---------------------------------------------------------------- FITUR: COSMETIC SERVER
local cosmetic = { conn = nil, items = {}, kind = nil, t0 = 0, phases = {} }

local function stopCosmetic()
    if cosmetic.conn then cosmetic.conn:Disconnect(); cosmetic.conn = nil end
    local stopR = findRemote("dragStop", PAT.dragStop)
    for _, it in ipairs(cosmetic.items) do
        if it.Parent and stopR then task.spawn(callRemote, stopR, it) end
    end
    cosmetic.items, cosmetic.kind = {}, nil
end

local function cosCenter()
    if S.cosCenter == "Above Campfire" then
        local c = campPos()
        if c then return c + Vector3.new(0, S.cosHeight, 0) end
    end
    local h = hrp()
    return (h and h.Position or Vector3.zero) + Vector3.new(0, S.cosHeight, 0)
end

local function startCosmetic(kind, list)
    stopCosmetic()
    local n = math.min(#list, S.cosCount)
    if n == 0 then
        notify("Item tidak ditemukan")
        return false
    end
    local startR = findRemote("dragStart", PAT.dragStart)
    local items = {}
    for i = 1, n do
        local it = list[i]
        items[i] = it
        if startR then task.spawn(callRemote, startR, it) end
        if it:IsA("BasePart") then pcall(function() it.CanCollide = false end) end
        for _, d in ipairs(it:GetDescendants()) do
            if d:IsA("BasePart") then pcall(function() d.CanCollide = false end) end
        end
    end
    cosmetic.items, cosmetic.kind, cosmetic.t0 = items, kind, os.clock()
    cosmetic.phases = {}
    for i = 1, n do cosmetic.phases[i] = { r = math.random(), a = math.random() * math.pi * 2 } end
    notify((kind == "saturn" and "Saturnus Wood: " or "Black Hole Metal: ") .. n .. " item")

    cosmetic.conn = RunService.Heartbeat:Connect(function()
        local t = os.clock() - cosmetic.t0
        local c = cosCenter()
        local n2 = #cosmetic.items
        local R, sp = S.cosRadius, S.cosSpeed
        if cosmetic.kind == "saturn" then
            local planet = math.max(1, math.floor(n2 * 0.5))
            local golden = math.pi * (3 - math.sqrt(5))
            local spin = CFrame.Angles(0, t * 0.4 * sp, 0)
            local tilt = CFrame.Angles(math.rad(22), 0, math.rad(14))
            for i, it in ipairs(cosmetic.items) do
                if it.Parent then
                    local pos
                    if i <= planet then
                        local y = 1 - ((i - 0.5) / planet) * 2
                        local rr = math.sqrt(math.max(0, 1 - y * y))
                        local th = i * golden
                        pos = c + (spin * Vector3.new(math.cos(th) * rr, y, math.sin(th) * rr)) * R
                    else
                        local k = math.max(1, n2 - planet)
                        local ang = ((i - planet) / k) * math.pi * 2 + t * sp
                        local rr = R * (1.8 + 0.25 * math.sin((i - planet) * 1.7))
                        pos = c + tilt * Vector3.new(math.cos(ang) * rr, 0, math.sin(ang) * rr)
                    end
                    setPivot(it, pos)
                    local rp = rootOf(it)
                    if rp then rp.AssemblyLinearVelocity = Vector3.zero end
                end
            end
        else
            local tilt = CFrame.Angles(math.rad(20), 0, 0)
            for i, it in ipairs(cosmetic.items) do
                if it.Parent then
                    local ph = cosmetic.phases[i]
                    local pos
                    if i <= 4 then
                        pos = c + Vector3.new(math.sin(t * 7 + i), math.cos(t * 5 + i), math.sin(t * 9 + i * 2)) * 0.9
                    else
                        local frac = (t * 0.12 * sp + ph.r) % 1
                        local rr = R * (2.2 - 1.95 * frac)
                        local ang = ph.a + t * sp * (1.2 + 2.2 * (1 - frac))
                        pos = c + tilt * Vector3.new(math.cos(ang) * rr, math.sin(t * 2 + i) * 0.7, math.sin(ang) * rr)
                    end
                    setPivot(it, pos)
                    local rp = rootOf(it)
                    if rp then rp.AssemblyLinearVelocity = Vector3.zero end
                end
            end
        end
    end)
    return true
end

local function findBearTraps()
    local out = listItems(KW.bearTrap)
    if #out == 0 then
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            n += 1
            if n % 4000 == 0 then task.wait() end
            if d:IsA("Model") and lowerHas(d.Name, KW.bearTrap) then out[#out + 1] = d end
        end
    end
    return out
end

local function bringPlayerToTrap(targetName)
    local traps = findBearTraps()
    if #traps == 0 then notify("Bear trap tidak ditemukan"); return end
    local targets = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
            and (targetName == "All Players" or pl.Name == targetName) then
            targets[#targets + 1] = pl
        end
    end
    if #targets == 0 then notify("Player target tidak ditemukan"); return end
    local startR, stopR = findRemote("dragStart", PAT.dragStart), findRemote("dragStop", PAT.dragStop)
    notify("Bear trap -> " .. #targets .. " player")
    for i, pl in ipairs(targets) do
        local trap = traps[((i - 1) % #traps) + 1]
        task.spawn(function()
            if startR then callRemote(startR, trap) end
            local t0 = os.clock()
            while os.clock() - t0 < 3 and alive() and pl.Character do
                local ph = pl.Character:FindFirstChild("HumanoidRootPart")
                if ph then
                    setPivot(trap, ph.Position - Vector3.new(0, 2.8, 0))
                    local rp = rootOf(trap)
                    if rp then rp.AssemblyLinearVelocity = Vector3.zero end
                end
                task.wait()
            end
            if stopR then callRemote(stopR, trap) end
        end)
    end
end

---------------------------------------------------------------- FITUR: SERVER
local function httpGet(url)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        local ok, res = pcall(req, { Url = url, Method = "GET" })
        if ok and res and res.Body then return res.Body end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok then return body end
    return nil
end

local function fetchServers(order, cursor)
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100%s",
        PLACE_ID, order, cursor and ("&cursor=" .. cursor) or "")
    local body = httpGet(url)
    if not body then return nil end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
    if ok then return data end
    return nil
end

local function pickServer(order, filterFn)
    local cursor, pool = nil, {}
    for _ = 1, 4 do
        local data = fetchServers(order, cursor)
        if not data or not data.data then break end
        for _, sv in ipairs(data.data) do
            if sv.id ~= game.JobId and sv.playing and sv.maxPlayers and sv.playing < sv.maxPlayers - 1
                and (not filterFn or filterFn(sv)) then
                pool[#pool + 1] = sv
            end
        end
        cursor = data.nextPageCursor
        if not cursor then break end
    end
    if #pool == 0 then return nil end
    return pool[math.random(1, #pool)]
end

local function queueResume()
    if queue_on_teleport and isfile and readfile then
        local ok, has = pcall(isfile, SCRIPT_FILE)
        if ok and has then
            local ok2, src = pcall(readfile, SCRIPT_FILE)
            if ok2 and src then pcall(queue_on_teleport, src) end
        end
    end
end

local function readHop()
    if not (isfile and readfile) then return nil end
    local ok, has = pcall(isfile, HOP_FILE)
    if not (ok and has) then return nil end
    local ok2, raw = pcall(readfile, HOP_FILE)
    if not ok2 then return nil end
    local ok3, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if ok3 and type(data) == "table" then return data end
    return nil
end
local function writeHop(tbl)
    if writefile then pcall(writefile, HOP_FILE, HttpService:JSONEncode(tbl)) end
end

local hopping = false
local function doHop(big)
    if hopping then notify("Masih mencari server..."); return end
    hopping = true
    notify(big and "Mencari server (Big Days)..." or "Mencari server...")
    local sv = pickServer(big and "Asc" or "Desc", big and function(s) return s.playing >= 1 end or nil)
    if not sv then
        hopping = false
        notify("Server tidak ditemukan / HTTP gagal")
        return
    end
    queueResume()
    notify("Pindah server (" .. sv.playing .. "/" .. sv.maxPlayers .. ")")
    local ok = pcall(function() TeleportService:TeleportToPlaceInstance(PLACE_ID, sv.id, LocalPlayer) end)
    if not ok then
        hopping = false
        notify("Teleport gagal")
    else
        task.delay(15, function() hopping = false end)
    end
end

local function getDay()
    for _, inst in ipairs({ workspace, ReplicatedStorage, Lighting }) do
        for _, k in ipairs({ "Day", "Days", "DayCount", "CurrentDay" }) do
            local v = inst:GetAttribute(k)
            if type(v) == "number" then return v end
        end
    end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") and d.Visible then
                local n = d.Text:match("[Dd]ay%s*(%d+)")
                if n then return tonumber(n) end
            end
        end
    end
    return nil
end

local function resumeBigHop()
    local data = readHop()
    if not (data and data.active) then return end
    task.spawn(function()
        local day
        for _ = 1, 20 do
            day = getDay()
            if day then break end
            task.wait(1)
        end
        if day and day >= (data.minDay or 10) then
            writeHop({ active = false })
            notify("Day " .. day .. " ditemukan, hop berhenti")
        else
            notify("Day " .. tostring(day or "?") .. " < " .. tostring(data.minDay) .. ", hop lagi...")
            task.wait(2)
            if readHop() and readHop().active then doHop(true) end
        end
    end)
end

---------------------------------------------------------------- INFORMASI
local fps = 60
table.insert(conns, RunService.RenderStepped:Connect(function(dt)
    fps = fps * 0.9 + (1 / math.max(dt, 0.001)) * 0.1
end))

local function shallowHas(names)
    for _, root in ipairs({ workspace:FindFirstChild("Characters"), workspace:FindFirstChild("Map"), workspace }) do
        if root then
            for _, ch in ipairs(root:GetChildren()) do
                if lowerHas(ch.Name, names) then return true end
            end
        end
    end
    return false
end

local function invCount(pl)
    local n = 0
    local bp = pl:FindFirstChild("Backpack")
    if bp then n += #bp:GetChildren() end
    if pl.Character then
        for _, t in ipairs(pl.Character:GetChildren()) do
            if t:IsA("Tool") then n += 1 end
        end
    end
    local inv = pl:FindFirstChild("Inventory")
    if inv then n += #inv:GetChildren() end
    return n
end

local function buildInfo()
    local lines = {}
    local function add(k, v) lines[#lines + 1] = "[" .. k .. ": " .. tostring(v) .. "]" end
    add("Alien Event", cached("alien", 4, function() return shallowHas({ "alien", "ufo", "mothership" }) end) and "Yes" or "No")
    add("Clutis Raid In", cached("raid", 4, function() return shallowHas({ "cultist" }) end) and "Now" or "Next Day")
    add("Biome Ice", cached("ice", 5, function() return shallowHas({ "ice", "snow", "frozen", "tundra", "glacier" }) end) and "Yes" or "No")
    add("Biome Jungle", cached("jungle", 5, function() return shallowHas({ "jungle", "tropic" }) end) and "Yes" or "No")
    local hm = hum()
    if hm and hm.MaxHealth > 0 then
        local pct = math.floor(hm.Health / hm.MaxHealth * 100 + 0.5)
        add("Health Player", pct >= 99 and "Full" or (pct .. "%"))
    else
        add("Health Player", "-")
    end
    add("Wood all In Server", #listItems(KW.wood))
    add("Metal all In Server", #listItems(KW.metal))
    local day = cached("day", 5, getDay)
    add("Day", day or "-")
    lines[#lines + 1] = "[All Inventory player In server]"
    for _, pl in ipairs(Players:GetPlayers()) do
        lines[#lines + 1] = "   " .. pl.Name .. ": " .. invCount(pl)
    end
    local ping = 0
    pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
    if ping == 0 then pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5) end) end
    add("ping", ping .. "ms")
    add("Fps", math.floor(fps + 0.5))
    return table.concat(lines, "\n")
end

---------------------------------------------------------------- UI: GAYA NOTHING
local C = {
    BG = Color3.fromRGB(22, 22, 22), SIDE = Color3.fromRGB(18, 18, 18), BANNER = Color3.fromRGB(14, 14, 14),
    BOX = Color3.fromRGB(28, 28, 28), ROW = Color3.fromRGB(38, 38, 38), FIELD = Color3.fromRGB(20, 20, 20),
    STROKE = Color3.fromRGB(48, 48, 48), TEXT = Color3.fromRGB(235, 235, 235), SUB = Color3.fromRGB(135, 135, 135),
    FILL = Color3.fromRGB(150, 150, 150), TRACK = Color3.fromRGB(56, 56, 56), ON = Color3.fromRGB(232, 232, 232),
}
local function stroke(o, col, th)
    return make("UIStroke", { Color = col or C.STROKE, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function tween(o, info, props)
    local tw = TweenService:Create(o, info, props)
    tw:Play()
    return tw
end
local function isPress(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local W, H = 700, 380
local SIDE_W, HEAD_H, RIGHT_W = 180, 52, 176

local holder = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Visible = false,
}, gui)
local uiScale = make("UIScale", { Scale = 1 }, holder)
local fitMul, userMul = 1, 1
local function maxTotal()
    local cam = workspace.CurrentCamera
    if not cam then return 1.5 end
    local vp = cam.ViewportSize
    return math.min(vp.X / (W + 10), vp.Y / (H + 10), 1.8)
end
local function applyScale() uiScale.Scale = math.clamp(fitMul * userMul, 0.4, math.max(0.4, maxTotal())) end
local function updateFit()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    fitMul = math.clamp(math.min(vp.X / (W + 30), vp.Y / (H + 30)), 0.45, 1)
    applyScale()
end
updateFit()
if workspace.CurrentCamera then
    table.insert(conns, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateFit))
end

local main = make("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.BG, BorderSizePixel = 0, ClipsDescendants = true,
}, holder)
corner(main, 8)
stroke(main, C.STROKE, 1.2)
local popScale = make("UIScale", { Scale = 1 }, main)

-- toast
local toastLbl = make("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(SIDE_W + (W - SIDE_W) / 2, H + 40),
    Size = UDim2.fromOffset(300, 26), BackgroundColor3 = C.BOX, BorderSizePixel = 0, Text = "",
    TextColor3 = C.TEXT, Font = Enum.Font.GothamMedium, TextSize = 11, Visible = false, ZIndex = 120,
}, main)
corner(toastLbl, 6)
stroke(toastLbl, C.FILL, 1)
local toastId = 0
notify = function(text)
    toastId += 1
    local id = toastId
    toastLbl.Text = tostring(text)
    toastLbl.Position = UDim2.fromOffset(SIDE_W + (W - SIDE_W) / 2, H + 40)
    toastLbl.Visible = true
    tween(toastLbl, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.fromOffset(SIDE_W + (W - SIDE_W) / 2, H - 10) })
    task.delay(2.6, function()
        if id ~= toastId or not toastLbl.Parent then return end
        tween(toastLbl, TweenInfo.new(0.2), { Position = UDim2.fromOffset(SIDE_W + (W - SIDE_W) / 2, H + 40) })
        task.delay(0.22, function()
            if id == toastId and toastLbl.Parent then toastLbl.Visible = false end
        end)
    end)
end

-- popup dropdown
local popup = make("Frame", {
    Size = UDim2.fromOffset(120, 40), BackgroundColor3 = C.BOX, BorderSizePixel = 0, Visible = false, ZIndex = 110,
}, main)
corner(popup, 6)
stroke(popup, C.FILL, 1)
local popList = make("ScrollingFrame", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
    ScrollBarImageColor3 = C.FILL, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
}, popup)
make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, popList)
make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, popList)
local popCatcher = make("TextButton", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 100,
}, main)
local function closePopup() popup.Visible = false; popCatcher.Visible = false end
popCatcher.Activated:Connect(closePopup)
local function openPopup(anchor, options, current, onPick)
    for _, ch in ipairs(popList:GetChildren()) do
        if ch:IsA("TextButton") then ch:Destroy() end
    end
    local k = math.max(main.AbsoluteSize.X / W, 0.01)
    local ap = (anchor.AbsolutePosition - main.AbsolutePosition) / k
    local aw, ah = anchor.AbsoluteSize.X / k, anchor.AbsoluteSize.Y / k
    local pw = math.max(aw, 130)
    local ph = math.min(#options * 26 + 10, 150)
    local x = math.clamp(ap.X + aw / 2 - pw / 2, 6, W - pw - 6)
    local y = ap.Y + ah + 3
    if y + ph > H - 6 then y = ap.Y - ph - 3 end
    popup.Position = UDim2.fromOffset(x, math.max(y, 4))
    popup.Size = UDim2.fromOffset(pw, ph)
    for i, opt in ipairs(options) do
        local sel = (opt == current)
        local b = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.ROW, BackgroundTransparency = sel and 0 or 1,
            BorderSizePixel = 0, Text = opt, TextColor3 = sel and C.TEXT or C.SUB,
            Font = Enum.Font.GothamMedium, TextSize = 11, AutoButtonColor = false, LayoutOrder = i,
        }, popList)
        corner(b, 5)
        b.Activated:Connect(function()
            closePopup()
            onPick(opt)
        end)
    end
    popCatcher.Visible = true
    popup.Visible = true
end

-- sidebar
local side = make("Frame", { Size = UDim2.fromOffset(SIDE_W, H), BackgroundColor3 = C.SIDE, BorderSizePixel = 0 }, main)
make("Frame", { Position = UDim2.fromOffset(SIDE_W - 1, 0), Size = UDim2.fromOffset(1, H), BackgroundColor3 = C.STROKE, BorderSizePixel = 0 }, side)
local banner = make("Frame", { Size = UDim2.fromOffset(SIDE_W - 1, 84), BackgroundColor3 = C.BANNER, BorderSizePixel = 0, Active = true }, side)
make("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = HUB_NAME, TextColor3 = Color3.fromRGB(225, 225, 225),
    Font = Enum.Font.Code, TextSize = 24,
}, banner)
make("Frame", { Position = UDim2.fromOffset(0, 83), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.STROKE, BorderSizePixel = 0 }, banner)

local tabScroll = make("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 90), Size = UDim2.fromOffset(SIDE_W - 1, H - 94), BackgroundTransparency = 1,
    BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.FILL,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
}, side)
make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, tabScroll)
make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2) }, tabScroll)

-- header
local header = make("Frame", {
    Position = UDim2.fromOffset(SIDE_W, 0), Size = UDim2.fromOffset(W - SIDE_W, HEAD_H), BackgroundTransparency = 1, Active = true,
}, main)
make("TextLabel", {
    Position = UDim2.fromOffset(16, 7), Size = UDim2.fromOffset(300, 22), BackgroundTransparency = 1, Text = HUB_NAME,
    TextColor3 = C.TEXT, Font = Enum.Font.GothamBlack, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
}, header)
make("TextLabel", {
    Position = UDim2.fromOffset(16, 30), Size = UDim2.fromOffset(300, 14), BackgroundTransparency = 1, Text = HUB_SUB,
    TextColor3 = C.SUB, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
}, header)
make("Frame", { Position = UDim2.fromOffset(SIDE_W, HEAD_H), Size = UDim2.fromOffset(W - SIDE_W, 1), BackgroundColor3 = C.STROKE, BorderSizePixel = 0 }, main)
local closeBtn = make("TextButton", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W - 28, 26), Size = UDim2.fromOffset(32, 32),
    BackgroundTransparency = 1, Text = "X", TextColor3 = C.SUB, Font = Enum.Font.GothamBold, TextSize = 18,
    AutoButtonColor = false, ZIndex = 50,
}, main)

-- tab & halaman
local tabs, tabOrder = {}, 0
local currentTab

local function selectTab(t)
    currentTab = t
    closePopup()
    for _, o in ipairs(tabs) do
        local on = (o == t)
        o.page.Visible = on
        o.btn.BackgroundTransparency = on and 0 or 1
        o.bar.Visible = on
        o.title.TextColor3 = on and C.TEXT or C.SUB
    end
    t.page.Position = UDim2.fromOffset(SIDE_W + 14, HEAD_H + 1)
    tween(t.page, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(SIDE_W, HEAD_H + 1) })
end

local function sectionAPI(body)
    local api = {}

    function api.Toggle(name, default, cb, key)
        local row = make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 }, body)
        make("TextLabel", {
            Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1, Text = name, TextColor3 = C.TEXT,
            Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
        }, row)
        local track = make("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(36, 18),
            BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        }, row)
        corner(track, 9)
        local knob = make("Frame", { Size = UDim2.fromOffset(12, 12), BorderSizePixel = 0 }, track)
        corner(knob, 6)
        local on = default and true or false
        local function paint(anim)
            local pos = on and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)
            local tc = on and C.ON or C.TRACK
            local kc = on and C.BG or C.FILL
            if anim then
                tween(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Position = pos, BackgroundColor3 = kc })
                tween(track, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { BackgroundColor3 = tc })
            else
                knob.Position = pos; knob.BackgroundColor3 = kc; track.BackgroundColor3 = tc
            end
        end
        paint(false)
        local ctl = {}
        function ctl.get() return on end
        function ctl.set(v, silent)
            on = v and true or false
            paint(true)
            if cb and not silent then
                local ok, err = pcall(cb, on)
                if not ok then warn("[Senar99] " .. name .. ": " .. tostring(err)) end
            end
        end
        track.Activated:Connect(function() ctl.set(not on) end)
        if key then CTL[key] = ctl end
        return ctl
    end

    function api.Button(name, cb)
        local b = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.ROW, BorderSizePixel = 0, Text = name, TextColor3 = C.TEXT,
            Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false,
        }, body)
        corner(b, 5)
        stroke(b, C.STROKE, 1)
        b.MouseEnter:Connect(function() tween(b, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(48, 48, 48) }) end)
        b.MouseLeave:Connect(function() tween(b, TweenInfo.new(0.12), { BackgroundColor3 = C.ROW }) end)
        b.Activated:Connect(function()
            tween(b, TweenInfo.new(0.08), { BackgroundColor3 = Color3.fromRGB(64, 64, 64) })
            task.delay(0.1, function() if b.Parent then tween(b, TweenInfo.new(0.12), { BackgroundColor3 = C.ROW }) end end)
            if cb then task.spawn(function()
                local ok, err = pcall(cb)
                if not ok then warn("[Senar99] " .. name .. ": " .. tostring(err)) end
            end) end
        end)
        return b
    end

    function api.Slider(name, min, max, default, step, cb, key)
        local row = make("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }, body)
        make("TextLabel", {
            Size = UDim2.new(1, -60, 0, 18), BackgroundTransparency = 1, Text = name, TextColor3 = C.TEXT,
            Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        local valLbl = make("TextLabel", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(60, 18),
            BackgroundTransparency = 1, TextColor3 = C.SUB, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right,
        }, row)
        local bar = make("Frame", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = C.TRACK, BorderSizePixel = 0 }, row)
        corner(bar, 3)
        local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.FILL, BorderSizePixel = 0 }, bar)
        corner(fill, 3)
        local hit = make("TextButton", {
            Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "",
            AutoButtonColor = false, ZIndex = 5,
        }, row)
        local value = default
        local ctl = {}
        local function render(v)
            fill.Size = UDim2.fromScale((max > min) and (v - min) / (max - min) or 0, 1)
            valLbl.Text = string.format("%g", v) .. "/" .. string.format("%g", max)
        end
        function ctl.get() return value end
        function ctl.set(v, silent)
            v = tonumber(v) or min
            v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
            local changed = (v ~= value)
            value = v
            render(v)
            if cb and (changed or silent == true) then pcall(cb, v) end
        end
        local dragging, sf = false, nil
        local function setX(x)
            local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
            ctl.set(min + (max - min) * rel)
        end
        hit.InputBegan:Connect(function(i)
            if isPress(i) then
                dragging = true
                sf = row:FindFirstAncestorOfClass("ScrollingFrame")
                if sf then sf.ScrollingEnabled = false end
                setX(i.Position.X)
            end
        end)
        table.insert(conns, UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                setX(i.Position.X)
            end
        end))
        table.insert(conns, UserInputService.InputEnded:Connect(function(i)
            if dragging and isPress(i) then
                dragging = false
                if sf then sf.ScrollingEnabled = true end
            end
        end))
        render(value)
        if cb then pcall(cb, value) end
        if key then CTL[key] = ctl end
        return ctl
    end

    function api.Dropdown(name, options, default, cb, key)
        local row = make("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1 }, body)
        make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = name, TextColor3 = C.TEXT,
            Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        local box = make("TextButton", {
            Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.FIELD,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false,
        }, row)
        corner(box, 5)
        stroke(box, C.STROKE, 1)
        local lbl = make("TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", TextColor3 = C.SUB,
            Font = Enum.Font.Gotham, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
        }, box)
        local value = default
        local ctl = {}
        function ctl.get() return value end
        function ctl.set(v, silent)
            value = v
            lbl.Text = tostring(v)
            if cb and not silent then pcall(cb, v) end
        end
        box.Activated:Connect(function()
            local opts = type(options) == "function" and options() or options
            openPopup(box, opts, value, function(opt) ctl.set(opt) end)
        end)
        lbl.Text = tostring(default)
        if cb then pcall(cb, default) end
        if key then CTL[key] = ctl end
        return ctl
    end

    function api.Label(text)
        local l = make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = text,
            TextColor3 = C.TEXT, Font = Enum.Font.GothamMedium, TextSize = 11, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        }, body)
        return l
    end
    return api
end

local function newSection(column, title)
    local box = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.BOX, BorderSizePixel = 0 }, column)
    corner(box, 6)
    stroke(box, C.STROKE, 1)
    make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, box)
    local head = make("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 0 }, box)
    make("TextLabel", {
        Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(16, 28), BackgroundTransparency = 1, Text = "::",
        TextColor3 = C.SUB, Font = Enum.Font.GothamBold, TextSize = 12,
    }, head)
    make("TextLabel", {
        Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -34, 1, 0), BackgroundTransparency = 1, Text = title,
        TextColor3 = C.TEXT, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    }, head)
    make("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.STROKE, BorderSizePixel = 0, LayoutOrder = 1 }, box)
    local body = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 }, box)
    make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    make("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, body)
    return sectionAPI(body)
end

local function newColumn(parent, pos, size)
    local col = make("ScrollingFrame", {
        Position = pos, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.FILL, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
    }, parent)
    make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, col)
    make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingRight = UDim.new(0, 4) }, col)
    return col
end

local function newTab(name, sub, glyph, hasRight)
    tabOrder += 1
    local page = make("Frame", {
        Position = UDim2.fromOffset(SIDE_W, HEAD_H + 1), Size = UDim2.fromOffset(W - SIDE_W, H - HEAD_H - 1),
        BackgroundTransparency = 1, Visible = false,
    }, main)
    local pw, ph = W - SIDE_W, H - HEAD_H - 1
    local left = newColumn(page, UDim2.fromOffset(8, 0),
        hasRight and UDim2.fromOffset(pw - RIGHT_W - 24, ph) or UDim2.fromOffset(pw - 16, ph))
    local right
    if hasRight then right = newColumn(page, UDim2.fromOffset(pw - RIGHT_W - 8, 0), UDim2.fromOffset(RIGHT_W, ph)) end

    local btn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = Color3.fromRGB(30, 30, 30), BackgroundTransparency = 1,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = tabOrder,
    }, tabScroll)
    corner(btn, 6)
    local bar = make("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -3, 0.5, 0), Size = UDim2.fromOffset(3, 22),
        BackgroundColor3 = C.TEXT, BorderSizePixel = 0, Visible = false,
    }, btn)
    corner(bar, 2)
    local icon = make("Frame", { Position = UDim2.fromOffset(8, 9), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(34, 34, 34), BorderSizePixel = 0 }, btn)
    corner(icon, 7)
    stroke(icon, C.STROKE, 1)
    make("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = glyph, TextColor3 = C.TEXT,
        Font = Enum.Font.GothamBold, TextSize = 13,
    }, icon)
    local title = make("TextLabel", {
        Position = UDim2.fromOffset(46, 8), Size = UDim2.new(1, -56, 0, 16), BackgroundTransparency = 1, Text = name,
        TextColor3 = C.SUB, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, btn)
    make("TextLabel", {
        Position = UDim2.fromOffset(46, 25), Size = UDim2.new(1, -56, 0, 14), BackgroundTransparency = 1, Text = sub,
        TextColor3 = Color3.fromRGB(95, 95, 95), Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, btn)

    local t = { page = page, btn = btn, bar = bar, title = title }
    tabs[#tabs + 1] = t
    btn.Activated:Connect(function() selectTab(t) end)

    local function sec(col, nm) return newSection(col, nm) end
    t.L = function(nm) return sec(left, nm) end
    t.R = function(nm) return sec(right, nm) end
    return t
end

---------------------------------------------------------------- ISI TAB
local running = {}
local function runLoop(name, fn)
    if running[name] then return end
    running[name] = true
    task.spawn(function()
        local ok, err = pcall(fn)
        if not ok then warn("[Senar99] " .. name .. ": " .. tostring(err)) end
        running[name] = nil
    end)
end

local copyDiscord -- diisi di bagian gate

-- 1. HOME
do
    local t = newTab("Home", "main features", "H", true)
    local a = t.L("Player Mode")
    a.Toggle("Mode God", false, function(v) S.god = v; if v then runLoop("god", godLoop) end end)
    local b = t.L("Bring Settings")
    b.Dropdown("Bring Speed", { "Smooth", "Fast", "Instant" }, "Smooth", function(v) S.bringSpeed = v end)
    b.Dropdown("Bring To", function()
        local o = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer then o[#o + 1] = pl.Name end
        end
        o[#o + 1] = "Campfire"
        o[#o + 1] = "Grinder"
        return o
    end, "Campfire", function(v) S.bringTo = v end)
    local c = t.L("Children")
    c.Toggle("Auto Get Child", false, function(v) S.child = v; if v then runLoop("child", childLoop) end end)
    c.Toggle("Auto Bring All Child (Campfire Max)", false, function(v)
        if v and not campMaxed() then
            notify("Terkunci: level api unggun belum max")
            if CTL.childAll then CTL.childAll.set(false, true) end
            return
        end
        S.childAll = v
        if v then runLoop("childAll", childAllLoop) end
    end, "childAll")
    local f = t.L("Farming")
    f.Toggle("Auto Farming Clutis", false, function(v) S.farmCultist = v; if v then runLoop("cultist", cultistLoop) end end)
    local info = t.R("Information")
    info.Label("UI by Senar Hub")
    info.Button("Discord", function()
        if copyDiscord then copyDiscord() end
    end)
end

-- 2. SOURCE & INFORMATION
local infoLabel
local infoTab
do
    local t = newTab("Source & Information", "items & server info", "S", true)
    infoTab = t
    local a = t.L("Bring Source")
    a.Dropdown("Source", { "Wood", "Metal", "Diamond", "All" }, "Wood", function(v) S.srcType = v end)
    a.Button("Bring Source", function() bringList(sourceList(S.srcType), "Bring " .. S.srcType) end)
    local b = t.L("Bring All Item")
    b.Button("Bring All Item in Server", function()
        bringList(listItems(nil, KW.chest), "Bring All")
    end)
    local c = t.L("Bring Food")
    c.Dropdown("Food", { "Meat", "Steak", "Carrot", "Corn", "All" }, "Meat", function(v) S.foodType = v end)
    c.Button("Bring Food", function() bringList(foodList(S.foodType), "Bring " .. S.foodType) end)
    local d = t.L("Rabbit")
    d.Button("Bring Rabbit Legs", function() bringList(listItems(KW.rabbit), "Bring Rabbit Legs") end)
    local e = t.L("Fuel & Coal")
    e.Button("Bring Fuel", function() bringList(listItems(KW.fuel), "Bring Fuel") end)
    e.Button("Bring Coal", function() bringList(listItems(KW.coal), "Bring Coal") end)
    local info = t.R("Informations")
    infoLabel = info.Label("Memuat...")
end

-- 3. PLAYER
do
    local t = newTab("Player", "movement & heal", "P", false)
    local a = t.L("Movement")
    a.Toggle("Speed Walk", false, function(v) S.speedOn = v end)
    a.Slider("Walk Speed", 16, 200, 32, 1, function(v) S.speed = v end)
    a.Toggle("Jumppower", false, function(v) S.jumpOn = v end)
    a.Slider("Jump Power", 50, 300, 100, 1, function(v) S.jump = v end)
    a.Toggle("Infinite Jump", false, function(v) S.infJump = v end)
    local b = t.L("Heal")
    b.Toggle("Auto Cure (Use Bandage)", false, function(v) S.cure = v; if v then runLoop("cure", cureLoop) end end)
    b.Slider("Cure Below (%)", 10, 100, 60, 5, function(v) S.cureBelow = v end)
end

-- 4. AUTO CHEST
do
    local t = newTab("Auto Chest", "chest automation", "C", false)
    local a = t.L("Chest")
    a.Toggle("Force To Chest & Open", false, function(v) S.chestForce = v; if v then runLoop("chestForce", chestForceLoop) end end)
    a.Slider("Force Speed", 100, 1000, 600, 10, function(v) S.chestSpeed = v end)
    a.Toggle("Auto Bring Item In Chest", false, function(v) S.chestBring = v; if v then runLoop("chestBring", chestBringLoop) end end)
    a.Toggle("Anti Waiting For Loading Map", false, function(v) S.antiLoading = v end)
end

-- 5. COMMON MELE
do
    local t = newTab("Common Mele", "combat", "M", false)
    local a = t.L("Kill Aura")
    a.Toggle("Kill Aura", false, function(v) S.aura = v; if v then runLoop("aura", auraLoop) end end)
    a.Slider("Aura Range", 10, 300, 25, 5, function(v) S.auraRange = v end)
    a.Toggle("Kill Aura Range 300", false, function(v) S.aura300 = v; if v then runLoop("aura", auraLoop) end end)
    local b = t.L("Tree & Rabbit")
    b.Toggle("Kill Aura Tree", false, function(v) S.treeAura = v; if v then runLoop("tree", treeLoop) end end)
    b.Slider("Tree Range", 10, 100, 30, 5, function(v) S.treeRange = v end)
    b.Toggle("Instant Kill Rabbit", false, function(v) S.killRabbit = v; if v then runLoop("rabbit", rabbitLoop) end end)
    local c = t.L("Support")
    c.Toggle("Heals Player In Range 10", false, function(v) S.healRange = v; if v then runLoop("heal", healRangeLoop) end end)
    local d = t.L("Protection")
    d.Toggle("Anti Trap", false, function(v) S.antiTrap = v; if v then runLoop("antiTrap", antiTrapLoop) end end)
    d.Toggle("Anti Trap Bear", false, function(v) S.antiTrapBear = v; if v then runLoop("antiTrap", antiTrapLoop) end end)
    d.Toggle("When Deer Chase Tp To Campfire", false, function(v) S.deerTp = v; if v then runLoop("deer", deerLoop) end end)
    local e = t.L("Aura Work")
    e.Toggle("Kill Aura Work", false, function(v) S.auraWork = v; if v then runLoop("auraWork", auraWorkLoop) end end)
    e.Button("Recalibrate Attack", function()
        sigIndex = nil
        notify("Kalibrasi ulang dilakukan saat Kill Aura Work aktif")
    end)
    local f = t.L("Plant & Gun")
    f.Toggle("Infinite Tree (1 -> 100)", false, function(v) S.infTree = v; if v then runLoop("plant", plantLoop) end end)
    f.Toggle("Infinite Ammo Gun", false, function(v) S.infAmmo = v; if v then runLoop("ammo", ammoLoop) end end)
end

-- 6. TELEPORT
do
    local t = newTab("Teleport", "auto teleport", "T", false)
    local a = t.L("Auto Teleport")
    a.Toggle("Auto Tp To Campfire", false, function(v)
        S.tpCamp = v
        if v then offOthers("tpCamp"); runLoop("tpCamp", tpCampLoop) end
    end, "tpCamp")
    a.Toggle("Auto Tp To Stronghold", false, function(v)
        S.tpStrong = v
        if v then offOthers("tpStrong"); runLoop("tpStrong", tpStrongLoop) end
    end, "tpStrong")
    a.Toggle("Auto Tp To Random Player", false, function(v)
        S.tpRandom = v
        if v then offOthers("tpRandom"); runLoop("tpRandom", tpRandomLoop) end
    end, "tpRandom")
    a.Slider("Random Interval (detik)", 1, 30, 5, 1, function(v) S.tpInterval = v end)
end

-- 7. COSMETIC SERVER
do
    local t = newTab("Cosmetic Server", "visual server", "K", false)
    local a = t.L("Saturnus Wood")
    a.Toggle("Saturnus Wood", false, function(v)
        S.saturn = v
        if v then
            if CTL.blackHole and CTL.blackHole.get() then CTL.blackHole.set(false) end
            startCosmetic("saturn", listItems(KW.wood))
        elseif cosmetic.kind == "saturn" then
            stopCosmetic()
        end
    end, "saturn")
    local b = t.L("Black Hole Metal")
    b.Toggle("Black Hole Metal", false, function(v)
        S.blackHole = v
        if v then
            if CTL.saturn and CTL.saturn.get() then CTL.saturn.set(false) end
            startCosmetic("blackhole", listItems(KW.metal))
        elseif cosmetic.kind == "blackhole" then
            stopCosmetic()
        end
    end, "blackHole")
    local c = t.L("Cosmetic Settings")
    c.Dropdown("Center", { "Above Me", "Above Campfire" }, "Above Me", function(v) S.cosCenter = v end)
    c.Slider("Height", 8, 50, 20, 1, function(v) S.cosHeight = v end)
    c.Slider("Radius", 4, 30, 10, 1, function(v) S.cosRadius = v end)
    c.Slider("Item Count", 10, 100, 60, 5, function(v) S.cosCount = v end)
    c.Slider("Rotation Speed", 1, 10, 3, 1, function(v) S.cosSpeed = v end)
    local d = t.L("Bring Player To Trap Bear")
    d.Dropdown("Target Player", function()
        local o = { "All Players" }
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer then o[#o + 1] = pl.Name end
        end
        return o
    end, "All Players", function(v) S.trapTarget = v end)
    d.Button("Bring Player To Trap Bear", function() bringPlayerToTrap(S.trapTarget) end)
    d.Label("Bear trap dipindah ke posisi player target (player lain tidak bisa dipindah dari client).")
end

-- 8. SERVER
do
    local t = newTab("Server", "server hop", "V", false)
    local a = t.L("Server Hop")
    a.Button("Server Hop", function() doHop(false) end)
    a.Slider("Min Day (Big Days)", 1, 99, 10, 1, function(v) S.hopMinDay = v end)
    a.Button("Server Hop Big Days", function()
        writeHop({ active = true, minDay = S.hopMinDay })
        doHop(true)
    end)
    a.Button("Stop Big Days Hop", function()
        writeHop({ active = false })
        notify("Big Days hop dihentikan")
    end)
    a.Label("Big Days lanjut otomatis setelah pindah server jika script disimpan sebagai SenarHub_99.lua di folder workspace executor.")
end

-- loop update informasi
task.spawn(function()
    while alive() do
        if currentTab == infoTab and holder.Visible then
            local ok, txt = pcall(buildInfo)
            if ok and infoLabel then infoLabel.Text = txt end
        end
        task.wait(1)
    end
end)

---------------------------------------------------------------- DRAG, CLOSE, RESIZE
local function attachDrag(frame)
    local dragging, startMouse, startPos
    frame.InputBegan:Connect(function(i)
        if isPress(i) then dragging, startMouse, startPos = true, i.Position, holder.Position end
    end)
    table.insert(conns, UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = (i.Position - startMouse) / uiScale.Scale
            holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    table.insert(conns, UserInputService.InputEnded:Connect(function(i)
        if isPress(i) then dragging = false end
    end))
end
attachDrag(header)
attachDrag(banner)

local opened = false
local function setOpen(state)
    opened = state
    if state then
        holder.Visible = true
        popScale.Scale = 0.88
        tween(popScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
    else
        closePopup()
        tween(popScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.88 })
        task.delay(0.16, function()
            if not opened and holder.Parent then holder.Visible = false end
        end)
    end
end
closeBtn.Activated:Connect(function() setOpen(false) end)

do
    local grip = make("TextButton", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromOffset(W - 2, H - 2), Size = UDim2.fromOffset(22, 22),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 60,
    }, main)
    for i = 0, 2 do
        local cc = 19 - i * 6
        make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cc, cc), Size = UDim2.fromOffset(4 + i * 6, 2),
            Rotation = -45, BackgroundColor3 = C.SUB, BorderSizePixel = 0, ZIndex = 61,
        }, grip)
    end
    local dragging, startMouse, startMul
    grip.InputBegan:Connect(function(i)
        if isPress(i) then dragging, startMouse, startMul = true, i.Position, userMul end
    end)
    table.insert(conns, UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startMouse
            userMul = math.clamp(startMul + (d.X + d.Y) / 700, 0.4 / math.max(fitMul, 0.01), 3)
            applyScale()
        end
    end))
    table.insert(conns, UserInputService.InputEnded:Connect(function(i)
        if dragging and isPress(i) then
            dragging = false
            notify("Ukuran UI: " .. math.floor(uiScale.Scale * 100) .. "%")
        end
    end))
end

---------------------------------------------------------------- FLOATING ICON
local iconBtn = make("ImageButton", {
    Name = "FloatingIcon", Position = UDim2.new(0, 20, 0.5, -26), Size = UDim2.fromOffset(52, 52),
    BackgroundColor3 = Color3.fromRGB(25, 25, 28), Image = ICON_ASSET, ScaleType = Enum.ScaleType.Fit,
    AutoButtonColor = false, Visible = false, ZIndex = 200,
}, gui)
corner(iconBtn, 12)
stroke(iconBtn, Color3.fromRGB(70, 70, 78), 1.5)
do
    local dragging, moved, startMouse, startPos
    iconBtn.InputBegan:Connect(function(i)
        if isPress(i) then dragging, moved, startMouse, startPos = true, false, i.Position, iconBtn.Position end
    end)
    table.insert(conns, UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startMouse
            if d.Magnitude > 6 then moved = true end
            if moved then
                iconBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end))
    table.insert(conns, UserInputService.InputEnded:Connect(function(i)
        if dragging and isPress(i) then
            dragging = false
            if not moved then setOpen(not opened) end
        end
    end))
end

---------------------------------------------------------------- GATE: SALIN DISCORD
copyDiscord = function()
    local copied = false
    if setclipboard then copied = pcall(setclipboard, DISCORD_LINK)
    elseif toclipboard then copied = pcall(toclipboard, DISCORD_LINK) end
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        pcall(req, {
            Url = "http://127.0.0.1:6463/rpc?v=1", Method = "POST",
            Headers = { ["Content-Type"] = "application/json", ["Origin"] = "https://discord.com" },
            Body = HttpService:JSONEncode({ cmd = "INVITE_BROWSER", args = { code = DISCORD_CODE }, nonce = HttpService:GenerateGUID(false) }),
        })
    end
    notify(copied and "Link Discord disalin" or DISCORD_LINK)
    return copied
end

---------------------------------------------------------------- KEY SYSTEM: TUNGGU 2 MENIT
local function unlockedRecently()
    local t = env.__Senar99Unlock
    if t and os.time() - t < UNLOCK_TTL then return true end
    if isfile and readfile then
        local ok, has = pcall(isfile, UNLOCK_FILE)
        if ok and has then
            local ok2, raw = pcall(readfile, UNLOCK_FILE)
            local n = ok2 and tonumber(raw)
            if n and os.time() - n < UNLOCK_TTL then return true end
        end
    end
    return false
end

local function markUnlocked()
    env.__Senar99Unlock = os.time()
    if writefile then pcall(writefile, UNLOCK_FILE, tostring(os.time())) end
end

local function openUI()
    iconBtn.Visible = true
    selectTab(tabs[1])
    setOpen(true)
    resumeBigHop()
end

local function runLoading()
    local TIPS = {
        "Tips: Bring Source memindahkan kayu & metal ke Campfire",
        "Tips: Aktifkan Mode God sebelum masuk area bahaya",
        "Tips: Tarik pegangan kanan bawah untuk resize UI",
        "Tips: Floating icon bisa digeser ke mana saja",
        "Tips: Server Hop Big Days mencari server dengan Day tinggi",
        "Tips: Auto Chest memakai gerak paksa kecepatan 600",
        "Tips: Cosmetic Server terlihat oleh semua player",
    }
    local overlay = make("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 8), BackgroundTransparency = 0.15,
        BorderSizePixel = 0, Active = true, ZIndex = 300,
    }, gui)

    local rng = Random.new(42)
    local parts = {}
    for i = 1, 26 do
        local sz = rng:NextInteger(2, 5)
        local f = make("Frame", {
            Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = Color3.fromRGB(200, 200, 200),
            BackgroundTransparency = rng:NextNumber(0.55, 0.9), BorderSizePixel = 0, ZIndex = 301,
        }, overlay)
        parts[i] = { f = f, x = rng:NextNumber(), y = rng:NextNumber(), v = rng:NextNumber(0.03, 0.12), sway = rng:NextNumber(0, 6.28) }
    end

    local card = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 236),
        BackgroundColor3 = C.BG, BorderSizePixel = 0, ZIndex = 310, ClipsDescendants = true,
    }, overlay)
    corner(card, 12)
    local cardStroke = stroke(card, C.FILL, 1.5)
    make("UIScale", { Scale = math.clamp(fitMul, 0.7, 1) }, card)

    local title = make("TextLabel", {
        Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Text = "",
        TextColor3 = Color3.fromRGB(230, 230, 230), Font = Enum.Font.Code, TextSize = 28,
    }, card)
    make("TextLabel", {
        Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = HUB_SUB,
        TextColor3 = C.SUB, Font = Enum.Font.Gotham, TextSize = 10,
    }, card)

    local orbit = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(64, 64),
        BackgroundTransparency = 1,
    }, card)
    local dots = {}
    for i = 1, 8 do
        local d = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.TEXT, BorderSizePixel = 0,
        }, orbit)
        corner(d, 4)
        dots[i] = d
    end
    local core = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, orbit)
    corner(core, 7)
    stroke(core, C.FILL, 2)

    local tipLbl = make("TextLabel", {
        Position = UDim2.fromOffset(16, 142), Size = UDim2.new(1, -32, 0, 16), BackgroundTransparency = 1, Text = TIPS[1],
        TextColor3 = C.SUB, Font = Enum.Font.Gotham, TextSize = 10,
    }, card)
    local track = make("Frame", {
        Position = UDim2.fromOffset(20, 168), Size = UDim2.new(1, -40, 0, 8), BackgroundColor3 = C.TRACK,
        BorderSizePixel = 0, ClipsDescendants = true,
    }, card)
    corner(track, 4)
    local fillB = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.FILL, BorderSizePixel = 0 }, track)
    corner(fillB, 4)
    local shine = make("Frame", {
        Size = UDim2.new(0, 40, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
    }, track)
    local timeLbl = make("TextLabel", {
        Position = UDim2.fromOffset(0, 184), Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "",
        TextColor3 = C.TEXT, Font = Enum.Font.GothamBold, TextSize = 12,
    }, card)
    make("TextLabel", {
        Position = UDim2.fromOffset(0, 207), Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
        Text = "UI terbuka otomatis setelah 2 menit", TextColor3 = Color3.fromRGB(95, 95, 95),
        Font = Enum.Font.Gotham, TextSize = 9,
    }, card)
    local scan = make("Frame", {
        Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.FILL, BackgroundTransparency = 0.8, BorderSizePixel = 0,
    }, card)

    local t0 = os.clock()
    local lastTip, tipIdx = 0, 1
    local nextGlitch, glitchUntil = 3, 0
    local done = false
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if done or not overlay.Parent then return end
        local t = os.clock() - t0
        local frac = math.clamp(t / UNLOCK_WAIT, 0, 1)
        local remain = math.max(0, math.ceil(UNLOCK_WAIT - t))
        timeLbl.Text = string.format("Membuka UI dalam %02d:%02d", remain // 60, remain % 60)
        fillB.Size = UDim2.fromScale(frac, 1)
        shine.Position = UDim2.new((t * 0.5) % 1.4 - 0.2, 0, 0, 0)

        -- judul mengetik + kursor + glitch
        local nShow = math.min(#HUB_NAME, math.floor(t / 0.15))
        title.Text = HUB_NAME:sub(1, nShow) .. ((t % 1 < 0.5) and "_" or " ")
        if t > nextGlitch then
            nextGlitch = t + 2 + math.random() * 2
            glitchUntil = t + 0.25
        end
        if t < glitchUntil then
            title.Position = UDim2.fromOffset(math.random(-4, 4), 14 + math.random(-2, 2))
            title.TextColor3 = Color3.fromRGB(math.random(150, 255), math.random(150, 255), math.random(150, 255))
        else
            title.Position = UDim2.fromOffset(0, 14)
            title.TextColor3 = Color3.fromRGB(230, 230, 230)
        end

        -- orbit loader
        for i, d in ipairs(dots) do
            local ang = t * 2.4 + (i / 8) * math.pi * 2
            local rad = 24 + 3 * math.sin(t * 3 + i)
            d.Position = UDim2.new(0.5, math.cos(ang) * rad, 0.5, math.sin(ang) * rad)
            d.Size = UDim2.fromOffset(9 - (i - 1) * 0.8, 9 - (i - 1) * 0.8)
            d.BackgroundTransparency = (i - 1) / 8 * 0.85
        end
        local cs = 14 + 4 * math.sin(t * 4)
        core.Size = UDim2.fromOffset(cs, cs)

        -- partikel naik
        for _, p in ipairs(parts) do
            p.y = p.y - p.v * dt
            if p.y < -0.05 then
                p.y = 1.05
                p.x = math.random()
            end
            p.f.Position = UDim2.fromScale(p.x + 0.01 * math.sin(t + p.sway), p.y)
        end

        cardStroke.Thickness = 1.5 + 0.8 * math.sin(t * 2)
        scan.Position = UDim2.fromOffset(0, (t * 60) % 236)

        -- tips bergantian
        if t - lastTip >= 6 then
            lastTip = t
            tween(tipLbl, TweenInfo.new(0.3), { TextTransparency = 1 })
            task.delay(0.3, function()
                if not tipLbl.Parent then return end
                tipIdx = tipIdx % #TIPS + 1
                tipLbl.Text = TIPS[tipIdx]
                tween(tipLbl, TweenInfo.new(0.3), { TextTransparency = 0 })
            end)
        end

        -- selesai
        if t >= UNLOCK_WAIT then
            done = true
            conn:Disconnect()
            markUnlocked()
            local flash = make("Frame", {
                Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 330,
            }, overlay)
            tween(flash, TweenInfo.new(0.15), { BackgroundTransparency = 0.35 })
            task.delay(0.15, function()
                if flash.Parent then tween(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }) end
                if card.Parent then tween(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(380, 0) }) end
            end)
            task.delay(0.6, function()
                if overlay.Parent then overlay:Destroy() end
                openUI()
            end)
        end
    end)
    table.insert(conns, conn)
end

if unlockedRecently() then
    task.defer(openUI)
else
    runLoading()
end

---------------------------------------------------------------- CLEANUP
env.__Senar99Cleanup = function() if gui and gui.Parent then gui:Destroy() end end
gui.Destroying:Connect(function()
    hookLive = false
    pcall(stopCosmetic)
    for k, v in pairs(S) do
        if type(v) == "boolean" then S[k] = false end
    end
    bringToken += 1
    local hm = hum()
    if hm then
        pcall(function()
            if defaults.speed then hm.WalkSpeed = defaults.speed end
            if defaults.jump then hm.JumpPower = defaults.jump end
        end)
    end
    for _, cn in ipairs(conns) do pcall(function() cn:Disconnect() end) end
    if env.__Senar99Cleanup then env.__Senar99Cleanup = nil end
end)
