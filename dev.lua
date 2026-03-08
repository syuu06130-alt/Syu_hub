-- ============================================================
-- Syu_uhub 完全版 v2.0
-- 修正・追加内容:
-- [メインタブ]
--  1. Head Lock プレイヤー・ボット両対応
--  2. ターゲット選択を複数選択対応、"なし"→"全員"に変更
--  3. ドロップダウンのスクロール問題を回避（Refresh管理改善）
--  4. ESP System（Name/Health/Box/Trace）完全動作化
--  5. 複数選択タブ廃止 → サブターゲット入力16個をメインタブに配置
--  6. 複数ESP選択タブ廃止 → ESPターゲット選択ドロップダウンをメインタブに配置
--
-- [サブメインタブ]
--  7. ボット Head Lock 完全実装（壁判定・スムーズロック・優先度 全動作）
--
-- [設定タブ]
--  8. 360°全方位距離スライダー: Increment 0.5 に変更
--  9. スムーズロック: ON/OFFトグル追加（プレイヤー・ボット両方）
-- 10. 各スライダーの値が反映されない問題を修正（設定参照の一元化）
--
-- [新機能]
-- 11. 東西南北 Head Rock 2 をメインタブ Head Lock 直下に配置
-- 12. 東西南北設定タブ: N/S/E/W 個別スタッド + 斜め NE/NW/SE/SW（初期0）
-- 13. リアルタイムで自分の向きを基準に8方向判定してロック
-- ============================================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- サービス
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ============================================================
-- 設定値
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
    TargetPlayers      = {},   -- ドロップダウン複数選択（空 = 全員）
    SubTargetPlayers   = {},   -- サブターゲット入力（名前文字列）
    -- ESP
    ESPPlayers         = {},   -- ESPドロップダウン（空 = 全員）
    NameESPEnabled     = false,
    HealthESPEnabled   = false,
    BoxESPEnabled      = false,
    TraceEnabled       = false,
    TraceThickness     = 1,
    TraceColor         = Color3.fromRGB(255, 50, 50),
    TraceTransparency  = 0.1,
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

-- 東西南北設定
local DirSettings = {
    LockEnabled       = false,
    -- 基本4方向（プレイヤーの向き基準: 前=北, 後=南, 右=東, 左=西）
    DistNorth         = 5,
    DistSouth         = 5,
    DistEast          = 5,
    DistWest          = 5,
    -- 斜め4方向（初期値0 = 無効）
    DistNE            = 0,
    DistNW            = 0,
    DistSE            = 0,
    DistSW            = 0,
    -- 共通設定
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

-- ESP接続管理
local nameESPConnections   = {}
local healthESPConnections = {}
local boxESPConnections    = {}
local traceConnections     = {}

-- [重要] サブターゲット入力フィールドを関数定義より先に宣言
local subTargetInputs = {}

-- ============================================================
-- ウィンドウ・タブ定義
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name             = "Syu_uhub",
    LoadingTitle     = "Syu_uhub Loading...",
    LoadingSubtitle  = "by Syu - Advanced Head Lock System v2",
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "SyuHub",
        FileName   = "SyuHubConfig"
    },
    Discord = {
        Enabled       = false,
        Invite        = "noinvitelink",
        RememberJoins = true
    }
})

local MainTab       = Window:CreateTab("メイン",              4483362458)
local BotTab        = Window:CreateTab("サブメイン（ボット）", 4483362458)
local SettingsTab   = Window:CreateTab("設定",                4483345998)
local DirSetTab     = Window:CreateTab("東西南北設定",        4483345998)
local InfoTab       = Window:CreateTab("情報",                4483345998)

-- ============================================================
-- ユーティリティ
-- ============================================================

-- プレイヤー名からインスタンスを安全に取得（FindFirstChild誤作動防止）
local function GetPlayerByName(name)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name then return p end
    end
    return nil
end

