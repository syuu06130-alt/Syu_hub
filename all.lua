-- ============================================================
-- Syu_uhub 完全修正版
-- 修正一覧（計13項目）:
--
-- [致命的バグ]
-- 1. multiTargetInputs/multiESPInputs のスコープ問題 → 先頭で宣言
-- 2. 毎フレームTween生成によるメモリリーク → Lerpに変更＋tween参照管理
-- 3. カメラ直接操作前にCameraTypeをScriptableに設定していない
-- 4. lockConnection/botLockConnection の二重接続漏れ（再割り当て前にDisconnectなし）
--
-- [ロジックバグ]
-- 5. GetBestBot() がworkspace直下しか検索しない（フォルダ内ボット未検出）
-- 6. PlayerAdded内のtask.wait(2)が不確実 → CharacterAdded:Wait()に変更
-- 7. targetHistoryにSettings.LockDuration（設定値）を記録 → 実経過時間を記録
-- 8. Players:FindFirstChild(SelectedPlayer) はPlayerインスタンス以外も返す可能性
--
-- [パフォーマンス・リソース]
-- 9. RenderSteppedの二重登録 → 1つに統合
-- 10. プレイヤーリスト更新の無限ループにキャンセル機構がない
-- 11. ゲーム終了時クリーンアップがCorGui.ChildRemovedに依存（不確実）
--      → game:BindToClose()を追加
--
-- [安全性]
-- 12. Drawing API操作にpcallがない（エグゼキューター非対応時クラッシュ）
-- 13. lockIndicator.AdorneeにHead消滅タイミングでnilが入る可能性 → nil安全化
-- ============================================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- サービス取得
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
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
    TraceEnabled       = false,
    TraceThickness     = 1,
    TraceColor         = Color3.fromRGB(255, 50, 50),
    TraceTransparency  = 0.1,
    NameESPEnabled     = false,
    HealthESPEnabled   = false,
    BoxESPEnabled      = false,
    TargetPlayer       = nil,
    TargetPlayerID     = nil,
    TargetPlayers      = {},
    ESPPlayers         = {},
    WallCheckEnabled   = true,
    WallCheckDelay     = 0,
    SmoothLockEnabled  = false,
    SmoothLockSpeed    = 0.1,
    ShowLockIndicator  = true,
    ResetOnDeath       = true,
    LockPriority       = "Closest"
}

local BotSettings = {
    LockEnabled       = false,
    LockDistance      = 5,
    LockDuration      = 0.5,
    CooldownTime      = 1,
    WallCheckEnabled  = true,
    WallCheckDelay    = 0,
    SmoothLockEnabled = false,
    SmoothLockSpeed   = 0.1,
    LockPriority      = "Closest"
}

-- ============================================================
-- 状態管理
-- ============================================================
local isLocking          = false
local isBotLocking       = false
local lastLockTime       = 0
local botLastLockTime    = 0
local lockConnection     = nil
local botLockConnection  = nil
local traceConnections   = {}
local nameESPConnections = {}
local healthESPConnections = {}
local boxESPConnections  = {}
local currentTarget      = nil
local currentBotTarget   = nil
local playerDropdown     = nil
local wallCheckStartTime = 0
local botWallCheckStartTime = 0
local lockStartTime      = 0
local botLockStartTime   = 0
local targetHistory      = {}
local lockIndicator      = nil
local SelectedPlayer     = nil

-- [修正10] プレイヤーリスト更新ループのキャンセルフラグ
local playerListLoopActive = true

-- [修正2] スムーズロック用のTween参照（再生前にキャンセルするため）
local activeSmoothTween    = nil
local activeBotSmoothTween = nil

-- ============================================================
-- [修正1] multiTargetInputs / multiESPInputs を関数より先に宣言
-- ============================================================
local multiTargetInputs = {}
local multiESPInputs    = {}

-- ============================================================
-- Rayfield ウィンドウ作成
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name          = "Syu_uhub",
    LoadingTitle  = "Syu_uhub Loading...",
    LoadingSubtitle = "by Syu - Advanced Head Lock System",
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "SyuHub",
        FileName   = "SyuHubConfig"
    },
    Discord = {
        Enabled      = false,
        Invite       = "noinvitelink",
        RememberJoins = true
    }
})

local MainTab         = Window:CreateTab("メイン",                4483362458)
local BotTab          = Window:CreateTab("サブメイン（ボット）",   4483362458)
local SettingsTab     = Window:CreateTab("設定",                  4483345998)
local MultiSelectTab  = Window:CreateTab("複数選択",              4483345998)
local MultiESPSelectTab = Window:CreateTab("複数選択ESP項目",     4483345998)
local InfoTab         = Window:CreateTab("情報",                  4483345998)

-- ============================================================
-- ユーティリティ
-- ============================================================

-- [修正8] プレイヤー名からPlayerインスタンスを安全に取得
local function GetPlayerByName(name)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name then return p end
    end
    return nil
end

-- プレイヤーIDからPlayerインスタンスを取得
local function GetPlayerByID(userId)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.UserId == userId then return p end
    end
    return nil
end

-- プレイヤーリスト取得
local function UpdatePlayerList()
    local list = {"なし", "リセット", "最寄りのプレイヤー"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, p.Name)
        end
    end
    return list
