-- Rayfield UIライブラリの読み込み
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
-- 変数の初期化
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
-- 設定値
local Settings = {
    LockEnabled = false,
    LockDistance = 5, -- 360°全方位距離（0-100スタッド）
    LockDuration = 0.5, -- 固定時間（秒）
    CooldownTime = 1, -- 再作動までの時間（秒）
    TraceEnabled = false,
    TraceThickness = 1, -- Traceの太さ（1-150）
    TraceColor = Color3.fromRGB(255, 50, 50), -- 赤色
    TraceTransparency = 0.1, -- 透明度
    NameESPEnabled = false,
    HealthESPEnabled = false,
    BoxESPEnabled = false,
    TargetPlayer = nil, -- 固定する特定のプレイヤー
    TargetPlayerID = nil, -- プレイヤーIDで指定
    TargetPlayers = {}, -- 複数ターゲットプレイヤー
    ESPPlayers = {}, -- 複数ESP対象プレイヤー
    WallCheckEnabled = true, -- 壁判定の有効/無効
    WallCheckDelay = 0, -- 壁判定の遅延（秒）- 固定0
    SmoothLockEnabled = false, -- スムーズロック
    SmoothLockSpeed = 0.1, -- スムーズロック速度
    AutoUpdateTarget = true, -- ターゲット自動更新
    ShowLockIndicator = true, -- ロックインジケーター表示
    ResetOnDeath = true, -- 死亡時リセット
    LockPriority = "Closest" -- "Closest", "LowestHealth", "Random"
}

-- ボット設定値
local BotSettings = {
    LockEnabled = false,
    LockDistance = 5, -- 360°全方位距離（0-100スタッド）
    LockDuration = 0.5,
    CooldownTime = 1,
    WallCheckEnabled = true,
    WallCheckDelay = 0,
    SmoothLockEnabled = false,
    SmoothLockSpeed = 0.1,
    LockPriority = "Closest"
}

-- 状態管理
local isLocking = false
local isBotLocking = false
local lastLockTime = 0
local botLastLockTime = 0
local lockConnection = nil
local botLockConnection = nil
local traceConnections = {}
local nameESPConnections = {}
local healthESPConnections = {}
local boxESPConnections = {}
local currentTarget = nil
local currentBotTarget = nil
local playerDropdown = nil
local wallCheckStartTime = 0
local botWallCheckStartTime = 0
local wallCheckPassed = false
local botWallCheckPassed = false
local lockStartTime = 0
local botLockStartTime = 0
local targetHistory = {}
local lockIndicator = nil
local SelectedPlayer = nil

-- Rayfield ウィンドウの作成
local Window = Rayfield:CreateWindow({
    Name = "Syu_uhub",
    LoadingTitle = "Syu_uhub Loading...",
    LoadingSubtitle = "by Syu - Advanced Head Lock System",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SyuHub",
        FileName = "SyuHubConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    }
})

-- メインタブ
local MainTab = Window:CreateTab("メイン", 4483362458)
-- サブメインタブ（ボット用）
local BotTab = Window:CreateTab("サブメイン（ボット）", 4483362458)
-- 設定タブ
local SettingsTab = Window:CreateTab("設定", 4483345998)
-- 複数選択タブ (ヘッドロックターゲット用)
local MultiSelectTab = Window:CreateTab("複数選択", 4483345998)
-- 複数選択ESP項目タブ (ESP対象用)
local MultiESPSelectTab = Window:CreateTab("複数選択ESP項目", 4483345998)
-- 情報タブ
local InfoTab = Window:CreateTab("情報", 4483345998)

-- ロックインジケーター作成
local function CreateLockIndicator()
    if lockIndicator then
        lockIndicator:Remove()
    end
   
    lockIndicator = Instance.new("BillboardGui")
    lockIndicator.Name = "LockIndicator"
    lockIndicator.AlwaysOnTop = true
    lockIndicator.Size = UDim2.new(4, 0, 4, 0)
    lockIndicator.StudsOffset = Vector3.new(0, 3, 0)
   
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    frame.BackgroundTransparency = 0.7
    frame.BorderSizePixel = 0
    frame.Parent = lockIndicator
   
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
   
    lockIndicator.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- プレイヤーリストを取得する関数（改善版）
local function UpdatePlayerList()
    local playerList = {"なし", "リセット", "最寄りのプレイヤー"}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerList, player.Name)
        end
    end
    return playerList
end

-- 選択中のプレイヤーラベルを更新
local selectedLabel = nil
local function UpdateSelectedLabel()
    if selectedLabel then
        if SelectedPlayer then
            selectedLabel:SetText("選択中: " .. SelectedPlayer)
        else
            selectedLabel:SetText("選択中: なし")
        end
    end
end

-- 最寄りのプレイヤーを検索
local function FindNearestPlayer()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local nearestPlayer = nil
    local shortestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                nearestPlayer = player
            end
        end
    end
    
    if nearestPlayer then
        SelectedPlayer = nearestPlayer.Name
        if playerDropdown then
            playerDropdown:Set(nearestPlayer.Name)
        end
        UpdateSelectedLabel()
    end
end

-- プレイヤーIDからプレイヤーを取得
local function GetPlayerByID(userId)
    for _, player in pairs(Players:GetPlayers()) do
        if player.UserId == userId then
            return player
        end
    end
    return nil
end

-- 壁判定関数
local function CheckWallBetween(startPos, endPos)
    if not Settings.WallCheckEnabled then
        return false
    end
   
    local direction = (endPos - startPos).Unit
    local distance = (endPos - startPos).Magnitude
   
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.IgnoreWater = true
   
    local raycastResult = workspace:Raycast(startPos, direction * distance, raycastParams)
   
    if raycastResult then
        local hitModel = raycastResult.Instance
        while hitModel and hitModel ~= workspace do
            local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
            if hitPlayer and hitPlayer ~= LocalPlayer then
                return false
            end
            hitModel = hitModel.Parent
        end
        return true
    end
   
    return false
