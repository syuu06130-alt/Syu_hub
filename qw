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
    LockDistance = 5, -- 作動距離（スタッド）
    LockDistanceLeft = 5, -- 左方向の距離
    LockDistanceRight = 5, -- 右方向の距離
    LockDistanceFront = 5, -- 前方向の距離
    LockDistanceBack = 5, -- 後方向の距離
    LockDuration = 0.5, -- 固定時間（秒）
    CooldownTime = 1, -- 再作動までの時間（秒）
    TraceEnabled = false,
    TraceThickness = 1, -- Traceの太さ
    TraceColor = Color3.fromRGB(255, 50, 50), -- 赤色
    NameESPEnabled = false,
    HealthESPEnabled = false,
    BoxESPEnabled = false,
    TargetPlayer = nil, -- 固定する特定のプレイヤー
    TargetPlayerID = nil, -- プレイヤーIDで指定
    TargetPlayers = {}, -- 複数ターゲットプレイヤー
    ESPPlayers = {}, -- 複数ESP対象プレイヤー
    WallCheckEnabled = true, -- 壁判定の有効/無効
    WallCheckDelay = 0, -- 壁判定の遅延（秒）
    SmoothLockEnabled = false, -- スムーズロック
    SmoothLockSpeed = 0.1, -- スムーズロック速度
    NotificationEnabled = true, -- 通知
    AutoUpdateTarget = true, -- ターゲット自動更新
    ShowLockIndicator = true, -- ロックインジケーター表示
    LockSoundEnabled = true, -- ロック音
    UnlockSoundEnabled = true, -- アンロック音
    ResetOnDeath = true, -- 死亡時リセット
    LockPriority = "Closest" -- "Closest", "LowestHealth", "Random"
}
-- 状態管理
local isLocking = false
local lastLockTime = 0
local lockConnection = nil
local traceConnections = {}
local nameESPConnections = {}
local healthESPConnections = {}
local boxESPConnections = {}
local currentTarget = nil
local playerDropdown = nil
local multiTargetDropdown = nil
local multiESPDropdown = nil
local wallCheckStartTime = 0
local wallCheckPassed = false
local lockStartTime = 0
local targetHistory = {}
local lockIndicator = nil
-- 音声設定
local lockSound = Instance.new("Sound")
lockSound.SoundId = "rbxassetid://9128736210" -- ロック音
lockSound.Volume = 0.5
lockSound.Parent = workspace
local unlockSound = Instance.new("Sound")
unlockSound.SoundId = "rbxassetid://9128736804" -- アンロック音
unlockSound.Volume = 0.5
unlockSound.Parent = workspace
-- Rayfield ウィンドウの作成
local Window = Rayfield:CreateWindow({
    Name = "Syu_uhub",
    LoadingTitle = "Syu_uhub ロード中",
    LoadingSubtitle = "by Syu - 強力ヘッドロックシステム",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SyuHub",
        FileName = "SyuHubConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink", -- Discord招待リンク
        RememberJoins = true
    }
})
-- メインタブ
local MainTab = Window:CreateTab("メイン", 4483362458)
-- 設定タブ
local SettingsTab = Window:CreateTab("設定", 4483345998)
-- 複数選択タブ (ヘッドロックターゲット用)
local MultiSelectTab = Window:CreateTab("複数選択", 4483345998)
-- 複数選択ESP項目タブ (ESP対象用)
local MultiESPSelectTab = Window:CreateTab("複数選択ESP項目", 4483345998)
-- 情報タブ
local InfoTab = Window:CreateTab("情報", 4483345998)
-- 通知関数
local function Notify(title, message, duration)
    if Settings.NotificationEnabled then
        Rayfield:Notify({
            Title = title,
            Content = message,
            Duration = duration or 3,
            Image = 4483362458,
            Actions = {
                Ignore = {
                    Name = "OK"
                }
            }
        })
    end
end
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
-- プレイヤーリストを取得する関数
local function GetPlayerList()
    local playerList = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerList, player.Name)
        end
    end
    return playerList
end

-- プレイヤー名リストを取得する関数（ドロップダウン用）
local function GetPlayerNames()
    local names = {}
    table.insert(names, "なし") -- 最初に「なし」オプションを追加
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    return names
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
        return false -- 壁判定無効なら常に壁なし
    end
   
    local direction = (endPos - startPos).Unit
    local distance = (endPos - startPos).Magnitude
   
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.IgnoreWater = true
   
    local raycastResult = workspace:Raycast(startPos, direction * distance, raycastParams)
   
    if raycastResult then
        -- 敵のキャラクターに当たった場合は壁なしとみなす
        local hitModel = raycastResult.Instance
        while hitModel and hitModel ~= workspace do
            local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
            if hitPlayer and hitPlayer ~= LocalPlayer then
                return false
            end
            hitModel = hitModel.Parent
        end
        return true -- 壁あり
    end
   
    return false -- 壁なし
