

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VU = game:GetService("VirtualUser")
local Core = game:GetService("CoreGui")
local P = Players.LocalPlayer
local Env = getgenv and getgenv() or _G

if type(Env.AevrixCleanup) == "function" then
    pcall(Env.AevrixCleanup)
end

local VIM
pcall(function()
    VIM = game:GetService("VirtualInputManager")
end)

local Comm = RS:WaitForChild("Remotes"):WaitForChild("CommF_")
local Quests = require(RS:WaitForChild("Quests"))
local Net = RS:FindFirstChild("Modules")
Net = Net and Net:FindFirstChild("Net")

local RegisterAttack = Net and Net:FindFirstChild("RE/RegisterAttack")
local RegisterHit = Net and Net:FindFirstChild("RE/RegisterHit")

local A = {
    Farm = false,
    Chest = false,
    PlayerESP = false,
    ChestESP = false,
    Skills = false,
    Stats = false,
    Hotkey = "F",
    TargetLevel = 2800,
    Speed = 320,
    ChestSpeed = 320,
    Weapon = "Melee",
    Range = 12,
    Delay = 0.15,
    SkillCooldown = 6,
    Points = 1,
    SelectedStats = {Melee = true},
    PlayerColor = "Cyan",
    ChestColor = "Gold"
}

local S = {
    Running = true,
    Connections = {},
    Collisions = {},
    Highlights = {},
    Labels = {},
    Chests = {},
    ChestDone = {},
    ChestFailed = {},
    SpawnMemory = {},
    SkillTimes = {},
    BossCooldown = {},

    Velocity = Vector3.zero,
    Updating = false,
    StatBusy = false,
    StatIndex = 1,
    SkillIndex = 0,

    Quest = nil,
    QuestSerial = 0,
    Target = nil,
    Spawn = nil,
    ChestTarget = nil,

    LastScan = 0,
    LastSpawn = 0,
    LastChest = 0,
    LastStat = 0,
    LastSkill = 0,
    LastAttack = 0,
    LastRemote = 0,
    LastError = 0,
    LastMemory = 0,

    RetreatUntil = 0,
    CombatMode = "probe"
}

local StatNames = {
    "Melee", "Defense", "Sword", "Gun", "Blox Fruit"
}

local ColorNames = {
    "Cyan", "Gold", "Red", "Green",
    "Blue", "Purple", "Pink", "White"
}

local Colors = {
    Cyan = Color3.fromRGB(0,220,255),
    Gold = Color3.fromRGB(255,200,40),
    Red = Color3.fromRGB(255,65,65),
    Green = Color3.fromRGB(60,255,120),
    Blue = Color3.fromRGB(75,130,255),
    Purple = Color3.fromRGB(175,90,255),
    Pink = Color3.fromRGB(255,100,190),
    White = Color3.new(1,1,1)
}

local Melee = {}
for n in ("combat,darkstep,blackleg,electric,waterkungfu,dragonbreath,superhuman,deathstep,sharkmankarate,electricclaw,dragontalon,godhuman,sanguineart"):gmatch("[^,]+") do
    Melee[n] = true
end

local Bosses = {}
for n in ("gorillaking,bobby,yeti,mobleader,viceadmiral,warden,chiefwarden,swan,magmaadmiral,fishmanlord,wysper,thundergod,cyborg,diamond,jeremy,fajita,donswan,smokeadmiral,awakenediceadmiral,tidekeeper,darkbeard,cursedcaptain,order,stone,islandempress,kiloadmiral,captainelephant,beautifulpirate,longma,soulreaper,cakequeen,cakeprince,doughking,ripindra,saberexpert,greybeard,saw,iceadmiral,doughprince,leviathan,terrorshark"):gmatch("[^,]+") do
    Bosses[n] = true
end

local Spawns = {
    bandit = Vector3.new(1060,17,1547),
    monkey = Vector3.new(-1460,40,100),
    gorilla = Vector3.new(-1190,40,-470),
    pirate = Vector3.new(-1115,14,3938),
    brute = Vector3.new(-1145,15,4350),
    desertbandit = Vector3.new(930,7,4485),
    desertofficer = Vector3.new(1550,14,4370),
    snowbandit = Vector3.new(1345,105,-1300),
    snowman = Vector3.new(1220,138,-1480),
    chiefpettyofficer = Vector3.new(-4850,23,4300),
    skypiean = Vector3.new(-4950,295,-2900),
    darkmaster = Vector3.new(-5250,390,-2270),
    prisonerguard = Vector3.new(4870,6,740)
}

local function Normal(v)
    return tostring(v or ""):lower()
        :gsub("%[.*", "")
        :gsub("[^%w]", "")
end

local function CleanText(v)
    return tostring(v or ""):gsub("<.->", "")
end

local function BossName(v)
    local n = Normal(v)
    return Bosses[n] == true
        or n:find("boss",1,true) ~= nil
end

local function Root(m)
    return m and (
        m:FindFirstChild("HumanoidRootPart")
        or m.PrimaryPart
    )
end

local function Char()
    local c = P.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")

    if h and h.Health > 0 and r then
        return c,h,r
    end
end

local function Level()
    local d = P:FindFirstChild("Data")
    local v = d and d:FindFirstChild("Level")
    return v and tonumber(v.Value) or 1
end

local function EnemyFolder()
    return workspace:FindFirstChild("Enemies")
end

local function Alive(n)
    local h = n and n:FindFirstChildOfClass("Humanoid")
    local r = Root(n)

    return n
        and n:IsA("Model")
        and n.Parent == EnemyFolder()
        and h and h.Health > 0
        and r and r:IsDescendantOf(workspace)
end

local function BossNPC(n)
    if not n then return false end
    if BossName(n.Name) then return true end

    for _,key in ipairs({
        "Boss","IsBoss","RaidBoss","IsRaidBoss"
    }) do
        if n:GetAttribute(key) == true then
            return true
        end
    end

    return false
end

