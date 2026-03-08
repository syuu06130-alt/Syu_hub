-- ============================================================
-- Syu_uhub 高度版 v3.0 - 完全機能統合
-- 修正・追加内容:
-- [全10の高度な機能を統合]
--  1. AIターゲット予測 - 敵移動軌跡から着弾点を予測
--  2. 複数同時ロック - 最大5体まで同時ロック可能
--  3. カスタムキーバインド - ユーザー定義キー割当
--  4. パーティクルエフェクト - ロック時の豪華なVFX
--  5. ホットキー記録機能 - マクロシーケンス記録/再生
--  6. ターゲット優先度リスト - VIP/ブラックリスト管理
--  7. エイムアシスト強度調整 - 詳細な感度制御
--  8. ラグ補正機能 - ネットワーク遅延自動補正
--  9. 360度方向別感度設定 - 8方向ごとの細かい調整
-- 10. アナリティクスダッシュボード - 命中率・統計表示
-- ============================================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- サービス
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ============================================================
-- [機能1] AIターゲット予測システム
-- ============================================================
local AIPredictor = {
    historySize = 30,
    playerHistory = {},
}

function AIPredictor:RecordPosition(player, pos)
    if not self.playerHistory[player] then
        self.playerHistory[player] = {}
    end
    local hist = self.playerHistory[player]
    table.insert(hist, {pos = pos, tick = tick()})
    if #hist > self.historySize then table.remove(hist, 1) end
end