end

-- ============================================================
-- ロックインジケーター
-- ============================================================
local function CreateLockIndicator()
    if lockIndicator then
        pcall(function() lockIndicator:Destroy() end)
    end
    lockIndicator = Instance.new("BillboardGui")
    lockIndicator.Name          = "LockIndicator"
    lockIndicator.AlwaysOnTop   = true
    lockIndicator.Size          = UDim2.new(4, 0, 4, 0)
    lockIndicator.StudsOffset   = Vector3.new(0, 3, 0)
    lockIndicator.Enabled       = false

    local frame = Instance.new("Frame")
    frame.Size                  = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3      = Color3.fromRGB(255, 50, 50)
    frame.BackgroundTransparency = 0.7
    frame.BorderSizePixel       = 0
    frame.Parent                = lockIndicator

    local corner = Instance.new("UICorner")
    corner.CornerRadius         = UDim.new(0, 8)
    corner.Parent               = frame

    lockIndicator.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================================
-- 選択ラベル
-- ============================================================
local selectedLabel = nil
local function UpdateSelectedLabel()
    if selectedLabel then
        selectedLabel:SetText(SelectedPlayer and ("選択中: " .. SelectedPlayer) or "選択中: なし")
    end
end

-- 最寄りのプレイヤーを検索
local function FindNearestPlayer()
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then return end
    local nearestPlayer, shortestDistance = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local d = (LocalPlayer.Character.HumanoidRootPart.Position - p.Character.HumanoidRootPart.Position).Magnitude
            if d < shortestDistance then
                shortestDistance = d
                nearestPlayer = p
            end
        end
    end
    if nearestPlayer then
        SelectedPlayer = nearestPlayer.Name
        if playerDropdown then playerDropdown:Set(nearestPlayer.Name) end
        UpdateSelectedLabel()
    end
end

-- ============================================================
-- 壁判定
-- ============================================================
local function CheckWallBetween(startPos, endPos)
    if not Settings.WallCheckEnabled then return false end
    local direction = (endPos - startPos).Unit
    local distance  = (endPos - startPos).Magnitude
    local params    = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.IgnoreWater = true
    local result = workspace:Raycast(startPos, direction * distance, params)
    if result then
        local hit = result.Instance
        while hit and hit ~= workspace do
            local hitPlayer = Players:GetPlayerFromCharacter(hit)
            if hitPlayer and hitPlayer ~= LocalPlayer then return false end
            hit = hit.Parent
        end
        return true
    end
    return false
end

local function CheckWallBetweenBot(startPos, endPos)
    if not BotSettings.WallCheckEnabled then return false end
    local direction = (endPos - startPos).Unit
    local distance  = (endPos - startPos).Magnitude
    local params    = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.IgnoreWater = true
    local result = workspace:Raycast(startPos, direction * distance, params)
    if result then
        local hit = result.Instance
        while hit and hit ~= workspace do
            if hit:IsA("Model") and hit:FindFirstChild("Humanoid") then return false end
            hit = hit.Parent
        end
        return true
    end
    return false
end

-- ============================================================
-- 距離チェック
-- ============================================================
local function IsWithinDistance(localPos, enemyPos)
    return (enemyPos - localPos).Magnitude <= Settings.LockDistance
end

local function IsWithinBotDistance(localPos, enemyPos)
    return (enemyPos - localPos).Magnitude <= BotSettings.LockDistance
end

-- ============================================================
-- HP取得
-- ============================================================
local function GetPlayerHealth(player)
    if player.Character then
        local h = player.Character:FindFirstChild("Humanoid")
        if h then return h.Health, h.MaxHealth end
    end
    return 0, 100
end

local function GetBotHealth(model)
    if model then
        local h = model:FindFirstChild("Humanoid")
        if h then return h.Health, h.MaxHealth end
    end
    return 0, 100
end

-- ============================================================
-- ターゲット優先度
-- ============================================================
local function CalculateTargetPriority(player, distance)
    if Settings.LockPriority == "LowestHealth" then
        local hp, maxHp = GetPlayerHealth(player)
        return -(hp / maxHp)   -- 低いほど高優先度
    elseif Settings.LockPriority == "Random" then
        return math.random()
    else
        return -(distance)     -- 近いほど高優先度
    end
end

local function CalculateBotPriority(model, distance)
    if BotSettings.LockPriority == "LowestHealth" then
        local hp, maxHp = GetBotHealth(model)
        return -(hp / maxHp)
    elseif BotSettings.LockPriority == "Random" then
        return math.random()
    else
        return -(distance)
    end
end