end

-- ボット用壁判定関数
local function CheckWallBetweenBot(startPos, endPos)
    if not BotSettings.WallCheckEnabled then
        return false
    end
   
    local direction = (endPos - startPos).Unit
    local distance = (endPos - startPos).Magnitude
   
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.IgnoreWater = true
   
    local raycastResult = workspace:Raycast(startPos, direction * distance, raycastParams)
   
    if raycastResult then
        local hitModel = raycastResult.Instance
        while hitModel and hitModel ~= workspace do
            if hitModel:IsA("Model") and hitModel:FindFirstChild("Humanoid") then
                return false
            end
            hitModel = hitModel.Parent
        end
        return true
    end
   
    return false
end

-- 360°球体距離チェック関数（プレイヤー用）
local function IsWithinDistance(localPos, enemyPos)
    local distance = (enemyPos - localPos).Magnitude
    return distance <= Settings.LockDistance
end

-- 360°球体距離チェック関数（ボット用）
local function IsWithinBotDistance(localPos, enemyPos)
    local distance = (enemyPos - localPos).Magnitude
    return distance <= BotSettings.LockDistance
end

-- プレイヤーの健康状態を取得
local function GetPlayerHealth(player)
    if player.Character then
        local humanoid = player.Character:FindFirstChild("Humanoid")
        if humanoid then
            return humanoid.Health, humanoid.MaxHealth
        end
    end
    return 0, 100
end

-- ボットの健康状態を取得
local function GetBotHealth(model)
    if model then
        local humanoid = model:FindFirstChild("Humanoid")
        if humanoid then
            return humanoid.Health, humanoid.MaxHealth
        end
    end
    return 0, 100
end

-- ターゲットの優先度を計算（プレイヤー用）
local function CalculateTargetPriority(player, distance)
    if Settings.LockPriority == "LowestHealth" then
        local health, maxHealth = GetPlayerHealth(player)
        return health / maxHealth
    elseif Settings.LockPriority == "Random" then
        return math.random()
    else -- "Closest"
        return 1 / (distance + 1)
    end
end

-- ターゲットの優先度を計算（ボット用）
local function CalculateBotPriority(model, distance)
    if BotSettings.LockPriority == "LowestHealth" then
        local health, maxHealth = GetBotHealth(model)
        return health / maxHealth
    elseif BotSettings.LockPriority == "Random" then
        return math.random()
    else -- "Closest"
        return 1 / (distance + 1)
    end
end