local function FindEnemy(name,bossOnly)
    local folder = EnemyFolder()
    local _,_,pr = Char()

    if not folder or not name then return nil end

    local best,closest

    for _,npc in ipairs(folder:GetChildren()) do
        if Alive(npc)
            and Normal(npc.Name) == Normal(name)
            and (not bossOnly or BossNPC(npc))
        then
            local d = pr
                and (pr.Position-Root(npc).Position).Magnitude
                or 0

            if not closest or d < closest then
                best,closest = npc,d
            end
        end
    end

    return best
end

local function BossAlive(name)
    if os.clock() < (S.BossCooldown[Normal(name)] or 0) then
        return nil
    end

    return FindEnemy(name,true)
end

local function Moving()
    return S.Running and (A.Farm or A.Chest)
end

-- MOVEMENT

local function Noclip()
    local c = P.Character
    if not c then return end

    for _,part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") then
            if S.Collisions[part] == nil then
                S.Collisions[part] = part.CanCollide
            end

            part.CanCollide = false
        end
    end
end

local function RestoreNoclip()
    for part,old in pairs(S.Collisions) do
        pcall(function()
            if part.Parent then
                part.CanCollide = old
            end
        end)

        S.Collisions[part] = nil
    end
end

local function ClearFlight()
    for _,obj in ipairs({S.BV,S.BG}) do
        if obj then
            pcall(function()
                obj:Destroy()
            end)
        end
    end

    S.BV,S.BG,S.FlightRoot = nil,nil,nil
    S.Velocity = Vector3.zero
end

local function Flight()
    local _,h,r = Char()
    if not r or not Moving() then return false end

    if S.FlightRoot ~= r
        or not S.BV or not S.BV.Parent
        or not S.BG or not S.BG.Parent
    then
        ClearFlight()

        local bv = Instance.new("BodyVelocity")
        bv.Name = "AevrixFlight"
        bv.MaxForce = Vector3.new(1e9,1e9,1e9)
        bv.P = 15000
        bv.Velocity = Vector3.zero
        bv.Parent = r

        local bg = Instance.new("BodyGyro")
        bg.Name = "AevrixFacing"
        bg.MaxTorque = Vector3.new(1e9,1e9,1e9)
        bg.P = 10000
        bg.D = 1400
        bg.CFrame = r.CFrame
        bg.Parent = r

        S.BV,S.BG,S.FlightRoot = bv,bg,r
    end

    h.AutoRotate = false
    h:Move(Vector3.zero)

    return true
end

local function Move(goal,speed,dt,face)
    if not goal or not Flight() then return end

    local _,_,r = Char()
    if not r then return end

    dt = math.clamp(dt,1/240,0.1)

    local delta = goal-r.Position
    local dist = delta.Magnitude

    local desired = dist > 0.15
        and delta.Unit*math.min(speed,dist*7)
        or Vector3.zero

    S.Velocity = S.Velocity:Lerp(
        desired,
        1-math.exp(-(dist > 25 and 11 or 15)*dt)
    )

    S.BV.Velocity = S.Velocity

    local look = face
        and Vector3.new(
            face.X-r.Position.X,
            0,
            face.Z-r.Position.Z
        )
        or Vector3.new(S.Velocity.X,0,S.Velocity.Z)

    if look.Magnitude > 0.05 then
        S.BG.CFrame = CFrame.lookAt(
            r.Position,
            r.Position+look.Unit
        )
    end
end

local function Hold()
    S.Velocity = Vector3.zero

    if S.BV then
        S.BV.Velocity = Vector3.zero
    end
end

local function Stop()
    ClearFlight()
    RestoreNoclip()

    local _,h = Char()
    if h then h.AutoRotate = true end

    S.Target,S.ChestTarget = nil,nil
end

-- SPAWN LOOKUP

local function RememberNPCs()
    local folder = EnemyFolder()
    if not folder then return end

    for _,npc in ipairs(folder:GetChildren()) do
        if Alive(npc) and not BossNPC(npc) then
            S.SpawnMemory[Normal(npc.Name)] = Root(npc).Position
        end
    end
end

local function FindSpawn(name)
    if not name or BossName(name) then return nil end

    local _,_,r = Char()
    if not r then return nil end

    local folders = {}
    local world = workspace:FindFirstChild("_WorldOrigin")

    for _,parent in ipairs({workspace,world}) do
        if parent then
            for _,key in ipairs({
                "EnemySpawns","NPCSpawns","MobSpawns"
            }) do
                local folder = parent:FindFirstChild(key)

                if folder then
                    table.insert(folders,folder)
                end
            end
        end
    end

    local best,dist
    local wanted = Normal(name)

    for _,folder in ipairs(folders) do
        for _,obj in ipairs(folder:GetDescendants()) do
            if obj:IsA("BasePart")
                or obj:IsA("Attachment")
            then
                local part = obj:IsA("Attachment")
                    and obj.Parent or obj

                if part and part:IsA("BasePart") then
                    local found = false

                    for _,n in ipairs({
                        obj.Name,
                        part.Name,
                        obj:GetAttribute("EnemyName") or "",
                        obj:GetAttribute("MobName") or "",
                        part:GetAttribute("EnemyName") or ""
                    }) do
                        if Normal(n) == wanted then
                            found = true
                            break
                        end
                    end

                    if found then
                        local pos = obj:IsA("Attachment")
                            and obj.WorldPosition
                            or part.Position

                        local d = (r.Position-pos).Magnitude

                        if not dist or d < dist then
                            best,dist = pos,d
                        end
                    end
                end
            end
        end
    end

    return best or S.SpawnMemory[wanted] or Spawns[wanted]
end

-- QUEST DATABASE

local QuestList = {}
local QuestNames = {}
local BossQuestNames = {}

