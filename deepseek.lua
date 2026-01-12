-- Roblox Headlock Script with ESP
-- 注意: このスクリプトは教育目的です

-- Rayfield UIの読み込み
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- サービス取得
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- 設定テーブル
local Settings = {
    LockEnabled = false,
    LockDistance = 50,
    LockDistanceFront = 50,
    LockDistanceBack = 25,
    LockDistanceLeft = 30,
    LockDistanceRight = 30,
    LockDuration = 0.5,
    CooldownTime = 1,
    WallCheckEnabled = true,
    WallCheckDelay = 0,
    SmoothLockEnabled = false,
    SmoothLockSpeed = 0.1,
    LockPriority = "Closest",
    TraceEnabled = false,
    NameESPEnabled = false,
    HealthESPEnabled = false,
    BoxESPEnabled = false,
    ShowLockIndicator = true,
    LockSoundEnabled = true,
    TargetPlayer = nil,
    LockSoundId = "rbxassetid://9046650628",
    TraceThickness = 1,
    LockIndicatorColor = Color3.fromRGB(255, 0, 0),
    MaxTargetHistory = 10
}

-- 変数
local Target = nil
local Locking = false
local LastLockTime = 0
local WallCheckTimer = 0
local TargetHistory = {}
local ESPDrawings = {}
local LockIndicator = nil
local TraceDrawing = nil
local Connections = {}

-- サウンド作成関数
local function createSound(id)
    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.Volume = 0.5
    sound.Parent = Workspace
    return sound
end

-- 距離計算関数
local function getDistance(pos1, pos2)
    return (pos1 - pos2).Magnitude
end

-- 壁判定関数
local function wallCheck(from, to)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local raycastResult = Workspace:Raycast(from, (to - from), raycastParams)
    
    if raycastResult then
        local hitPart = raycastResult.Instance
        local hitHumanoid = hitPart.Parent:FindFirstChildOfClass("Humanoid") or
                           hitPart.Parent.Parent:FindFirstChildOfClass("Humanoid")
        
        if hitHumanoid and hitHumanoid.Parent:IsA("Model") then
            local hitPlayer = Players:GetPlayerFromCharacter(hitHumanoid.Parent)
            if hitPlayer and hitPlayer ~= LocalPlayer then
                return true, hitPlayer
            end
        end
        return false, nil
    end
    return true, nil
end

-- 方向別距離チェック
local function checkDirectionDistance(characterPos, targetPos)
    local cameraCFrame = Camera.CFrame
    local cameraLookVector = cameraCFrame.LookVector
    local toTargetVector = (targetPos - characterPos).Unit
    
    local dotProduct = cameraLookVector:Dot(toTargetVector)
    local distance = getDistance(characterPos, targetPos)
    
    -- 前方向
    if dotProduct > 0.7 then
        return distance <= Settings.LockDistanceFront
    -- 後方向
    elseif dotProduct < -0.7 then
        return distance <= Settings.LockDistanceBack
    -- 右方向
    elseif cameraLookVector:Cross(toTargetVector).Y < -0.5 then
        return distance <= Settings.LockDistanceRight
    -- 左方向
    else
        return distance <= Settings.LockDistanceLeft
    end
end

-- ターゲット選択関数
local function selectTarget()
    if Settings.TargetPlayer then
        local player = Players:FindFirstChild(Settings.TargetPlayer)
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            return player
        end
    end
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local rootPart = character.HumanoidRootPart
    local bestTarget = nil
    local bestScore = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetCharacter = player.Character
            local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
            local head = targetCharacter:FindFirstChild("Head")
            local root = targetCharacter:FindFirstChild("HumanoidRootPart")
            
            if humanoid and humanoid.Health > 0 and head and root then
                -- 方向別距離チェック
                if not checkDirectionDistance(rootPart.Position, root.Position) then
                    continue
                end
                
                -- 壁チェック
                if Settings.WallCheckEnabled then
                    local canSee = wallCheck(rootPart.Position, head.Position)
                    if not canSee then
                        continue
                    end
                end
                
                local score
                if Settings.LockPriority == "Closest" then
                    score = getDistance(rootPart.Position, root.Position)
                elseif Settings.LockPriority == "LowestHealth" then
                    score = humanoid.Health
                else -- Random
                    score = math.random(1, 1000)
                end
                
                if score < bestScore then
                    bestScore = score
                    bestTarget = player
                end
            end
        end
    end
    
    return bestTarget