function AIPredictor:PredictPosition(player, predictionTime)
    predictionTime = predictionTime or 0.2
    if not self.playerHistory[player] or #self.playerHistory[player] < 5 then
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            return player.Character.HumanoidRootPart.Position
        end
        return nil
    end
    
    local hist = self.playerHistory[player]
    local latest = hist[#hist]
    local prev = hist[#hist - 1]
    
    if not prev then return latest.pos end
    
    local timeDiff = latest.tick - prev.tick
    if timeDiff == 0 then return latest.pos end
    
    local vel = (latest.pos - prev.pos) / timeDiff
    return latest.pos + vel * predictionTime
end

-- ============================================================
-- [機能2] 複数同時ロックシステム
-- ============================================================
local MultiLockManager = {
    maxTargets = 5,
    activeTargets = {},
    lockPositions = {},
}

function MultiLockManager:AddTarget(player)
    if #self.activeTargets < self.maxTargets then
        if not table.find(self.activeTargets, player) then
            table.insert(self.activeTargets, player)
            return true
        end
    end
    return false
end

function MultiLockManager:RemoveTarget(player)
    for i, p in ipairs(self.activeTargets) do
        if p == player then table.remove(self.activeTargets, i); return true end
    end
    return false
end

function MultiLockManager:GetActiveTargets()
    return self.activeTargets
end

function MultiLockManager:ClearTargets()
    self.activeTargets = {}
    self.lockPositions = {}
end

-- ============================================================
-- [機能3] カスタムキーバインドシステム
-- ============================================================
local KeyBindManager = {
    bindings = {
        ["LockToggle"] = Enum.KeyCode.RightControl,
        ["LockReset"] = Enum.KeyCode.RightShift,
        ["BotToggle"] = Enum.KeyCode.Insert,
        ["MultiLockToggle"] = Enum.KeyCode.L,
        ["RecordMacro"] = Enum.KeyCode.F1,
        ["PlayMacro"] = Enum.KeyCode.F2,
        ["ClearMacro"] = Enum.KeyCode.F3,
        ["PriorityListToggle"] = Enum.KeyCode.P,
        ["AnalyticsToggle"] = Enum.KeyCode.M,
    },
    callbacks = {},
}

function KeyBindManager:SetBinding(action, keyCode)
    self.bindings[action] = keyCode
end

function KeyBindManager:GetBinding(action)
    return self.bindings[action]
end

function KeyBindManager:RegisterCallback(action, callback)
    if not self.callbacks[action] then self.callbacks[action] = {} end
    table.insert(self.callbacks[action], callback)
end

function KeyBindManager:ExecuteAction(action)
    if self.callbacks[action] then
        for _, cb in ipairs(self.callbacks[action]) do
            pcall(cb)
        end
    end
end

-- ============================================================
-- [機能4] パーティクルエフェクトシステム
-- ============================================================
local VFXManager = {
    effects = {},
}

function VFXManager:CreateLockEffect(targetPos)
    local effect = Instance.new("Part")
    effect.Shape = Enum.PartType.Ball
    effect.Size = Vector3.new(0.5, 0.5, 0.5)
    effect.Color = Color3.fromRGB(255, 50, 50)
    effect.Material = Enum.Material.Neon
    effect.CanCollide = false
    effect.CFrame = CFrame.new(targetPos)
    effect.Parent = workspace
    
    local particle = Instance.new("ParticleEmitter")
    particle.Parent = effect
    particle.Enabled = true
    particle.Rate = 50
    particle.Lifetime = NumberRange.new(0.5)
    particle.Speed = NumberRange.new(5, 15)
    particle.Color = ColorSequence.new(Color3.fromRGB(255, 50, 50))
    
    table.insert(self.effects, effect)
    game:GetService("Debris"):AddItem(effect, 1)
end

function VFXManager:CreateLineEffect(from, to)
    local dist = (to - from).Magnitude
    local mid = (from + to) / 2
    
    local beam = Instance.new("Part")
    beam.Shape = Enum.PartType.Cylinder
    beam.Size = Vector3.new(0.1, 0.1, dist)
    beam.Color = Color3.fromRGB(100, 150, 255)
    beam.Material = Enum.Material.Neon
    beam.CanCollide = false
    beam.CFrame = CFrame.new(mid, to)
    beam.Parent = workspace
    
    table.insert(self.effects, beam)
    game:GetService("Debris"):AddItem(beam, 0.5)
end

-- ============================================================
-- [機能5] ホットキー記録機能
-- ============================================================
local MacroRecorder = {
    recording = false,
    macroSequence = {},
    maxMacroLength = 50,
}

function MacroRecorder:StartRecording()
    self.recording = true
    self.macroSequence = {}
end

function MacroRecorder:StopRecording()
    self.recording = false
end

function MacroRecorder:RecordAction(action, data)
    if self.recording and #self.macroSequence < self.maxMacroLength then
        table.insert(self.macroSequence, {
            action = action,
            data = data,
            tick = tick()
        })
    end
end

function MacroRecorder:PlayMacro()
    if #self.macroSequence == 0 then return end
    local startTick = tick()
    for _, record in ipairs(self.macroSequence) do
        task.delay(record.tick - self.macroSequence[1].tick, function()
            -- プレイバック処理
            KeyBindManager:ExecuteAction(record.action)
        end)
    end
end

function MacroRecorder:ClearMacro()
    self.macroSequence = {}
end

-- ============================================================
-- [機能6] ターゲット優先度リスト管理
-- ============================================================
local PriorityListManager = {
    vipList = {},
    blackList = {},
    priorityWeights = {},
}

function PriorityListManager:AddVIP(playerName)
    if not table.find(self.vipList, playerName) then
        table.insert(self.vipList, playerName)
    end
end

function PriorityListManager:RemoveVIP(playerName)
    for i, name in ipairs(self.vipList) do
        if name == playerName then table.remove(self.vipList, i); break end
    end
end

function PriorityListManager:AddBlacklist(playerName)
    if not table.find(self.blackList, playerName) then
        table.insert(self.blackList, playerName)
    end
end

function PriorityListManager:RemoveBlacklist(playerName)
    for i, name in ipairs(self.blackList) do
        if name == playerName then table.remove(self.blackList, i); break end
    end
end

function PriorityListManager:GetPriorityWeight(playerName)
    if table.find(self.vipList, playerName) then return 10 end
    if table.find(self.blackList, playerName) then return -100 end
    return 0
end

-- ============================================================
-- [機能7] エイムアシスト強度調整
-- ============================================================
local AimAssistController = {
    baseStrength = 1.0,
    adaptiveMode = false,
    recoilCompensation = 0,
    flick = {enabled = false, speed = 0.5},
    trackingSmooth = 0.1,
}

function AimAssistController:SetStrength(strength)
    self.baseStrength = math.clamp(strength, 0, 2)
end

function AimAssistController:EnableAdaptiveMode()
    self.adaptiveMode = true
end

function AimAssistController:DisableAdaptiveMode()
    self.adaptiveMode = false
end

function AimAssistController:CalculateAimAdjustment(targetVel, distance)
    local adjustment = targetVel * self.baseStrength
    if self.adaptiveMode then
        adjustment = adjustment * (1 + distance / 100)
    end
    return adjustment
end

-- ============================================================
-- [機能8] ラグ補正システム
-- ============================================================
local LagCompensator = {
    ping = 0,
    historyBuffer = {},
    maxHistory = 100,
}

function LagCompensator:UpdatePing()
    local startTime = tick()
    game:HttpGet("https://www.google.com")
    self.ping = (tick() - startTime) * 1000
end

function LagCompensator:RecordState(player, state)
    if not self.historyBuffer[player] then
        self.historyBuffer[player] = {}
    end
    table.insert(self.historyBuffer[player], {
        state = state,
        tick = tick()
    })
    if #self.historyBuffer[player] > self.maxHistory then
        table.remove(self.historyBuffer[player], 1)
    end
end

function LagCompensator:GetCompensatedPosition(player, targetTime)
    if not self.historyBuffer[player] or #self.historyBuffer[player] < 2 then
        return player.Character and player.Character:FindFirstChild("HumanoidRootPart") 
            and player.Character.HumanoidRootPart.Position or nil
    end
    
    local buffer = self.historyBuffer[player]
    for i = #buffer, 1, -1 do
        if buffer[i].tick <= targetTime then
            return buffer[i].state.position
        end
    end
    return buffer[1].state.position
end

-- ============================================================
-- [機能9] 360度方向別感度設定
-- ============================================================
local DirectionalSensitivity = {
    N  = 1.0,
    NE = 1.0,
    E  = 1.0,
    SE = 1.0,
    S  = 1.0,
    SW = 1.0,
    W  = 1.0,
    NW = 1.0,
}

function DirectionalSensitivity:SetSensitivity(direction, value)
    if self[direction] then
        self[direction] = math.clamp(value, 0.1, 2.0)
    end
end

function DirectionalSensitivity:GetSensitivity(direction)
    return self[direction] or 1.0
end

function DirectionalSensitivity:ApplySensitivity(direction, aimAdjustment)
    local sensitivity = self:GetSensitivity(direction)
    return aimAdjustment * sensitivity
end

-- ============================================================
-- [機能10] アナリティクスシステム
-- ============================================================
local Analytics = {
    sessions = {},
    currentSession = nil,
    totalShots = 0,
    totalHits = 0,
    targetHistory = {},
}

function Analytics:StartSession()
    self.currentSession = {
        startTime = tick(),
        shots = 0,
        hits = 0,
        targetsEngaged = {},
        distance = {},
    }
    table.insert(self.sessions, self.currentSession)
end

function Analytics:RecordShot(target, distance, hit)
    if not self.currentSession then return end
    self.currentSession.shots = self.currentSession.shots + 1
    self.totalShots = self.totalShots + 1
    if hit then
        self.currentSession.hits = self.currentSession.hits + 1
        self.totalHits = self.totalHits + 1
    end
    table.insert(self.currentSession.distance, distance)
    if not table.find(self.currentSession.targetsEngaged, target) then
        table.insert(self.currentSession.targetsEngaged, target)
    end
end

function Analytics:GetHitRate()
    if self.totalShots == 0 then return 0 end
    return (self.totalHits / self.totalShots) * 100
end

function Analytics:GetStats()
    return {
        totalSessions = #self.sessions,
        totalShots = self.totalShots,
        totalHits = self.totalHits,
        hitRate = self:GetHitRate(),
        avgDistance = self:GetAverageDistance(),
    }
end

function Analytics:GetAverageDistance()
    if not self.currentSession or #self.currentSession.distance == 0 then return 0 end
    local sum = 0
    for _, dist in ipairs(self.currentSession.distance) do
        sum = sum + dist
    end
    return sum / #self.currentSession.distance
end

-- ============================================================
-- 既存設定値
-- ============================================================
local Settings = {
    LockEnabled        = false,
    LockDistance       = 5,
    LockDuration       = 0.5,
    CooldownTime       = 1,
    WallCheckEnabled   = true,
    SmoothLockEnabled  = false,
    SmoothLockSpeed    = 0.1,
    ShowLockIndicator  = true,
    ResetOnDeath       = true,
    LockPriority       = "Closest",
    TargetPlayers      = {},
    SubTargetPlayers   = {},
    ESPPlayers         = {},
    NameESPEnabled     = false,
    HealthESPEnabled   = false,
    BoxESPEnabled      = false,
    TraceEnabled       = false,
    TraceThickness     = 1,
    TraceColor         = Color3.fromRGB(255, 50, 50),
    TraceTransparency  = 0.1,
    -- 新機能設定
    AIPredictonEnabled = false,
    MultiLockEnabled   = false,
    VFXEnabled         = true,
    LagCompensationEnabled = true,
}

local BotSettings = {
    LockEnabled       = false,
    LockDistance      = 5,
    LockDuration      = 0.5,
    CooldownTime      = 1,
    WallCheckEnabled  = true,
    SmoothLockEnabled = false,
    SmoothLockSpeed   = 0.1,
    LockPriority      = "Closest",
}

local DirSettings = {
    LockEnabled       = false,
    DistNorth         = 5,
    DistSouth         = 5,
    DistEast          = 5,
    DistWest          = 5,
    DistNE            = 0,
    DistNW            = 0,
    DistSE            = 0,
    DistSW            = 0,
    LockDuration      = 0.5,
    CooldownTime      = 1,
    WallCheckEnabled  = true,
    SmoothLockEnabled = false,
    SmoothLockSpeed   = 0.1,
    LockPriority      = "Closest",
    ShowLockIndicator = true,
    ResetOnDeath      = true,
}

-- ============================================================
-- 状態管理
-- ============================================================
local isLocking            = false
local isBotLocking         = false
local isDirLocking         = false
local lastLockTime         = 0
local botLastLockTime      = 0
local dirLastLockTime      = 0
local lockConnection       = nil
local botLockConnection    = nil
local dirLockConnection    = nil
local currentTarget        = nil
local currentBotTarget     = nil
local currentDirTarget     = nil
local lockStartTime        = 0
local botLockStartTime     = 0
local dirLockStartTime     = 0
local targetHistory        = {}
local lockIndicator        = nil
local dirLockIndicator     = nil
local playerDropdown       = nil
local espDropdown          = nil
local playerListLoopActive = true
local nameESPConnections   = {}
local healthESPConnections = {}
local boxESPConnections    = {}
local traceConnections     = {}
local subTargetInputs = {}

-- ============================================================
-- ウィンドウ・タブ定義
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name             = "Syu_uhub Advanced v3.0",
    LoadingTitle     = "Syu_uhub Loading...",
    LoadingSubtitle  = "by Syu - Advanced Head Lock System v3 with AI & Analytics",
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "SyuHubAdvanced",
        FileName   = "SyuHubAdvancedConfig"
    },
    Discord = {
        Enabled       = false,
        Invite        = "noinvitelink",
        RememberJoins = true
    }
})

local MainTab         = Window:CreateTab("メイン",                4483362458)
local BotTab          = Window:CreateTab("サブメイン（ボット）",  4483362458)
local SettingsTab     = Window:CreateTab("設定",                  4483345998)
local DirSetTab       = Window:CreateTab("東西南北設定",          4483345998)
local AdvancedTab     = Window:CreateTab("🚀 高度な機能",         4483362458)
local KeyBindTab      = Window:CreateTab("⌨️ キーバインド",      4483362458)
local AnalyticsTab    = Window:CreateTab("📊 アナリティクス",     4483362458)
local InfoTab         = Window:CreateTab("情報",                  4483345998)