for id,stages in pairs(Quests) do
    if type(stages) == "table" then
        for index,q in pairs(stages) do
            if type(index) == "number"
                and type(q) == "table"
                and type(q.LevelReq) == "number"
                and type(q.Task) == "table"
            then
                local enemy,count,total = nil,nil,0

                for name,amount in pairs(q.Task) do
                    if type(name) == "string"
                        and type(amount) == "number"
                        and amount > 0
                    then
                        enemy,count = name,amount
                        total = total+1
                    end
                end

                if total == 1 then
                    local boss = BossName(enemy)
                        or BossName(id)
                        or BossName(q.Name)
                        or BossName(q.Title)

                    local record = {
                        ID = id,
                        Index = index,
                        Enemy = enemy,
                        Count = count,
                        LevelReq = q.LevelReq,
                        Boss = boss
                    }

                    table.insert(QuestList,record)
                    QuestNames[enemy] = true

                    if boss then
                        BossQuestNames[Normal(enemy)] = true
                    end
                end
            end
        end
    end
end

table.sort(QuestList,function(a,b)
    return a.LevelReq > b.LevelReq
end)

local function QuestIsBoss(name)
    return BossQuestNames[Normal(name)] == true
        or BossName(name)
end

local function FindQuestRecord(name)
    for _,q in ipairs(QuestList) do
        if Normal(q.Enemy) == Normal(name)
            and q.LevelReq <= Level()
        then
            return q
        end
    end
end

local function SelectQuest(normalOnly)
    local normal,boss
    local level = Level()

    for _,q in ipairs(QuestList) do
        if q.LevelReq <= level then
            if q.Boss then
                if not normalOnly
                    and not boss
                    and BossAlive(q.Enemy)
                then
                    boss = q
                end
            elseif not normal then
                normal = q
            end
        end

        if normal and boss then break end
    end

    return boss or normal
end

-- QUEST GUI
-- Updated: search recursively, not only Main.Quest.

local function QuestGui()
    local pg = P:FindFirstChild("PlayerGui")
    if not pg then return nil end

    local main = pg:FindFirstChild("Main")
    if main then
        local quest = main:FindFirstChild("Quest",true)
        if quest then return quest end
    end

    return pg:FindFirstChild("Quest",true)
end

local function QuestVisible()
    local gui = QuestGui()
    if not gui then return false end

    if gui:IsA("GuiObject") then
        return gui.Visible == true
    end

    if gui:IsA("ScreenGui") then
        return gui.Enabled == true
    end

    return false
end

local function QuestText()
    local gui = QuestGui()
    if not gui then return "" end

    local lines = {}

    for _,obj in ipairs(gui:GetDescendants()) do
        if (obj:IsA("TextLabel")
            or obj:IsA("TextButton"))
            and obj.Text ~= ""
        then
            table.insert(lines,CleanText(obj.Text))
        end
    end

    return table.concat(lines,"\n")
end

local function DetectEnemy(text)
    local cleaned = tostring(text):lower()
        :gsub("[^%w]","")

    local best,longest = nil,0

    for name in pairs(QuestNames) do
        local n = Normal(name)

        if #n >= 4
            and #n > longest
            and cleaned:find(n,1,true)
        then
            best,longest = name,#n
        end
    end

    return best
end

local function CompletionText(text)
    local t = CleanText(text):lower()

    return t:find("quest completed",1,true)
        or t:find("quest complete!",1,true)
        or t:find("quest finished",1,true)
end

local function ObjectiveProgress(text,q)
    if not q or not q.Enemy or not q.Count then
        return nil
    end

    local wanted = Normal(q.Enemy)

    for line in tostring(text):gmatch("[^\r\n]+") do
        local cleaned = CleanText(line)
        local normalized = cleaned:lower()
            :gsub("[^%w]","")

        if normalized:find(wanted,1,true) then
            for a,b in cleaned:gmatch("(%d+)%s*/%s*(%d+)") do
                local current = tonumber(a)
                local required = tonumber(b)

                if required == q.Count
                    and current
                    and current >= 0
                    and current <= required
                then
                    return current
                end
            end
        end
    end

    return nil
end

-- QUEST STATE

local function ResetCombat()
    S.CombatTarget = nil
    S.CombatHealth = nil
    S.CombatMode = "probe"
    S.CombatStart = 0
    S.LastDamage = 0
    S.CombatRetry = 0
end

local function ResetQuest()
    S.QuestSerial = S.QuestSerial+1
    S.Quest = nil
    S.Target = nil
    S.Spawn = nil
    S.LastScan = 0
    S.LastSpawn = 0
    ResetCombat()
end

local function NewQuest(record,visible)
    S.QuestSerial = S.QuestSerial+1

    local q = {
        ID = record.ID,
        Index = record.Index,
        Enemy = record.Enemy,
        Count = record.Count,
        Boss = record.Boss,

        -- Seen means we are allowed to start farming.
        Seen = visible == true,

        -- GuiSeen means the quest UI actually appeared.
        GuiSeen = visible == true,

        Requested = 0,
        RequestBusy = false,

        FullProgress = false,
        CompletionNotice = false,

        HiddenSince = nil,
        BossMissingSince = nil,
        Abandoning = false,
        AbandonAt = 0,
        AbandonHidden = nil
    }

    S.Quest = q
    S.Target = nil
    S.Spawn = nil
    S.LastScan = 0
    S.LastSpawn = 0

    ResetCombat()
    return q
end

local function RequestQuest(q)
    if not A.Farm or not q
        or S.Quest ~= q
        or q.RequestBusy
        or q.GuiSeen
    then
        return
    end

    if q.Boss and not BossAlive(q.Enemy) then
        return
    end

    -- Never send a second StartQuest for the same
    -- quest while its first request is still pending.
    q.RequestBusy = true
    q.Requested = os.clock()

    local serial = S.QuestSerial

    task.spawn(function()
        if not S.Running or not A.Farm
            or S.Quest ~= q
            or S.QuestSerial ~= serial
        then
            q.RequestBusy = false
            return
        end

        if q.Boss and not BossAlive(q.Enemy) then
            q.RequestBusy = false
            return
        end

        pcall(function()
            Comm:InvokeServer(
                "StartQuest",
                q.ID,
                q.Index
            )
        end)

        q.RequestBusy = false
    end)