-- ============================================================
-- ターゲット検索（プレイヤー用）
-- ============================================================
local function GetBestEnemy()
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then
        return nil, math.huge, false
    end
    local localPos = LocalPlayer.Character.HumanoidRootPart.Position

    -- PlayerIDで指定
    if Settings.TargetPlayerID and Settings.TargetPlayerID ~= 0 then
        local tp = GetPlayerByID(Settings.TargetPlayerID)
        if tp and tp.Character and tp.Character:FindFirstChild("HumanoidRootPart") and tp.Character:FindFirstChild("Head") then
            local hum = tp.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (localPos - tp.Character.HumanoidRootPart.Position).Magnitude
                if IsWithinDistance(localPos, tp.Character.HumanoidRootPart.Position) then
                    local wall = CheckWallBetween(localPos, tp.Character.Head.Position)
                    return tp, dist, wall
                end
            end
        end
        return nil, math.huge, false
    end

    -- ドロップダウン選択
    if SelectedPlayer and SelectedPlayer ~= "なし" then
        -- [修正8] GetPlayerByName を使用
        local tp = GetPlayerByName(SelectedPlayer)
        if tp and tp.Character and tp.Character:FindFirstChild("HumanoidRootPart") and tp.Character:FindFirstChild("Head") then
            local hum = tp.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (localPos - tp.Character.HumanoidRootPart.Position).Magnitude
                if IsWithinDistance(localPos, tp.Character.HumanoidRootPart.Position) then
                    local wall = CheckWallBetween(localPos, tp.Character.Head.Position)
                    return tp, dist, wall
                end
            end
        end
        return nil, math.huge, false
    end

    -- 複数ターゲット or 全員
    local candidates = {}
    if #Settings.TargetPlayers > 0 then
        for _, name in ipairs(Settings.TargetPlayers) do
            if name ~= "" then
                local p = GetPlayerByName(name) -- [修正8]
                if p then table.insert(candidates, p) end
            end
        end
    else
        candidates = Players:GetPlayers()
    end

    local bestPlayer, bestPriority = nil, -math.huge
    local bestDistance = math.huge

    for _, player in ipairs(candidates) do
        if player ~= LocalPlayer and player.Character
            and player.Character:FindFirstChild("HumanoidRootPart")
            and player.Character:FindFirstChild("Head") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local dist = (localPos - player.Character.HumanoidRootPart.Position).Magnitude
                if IsWithinDistance(localPos, player.Character.HumanoidRootPart.Position) then
                    if not CheckWallBetween(localPos, player.Character.Head.Position) then
                        local priority = CalculateTargetPriority(player, dist)
                        if priority > bestPriority then
                            bestPriority = priority
                            bestPlayer   = player
                            bestDistance = dist
                        end
                    end
                end
            end
        end
    end

    return bestPlayer, bestDistance, false
end

-- ============================================================
-- [修正5] ターゲット検索（ボット用）- GetDescendants で深部も検索
-- ============================================================
local function GetBestBot()
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then
        return nil, math.huge, false
    end
    local localPos   = LocalPlayer.Character.HumanoidRootPart.Position
    local bestBot    = nil
    local bestPriority = -math.huge
    local bestDistance = math.huge

    -- [修正5] GetDescendants でフォルダ内のボットも検出
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model")
            and model:FindFirstChild("Humanoid")
            and model:FindFirstChild("HumanoidRootPart")
            and model:FindFirstChild("Head") then

            local isPlayer = false
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character == model then isPlayer = true; break end
            end

            if not isPlayer then
                local hum = model:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then
                    local dist = (localPos - model.HumanoidRootPart.Position).Magnitude
                    if IsWithinBotDistance(localPos, model.HumanoidRootPart.Position) then
                        if not CheckWallBetweenBot(localPos, model.Head.Position) then
                            local priority = CalculateBotPriority(model, dist)
                            if priority > bestPriority then
                                bestPriority = priority
                                bestBot      = model
                                bestDistance = dist
                            end
                        end
                    end
                end
            end
        end
    end

    return bestBot, bestDistance, false
end

-- ============================================================
-- [修正2][修正3] スムーズロック - Lerpを使いTween生成ゼロ化
--               カメラタイプをScriptableに設定
-- ============================================================
local function SetCameraScriptable()
    Camera.CameraType = Enum.CameraType.Scriptable
end

local function RestoreCamera()
    Camera.CameraType = Enum.CameraType.Custom
end

local function SmoothLookAt(targetPosition)
    -- [修正2] Tweenを毎フレーム作らずLerpで補間
    local currentLook = Camera.CFrame
    local goalCFrame  = CFrame.new(currentLook.Position, targetPosition)
    Camera.CFrame     = currentLook:Lerp(goalCFrame, math.clamp(Settings.SmoothLockSpeed, 0.01, 1))
end

local function SmoothLookAtBot(targetPosition)
    local currentLook = Camera.CFrame
    local goalCFrame  = CFrame.new(currentLook.Position, targetPosition)
    Camera.CFrame     = currentLook:Lerp(goalCFrame, math.clamp(BotSettings.SmoothLockSpeed, 0.01, 1))
end

-- ============================================================
-- リセット関数
-- ============================================================
local function ResetLock()
    if lockConnection then lockConnection:Disconnect(); lockConnection = nil end
    isLocking          = false
    currentTarget      = nil
    wallCheckStartTime = 0
    lastLockTime       = 0
    RestoreCamera()
    if lockIndicator then lockIndicator.Enabled = false end
end

local function ResetBotLock()
    if botLockConnection then botLockConnection:Disconnect(); botLockConnection = nil end
    isBotLocking           = false
    currentBotTarget       = nil
    botWallCheckStartTime  = 0
    botLastLockTime        = 0
    RestoreCamera()