end

-- ロック実行関数
local function executeLock()
    if not Target or not Target.Character then
        Locking = false
        return
    end
    
    local character = Target.Character
    local head = character:FindFirstChild("Head")
    if not head then return end
    
    -- スムーズロック
    if Settings.SmoothLockEnabled then
        local goal = CFrame.new(Camera.CFrame.Position, head.Position)
        local tweenInfo = TweenInfo.new(Settings.SmoothLockSpeed, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(Camera, tweenInfo, {CFrame = goal})
        tween:Play()
    else
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
    end
    
    -- ロックインジケーター
    if Settings.ShowLockIndicator and not LockIndicator then
        LockIndicator = Instance.new("BillboardGui")
        LockIndicator.Name = "LockIndicator"
        LockIndicator.Size = UDim2.new(2, 0, 2, 0)
        LockIndicator.AlwaysOnTop = true
        LockIndicator.Adornee = head
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Settings.LockIndicatorColor
        frame.BackgroundTransparency = 0.3
        frame.BorderSizePixel = 0
        
        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(1, 0)
        UICorner.Parent = frame
        
        frame.Parent = LockIndicator
        LockIndicator.Parent = head
    end
    
    -- トレース描画
    if Settings.TraceEnabled and not TraceDrawing then
        TraceDrawing = Drawing.new("Line")
        TraceDrawing.Thickness = Settings.TraceThickness
        TraceDrawing.Color = Color3.fromRGB(255, 0, 0)
        TraceDrawing.Transparency = 0.3
    end
    
    if Settings.TraceEnabled and TraceDrawing then
        local character = LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local rootPos = character.HumanoidRootPart.Position
            local headPos = head.Position
            
            local rootScreenPos, rootVisible = Camera:WorldToViewportPoint(rootPos)
            local headScreenPos, headVisible = Camera:WorldToViewportPoint(headPos)
            
            if rootVisible and headVisible then
                TraceDrawing.From = Vector2.new(rootScreenPos.X, rootScreenPos.Y)
                TraceDrawing.To = Vector2.new(headScreenPos.X, headScreenPos.Y)
                TraceDrawing.Visible = true
            else
                TraceDrawing.Visible = false
            end
        end
    end
    
    -- ロック音
    if Settings.LockSoundEnabled and tick() - LastLockTime > Settings.CooldownTime then
        local sound = createSound(Settings.LockSoundId)
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 2)
        LastLockTime = tick()
    end
end