-- ドロップダウン用プレイヤーリスト
local function MakePlayerList()
    local list = {"全員"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(list, p.Name) end
    end
    return list
end

-- ============================================================
-- ロックインジケーター
-- ============================================================
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
    f.BackgroundColor3           = Color3.fromRGB(50, 120, 255) -- 青で区別
    f.BackgroundTransparency     = 0.7
    f.BorderSizePixel            = 0
    local c = Instance.new("UICorner", f); c.CornerRadius = UDim.new(0, 8)
    dirLockIndicator.Parent      = LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================================
-- 壁判定（プレイヤー・ボット共通）
-- ============================================================
local function HasWallBetween(startPos, endPos, excludeChar)
    local dir    = (endPos - startPos).Unit
    local dist   = (endPos - startPos).Magnitude
    local params = RaycastParams.new()
    params.FilterType                 = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = excludeChar and {excludeChar} or {}
    params.IgnoreWater                = true
    local result = workspace:Raycast(startPos, dir * dist, params)
    if result then
        -- ヒットしたものがプレイヤー/ボットなら壁ではない
        local hit = result.Instance
        while hit and hit ~= workspace do
            local hp = Players:GetPlayerFromCharacter(hit)
            if hp and hp ~= LocalPlayer then return false end
            if hit:IsA("Model") and hit:FindFirstChild("Humanoid") then return false end
            hit = hit.Parent
        end
        return true -- 壁にヒット
    end
    return false
end

-- ============================================================
-- 優先度計算
-- ============================================================
local function CalcPriority(subject, distance, priorityMode)
    if priorityMode == "LowestHealth" then
        local hum
        if typeof(subject) == "Instance" and subject:IsA("Model") then
            hum = subject:FindFirstChild("Humanoid")
                or (subject.Character and subject.Character:FindFirstChild("Humanoid"))
        end
        if hum and hum.MaxHealth > 0 then
            return -(hum.Health / hum.MaxHealth) -- HP低いほど高優先
        end
        return 0
    elseif priorityMode == "Random" then
        return math.random()
    else -- Closest
        return -distance
    end
end

-- ============================================================
-- 方向セクター判定（東西南北 Head Rock 2 専用）
-- プレイヤーの HumanoidRootPart.CFrame を基準に8方向を判定
-- ============================================================
local function GetSector(localCFrame, enemyWorldPos)
    -- プレイヤーローカル空間に変換
    -- Roblox: LookVector = 前方 = ローカル(0,0,-1)
    -- PointToObjectSpace後: Z- = 北(前), Z+ = 南(後), X+ = 東(右), X- = 西(左)
    local rel   = localCFrame:PointToObjectSpace(enemyWorldPos)
    local angle = math.deg(math.atan2(rel.X, -rel.Z)) -- 北=0°, 東=90°, 南=180°, 西=-90°
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

local function GetDirMaxDist(sector)
    return ({
        N  = DirSettings.DistNorth,
        S  = DirSettings.DistSouth,
        E  = DirSettings.DistEast,
        W  = DirSettings.DistWest,
        NE = DirSettings.DistNE,
        NW = DirSettings.DistNW,
        SE = DirSettings.DistSE,
        SW = DirSettings.DistSW,
    })[sector] or 0
end

-- ============================================================
-- ターゲット候補リスト構築（プレイヤー・東西南北共通）
-- ============================================================
local function BuildPlayerCandidates()
    local candidates = {}
    local hasSpecific = (#Settings.TargetPlayers > 0)

    if hasSpecific then
        for _, name in ipairs(Settings.TargetPlayers) do
            local p = GetPlayerByName(name)
            if p then table.insert(candidates, p) end
        end
    end
    -- サブターゲット入力から追加（重複チェック付き）
    for _, name in ipairs(Settings.SubTargetPlayers) do
        if name ~= "" then
            local p = GetPlayerByName(name)
            if p then
                local already = false
                for _, c in ipairs(candidates) do
                    if c == p then already = true; break end
                end
                if not already then table.insert(candidates, p) end
            end
        end
    end
    -- 候補が空なら全プレイヤー
    if #candidates == 0 then
        for _, p in ipairs(Players:GetPlayers()) do
            table.insert(candidates, p)
        end
    end
    return candidates
end

-- ============================================================
-- ターゲット取得（通常 Head Lock）
-- ============================================================
local function GetBestEnemy()
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then return nil end
    local localPos  = LocalPlayer.Character.HumanoidRootPart.Position
    local localChar = LocalPlayer.Character
    local best, bestPri = nil, -math.huge

    for _, player in ipairs(BuildPlayerCandidates()) do
        if player ~= LocalPlayer
            and player.Character
            and player.Character:FindFirstChild("HumanoidRootPart")
            and player.Character:FindFirstChild("Head") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
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
        end
    end
    return best
end

-- ============================================================
-- ターゲット取得（ボット）
-- GetDescendants でフォルダ内ボットも検出
-- ============================================================
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
            -- プレイヤーキャラクターを除外
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

-- ============================================================
-- ターゲット取得（東西南北 Head Rock 2）
-- リアルタイムの自分の向きを基準に方向判定
-- ============================================================
local function GetBestDirEnemy()
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then return nil end
    local rootPart  = LocalPlayer.Character.HumanoidRootPart
    local localPos  = rootPart.Position
    local localCF   = rootPart.CFrame  -- リアルタイム向き
    local localChar = LocalPlayer.Character
    local best, bestPri = nil, -math.huge

    for _, player in ipairs(BuildPlayerCandidates()) do
        if player ~= LocalPlayer
            and player.Character
            and player.Character:FindFirstChild("HumanoidRootPart")
            and player.Character:FindFirstChild("Head") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local enemyPos = player.Character.HumanoidRootPart.Position
                local sector   = GetSector(localCF, enemyPos)
                local maxDist  = GetDirMaxDist(sector)

                if maxDist > 0 then
                    local dist = (localPos - enemyPos).Magnitude
                    if dist <= maxDist then
                        local wallBlocked = DirSettings.WallCheckEnabled
                            and HasWallBetween(localPos, player.Character.Head.Position, localChar)
                        if not wallBlocked then
                            local pri = CalcPriority(player, dist, DirSettings.LockPriority)
                            if pri > bestPri then bestPri = pri; best = player end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- ============================================================
-- カメラ向き設定（スムーズ / 即時）
-- ============================================================
local function AimAt(targetPos, smooth, speed)
    if smooth then
        local goal = CFrame.new(Camera.CFrame.Position, targetPos)
        Camera.CFrame = Camera.CFrame:Lerp(goal, math.clamp(speed, 0.01, 1))
    else
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
    end
end

-- ============================================================
-- リセット関数
-- ============================================================
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

local function ResetLogs()
    targetHistory = {}
end

-- ============================================================
-- Head Lock 本体（プレイヤー用）
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

    -- インジケーター
    if Settings.ShowLockIndicator and lockIndicator then
        local head = enemy.Character and enemy.Character:FindFirstChild("Head")
        if head then lockIndicator.Adornee = head; lockIndicator.Enabled = true end
    end

    isLocking     = true
    currentTarget = enemy
    lastLockTime  = t
    lockStartTime = t
    local recordStart = t

    if lockConnection then lockConnection:Disconnect() end
    lockConnection = RunService.RenderStepped:Connect(function()
        -- ロック無効化 / ターゲット消失チェック
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
            local elapsed = math.floor((tick() - recordStart) * 10) / 10
            table.insert(targetHistory, 1, {
                player   = currentTarget.Name,
                time     = os.date("%H:%M:%S"),
                duration = elapsed
            })
            if #targetHistory > 10 then table.remove(targetHistory, 11) end
            ResetLock(); return
        end

        local head = currentTarget.Character:FindFirstChild("Head")
        if not head then ResetLock(); return end
        AimAt(head.Position, Settings.SmoothLockEnabled, Settings.SmoothLockSpeed)
    end)
end

-- ============================================================
-- Head Lock 本体（ボット用）
-- ============================================================
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

-- ============================================================
-- 東西南北 Head Rock 2 本体
-- ============================================================
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
        local localCF   = rootPart.CFrame  -- リアルタイム向き更新
        local enemyPos  = currentDirTarget.Character.HumanoidRootPart.Position
        local sector    = GetSector(localCF, enemyPos)
        local maxDist   = GetDirMaxDist(sector)
        local dist      = (localPos - enemyPos).Magnitude

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
-- ESP（Drawing API を pcall で安全化）
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
                    tag.Visible  = true
                    return
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
                    local pct   = hum.Health / hum.MaxHealth
                    local L     = 50
                    bar.From    = Vector2.new(pos.X - L / 2, pos.Y + 20)
                    bar.To      = Vector2.new(pos.X - L / 2 + L * pct, pos.Y + 20)
                    bar.Color   = pct > 0.5 and Color3.new(0,1,0)
                                    or (pct > 0.25 and Color3.new(1,1,0) or Color3.new(1,0,0))
                    text.Position = Vector2.new(pos.X, pos.Y + 25)
                    text.Text     = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
                    bar.Visible   = true; text.Visible = true
                    return
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
                local hp     = Camera:WorldToViewportPoint(char.Head.Position)
                if on then
                    local h = math.abs(hp.Y - rp.Y) * 1.5
                    local w = h * 0.6
                    box.Size     = Vector2.new(w, h)
                    box.Position = Vector2.new(rp.X - w / 2, rp.Y - h / 2)
                    box.Visible  = true
                    return
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
        -- 毎フレーム設定を反映
        trace.Thickness    = Settings.TraceThickness
        trace.Color        = Settings.TraceColor
        trace.Transparency = Settings.TraceTransparency
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos, on = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position)
            if on then
                trace.From    = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                trace.To      = Vector2.new(pos.X, pos.Y)
                trace.Visible = true
                return
            end
        end
        trace.Visible = false
    end)
    traceConnections[player] = {trace = trace, connection = conn}