end

local function ResetLogs()
    targetHistory = {}
end

-- ============================================================
-- ヘッドロック本体（プレイヤー用）
-- ============================================================
local function LockToHead()
    if not Settings.LockEnabled then return end
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then return end

    if Settings.ResetOnDeath then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum and hum.Health <= 0 then ResetLock(); return end
    end

    local currentTime = tick()
    if currentTime - lastLockTime < Settings.CooldownTime then return end
    if isLocking then return end

    local enemy, distance, hasWall = GetBestEnemy()

    if enemy then
        -- [修正13] Head の nil チェックを安全に
        if Settings.ShowLockIndicator and lockIndicator then
            local head = enemy.Character and enemy.Character:FindFirstChild("Head")
            if head then
                lockIndicator.Adornee = head
                lockIndicator.Enabled = true
            end
        end

        local function DoLock()
            isLocking     = true
            currentTarget = enemy
            lastLockTime  = currentTime
            lockStartTime = currentTime

            -- [修正7] 実経過時間を後で記録するためにstartを保存
            local recordStart = tick()

            -- [修正4] 再割り当て前に必ずDisconnect
            if lockConnection then lockConnection:Disconnect(); lockConnection = nil end

            -- [修正3] カメラをScriptableに
            SetCameraScriptable()

            lockConnection = RunService.RenderStepped:Connect(function()
                if not Settings.LockEnabled
                    or not currentTarget
                    or not (currentTarget.Character and currentTarget.Character:FindFirstChild("Head")) then
                    ResetLock()
                    return
                end

                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    if not IsWithinDistance(LocalPlayer.Character.HumanoidRootPart.Position,
                                           currentTarget.Character.HumanoidRootPart.Position) then
                        ResetLock(); return
                    end

                    if Settings.WallCheckEnabled then
                        if CheckWallBetween(LocalPlayer.Character.HumanoidRootPart.Position,
                                            currentTarget.Character.Head.Position) then
                            ResetLock(); return
                        end
                    end
                end

                if tick() - lockStartTime >= Settings.LockDuration then
                    -- [修正7] 実際に経過した時間を記録
                    local elapsed = math.floor((tick() - recordStart) * 10) / 10
                    table.insert(targetHistory, 1, {
                        player   = currentTarget.Name,
                        time     = os.date("%H:%M:%S"),
                        duration = elapsed  -- 実経過時間
                    })
                    if #targetHistory > 10 then table.remove(targetHistory, 11) end
                    ResetLock(); return
                end

                local head = currentTarget.Character:FindFirstChild("Head")
                if not head then ResetLock(); return end

                if Settings.SmoothLockEnabled then
                    SmoothLookAt(head.Position)
                else
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
                end
            end)
        end

        if not Settings.WallCheckEnabled then
            DoLock()
        else
            if not hasWall then
                if wallCheckStartTime == 0 then wallCheckStartTime = currentTime end
                if currentTime - wallCheckStartTime >= Settings.WallCheckDelay then
                    wallCheckStartTime = 0
                    DoLock()
                end
            else
                wallCheckStartTime = 0
                if lockIndicator then lockIndicator.Enabled = false end
            end
        end
    else
        wallCheckStartTime = 0
        if lockIndicator then lockIndicator.Enabled = false end
    end
end

-- ============================================================
-- ヘッドロック本体（ボット用）
-- ============================================================
local function LockToBot()
    if not BotSettings.LockEnabled then return end
    if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then return end

    local currentTime = tick()
    if currentTime - botLastLockTime < BotSettings.CooldownTime then return end
    if isBotLocking then return end

    local bot, distance, hasWall = GetBestBot()

    if bot then
        local function DoBotLock()
            isBotLocking    = true
            currentBotTarget = bot
            botLastLockTime = currentTime
            botLockStartTime = currentTime

            -- [修正4] 再割り当て前に必ずDisconnect
            if botLockConnection then botLockConnection:Disconnect(); botLockConnection = nil end

            SetCameraScriptable() -- [修正3]

            botLockConnection = RunService.RenderStepped:Connect(function()
                if not BotSettings.LockEnabled
                    or not currentBotTarget
                    or not currentBotTarget:FindFirstChild("Head") then
                    ResetBotLock(); return
                end

                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    if not IsWithinBotDistance(LocalPlayer.Character.HumanoidRootPart.Position,
                                               currentBotTarget.HumanoidRootPart.Position) then
                        ResetBotLock(); return
                    end

                    if BotSettings.WallCheckEnabled then
                        if CheckWallBetweenBot(LocalPlayer.Character.HumanoidRootPart.Position,
                                               currentBotTarget.Head.Position) then
                            ResetBotLock(); return
                        end
                    end
                end

                if tick() - botLockStartTime >= BotSettings.LockDuration then
                    ResetBotLock(); return
                end

                local head = currentBotTarget:FindFirstChild("Head")
                if not head then ResetBotLock(); return end

                if BotSettings.SmoothLockEnabled then
                    SmoothLookAtBot(head.Position)
                else
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
                end
            end)
        end

        if not BotSettings.WallCheckEnabled then
            DoBotLock()
        else
            if not hasWall then
                if botWallCheckStartTime == 0 then botWallCheckStartTime = currentTime end
                if currentTime - botWallCheckStartTime >= BotSettings.WallCheckDelay then
                    botWallCheckStartTime = 0
                    DoBotLock()
                end
            else
                botWallCheckStartTime = 0
            end
        end
    else
        botWallCheckStartTime = 0
    end