-- ESP描画関数
local function updateESP()
    for _, drawing in pairs(ESPDrawings) do
        if drawing then
            drawing:Remove()
        end
    end
    ESPDrawings = {}
    
    if not Settings.NameESPEnabled and not Settings.HealthESPEnabled and not Settings.BoxESPEnabled then
        return
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local character = player.Character
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local head = character:FindFirstChild("Head")
            local root = character:FindFirstChild("HumanoidRootPart")
            
            if humanoid and humanoid.Health > 0 and head and root then
                local headPos, headVisible = Camera:WorldToViewportPoint(head.Position)
                
                if headVisible then
                    -- 名前ESP
                    if Settings.NameESPEnabled then
                        local nameText = Drawing.new("Text")
                        nameText.Text = player.Name
                        nameText.Color = Color3.fromRGB(255, 255, 255)
                        nameText.Size = 16
                        nameText.Outline = true
                        nameText.OutlineColor = Color3.fromRGB(0, 0, 0)
                        nameText.Position = Vector2.new(headPos.X, headPos.Y - 40)
                        nameText.Visible = true
                        table.insert(ESPDrawings, nameText)
                    end
                    
                    -- HPバーESP
                    if Settings.HealthESPEnabled then
                        local healthPercentage = humanoid.Health / humanoid.MaxHealth
                        local healthColor
                        
                        if healthPercentage > 0.6 then
                            healthColor = Color3.fromRGB(0, 255, 0)
                        elseif healthPercentage > 0.3 then
                            healthColor = Color3.fromRGB(255, 255, 0)
                        else
                            healthColor = Color3.fromRGB(255, 0, 0)
                        end
                        
                        -- HPバー
                        local hpBarOutline = Drawing.new("Square")
                        hpBarOutline.Size = Vector2.new(50, 8)
                        hpBarOutline.Position = Vector2.new(headPos.X - 25, headPos.Y - 30)
                        hpBarOutline.Color = Color3.fromRGB(0, 0, 0)
                        hpBarOutline.Thickness = 2
                        hpBarOutline.Filled = false
                        hpBarOutline.Visible = true
                        
                        local hpBar = Drawing.new("Square")
                        hpBar.Size = Vector2.new(48 * healthPercentage, 6)
                        hpBar.Position = Vector2.new(headPos.X - 24, headPos.Y - 29)
                        hpBar.Color = healthColor
                        hpBar.Thickness = 1
                        hpBar.Filled = true
                        hpBar.Visible = true
                        
                        -- HP数値
                        local hpText = Drawing.new("Text")
                        hpText.Text = math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
                        hpText.Color = Color3.fromRGB(255, 255, 255)
                        hpText.Size = 14
                        hpText.Outline = true
                        hpText.Position = Vector2.new(headPos.X - 25, headPos.Y - 42)
                        hpText.Visible = true
                        
                        table.insert(ESPDrawings, hpBarOutline)
                        table.insert(ESPDrawings, hpBar)
                        table.insert(ESPDrawings, hpText)
                    end
                    
                    -- ボックスESP
                    if Settings.BoxESPEnabled then
                        local rootPos = root.Position
                        local rootScreenPos = Camera:WorldToViewportPoint(rootPos)
                        
                        if rootScreenPos.Z > 0 then
                            local boxHeight = 80
                            local boxWidth = 40
                            
                            local box = Drawing.new("Square")
                            box.Size = Vector2.new(boxWidth, boxHeight)
                            box.Position = Vector2.new(rootScreenPos.X - boxWidth/2, rootScreenPos.Y - boxHeight/2)
                            box.Color = Color3.fromRGB(0, 255, 0)
                            box.Thickness = 2
                            box.Filled = false
                            box.Visible = true
                            
                            table.insert(ESPDrawings, box)
                        end
                    end
                end
            end
        end
    end
end

-- ターゲット履歴追加
local function addToHistory(player, duration)
    table.insert(TargetHistory, 1, {
        Player = player.Name,
        Time = os.date("%H:%M:%S"),
        Duration = duration
    })
    
    if #TargetHistory > Settings.MaxTargetHistory then
        table.remove(TargetHistory, #TargetHistory)
    end
end

-- メインループ
local lockStartTime = 0
RunService.RenderStepped:Connect(function(deltaTime)
    -- ESP更新
    if Settings.NameESPEnabled or Settings.HealthESPEnabled or Settings.BoxESPEnabled then
        updateESP()
    end
    
    -- ヘッドロック
    if Settings.LockEnabled then
        if not Locking then
            Target = selectTarget()
            if Target then
                Locking = true
                lockStartTime = tick()
                
                -- ターゲット履歴に追加
                addToHistory(Target, Settings.LockDuration)
            end
        elseif Target then
            -- ロック時間チェック
            if tick() - lockStartTime >= Settings.LockDuration then
                Locking = false
                Target = nil
                
                -- ロックインジケーター削除
                if LockIndicator then
                    LockIndicator:Destroy()
                    LockIndicator = nil
                end
                
                -- トレース削除
                if TraceDrawing then
                    TraceDrawing.Visible = false
                    TraceDrawing:Remove()
                    TraceDrawing = nil
                end
            else
                executeLock()
            end
        end
    elseif Locking then
        Locking = false
        Target = nil
        
        if LockIndicator then
            LockIndicator:Destroy()
            LockIndicator = nil
        end
        
        if TraceDrawing then
            TraceDrawing.Visible = false
            TraceDrawing:Remove()
            TraceDrawing = nil
        end
    end
end)

-- 死亡時リセット
local function resetOnDeath()
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Died:Connect(function()
                Settings.LockEnabled = false
                Locking = false
                Target = nil
                
                if LockIndicator then
                    LockIndicator:Destroy()
                    LockIndicator = nil
                end
                
                if TraceDrawing then
                    TraceDrawing:Remove()
                    TraceDrawing = nil
                end
            end)
        end
    end
end

-- プレイヤー追加時の処理
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        if player == LocalPlayer then
            resetOnDeath()
        end
    end)