-- 最も適切な敵を取得する関数（プレイヤー用）
local function GetBestEnemy()
    local bestPlayer = nil
    local bestPriority = -math.huge
    local bestDistance = math.huge
    local hasWall = false
    
    -- 特定のプレイヤーIDが設定されている場合
    if Settings.TargetPlayerID and Settings.TargetPlayerID ~= 0 then
        local targetPlayer = GetPlayerByID(Settings.TargetPlayerID)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and targetPlayer.Character:FindFirstChild("Head") then
            local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
                if IsWithinDistance(LocalPlayer.Character.HumanoidRootPart.Position, targetPlayer.Character.HumanoidRootPart.Position) then
                    local wallCheck = CheckWallBetween(LocalPlayer.Character.HumanoidRootPart.Position, targetPlayer.Character.Head.Position)
                    if not wallCheck then
                        return targetPlayer, distance, false
                    else
                        return targetPlayer, distance, true
                    end
                end
            end
        end
        return nil, math.huge, false
    end
    
    -- ドロップダウンで選択されたプレイヤー
    if SelectedPlayer and SelectedPlayer ~= "なし" then
        local targetPlayer = Players:FindFirstChild(SelectedPlayer)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and targetPlayer.Character:FindFirstChild("Head") then
            local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
                if IsWithinDistance(LocalPlayer.Character.HumanoidRootPart.Position, targetPlayer.Character.HumanoidRootPart.Position) then
                    local wallCheck = CheckWallBetween(LocalPlayer.Character.HumanoidRootPart.Position, targetPlayer.Character.Head.Position)
                    if not wallCheck then
                        return targetPlayer, distance, false
                    else
                        return targetPlayer, distance, true
                    end
                end
            end
        end
        return nil, math.huge, false
    end
    
    -- 複数ターゲットが設定されている場合
    local candidates = {}
    if #Settings.TargetPlayers > 0 then
        for _, name in ipairs(Settings.TargetPlayers) do
            if name ~= "" then
                local player = Players:FindFirstChild(name)
                if player then
                    table.insert(candidates, player)
                end
            end
        end
    end
    
    -- 全プレイヤーを対象にする場合
    if (not SelectedPlayer or SelectedPlayer == "なし") and (#Settings.TargetPlayers == 0 and Settings.TargetPlayerID == nil) then
        candidates = Players:GetPlayers()
    end
    
    -- 自動で最適な敵を探す
    for _, player in pairs(candidates) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Head") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                if IsWithinDistance(LocalPlayer.Character.HumanoidRootPart.Position, player.Character.HumanoidRootPart.Position) then
                    local wallCheck = CheckWallBetween(LocalPlayer.Character.HumanoidRootPart.Position, player.Character.Head.Position)
                    if not wallCheck then
                        local priority = CalculateTargetPriority(player, distance)
                        if priority > bestPriority then
                            bestPriority = priority
                            bestPlayer = player
                            bestDistance = distance
                            hasWall = false
                        end
                    end
                end
            end
        end
    end
    
    return bestPlayer, bestDistance, hasWall
end

-- 最も適切なボットを取得する関数
local function GetBestBot()
    local bestBot = nil
    local bestPriority = -math.huge
    local bestDistance = math.huge
    local hasWall = false
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil, math.huge, false
    end
    
    local localPos = LocalPlayer.Character.HumanoidRootPart.Position
    
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and model:FindFirstChild("Humanoid") and model:FindFirstChild("HumanoidRootPart") and model:FindFirstChild("Head") then
            local isPlayer = false
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character == model then
                    isPlayer = true
                    break
                end
            end
            
            if not isPlayer then
                local humanoid = model:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local distance = (localPos - model.HumanoidRootPart.Position).Magnitude
                    if IsWithinBotDistance(localPos, model.HumanoidRootPart.Position) then
                        local wallCheck = CheckWallBetweenBot(localPos, model.Head.Position)
                        if not wallCheck then
                            local priority = CalculateBotPriority(model, distance)
                            if priority > bestPriority then
                                bestPriority = priority
                                bestBot = model
                                bestDistance = distance
                                hasWall = false
                            end
                        end
                    end
                end
            end
        end
    end
    
    return bestBot, bestDistance, hasWall
end

-- スムーズなカメラ移動
local function SmoothLookAt(targetPosition)
    local currentCFrame = Camera.CFrame
    local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPosition)
    
    local tweenInfo = TweenInfo.new(
        Settings.SmoothLockSpeed,
        Enum.EasingStyle.Sine,
        Enum.EasingDirection.Out
    )
    
    local tween = TweenService:Create(Camera, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
end

-- スムーズなカメラ移動（ボット用）
local function SmoothLookAtBot(targetPosition)
    local currentCFrame = Camera.CFrame
    local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPosition)
    
    local tweenInfo = TweenInfo.new(
        BotSettings.SmoothLockSpeed,
        Enum.EasingStyle.Sine,
        Enum.EasingDirection.Out
    )
    
    local tween = TweenService:Create(Camera, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
end

-- 頭に視点を固定する関数（プレイヤー用）
local function LockToHead()
    if not Settings.LockEnabled then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    if Settings.ResetOnDeath then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            if lockConnection then
                lockConnection:Disconnect()
                isLocking = false
                currentTarget = nil
                wallCheckStartTime = 0
            end
            return
        end
    end
    
    local currentTime = tick()
    if currentTime - lastLockTime < Settings.CooldownTime then return end
    if isLocking then return end
    
    local enemy, distance, hasWall = GetBestEnemy()
    
    if enemy then
        if Settings.ShowLockIndicator and lockIndicator and enemy.Character and enemy.Character:FindFirstChild("Head") then
            lockIndicator.Adornee = enemy.Character.Head
            lockIndicator.Enabled = true
        end
        
        if not Settings.WallCheckEnabled then
            isLocking = true
            currentTarget = enemy
            lastLockTime = currentTime
            lockStartTime = currentTime
            
            table.insert(targetHistory, 1, {
                player = enemy.Name,
                time = os.date("%H:%M:%S"),
                duration = Settings.LockDuration
            })
            if #targetHistory > 10 then
                table.remove(targetHistory, 11)
            end
            
            if lockConnection then
                lockConnection:Disconnect()
            end
            
            lockConnection = RunService.RenderStepped:Connect(function()
                if not Settings.LockEnabled or not currentTarget or not currentTarget.Character or not currentTarget.Character:FindFirstChild("Head") then
                    lockConnection:Disconnect()
                    isLocking = false
                    currentTarget = nil
                    
                    if lockIndicator then
                        lockIndicator.Enabled = false
                    end
                    return
                end
                
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    if not IsWithinDistance(LocalPlayer.Character.HumanoidRootPart.Position, currentTarget.Character.HumanoidRootPart.Position) then
                        lockConnection:Disconnect()
                        isLocking = false
                        currentTarget = nil
                        
                        if lockIndicator then
                            lockIndicator.Enabled = false
                        end
                        return
                    end
                end
                
                if tick() - lockStartTime >= Settings.LockDuration then
                    lockConnection:Disconnect()
                    isLocking = false
                    currentTarget = nil
                    
                    if lockIndicator then
                        lockIndicator.Enabled = false
                    end
                    return
                end
                
                if Settings.SmoothLockEnabled then
                    SmoothLookAt(currentTarget.Character.Head.Position)
                else
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Character.Head.Position)
                end
            end)
        else
            if not hasWall then
                if wallCheckStartTime == 0 then
                    wallCheckStartTime = currentTime
                end
                
                if currentTime - wallCheckStartTime >= Settings.WallCheckDelay then
                    isLocking = true
                    currentTarget = enemy
                    lastLockTime = currentTime
                    wallCheckStartTime = 0
                    lockStartTime = currentTime
                    
                    table.insert(targetHistory, 1, {
                        player = enemy.Name,
                        time = os.date("%H:%M:%S"),
                        duration = Settings.LockDuration
                    })
                    if #targetHistory > 10 then
                        table.remove(targetHistory, 11)
                    end
                    
                    if lockConnection then
                        lockConnection:Disconnect()
                    end
                    
                    lockConnection = RunService.RenderStepped:Connect(function()
                        if not Settings.LockEnabled or not currentTarget or not currentTarget.Character or not currentTarget.Character:FindFirstChild("Head") then
                            lockConnection:Disconnect()
                            isLocking = false
                            currentTarget = nil
                            
                            if lockIndicator then
                                lockIndicator.Enabled = false
                            end
                            return
                        end
                        
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            if not IsWithinDistance(LocalPlayer.Character.HumanoidRootPart.Position, currentTarget.Character.HumanoidRootPart.Position) then
                                lockConnection:Disconnect()
                                isLocking = false
                                currentTarget = nil
                                
                                if lockIndicator then
                                    lockIndicator.Enabled = false
                                end
                                return
                            end
                            
                            if Settings.WallCheckEnabled then
                                local wallCheck = CheckWallBetween(LocalPlayer.Character.HumanoidRootPart.Position, currentTarget.Character.Head.Position)
                                if wallCheck then
                                    lockConnection:Disconnect()
                                    isLocking = false
                                    currentTarget = nil
                                    
                                    if lockIndicator then
                                        lockIndicator.Enabled = false
                                    end
                                    return
                                end
                            end
                        end
                        
                        if tick() - lockStartTime >= Settings.LockDuration then
                            lockConnection:Disconnect()
                            isLocking = false
                            currentTarget = nil
                            
                            if lockIndicator then
                                lockIndicator.Enabled = false
                            end
                            return
                        end
                        
                        if Settings.SmoothLockEnabled then
                            SmoothLookAt(currentTarget.Character.Head.Position)
                        else
                            Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Character.Head.Position)
                        end
                    end)
                end
            else
                wallCheckStartTime = 0
                
                if lockIndicator then
                    lockIndicator.Enabled = false
                end
            end
        end
    else
        wallCheckStartTime = 0
        
        if lockIndicator then
            lockIndicator.Enabled = false
        end
    end