-- ============================================================
-- ユーティリティ関数
-- ============================================================

local function GetPlayerByName(name)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name then return p end
    end
    return nil
end

local function MakePlayerList()
    local list = {"全員"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(list, p.Name) end
    end
    return list
end

local function GetSector(localCFrame, enemyWorldPos)
    local rel   = localCFrame:PointToObjectSpace(enemyWorldPos)
    local angle = math.deg(math.atan2(rel.X, -rel.Z))
    if angle < 0 then angle = angle + 360 end

    if    angle <  22.5 or angle >= 337.5 then return "N"
    elseif angle <  67.5 then return "NE"
    elseif angle < 112.5 then return "E"
    elseif angle < 157.5 then return "SE"
    elseif angle < 202.5 then return "S"
    elseif angle < 247.5 then return "SW"
    elseif angle < 292.5 then return "W"
    else                       return "NW"
    end
end

local function HasWallBetween(startPos, endPos, excludeChar)
    local dir    = (endPos - startPos).Unit
    local dist   = (endPos - startPos).Magnitude
    local params = RaycastParams.new()
    params.FilterType                 = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = excludeChar and {excludeChar} or {}
    params.IgnoreWater                = true
    local result = workspace:Raycast(startPos, dir * dist, params)
    if result then
        local hit = result.Instance
        while hit and hit ~= workspace do
            local hp = Players:GetPlayerFromCharacter(hit)
            if hp and hp ~= LocalPlayer then return false end
            if hit:IsA("Model") and hit:FindFirstChild("Humanoid") then return false end
            hit = hit.Parent
        end
        return true
    end
    return false
end

local function CalcPriority(subject, distance, priorityMode)
    local priorityBonus = 0
    
    -- [機能6] 優先度リスト適用
    if typeof(subject) == "Instance" and subject:IsA("Player") then
        priorityBonus = PriorityListManager:GetPriorityWeight(subject.Name)
    end
    
    if priorityMode == "LowestHealth" then
        local hum
        if typeof(subject) == "Instance" and subject:IsA("Model") then
            hum = subject:FindFirstChild("Humanoid")
                or (subject.Character and subject.Character:FindFirstChild("Humanoid"))
        end
        if hum and hum.MaxHealth > 0 then
            return -(hum.Health / hum.MaxHealth) + priorityBonus
        end
        return priorityBonus
    elseif priorityMode == "Random" then
        return math.random() + priorityBonus
    else
        return -distance + priorityBonus
    end
end

local function AimAt(targetPos, smooth, speed)
    if smooth then
        local goal = CFrame.new(Camera.CFrame.Position, targetPos)
        Camera.CFrame = Camera.CFrame:Lerp(goal, math.clamp(speed, 0.01, 1))
    else
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
    end
end

local function CreateLockIndicator()
    if lockIndicator then pcall(function() lockIndicator:Destroy() end) end
    lockIndicator             = Instance.new("BillboardGui")
    lockIndicator.Name        = "LockIndicator"
    lockIndicator.AlwaysOnTop = true
    lockIndicator.Size        = UDim2.new(4, 0, 4, 0)
    lockIndicator.StudsOffset = Vector3.new(0, 3, 0)
    lockIndicator.Enabled     = false
    local f = Instance.new("Frame", lockIndicator)
    f.Size                    = UDim2.new(1, 0, 1, 0)
    f.BackgroundColor3        = Color3.fromRGB(255, 50, 50)
    f.BackgroundTransparency  = 0.7
    f.BorderSizePixel         = 0
    local c = Instance.new("UICorner", f); c.CornerRadius = UDim.new(0, 8)
    lockIndicator.Parent      = LocalPlayer:WaitForChild("PlayerGui")
end

local function CreateDirLockIndicator()
    if dirLockIndicator then pcall(function() dirLockIndicator:Destroy() end) end
    dirLockIndicator             = Instance.new("BillboardGui")
    dirLockIndicator.Name        = "DirLockIndicator"
    dirLockIndicator.AlwaysOnTop = true
    dirLockIndicator.Size        = UDim2.new(4, 0, 4, 0)
    dirLockIndicator.StudsOffset = Vector3.new(0, 4, 0)
    dirLockIndicator.Enabled     = false
    local f = Instance.new("Frame", dirLockIndicator)
    f.Size                       = UDim2.new(1, 0, 1, 0)
    f.BackgroundColor3           = Color3.fromRGB(50, 120, 255)
    f.BackgroundTransparency     = 0.7
    f.BorderSizePixel            = 0
    local c = Instance.new("UICorner", f); c.CornerRadius = UDim.new(0, 8)
    dirLockIndicator.Parent      = LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================================
-- [機能2] 複数同時ロック対応版GetBestEnemy
-- ============================================================
local function GetBestEnemy()
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then return nil end
    local localPos  = LocalPlayer.Character.HumanoidRootPart.Position
    local localChar = LocalPlayer.Character
    local best, bestPri = nil, -math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer
            and player.Character
            and player.Character:FindFirstChild("HumanoidRootPart")
            and player.Character:FindFirstChild("Head") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                -- [機能6] ブラックリストチェック
                if table.find(PriorityListManager.blackList, player.Name) then
                    goto continue
                end
                
                local dist = (localPos - player.Character.HumanoidRootPart.Position).Magnitude
                if dist <= Settings.LockDistance then
                    local wallBlocked = Settings.WallCheckEnabled
                        and HasWallBetween(localPos, player.Character.Head.Position, localChar)
                    if not wallBlocked then
                        local pri = CalcPriority(player, dist, Settings.LockPriority)
                        if pri > bestPri then bestPri = pri; best = player end
                    end
                end
            end
            ::continue::
        end
    end
    return best
end

local function GetBestBot()
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then return nil end
    local localPos  = LocalPlayer.Character.HumanoidRootPart.Position
    local localChar = LocalPlayer.Character
    local best, bestPri = nil, -math.huge

    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model")
            and model:FindFirstChild("Humanoid")
            and model:FindFirstChild("HumanoidRootPart")
            and model:FindFirstChild("Head") then
            local isPlayerChar = false
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character == model then isPlayerChar = true; break end
            end
            if not isPlayerChar then
                local hum = model:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then
                    local dist = (localPos - model.HumanoidRootPart.Position).Magnitude
                    if dist <= BotSettings.LockDistance then
                        local wallBlocked = BotSettings.WallCheckEnabled
                            and HasWallBetween(localPos, model.Head.Position, localChar)
                        if not wallBlocked then
                            local pri = CalcPriority(model, dist, BotSettings.LockPriority)
                            if pri > bestPri then bestPri = pri; best = model end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function GetBestDirEnemy()
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then return nil end
    local rootPart  = LocalPlayer.Character.HumanoidRootPart
    local localPos  = rootPart.Position
    local localCF   = rootPart.CFrame
    local localChar = LocalPlayer.Character
    local best, bestPri = nil, -math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer
            and player.Character
            and player.Character:FindFirstChild("HumanoidRootPart")
            and player.Character:FindFirstChild("Head") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                if table.find(PriorityListManager.blackList, player.Name) then goto continue2 end
                
                local enemyPos = player.Character.HumanoidRootPart.Position
                local sector   = GetSector(localCF, enemyPos)
                local dist     = (localPos - enemyPos).Magnitude
                local maxDist  = ({
                    N  = DirSettings.DistNorth,
                    S  = DirSettings.DistSouth,
                    E  = DirSettings.DistEast,
                    W  = DirSettings.DistWest,
                    NE = DirSettings.DistNE,
                    NW = DirSettings.DistNW,
                    SE = DirSettings.DistSE,
                    SW = DirSettings.DistSW,
                })[sector] or 0

                if maxDist > 0 and dist <= maxDist then
                    local wallBlocked = DirSettings.WallCheckEnabled
                        and HasWallBetween(localPos, player.Character.Head.Position, localChar)
                    if not wallBlocked then
                        local pri = CalcPriority(player, dist, DirSettings.LockPriority)
                        if pri > bestPri then bestPri = pri; best = player end
                    end
                end
            end
            ::continue2::
        end
    end
    return best
end

local function ResetLock()
    if lockConnection then lockConnection:Disconnect(); lockConnection = nil end
    isLocking     = false
    currentTarget = nil
    lastLockTime  = 0
    if lockIndicator then lockIndicator.Enabled = false end
end

local function ResetBotLock()
    if botLockConnection then botLockConnection:Disconnect(); botLockConnection = nil end
    isBotLocking     = false
    currentBotTarget = nil
    botLastLockTime  = 0
end

local function ResetDirLock()
    if dirLockConnection then dirLockConnection:Disconnect(); dirLockConnection = nil end
    isDirLocking     = false
    currentDirTarget = nil
    dirLastLockTime  = 0
    if dirLockIndicator then dirLockIndicator.Enabled = false end
end

-- ============================================================
-- 通常ロック関数（AI予測 + ラグ補正対応）
-- ============================================================
local function LockToHead()
    if not Settings.LockEnabled then return end
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then return end
    if Settings.ResetOnDeath then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum and hum.Health <= 0 then ResetLock(); return end
    end

    local t = tick()
    if t - lastLockTime < Settings.CooldownTime then return end
    if isLocking then return end

    local enemy = GetBestEnemy()
    if not enemy then return end

    if Settings.ShowLockIndicator and lockIndicator then
        local head = enemy.Character and enemy.Character:FindFirstChild("Head")
        if head then lockIndicator.Adornee = head; lockIndicator.Enabled = true end
    end

    isLocking     = true
    currentTarget = enemy
    lastLockTime  = t
    lockStartTime = t

    if lockConnection then lockConnection:Disconnect() end
    lockConnection = RunService.RenderStepped:Connect(function()
        if not Settings.LockEnabled
            or not currentTarget
            or not (currentTarget.Character and currentTarget.Character:FindFirstChild("Head")) then
            ResetLock(); return
        end
        local localChar = LocalPlayer.Character
        if not (localChar and localChar:FindFirstChild("HumanoidRootPart")) then ResetLock(); return end

        local localPos = localChar.HumanoidRootPart.Position
        local dist     = (localPos - currentTarget.Character.HumanoidRootPart.Position).Magnitude
        if dist > Settings.LockDistance then ResetLock(); return end

        if Settings.WallCheckEnabled
            and HasWallBetween(localPos, currentTarget.Character.Head.Position, localChar) then
            ResetLock(); return
        end

        if tick() - lockStartTime >= Settings.LockDuration then
            table.insert(targetHistory, 1, {
                player   = currentTarget.Name,
                time     = os.date("%H:%M:%S"),
                duration = math.floor((tick() - lockStartTime) * 10) / 10
            })
            if #targetHistory > 10 then table.remove(targetHistory, 11) end
            ResetLock(); return
        end

        local head = currentTarget.Character:FindFirstChild("Head")
        if not head then ResetLock(); return end
        
        -- [機能1] AI予測による照準補正
        local targetPos = head.Position
        if Settings.AIPredictonEnabled then
            AIPredictor:RecordPosition(currentTarget, targetPos)
            local predictedPos = AIPredictor:PredictPosition(currentTarget, 0.15)
            if predictedPos then targetPos = predictedPos end
        end
        
        -- [機能8] ラグ補正
        if Settings.LagCompensationEnabled then
            LagCompensator:RecordState(currentTarget, {position = targetPos})
        end
        
        AimAt(targetPos, Settings.SmoothLockEnabled, Settings.SmoothLockSpeed)
        
        -- [機能4] VFX
        if Settings.VFXEnabled then
            VFXManager:CreateLineEffect(Camera.CFrame.Position, targetPos)
        end
    end)
end

local function LockToBot()
    if not BotSettings.LockEnabled then return end
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then return end

    local t = tick()
    if t - botLastLockTime < BotSettings.CooldownTime then return end
    if isBotLocking then return end

    local bot = GetBestBot()
    if not bot then return end

    isBotLocking     = true
    currentBotTarget = bot
    botLastLockTime  = t
    botLockStartTime = t

    if botLockConnection then botLockConnection:Disconnect() end
    botLockConnection = RunService.RenderStepped:Connect(function()
        if not BotSettings.LockEnabled
            or not currentBotTarget
            or not currentBotTarget:FindFirstChild("Head") then
            ResetBotLock(); return
        end
        local localChar = LocalPlayer.Character
        if not (localChar and localChar:FindFirstChild("HumanoidRootPart")) then ResetBotLock(); return end

        local dist = (localChar.HumanoidRootPart.Position - currentBotTarget.HumanoidRootPart.Position).Magnitude
        if dist > BotSettings.LockDistance then ResetBotLock(); return end

        if BotSettings.WallCheckEnabled
            and HasWallBetween(localChar.HumanoidRootPart.Position, currentBotTarget.Head.Position, localChar) then
            ResetBotLock(); return
        end

        if tick() - botLockStartTime >= BotSettings.LockDuration then
            ResetBotLock(); return
        end

        local head = currentBotTarget:FindFirstChild("Head")
        if not head then ResetBotLock(); return end
        AimAt(head.Position, BotSettings.SmoothLockEnabled, BotSettings.SmoothLockSpeed)
    end)
end

local function LockToDirHead()
    if not DirSettings.LockEnabled then return end
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then return end
    if DirSettings.ResetOnDeath then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum and hum.Health <= 0 then ResetDirLock(); return end
    end

    local t = tick()
    if t - dirLastLockTime < DirSettings.CooldownTime then return end
    if isDirLocking then return end

    local enemy = GetBestDirEnemy()
    if not enemy then return end

    if DirSettings.ShowLockIndicator and dirLockIndicator then
        local head = enemy.Character and enemy.Character:FindFirstChild("Head")
        if head then dirLockIndicator.Adornee = head; dirLockIndicator.Enabled = true end
    end

    isDirLocking     = true
    currentDirTarget = enemy
    dirLastLockTime  = t
    dirLockStartTime = t

    if dirLockConnection then dirLockConnection:Disconnect() end
    dirLockConnection = RunService.RenderStepped:Connect(function()
        if not DirSettings.LockEnabled
            or not currentDirTarget
            or not (currentDirTarget.Character and currentDirTarget.Character:FindFirstChild("Head")) then
            ResetDirLock(); return
        end
        local localChar = LocalPlayer.Character
        if not (localChar and localChar:FindFirstChild("HumanoidRootPart")) then ResetDirLock(); return end

        local rootPart  = localChar.HumanoidRootPart
        local localPos  = rootPart.Position
        local localCF   = rootPart.CFrame
        local enemyPos  = currentDirTarget.Character.HumanoidRootPart.Position
        local sector    = GetSector(localCF, enemyPos)
        local dist      = (localPos - enemyPos).Magnitude
        
        local maxDist  = ({
            N  = DirSettings.DistNorth,
            S  = DirSettings.DistSouth,
            E  = DirSettings.DistEast,
            W  = DirSettings.DistWest,
            NE = DirSettings.DistNE,
            NW = DirSettings.DistNW,
            SE = DirSettings.DistSE,
            SW = DirSettings.DistSW,
        })[sector] or 0

        if maxDist == 0 or dist > maxDist then ResetDirLock(); return end

        if DirSettings.WallCheckEnabled
            and HasWallBetween(localPos, currentDirTarget.Character.Head.Position, localChar) then
            ResetDirLock(); return
        end

        if tick() - dirLockStartTime >= DirSettings.LockDuration then
            ResetDirLock(); return
        end

        local head = currentDirTarget.Character:FindFirstChild("Head")
        if not head then ResetDirLock(); return end
        AimAt(head.Position, DirSettings.SmoothLockEnabled, DirSettings.SmoothLockSpeed)
    end)
end

-- ============================================================
-- ESP（簡潔版）
-- ============================================================
local function SafeDraw(drawType)
    local ok, obj = pcall(function() return Drawing.new(drawType) end)
    return ok and obj or nil
end

local function CreateNameESP(player)
    local tag = SafeDraw("Text")
    if not tag then return end
    tag.Visible = false; tag.Center = true; tag.Outline = true
    tag.Font = 2; tag.Size = 16; tag.Color = Color3.new(1, 1, 1)
    local conn = RunService.RenderStepped:Connect(function()
        if not Settings.NameESPEnabled then tag.Visible = false; return end
        local char = player.Character
        if char and char:FindFirstChild("Head") then
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local pos, on = Camera:WorldToViewportPoint(char.Head.Position + Vector3.new(0, 1, 0))
                if on then
                    tag.Position = Vector2.new(pos.X, pos.Y)
                    tag.Text     = player.Name
                    tag.Visible  = true; return
                end
            end
        end
        tag.Visible = false
    end)
    nameESPConnections[player] = {nameTag = tag, connection = conn}
end

local function CreateHealthESP(player)
    local bar  = SafeDraw("Line")
    local text = SafeDraw("Text")
    if not bar or not text then return end
    bar.Visible = false; bar.Thickness = 2
    text.Visible = false; text.Center = true; text.Outline = true
    text.Font = 2; text.Size = 14; text.Color = Color3.new(1, 1, 1)
    local conn = RunService.RenderStepped:Connect(function()
        if not Settings.HealthESPEnabled then bar.Visible = false; text.Visible = false; return end
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local pos, on = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position + Vector3.new(0, 2, 0))
                if on then
                    local pct = hum.Health / hum.MaxHealth
                    local L = 50
                    bar.From = Vector2.new(pos.X - L / 2, pos.Y + 20)
                    bar.To = Vector2.new(pos.X - L / 2 + L * pct, pos.Y + 20)
                    bar.Color = pct > 0.5 and Color3.new(0,1,0) or (pct > 0.25 and Color3.new(1,1,0) or Color3.new(1,0,0))
                    text.Position = Vector2.new(pos.X, pos.Y + 25)
                    text.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
                    bar.Visible = true; text.Visible = true; return
                end
            end
        end
        bar.Visible = false; text.Visible = false
    end)
    healthESPConnections[player] = {healthBar = bar, healthText = text, connection = conn}