end

-- ============================================================
-- [修正12] Drawing API を pcall でラップした安全なESP作成
-- ============================================================
local function SafeDrawingNew(drawType)
    local ok, obj = pcall(function() return Drawing.new(drawType) end)
    return ok and obj or nil
end

local function CreateNameESP(player)
    local nameTag = SafeDrawingNew("Text")
    if not nameTag then return end
    nameTag.Visible  = false
    nameTag.Center   = true
    nameTag.Outline  = true
    nameTag.Font     = 2
    nameTag.Size     = 16
    nameTag.Color    = Color3.new(1, 1, 1)

    local conn = RunService.RenderStepped:Connect(function()
        if not Settings.NameESPEnabled then nameTag.Visible = false; return end
        if player.Character and player.Character:FindFirstChild("Head") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local pos, onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position + Vector3.new(0, 1, 0))
                if onScreen then
                    nameTag.Position = Vector2.new(pos.X, pos.Y)
                    nameTag.Text     = player.Name
                    nameTag.Visible  = true
                    return
                end
            end
        end
        nameTag.Visible = false
    end)
    nameESPConnections[player] = {nameTag = nameTag, connection = conn}
end

local function CreateHealthESP(player)
    local healthBar  = SafeDrawingNew("Line")
    local healthText = SafeDrawingNew("Text")
    if not healthBar or not healthText then return end

    healthBar.Visible    = false
    healthBar.Color      = Color3.new(0, 1, 0)
    healthBar.Thickness  = 2

    healthText.Visible   = false
    healthText.Center    = true
    healthText.Outline   = true
    healthText.Font      = 2
    healthText.Size      = 14
    healthText.Color     = Color3.new(1, 1, 1)

    local conn = RunService.RenderStepped:Connect(function()
        if not Settings.HealthESPEnabled then
            healthBar.Visible = false; healthText.Visible = false; return
        end
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local pos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position + Vector3.new(0, 2, 0))
                if onScreen then
                    local pct    = hum.Health / hum.MaxHealth
                    local barLen = 50
                    healthBar.From = Vector2.new(pos.X - barLen/2, pos.Y + 20)
                    healthBar.To   = Vector2.new(pos.X - barLen/2 + barLen * pct, pos.Y + 20)
                    healthBar.Color = pct > 0.5 and Color3.new(0,1,0) or (pct > 0.25 and Color3.new(1,1,0) or Color3.new(1,0,0))
                    healthText.Position = Vector2.new(pos.X, pos.Y + 25)
                    healthText.Text     = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
                    healthBar.Visible   = true
                    healthText.Visible  = true
                    return
                end
            end
        end
        healthBar.Visible = false; healthText.Visible = false
    end)
    healthESPConnections[player] = {healthBar = healthBar, healthText = healthText, connection = conn}
end