end

-- ESP全再構築（接続を全て切断してから対象プレイヤーに再接続）
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
    nameESPConnections   = {}
    healthESPConnections = {}
    boxESPConnections    = {}
    traceConnections     = {}

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
-- サブターゲット入力更新
-- ============================================================
local function UpdateSubTargets()
    Settings.SubTargetPlayers = {}
    for i = 1, 16 do
        local inp = subTargetInputs[i]
        if inp and inp.Text and inp.Text ~= "" then
            table.insert(Settings.SubTargetPlayers, inp.Text)
        end
    end
end

-- ============================================================
-- プレイヤー参加/退出
-- CharacterAdded:Wait() でキャラクターロードを保証
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
    if espDropdown    then pcall(function() espDropdown:Refresh(list, true)    end) end
end)

Players.PlayerRemoving:Connect(function(player)
    local function clean(tbl, key, ...)
        if tbl[key] then
            tbl[key].connection:Disconnect()
            for _, f in ipairs({...}) do pcall(function() tbl[key][f]:Remove() end) end
            tbl[key] = nil
        end
    end
    clean(nameESPConnections,   player, "nameTag")
    clean(healthESPConnections, player, "healthBar", "healthText")
    clean(boxESPConnections,    player, "box")
    clean(traceConnections,     player, "trace")
    local list = MakePlayerList()
    if playerDropdown then pcall(function() playerDropdown:Refresh(list, true) end) end
    if espDropdown    then pcall(function() espDropdown:Refresh(list, true)    end) end
end)