end

-- ボットに視点を固定する関数
local function LockToBot()
    if not BotSettings.LockEnabled then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local currentTime = tick()
    if currentTime - botLastLockTime < BotSettings.CooldownTime then return end
    if isBotLocking then return end
    
    local bot, distance, hasWall = GetBestBot()
    
    if bot then
        if not BotSettings.WallCheckEnabled then
            isBotLocking = true
            currentBotTarget = bot
            botLastLockTime = currentTime
            botLockStartTime = currentTime
            
            if botLockConnection then
                botLockConnection:Disconnect()
            end
            
            botLockConnection = RunService.RenderStepped:Connect(function()
                if not BotSettings.LockEnabled or not currentBotTarget or not currentBotTarget:FindFirstChild("Head") then
                    botLockConnection:Disconnect()
                    isBotLocking = false
                    currentBotTarget = nil
                    return
                end
                
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    if not IsWithinBotDistance(LocalPlayer.Character.HumanoidRootPart.Position, currentBotTarget.HumanoidRootPart.Position) then
                        botLockConnection:Disconnect()
                        isBotLocking = false
                        currentBotTarget = nil
                        return
                    end
                end
                
                if tick() - botLockStartTime >= BotSettings.LockDuration then
                    botLockConnection:Disconnect()
                    isBotLocking = false
                    currentBotTarget = nil
                    return
                end
                
                if BotSettings.SmoothLockEnabled then
                    SmoothLookAtBot(currentBotTarget.Head.Position)
                else
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentBotTarget.Head.Position)
                end
            end)
        else
            if not hasWall then
                if botWallCheckStartTime == 0 then
                    botWallCheckStartTime = currentTime
                end
                
                if currentTime - botWallCheckStartTime >= BotSettings.WallCheckDelay then
                    isBotLocking = true
                    currentBotTarget = bot
                    botLastLockTime = currentTime
                    botWallCheckStartTime = 0
                    botLockStartTime = currentTime
                    
                    if botLockConnection then
                        botLockConnection:Disconnect()
                    end
                    
                    botLockConnection = RunService.RenderStepped:Connect(function()
                        if not BotSettings.LockEnabled or not currentBotTarget or not currentBotTarget:FindFirstChild("Head") then
                            botLockConnection:Disconnect()
                            isBotLocking = false
                            currentBotTarget = nil
                            return
                        end
                        
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            if not IsWithinBotDistance(LocalPlayer.Character.HumanoidRootPart.Position, currentBotTarget.HumanoidRootPart.Position) then
                                botLockConnection:Disconnect()
                                isBotLocking = false
                                currentBotTarget = nil
                                return
                            end
                            
                            if BotSettings.WallCheckEnabled then
                                local wallCheck = CheckWallBetweenBot(LocalPlayer.Character.HumanoidRootPart.Position, currentBotTarget.Head.Position)
                                if wallCheck then
                                    botLockConnection:Disconnect()
                                    isBotLocking = false
                                    currentBotTarget = nil
                                    return
                                end
                            end
                        end
                        
                        if tick() - botLockStartTime >= BotSettings.LockDuration then
                            botLockConnection:Disconnect()
                            isBotLocking = false
                            currentBotTarget = nil
                            return
                        end
                        
                        if BotSettings.SmoothLockEnabled then
                            SmoothLookAtBot(currentBotTarget.Head.Position)
                        else
                            Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentBotTarget.Head.Position)
                        end
                    end)
                end
            else
                botWallCheckStartTime = 0
            end
        end
    else
        botWallCheckStartTime = 0
    end
end

-- Name ESPを作成する関数
local function CreateNameESP(player)
    if not player.Character or not player.Character:FindFirstChild("Head") then return end
    
    local nameTag = Drawing.new("Text")
    nameTag.Visible = false
    nameTag.Center = true
    nameTag.Outline = true
    nameTag.Font = 2
    nameTag.Size = 16
    nameTag.Color = Color3.new(1, 1, 1)
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not Settings.NameESPEnabled then
            nameTag.Visible = false
            return
        end
        
        if player.Character and player.Character:FindFirstChild("Head") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local pos, onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position + Vector3.new(0, 1, 0))
                if onScreen then
                    nameTag.Position = Vector2.new(pos.X, pos.Y)
                    nameTag.Text = player.Name
                    nameTag.Visible = true
                else
                    nameTag.Visible = false
                end
            else
                nameTag.Visible = false
            end
        else
            nameTag.Visible = false
        end
    end)
    
    nameESPConnections[player] = {nameTag = nameTag, connection = connection}
end