end)

-- プレイヤー退出時の処理
Players.PlayerRemoving:Connect(function(player)
    if player == Target then
        Locking = false
        Target = nil
    end
end)

-- Rayfield UI作成
local Window = Rayfield:CreateWindow({
    Name = "Headlock Script v2.0",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by Script Developer",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "HeadlockConfig",
        FileName = "Settings.json"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false,
    KeySettings = {
        Title = "Key System",
        Subtitle = "Enter Key",
        Note = "No Key Required",
        FileName = "Key",
        SaveKey = false,
        GrabKeyFromSite = false,
        Key = {"Key1", "Key2"}
    }
})

-- メインタブ
local MainTab = Window:CreateTab("Main", 4483362458)

-- ヘッドロックON/OFF
MainTab:CreateToggle({
    Name = "Headlock",
    CurrentValue = Settings.LockEnabled,
    Flag = "LockToggle",
    Callback = function(value)
        Settings.LockEnabled = value
    end
})

-- リセットボタン
MainTab:CreateButton({
    Name = "Reset Lock",
    Callback = function()
        Settings.LockEnabled = false
        Locking = false
        Target = nil
        if LockIndicator then
            LockIndicator:Destroy()
            LockIndicator = nil
        end
        if TraceDrawing then
            TraceDrawing:Remove()
            TraceDrawing = nil
        end
        Rayfield:Notify({
            Title = "Lock Reset",
            Content = "Headlock has been reset",
            Duration = 2,
            Image = 4483362458
        })
    end
})

-- ターゲット選択ドロップダウン
local playerList = {}
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        table.insert(playerList, player.Name)
    end
end

MainTab:CreateDropdown({
    Name = "Select Target",
    Options = playerList,
    CurrentOption = "",
    Flag = "TargetDropdown",
    Callback = function(value)
        if value == "" then
            Settings.TargetPlayer = nil
        else
            Settings.TargetPlayer = value
        end
    end
})

-- ユーザーID入力
MainTab:CreateInput({
    Name = "Target by UserID",
    PlaceholderText = "Enter UserID",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local player = Players:GetPlayerByUserId(tonumber(text))
        if player then
            Settings.TargetPlayer = player.Name
        end
    end
})

-- ESP設定
MainTab:CreateToggle({
    Name = "Name ESP",
    CurrentValue = Settings.NameESPEnabled,
    Flag = "NameESP",
    Callback = function(value)
        Settings.NameESPEnabled = value
    end
})

MainTab:CreateToggle({
    Name = "Health ESP",
    CurrentValue = Settings.HealthESPEnabled,
    Flag = "HealthESP",
    Callback = function(value)
        Settings.HealthESPEnabled = value
    end
})

MainTab:CreateToggle({
    Name = "Box ESP",
    CurrentValue = Settings.BoxESPEnabled,
    Flag = "BoxESP",
    Callback = function(value)
        Settings.BoxESPEnabled = value
    end
})