-- ============================================================
-- UI - メインタブ
-- ============================================================

-- Head Lock
MainTab:CreateToggle({
    Name = "🔐 Head Lock",
    CurrentValue = false,
    Flag = "HeadLockToggle",
    Callback = function(v)
        Settings.LockEnabled = v
        if not v then ResetLock() end
    end,
})

MainTab:CreateButton({
    Name = "🔄 Lock Reset",
    Callback = function() ResetLock() end,
})

-- 東西南北 Head Rock 2（Head Lock の直下）
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

-- ターゲット設定
MainTab:CreateSection("🎯 ターゲット設定")

-- 複数選択対応ドロップダウン（"全員" = 全プレイヤー対象）
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

-- サブターゲット入力（16個、ターゲット選択の直下）
MainTab:CreateSection("📝 サブターゲット入力")

for i = 1, 16 do
    subTargetInputs[i] = MainTab:CreateInput({
        Name              = "サブターゲット " .. i,
        PlaceholderText   = "プレイヤー名を入力",
        RemoveTextAfterFocusLost = false,
        Callback          = function() UpdateSubTargets() end,
    })
end

-- ESP System
MainTab:CreateSection("🎥 ESP System")

-- ESPターゲット選択ドロップダウン（複数選択）
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
-- UI - 情報タブ（簡潔版）
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