-- Health ESPを作成する関数
local function CreateHealthESP(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local healthBar = Drawing.new("Line")
    local healthText = Drawing.new("Text")
    
    healthBar.Visible = false
    healthBar.Color = Color3.new(0, 1, 0)
    healthBar.Thickness = 2
    
    healthText.Visible = false
    healthText.Center = true
    healthText.Outline = true
    healthText.Font = 2
    healthText.Size = 14
    healthText.Color = Color3.new(1, 1, 1)
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not Settings.HealthESPEnabled then
            healthBar.Visible = false
            healthText.Visible = false
            return
        end
        
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local pos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position + Vector3.new(0, 2, 0))
                if onScreen then
                    local healthPercent = humanoid.Health / humanoid.MaxHealth
                    local barLength = 50
                    local filledLength = barLength * healthPercent
                    
                    healthBar.From = Vector2.new(pos.X - barLength/2, pos.Y + 20)
                    healthBar.To = Vector2.new(pos.X - barLength/2 + filledLength, pos.Y + 20)
                    
                    if healthPercent > 0.5 then
                        healthBar.Color = Color3.new(0, 1, 0)
                    elseif healthPercent > 0.25 then
                        healthBar.Color = Color3.new(1, 1, 0)
                    else
                        healthBar.Color = Color3.new(1, 0, 0)
                    end
                    
                    healthText.Position = Vector2.new(pos.X, pos.Y + 25)
                    healthText.Text = math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
                    
                    healthBar.Visible = true
                    healthText.Visible = true
                else
                    healthBar.Visible = false
                    healthText.Visible = false
                end
            else
                healthBar.Visible = false
                healthText.Visible = false
            end
        else
            healthBar.Visible = false
            healthText.Visible = false
        end
    end)
    
    healthESPConnections[player] = {healthBar = healthBar, healthText = healthText, connection = connection}
end

-- Box ESPを作成する関数
local function CreateBoxESP(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.new(0, 1, 0)
    box.Thickness = 1
    box.Filled = false
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not Settings.BoxESPEnabled then
            box.Visible = false
            return
        end
        
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local rootPos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
                local headPos = Camera:WorldToViewportPoint(player.Character.Head.Position)
                
                if onScreen then
                    local height = math.abs(headPos.Y - rootPos.Y) * 1.5
                    local width = height * 0.6
                    
                    box.Size = Vector2.new(width, height)
                    box.Position = Vector2.new(rootPos.X - width/2, rootPos.Y - height/2)
                    box.Visible = true
                else
                    box.Visible = false
                end
            else
                box.Visible = false
            end
        else
            box.Visible = false
        end
    end)
    
    boxESPConnections[player] = {box = box, connection = connection}
end

-- Traceを作成する関数
local function CreateTrace(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local trace = Drawing.new("Line")
    trace.Visible = false
    trace.Color = Settings.TraceColor
    trace.Thickness = Settings.TraceThickness
    trace.Transparency = Settings.TraceTransparency
    
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not Settings.TraceEnabled then
            trace.Visible = false
            return
        end
        
        trace.Thickness = Settings.TraceThickness
        trace.Color = Settings.TraceColor
        trace.Transparency = Settings.TraceTransparency
        
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local pos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
            if onScreen then
                trace.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                trace.To = Vector2.new(pos.X, pos.Y)
                trace.Visible = true
            else
                trace.Visible = false
            end
        else
            trace.Visible = false
        end
    end)
    
    traceConnections[player] = {trace = trace, connection = connection}
end

-- ESPを更新する関数
local function UpdateESP()
    for player, data in pairs(nameESPConnections) do
        data.connection:Disconnect()
        data.nameTag:Remove()
    end
    nameESPConnections = {}
    
    for player, data in pairs(healthESPConnections) do
        data.connection:Disconnect()
        data.healthBar:Remove()
        data.healthText:Remove()
    end
    healthESPConnections = {}
    
    for player, data in pairs(boxESPConnections) do
        data.connection:Disconnect()
        data.box:Remove()
    end
    boxESPConnections = {}
    
    for player, data in pairs(traceConnections) do
        data.connection:Disconnect()
        data.trace:Remove()
    end
    traceConnections = {}
    
    for _, name in ipairs(Settings.ESPPlayers) do
        if name ~= "" then
            local player = Players:FindFirstChild(name)
            if player and player ~= LocalPlayer then
                CreateNameESP(player)
                CreateHealthESP(player)
                CreateBoxESP(player)
                CreateTrace(player)
            end
        end
    end
end

-- プレイヤー追加時の処理
Players.PlayerAdded:Connect(function(player)
    task.wait(1)
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
    if traceConnections[player] then
        traceConnections[player].connection:Disconnect()
        traceConnections[player].trace:Remove()
        traceConnections[player] = nil
    end
    if nameESPConnections[player] then
        nameESPConnections[player].connection:Disconnect()
        nameESPConnections[player].nameTag:Remove()
        nameESPConnections[player] = nil
    end
    if healthESPConnections[player] then
        healthESPConnections[player].connection:Disconnect()
        healthESPConnections[player].healthBar:Remove()
        healthESPConnections[player].healthText:Remove()
        healthESPConnections[player] = nil
    end
    if boxESPConnections[player] then
        boxESPConnections[player].connection:Disconnect()
        boxESPConnections[player].box:Remove()
        boxESPConnections[player] = nil
    end
    if playerDropdown then
        playerDropdown:Refresh(UpdatePlayerList(), true)
    end
end)

-- リセット関数
local function ResetLock()
    if lockConnection then
        lockConnection:Disconnect()
    end
    isLocking = false
    currentTarget = nil
    wallCheckStartTime = 0
    lastLockTime = 0
    
    if lockIndicator then
        lockIndicator.Enabled = false
    end
end

-- ボットロックリセット関数
local function ResetBotLock()
    if botLockConnection then
        botLockConnection:Disconnect()
    end
    isBotLocking = false
    currentBotTarget = nil
    botWallCheckStartTime = 0
    botLastLockTime = 0