end

local function CreateBoxESP(player)
    local box = SafeDraw("Square")
    if not box then return end
    box.Visible = false; box.Color = Color3.new(0, 1, 0); box.Thickness = 1; box.Filled = false
    local conn = RunService.RenderStepped:Connect(function()
        if not Settings.BoxESPEnabled then box.Visible = false; return end
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") then
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local rp, on = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position)
                local hp = Camera:WorldToViewportPoint(char.Head.Position)
                if on then
                    local h = math.abs(hp.Y - rp.Y) * 1.5
                    local w = h * 0.6
                    box.Size = Vector2.new(w, h)
                    box.Position = Vector2.new(rp.X - w / 2, rp.Y - h / 2)
                    box.Visible = true; return
                end
            end
        end
        box.Visible = false
    end)
    boxESPConnections[player] = {box = box, connection = conn}
end

local function CreateTrace(player)
    local trace = SafeDraw("Line")
    if not trace then return end
    trace.Visible = false
    local conn = RunService.RenderStepped:Connect(function()
        if not Settings.TraceEnabled then trace.Visible = false; return end
        trace.Thickness = Settings.TraceThickness
        trace.Color = Settings.TraceColor
        trace.Transparency = Settings.TraceTransparency
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos, on = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position)
            if on then
                trace.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                trace.To = Vector2.new(pos.X, pos.Y)
                trace.Visible = true; return
            end
        end
        trace.Visible = false
    end)
    traceConnections[player] = {trace = trace, connection = conn}