end

local function AbandonBoss(q)
    if not q or S.Quest ~= q
        or not q.Boss
        or q.Abandoning
    then
        return
    end

    q.Abandoning = true
    q.AbandonAt = os.clock()
    q.AbandonHidden = nil

    S.BossCooldown[Normal(q.Enemy)] = os.clock()+6
    S.Target,S.Spawn = nil,nil

    Hold()

    task.spawn(function()
        pcall(function()
            Comm:InvokeServer("AbandonQuest")
        end)
    end)
end

local function UpdateQuest()
    if not A.Farm then return end

    local now = os.clock()
    local visible = QuestVisible()
    local text = visible and QuestText() or ""
    local detected = visible and DetectEnemy(text) or nil
    local q = S.Quest

    -- Adopt an existing quest if Auto Farm was
    -- switched on while one was already active.
    if not q and visible then
        if detected then
            local record = FindQuestRecord(detected)

            if record then
                q = NewQuest(record,true)
            else
                q = NewQuest({
                    Enemy = detected,
                    Boss = QuestIsBoss(detected)
                },true)
            end
        end

        return
    end

    -- Choose a quest only when no quest is locked.
    if not q then
        if visible then return end

        local chosen = SelectQuest(false)
        if not chosen then return end

        -- Recheck boss availability before requesting.
        if chosen.Boss and not BossAlive(chosen.Enemy) then
            chosen = SelectQuest(true)
        end

        if not chosen then return end

        q = NewQuest(chosen,false)
        RequestQuest(q)
        return
    end

    -- FIX: Once the quest GUI becomes visible,
    -- farming is immediately enabled.
    if visible then
        q.Seen = true
        q.GuiSeen = true
        q.HiddenSince = nil

        if q.Abandoning then
            q.AbandonHidden = nil

            if now-q.AbandonAt >= 2 then
                q.AbandonAt = now

                task.spawn(function()
                    pcall(function()
                        Comm:InvokeServer("AbandonQuest")
                    end)
                end)
            end

            return
        end

        local progress = ObjectiveProgress(text,q)

        if progress and q.Count
            and progress >= q.Count
        then
            q.FullProgress = true
        end

        if CompletionText(text) then
            q.CompletionNotice = true
        end

    else
        q.HiddenSince = q.HiddenSince or now

        if q.Abandoning then
            q.AbandonHidden = q.AbandonHidden or now

            if now-q.AbandonHidden >= 0.35 then
                ResetQuest()
            end

            return
        end

        -- A normal quest is only released after
        -- completion AND disappearance of its UI.
        if q.GuiSeen
            and (q.FullProgress or q.CompletionNotice)
            and now-q.HiddenSince >= 0.4
        then
            ResetQuest()
            return
        end
    end

    -- Boss quests have their own recovery rules.
    if q.Boss then
        if BossAlive(q.Enemy) then
            q.BossMissingSince = nil
        else
            q.BossMissingSince = q.BossMissingSince or now

            if now-q.BossMissingSince >= 1.2 then
                if q.GuiSeen and visible then
                    if not q.FullProgress
                        and not q.CompletionNotice
                    then
                        AbandonBoss(q)

                    elseif now-q.BossMissingSince >= 2 then
                        AbandonBoss(q)
                    end

                elseif not visible then
                    S.BossCooldown[Normal(q.Enemy)] = now+6
                    ResetQuest()
                end
            end
        end

        return
    end

    -- FIX: Normal quests are NEVER restarted after
    -- an NPC kill or a temporary quest UI flicker.
    --
    -- The initial request happens once.
    -- Only retry if the game never showed the
    -- quest GUI AND we have not started farming.
    if not q.GuiSeen
        and not q.Seen
        and not visible
        and not q.RequestBusy
        and q.ID and q.Index
        and now-q.Requested >= 5
    then
        RequestQuest(q)
    end

    -- Movement fallback:
    -- if the quest was requested but the GUI
    -- wasn't detected, allow combat to start.
    -- This does not issue another quest request.
    if not q.Seen
        and q.Requested > 0
        and now-q.Requested >= 0.65
    then
        q.Seen = true
    end
end

-- COMBAT

local function WeaponMatch(tool)
    if not tool:IsA("Tool") then return false end

    local kind = tool:GetAttribute("WeaponType")
    local tip = (tool.ToolTip or ""):lower()

    if A.Weapon == "Melee" then
        return kind == "Melee"
            or kind == "FightingStyle"
            or tip == "melee"
            or Melee[Normal(tool.Name)] == true

    elseif A.Weapon == "Fruit" then
        return kind == "Fruit"
            or kind == "Demon Fruit"
            or tip == "fruit"
            or tip == "blox fruit"
    end

    return kind == A.Weapon
        or tip == A.Weapon:lower()
end

local function Equip()
    local c,h = Char()
    if not c then return nil end

    for _,tool in ipairs(c:GetChildren()) do
        if WeaponMatch(tool) then
            return tool
        end
    end

    local bag = P:FindFirstChild("Backpack")

    if bag then
        for _,tool in ipairs(bag:GetChildren()) do
            if WeaponMatch(tool) then
                h:EquipTool(tool)
                return tool.Parent == c and tool or nil
            end
        end
    end
end

local function RemoteAttack(npc)
    if not Alive(npc)
        or not RegisterAttack
        or not RegisterHit
        or not RegisterAttack:IsA("RemoteEvent")
        or not RegisterHit:IsA("RemoteEvent")
        or os.clock()-S.LastRemote < A.Delay
    then
        return
    end

    if not Equip() then return end

    local part = npc:FindFirstChild("Head") or Root(npc)
    if not part then return end

    S.LastRemote = os.clock()

    pcall(function()
        RegisterAttack:FireServer(0.1)
        RegisterHit:FireServer(part,{{npc,part}})
    end)