end
-- 方向による距離チェック関数
local function IsWithinDirectionalDistance(localPos, enemyPos, localLook)
    local offset = enemyPos - localPos
    local distance = offset.Magnitude
   
    -- 全体の距離チェック
    if distance > Settings.LockDistance then
        return false
    end
   
    -- 方向ベクトル
    local right = localLook:Cross(Vector3.new(0, 1, 0)).Unit
    local forward = localLook
   
    -- 各方向の距離を計算
    local rightDist = math.abs(offset:Dot(right))
    local forwardDist = offset:Dot(forward)
   
    -- 左右チェック
    if offset:Dot(right) > 0 then -- 右側
        if rightDist > Settings.LockDistanceRight then return false end
    else -- 左側
        if rightDist > Settings.LockDistanceLeft then return false end
    end
   
    -- 前後チェック
    if forwardDist > 0 then -- 前方
        if forwardDist > Settings.LockDistanceFront then return false end
    else -- 後方
        if math.abs(forwardDist) > Settings.LockDistanceBack then return false end
    end
   
    return true
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
-- ターゲットの優先度を計算
local function CalculateTargetPriority(player, distance)
    if Settings.LockPriority == "LowestHealth" then
        local health, maxHealth = GetPlayerHealth(player)
        return health / maxHealth -- 健康率が低いほど優先度高
    elseif Settings.LockPriority == "Random" then
        return math.random()
    else -- "Closest"
        return 1 / (distance + 1) -- 距離が近いほど優先度高
    end