local function CreateBoxESP(player)
    local box = SafeDrawingNew("Square")
    if not box then return end
    box.Visible    = false
    box.Color      = Color3.new(0, 1, 0)
    box.Thickness  = 1
    box.Filled     = false

    local conn = RunService.RenderStepped:Connect(function()
        if not Settings.BoxESPEnabled then box.Visible = false; return end
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local rootPos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
                local headPos = Camera:WorldToViewportPoint(player.Character.Head.Position)
                if onScreen then
                    local height = math.abs(headPos.Y - rootPos.Y) * 1.5
                    local width  = height * 0.6
                    box.Size     = Vector2.new(width, height)
                    box.Position = Vector2.new(rootPos.X - width/2, rootPos.Y - height/2)
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
    local trace = SafeDrawingNew("Line")
    if not trace then return end
    trace.Visible       = false
    trace.Color         = Settings.TraceColor
    trace.Thickness     = Settings.TraceThickness
    trace.Transparency  = Settings.TraceTransparency

    local conn = RunService.RenderStepped:Connect(function()
        if not Settings.TraceEnabled then trace.Visible = false; return end
        trace.Thickness    = Settings.TraceThickness
        trace.Color        = Settings.TraceColor
        trace.Transparency = Settings.TraceTransparency
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local pos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
            if onScreen then
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

-- ESP全更新
local function UpdateESP()
    for _, data in pairs(nameESPConnections) do
        data.connection:Disconnect()
        pcall(function() data.nameTag:Remove() end)
    end
    nameESPConnections = {}

    for _, data in pairs(healthESPConnections) do
        data.connection:Disconnect()
        pcall(function() data.healthBar:Remove(); data.healthText:Remove() end)
    end
    healthESPConnections = {}

    for _, data in pairs(boxESPConnections) do
        data.connection:Disconnect()
        pcall(function() data.box:Remove() end)
    end
    boxESPConnections = {}

    for _, data in pairs(traceConnections) do
        data.connection:Disconnect()
        pcall(function() data.trace:Remove() end)
    end
    traceConnections = {}

    for _, name in ipairs(Settings.ESPPlayers) do
        if name ~= "" then
            local player = GetPlayerByName(name) -- [修正8]
            if player and player ~= LocalPlayer then
                CreateNameESP(player)
                CreateHealthESP(player)
                CreateBoxESP(player)
                CreateTrace(player)
            end
        end
    end
end

-- ============================================================
-- 複数ターゲット / ESP 更新
-- ============================================================
local function UpdateMultiTarget()
    Settings.TargetPlayers = {}
    for i = 1, 25 do
        local inp = multiTargetInputs[i]
        if inp and inp.Text and inp.Text ~= "" then
            table.insert(Settings.TargetPlayers, inp.Text)
        end
    end
end

local function UpdateMultiESP()
    Settings.ESPPlayers = {}
    for i = 1, 25 do
        local inp = multiESPInputs[i]
        if inp and inp.Text and inp.Text ~= "" then
            table.insert(Settings.ESPPlayers, inp.Text)
        end
    end
    UpdateESP()
end

-- ============================================================
-- プレイヤー参加 / 退出処理
-- [修正6] task.wait(2) → CharacterAdded:Wait()
-- ============================================================
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Wait() -- [修正6] キャラクターが確実にロードされるまで待機
    if player ~= LocalPlayer then
        if table.find(Settings.ESPPlayers, player.Name) then
            CreateTrace(player)
            CreateNameESP(player)
            CreateHealthESP(player)
            CreateBoxESP(player)
        end
    end
    if playerDropdown then
        playerDropdown:Refresh(UpdatePlayerList(), true)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local function cleanConn(tbl, key, ...)
        if tbl[key] then
            tbl[key].connection:Disconnect()
            for _, field in ipairs({...}) do
                pcall(function() tbl[key][field]:Remove() end)
            end
            tbl[key] = nil
        end
    end
    cleanConn(traceConnections,    player, "trace")
    cleanConn(nameESPConnections,  player, "nameTag")
    cleanConn(healthESPConnections,player, "healthBar", "healthText")
    cleanConn(boxESPConnections,   player, "box")
    if playerDropdown then
        playerDropdown:Refresh(UpdatePlayerList(), true)
    end
end)

-- ============================================================
-- UI構築 - メインタブ
-- ============================================================
local LockToggle = MainTab:CreateToggle({
    Name = "🔐 Head Lock",
    CurrentValue = false,
    Flag = "HeadLockToggle",
    Callback = function(Value)
        Settings.LockEnabled = Value
        if not Value then ResetLock() end
    end,
})

MainTab:CreateButton({
    Name = "🔄 Lock Reset",
    Callback = function() ResetLock() end,
})

MainTab:CreateSection("🎯 ターゲット設定")

playerDropdown = MainTab:CreateDropdown({
    Name = "ターゲットプレイヤー選択",
    Options = UpdatePlayerList(),
    CurrentOption = {"なし"},
    Flag = "PlayerSelect",
    Callback = function(Option)
        local sel = type(Option) == "table" and Option[1] or Option
        if sel == "なし" then
            SelectedPlayer = nil
        elseif sel == "リセット" then
            SelectedPlayer = nil
            playerDropdown:Set("なし")
        elseif sel == "最寄りのプレイヤー" then
            FindNearestPlayer()
        else
            SelectedPlayer = sel
        end
        UpdateSelectedLabel()
    end,
})

selectedLabel = MainTab:CreateLabel("選択中: なし")

MainTab:CreateInput({
    Name = "プレイヤーIDで指定",
    PlaceholderText = "ユーザーIDを入力",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local userId = tonumber(Text)
        Settings.TargetPlayerID = userId or nil
    end,
})

MainTab:CreateSection("🎥 ESP System")

MainTab:CreateToggle({
    Name = "㈴ Name ESP",
    CurrentValue = false,
    Flag = "NameESPToggle",
    Callback = function(Value) Settings.NameESPEnabled = Value; UpdateESP() end,
})

MainTab:CreateToggle({
    Name = "💚 Health ESP",
    CurrentValue = false,
    Flag = "HealthESPToggle",
    Callback = function(Value) Settings.HealthESPEnabled = Value; UpdateESP() end,
})

MainTab:CreateToggle({
    Name = "🎁 Box ESP",
    CurrentValue = false,
    Flag = "BoxESPToggle",
    Callback = function(Value) Settings.BoxESPEnabled = Value; UpdateESP() end,
})

MainTab:CreateToggle({
    Name = "一 Trace ESP",
    CurrentValue = false,
    Flag = "TraceToggle",
    Callback = function(Value) Settings.TraceEnabled = Value; UpdateESP() end,
})

-- ============================================================
-- UI構築 - ボットタブ
-- ============================================================
MainTab:CreateSection("") -- spacer

BotTab:CreateToggle({
    Name = "🤖 ボットヘッドロック",
    CurrentValue = false,
    Flag = "BotHeadLockToggle",
    Callback = function(Value)
        BotSettings.LockEnabled = Value
        if not Value then ResetBotLock() end
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
    Callback = function(Value) BotSettings.WallCheckEnabled = Value end,
})

BotTab:CreateToggle({
    Name = "🌀 スムーズロック",
    CurrentValue = false,
    Flag = "BotSmoothLockToggle",
    Callback = function(Value) BotSettings.SmoothLockEnabled = Value end,
})

BotTab:CreateDropdown({
    Name = "ターゲット優先度",
    Options = {"最近", "低HP", "ランダム"},
    CurrentOption = {"最近"},
    MultipleOptions = false,
    Flag = "BotLockPriorityDropdown",
    Callback = function(Option)
        local map = {["最近"] = "Closest", ["低HP"] = "LowestHealth", ["ランダム"] = "Random"}
        BotSettings.LockPriority = map[Option[1]] or "Closest"
    end,
})

-- ============================================================
-- UI構築 - 複数選択タブ
-- ============================================================
MultiSelectTab:CreateSection("複数ターゲットプレイヤー (最大25人)")

for i = 1, 25 do
    multiTargetInputs[i] = MultiSelectTab:CreateInput({
        Name = "ターゲットプレイヤー " .. i,
        PlaceholderText = "プレイヤー名を入力",
        RemoveTextAfterFocusLost = false,
        Callback = function() UpdateMultiTarget() end,
    })
end

MultiSelectTab:CreateButton({
    Name = "🔄 複数ターゲット更新",
    Callback = function() UpdateMultiTarget() end,
})

-- ============================================================
-- UI構築 - 複数ESP選択タブ
-- ============================================================
MultiESPSelectTab:CreateSection("複数ESPプレイヤー (最大25人)")

for i = 1, 25 do
    multiESPInputs[i] = MultiESPSelectTab:CreateInput({
        Name = "ESPプレイヤー " .. i,
        PlaceholderText = "プレイヤー名を入力",
        RemoveTextAfterFocusLost = false,
        Callback = function() UpdateMultiESP() end,
    })
end

MultiESPSelectTab:CreateButton({
    Name = "🔄 複数ESP更新",
    Callback = function() UpdateMultiESP() end,
})

-- ============================================================
-- UI構築 - 設定タブ
-- ============================================================
SettingsTab:CreateSection("📏 ロック距離設定（プレイヤー用）")
SettingsTab:CreateSlider({
    Name = "360°全方位距離（スタッド）",
    Range = {0, 100}, Increment = 1, CurrentValue = 5,
    Flag = "LockDistanceSlider",
    Callback = function(v) Settings.LockDistance = v end,
})

SettingsTab:CreateSection("📏 ロック距離設定（ボット用）")
SettingsTab:CreateSlider({
    Name = "ボット360°全方位距離（スタッド）",
    Range = {0, 100}, Increment = 1, CurrentValue = 5,
    Flag = "BotDistanceSlider",
    Callback = function(v) BotSettings.LockDistance = v end,
})

SettingsTab:CreateSection("⏱️ ロックタイミング設定（プレイヤー用）")
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
    Name = "クールダウン時間（秒）",
    Range = {0.1, 10}, Increment = 0.1, CurrentValue = 1,
    Flag = "CooldownSlider",
    Callback = function(v) Settings.CooldownTime = v end,
})