end

local ClickPositions = {
    {88,45},{91,55},{85,32},{87,68},
    {75,45},{75,65},{12,45},{15,30},
    {50,75},{50,50}
}

local function Blocked(x,y)
    for _,gui in ipairs({
        P:FindFirstChild("PlayerGui"),Core
    }) do
        if gui then
            for _,obj in ipairs(gui:GetDescendants()) do
                if obj:IsA("GuiObject") and (
                    obj:IsA("GuiButton")
                    or obj:IsA("TextBox")
                    or obj.Active
                    or obj.Selectable
                ) then
                    local shown = true
                    local parent = obj

                    while parent do
                        if parent:IsA("GuiObject")
                            and not parent.Visible
                        then
                            shown = false
                            break
                        end

                        if parent:IsA("ScreenGui")
                            and not parent.Enabled
                        then
                            shown = false
                            break
                        end

                        parent = parent.Parent
                    end

                    if shown then
                        local p,s = obj.AbsolutePosition,obj.AbsoluteSize

                        if x >= p.X-7
                            and x <= p.X+s.X+7
                            and y >= p.Y-7
                            and y <= p.Y+s.Y+7
                        then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

local function NormalAttack()
    if os.clock()-S.LastAttack < A.Delay
        or not Equip()
    then
        return
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    for _,p in ipairs(ClickPositions) do
        local x = math.floor(cam.ViewportSize.X*p[1]/100)
        local y = math.floor(cam.ViewportSize.Y*p[2]/100)

        if not Blocked(x,y) then
            S.LastAttack = os.clock()
            local ok = false

            if VIM then
                ok = pcall(function()
                    VIM:SendMouseButtonEvent(
                        x,y,0,true,game,0
                    )
                    VIM:SendMouseButtonEvent(
                        x,y,0,false,game,0
                    )
                end)
            end

            if not ok then
                pcall(function()
                    VU:CaptureController()
                    VU:Button1Down(
                        Vector2.new(x,y),cam.CFrame
                    )
                    VU:Button1Up(
                        Vector2.new(x,y),cam.CFrame
                    )
                end)
            end

            return
        end
    end
end

local function UseSkills()
    if not A.Skills
        or not VIM
        or os.clock()-S.LastSkill < 1
    then
        return
    end

    local tool = Equip()
    if not tool then return end

    local keys = {"Z","X","C","V"}

    for offset = 1,#keys do
        local index = (S.SkillIndex+offset-1)%#keys+1
        local key = keys[index]
        local id = tool.Name..":"..key

        if os.clock()-(S.SkillTimes[id] or -math.huge)
            >= A.SkillCooldown
        then
            S.SkillIndex = index
            S.LastSkill = os.clock()
            S.SkillTimes[id] = S.LastSkill

            task.spawn(function()
                pcall(function()
                    VIM:SendKeyEvent(
                        true,Enum.KeyCode[key],false,game
                    )

                    task.wait(0.08)

                    VIM:SendKeyEvent(
                        false,Enum.KeyCode[key],false,game
                    )
                end)
            end)

            break
        end
    end
end

local function GluePosition(npc)
    local r = Root(npc)
    local f = r.CFrame.LookVector

    f = Vector3.new(f.X,0,f.Z)
    f = f.Magnitude > 0.1
        and f.Unit or Vector3.new(0,0,-1)

    local dist = math.clamp(A.Range*0.23,2.3,3)

    if r.Size.Z > 4 then
        dist = math.min(
            4,dist+(r.Size.Z-4)*0.15
        )
    end

    return r.Position-f*dist+Vector3.new(0,0.3,0)
end

local function SurfaceDistance(npc,pos)
    local ok,cf,size = pcall(function()
        return npc:GetBoundingBox()
    end)

    if not ok then
        return (pos-Root(npc).Position).Magnitude
    end

    local p = cf:PointToObjectSpace(pos)
    local h = size/2

    return Vector3.new(
        math.max(math.abs(p.X)-h.X,0),
        math.max(math.abs(p.Y)-h.Y,0),
        math.max(math.abs(p.Z)-h.Z,0)
    ).Magnitude
end