end

-- ログリセット関数
local function ResetLogs()
    targetHistory = {}
end

-- 複数ターゲットの入力を更新
local function UpdateMultiTarget()
    Settings.TargetPlayers = {}
    for i = 1, 25 do
        local input = multiTargetInputs[i]
        if input and input.Text ~= "" then
            table.insert(Settings.TargetPlayers, input.Text)
        end
    end
end

-- 複数ESPの入力を更新
local function UpdateMultiESP()
    Settings.ESPPlayers = {}
    for i = 1, 25 do
        local input = multiESPInputs[i]
        if input and input.Text ~= "" then
            table.insert(Settings.ESPPlayers, input.Text)
        end
    end
    UpdateESP()
end

-- メインタブの機能
local LockToggle = MainTab:CreateToggle({
    Name = "🔐 head Rock",
    CurrentValue = false,
    Flag = "HeadLockToggle",
    Callback = function(Value)
        Settings.LockEnabled = Value
        if not Value then
            ResetLock()
        end
    end,
})

MainTab:CreateButton({
    Name = "🔄 Rock Reset",
    Callback = function()
        ResetLock()
    end,
})

MainTab:CreateSection("🎯 ターゲット設定")

-- ドロップダウンでプレイヤー選択（改善版）
playerDropdown = MainTab:CreateDropdown({
    Name = "ターゲットプレイヤー選択",
    Options = UpdatePlayerList(),
    CurrentOption = {"なし"},
    Flag = "PlayerSelect",
    Callback = function(Option)
        local selectedOption = Option
        if type(Option) == "table" then
            selectedOption = Option[1]
        end
        
        if selectedOption == "なし" then
            SelectedPlayer = nil
        elseif selectedOption == "リセット" then
            SelectedPlayer = nil
            playerDropdown:Set("なし")
        elseif selectedOption == "最寄りのプレイヤー" then
            FindNearestPlayer()
        else
            SelectedPlayer = selectedOption
        end
        UpdateSelectedLabel()
    end,
})

-- 選択中のプレイヤー表示ラベル
selectedLabel = MainTab:CreateLabel("選択中: なし")

MainTab:CreateInput({
    Name = "プレイヤーIDで指定",
    PlaceholderText = "ユーザーIDを入力",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local userId = tonumber(Text)
        if userId then
            Settings.TargetPlayerID = userId
            Settings.TargetPlayer = nil
        end
    end,
})

MainTab:CreateSection("🎥 ESP System")

local NameESPToggle = MainTab:CreateToggle({
    Name = "㈴ Name ESP",
    CurrentValue = false,
    Flag = "NameESPToggle",
    Callback = function(Value)
        Settings.NameESPEnabled = Value
        UpdateESP()
    end,
})

local HealthESPToggle = MainTab:CreateToggle({
    Name = "💚 Health ESP",
    CurrentValue = false,
    Flag = "HealthESPToggle",
    Callback = function(Value)
        Settings.HealthESPEnabled = Value
        UpdateESP()
    end,
})

local BoxESPToggle = MainTab:CreateToggle({
    Name = "🎁 Box ESP",
    CurrentValue = false,
    Flag = "BoxESPToggle",
    Callback = function(Value)
        Settings.BoxESPEnabled = Value
        UpdateESP()
    end,
})

local TraceToggle = MainTab:CreateToggle({
    Name = "一 Trace ESP",
    CurrentValue = false,
    Flag = "TraceToggle",
    Callback = function(Value)
        Settings.TraceEnabled = Value
        UpdateESP()
    end,
})

-- サブメインタブ（ボット用）
local BotLockToggle = BotTab:CreateToggle({
    Name = "🤖 ボットヘッドロック",
    CurrentValue = false,
    Flag = "BotHeadLockToggle",
    Callback = function(Value)
        BotSettings.LockEnabled = Value
        if not Value then
            ResetBotLock()
        end
    end,
})

BotTab:CreateButton({
    Name = "🔄 ボットロックリセット",
    Callback = function()
        ResetBotLock()
    end,
})

BotTab:CreateSection("🤖 ボット設定")

local BotWallCheckToggle = BotTab:CreateToggle({
    Name = "🧱 壁判定",
    CurrentValue = true,
    Flag = "BotWallCheckToggle",
    Callback = function(Value)
        BotSettings.WallCheckEnabled = Value
    end,
})

local BotSmoothLockToggle = BotTab:CreateToggle({
    Name = "🌀 スムーズロック",
    CurrentValue = false,
    Flag = "BotSmoothLockToggle",
    Callback = function(Value)
        BotSettings.SmoothLockEnabled = Value
    end,
})

BotTab:CreateDropdown({
    Name = "ターゲット優先度",
    Options = {"最近", "低HP", "ランダム"},
    CurrentOption = {"最近"},
    MultipleOptions = false,
    Flag = "BotLockPriorityDropdown",
    Callback = function(Option)
        if Option[1] == "最近" then
            BotSettings.LockPriority = "Closest"
        elseif Option[1] == "低HP" then
            BotSettings.LockPriority = "LowestHealth"
        elseif Option[1] == "ランダム" then
            BotSettings.LockPriority = "Random"
        end
    end,
})

-- 複数選択タブ (ヘッドロックターゲット用)
MultiSelectTab:CreateSection("複数ターゲットプレイヤー (最大25人)")

local multiTargetInputs = {}
for i = 1, 25 do
    multiTargetInputs[i] = MultiSelectTab:CreateInput({
        Name = "ターゲットプレイヤー " .. i,
        PlaceholderText = "プレイヤー名を入力",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            UpdateMultiTarget()
        end,
    })
end

MultiSelectTab:CreateButton({
    Name = "🔄 複数ターゲット更新",
    Callback = function()
        UpdateMultiTarget()
    end,
})