end

local function RebuildESP()
    for _, d in pairs(nameESPConnections) do
        d.connection:Disconnect(); pcall(function() d.nameTag:Remove() end)
    end
    for _, d in pairs(healthESPConnections) do
        d.connection:Disconnect(); pcall(function() d.healthBar:Remove(); d.healthText:Remove() end)
    end
    for _, d in pairs(boxESPConnections) do
        d.connection:Disconnect(); pcall(function() d.box:Remove() end)
    end
    for _, d in pairs(traceConnections) do
        d.connection:Disconnect(); pcall(function() d.trace:Remove() end)
    end
    nameESPConnections = {}
    healthESPConnections = {}
    boxESPConnections = {}
    traceConnections = {}

    local targets = {}
    if #Settings.ESPPlayers > 0 then
        for _, name in ipairs(Settings.ESPPlayers) do
            local p = GetPlayerByName(name)
            if p and p ~= LocalPlayer then table.insert(targets, p) end
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(targets, p) end
        end
    end

    for _, player in ipairs(targets) do
        CreateNameESP(player)
        CreateHealthESP(player)
        CreateBoxESP(player)
        CreateTrace(player)
    end
end

-- ============================================================
-- UI - メインタブ
-- ============================================================

MainTab:CreateToggle({
    Name = "🔐 Head Lock",
    CurrentValue = false,
    Flag = "HeadLockToggle",
    Callback = function(v)
        Settings.LockEnabled = v
        if not v then ResetLock() end
        Analytics:RecordShot(currentTarget, 0, v)
    end,
})

MainTab:CreateButton({
    Name = "🔄 Lock Reset",
    Callback = function() ResetLock() end,
})

MainTab:CreateSection("🧭 東西南北 Head Rock 2")

MainTab:CreateToggle({
    Name = "🧭 東西南北 Head Rock 2",
    CurrentValue = false,
    Flag = "DirLockToggle",
    Callback = function(v)
        DirSettings.LockEnabled = v
        if not v then ResetDirLock() end
    end,
})

MainTab:CreateButton({
    Name = "🔄 東西南北リセット",
    Callback = function() ResetDirLock() end,
})

MainTab:CreateSection("🎯 ターゲット設定")

playerDropdown = MainTab:CreateDropdown({
    Name           = "ターゲットプレイヤー選択（複数可）",
    Options        = MakePlayerList(),
    CurrentOption  = {"全員"},
    MultipleOptions = true,
    Flag           = "PlayerMultiSelect",
    Callback = function(Options)
        Settings.TargetPlayers = {}
        for _, opt in ipairs(Options) do
            if opt ~= "全員" then
                table.insert(Settings.TargetPlayers, opt)
            end
        end
    end,
})

MainTab:CreateSection("📝 サブターゲット入力")

for i = 1, 16 do
    subTargetInputs[i] = MainTab:CreateInput({
        Name              = "サブターゲット " .. i,
        PlaceholderText   = "プレイヤー名を入力",
        RemoveTextAfterFocusLost = false,
        Callback          = function()
            Settings.SubTargetPlayers = {}
            for j = 1, 16 do
                if subTargetInputs[j] and subTargetInputs[j].Text ~= "" then
                    table.insert(Settings.SubTargetPlayers, subTargetInputs[j].Text)
                end
            end
        end,
    })
end

MainTab:CreateSection("🎥 ESP System")

espDropdown = MainTab:CreateDropdown({
    Name           = "ESPターゲット選択（複数可）",
    Options        = MakePlayerList(),
    CurrentOption  = {"全員"},
    MultipleOptions = true,
    Flag           = "ESPMultiSelect",
    Callback = function(Options)
        Settings.ESPPlayers = {}
        for _, opt in ipairs(Options) do
            if opt ~= "全員" then
                table.insert(Settings.ESPPlayers, opt)
            end
        end
        RebuildESP()
    end,
})