local function UpdateFarm(dt)
    if Level() >= A.TargetLevel then
        return false
    end

    local q = S.Quest

    if not q or q.Abandoning then
        Hold()
        return true
    end

    -- Updated: allow movement after quest acceptance
    -- even if the GUI was slow to load.
    if not q.Seen then
        if QuestVisible() then
            q.Seen = true
            q.GuiSeen = true
        elseif q.Requested > 0
            and os.clock()-q.Requested >= 0.65
        then
            q.Seen = true
        else
            Hold()
            return true
        end
    end

    local enemy = q.Enemy

    if q.Boss and not BossAlive(enemy) then
        S.Target,S.Spawn = nil,nil
        Hold()
        return true
    end

    if S.Target and (
        not Alive(S.Target)
        or Normal(S.Target.Name) ~= Normal(enemy)
    ) then
        S.Target = nil
        S.LastScan = 0
        ResetCombat()
    end

    if not S.Target
        and os.clock()-S.LastScan >= 0.1
    then
        S.LastScan = os.clock()
        S.Target = FindEnemy(enemy,q.Boss)
    end

    local npc = S.Target

    if not npc then
        if q.Boss then
            Hold()
            return true
        end

        if not S.Spawn
            or os.clock()-S.LastSpawn >= 2
        then
            S.LastSpawn = os.clock()
            S.Spawn = FindSpawn(enemy)
        end

        if S.Spawn then
            Move(
                S.Spawn+Vector3.new(0,40,0),
                A.Speed,dt
            )
        else
            Hold()
        end

        return true
    end

    local r = Root(npc)
    local _,hum,root = Char()

    if not r or not root then return true end

    if not q.Boss then
        S.SpawnMemory[Normal(enemy)] = r.Position
    end

    if S.CombatTarget ~= npc then
        ResetCombat()
        S.CombatTarget = npc

        local h = npc:FindFirstChildOfClass("Humanoid")
        S.CombatHealth = h and h.Health
        S.CombatStart = os.clock()
        S.LastDamage = os.clock()
    end

    local th = npc:FindFirstChildOfClass("Humanoid")

    if th then
        if S.CombatHealth
            and th.Health < S.CombatHealth
        then
            S.LastDamage = os.clock()

            if S.CombatMode == "probe" then
                S.CombatMode = "verified"
            end
        end

        S.CombatHealth = th.Health
    end

    local now = os.clock()

    if hum.Health/math.max(hum.MaxHealth,1) < 0.25 then
        S.RetreatUntil = now+5
    end

    if now < S.RetreatUntil then
        Move(
            r.Position+Vector3.new(0,65,0),
            A.Speed,dt,r.Position
        )
        return true
    end

    if S.CombatMode == "normal"
        and now >= S.CombatRetry
    then
        S.CombatMode = "probe"
        S.CombatStart = now
        S.LastDamage = now
    end

    if S.CombatMode == "probe"
        or S.CombatMode == "verified"
    then
        local goal = r.Position+Vector3.new(0,40,0)

        Move(goal,A.Speed,dt,r.Position)

        if (root.Position-goal).Magnitude <= 5 then
            RemoteAttack(npc)

            if S.CombatMode == "probe"
                and now-S.CombatStart >= 3
                and now-S.LastDamage >= 2.5
            then
                S.CombatMode = "normal"
                S.CombatRetry = now+12

            elseif S.CombatMode == "verified"
                and now-S.LastDamage >= 5
            then
                S.CombatMode = "normal"
                S.CombatRetry = now+12
            end
        end

        return true
    end

    Move(GluePosition(npc),A.Speed,dt,r.Position)

    local dist = math.min(
        (root.Position-r.Position).Magnitude,
        SurfaceDistance(npc,root.Position)+2
    )

    if dist <= A.Range then
        NormalAttack()
        UseSkills()
    end

    return true
end

-- AUTO CHEST

local function ChestName(name)
    local n = Normal(name)

    return n == "chest"
        or n:match("^chest%d+$") ~= nil
        or n:match("^chest%a+$") ~= nil
end

local function ChestPart(obj)
    if not obj or not obj.Parent then return nil end

    if obj:IsA("BasePart") and ChestName(obj.Name) then
        return obj
    end

    if obj:IsA("Model") and ChestName(obj.Name) then
        return obj.PrimaryPart
            or obj:FindFirstChildWhichIsA("BasePart",true)
    end
end

local function ChestObject(obj)
    if not obj or not ChestName(obj.Name) then
        return nil
    end

    if obj:IsA("Model") then
        return ChestPart(obj) and obj or nil
    end

    if obj:IsA("BasePart") then
        local parent = obj.Parent

        return parent and parent:IsA("Model")
            and ChestName(parent.Name)
            and parent or obj
    end
end

local function RefreshChests()
    local found,seen = {},{}

    for _,obj in ipairs(workspace:GetDescendants()) do
        local chest = ChestObject(obj)

        if chest and ChestPart(chest)
            and not seen[chest]
        then
            seen[chest] = true
            table.insert(found,chest)
        end
    end

    S.Chests = found
    S.LastChest = os.clock()

    for _,bucket in ipairs({
        S.ChestDone,S.ChestFailed
    }) do
        for chest in pairs(bucket) do
            if not ChestPart(chest) then
                bucket[chest] = nil
            end
        end
    end
end

local function FindChest()
    local _,_,root = Char()
    if not root then return nil end

    local best,dist

    for _,chest in ipairs(S.Chests) do
        local part = ChestPart(chest)

        if part and not S.ChestDone[chest]
            and (S.ChestFailed[chest] or 0) <= os.clock()
        then
            local d = (root.Position-part.Position).Magnitude

            if not dist or d < dist then
                best,dist = chest,d
            end
        end
    end

    return best
end

local function NextChest()
    S.ChestTarget = FindChest()
    S.ChestProgress = nil
    S.ChestProgressTime = nil
    S.ChestStuck = 0
end

local function UpdateChest(dt)
    if os.clock()-S.LastChest >= 5 then
        RefreshChests()
    end

    if S.ChestTarget and (
        not ChestPart(S.ChestTarget)
        or S.ChestDone[S.ChestTarget]
    ) then
        S.ChestTarget = nil
    end

    if not S.ChestTarget then NextChest() end

    local chest = S.ChestTarget
    if not chest then Hold() return end

    local part = ChestPart(chest)
    local _,_,root = Char()

    if not part or not root then
        S.ChestTarget = nil
        return
    end

    local dist = (root.Position-part.Position).Magnitude

    if dist <= 3.5 then
        S.ChestDone[chest] = true
        NextChest()
        return
    end

    local now = os.clock()

    if not S.ChestProgressTime then
        S.ChestProgressTime = now
        S.ChestProgress = dist

    elseif now-S.ChestProgressTime >= 1.5 then
        if (S.ChestProgress or dist)-dist < 10 then
            S.ChestStuck = (S.ChestStuck or 0)+1
        else
            S.ChestStuck = 0
        end

        S.ChestProgressTime = now
        S.ChestProgress = dist

        if S.ChestStuck >= 3 then
            S.ChestFailed[chest] = now+180
            NextChest()
            return
        end
    end

    Move(part.Position,A.ChestSpeed,dt,part.Position)
end

-- ESP

local function RemoveESP(obj)
    for _,bucket in ipairs({
        S.Highlights,S.Labels
    }) do
        if bucket[obj] then
            pcall(function()
                bucket[obj]:Destroy()
            end)

            bucket[obj] = nil
        end
    end
end