SettingsTab:CreateSection("⏱️ ロックタイミング設定（ボット用）")
SettingsTab:CreateSlider({
    Name = "ボットロック持続時間（秒）",
    Range = {0.1, 10}, Increment = 0.1, CurrentValue = 0.5,
    Flag = "BotLockDurationSlider",
    Callback = function(v) BotSettings.LockDuration = v end,
})
SettingsTab:CreateSlider({
    Name = "ボットクールダウン時間（秒）",
    Range = {0.1, 10}, Increment = 0.1, CurrentValue = 1,
    Flag = "BotCooldownSlider",
    Callback = function(v) BotSettings.CooldownTime = v end,
})

SettingsTab:CreateSection("🎮 高度な設定（プレイヤー用）")
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
        local map = {["最近"] = "Closest", ["低HP"] = "LowestHealth", ["ランダム"] = "Random"}
        Settings.LockPriority = map[Option[1]] or "Closest"
    end,
})

SettingsTab:CreateSection("🎮 高度な設定（ボット用）")
SettingsTab:CreateSlider({
    Name = "ボットスムーズ速度",
    Range = {0.01, 1}, Increment = 0.01, CurrentValue = 0.1,
    Flag = "BotSmoothLockSpeedSlider",
    Callback = function(v) BotSettings.SmoothLockSpeed = v end,
})

SettingsTab:CreateSection("🔧 トレース設定")
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
    Callback = function(v)
        Settings.ShowLockIndicator = v
        if v and not lockIndicator then CreateLockIndicator() end
        if lockIndicator then lockIndicator.Enabled = false end
    end,
})
SettingsTab:CreateToggle({
    Name = "死亡時リセット",
    CurrentValue = true,
    Flag = "ResetOnDeathToggle",
    Callback = function(v) Settings.ResetOnDeath = v end,
})

-- ============================================================
-- UI構築 - 情報タブ
-- ============================================================
InfoTab:CreateSection("📊 システム情報")
InfoTab:CreateButton({
    Name = "🔄 ログリセット",
    Callback = function() ResetLogs() end,
})