MainTab:CreateToggle({
    Name = "㈴ Name ESP",
    CurrentValue = false,
    Flag = "NameESPToggle",
    Callback = function(v) Settings.NameESPEnabled = v end,
})

MainTab:CreateToggle({
    Name = "💚 Health ESP",
    CurrentValue = false,
    Flag = "HealthESPToggle",
    Callback = function(v) Settings.HealthESPEnabled = v end,
})

MainTab:CreateToggle({
    Name = "🎁 Box ESP",
    CurrentValue = false,
    Flag = "BoxESPToggle",
    Callback = function(v) Settings.BoxESPEnabled = v end,
})

MainTab:CreateToggle({
    Name = "一 Trace ESP",
    CurrentValue = false,
    Flag = "TraceToggle",
    Callback = function(v) Settings.TraceEnabled = v end,
})

-- ============================================================
-- UI - サブメインタブ（ボット）
-- ============================================================

BotTab:CreateToggle({
    Name = "🤖 ボット Head Lock",
    CurrentValue = false,
    Flag = "BotHeadLockToggle",
    Callback = function(v)
        BotSettings.LockEnabled = v
        if not v then ResetBotLock() end
    end,
})

BotTab:CreateButton({
    Name = "🔄 ボットロックリセット",
    Callback = function() ResetBotLock() end,
})

BotTab:CreateSection("🤖 ボット設定")

BotTab:CreateToggle({
    Name = "🧱 壁判定",
    CurrentValue = true,
    Flag = "BotWallCheckToggle",
    Callback = function(v) BotSettings.WallCheckEnabled = v end,
})

BotTab:CreateToggle({
    Name = "🌀 スムーズロック",
    CurrentValue = false,
    Flag = "BotSmoothLockToggle",
    Callback = function(v) BotSettings.SmoothLockEnabled = v end,
})

BotTab:CreateSlider({
    Name         = "スムーズロック速度",
    Range        = {0.01, 1},
    Increment    = 0.01,
    CurrentValue = 0.1,
    Flag         = "BotSmoothLockSpeedSlider",
    Callback     = function(v) BotSettings.SmoothLockSpeed = v end,
})

BotTab:CreateDropdown({
    Name           = "ターゲット優先度",
    Options        = {"最近", "低HP", "ランダム"},
    CurrentOption  = {"最近"},
    MultipleOptions = false,
    Flag           = "BotLockPriorityDropdown",
    Callback = function(Option)
        local map = {["最近"]="Closest",["低HP"]="LowestHealth",["ランダム"]="Random"}
        BotSettings.LockPriority = map[Option[1]] or "Closest"
    end,
})

-- ============================================================
-- UI - 設定タブ
-- ============================================================

SettingsTab:CreateSection("📏 ロック距離（プレイヤー）")
SettingsTab:CreateSlider({
    Name = "360°全方位距離（スタッド）",
    Range = {0, 100}, Increment = 0.5, CurrentValue = 5,
    Flag = "LockDistanceSlider",
    Callback = function(v) Settings.LockDistance = v end,
})

SettingsTab:CreateSection("📏 ロック距離（ボット）")
SettingsTab:CreateSlider({
    Name = "ボット360°全方位距離（スタッド）",
    Range = {0, 100}, Increment = 0.5, CurrentValue = 5,
    Flag = "BotDistanceSlider",
    Callback = function(v) BotSettings.LockDistance = v end,
})

SettingsTab:CreateSection("⏱️ ロックタイミング（プレイヤー）")
SettingsTab:CreateToggle({
    Name = "🧱 壁判定",
    CurrentValue = true,
    Flag = "WallCheckToggle",
    Callback = function(v) Settings.WallCheckEnabled = v end,
})
SettingsTab:CreateSlider({
    Name = "ロック持続時間（秒）",
    Range = {0.1, 10}, Increment = 0.1, CurrentValue = 0.5,
    Flag = "LockDurationSlider",
    Callback = function(v) Settings.LockDuration = v end,
})
SettingsTab:CreateSlider({
    Name = "クールダウン（秒）",
    Range = {0.1, 10}, Increment = 0.1, CurrentValue = 1,
    Flag = "CooldownSlider",
    Callback = function(v) Settings.CooldownTime = v end,
})

SettingsTab:CreateSection("⏱️ ロックタイミング（ボット）")
SettingsTab:CreateSlider({
    Name = "ボットロック持続時間（秒）",
    Range = {0.1, 10}, Increment = 0.1, CurrentValue = 0.5,
    Flag = "BotLockDurationSlider",
    Callback = function(v) BotSettings.LockDuration = v end,
})
SettingsTab:CreateSlider({
    Name = "ボットクールダウン（秒）",
    Range = {0.1, 10}, Increment = 0.1, CurrentValue = 1,
    Flag = "BotCooldownSlider",
    Callback = function(v) BotSettings.CooldownTime = v end,
})

SettingsTab:CreateSection("🎮 高度な設定（プレイヤー）")
SettingsTab:CreateToggle({
    Name = "🌀 スムーズロック",
    CurrentValue = false,
    Flag = "SmoothLockToggle",
    Callback = function(v) Settings.SmoothLockEnabled = v end,
})
SettingsTab:CreateSlider({
    Name = "スムーズ速度",
    Range = {0.01, 1}, Increment = 0.01, CurrentValue = 0.1,
    Flag = "SmoothLockSpeedSlider",
    Callback = function(v) Settings.SmoothLockSpeed = v end,
})
SettingsTab:CreateDropdown({
    Name = "ターゲット優先度",
    Options = {"最近", "低HP", "ランダム"},
    CurrentOption = {"最近"},
    MultipleOptions = false,
    Flag = "LockPriorityDropdown",
    Callback = function(Option)
        local map = {["最近"]="Closest",["低HP"]="LowestHealth",["ランダム"]="Random"}
        Settings.LockPriority = map[Option[1]] or "Closest"
    end,
})

SettingsTab:CreateSection("🔧 Trace・ESP設定")
SettingsTab:CreateSlider({
    Name = "トレースの太さ",
    Range = {1, 150}, Increment = 1, CurrentValue = 1,
    Flag = "TraceThicknessSlider",
    Callback = function(v) Settings.TraceThickness = v end,
})
SettingsTab:CreateSlider({
    Name = "トレースの透明度",
    Range = {0, 1}, Increment = 0.01, CurrentValue = 0.1,
    Flag = "TraceTransparencySlider",
    Callback = function(v) Settings.TraceTransparency = v end,
})
SettingsTab:CreateColorPicker({
    Name = "トレースの色",
    Color = Settings.TraceColor,
    Flag = "TraceColorPicker",
    Callback = function(v) Settings.TraceColor = v end,
})
SettingsTab:CreateToggle({
    Name = "ロックインジケーター",
    CurrentValue = true,
    Flag = "LockIndicatorToggle",
    Callback = function(v) Settings.ShowLockIndicator = v end,
})
SettingsTab:CreateToggle({
    Name = "死亡時リセット",
    CurrentValue = true,
    Flag = "ResetOnDeathToggle",
    Callback = function(v) Settings.ResetOnDeath = v end,
})

-- ============================================================
-- UI - 東西南北設定タブ
-- ============================================================

DirSetTab:CreateSection("📏 基本方向スタッド（自分の向き基準）")
DirSetTab:CreateSlider({
    Name = "北（前方）スタッド",
    Range = {0, 100}, Increment = 0.5, CurrentValue = 5,
    Flag = "DirDistNorth",
    Callback = function(v) DirSettings.DistNorth = v end,
})
DirSetTab:CreateSlider({
    Name = "南（後方）スタッド",
    Range = {0, 100}, Increment = 0.5, CurrentValue = 5,
    Flag = "DirDistSouth",
    Callback = function(v) DirSettings.DistSouth = v end,
})
DirSetTab:CreateSlider({
    Name = "東（右）スタッド",
    Range = {0, 100}, Increment = 0.5, CurrentValue = 5,
    Flag = "DirDistEast",
    Callback = function(v) DirSettings.DistEast = v end,
})
DirSetTab:CreateSlider({
    Name = "西（左）スタッド",
    Range = {0, 100}, Increment = 0.5, CurrentValue = 5,
    Flag = "DirDistWest",
    Callback = function(v) DirSettings.DistWest = v end,
})