local function ESP(obj,part,name,color)
    if not obj or not part then return end

    local h = S.Highlights[obj]

    if not h or not h.Parent then
        h = Instance.new("Highlight")
        h.Name = "AevrixESP"
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.75
        h.Parent = Core
        S.Highlights[obj] = h
    end

    h.Adornee = obj
    h.FillColor = color
    h.OutlineColor = color

    local b = S.Labels[obj]

    if not b or not b.Parent then
        b = Instance.new("BillboardGui")
        b.Name = "AevrixLabel"
        b.Size = UDim2.fromOffset(160,30)
        b.StudsOffsetWorldSpace = Vector3.new(0,3,0)
        b.AlwaysOnTop = true
        b.Parent = Core

        local t = Instance.new("TextLabel")
        t.Name = "Name"
        t.Size = UDim2.fromScale(1,1)
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.GothamBold
        t.TextSize = 14
        t.TextStrokeTransparency = 0.35
        t.Parent = b

        S.Labels[obj] = b
    end

    b.Adornee = part

    local text = b:FindFirstChild("Name")

    if text then
        text.Text = name
        text.TextColor3 = color
    end
end

local function UpdateESP()
    local active = {}

    if A.PlayerESP then
        for _,player in ipairs(Players:GetPlayers()) do
            if player ~= P then
                local c = player.Character
                local r = c and Root(c)

                if c and r then
                    active[c] = true

                    ESP(
                        c,
                        c:FindFirstChild("Head") or r,
                        player.DisplayName,
                        Colors[A.PlayerColor]
                    )
                end
            end
        end
    end

    if A.ChestESP then
        for _,chest in ipairs(S.Chests) do
            local part = ChestPart(chest)

            if part then
                active[chest] = true

                ESP(
                    chest,part,"Chest",
                    Colors[A.ChestColor]
                )
            end
        end
    end

    for obj in pairs(S.Highlights) do
        if not active[obj] then
            RemoveESP(obj)
        end
    end
end

-- AUTO STATS

local function SelectedStats()
    local result = {}

    for _,name in ipairs(StatNames) do
        if A.SelectedStats[name] then
            table.insert(result,name)
        end
    end

    return result
end

local function DistributeStats()
    if S.StatBusy or not A.Stats then return end

    local d = P:FindFirstChild("Data")
    local points = d and d:FindFirstChild("Points")

    if not points or points.Value <= 0 then return end

    S.StatBusy = true

    local amount = math.min(
        math.floor(points.Value),
        math.floor(A.Points)
    )

    for _ = 1,amount do
        if not S.Running
            or not A.Stats
            or not points.Parent
            or points.Value <= 0
        then
            break
        end

        local selected = SelectedStats()

        if #selected == 0 then break end

        if S.StatIndex > #selected then
            S.StatIndex = 1
        end

        local stat = selected[S.StatIndex]
        local before = points.Value
        local serverName = stat == "Blox Fruit"
            and "Demon Fruit" or stat

        local ok,result = pcall(function()
            return Comm:InvokeServer(
                "AddPoint",serverName,1
            )
        end)

        if not ok or result == false then break end

        S.StatIndex = S.StatIndex%#selected+1

        task.wait(0.08)

        if points.Parent and points.Value >= before then
            task.wait(0.12)
        end
    end

    S.StatBusy = false
end

-- CONTROLS

local Notify = function() end

local function SyncToggle(toggle,value)
    if not toggle or S.Updating then return end

    S.Updating = true

    pcall(function()
        toggle:SetValue(value)
    end)

    S.Updating = false
end

local function SetFarm(enabled)
    if A.Farm == enabled then return end

    if enabled and A.Chest then
        A.Chest = false
        SyncToggle(S.ChestToggle,false)
        Stop()
    end

    A.Farm = enabled
    S.RetreatUntil = 0

    ResetQuest()

    if enabled then
        Flight()
    else
        Stop()
    end

    SyncToggle(S.FarmToggle,enabled)

    Notify(
        enabled and "Auto Farm Enabled"
            or "Auto Farm Disabled",
        "Hotkey: "..A.Hotkey
    )
end

local function SetChest(enabled)
    if A.Chest == enabled then return end

    if enabled and A.Farm then
        A.Farm = false
        SyncToggle(S.FarmToggle,false)
        Stop()
    end

    A.Chest = enabled
    S.ChestTarget = nil

    if enabled then
        RefreshChests()
        Flight()
    else
        Stop()
    end

    SyncToggle(S.ChestToggle,enabled)

    Notify(
        enabled and "Auto Chest Enabled"
            or "Auto Chest Disabled",
        "Aevrix Hub"
    )
end

local function Connect(signal,fn)
    table.insert(S.Connections,signal:Connect(fn))
end

Connect(Run.PreSimulation,function()
    if Moving() then Noclip() end
end)

Connect(Run.Heartbeat,function(dt)
    if not Moving() then return end

    local ok,err = pcall(function()
        if not Flight() then return end

        if A.Chest then
            UpdateChest(dt)

        elseif A.Farm and not UpdateFarm(dt) then
            SetFarm(false)
        end
    end)

    if not ok and os.clock()-S.LastError > 3 then
        S.LastError = os.clock()
        warn("[Aevrix Hub]",err)
    end
end)

Connect(P.CharacterAdded,function()
    ClearFlight()
    RestoreNoclip()

    S.Target,S.ChestTarget = nil,nil
    ResetCombat()
end)

Connect(UIS.InputBegan,function(input)
    if not S.Running
        or UIS:GetFocusedTextBox()
    then
        return
    end

    if input.UserInputType == Enum.UserInputType.Keyboard
        and input.KeyCode == Enum.KeyCode[A.Hotkey]
    then
        SetFarm(not A.Farm)
    end
end)

task.spawn(function()
    while S.Running do
        if A.Farm then
            local ok,err = pcall(UpdateQuest)

            if not ok and os.clock()-S.LastError > 3 then
                S.LastError = os.clock()
                warn("[Aevrix Quest]",err)
            end
        end

        task.wait(0.1)
    end
end)