InfoTab:CreateSection("📈 ターゲット履歴（最大10件）")
local lblHistory = InfoTab:CreateLabel("履歴なし")

InfoTab:CreateButton({
    Name = "履歴を更新",
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

InfoTab:CreateButton({
    Name = "🗑️ 履歴リセット",
    Callback = function() ResetLogs(); lblHistory:SetText("履歴なし") end,
})

InfoTab:CreateSection("ℹ️ 操作ガイド")
InfoTab:CreateParagraph({
    Title   = "基本操作",
    Content = "・Head Lock: メインタブでON/OFF\n・東西南北 Head Rock 2: Head Lock直下でON/OFF\n・ターゲット: ドロップダウンで複数選択（全員=全プレイヤー対象）\n・サブターゲット: テキスト入力で最大16名追加指定\n・キーバインド: RightCtrl=Lock切替 / RightShift=リセット / Insert=ボット切替"
})
InfoTab:CreateParagraph({
    Title   = "東西南北 Head Rock 2",
    Content = "・自分のキャラクターの向きを基準にリアルタイムで東西南北を判定\n・東西南北設定タブで方向ごとのスタッド距離を個別設定\n・斜め方向(NE/NW/SE/SW)は初期値0（0=その方向は無効）\n・方向ごとに異なる距離でロック範囲を細かく調整可能"
})
InfoTab:CreateParagraph({
    Title   = "ESP",
    Content = "・ESPターゲット選択で表示対象を絞り込み（全員=全プレイヤー）\n・Name/Health/Box/TraceをONにするだけで即表示\n・設定タブでTrace色・太さ・透明度を変更"
})

-- ============================================================
-- キーバインド
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        Settings.LockEnabled = not Settings.LockEnabled
        if not Settings.LockEnabled then ResetLock() end
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        ResetLock()
    elseif input.KeyCode == Enum.KeyCode.Insert then
        BotSettings.LockEnabled = not BotSettings.LockEnabled
        if not BotSettings.LockEnabled then ResetBotLock() end
    end
end)

-- ============================================================
-- メインループ（RenderStepped 1本に統合）
-- ============================================================
RunService.RenderStepped:Connect(function()
    LockToHead()
    LockToBot()
    LockToDirHead()
end)

-- ============================================================
-- プレイヤーリスト自動更新ループ（キャンセル機構付き）
-- ============================================================
task.spawn(function()
    while playerListLoopActive and task.wait(3) do
        local list = MakePlayerList()
        if playerDropdown then pcall(function() playerDropdown:Refresh(list, true) end) end
        if espDropdown    then pcall(function() espDropdown:Refresh(list, true)    end) end
    end
end)

-- ============================================================
-- 初期化
-- ============================================================
task.spawn(function()
    task.wait(2)
    CreateLockIndicator()
    CreateDirLockIndicator()
    RebuildESP()
end)

Rayfield:LoadConfiguration()

-- ============================================================
-- クリーンアップ（ゲーム終了 / UI手動終了 両対応）
-- ============================================================
local function Cleanup()
    playerListLoopActive = false
    ResetLock(); ResetBotLock(); ResetDirLock()
    for _, d in pairs(nameESPConnections)   do d.connection:Disconnect(); pcall(function() d.nameTag:Remove() end) end
    for _, d in pairs(healthESPConnections) do d.connection:Disconnect(); pcall(function() d.healthBar:Remove(); d.healthText:Remove() end) end
    for _, d in pairs(boxESPConnections)    do d.connection:Disconnect(); pcall(function() d.box:Remove() end) end
    for _, d in pairs(traceConnections)     do d.connection:Disconnect(); pcall(function() d.trace:Remove() end) end
    if lockIndicator    then pcall(function() lockIndicator:Destroy()    end) end
    if dirLockIndicator then pcall(function() dirLockIndicator:Destroy() end) end
end

game:BindToClose(Cleanup)
game:GetService("CoreGui").ChildRemoved:Connect(function(child)
    if child.Name == "Rayfield" then Cleanup() end
end)