-- 複数選択ESP項目タブ (ESP対象用)
MultiESPSelectTab:CreateSection("複数ESPプレイヤー (最大25人)")

local multiESPInputs = {}
for i = 1, 25 do
    multiESPInputs[i] = MultiESPSelectTab:CreateInput({
        Name = "ESPプレイヤー " .. i,
        PlaceholderText = "プレイヤー名を入力",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            UpdateMultiESP()
        end,
    })
end

MultiESPSelectTab:CreateButton({
    Name = "🔄 複数ESP更新",
    Callback = function()
        UpdateMultiESP()
    end,
})

-- 設定タブ
SettingsTab:CreateSection("📏 ロック距離設定（プレイヤー用）")

local LockDistanceSlider = SettingsTab:CreateSlider({
    Name = "360°全方位距離（スタッド）",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceSlider",
    Callback = function(Value)
        Settings.LockDistance = Value
    end,
})

SettingsTab:CreateSection("📏 ロック距離設定（ボット用）")

local BotDistanceSlider = SettingsTab:CreateSlider({
    Name = "ボット360°全方位距離（スタッド）",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 5,
    Flag = "BotDistanceSlider",
    Callback = function(Value)
        BotSettings.LockDistance = Value
    end,
})

SettingsTab:CreateSection("⏱️ ロックタイミング設定（プレイヤー用）")

local WallCheckToggle = SettingsTab:CreateToggle({
    Name = "🧱 壁判定",
    CurrentValue = true,
    Flag = "WallCheckToggle",
    Callback = function(Value)
        Settings.WallCheckEnabled = Value
    end,
})

local LockDurationSlider = SettingsTab:CreateSlider({
    Name = "ロック持続時間（秒）",
    Range = {0.1, 10},
    Increment = 0.1,
    CurrentValue = 0.5,
    Flag = "LockDurationSlider",
    Callback = function(Value)
        Settings.LockDuration = Value
    end,
})

local CooldownSlider = SettingsTab:CreateSlider({
    Name = "クールダウン時間（秒）",
    Range = {0.1, 10},
    Increment = 0.1,
    CurrentValue = 1,
    Flag = "CooldownSlider",
    Callback = function(Value)
        Settings.CooldownTime = Value
    end,
})

SettingsTab:CreateSection("⏱️ ロックタイミング設定（ボット用）")

local BotLockDurationSlider = SettingsTab:CreateSlider({
    Name = "ボットロック持続時間（秒）",
    Range = {0.1, 10},
    Increment = 0.1,
    CurrentValue = 0.5,
    Flag = "BotLockDurationSlider",
    Callback = function(Value)
        BotSettings.LockDuration = Value
    end,
})

local BotCooldownSlider = SettingsTab:CreateSlider({
    Name = "ボットクールダウン時間（秒）",
    Range = {0.1, 10},
    Increment = 0.1,
    CurrentValue = 1,
    Flag = "BotCooldownSlider",
    Callback = function(Value)
        BotSettings.CooldownTime = Value
    end,
})

SettingsTab:CreateSection("🎮 高度な設定（プレイヤー用）")

local SmoothLockToggle = SettingsTab:CreateToggle({
    Name = "🌀 スムーズロック",
    CurrentValue = false,
    Flag = "SmoothLockToggle",
    Callback = function(Value)
        Settings.SmoothLockEnabled = Value
    end,
})

local SmoothLockSpeedSlider = SettingsTab:CreateSlider({
    Name = "スムーズ速度",
    Range = {0.01, 1},
    Increment = 0.01,
    CurrentValue = 0.1,
    Flag = "SmoothLockSpeedSlider",
    Callback = function(Value)
        Settings.SmoothLockSpeed = Value
    end,
})

local LockPriorityDropdown = SettingsTab:CreateDropdown({
    Name = "ターゲット優先度",
    Options = {"最近", "低HP", "ランダム"},
    CurrentOption = {"最近"},
    MultipleOptions = false,
    Flag = "LockPriorityDropdown",
    Callback = function(Option)
        if Option[1] == "最近" then
            Settings.LockPriority = "Closest"
        elseif Option[1] == "低HP" then
            Settings.LockPriority = "LowestHealth"
        elseif Option[1] == "ランダム" then
            Settings.LockPriority = "Random"
        end
    end,
})

SettingsTab:CreateSection("🎮 高度な設定（ボット用）")

local BotSmoothLockSpeedSlider = SettingsTab:CreateSlider({
    Name = "ボットスムーズ速度",
    Range = {0.01, 1},
    Increment = 0.01,
    CurrentValue = 0.1,
    Flag = "BotSmoothLockSpeedSlider",
    Callback = function(Value)
        BotSettings.SmoothLockSpeed = Value
    end,
})

SettingsTab:CreateSection("🔧 トレース設定")

local TraceThicknessSlider = SettingsTab:CreateSlider({
    Name = "トレースの太さ",
    Range = {1, 150},
    Increment = 1,
    CurrentValue = 1,
    Flag = "TraceThicknessSlider",
    Callback = function(Value)
        Settings.TraceThickness = Value
    end,
})

local TraceTransparencySlider = SettingsTab:CreateSlider({
    Name = "トレースの透明度",
    Range = {0, 1},
    Increment = 0.01,
    CurrentValue = 0.1,
    Flag = "TraceTransparencySlider",
    Callback = function(Value)
        Settings.TraceTransparency = Value
    end,
})

SettingsTab:CreateColorPicker({
    Name = "トレースの色",
    Color = Settings.TraceColor,
    Flag = "TraceColorPicker",
    Callback = function(Value)
        Settings.TraceColor = Value
    end
})