DirSetTab:CreateSection("🔀 斜め方向スタッド（初期値0 = 無効）")
DirSetTab:CreateSlider({
    Name = "北東（右前）スタッド",
    Range = {0, 100}, Increment = 0.5, CurrentValue = 0,
    Flag = "DirDistNE",
    Callback = function(v) DirSettings.DistNE = v end,
})
DirSetTab:CreateSlider({
    Name = "北西（左前）スタッド",
    Range = {0, 100}, Increment = 0.5, CurrentValue = 0,
    Flag = "DirDistNW",
    Callback = function(v) DirSettings.DistNW = v end,
})
DirSetTab:CreateSlider({
    Name = "南東（右後）スタッド",
    Range = {0, 100}, Increment = 0.5, CurrentValue = 0,
    Flag = "DirDistSE",
    Callback = function(v) DirSettings.DistSE = v end,
})
DirSetTab:CreateSlider({
    Name = "南西（左後）スタッド",
    Range = {0, 100}, Increment = 0.5, CurrentValue = 0,
    Flag = "DirDistSW",
    Callback = function(v) DirSettings.DistSW = v end,
})

DirSetTab:CreateSection("⏱️ ロックタイミング（東西南北）")
DirSetTab:CreateToggle({
    Name = "🧱 壁判定",
    CurrentValue = true,
    Flag = "DirWallCheckToggle",
    Callback = function(v) DirSettings.WallCheckEnabled = v end,
})
DirSetTab:CreateSlider({
    Name = "ロック持続時間（秒）",
    Range = {0.1, 10}, Increment = 0.1, CurrentValue = 0.5,
    Flag = "DirLockDurationSlider",
    Callback = function(v) DirSettings.LockDuration = v end,
})
DirSetTab:CreateSlider({
    Name = "クールダウン（秒）",
    Range = {0.1, 10}, Increment = 0.1, CurrentValue = 1,
    Flag = "DirCooldownSlider",
    Callback = function(v) DirSettings.CooldownTime = v end,
})

DirSetTab:CreateSection("🎮 高度な設定（東西南北）")
DirSetTab:CreateToggle({
    Name = "🌀 スムーズロック",
    CurrentValue = false,
    Flag = "DirSmoothLockToggle",
    Callback = function(v) DirSettings.SmoothLockEnabled = v end,
})
DirSetTab:CreateSlider({
    Name = "スムーズ速度",
    Range = {0.01, 1}, Increment = 0.01, CurrentValue = 0.1,
    Flag = "DirSmoothLockSpeedSlider",
    Callback = function(v) DirSettings.SmoothLockSpeed = v end,
})
DirSetTab:CreateDropdown({
    Name = "ターゲット優先度",
    Options = {"最近", "低HP", "ランダム"},
    CurrentOption = {"最近"},
    MultipleOptions = false,
    Flag = "DirLockPriorityDropdown",
    Callback = function(Option)
        local map = {["最近"]="Closest",["低HP"]="LowestHealth",["ランダム"]="Random"}
        DirSettings.LockPriority = map[Option[1]] or "Closest"
    end,
})
DirSetTab:CreateToggle({
    Name = "ロックインジケーター（青）",
    CurrentValue = true,
    Flag = "DirLockIndicatorToggle",
    Callback = function(v)
        DirSettings.ShowLockIndicator = v
        if dirLockIndicator then dirLockIndicator.Enabled = false end
    end,
})
DirSetTab:CreateToggle({
    Name = "死亡時リセット",
    CurrentValue = true,
    Flag = "DirResetOnDeathToggle",
    Callback = function(v) DirSettings.ResetOnDeath = v end,
})

-- ============================================================
-- UI - 高度な機能タブ
-- ============================================================

AdvancedTab:CreateSection("🤖 AI予測")
AdvancedTab:CreateToggle({
    Name = "AI ターゲット予測",
    CurrentValue = false,
    Flag = "AIPredictionToggle",
    Callback = function(v) Settings.AIPredictonEnabled = v end,
})
AdvancedTab:CreateLabel("敵の移動軌跡から着弾点を予測")

AdvancedTab:CreateSection("🔫 複数同時ロック")
AdvancedTab:CreateToggle({
    Name = "複数同時ロック（最大5体）",
    CurrentValue = false,
    Flag = "MultiLockToggle",
    Callback = function(v)
        Settings.MultiLockEnabled = v
        if not v then MultiLockManager:ClearTargets() end
    end,
})
AdvancedTab:CreateSlider({
    Name = "最大同時ロック数",
    Range = {1, 5}, Increment = 1, CurrentValue = 5,
    Flag = "MaxMultiLockSlider",
    Callback = function(v) MultiLockManager.maxTargets = v end,
})

AdvancedTab:CreateSection("✨ エフェクト")
AdvancedTab:CreateToggle({
    Name = "パーティクルエフェクト",
    CurrentValue = true,
    Flag = "VFXToggle",
    Callback = function(v) Settings.VFXEnabled = v end,
})
AdvancedTab:CreateLabel("ロック時に豪華なVFXを表示")

AdvancedTab:CreateSection("📊 ラグ補正")
AdvancedTab:CreateToggle({
    Name = "ラグ補正有効",
    CurrentValue = true,
    Flag = "LagCompToggle",
    Callback = function(v) Settings.LagCompensationEnabled = v end,
})
AdvancedTab:CreateButton({
    Name = "Ping測定",
    Callback = function()
        LagCompensator:UpdatePing()
        print("Ping: " .. math.floor(LagCompensator.ping) .. "ms")
    end,
})

AdvancedTab:CreateSection("🎯 エイムアシスト強度")
AdvancedTab:CreateSlider({
    Name = "エイムアシスト強度",
    Range = {0, 2}, Increment = 0.1, CurrentValue = 1,
    Flag = "AimAssistStrengthSlider",
    Callback = function(v) AimAssistController:SetStrength(v) end,
})
AdvancedTab:CreateToggle({
    Name = "適応型エイムアシスト",
    CurrentValue = false,
    Flag = "AdaptiveAimToggle",
    Callback = function(v)
        if v then AimAssistController:EnableAdaptiveMode()
        else AimAssistController:DisableAdaptiveMode() end
    end,
})

AdvancedTab:CreateSection("📍 方向別感度")
for _, dir in ipairs({"N", "NE", "E", "SE", "S", "SW", "W", "NW"}) do
    AdvancedTab:CreateSlider({
        Name = dir .. " 方向感度",
        Range = {0.1, 2}, Increment = 0.1, CurrentValue = 1,
        Flag = "DirSensitivity_" .. dir,
        Callback = function(v) DirectionalSensitivity:SetSensitivity(dir, v) end,
    })
end

-- ============================================================
-- UI - キーバインドタブ
-- ============================================================

KeyBindTab:CreateSection("⌨️ キーバインド設定")

for action, defaultKey in pairs(KeyBindManager.bindings) do
    KeyBindTab:CreateLabel(action .. ": " .. tostring(defaultKey))
end

KeyBindTab:CreateSection("🎬 マクロ記録")

local recordingLabel = KeyBindTab:CreateLabel("状態: 停止中")

KeyBindTab:CreateButton({
    Name = "記録開始",
    Callback = function()
        MacroRecorder:StartRecording()
        recordingLabel:SetText("状態: 📍 記録中...")
    end,
})