-- 設定タブ
local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- 距離設定
SettingsTab:CreateSlider({
    Name = "Lock Distance",
    Range = {1, 100},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = Settings.LockDistance,
    Flag = "DistanceSlider",
    Callback = function(value)
        Settings.LockDistance = value
        Settings.LockDistanceFront = value
        Settings.LockDistanceBack = value
        Settings.LockDistanceLeft = value
        Settings.LockDistanceRight = value
    end
})

SettingsTab:CreateSlider({
    Name = "Front Distance",
    Range = {1, 100},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = Settings.LockDistanceFront,
    Flag = "FrontDistance",
    Callback = function(value)
        Settings.LockDistanceFront = value
    end
})

SettingsTab:CreateSlider({
    Name = "Back Distance",
    Range = {1, 100},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = Settings.LockDistanceBack,
    Flag = "BackDistance",
    Callback = function(value)
        Settings.LockDistanceBack = value
    end
})

SettingsTab:CreateSlider({
    Name = "Left Distance",
    Range = {1, 100},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = Settings.LockDistanceLeft,
    Flag = "LeftDistance",
    Callback = function(value)
        Settings.LockDistanceLeft = value
    end
})

SettingsTab:CreateSlider({
    Name = "Right Distance",
    Range = {1, 100},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = Settings.LockDistanceRight,
    Flag = "RightDistance",
    Callback = function(value)
        Settings.LockDistanceRight = value
    end
})

-- 時間設定
SettingsTab:CreateSlider({
    Name = "Lock Duration",
    Range = {0.1, 5},
    Increment = 0.1,
    Suffix = "seconds",
    CurrentValue = Settings.LockDuration,
    Flag = "DurationSlider",
    Callback = function(value)
        Settings.LockDuration = value
    end
})

SettingsTab:CreateSlider({
    Name = "Cooldown Time",
    Range = {0.1, 5},
    Increment = 0.1,
    Suffix = "seconds",
    CurrentValue = Settings.CooldownTime,
    Flag = "CooldownSlider",
    Callback = function(value)
        Settings.CooldownTime = value
    end
})

-- 壁判定設定
SettingsTab:CreateToggle({
    Name = "Wall Check",
    CurrentValue = Settings.WallCheckEnabled,
    Flag = "WallCheck",
    Callback = function(value)
        Settings.WallCheckEnabled = value
    end
})

SettingsTab:CreateSlider({
    Name = "Wall Check Delay",
    Range = {0, 3},
    Increment = 0.1,
    Suffix = "seconds",
    CurrentValue = Settings.WallCheckDelay,
    Flag = "WallDelay",
    Callback = function(value)
        Settings.WallCheckDelay = value
    end
})

-- スムーズロック設定
SettingsTab:CreateToggle({
    Name = "Smooth Lock",
    CurrentValue = Settings.SmoothLockEnabled,
    Flag = "SmoothLock",
    Callback = function(value)
        Settings.SmoothLockEnabled = value
    end
})

SettingsTab:CreateSlider({
    Name = "Smooth Speed",
    Range = {0.01, 0.5},
    Increment = 0.01,
    Suffix = "speed",
    CurrentValue = Settings.SmoothLockSpeed,
    Flag = "SmoothSpeed",
    Callback = function(value)
        Settings.SmoothLockSpeed = value
    end
})

-- 優先度設定
SettingsTab:CreateDropdown({
    Name = "Lock Priority",
    Options = {"Closest", "LowestHealth", "Random"},
    CurrentOption = Settings.LockPriority,
    Flag = "PriorityDropdown",
    Callback = function(value)
        Settings.LockPriority = value
    end
})

-- トレース設定
SettingsTab:CreateToggle({
    Name = "Trace Line",
    CurrentValue = Settings.TraceEnabled,
    Flag = "TraceToggle",
    Callback = function(value)
        Settings.TraceEnabled = value
    end
})

SettingsTab:CreateSlider({
    Name = "Trace Thickness",
    Range = {1, 5},
    Increment = 1,
    Suffix = "px",
    CurrentValue = Settings.TraceThickness,
    Flag = "TraceThickness",
    Callback = function(value)
        Settings.TraceThickness = value
    end
})