local LockIndicatorToggle = SettingsTab:CreateToggle({
    Name = "ロックインジケーター",
    CurrentValue = true,
    Flag = "LockIndicatorToggle",
    Callback = function(Value)
        Settings.ShowLockIndicator = Value
        if Value and not lockIndicator then
            CreateLockIndicator()
        end
    end,
})

local ResetOnDeathToggle = SettingsTab:CreateToggle({
    Name = "死亡時リセット",
    CurrentValue = true,
    Flag = "ResetOnDeathToggle",
    Callback = function(Value)
        Settings.ResetOnDeath = Value
    end,
})

-- 情報タブ
InfoTab:CreateSection("📊 システム情報")

InfoTab:CreateButton({
    Name = "🔄 ログリセット",
    Callback = function()
        ResetLogs()
    end,
})

local currentTargetLabel = InfoTab:CreateLabel("現在のターゲット: " .. (currentTarget and currentTarget.Name or "なし"))
local lockStatusLabel = InfoTab:CreateLabel("ロック状態: " .. (isLocking and "🔒 ロック中" or "🔓 未ロック"))
local wallCheckLabel = InfoTab:CreateLabel("壁判定: " .. (Settings.WallCheckEnabled and "有効" or "無効"))
local botTargetLabel = InfoTab:CreateLabel("現在のボットターゲット: " .. (currentBotTarget and currentBotTarget.Name or "なし"))
local botLockStatusLabel = InfoTab:CreateLabel("ボットロック状態: " .. (isBotLocking and "🔒 ロック中" or "🔓 未ロック"))

InfoTab:CreateSection("📈 ターゲット履歴")
local historyLabel = InfoTab:CreateLabel("履歴は最大10件保存されます")

InfoTab:CreateButton({
    Name = "履歴を更新",
    Callback = function()
        local historyText = "ターゲット履歴:\n"
        if #targetHistory > 0 then
            for i, entry in ipairs(targetHistory) do
                historyText = historyText .. string.format("%d. %s - %s (%s秒)\n",
                    i, entry.player, entry.time, entry.duration)
            end
        else
            historyText = historyText .. "履歴はありません"
        end
        historyLabel:SetText(historyText)
        
        currentTargetLabel:SetText("現在のターゲット: " .. (currentTarget and currentTarget.Name or "なし"))
        lockStatusLabel:SetText("ロック状態: " .. (isLocking and "🔒 ロック中" or "🔓 未ロック"))
        wallCheckLabel:SetText("壁判定: " .. (Settings.WallCheckEnabled and "有効" or "無効"))
        botTargetLabel:SetText("現在のボットターゲット: " .. (currentBotTarget and currentBotTarget.Name or "なし"))
        botLockStatusLabel:SetText("ボットロック状態: " .. (isBotLocking and "🔒 ロック中" or "🔓 未ロック"))
    end,
})

InfoTab:CreateSection("ℹ️ 使い方")
InfoTab:CreateParagraph({
    Title = "基本操作",
    Content = "1. メインタブでヘッドロックを有効化\n2. 設定タブで各種パラメータを調整\n3. 特定のプレイヤーをターゲットにする場合はドロップダウンから選択\n4. リセットボタンでロック状態をクリア"
})

InfoTab:CreateParagraph({
    Title = "壁判定機能",
    Content = "有効時: 壁がない場合のみロック\n無効時: 壁を無視して即座にロック（強力モード）"
})

InfoTab:CreateParagraph({
    Title = "ESP機能",
    Content = "Name ESP: プレイヤー名を表示\nHealth ESP: HPバーと数値を表示\nBox ESP: プレイヤー周囲にボックスを表示\nTrace ESP: プレイヤーへの線（太さ・色・透明度調整可能）"
})

InfoTab:CreateParagraph({
    Title = "ボット機能",
    Content = "サブメインタブでボットヘッドロックを有効化\nボットはワークスペース内のHumanoidを持つモデルを対象\nプレイヤーキャラクターは除外されます"
})

-- プレイヤーリストを更新
task.spawn(function()
    while task.wait(2) do
        local currentList = UpdatePlayerList()
        if playerDropdown then
            playerDropdown:Refresh(currentList, true)
        end
    end
end)

-- メインループ（プレイヤー）
RunService.RenderStepped:Connect(function()
    LockToHead()
end)

-- メインループ（ボット）
RunService.RenderStepped:Connect(function()
    LockToBot()
end)

-- キーバインド設定（オプション）
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.RightControl then
        Settings.LockEnabled = not Settings.LockEnabled
    end
    
    if input.KeyCode == Enum.KeyCode.RightShift then
        ResetLock()
    end
    
    if input.KeyCode == Enum.KeyCode.Insert then
        BotSettings.LockEnabled = not BotSettings.LockEnabled
    end
end)

-- 初期化
task.spawn(function()
    task.wait(2)
    CreateLockIndicator()
    UpdateESP()
end)

Rayfield:LoadConfiguration()

-- 終了時のクリーンアップ
game:GetService("CoreGui").ChildRemoved:Connect(function(child)
    if child.Name == "Rayfield" then
        if lockConnection then
            lockConnection:Disconnect()
        end
        
        if botLockConnection then
            botLockConnection:Disconnect()
        end
        
        for _, connectionData in pairs(traceConnections) do
            connectionData.connection:Disconnect()
            connectionData.trace:Remove()
        end
        
        for _, connectionData in pairs(nameESPConnections) do
            connectionData.connection:Disconnect()
            connectionData.nameTag:Remove()
        end
        
        for _, connectionData in pairs(healthESPConnections) do
            connectionData.connection:Disconnect()
            connectionData.healthBar:Remove()
            connectionData.healthText:Remove()
        end
        
        for _, connectionData in pairs(boxESPConnections) do
            connectionData.connection:Disconnect()
            connectionData.box:Remove()
        end
        
        if lockIndicator then
            lockIndicator:Destroy()
        end
    end
end)