task.spawn(function()
    while S.Running do
        if A.Farm
            and os.clock()-S.LastMemory >= 2
        then
            S.LastMemory = os.clock()
            pcall(RememberNPCs)
        end

        if (A.Chest or A.ChestESP)
            and os.clock()-S.LastChest >= 5
        then
            pcall(RefreshChests)
        end

        pcall(UpdateESP)
        task.wait(0.5)
    end
end)

task.spawn(function()
    while S.Running do
        if A.Stats
            and os.clock()-S.LastStat >= 1
        then
            S.LastStat = os.clock()

            local ok,err = pcall(DistributeStats)

            if not ok then
                S.StatBusy = false
                warn("[Aevrix Stats]",err)
            end
        end

        task.wait(0.25)
    end
end)

local function Cleanup()
    S.Running = false
    A.Farm,A.Chest,A.Stats = false,false,false

    Stop()

    for _,conn in ipairs(S.Connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end

    for obj in pairs(S.Highlights) do
        RemoveESP(obj)
    end

    if S.Library then
        pcall(function()
            S.Library:Unload()
        end)
    end
end

Env.AevrixCleanup = Cleanup

-- FLUENT UI

local ok,Lib = pcall(function()
    return loadstring(game:HttpGetAsync(
        "https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"
    ))()
end)

if not ok then
    Cleanup()
    error("[Aevrix Hub] "..tostring(Lib))
end

S.Library = Lib

Notify = function(title,message)
    pcall(function()
        Lib:Notify({
            Title = "Aevrix Hub | "..title,
            Content = message,
            Duration = 3
        })
    end)
end

local Window = Lib:CreateWindow({
    Title = "Aevrix Hub",
    SubTitle = "Blox Fruits Auto Farm",
    TabWidth = 145,
    Size = UDim2.fromOffset(650,455),
    Resize = true,
    MinSize = Vector2.new(470,350),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local FarmTab = Window:CreateTab({
    Title = "Auto Farm",
    Icon = "swords"
})

local ChestTab = Window:CreateTab({
    Title = "Auto Chest",
    Icon = "package"
})

local ESPTab = Window:CreateTab({
    Title = "ESP",
    Icon = "eye"
})

local StatsTab = Window:CreateTab({
    Title = "Auto Stats",
    Icon = "chart-no-axes-column"
})

local SettingsTab = Window:CreateTab({
    Title = "Settings",
    Icon = "settings"
})

local function Toggle(tab,id,title,key)
    return tab:CreateToggle(id,{
        Title = title,
        Default = A[key],

        Callback = function(value)
            if S.Updating then return end

            if key == "Farm" then
                SetFarm(value)

            elseif key == "Chest" then
                SetChest(value)

            else
                A[key] = value
            end
        end
    })
end

local function Slider(tab,id,title,key,min,max,round)
    tab:CreateSlider(id,{
        Title = title,
        Min = min,
        Max = max,
        Default = A[key],
        Rounding = round or 0,

        Callback = function(value)
            A[key] = value
        end
    })
end

local function Drop(tab,id,title,key,values)
    tab:CreateDropdown(id,{
        Title = title,
        Values = values,
        Multi = false,
        Default = table.find(values,A[key]) or 1,

        Callback = function(value)
            A[key] = value
        end
    })
end

FarmTab:CreateParagraph("FarmInfo",{
    Title = "Auto Farm",
    Content = "Default hotkey is F. Change it in Settings."
})

S.FarmToggle = Toggle(
    FarmTab,"Farm","Auto Farm","Farm"
)

Slider(
    FarmTab,"Target","Target Level",
    "TargetLevel",1,3000
)

Slider(
    FarmTab,"Speed","Movement Speed",
    "Speed",50,650
)

Drop(
    FarmTab,"Weapon","Weapon","Weapon",
    {"Melee","Sword","Gun","Fruit"}
)

Slider(
    FarmTab,"Range","Attack Range",
    "Range",3,50
)

Slider(
    FarmTab,"Delay","Attack Interval",
    "Delay",0.05,1,2
)

Toggle(
    FarmTab,"Skills","Auto Skills","Skills"
)

FarmTab:CreateParagraph("SkillsWarning",{
    Title = "Auto Skills",
    Content = "May cause you to get hit."
})

Slider(
    FarmTab,"SkillCooldown","Skill Cooldown",
    "SkillCooldown",1,30
)

S.ChestToggle = Toggle(
    ChestTab,"Chest","Auto Chest","Chest"
)

Slider(
    ChestTab,"ChestSpeed","Chest Movement Speed",
    "ChestSpeed",50,650
)

Toggle(
    ESPTab,"PlayerESP","Player ESP","PlayerESP"
)

Drop(
    ESPTab,"PlayerColor","Player Color",
    "PlayerColor",ColorNames
)

Toggle(
    ESPTab,"ChestESP","Chest ESP","ChestESP"
)

Drop(
    ESPTab,"ChestColor","Chest Color",
    "ChestColor",ColorNames
)

Toggle(
    StatsTab,"AutoStats","Auto Stats","Stats"
)

StatsTab:CreateDropdown("MultiStats",{
    Title = "Stats",
    Values = StatNames,
    Multi = true,
    Default = {"Melee"},

    Callback = function(values)
        local selected = {}

        for name,enabled in pairs(values) do
            if enabled
                and table.find(StatNames,name)
            then
                selected[name] = true
            end
        end

        A.SelectedStats = selected
        S.StatIndex = 1
    end
})

Slider(
    StatsTab,"Points","Points Per Use",
    "Points",1,100
)

local Hotkeys = {}

for key in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do
    table.insert(Hotkeys,key)
end

for i = 1,10 do
    table.insert(Hotkeys,"F"..i)
end

Drop(
    SettingsTab,"Hotkey","Auto Farm Hotkey",
    "Hotkey",Hotkeys
)

Window:SelectTab(1)

Notify("Loaded","Blox Fruits Auto Farm")
print("[Aevrix Hub] Loaded")