end
-- 最も適切な敵を取得する関数
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
                local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                if IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, targetPlayer.Character.HumanoidRootPart.Position, lookVector) then
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
   
    -- 特定のプレイヤー名が設定されている場合
    if Settings.TargetPlayer and Settings.TargetPlayer ~= "なし" then
        local targetPlayer = Players:FindFirstChild(Settings.TargetPlayer)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and targetPlayer.Character:FindFirstChild("Head") then
            local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
                local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                if IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, targetPlayer.Character.HumanoidRootPart.Position, lookVector) then
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
            local player = Players:FindFirstChild(name)
            if player then
                table.insert(candidates, player)
            end
        end
    else
        candidates = Players:GetPlayers()
    end
   
    -- 自動で最適な敵を探す
    for _, player in pairs(candidates) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Head") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                if IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, player.Character.HumanoidRootPart.Position, lookVector) then
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
-- 頭に視点を固定する関数
local function LockToHead()
    if not Settings.LockEnabled then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
   
    -- 死亡時リセット
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
   
    if enemy and distance <= Settings.LockDistance then
        -- ロックインジケーター更新
        if Settings.ShowLockIndicator and lockIndicator and enemy.Character and enemy.Character:FindFirstChild("Head") then
            lockIndicator.Adornee = enemy.Character.Head
            lockIndicator.Enabled = true
        end
       
        -- 壁判定が無効の場合は即ロック
        if not Settings.WallCheckEnabled then
            isLocking = true
            currentTarget = enemy
            lastLockTime = currentTime
            lockStartTime = currentTime
           
            -- ロック音
            if Settings.LockSoundEnabled then
                lockSound:Play()
            end
           
            -- 通知
            Notify("🔒 ロック成功", enemy.Name .. " をロックしました", 2)
           
            -- ターゲット履歴に追加
            table.insert(targetHistory, 1, {
                player = enemy,
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
                   
                    -- ロックインジケーター無効化
                    if lockIndicator then
                        lockIndicator.Enabled = false
                    end
                    return
                end
               
                -- 設定距離以上離れたら自動解除
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local currentDistance = (LocalPlayer.Character.HumanoidRootPart.Position - currentTarget.Character.HumanoidRootPart.Position).Magnitude
                    local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                    if currentDistance > Settings.LockDistance or not IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, currentTarget.Character.HumanoidRootPart.Position, lookVector) then
                        lockConnection:Disconnect()
                        isLocking = false
                        currentTarget = nil
                       
                        -- アンロック音
                        if Settings.UnlockSoundEnabled then
                            unlockSound:Play()
                        end
                       
                        -- ロックインジケーター無効化
                        if lockIndicator then
                            lockIndicator.Enabled = false
                        end
                        return
                    end
                end
               
                -- 固定時間経過で解除
                if tick() - lockStartTime >= Settings.LockDuration then
                    lockConnection:Disconnect()
                    isLocking = false
                    currentTarget = nil
                   
                    -- アンロック音
                    if Settings.UnlockSoundEnabled then
                        unlockSound:Play()
                    end
                   
                    -- ロックインジケーター無効化
                    if lockIndicator then
                        lockIndicator.Enabled = false
                    end
                    return
                end
               
                -- カメラをターゲットに向ける
                if Settings.SmoothLockEnabled then
                    SmoothLookAt(currentTarget.Character.Head.Position)
                else
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Character.Head.Position)
                end
            end)
        else
            -- 壁判定が有効の場合は遅延処理
            if not hasWall then
                -- 壁なしの場合、遅延時間経過後にロック
                if wallCheckStartTime == 0 then
                    wallCheckStartTime = currentTime
                end
               
                if currentTime - wallCheckStartTime >= Settings.WallCheckDelay then
                    isLocking = true
                    currentTarget = enemy
                    lastLockTime = currentTime
                    wallCheckStartTime = 0
                    lockStartTime = currentTime
                   
                    -- ロック音
                    if Settings.LockSoundEnabled then
                        lockSound:Play()
                    end
                   
                    -- 通知
                    Notify("🔒 ロック成功", enemy.Name .. " をロックしました", 2)
                   
                    -- ターゲット履歴に追加
                    table.insert(targetHistory, 1, {
                        player = enemy,
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
                           
                            -- ロックインジケーター無効化
                            if lockIndicator then
                                lockIndicator.Enabled = false
                            end
                            return
                        end
                       
                        -- 設定距離以上離れたら自動解除
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            local currentDistance = (LocalPlayer.Character.HumanoidRootPart.Position - currentTarget.Character.HumanoidRootPart.Position).Magnitude
                            local lookVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
                            if currentDistance > Settings.LockDistance or not IsWithinDirectionalDistance(LocalPlayer.Character.HumanoidRootPart.Position, currentTarget.Character.HumanoidRootPart.Position, lookVector) then
                                lockConnection:Disconnect()
                                isLocking = false
                                currentTarget = nil
                               
                                -- アンロック音
                                if Settings.UnlockSoundEnabled then
                                    unlockSound:Play()
                                end
                               
                                -- ロックインジケーター無効化
                                if lockIndicator then
                                    lockIndicator.Enabled = false
                                end
                                return
                            end
                           
                            -- ロック中に壁ができた場合は解除
                            if Settings.WallCheckEnabled then
                                local wallCheck = CheckWallBetween(LocalPlayer.Character.HumanoidRootPart.Position, currentTarget.Character.Head.Position)
                                if wallCheck then
                                    lockConnection:Disconnect()
                                    isLocking = false
                                    currentTarget = nil
                                   
                                    -- アンロック音
                                    if Settings.UnlockSoundEnabled then
                                        unlockSound:Play()
                                    end
                                   
                                    -- 通知
                                    Notify("🚫 壁検出", "壁が検出されたためロック解除", 2)
                                   
                                    -- ロックインジケーター無効化
                                    if lockIndicator then
                                        lockIndicator.Enabled = false
                                    end
                                    return
                                end
                            end
                        end
                       
                        -- 固定時間経過で解除
                        if tick() - lockStartTime >= Settings.LockDuration then
                            lockConnection:Disconnect()
                            isLocking = false
                            currentTarget = nil
                           
                            -- アンロック音
                            if Settings.UnlockSoundEnabled then
                                unlockSound:Play()
                            end
                           
                            -- ロックインジケーター無効化
                            if lockIndicator then
                                lockIndicator.Enabled = false
                            end
                            return
                        end
                       
                        -- カメラをターゲットに向ける
                        if Settings.SmoothLockEnabled then
                            SmoothLookAt(currentTarget.Character.Head.Position)
                        else
                            Camera.CFrame = CFrame.new(Camera.CFrame.Position, currentTarget.Character.Head.Position)
                        end
                    end)
                end
            else
                -- 壁がある場合はタイマーリセット
                wallCheckStartTime = 0
               
                -- ロックインジケーター無効化
                if lockIndicator then
                    lockIndicator.Enabled = false
                end
            end
        end
    else
        wallCheckStartTime = 0
       
        -- ロックインジケーター無効化
        if lockIndicator then
            lockIndicator.Enabled = false
        end
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
-- Traceを作成する関数（超薄い赤色）
local function CreateTrace(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
   
    local trace = Drawing.new("Line")
    trace.Visible = false
    trace.Color = Settings.TraceColor
    trace.Thickness = Settings.TraceThickness
    trace.Transparency = 0.1 -- 超薄い
   
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not Settings.TraceEnabled then
            trace.Visible = false
            return
        end
       
        trace.Thickness = Settings.TraceThickness
        trace.Color = Settings.TraceColor
       
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
-- ESPを更新する関数（選択されたプレイヤーのみに適用）
local function UpdateESP()
    -- 既存のESPをすべて削除
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
    
    -- 選択されたESPプレイヤーにのみESPを作成
    for _, name in ipairs(Settings.ESPPlayers) do
        local player = Players:FindFirstChild(name)
        if player and player ~= LocalPlayer then
            CreateNameESP(player)
            CreateHealthESP(player)
            CreateBoxESP(player)
            CreateTrace(player)
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
        playerDropdown:Refresh(GetPlayerNames())
    end
    if multiTargetDropdown then
        multiTargetDropdown:Refresh(GetPlayerList(), true)
    end
    if multiESPDropdown then
        multiESPDropdown:Refresh(GetPlayerList(), true)
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
        playerDropdown:Refresh(GetPlayerNames())
    end
    if multiTargetDropdown then
        multiTargetDropdown:Refresh(GetPlayerList(), true)
    end
    if multiESPDropdown then
        multiESPDropdown:Refresh(GetPlayerList(), true)
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
   
    Notify("🔄 リセット", "ロックシステムをリセットしました", 2)
end
-- メインタブの機能
local LockToggle = MainTab:CreateToggle({
    Name = "🔒 ヘッドロック メイン",
    CurrentValue = false,
    Flag = "HeadLockToggle",
    Callback = function(Value)
        Settings.LockEnabled = Value
        if Value then
            Notify("✅ 有効化", "ヘッドロックシステムが有効になりました", 2)
        else
            Notify("❌ 無効化", "ヘッドロックシステムが無効になりました", 2)
            ResetLock()
        end
    end,
})
MainTab:CreateButton({
    Name = "🔄 ロックリセット",
    Callback = function()
        ResetLock()
    end,
})

-- ========== ターゲット選択機能（新しく追加）==========
MainTab:CreateSection("🎯 ターゲット設定")

-- ドロップダウン（前方宣言して更新可能にする）
playerDropdown = MainTab:CreateDropdown({
   Name = "ターゲットプレイヤー選択",
   Options = GetPlayerNames(),
   CurrentOption = {"なし"}, -- 初期選択は「なし」
   MultipleOptions = false,
   Flag = "TargetPlayerDropdown", 
   Callback = function(Option)
       -- Rayfieldは選択されたオプションをテーブル{"Name"}で返す
       local selectedPlayer = Option[1]
       if selectedPlayer == "なし" then
           Settings.TargetPlayer = nil
           Settings.TargetPlayerID = nil
           Notify("🎯 ターゲット解除", "全プレイヤーを対象にします", 2)
       else
           Settings.TargetPlayer = selectedPlayer
           Settings.TargetPlayerID = nil
           Notify("🎯 ターゲット設定", selectedPlayer .. " をターゲットに設定しました", 3)
       end
   end,
})

MainTab:CreateButton({
   Name = "プレイヤーリスト更新",
   Callback = function()
       -- ドロップダウンの中身を現在のプレイヤーリストで更新
       playerDropdown:Refresh(GetPlayerNames())
       Notify("🔄 更新", "プレイヤーリストを更新しました", 2)
   end,
})

MainTab:CreateInput({
    Name = "プレイヤーIDで指定",
    PlaceholderText = "ユーザーIDを入力",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local userId = tonumber(Text)
        if userId then
            Settings.TargetPlayerID = userId
            Settings.TargetPlayer = nil
            Notify("🎯 ID設定", "ユーザーID: " .. userId .. " をターゲットに設定", 3)
        else
            Notify("⚠️ エラー", "有効なユーザーIDを入力してください", 3)
        end
    end,
})
-- ========== ターゲット選択機能ここまで ==========

MainTab:CreateSection("👁️ ESPシステム")
local NameESPToggle = MainTab:CreateToggle({
    Name = "ネームESP",
    CurrentValue = false,
    Flag = "NameESPToggle",
    Callback = function(Value)
        Settings.NameESPEnabled = Value
        UpdateESP()
    end,
})
local HealthESPToggle = MainTab:CreateToggle({
    Name = "ヘルスESP",
    CurrentValue = false,
    Flag = "HealthESPToggle",
    Callback = function(Value)
        Settings.HealthESPEnabled = Value
        UpdateESP()
    end,
})
local BoxESPToggle = MainTab:CreateToggle({
    Name = "ボックスESP",
    CurrentValue = false,
    Flag = "BoxESPToggle",
    Callback = function(Value)
        Settings.BoxESPEnabled = Value
        UpdateESP()
    end,
})
local TraceToggle = MainTab:CreateToggle({
    Name = "🔴 トレース（超薄赤線）",
    CurrentValue = false,
    Flag = "TraceToggle",
    Callback = function(Value)
        Settings.TraceEnabled = Value
        UpdateESP()
    end,
})
-- 複数選択タブ (ヘッドロックターゲット用)
MultiSelectTab:CreateSection("複数ターゲット選択 (最大25人)")
multiTargetDropdown = MultiSelectTab:CreateDropdown({
    Name = "複数ターゲットプレイヤー",
    Options = GetPlayerList(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "MultiTargetDropdown",
    Callback = function(Options)
        if #Options > 25 then
            Notify("⚠️ 制限超過", "最大25人までです。超過分は無視されます。", 3)
            Settings.TargetPlayers = {unpack(Options, 1, 25)}
        else
            Settings.TargetPlayers = Options
        end
        Notify("🎯 複数ターゲット設定", "選択数: " .. #Settings.TargetPlayers, 3)
    end,
})
-- 複数選択ESP項目タブ (ESP対象用)
MultiESPSelectTab:CreateSection("複数ESP対象選択 (最大25人)")
multiESPDropdown = MultiESPSelectTab:CreateDropdown({
    Name = "複数ESPプレイヤー",
    Options = GetPlayerList(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "MultiESPDropdown",
    Callback = function(Options)
        if #Options > 25 then
            Notify("⚠️ 制限超過", "最大25人までです。超過分は無視されます。", 3)
            Settings.ESPPlayers = {unpack(Options, 1, 25)}
        else
            Settings.ESPPlayers = Options
        end
        Notify("👁️ 複数ESP設定", "選択数: " .. #Settings.ESPPlayers, 3)
        UpdateESP()
    end,
})
-- 設定タブ
SettingsTab:CreateSection("📏 ロック距離設定")
local LockDistanceSlider = SettingsTab:CreateSlider({
    Name = "全体距離（スタッド）",
    Range = {1, 100},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceSlider",
    Callback = function(Value)
        Settings.LockDistance = Value
    end,
})
local LockDistanceFrontSlider = SettingsTab:CreateSlider({
    Name = "前方距離（スタッド）",
    Range = {1, 50},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceFrontSlider",
    Callback = function(Value)
        Settings.LockDistanceFront = Value
    end,
})
local LockDistanceBackSlider = SettingsTab:CreateSlider({
    Name = "後方距離（スタッド）",
    Range = {1, 50},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceBackSlider",
    Callback = function(Value)
        Settings.LockDistanceBack = Value
    end,
})
local LockDistanceLeftSlider = SettingsTab:CreateSlider({
    Name = "左方向距離（スタッド）",
    Range = {1, 50},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceLeftSlider",
    Callback = function(Value)
        Settings.LockDistanceLeft = Value
    end,
})
local LockDistanceRightSlider = SettingsTab:CreateSlider({
    Name = "右方向距離（スタッド）",
    Range = {1, 50},
    Increment = 1,
    CurrentValue = 5,
    Flag = "LockDistanceRightSlider",
    Callback = function(Value)
        Settings.LockDistanceRight = Value
    end,
})
SettingsTab:CreateSection("⏱️ ロックタイミング設定")
local WallCheckToggle = SettingsTab:CreateToggle({
    Name = "🧱 壁判定",
    CurrentValue = true,
    Flag = "WallCheckToggle",
    Callback = function(Value)
        Settings.WallCheckEnabled = Value
        if not Value then
            Notify("💪 強力モード", "壁判定無効 - 壁越しロック可能", 3)
        end
    end,
})
local WallCheckDelaySlider = SettingsTab:CreateSlider({
    Name = "壁判定遅延（秒）",
    Range = {0, 5},
    Increment = 0.1,
    CurrentValue = 0,
    Flag = "WallCheckDelaySlider",
    Callback = function(Value)
        Settings.WallCheckDelay = Value
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
SettingsTab:CreateSection("🎮 高度な設定")
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
SettingsTab:CreateSection("🔧 トレース設定")
local TraceThicknessSlider = SettingsTab:CreateSlider({
    Name = "トレースの太さ",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = 1,
    Flag = "TraceThicknessSlider",
    Callback = function(Value)
        Settings.TraceThickness = Value
    end,
})
SettingsTab:CreateSection("🔔 通知設定")
local NotificationToggle = SettingsTab:CreateToggle({
    Name = "通知表示",
    CurrentValue = true,
    Flag = "NotificationToggle",
    Callback = function(Value)
        Settings.NotificationEnabled = Value
    end,
})
local LockSoundToggle = SettingsTab:CreateToggle({
    Name = "ロック音",
    CurrentValue = true,
    Flag = "LockSoundToggle",
    Callback = function(Value)
        Settings.LockSoundEnabled = Value
    end,
})
local UnlockSoundToggle = SettingsTab:CreateToggle({
    Name = "アンロック音",
    CurrentValue = true,
    Flag = "UnlockSoundToggle",
    Callback = function(Value)
        Settings.UnlockSoundEnabled = Value
    end,
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
InfoTab:CreateLabel("現在のターゲット: " .. (currentTarget and currentTarget.Name or "なし"))
InfoTab:CreateLabel("ロック状態: " .. (isLocking and "🔒 ロック中" or "🔓 未ロック"))
InfoTab:CreateLabel("壁判定: " .. (Settings.WallCheckEnabled and "有効" or "無効"))
InfoTab:CreateSection("📈 ターゲット履歴")
local historyLabel = InfoTab:CreateLabel("履歴は最大10件保存されます")
InfoTab:CreateButton({
    Name = "履歴を更新",
    Callback = function()
        local historyText = "ターゲット履歴:\n"
        if #targetHistory > 0 then
            for i, entry in ipairs(targetHistory) do
                historyText = historyText .. string.format("%d. %s - %s (%s秒)\n",
                    i, entry.player.Name, entry.time, entry.duration)
            end
        else
            historyText = historyText .. "履歴はありません"
        end
        historyLabel:SetText(historyText)
    end,
})
InfoTab:CreateSection("ℹ️ 使い方")
InfoTab:CreateParagraph({
    Title = "基本操作",
    Content = "1. メインタブでヘッドロックを有効化\n2. 設定タブで各種パラメータを調整\n3. 特定のプレイヤーをターゲットにする場合はドロップダウンから選択\n4. リセットボタンでロック状態をクリア"
})
InfoTab:CreateParagraph({
    Title = "壁判定機能",
    Content = "有効時: 壁がない場合のみロック\n無効時: 壁を無視して即座にロック（強力モード）\n遅延設定: 壁がない状態が設定秒数続いた後にロック"
})
InfoTab:CreateParagraph({
    Title = "ESP機能",
    Content = "ネームESP: プレイヤー名を表示\nヘルスESP: HPバーと数値を表示\nボックスESP: プレイヤー周囲にボックスを表示\nトレース: プレイヤーへの超薄い赤線"
})
-- プレイヤーリストを更新
task.spawn(function()
    while task.wait(2) do
        local currentList = GetPlayerList()
        if playerDropdown then
            playerDropdown:Refresh(GetPlayerNames())
        end
        if multiTargetDropdown then
            multiTargetDropdown:Refresh(currentList, true)
        end
        if multiESPDropdown then
            multiESPDropdown:Refresh(currentList, true)
        end
    end
end)
-- メインループ
RunService.RenderStepped:Connect(function()
    LockToHead()
end)
-- キーバインド設定（オプション）
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
   
    if input.KeyCode == Enum.KeyCode.RightControl then
        Settings.LockEnabled = not Settings.LockEnabled
        Notify("キーバインド", "ヘッドロック: " .. (Settings.LockEnabled and "有効" or "無効"), 2)
    end
   
    if input.KeyCode == Enum.KeyCode.RightShift then
        ResetLock()
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
        -- すべての接続を切断
        if lockConnection then
            lockConnection:Disconnect()
        end
       
        -- すべてのDrawingオブジェクトを削除
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
       
        -- ロックインジケーターを削除
        if lockIndicator then
            lockIndicator:Destroy()
        end
    end
end)