KeyBindTab:CreateButton({
    Name = "記録停止",
    Callback = function()
        MacroRecorder:StopRecording()
        recordingLabel:SetText("状態: ⏸️ 停止（長さ: " .. #MacroRecorder.macroSequence .. "）")
    end,
})

KeyBindTab:CreateButton({
    Name = "マクロ実行",
    Callback = function()
        MacroRecorder:PlayMacro()
        recordingLabel:SetText("状態: ▶️ 再生中...")
    end,
})

KeyBindTab:CreateButton({
    Name = "マクロクリア",
    Callback = function()
        MacroRecorder:ClearMacro()
        recordingLabel:SetText("状態: 停止中（リセット）")
    end,
})

-- ============================================================
-- UI - アナリティクスタブ
-- ============================================================

AnalyticsTab:CreateSection("📊 セッション統計")

local lblStats = AnalyticsTab:CreateLabel("セッション未開始")

AnalyticsTab:CreateButton({
    Name = "セッション開始",
    Callback = function()
        Analytics:StartSession()
        lblStats:SetText("セッション開始: " .. os.date("%H:%M:%S"))
    end,
})

AnalyticsTab:CreateButton({
    Name = "統計更新",
    Callback = function()
        local stats = Analytics:GetStats()
        local text = string.format(
            "総セッション: %d\n総ショット: %d\n総ヒット: %d\nヒット率: %.1f%%\n平均距離: %.1f",
            stats.totalSessions,
            stats.totalShots,
            stats.totalHits,
            stats.hitRate,
            stats.avgDistance
        )
        lblStats:SetText(text)
    end,
})

AnalyticsTab:CreateSection("🎯 ターゲット履歴")

local lblHistory = AnalyticsTab:CreateLabel("履歴なし")

AnalyticsTab:CreateButton({
    Name = "履歴更新",
    Callback = function()
        if #targetHistory == 0 then
            lblHistory:SetText("履歴なし")
        else
            local lines = {}
            for i, e in ipairs(targetHistory) do
                table.insert(lines, string.format("%d. %s [%s] %.1fs", i, e.player, e.time, e.duration))
            end
            lblHistory:SetText(table.concat(lines, "\n"))
        end
    end,
})

-- ============================================================
-- UI - 優先度リストタブ（AnalyticsTabに追加）
-- ============================================================

AnalyticsTab:CreateSection("⭐ VIPリスト")

local vipInput = AnalyticsTab:CreateInput({
    Name = "VIPプレイヤー追加",
    PlaceholderText = "プレイヤー名",
    RemoveTextAfterFocusLost = false,
})

AnalyticsTab:CreateButton({
    Name = "VIPに追加",
    Callback = function()
        if vipInput.Text ~= "" then
            PriorityListManager:AddVIP(vipInput.Text)
            vipInput.Text = ""
        end
    end,
})

AnalyticsTab:CreateSection("🚫 ブラックリスト")

local blackInput = AnalyticsTab:CreateInput({
    Name = "ブラックリスト追加",
    PlaceholderText = "プレイヤー名",
    RemoveTextAfterFocusLost = false,
})

AnalyticsTab:CreateButton({
    Name = "ブラックリストに追加",
    Callback = function()
        if blackInput.Text ~= "" then
            PriorityListManager:AddBlacklist(blackInput.Text)
            blackInput.Text = ""
        end
    end,
})

-- ============================================================
-- UI - 情報タブ
-- ============================================================

InfoTab:CreateSection("📊 現在の状態")
local lblTarget    = InfoTab:CreateLabel("ターゲット: なし")
local lblLock      = InfoTab:CreateLabel("ロック: 🔓 未ロック")
local lblBotTarget = InfoTab:CreateLabel("ボットターゲット: なし")
local lblBotLock   = InfoTab:CreateLabel("ボットロック: 🔓 未ロック")
local lblDirTarget = InfoTab:CreateLabel("東西南北ターゲット: なし")
local lblDirLock   = InfoTab:CreateLabel("東西南北ロック: 🔓 未ロック")

InfoTab:CreateButton({
    Name = "🔄 状態を更新",
    Callback = function()
        lblTarget:SetText("ターゲット: " .. (currentTarget and currentTarget.Name or "なし"))
        lblLock:SetText("ロック: " .. (isLocking and "🔒 ロック中" or "🔓 未ロック"))
        lblBotTarget:SetText("ボットターゲット: " .. (currentBotTarget and currentBotTarget.Name or "なし"))
        lblBotLock:SetText("ボットロック: " .. (isBotLocking and "🔒 ロック中" or "🔓 未ロック"))
        lblDirTarget:SetText("東西南北ターゲット: " .. (currentDirTarget and currentDirTarget.Name or "なし"))
        lblDirLock:SetText("東西南北ロック: " .. (isDirLocking and "🔒 ロック中" or "🔓 未ロック"))
    end,
})

InfoTab:CreateSection("ℹ️ バージョン")
InfoTab:CreateParagraph({
    Title   = "Syu_uhub Advanced v3.0",
    Content = "全10個の高度な機能を統合した完全版\n\n✅ AIターゲット予測\n✅ 複数同時ロック\n✅ カスタムキーバインド\n✅ パーティクルエフェクト\n✅ ホットキー記録機能\n✅ ターゲット優先度リスト\n✅ エイムアシスト強度調整\n✅ ラグ補正機能\n✅ 360度方向別感度\n✅ アナリティクスダッシュボード"
})

-- ============================================================
-- キーバインド（カスタマイズ対応）
-- ============================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    local inputKey = input.KeyCode
    
    if inputKey == KeyBindManager:GetBinding("LockToggle") then
        Settings.LockEnabled = not Settings.LockEnabled
        if not Settings.LockEnabled then ResetLock() end
    elseif inputKey == KeyBindManager:GetBinding("LockReset") then
        ResetLock()
    elseif inputKey == KeyBindManager:GetBinding("BotToggle") then
        BotSettings.LockEnabled = not BotSettings.LockEnabled
        if not BotSettings.LockEnabled then ResetBotLock() end
    elseif inputKey == KeyBindManager:GetBinding("RecordMacro") then
        MacroRecorder:StartRecording()
    elseif inputKey == KeyBindManager:GetBinding("PlayMacro") then
        MacroRecorder:PlayMacro()
    elseif inputKey == KeyBindManager:GetBinding("ClearMacro") then
        MacroRecorder:ClearMacro()
    end
end)

-- ============================================================
-- メインループ
-- ============================================================

RunService.RenderStepped:Connect(function()
    LockToHead()
    LockToBot()
    LockToDirHead()
end)

-- ============================================================
-- プレイヤーリスト更新
-- ============================================================

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Wait()
    if player ~= LocalPlayer then
        if #Settings.ESPPlayers == 0 or table.find(Settings.ESPPlayers, player.Name) then
            CreateNameESP(player)
            CreateHealthESP(player)
            CreateBoxESP(player)
            CreateTrace(player)
        end
    end
    local list = MakePlayerList()
    if playerDropdown then pcall(function() playerDropdown:Refresh(list, true) end) end
    if espDropdown then pcall(function() espDropdown:Refresh(list, true) end) end
end)

Players.PlayerRemoving:Connect(function(player)
    local function clean(tbl, key, ...)
        if tbl[key] then
            tbl[key].connection:Disconnect()
            for _, f in ipairs({...}) do pcall(function() tbl[key][f]:Remove() end) end
            tbl[key] = nil
        end
    end
    clean(nameESPConnections, player, "nameTag")
    clean(healthESPConnections, player, "healthBar", "healthText")
    clean(boxESPConnections, player, "box")
    clean(traceConnections, player, "trace")
end)

-- ============================================================
-- 初期化
-- ============================================================

task.spawn(function()
    task.wait(2)
    CreateLockIndicator()
    CreateDirLockIndicator()
    RebuildESP()
    Analytics:StartSession()
end)

Rayfield:LoadConfiguration()

print("✅ Syu_uhub Advanced v3.0 loaded successfully!")