local currentTargetLabel  = InfoTab:CreateLabel("現在のターゲット: なし")
local lockStatusLabel     = InfoTab:CreateLabel("ロック状態: 🔓 未ロック")
local wallCheckLabel      = InfoTab:CreateLabel("壁判定: 有効")
local botTargetLabel      = InfoTab:CreateLabel("現在のボットターゲット: なし")
local botLockStatusLabel  = InfoTab:CreateLabel("ボットロック状態: 🔓 未ロック")

InfoTab:CreateSection("📈 ターゲット履歴")
local historyLabel = InfoTab:CreateLabel("履歴は最大10件保存されます")

InfoTab:CreateButton({
    Name = "履歴を更新",
    Callback = function()
        local lines = {"ターゲット履歴:"}
        if #targetHistory > 0 then
            for i, entry in ipairs(targetHistory) do
                table.insert(lines, string.format("%d. %s - %s (%.1f秒)", i, entry.player, entry.time, entry.duration))
            end
        else
            table.insert(lines, "履歴はありません")
        end
        historyLabel:SetText(table.concat(lines, "\n"))
        currentTargetLabel:SetText("現在のターゲット: " .. (currentTarget and currentTarget.Name or "なし"))
        lockStatusLabel:SetText("ロック状態: " .. (isLocking and "🔒 ロック中" or "🔓 未ロック"))
        wallCheckLabel:SetText("壁判定: " .. (Settings.WallCheckEnabled and "有効" or "無効"))
        botTargetLabel:SetText("現在のボットターゲット: " .. (currentBotTarget and currentBotTarget.Name or "なし"))
        botLockStatusLabel:SetText("ボットロック状態: " .. (isBotLocking and "🔒 ロック中" or "🔓 未ロック"))
    end,
})

InfoTab:CreateSection("ℹ️ 使い方")
InfoTab:CreateParagraph({
    Title   = "基本操作",
    Content = "1. メインタブでヘッドロックを有効化\n2. 設定タブで各種パラメータを調整\n3. 特定のプレイヤーをターゲットにする場合はドロップダウンから選択\n4. リセットボタンでロック状態をクリア"
})
InfoTab:CreateParagraph({
    Title   = "壁判定機能",
    Content = "有効時: 壁がない場合のみロック\n無効時: 壁を無視して即座にロック（強力モード）"
})
InfoTab:CreateParagraph({
    Title   = "ESP機能",
    Content = "Name ESP: プレイヤー名を表示\nHealth ESP: HPバーと数値を表示\nBox ESP: プレイヤー周囲にボックスを表示\nTrace ESP: プレイヤーへの線（太さ・色・透明度調整可能）"
})
InfoTab:CreateParagraph({
    Title   = "ボット機能",
    Content = "サブメインタブでボットヘッドロックを有効化\nボットはワークスペース内のHumanoidを持つモデルを対象（フォルダ内も検索）\nプレイヤーキャラクターは除外されます"
})

-- ============================================================
-- キーバインド
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        Settings.LockEnabled = not Settings.LockEnabled
        if not Settings.LockEnabled then ResetLock() end
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        ResetLock()
    end
    if input.KeyCode == Enum.KeyCode.Insert then
        BotSettings.LockEnabled = not BotSettings.LockEnabled
        if not BotSettings.LockEnabled then ResetBotLock() end
    end
end)

-- ============================================================
-- [修正9] RenderStepped を1つに統合
-- ============================================================
RunService.RenderStepped:Connect(function()
    LockToHead()
    LockToBot()
end)

-- ============================================================
-- [修正10] プレイヤーリスト更新ループ（キャンセル機構付き）
-- ============================================================
task.spawn(function()
    while playerListLoopActive and task.wait(2) do
        if playerDropdown then
            playerDropdown:Refresh(UpdatePlayerList(), true)
        end
    end
end)

-- ============================================================
-- 初期化
-- ============================================================
task.spawn(function()
    task.wait(2)
    CreateLockIndicator()
    UpdateESP()
end)

Rayfield:LoadConfiguration()

-- ============================================================
-- [修正11] ゲーム終了時クリーンアップ - BindToClose で確実に実行
-- ============================================================
local function Cleanup()
    playerListLoopActive = false  -- [修正10] ループ停止

    ResetLock()
    ResetBotLock()
    RestoreCamera()

    for _, data in pairs(traceConnections) do
        data.connection:Disconnect()
        pcall(function() data.trace:Remove() end)
    end
    for _, data in pairs(nameESPConnections) do
        data.connection:Disconnect()
        pcall(function() data.nameTag:Remove() end)
    end
    for _, data in pairs(healthESPConnections) do
        data.connection:Disconnect()
        pcall(function() data.healthBar:Remove(); data.healthText:Remove() end)
    end
    for _, data in pairs(boxESPConnections) do
        data.connection:Disconnect()
        pcall(function() data.box:Remove() end)
    end
    if lockIndicator then
        pcall(function() lockIndicator:Destroy() end)
    end
end

game:BindToClose(Cleanup)

-- CoreGui.ChildRemoved も残す（UI手動終了対応）
game:GetService("CoreGui").ChildRemoved:Connect(function(child)
    if child.Name == "Rayfield" then
        Cleanup()
    end
end)