-- 音設定
SettingsTab:CreateToggle({
    Name = "Lock Sound",
    CurrentValue = Settings.LockSoundEnabled,
    Flag = "SoundToggle",
    Callback = function(value)
        Settings.LockSoundEnabled = value
    end
})

-- インジケーター設定
SettingsTab:CreateToggle({
    Name = "Lock Indicator",
    CurrentValue = Settings.ShowLockIndicator,
    Flag = "IndicatorToggle",
    Callback = function(value)
        Settings.ShowLockIndicator = value
    end
})

-- 情報タブ
local InfoTab = Window:CreateTab("Information", 4483362458)

-- 現在のターゲット表示
local targetLabel = InfoTab:CreateLabel("Current Target: None")
local statusLabel = InfoTab:CreateLabel("Lock Status: Inactive")

-- ターゲット履歴表示
InfoTab:CreateSection("Target History")
local historyText = InfoTab:CreateLabel("No targets yet")

-- 履歴更新関数
local function updateHistoryDisplay()
    if #TargetHistory == 0 then
        historyText:Set("No targets yet")
    else
        local text = ""
        for i, entry in ipairs(TargetHistory) do
            text = text .. string.format("%d. %s - %s (%ss)\n", i, entry.Player, entry.Time, entry.Duration)
        end
        historyText:Set(text)
    end
end

-- 使い方説明
InfoTab:CreateSection("How to Use")
InfoTab:CreateLabel("1. Enable Headlock in Main tab")
InfoTab:CreateLabel("2. Adjust settings in Settings tab")
InfoTab:CreateLabel("3. Select specific target if needed")
InfoTab:CreateLabel("4. ESP can be enabled separately")
InfoTab:CreateLabel("Keybinds:")
InfoTab:CreateLabel("  Right Ctrl - Toggle Lock")
InfoTab:CreateLabel("  Right Shift - Reset")

-- 情報更新ループ
spawn(function()
    while true do
        wait(0.5)
        
        -- ターゲット情報更新
        if Target then
            targetLabel:Set("Current Target: " .. Target.Name)
            statusLabel:Set("Lock Status: " .. (Locking and "Active" or "Inactive"))
        else
            targetLabel:Set("Current Target: None")
            statusLabel:Set("Lock Status: Inactive")
        end
        
        -- 履歴表示更新
        updateHistoryDisplay()
    end
end)

-- キーバインド
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.RightControl then
        Settings.LockEnabled = not Settings.LockEnabled
        Rayfield:Notify({
            Title = "Headlock",
            Content = Settings.LockEnabled and "Enabled" or "Disabled",
            Duration = 1,
            Image = 4483362458
        })
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        Settings.LockEnabled = false
        Locking = false
        Target = nil
        if LockIndicator then
            LockIndicator:Destroy()
            LockIndicator = nil
        end
        if TraceDrawing then
            TraceDrawing:Remove()
            TraceDrawing = nil
        end
        Rayfield:Notify({
            Title = "Reset",
            Content = "Lock has been reset",
            Duration = 1,
            Image = 4483362458
        })
    end
end)

-- 初期化
resetOnDeath()
Rayfield:Notify({
    Title = "Headlock Script",
    Content = "Successfully loaded!",
    Duration = 3,
    Image = 4483362458
})

-- クリーンアップ処理
Window:DestroyOnClose = true

local function cleanup()
    for _, drawing in pairs(ESPDrawings) do
        if drawing then
            drawing:Remove()
        end
    end
    
    if LockIndicator then
        LockIndicator:Destroy()
    end
    
    if TraceDrawing then
        TraceDrawing:Remove()
    end
    
    Settings.LockEnabled = false
    Locking = false
    Target = nil
end

-- スクリプト終了時のクリーンアップ
game:GetService("CoreGui").ChildRemoved:Connect(function(child)
    if child.Name == "Rayfield" then
        cleanup()
    end
end)
