local Players           = game:GetService("Players")
local Teams             = game:GetService("Teams")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local TeleportService   = game:GetService("TeleportService")
local LogService        = game:GetService("LogService")
local TextChatService   = game:GetService("TextChatService")
local LocalPlayer       = Players.LocalPlayer

local UI_PARENT = game.CoreGui
pcall(function()
    if typeof(gethui) == "function" then
        local h = gethui()
        if h then UI_PARENT = h end
    end
end)

pcall(function()
    local old = UI_PARENT:FindFirstChild("ExecutorUI")
    if old then old:Destroy() end
end)
pcall(function()
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        if c then
            local h = c:FindFirstChild("CustomESP"); if h then h:Destroy() end
            local b = c:FindFirstChild("CustomESPGui"); if b then b:Destroy() end
            local w = c:FindFirstChild("WantedLabel"); if w then w:Destroy() end
        end
    end
end)

local function loadJsonFile(path)
    local result = {}
    pcall(function()
        if typeof(readfile) == "function" then
            local ok, data = pcall(readfile, path)
            if ok and data and data ~= "" then
                local ok2, d = pcall(HttpService.JSONDecode, HttpService, data)
                if ok2 and type(d) == "table" then result = d end
            end
        end
    end)
    return result
end

local function saveJsonFile(path, data)
    pcall(function()
        if typeof(writefile) == "function" then
            writefile(path, HttpService:JSONEncode(data))
        end
    end)
end

local CustomScripts = loadJsonFile("custom_scripts.json")
local GameScripts   = loadJsonFile("games_scripts.json")
local Favorites     = loadJsonFile("favorites.json")
local ChatMessages  = loadJsonFile("chat_messages.json")
local Warrants      = loadJsonFile("warrants.json")
local Records       = loadJsonFile("records.json")

local function isFav(key) return Favorites[key] == true end
local function toggleFav(key)
    if Favorites[key] then Favorites[key] = nil else Favorites[key] = true end
    saveJsonFile("favorites.json", Favorites)
end

local function getTimestamp()
    local ok, result = pcall(function() return os.date("%d/%m %H:%M") end)
    if ok and result then return result end
    return "??/?? ??:??"
end

local warrantCounter = 0
for _, w in ipairs(Warrants) do
    if type(w) == "table" and type(w.id) == "number" and w.id > warrantCounter then
        warrantCounter = w.id
    end
end
local function newWarrantId()
    warrantCounter = warrantCounter + 1
    return warrantCounter
end

local recordCounter = 0
for _, r in ipairs(Records) do
    if type(r) == "table" and type(r.id) == "number" and r.id > recordCounter then
        recordCounter = r.id
    end
end
local function newRecordId()
    recordCounter = recordCounter + 1
    return recordCounter
end

local function addRecord(entry)
    entry.id = newRecordId()
    entry.timestamp = entry.timestamp or getTimestamp()
    table.insert(Records, entry)
    saveJsonFile("records.json", Records)
end

local function hasApprovedWarrant(playerName)
    for _, w in ipairs(Warrants) do
        if w.targetName == playerName and w.status == "approved" then
            return w
        end
    end
    return nil
end

local wantedLabels = {}

local ConsoleLogs = {}
local MAX_LOGS = 500
local consoleUIUpdater = nil

local function addConsoleLog(level, message)
    if not message or message == "" then return end
    table.insert(ConsoleLogs, { level = level, text = tostring(message) })
    if #ConsoleLogs > MAX_LOGS then table.remove(ConsoleLogs, 1) end
    if consoleUIUpdater then pcall(consoleUIUpdater) end
end

pcall(function()
    LogService.MessageOut:Connect(function(message, messageType)
        local level = "info"
        if messageType == Enum.MessageType.MessageWarning then level = "warn"
        elseif messageType == Enum.MessageType.MessageError then level = "error"
        elseif messageType == Enum.MessageType.MessageOutput then level = "print"
        elseif messageType == Enum.MessageType.MessageInfo then level = "info"
        end
        addConsoleLog(level, message)
    end)
end)

local ESP = {
    enabled = false, color = Color3.fromRGB(255, 50, 50),
    excludeTeam = false, teamColor = false,
    showStuds = false, showHealth = false,
    teamColors = {},
}
local espObjects = {}

local function removeESP(player)
    local d = espObjects[player]
    if not d then return end
    pcall(function() if d.highlight then d.highlight:Destroy() end end)
    pcall(function() if d.billboard then d.billboard:Destroy() end end)
    espObjects[player] = nil
end
local function clearAllESP()
    for p in pairs(espObjects) do removeESP(p) end
end

local function createESP(player)
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp      = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "CustomESP"
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
    highlight.Adornee = char
    highlight.Parent = char

    local bb = Instance.new("BillboardGui")
    bb.Name = "CustomESPGui"
    bb.Size = UDim2.new(0, 130, 0, 62)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = hrp
    bb.Parent = char

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = player.Name
    nameLabel.Parent = bb

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 0, 14)
    distLabel.Position = UDim2.new(0, 0, 0, 20)
    distLabel.BackgroundTransparency = 1
    distLabel.TextStrokeTransparency = 0
    distLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    distLabel.TextSize = 12
    distLabel.Font = Enum.Font.Gotham
    distLabel.Visible = false
    distLabel.Parent = bb

    local healthBg = Instance.new("Frame")
    healthBg.Size = UDim2.new(0.9, 0, 0, 8)
    healthBg.Position = UDim2.new(0.05, 0, 0, 38)
    healthBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    healthBg.BorderSizePixel = 0
    healthBg.Visible = false
    healthBg.Parent = bb
    Instance.new("UICorner", healthBg).CornerRadius = UDim.new(0, 3)

    local healthFill = Instance.new("Frame")
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBg
    Instance.new("UICorner", healthFill).CornerRadius = UDim.new(0, 3)

    espObjects[player] = {
        highlight = highlight, billboard = bb,
        nameLabel = nameLabel, distLabel = distLabel,
        healthBg = healthBg, healthFill = healthFill,
        character = char,
    }
end

local CharSettings = { walkSpeed = nil, jumpPower = nil }
local InfiniteJump = { enabled = false }
local Noclip       = { enabled = false }
local Freecam      = { enabled = false, speed = 50, saved = nil }
local Fullbright   = { saved = nil }

LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid", 5)
    task.wait(0.5)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if CharSettings.walkSpeed then hum.WalkSpeed = CharSettings.walkSpeed end
    if CharSettings.jumpPower then
        hum.UseJumpPower = true
        hum.JumpPower = CharSettings.jumpPower
    end
end)

UserInputService.JumpRequest:Connect(function()
    if not InfiniteJump.enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

RunService.Stepped:Connect(function()
    if not Noclip.enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end)

local freecamTouch, freecamLastPos, freecamMouseHeld = nil, nil, false

UserInputService.TouchStarted:Connect(function(input, gpe)
    if gpe or not Freecam.enabled then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    if input.Position.X > cam.ViewportSize.X * 0.5 then
        freecamTouch = input
        freecamLastPos = input.Position
    end
end)
UserInputService.TouchEnded:Connect(function(input)
    if input == freecamTouch then freecamTouch = nil end
end)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then freecamMouseHeld = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then freecamMouseHeld = false end
end)

local function sendChatMessage(message, channels)
    if not message or message == "" then return end
    if not channels or #channels == 0 then
        showToast("No channel selected", Color3.fromRGB(140, 50, 50), 2)
        return
    end

    local sent = 0
    local errors = {}

    for _, channelName in ipairs(channels) do
        if channelName == "Server" then
            local ok, err = pcall(function()
                local general = TextChatService:FindFirstChild("TextChannels")
                if general then general = general:FindFirstChild("RBXGeneral") end
                if general then general:SendAsync(message) else error("RBXGeneral channel not found") end
            end)
            if ok then sent = sent + 1 else table.insert(errors, "Server: " .. tostring(err)) end

        elseif channelName == "Global" then
            local ok, err = pcall(function()
                local channelsFolder = TextChatService:FindFirstChild("TextChannels")
                if not channelsFolder then error("TextChannels not found") end
                local globalChannel = nil
                for _, ch in ipairs(channelsFolder:GetChildren()) do
                    if ch:IsA("TextChannel") and (string.find(string.lower(ch.Name), "global") or string.find(string.lower(ch.Name), "cross")) then
                        globalChannel = ch; break
                    end
                end
                if globalChannel then globalChannel:SendAsync(message) else error("Global channel not found") end
            end)
            if ok then sent = sent + 1 else table.insert(errors, "Global: " .. tostring(err)) end

        elseif channelName == "Friends" then
            local ok, err = pcall(function()
                local channelsFolder = TextChatService:FindFirstChild("TextChannels")
                if not channelsFolder then error("TextChannels not found") end
                local friendChannel = nil
                for _, ch in ipairs(channelsFolder:GetChildren()) do
                    if ch:IsA("TextChannel") and (string.find(string.lower(ch.Name), "friend") or string.find(string.lower(ch.Name), "whisper")) then
                        friendChannel = ch; break
                    end
                end
                if friendChannel then friendChannel:SendAsync(message) else error("Friends channel not found") end
            end)
            if ok then sent = sent + 1 else table.insert(errors, "Friends: " .. tostring(err)) end
        end
    end

    if sent > 0 then
        showToast("Sent to " .. sent .. " channel(s)", Color3.fromRGB(60, 120, 60), 2)
    end
    for _, e in ipairs(errors) do warn("[Chat] " .. e) end
end

local buildOk, buildErr = pcall(function()

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ExecutorUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = UI_PARENT

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

local refreshPending
local refreshWanted
local refreshRecordsFor
local openReviewDialog

local ToastContainer = Instance.new("Frame")
ToastContainer.Size = UDim2.new(1, 0, 0, 150)
ToastContainer.Position = UDim2.new(0, 0, 1, -160)
ToastContainer.BackgroundTransparency = 1
ToastContainer.ZIndex = 200
ToastContainer.Parent = ScreenGui

local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 4)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = ToastContainer

local toastOrder = 0

local function showToast(text, color, duration)
    color = color or Color3.fromRGB(60, 60, 60)
    duration = duration or 2.5
    toastOrder = toastOrder + 1
    local myOrder = toastOrder

    task.spawn(function()
        local toast = Instance.new("Frame")
        toast.Size = UDim2.new(0, 280, 0, 34)
        toast.BackgroundColor3 = color
        toast.BackgroundTransparency = 1
        toast.BorderSizePixel = 0
        toast.LayoutOrder = -myOrder
        toast.ZIndex = 201
        toast.Parent = ToastContainer
        corner(toast, 6)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -20, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.TextSize = 14
        lbl.Font = Enum.Font.GothamBold
        lbl.TextTransparency = 1
        lbl.TextWrapped = true
        lbl.ZIndex = 202
        lbl.Parent = toast

        pcall(function()
            TweenService:Create(toast, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()
            TweenService:Create(lbl, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
        end)

        task.wait(duration)

        pcall(function()
            TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(lbl, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
        end)
        task.wait(0.35)
        if toast.Parent then toast:Destroy() end
    end)
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
corner(MainFrame, 8)

local function fitFrame()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    MainFrame.Size = UDim2.new(0, math.min(360, vp.X - 20), 0, math.min(480, vp.Y - 40))
end
fitFrame()
local cam = workspace.CurrentCamera
if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitFrame) end

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 0, 28)
Title.Position = UDim2.new(0, 10, 0, 4)
Title.BackgroundTransparency = 1
Title.Text = "Script Executor"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 28, 0, 28)
CloseButton.Position = UDim2.new(1, -33, 0, 4)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 16
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = MainFrame
corner(CloseButton, 6)

local TabBar = Instance.new("ScrollingFrame")
TabBar.Size = UDim2.new(1, -20, 0, 34)
TabBar.Position = UDim2.new(0, 10, 0, 36)
TabBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 2
TabBar.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.CanvasSize = UDim2.new(0, 1600, 0, 0)
TabBar.Parent = MainFrame
corner(TabBar, 6)

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Parent = TabBar

local tabPad = Instance.new("UIPadding")
tabPad.PaddingLeft = UDim.new(0, 4)
tabPad.Parent = TabBar

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -20, 1, -88)
ContentArea.Position = UDim2.new(0, 10, 0, 78)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local function makeCheckRow(parentList, text, initial, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, 34)
    row.BackgroundTransparency = 1
    row.Parent = parentList

    local box = Instance.new("TextButton")
    box.Size = UDim2.new(0, 26, 0, 26)
    box.Position = UDim2.new(0, 0, 0.5, -13)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    box.Text = initial and "✓" or ""
    box.TextColor3 = Color3.fromRGB(100, 220, 100)
    box.TextSize = 16
    box.Font = Enum.Font.GothamBold
    box.Parent = row
    corner(box, 4)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -36, 1, 0)
    lbl.Position = UDim2.new(0, 36, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local state = initial
    box.MouseButton1Click:Connect(function()
        state = not state
        box.Text = state and "✓" or ""
        onChange(state)
    end)
    return row
end

local function makeColorRow(parentList, text, initialColor, onPick)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, 34)
    row.BackgroundTransparency = 1
    row.Parent = parentList

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local swatch = Instance.new("TextButton")
    swatch.Size = UDim2.new(0, 64, 0, 26)
    swatch.Position = UDim2.new(1, -64, 0.5, -13)
    swatch.BackgroundColor3 = initialColor
    swatch.Text = ""
    swatch.Parent = row
    corner(swatch, 4)

    swatch.MouseButton1Click:Connect(function() onPick(swatch) end)
    return swatch
end

local function makeSliderRow(parentList, text, minV, maxV, initial, isFloat, onChange, showReset, onReset)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, 44)
    row.BackgroundTransparency = 1
    row.Parent = parentList

    local function fmt(v)
        if isFloat then return string.format("%s: %.2f", text, v)
        else return string.format("%s: %d", text, math.floor(v)) end
    end

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, showReset and -50 or 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = fmt(initial)
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    if showReset then
        local resetBtn = Instance.new("TextButton")
        resetBtn.Size = UDim2.new(0, 46, 0, 20)
        resetBtn.Position = UDim2.new(1, -46, 0, 0)
        resetBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 60)
        resetBtn.Text = "Reset"
        resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        resetBtn.TextSize = 11
        resetBtn.Font = Enum.Font.GothamBold
        resetBtn.Parent = row
        corner(resetBtn, 4)
        resetBtn.MouseButton1Click:Connect(function()
            if onReset then onReset() end
        end)
    end

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, 0, 0, 16)
    bar.Position = UDim2.new(0, 0, 0, 24)
    bar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    bar.Text = ""
    bar.AutoButtonColor = false
    bar.Parent = row
    corner(bar, 8)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((initial - minV) / (maxV - minV), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(120, 120, 200)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    corner(fill, 8)

    local function setFromX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local v = minV + rel * (maxV - minV)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        lbl.Text = fmt(v)
        onChange(v)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            setFromX(input.Position.X)
            local c1, c2
            c1 = UserInputService.InputChanged:Connect(function(inp)
                if inp == input then setFromX(inp.Position.X) end
            end)
            c2 = UserInputService.InputEnded:Connect(function(inp)
                if inp == input then
                    c1:Disconnect()
                    c2:Disconnect()
                end
            end)
        end
    end)
    return row
end

local function buildListPage(parent, dataStore, saveFile, addLabel, hintText, favPrefix)
    local page = Instance.new("Frame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Parent = parent

    local addBtn = Instance.new("TextButton")
    addBtn.Size = UDim2.new(1, 0, 0, 32)
    addBtn.Position = UDim2.new(0, 0, 0, 0)
    addBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 60)
    addBtn.Text = addLabel
    addBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    addBtn.TextSize = 14
    addBtn.Font = Enum.Font.GothamBold
    addBtn.Parent = page
    corner(addBtn, 6)

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, 0, 0, 28)
    searchBox.Position = UDim2.new(0, 0, 0, 36)
    searchBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    searchBox.PlaceholderText = "Search..."
    searchBox.Text = ""
    searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    searchBox.TextSize = 13
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = page
    corner(searchBox, 6)
    local sbp = Instance.new("UIPadding"); sbp.PaddingLeft = UDim.new(0, 8); sbp.Parent = searchBox

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, 0, 1, -70)
    list.Position = UDim2.new(0, 0, 0, 70)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 4
    list.CanvasSize = UDim2.new(0, 0, 0, 100)
    list.Parent = page

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.Parent = list
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end)

    local form = Instance.new("Frame")
    form.Size = UDim2.new(1, -30, 0, 280)
    form.Position = UDim2.new(0, 15, 0.5, -140)
    form.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    form.BorderSizePixel = 0
    form.Visible = false
    form.ZIndex = 90
    form.Parent = MainFrame
    corner(form, 8)

    local fTitle = Instance.new("TextLabel")
    fTitle.Size = UDim2.new(1, -20, 0, 25)
    fTitle.Position = UDim2.new(0, 10, 0, 5)
    fTitle.BackgroundTransparency = 1
    fTitle.Text = (addLabel:gsub("^%+ ", ""))
    fTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    fTitle.TextSize = 16
    fTitle.Font = Enum.Font.GothamBold
    fTitle.TextXAlignment = Enum.TextXAlignment.Left
    fTitle.ZIndex = 91
    fTitle.Parent = form

    local nameBox = Instance.new("TextBox")
    nameBox.Size = UDim2.new(1, -20, 0, 30)
    nameBox.Position = UDim2.new(0, 10, 0, 40)
    nameBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    nameBox.PlaceholderText = "Message name..."
    nameBox.Text = ""
    nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    nameBox.TextSize = 13
    nameBox.Font = Enum.Font.Gotham
    nameBox.TextXAlignment = Enum.TextXAlignment.Left
    nameBox.ClearTextOnFocus = false
    nameBox.ZIndex = 91
    nameBox.Parent = form
    corner(nameBox, 6)
    local np = Instance.new("UIPadding"); np.PaddingLeft = UDim.new(0, 8); np.PaddingRight = UDim.new(0, 8); np.Parent = nameBox

    local msgBox = Instance.new("TextBox")
    msgBox.Size = UDim2.new(1, -20, 0, 100)
    msgBox.Position = UDim2.new(0, 10, 0, 78)
    msgBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    msgBox.PlaceholderText = "Message content..."
    msgBox.Text = ""
    msgBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    msgBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    msgBox.TextSize = 13
    msgBox.Font = Enum.Font.Gotham
    msgBox.TextXAlignment = Enum.TextXAlignment.Left
    msgBox.TextYAlignment = Enum.TextYAlignment.Top
    msgBox.TextWrapped = true
    msgBox.MultiLine = true
    msgBox.ClearTextOnFocus = false
    msgBox.ZIndex = 91
    msgBox.Parent = form
    corner(msgBox, 6)
    local mp = Instance.new("UIPadding"); mp.PaddingLeft = UDim.new(0, 8); mp.PaddingRight = UDim.new(0, 8); mp.PaddingTop = UDim.new(0, 4); mp.Parent = msgBox

    local channelLabel = Instance.new("TextLabel")
    channelLabel.Size = UDim2.new(1, -20, 0, 18)
    channelLabel.Position = UDim2.new(0, 10, 0, 186)
    channelLabel.BackgroundTransparency = 1
    channelLabel.Text = "Channels:"
    channelLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    channelLabel.TextSize = 12
    channelLabel.Font = Enum.Font.GothamBold
    channelLabel.TextXAlignment = Enum.TextXAlignment.Left
    channelLabel.ZIndex = 91
    channelLabel.Parent = form

    local chServer = Instance.new("TextButton")
    chServer.Size = UDim2.new(0, 70, 0, 26)
    chServer.Position = UDim2.new(0, 10, 0, 206)
    chServer.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    chServer.Text = "Server"
    chServer.TextColor3 = Color3.fromRGB(255, 255, 255)
    chServer.TextSize = 12
    chServer.Font = Enum.Font.GothamBold
    chServer.ZIndex = 91
    chServer.Parent = form
    corner(chServer, 4)
    local srvOn = true
    chServer.MouseButton1Click:Connect(function()
        srvOn = not srvOn
        chServer.BackgroundColor3 = srvOn and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(60, 60, 60)
    end)
    chServer.BackgroundColor3 = Color3.fromRGB(60, 120, 60)

    local chGlobal = Instance.new("TextButton")
    chGlobal.Size = UDim2.new(0, 70, 0, 26)
    chGlobal.Position = UDim2.new(0, 86, 0, 206)
    chGlobal.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    chGlobal.Text = "Global"
    chGlobal.TextColor3 = Color3.fromRGB(255, 255, 255)
    chGlobal.TextSize = 12
    chGlobal.Font = Enum.Font.GothamBold
    chGlobal.ZIndex = 91
    chGlobal.Parent = form
    corner(chGlobal, 4)
    local gblOn = false
    chGlobal.MouseButton1Click:Connect(function()
        gblOn = not gblOn
        chGlobal.BackgroundColor3 = gblOn and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(60, 60, 60)
    end)

    local chFriends = Instance.new("TextButton")
    chFriends.Size = UDim2.new(0, 70, 0, 26)
    chFriends.Position = UDim2.new(0, 162, 0, 206)
    chFriends.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    chFriends.Text = "Friends"
    chFriends.TextColor3 = Color3.fromRGB(255, 255, 255)
    chFriends.TextSize = 12
    chFriends.Font = Enum.Font.GothamBold
    chFriends.ZIndex = 91
    chFriends.Parent = form
    corner(chFriends, 4)
    local frdOn = false
    chFriends.MouseButton1Click:Connect(function()
        frdOn = not frdOn
        chFriends.BackgroundColor3 = frdOn and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(60, 60, 60)
    end)

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0.5, -15, 0, 32)
    cancelBtn.Position = UDim2.new(0, 10, 1, -42)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    cancelBtn.Text = "Cancel"
    cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelBtn.TextSize = 14
    cancelBtn.Font = Enum.Font.Gotham
    cancelBtn.ZIndex = 91
    cancelBtn.Parent = form
    corner(cancelBtn, 6)

    local confirmBtn = Instance.new("TextButton")
    confirmBtn.Size = UDim2.new(0.5, -15, 0, 32)
    confirmBtn.Position = UDim2.new(0.5, 5, 1, -42)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 60)
    confirmBtn.Text = "Add"
    confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmBtn.TextSize = 14
    confirmBtn.Font = Enum.Font.GothamBold
    confirmBtn.ZIndex = 91
    confirmBtn.Parent = form
    corner(confirmBtn, 6)

    local editingIndex = nil

    local refresh = function()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end

        local filter = string.lower(searchBox.Text)
        local shown = {}
        for i, entry in ipairs(dataStore) do
            if filter == "" or string.find(string.lower(tostring(entry.name)), filter, 1, true) then
                table.insert(shown, { i = i, entry = entry })
            end
        end

        if #shown == 0 then
            local e = Instance.new("TextLabel")
            e.Size = UDim2.new(1, -10, 0, 60)
            e.BackgroundTransparency = 1
            e.Text = #dataStore == 0 and hintText or "No matches."
            e.TextColor3 = Color3.fromRGB(150, 150, 150)
            e.TextSize = 13
            e.Font = Enum.Font.Gotham
            e.TextWrapped = true
            e.Parent = list
        else
            for _, item in ipairs(shown) do
                local i = item.i
                local entry = item.entry
                local favKey = favPrefix .. ":" .. entry.name

                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, -6, 0, 38)
                row.BackgroundTransparency = 1
                row.Parent = list

                local star = Instance.new("TextButton")
                star.Size = UDim2.new(0, 30, 1, 0)
                star.Position = UDim2.new(0, 0, 0, 0)
                star.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
                star.Text = isFav(favKey) and "★" or "☆"
                star.TextColor3 = isFav(favKey) and Color3.fromRGB(255, 210, 80) or Color3.fromRGB(180, 180, 180)
                star.TextSize = 16
                star.Font = Enum.Font.GothamBold
                star.Parent = row
                corner(star, 6)
                star.MouseButton1Click:Connect(function()
                    toggleFav(favKey)
                    star.Text = isFav(favKey) and "★" or "☆"
                    star.TextColor3 = isFav(favKey) and Color3.fromRGB(255, 210, 80) or Color3.fromRGB(180, 180, 180)
                    showToast(isFav(favKey) and ("Favorited: " .. entry.name) or ("Unfavorited: " .. entry.name),
                        isFav(favKey) and Color3.fromRGB(140, 100, 30) or Color3.fromRGB(60, 60, 60), 1.5)
                end)

                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -100, 1, 0)
                btn.Position = UDim2.new(0, 34, 0, 0)
                btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                btn.Text = "▶ " .. entry.name
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                btn.TextSize = 14
                btn.Font = Enum.Font.Gotham
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.TextTruncate = Enum.TextTruncate.AtEnd
                btn.Parent = row
                corner(btn, 6)
                local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0, 10); p.Parent = btn

                btn.MouseButton1Click:Connect(function()
                    if favPrefix == "chat" then
                        local channels = {}
                        if entry.channels then
                            for ch, on in pairs(entry.channels) do
                                if on then table.insert(channels, ch) end
                            end
                        end
                        sendChatMessage(entry.script, channels)
                    else
                        local ok, err = pcall(function() loadstring(entry.script)() end)
                        if ok then
                            showToast("Executed: " .. entry.name, Color3.fromRGB(60, 120, 60), 2)
                        else
                            showToast("Failed: " .. entry.name, Color3.fromRGB(140, 50, 50), 3)
                            warn("Failed " .. entry.name .. ": " .. tostring(err))
                        end
                    end
                end)

                local edit = Instance.new("TextButton")
                edit.Size = UDim2.new(0, 30, 1, 0)
                edit.Position = UDim2.new(1, -64, 0, 0)
                edit.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
                edit.Text = "✎"
                edit.TextColor3 = Color3.fromRGB(255, 255, 255)
                edit.TextSize = 15
                edit.Font = Enum.Font.GothamBold
                edit.Parent = row
                corner(edit, 6)
                edit.MouseButton1Click:Connect(function()
                    editingIndex = i
                    nameBox.Text = entry.name
                    msgBox.Text = entry.script
                    if entry.channels then
                        srvOn = entry.channels.Server == true
                        gblOn = entry.channels.Global == true
                        frdOn = entry.channels.Friends == true
                        chServer.BackgroundColor3 = srvOn and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(60, 60, 60)
                        chGlobal.BackgroundColor3 = gblOn and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(60, 60, 60)
                        chFriends.BackgroundColor3 = frdOn and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(60, 60, 60)
                    end
                    confirmBtn.Text = "Save"
                    fTitle.Text = "Edit: " .. entry.name
                    form.Visible = true
                end)

                local del = Instance.new("TextButton")
                del.Size = UDim2.new(0, 30, 1, 0)
                del.Position = UDim2.new(1, -30, 0, 0)
                del.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
                del.Text = "X"
                del.TextColor3 = Color3.fromRGB(255, 255, 255)
                del.TextSize = 14
                del.Font = Enum.Font.GothamBold
                del.Parent = row
                corner(del, 6)
                del.MouseButton1Click:Connect(function()
                    local removed = table.remove(dataStore, i)
                    saveJsonFile(saveFile, dataStore)
                    refresh()
                    showToast("Removed: " .. removed.name, Color3.fromRGB(140, 50, 50), 1.5)
                end)
            end
        end
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(refresh)

    addBtn.MouseButton1Click:Connect(function()
        editingIndex = nil
        nameBox.Text = ""
        msgBox.Text = ""
        srvOn = true
        gblOn = false
        frdOn = false
        chServer.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
        chGlobal.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        chFriends.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        confirmBtn.Text = "Add"
        fTitle.Text = (addLabel:gsub("^%+ ", ""))
        form.Visible = true
    end)

    cancelBtn.MouseButton1Click:Connect(function()
        editingIndex = nil
        nameBox.Text = ""
        msgBox.Text = ""
        form.Visible = false
    end)

    confirmBtn.MouseButton1Click:Connect(function()
        if nameBox.Text == "" or msgBox.Text == "" then
            if nameBox.Text == "" then nameBox.BackgroundColor3 = Color3.fromRGB(80, 30, 30) end
            if msgBox.Text == "" then msgBox.BackgroundColor3 = Color3.fromRGB(80, 30, 30) end
            task.wait(0.4)
            nameBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            msgBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            return
        end

        local channelData = {
            Server = srvOn,
            Global = gblOn,
            Friends = frdOn,
        }

        if editingIndex then
            dataStore[editingIndex] = { name = nameBox.Text, script = msgBox.Text, channels = channelData }
            showToast("Saved: " .. nameBox.Text, Color3.fromRGB(60, 120, 60), 2)
        else
            table.insert(dataStore, { name = nameBox.Text, script = msgBox.Text, channels = channelData })
            showToast("Added: " .. nameBox.Text, Color3.fromRGB(60, 120, 60), 2)
        end
        saveJsonFile(saveFile, dataStore)
        editingIndex = nil
        nameBox.Text = ""
        msgBox.Text = ""
        form.Visible = false
        refresh()
    end)

    refresh()
    return { page = page, refresh = refresh }
end

local function buildPlayerListPanel(parent, onSelect)
    local panel = Instance.new("ScrollingFrame")
    panel.Size = UDim2.new(0, 135, 1, 0)
    panel.Position = UDim2.new(0, 0, 0, 0)
    panel.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    panel.BorderSizePixel = 0
    panel.ScrollBarThickness = 3
    panel.CanvasSize = UDim2.new(0, 0, 0, 0)
    panel.Parent = parent
    corner(panel, 6)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.Parent = panel
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        panel.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 6)
    end)

    local buttons = {}

    local function refresh()
        for _, b in ipairs(buttons) do
            pcall(function() b:Destroy() end)
        end
        buttons = {}

        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(list, p) end
        end
        table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)

        if #list == 0 then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -6, 0, 30)
            lbl.BackgroundTransparency = 1
            lbl.Text = "No other players"
            lbl.TextColor3 = Color3.fromRGB(140, 140, 140)
            lbl.TextSize = 11
            lbl.Font = Enum.Font.Gotham
            lbl.Parent = panel
            table.insert(buttons, lbl)
            return
        end

        for _, p in ipairs(list) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -6, 0, 28)
            btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            btn.Text = p.Name
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.TextSize = 12
            btn.Font = Enum.Font.Gotham
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.TextTruncate = Enum.TextTruncate.AtEnd
            btn.Parent = panel
            corner(btn, 4)
            local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 6); pad.Parent = btn

            btn.MouseButton1Click:Connect(function()
                for _, b in ipairs(buttons) do
                    if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(45, 45, 45) end
                end
                btn.BackgroundColor3 = Color3.fromRGB(70, 90, 130)
                if onSelect then onSelect(p) end
            end)

            table.insert(buttons, btn)
        end
    end

    Players.PlayerAdded:Connect(function() task.wait(0.3); refresh() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.3); refresh() end)
    task.spawn(function() task.wait(0.3); refresh() end)

    return panel, refresh
end

local function makeSmallBtn(parent, text, x, y, w, h, color, onClick)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, h)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.Parent = parent
    corner(b, 5)
    b.MouseButton1Click:Connect(onClick)
    return b
end

local ScriptHubs = {
    { name = "Spiem Hub (36 Games)",        url = "https://raw.githubusercontent.com/perfectusmim1/spiemhub/refs/heads/main/loader" },
    { name = "Kagu Hub (100+ Games)",       url = "https://raw.githubusercontent.com/Kaguya11/KaguHubRework/main/KaguHub" },
    { name = "MiHUB (Multi-Game)",           url = "https://git.miguvt.com/MiguVT/MiHUB/raw/branch/main/loader.luau" },
    { name = "Unknownius Hub (40+ Games)",   url = "https://raw.githubusercontent.com/Unknownius-br/Hub/refs/heads/main/Hub" },
    { name = "OP Script Hub (100s Games)",   url = "https://raw.githubusercontent.com/scripthubekitten/SCRIPTHUBV3/main/SCRIPTHUBV3" },
    { name = "Unfair Hub (47+ Games)",       url = "https://raw.githubusercontent.com/rblxscriptsnet/unfair/main/rblxhub.lua" },
    { name = "wayout (Multi-Game)",          url = "https://raw.githubusercontent.com/raphaelmaboi/wayout/refs/heads/main/loader.lua" },
    { name = "RealZzHub (Multi-Game)",       url = "https://realzzhub.xyz/script.lua" },
    { name = "Kitty Hub (190 Games)",        url = "https://rscripts.net/raw/kitty-hub-190-games-keyless_1723323186468_Gak3vicgC5.txt" },
    { name = "Redz Hub (Multi-Game)",        url = "https://raw.githubusercontent.com/tlredz/Scripts/refs/heads/main/main.luau" },
    { name = "Vidas Hub (Multi-Game)",       url = "https://pastebin.com/raw/1K0n4K7q" },
    { name = "ROXCOM Hub (All Games)",       url = "https://raw.githubusercontent.com/yasinklauss1/roxcom-hub/refs/heads/main/roxcom-hub.lua" },
    { name = "SP Hub (Multi-Game)",          url = "https://raw.githubusercontent.com/as6cd0/SP_Hub/refs/heads/main/Loader" },
    { name = "Speed Hub X (Multi-Game)",     url = "https://raw.githubusercontent.com/AhmadV99/Speed-Hub-X/main/Speed%20Hub%20X.lua" },
    { name = "BlackCat48Hub (8 Games)",      url = "https://raw.githubusercontent.com/ytDragonV6bayku/BlackCat48HubMainScriptLoader/main/MainScriptLoader" },
    { name = "Solara Hub (450+ Games)",      url = "https://raw.githubusercontent.com/FFJ1/Roblox-Exploits/main/scripts/Loader.lua" },
    { name = "Nexus Hub (Multi-Game)",       url = "https://nexus-script.vercel.app/Loader.lua" },
    { name = "Ouroboros Hub (Multi-Game)",   url = "https://raw.githubusercontent.com/joustingmatch/Ouroboros/main/loader.lua" },
    { name = "ZHub (Multi-Game)",            url = "https://raw.githubusercontent.com/ZHubTeam/zhubteam.github.io/main/zhub-script.lua" },
    { name = "JimHub (Runaways)",            url = "https://raw.githubusercontent.com/w15546251-afk/RUNAWAY/refs/heads/main/JimHub" },
}

local ScriptsTab = Instance.new("Frame")
ScriptsTab.Size = UDim2.new(1, 0, 1, 0)
ScriptsTab.BackgroundTransparency = 1
ScriptsTab.Visible = true
ScriptsTab.Parent = ContentArea

local ScriptsTitleBtn = Instance.new("TextButton")
ScriptsTitleBtn.Size = UDim2.new(1, 0, 0, 30)
ScriptsTitleBtn.Position = UDim2.new(0, 0, 0, 0)
ScriptsTitleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 120)
ScriptsTitleBtn.Text = "My Scripts"
ScriptsTitleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ScriptsTitleBtn.TextSize = 14
ScriptsTitleBtn.Font = Enum.Font.GothamBold
ScriptsTitleBtn.Parent = ScriptsTab
corner(ScriptsTitleBtn, 6)

local MainScriptsPage = Instance.new("Frame")
MainScriptsPage.Size = UDim2.new(1, 0, 1, -36)
MainScriptsPage.Position = UDim2.new(0, 0, 0, 36)
MainScriptsPage.BackgroundTransparency = 1
MainScriptsPage.Visible = true
MainScriptsPage.Parent = ScriptsTab

local presetsSearch = Instance.new("TextBox")
presetsSearch.Size = UDim2.new(1, 0, 0, 28)
presetsSearch.Position = UDim2.new(0, 0, 0, 0)
presetsSearch.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
presetsSearch.PlaceholderText = "Search presets..."
presetsSearch.Text = ""
presetsSearch.TextColor3 = Color3.fromRGB(255, 255, 255)
presetsSearch.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
presetsSearch.TextSize = 13
presetsSearch.Font = Enum.Font.Gotham
presetsSearch.TextXAlignment = Enum.TextXAlignment.Left
presetsSearch.ClearTextOnFocus = false
presetsSearch.Parent = MainScriptsPage
corner(presetsSearch, 6)
local psp = Instance.new("UIPadding"); psp.PaddingLeft = UDim.new(0, 8); psp.Parent = presetsSearch

local PresetList = Instance.new("ScrollingFrame")
PresetList.Size = UDim2.new(1, 0, 1, -34)
PresetList.Position = UDim2.new(0, 0, 0, 34)
PresetList.BackgroundTransparency = 1
PresetList.BorderSizePixel = 0
PresetList.ScrollBarThickness = 4
PresetList.CanvasSize = UDim2.new(0, 0, 0, 100)
PresetList.Parent = MainScriptsPage

local presetLayout = Instance.new("UIListLayout")
presetLayout.Padding = UDim.new(0, 4)
presetLayout.Parent = PresetList
presetLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    PresetList.CanvasSize = UDim2.new(0, 0, 0, presetLayout.AbsoluteContentSize.Y + 8)
end)

local Presets = {
    { name = "Infinite Yield", url = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source" },
    { name = "Fly GUI V3", url = "https://rawscripts.net/raw/Universal-Script-FLY-GUI-V3-Universal-230365" },
    { name = "Dex Explorer (Mobile)", url = "https://rawscripts.net/raw/Universal-Script-Dex-Explorer-for-Mobile-32019" },
    { name = "Simple Spy", url = "https://raw.githubusercontent.com/78n/SimpleSpy/main/SimpleSpyBeta.lua" },
    { name = "Turtle Spy", url = "https://rawscripts.net/raw/Universal-Script-Turtle-Spy-21930" },
}

local function refreshPresets()
    for _, c in ipairs(PresetList:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    local filter = string.lower(presetsSearch.Text)
    for _, p in ipairs(Presets) do
        if filter == "" or string.find(string.lower(p.name), filter, 1, true) then
            local favKey = "preset:" .. p.name
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -6, 0, 38)
            row.BackgroundTransparency = 1
            row.Parent = PresetList

            local star = Instance.new("TextButton")
            star.Size = UDim2.new(0, 30, 1, 0)
            star.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            star.Text = isFav(favKey) and "★" or "☆"
            star.TextColor3 = isFav(favKey) and Color3.fromRGB(255, 210, 80) or Color3.fromRGB(180, 180, 180)
            star.TextSize = 16
            star.Font = Enum.Font.GothamBold
            star.Parent = row
            corner(star, 6)
            star.MouseButton1Click:Connect(function()
                toggleFav(favKey)
                star.Text = isFav(favKey) and "★" or "☆"
                star.TextColor3 = isFav(favKey) and Color3.fromRGB(255, 210, 80) or Color3.fromRGB(180, 180, 180)
                showToast(isFav(favKey) and (p.name) or ("Removed: " .. p.name),
                    isFav(favKey) and Color3.fromRGB(140, 100, 30) or Color3.fromRGB(60, 60, 60), 1.5)
            end)

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -34, 1, 0)
            btn.Position = UDim2.new(0, 34, 0, 0)
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            btn.Text = "▶ " .. p.name
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.TextSize = 14
            btn.Font = Enum.Font.Gotham
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.TextTruncate = Enum.TextTruncate.AtEnd
            btn.Parent = row
            corner(btn, 6)
            local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 10); pad.Parent = btn

            btn.MouseButton1Click:Connect(function()
                local ok, err = pcall(function() loadstring(game:HttpGet(p.url))() end)
                if ok then showToast("Executed: " .. p.name, Color3.fromRGB(60, 120, 60), 2)
                else showToast("Failed: " .. p.name, Color3.fromRGB(140, 50, 50), 3) end
                if not ok then warn("Failed: " .. tostring(err)) end
            end)
        end
    end
end
presetsSearch:GetPropertyChangedSignal("Text"):Connect(refreshPresets)
refreshPresets()

local customBuilder = buildListPage(
    ScriptsTab, CustomScripts, "custom_scripts.json",
    "+ Add Script", "No scripts added yet.\nClick '+ Add Script' above.",
    "custom"
)
local CustomPage = customBuilder.page
CustomPage.Position = UDim2.new(0, 0, 0, 36)
CustomPage.Size = UDim2.new(1, 0, 1, -36)
CustomPage.Visible = false

local onCustomPage = false
local function showScriptsSubPage(custom)
    onCustomPage = custom
    MainScriptsPage.Visible = not custom
    CustomPage.Visible = custom
    ScriptsTitleBtn.Text = custom and "Back to Presets" or "My Scripts"
end
ScriptsTitleBtn.MouseButton1Click:Connect(function()
    showScriptsSubPage(not onCustomPage)
end)

local HubsTab = Instance.new("Frame")
HubsTab.Size = UDim2.new(1, 0, 1, 0)
HubsTab.BackgroundTransparency = 1
HubsTab.Visible = false
HubsTab.Parent = ContentArea

local hubsSearch = Instance.new("TextBox")
hubsSearch.Size = UDim2.new(1, 0, 0, 28)
hubsSearch.Position = UDim2.new(0, 0, 0, 0)
hubsSearch.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
hubsSearch.PlaceholderText = "Search hubs..."
hubsSearch.Text = ""
hubsSearch.TextColor3 = Color3.fromRGB(255, 255, 255)
hubsSearch.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
hubsSearch.TextSize = 13
hubsSearch.Font = Enum.Font.Gotham
hubsSearch.TextXAlignment = Enum.TextXAlignment.Left
hubsSearch.ClearTextOnFocus = false
hubsSearch.Parent = HubsTab
corner(hubsSearch, 6)
local hsp = Instance.new("UIPadding"); hsp.PaddingLeft = UDim.new(0, 8); hsp.Parent = hubsSearch

local HubsList = Instance.new("ScrollingFrame")
HubsList.Size = UDim2.new(1, 0, 1, -34)
HubsList.Position = UDim2.new(0, 0, 0, 34)
HubsList.BackgroundTransparency = 1
HubsList.BorderSizePixel = 0
HubsList.ScrollBarThickness = 4
HubsList.CanvasSize = UDim2.new(0, 0, 0, 100)
HubsList.Parent = HubsTab

local hubsLayout = Instance.new("UIListLayout")
hubsLayout.Padding = UDim.new(0, 4)
hubsLayout.Parent = HubsList
hubsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    HubsList.CanvasSize = UDim2.new(0, 0, 0, hubsLayout.AbsoluteContentSize.Y + 8)
end)

local function refreshHubs()
    for _, c in ipairs(HubsList:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    local filter = string.lower(hubsSearch.Text)
    for _, hub in ipairs(ScriptHubs) do
        if filter == "" or string.find(string.lower(hub.name), filter, 1, true) then
            local favKey = "hub:" .. hub.name
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -6, 0, 38)
            row.BackgroundTransparency = 1
            row.Parent = HubsList

            local star = Instance.new("TextButton")
            star.Size = UDim2.new(0, 30, 1, 0)
            star.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            star.Text = isFav(favKey) and "★" or "☆"
            star.TextColor3 = isFav(favKey) and Color3.fromRGB(255, 210, 80) or Color3.fromRGB(180, 180, 180)
            star.TextSize = 16
            star.Font = Enum.Font.GothamBold
            star.Parent = row
            corner(star, 6)
            star.MouseButton1Click:Connect(function()
                toggleFav(favKey)
                star.Text = isFav(favKey) and "★" or "☆"
                star.TextColor3 = isFav(favKey) and Color3.fromRGB(255, 210, 80) or Color3.fromRGB(180, 180, 180)
                showToast(isFav(favKey) and (hub.name) or ("Removed: " .. hub.name),
                    isFav(favKey) and Color3.fromRGB(140, 100, 30) or Color3.fromRGB(60, 60, 60), 1.5)
            end)

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -34, 1, 0)
            btn.Position = UDim2.new(0, 34, 0, 0)
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            btn.Text = "▶ " .. hub.name
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.TextSize = 14
            btn.Font = Enum.Font.Gotham
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.TextTruncate = Enum.TextTruncate.AtEnd
            btn.Parent = row
            corner(btn, 6)
            local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 10); pad.Parent = btn

            btn.MouseButton1Click:Connect(function()
                showToast("Loading: " .. hub.name .. "...", Color3.fromRGB(80, 80, 140), 2)
                local ok, err = pcall(function() loadstring(game:HttpGet(hub.url))() end)
                if ok then showToast("Executed: " .. hub.name, Color3.fromRGB(60, 120, 60), 2)
                else showToast("Failed: " .. hub.name, Color3.fromRGB(140, 50, 50), 3) end
                if not ok then warn("Failed " .. hub.name .. ": " .. tostring(err)) end
            end)
        end
    end
end
hubsSearch:GetPropertyChangedSignal("Text"):Connect(refreshHubs)
refreshHubs()

local GamesTab = Instance.new("Frame")
GamesTab.Size = UDim2.new(1, 0, 1, 0)
GamesTab.BackgroundTransparency = 1
GamesTab.Visible = false
GamesTab.Parent = ContentArea

buildListPage(
    GamesTab, GameScripts, "games_scripts.json",
    "+ Add Game", "No games added yet.\nClick '+ Add Game' above.",
    "game"
)

local ChatTab = Instance.new("Frame")
ChatTab.Size = UDim2.new(1, 0, 1, 0)
ChatTab.BackgroundTransparency = 1
ChatTab.Visible = false
ChatTab.Parent = ContentArea

buildListPage(
    ChatTab, ChatMessages, "chat_messages.json",
    "+ Add Message", "No messages added yet.\nClick '+ Add Message' above.",
    "chat"
)

local WarrantTab = Instance.new("Frame")
WarrantTab.Size = UDim2.new(1, 0, 1, 0)
WarrantTab.BackgroundTransparency = 1
WarrantTab.Visible = false
WarrantTab.Parent = ContentArea

local selectedWarrantPlayer = nil

buildPlayerListPanel(WarrantTab, function(p)
    selectedWarrantPlayer = p
    warrantSelectedLabel.Text = "Selected: " .. p.Name
end)

local warrantRight = Instance.new("Frame")
warrantRight.Size = UDim2.new(1, -143, 1, 0)
warrantRight.Position = UDim2.new(0, 143, 0, 0)
warrantRight.BackgroundTransparency = 1
warrantRight.Parent = WarrantTab

local warrantSelectedLabel = Instance.new("TextLabel")
warrantSelectedLabel.Size = UDim2.new(1, 0, 0, 26)
warrantSelectedLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
warrantSelectedLabel.Text = "Select a player"
warrantSelectedLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
warrantSelectedLabel.TextSize = 12
warrantSelectedLabel.Font = Enum.Font.GothamBold
warrantSelectedLabel.TextTruncate = Enum.TextTruncate.AtEnd
warrantSelectedLabel.Parent = warrantRight
corner(warrantSelectedLabel, 6)

local warrantReasonLabel = Instance.new("TextLabel")
warrantReasonLabel.Size = UDim2.new(1, 0, 0, 16)
warrantReasonLabel.Position = UDim2.new(0, 0, 0, 32)
warrantReasonLabel.BackgroundTransparency = 1
warrantReasonLabel.Text = "Reason:"
warrantReasonLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
warrantReasonLabel.TextSize = 11
warrantReasonLabel.Font = Enum.Font.GothamBold
warrantReasonLabel.TextXAlignment = Enum.TextXAlignment.Left
warrantReasonLabel.Parent = warrantRight

local warrantReasonBox = Instance.new("TextBox")
warrantReasonBox.Size = UDim2.new(1, 0, 0, 140)
warrantReasonBox.Position = UDim2.new(0, 0, 0, 52)
warrantReasonBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
warrantReasonBox.PlaceholderText = "Type reason..."
warrantReasonBox.Text = ""
warrantReasonBox.TextColor3 = Color3.fromRGB(255, 255, 255)
warrantReasonBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
warrantReasonBox.TextSize = 12
warrantReasonBox.Font = Enum.Font.Gotham
warrantReasonBox.TextXAlignment = Enum.TextXAlignment.Left
warrantReasonBox.TextYAlignment = Enum.TextYAlignment.Top
warrantReasonBox.TextWrapped = true
warrantReasonBox.MultiLine = true
warrantReasonBox.ClearTextOnFocus = false
warrantReasonBox.Parent = warrantRight
corner(warrantReasonBox, 6)
local wrbPad = Instance.new("UIPadding")
wrbPad.PaddingLeft = UDim.new(0, 8)
wrbPad.PaddingRight = UDim.new(0, 8)
wrbPad.PaddingTop = UDim.new(0, 6)
wrbPad.Parent = warrantReasonBox

local fileWarrantBtn = Instance.new("TextButton")
fileWarrantBtn.Size = UDim2.new(1, 0, 0, 40)
fileWarrantBtn.Position = UDim2.new(0, 0, 0, 202)
fileWarrantBtn.BackgroundColor3 = Color3.fromRGB(220, 130, 40)
fileWarrantBtn.Text = "File Warrant"
fileWarrantBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
fileWarrantBtn.TextSize = 14
fileWarrantBtn.Font = Enum.Font.GothamBold
fileWarrantBtn.Parent = warrantRight
corner(fileWarrantBtn, 6)

fileWarrantBtn.MouseButton1Click:Connect(function()
    if not selectedWarrantPlayer then
        showToast("Select a player first", Color3.fromRGB(140, 50, 50), 2)
        return
    end
    local reason = warrantReasonBox.Text
    if reason == "" then
        showToast("Enter a reason", Color3.fromRGB(140, 50, 50), 2)
        return
    end

    local warrant = {
        id = newWarrantId(),
        targetName = selectedWarrantPlayer.Name,
        targetUserId = selectedWarrantPlayer.UserId,
        reason = reason,
        filedBy = LocalPlayer.DisplayName,
        filedByUser = LocalPlayer.Name,
        filedAt = getTimestamp(),
        status = "pending",
        reviewedBy = nil,
        reviewedByUser = nil,
        reviewReason = nil,
        reviewedAt = nil,
    }
    table.insert(Warrants, warrant)
    saveJsonFile("warrants.json", Warrants)

    addRecord({
        warrantId = warrant.id,
        targetName = warrant.targetName,
        kind = "filed",
        reason = reason,
        filerDisplay = LocalPlayer.DisplayName,
        filerUser = LocalPlayer.Name,
        timestamp = warrant.filedAt,
    })

    warrantReasonBox.Text = ""
    showToast("Warrant filed for " .. selectedWarrantPlayer.Name, Color3.fromRGB(140, 100, 30), 2)
    if refreshPending then refreshPending() end
    if refreshRecordsFor then refreshRecordsFor() end
end)

local PendingTab = Instance.new("Frame")
PendingTab.Size = UDim2.new(1, 0, 1, 0)
PendingTab.BackgroundTransparency = 1
PendingTab.Visible = false
PendingTab.Parent = ContentArea

local PendingList = Instance.new("ScrollingFrame")
PendingList.Size = UDim2.new(1, 0, 1, 0)
PendingList.BackgroundTransparency = 1
PendingList.BorderSizePixel = 0
PendingList.ScrollBarThickness = 4
PendingList.CanvasSize = UDim2.new(0, 0, 0, 0)
PendingList.Parent = PendingTab

local pendingLayout = Instance.new("UIListLayout")
pendingLayout.Padding = UDim.new(0, 6)
pendingLayout.Parent = PendingList
pendingLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    PendingList.CanvasSize = UDim2.new(0, 0, 0, pendingLayout.AbsoluteContentSize.Y + 8)
end)

openReviewDialog = function(warrantId, action)
    local form = Instance.new("Frame")
    form.Size = UDim2.new(1, -30, 0, 210)
    form.Position = UDim2.new(0, 15, 0.5, -105)
    form.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    form.BorderSizePixel = 0
    form.ZIndex = 120
    form.Parent = MainFrame
    corner(form, 8)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -20, 0, 24)
    titleLbl.Position = UDim2.new(0, 10, 0, 6)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = action == "approved" and "Approve Warrant" or "Deny Warrant"
    titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLbl.TextSize = 16
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.ZIndex = 121
    titleLbl.Parent = form

    local rl = Instance.new("TextLabel")
    rl.Size = UDim2.new(1, -20, 0, 16)
    rl.Position = UDim2.new(0, 10, 0, 36)
    rl.BackgroundTransparency = 1
    rl.Text = "Reason:"
    rl.TextColor3 = Color3.fromRGB(180, 180, 180)
    rl.TextSize = 12
    rl.Font = Enum.Font.GothamBold
    rl.TextXAlignment = Enum.TextXAlignment.Left
    rl.ZIndex = 121
    rl.Parent = form

    local reasonBox = Instance.new("TextBox")
    reasonBox.Size = UDim2.new(1, -20, 0, 90)
    reasonBox.Position = UDim2.new(0, 10, 0, 56)
    reasonBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    reasonBox.PlaceholderText = "Type reason..."
    reasonBox.Text = ""
    reasonBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    reasonBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    reasonBox.TextSize = 13
    reasonBox.Font = Enum.Font.Gotham
    reasonBox.TextXAlignment = Enum.TextXAlignment.Left
    reasonBox.TextYAlignment = Enum.TextYAlignment.Top
    reasonBox.TextWrapped = true
    reasonBox.MultiLine = true
    reasonBox.ClearTextOnFocus = false
    reasonBox.ZIndex = 121
    reasonBox.Parent = form
    corner(reasonBox, 6)
    local rbPad = Instance.new("UIPadding")
    rbPad.PaddingLeft = UDim.new(0, 8)
    rbPad.PaddingRight = UDim.new(0, 8)
    rbPad.PaddingTop = UDim.new(0, 4)
    rbPad.Parent = reasonBox

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0.5, -15, 0, 32)
    cancelBtn.Position = UDim2.new(0, 10, 1, -42)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    cancelBtn.Text = "Cancel"
    cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelBtn.TextSize = 14
    cancelBtn.Font = Enum.Font.Gotham
    cancelBtn.ZIndex = 121
    cancelBtn.Parent = form
    corner(cancelBtn, 6)

    local confirmBtn = Instance.new("TextButton")
    confirmBtn.Size = UDim2.new(0.5, -15, 0, 32)
    confirmBtn.Position = UDim2.new(0.5, 5, 1, -42)
    confirmBtn.BackgroundColor3 = action == "approved" and Color3.fromRGB(60, 140, 60) or Color3.fromRGB(150, 50, 50)
    confirmBtn.Text = action == "approved" and "Approve" or "Deny"
    confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmBtn.TextSize = 14
    confirmBtn.Font = Enum.Font.GothamBold
    confirmBtn.ZIndex = 121
    confirmBtn.Parent = form
    corner(confirmBtn, 6)

    cancelBtn.MouseButton1Click:Connect(function() form:Destroy() end)
    confirmBtn.MouseButton1Click:Connect(function()
        local reviewReason = reasonBox.Text
        if reviewReason == "" then
            showToast("Enter a reason", Color3.fromRGB(140, 50, 50), 2)
            return
        end

        local found = nil
        for _, w in ipairs(Warrants) do
            if w.id == warrantId then found = w break end
        end
        if not found then form:Destroy() return end

        found.status = action
        found.reviewedBy = LocalPlayer.DisplayName
        found.reviewedByUser = LocalPlayer.Name
        found.reviewReason = reviewReason
        found.reviewedAt = getTimestamp()
        saveJsonFile("warrants.json", Warrants)

        addRecord({
            warrantId = found.id,
            targetName = found.targetName,
            kind = action,
            reason = found.reason,
            reviewReason = reviewReason,
            filerDisplay = found.filedBy,
            filerUser = found.filedByUser,
            reviewerDisplay = LocalPlayer.DisplayName,
            reviewerUser = LocalPlayer.Name,
            timestamp = found.reviewedAt,
        })

        form:Destroy()
        showToast("Warrant " .. action, action == "approved" and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(140, 50, 50), 2)
        if refreshPending then refreshPending() end
        if refreshWanted then refreshWanted() end
        if refreshRecordsFor then refreshRecordsFor() end
    end)
end

refreshPending = function()
    for _, c in ipairs(PendingList:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end

    local any = false
    for _, w in ipairs(Warrants) do
        if w.status == "pending" then
            any = true
            local item = Instance.new("Frame")
            item.Size = UDim2.new(1, -6, 0, 130)
            item.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            item.BorderSizePixel = 0
            item.Parent = PendingList
            corner(item, 6)

            local targetLbl = Instance.new("TextLabel")
            targetLbl.Size = UDim2.new(1, -12, 0, 20)
            targetLbl.Position = UDim2.new(0, 6, 0, 6)
            targetLbl.BackgroundTransparency = 1
            targetLbl.Text = "Target: " .. tostring(w.targetName)
            targetLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
            targetLbl.TextSize = 14
            targetLbl.Font = Enum.Font.GothamBold
            targetLbl.TextXAlignment = Enum.TextXAlignment.Left
            targetLbl.TextTruncate = Enum.TextTruncate.AtEnd
            targetLbl.Parent = item

            local reasonLbl = Instance.new("TextLabel")
            reasonLbl.Size = UDim2.new(1, -12, 0, 34)
            reasonLbl.Position = UDim2.new(0, 6, 0, 28)
            reasonLbl.BackgroundTransparency = 1
            reasonLbl.Text = "Reason: " .. tostring(w.reason)
            reasonLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
            reasonLbl.TextSize = 12
            reasonLbl.Font = Enum.Font.Gotham
            reasonLbl.TextXAlignment = Enum.TextXAlignment.Left
            reasonLbl.TextYAlignment = Enum.TextYAlignment.Top
            reasonLbl.TextWrapped = true
            reasonLbl.Parent = item

            local metaLbl = Instance.new("TextLabel")
            metaLbl.Size = UDim2.new(1, -12, 0, 16)
            metaLbl.Position = UDim2.new(0, 6, 0, 66)
            metaLbl.BackgroundTransparency = 1
            metaLbl.Text = "By " .. tostring(w.filedByUser or w.filedBy) .. " | " .. tostring(w.filedAt)
            metaLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
            metaLbl.TextSize = 11
            metaLbl.Font = Enum.Font.Gotham
            metaLbl.TextXAlignment = Enum.TextXAlignment.Left
            metaLbl.TextTruncate = Enum.TextTruncate.AtEnd
            metaLbl.Parent = item

            local wid = w.id
            makeSmallBtn(item, "Approve", 6, 0, 100, 32, Color3.fromRGB(60, 140, 60), function()
                openReviewDialog(wid, "approved")
            end).Position = UDim2.new(0, 6, 1, -38)

            makeSmallBtn(item, "Deny", 0, 0, 100, 32, Color3.fromRGB(150, 50, 50), function()
                openReviewDialog(wid, "denied")
            end).Position = UDim2.new(1, -106, 1, -38)
        end
    end

    if not any then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 60)
        lbl.BackgroundTransparency = 1
        lbl.Text = "No pending warrants."
        lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        lbl.TextSize = 13
        lbl.Font = Enum.Font.Gotham
        lbl.Parent = PendingList
    end
end
refreshPending()

local WantedTab = Instance.new("Frame")
WantedTab.Size = UDim2.new(1, 0, 1, 0)
WantedTab.BackgroundTransparency = 1
WantedTab.Visible = false
WantedTab.Parent = ContentArea

local WantedList = Instance.new("ScrollingFrame")
WantedList.Size = UDim2.new(1, 0, 1, 0)
WantedList.BackgroundTransparency = 1
WantedList.BorderSizePixel = 0
WantedList.ScrollBarThickness = 4
WantedList.CanvasSize = UDim2.new(0, 0, 0, 0)
WantedList.Parent = WantedTab

local wantedLayout = Instance.new("UIListLayout")
wantedLayout.Padding = UDim.new(0, 6)
wantedLayout.Parent = WantedList
wantedLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    WantedList.CanvasSize = UDim2.new(0, 0, 0, wantedLayout.AbsoluteContentSize.Y + 8)
end)

refreshWanted = function()
    for _, c in ipairs(WantedList:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end

    local any = false
    for _, w in ipairs(Warrants) do
        if w.status == "approved" then
            any = true
            local item = Instance.new("Frame")
            item.Size = UDim2.new(1, -6, 0, 90)
            item.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
            item.BorderSizePixel = 0
            item.Parent = WantedList
            corner(item, 6)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(1, -100, 0, 22)
            nameLbl.Position = UDim2.new(0, 8, 0, 6)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = "WANTED: " .. tostring(w.targetName)
            nameLbl.TextColor3 = Color3.fromRGB(255, 150, 40)
            nameLbl.TextSize = 14
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            nameLbl.Parent = item

            local reasonLbl = Instance.new("TextLabel")
            reasonLbl.Size = UDim2.new(1, -16, 0, 50)
            reasonLbl.Position = UDim2.new(0, 8, 0, 30)
            reasonLbl.BackgroundTransparency = 1
            reasonLbl.Text = "Reason: " .. tostring(w.reviewReason or w.reason)
            reasonLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
            reasonLbl.TextSize = 12
            reasonLbl.Font = Enum.Font.Gotham
            reasonLbl.TextXAlignment = Enum.TextXAlignment.Left
            reasonLbl.TextYAlignment = Enum.TextYAlignment.Top
            reasonLbl.TextWrapped = true
            reasonLbl.Parent = item

            local wid = w.id
            local clearBtn = Instance.new("TextButton")
            clearBtn.Size = UDim2.new(0, 80, 0, 24)
            clearBtn.Position = UDim2.new(1, -88, 0, 6)
            clearBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
            clearBtn.Text = "Clear"
            clearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            clearBtn.TextSize = 12
            clearBtn.Font = Enum.Font.GothamBold
            clearBtn.Parent = item
            corner(clearBtn, 4)

            clearBtn.MouseButton1Click:Connect(function()
                local target = nil
                for _, tw in ipairs(Warrants) do
                    if tw.id == wid then
                        tw.status = "cleared"
                        target = tw
                        break
                    end
                end
                if target then
                    addRecord({
                        warrantId = target.id,
                        targetName = target.targetName,
                        kind = "cleared",
                        reason = target.reason,
                        reviewReason = target.reviewReason,
                        filerDisplay = target.filedBy,
                        filerUser = target.filedByUser,
                        reviewerDisplay = LocalPlayer.DisplayName,
                        reviewerUser = LocalPlayer.Name,
                        timestamp = getTimestamp(),
                    })
                    saveJsonFile("warrants.json", Warrants)
                    showToast("Cleared warrant for " .. tostring(target.targetName), Color3.fromRGB(100, 80, 80), 2)
                    refreshWanted()
                    if refreshRecordsFor then refreshRecordsFor() end
                end
            end)
        end
    end

    if not any then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 60)
        lbl.BackgroundTransparency = 1
        lbl.Text = "No wanted players."
        lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        lbl.TextSize = 13
        lbl.Font = Enum.Font.Gotham
        lbl.Parent = WantedList
    end
end
refreshWanted()

local RecordsTab = Instance.new("Frame")
RecordsTab.Size = UDim2.new(1, 0, 1, 0)
RecordsTab.BackgroundTransparency = 1
RecordsTab.Visible = false
RecordsTab.Parent = ContentArea

local selectedRecordsPlayer = nil

buildPlayerListPanel(RecordsTab, function(p)
    selectedRecordsPlayer = p
    recordsSelectedLabel.Text = "Records: " .. p.Name
    if refreshRecordsFor then refreshRecordsFor() end
end)

local recordsRight = Instance.new("Frame")
recordsRight.Size = UDim2.new(1, -143, 1, 0)
recordsRight.Position = UDim2.new(0, 143, 0, 0)
recordsRight.BackgroundTransparency = 1
recordsRight.Parent = RecordsTab

local recordsSelectedLabel = Instance.new("TextLabel")
recordsSelectedLabel.Size = UDim2.new(1, 0, 0, 26)
recordsSelectedLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
recordsSelectedLabel.Text = "Select a player"
recordsSelectedLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
recordsSelectedLabel.TextSize = 12
recordsSelectedLabel.Font = Enum.Font.GothamBold
recordsSelectedLabel.TextTruncate = Enum.TextTruncate.AtEnd
recordsSelectedLabel.Parent = recordsRight
corner(recordsSelectedLabel, 6)

local RecordsList = Instance.new("ScrollingFrame")
RecordsList.Size = UDim2.new(1, 0, 1, -32)
RecordsList.Position = UDim2.new(0, 0, 0, 32)
RecordsList.BackgroundTransparency = 1
RecordsList.BorderSizePixel = 0
RecordsList.ScrollBarThickness = 4
RecordsList.CanvasSize = UDim2.new(0, 0, 0, 0)
RecordsList.Parent = recordsRight

local recordsLayout = Instance.new("UIListLayout")
recordsLayout.Padding = UDim.new(0, 6)
recordsLayout.Parent = RecordsList
recordsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    RecordsList.CanvasSize = UDim2.new(0, 0, 0, recordsLayout.AbsoluteContentSize.Y + 8)
end)

local function buildRecordText(r)
    if r.kind == "filed" then
        return "APB\nWarrant filed: " .. tostring(r.reason) ..
               "\nBy " .. tostring(r.filerUser or r.filerDisplay) .. " " .. tostring(r.timestamp)
    elseif r.kind == "approved" then
        return "APB\nWarrant approved | Reason: " .. tostring(r.reason) ..
               " Filed by: " .. tostring(r.filerDisplay) ..
               " | Approved by: " .. tostring(r.reviewerDisplay) ..
               "\nBy " .. tostring(r.reviewerUser or r.reviewerDisplay) .. "\n" .. tostring(r.timestamp)
    elseif r.kind == "denied" then
        return "APB\nWarrant denied | Reason: " .. tostring(r.reviewReason or r.reason) ..
               " Filed by: " .. tostring(r.filerDisplay) ..
               " | Denied by: " .. tostring(r.reviewerDisplay) ..
               "\nBy " .. tostring(r.reviewerUser or r.reviewerDisplay) .. "\n" .. tostring(r.timestamp)
    elseif r.kind == "cleared" then
        return "APB\nWarrant cleared | Reason: " .. tostring(r.reviewReason or r.reason) ..
               " | Cleared by: " .. tostring(r.reviewerDisplay) ..
               "\nBy " .. tostring(r.reviewerUser or r.reviewerDisplay) .. "\n" .. tostring(r.timestamp)
    else
        return "APB\nUnknown record"
    end
end

refreshRecordsFor = function()
    for _, c in ipairs(RecordsList:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end

    if not selectedRecordsPlayer then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 40)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Select a player to view their records."
        lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Gotham
        lbl.TextWrapped = true
        lbl.Parent = RecordsList
        return
    end

    local matching = {}
    for _, r in ipairs(Records) do
        if r.targetName == selectedRecordsPlayer.Name then
            table.insert(matching, r)
        end
    end

    if #matching == 0 then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 40)
        lbl.BackgroundTransparency = 1
        lbl.Text = "No records for " .. selectedRecordsPlayer.Name
        lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Gotham
        lbl.TextWrapped = true
        lbl.Parent = RecordsList
        return
    end

    for _, r in ipairs(matching) do
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -6, 0, 130)
        item.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        item.BorderSizePixel = 0
        item.Parent = RecordsList
        corner(item, 6)

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 8)
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)
        pad.Parent = item

        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.Text = buildRecordText(r)
        txt.TextColor3 = Color3.fromRGB(220, 220, 220)
        txt.TextSize = 11
        txt.Font = Enum.Font.Code
        txt.TextXAlignment = Enum.TextXAlignment.Left
        txt.TextYAlignment = Enum.TextYAlignment.Top
        txt.TextWrapped = true
        txt.Parent = item
    end
end
refreshRecordsFor()

local GameTab = Instance.new("Frame")
GameTab.Size = UDim2.new(1, 0, 1, 0)
GameTab.BackgroundTransparency = 1
GameTab.Visible = false
GameTab.Parent = ContentArea

local gameArea = Instance.new("Frame")
gameArea.Name = "GameArea"
gameArea.Size = UDim2.new(1, 0, 1, -40)
gameArea.Position = UDim2.new(0, 0, 0, 0)
gameArea.BackgroundColor3 = Color3.fromRGB(28, 38, 52)
gameArea.BorderSizePixel = 0
gameArea.ClipsDescendants = true
gameArea.Parent = GameTab
corner(gameArea, 10)

local scoreLabel = Instance.new("TextLabel")
scoreLabel.Size = UDim2.new(1, 0, 0, 42)
scoreLabel.Position = UDim2.new(0, 0, 0, 12)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Text = "0"
scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
scoreLabel.TextStrokeTransparency = 0
scoreLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
scoreLabel.TextSize = 36
scoreLabel.Font = Enum.Font.GothamBold
scoreLabel.ZIndex = 5
scoreLabel.Parent = gameArea

local gameHint = Instance.new("TextLabel")
gameHint.Size = UDim2.new(1, 0, 1, 0)
gameHint.BackgroundTransparency = 1
gameHint.Text = "Tap Start to play\n\nTap the area to flap"
gameHint.TextColor3 = Color3.fromRGB(255, 255, 255)
gameHint.TextStrokeTransparency = 0
gameHint.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
gameHint.TextSize = 14
gameHint.Font = Enum.Font.GothamBold
gameHint.TextWrapped = true
gameHint.ZIndex = 4
gameHint.Parent = gameArea

local bird = Instance.new("Frame")
bird.Size = UDim2.new(0, 26, 0, 18)
bird.Position = UDim2.new(0, 60, 0.5, -9)
bird.BackgroundColor3 = Color3.fromRGB(255, 190, 50)
bird.BorderSizePixel = 0
bird.ZIndex = 3
bird.Visible = false
bird.Rotation = 0
bird.Parent = gameArea
corner(bird, 4)

local gameBtn = Instance.new("TextButton")
gameBtn.Size = UDim2.new(1, 0, 0, 32)
gameBtn.Position = UDim2.new(0, 0, 1, -34)
gameBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 60)
gameBtn.Text = "Start"
gameBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
gameBtn.TextSize = 14
gameBtn.Font = Enum.Font.GothamBold
gameBtn.Parent = GameTab
corner(gameBtn, 6)

local gameState = {
    running = false,
    y = 0,
    vy = 0,
    score = 0,
    speed = 130,
    spawnTimer = 0,
    spawnInterval = 1.6,
    pipes = {},
    gap = 90,
    pipeW = 46,
    birdW = 26,
    birdH = 18,
    birdX = 60,
    gravity = 500,
    flapPower = -230,
    hasStarted = false,
}

local function clearPipes()
    for _, p in ipairs(gameState.pipes) do
        pcall(function() p.top:Destroy() end)
        pcall(function() p.bottom:Destroy() end)
    end
    gameState.pipes = {}
end

local function spawnPipe()
    local areaH = gameArea.AbsoluteSize.Y
    local areaW = gameArea.AbsoluteSize.X
    if areaH < 80 or areaW < 80 then return end
    local gap = gameState.gap
    local pipeW = gameState.pipeW
    local minTop = 30
    local maxTop = areaH - gap - 30
    if maxTop < minTop then maxTop = minTop end
    local gapY = math.random(minTop, math.floor(maxTop))

    local top = Instance.new("Frame")
    top.Size = UDim2.new(0, pipeW, 0, gapY)
    top.Position = UDim2.new(0, areaW, 0, 0)
    top.BackgroundColor3 = Color3.fromRGB(85, 195, 100)
    top.BorderSizePixel = 0
    top.ZIndex = 2
    top.Parent = gameArea
    corner(top, 4)

    local bottom = Instance.new("Frame")
    bottom.Size = UDim2.new(0, pipeW, 0, math.max(areaH - gapY - gap, 0))
    bottom.Position = UDim2.new(0, areaW, 0, gapY + gap)
    bottom.BackgroundColor3 = Color3.fromRGB(85, 195, 100)
    bottom.BorderSizePixel = 0
    bottom.ZIndex = 2
    bottom.Parent = gameArea
    corner(bottom, 4)

    table.insert(gameState.pipes, {
        top = top, bottom = bottom,
        x = areaW,
        gapY = gapY,
        gap = gap,
        pipeW = pipeW,
        passed = false,
    })
end

local function resetGame()
    gameState.running = false
    gameState.score = 0
    gameState.speed = 130
    gameState.spawnTimer = 0
    gameState.spawnInterval = 1.6
    gameState.vy = 0
    gameState.hasStarted = false
    clearPipes()

    local areaH = gameArea.AbsoluteSize.Y
    gameState.y = areaH / 2 - gameState.birdH / 2
    if gameState.y < 0 then gameState.y = 20 end

    bird.Position = UDim2.new(0, gameState.birdX, 0, gameState.y)
    bird.Rotation = 0
    bird.Visible = false
    scoreLabel.Text = "0"
    gameHint.Visible = true
end

local function gameOver()
    gameState.running = false
    gameBtn.Text = "Play Again"
    gameHint.Text = "Game Over\nScore: " .. gameState.score .. "\n\nTap to try again"
    gameHint.Visible = true
    showToast("Flappy Score: " .. gameState.score, Color3.fromRGB(140, 100, 30), 2.5)
end

gameBtn.MouseButton1Click:Connect(function()
    resetGame()
    gameState.running = true
    gameState.hasStarted = false
    gameState.vy = gameState.flapPower
    bird.Visible = true
    gameHint.Visible = false
    gameBtn.Text = "Restart"
end)

gameArea.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        if gameState.running then
            gameState.vy = gameState.flapPower
        end
    end
end)

RunService.RenderStepped:Connect(function(dt)
    if not gameState.running then return end
    if not GameTab.Visible then return end
    if not MainFrame.Visible then return end
    if dt > 0.2 then dt = 0.2 end

    local areaW = gameArea.AbsoluteSize.X
    local areaH = gameArea.AbsoluteSize.Y
    if areaH < 80 or areaW < 80 then return end

    gameState.vy = gameState.vy + gameState.gravity * dt
    gameState.y = gameState.y + gameState.vy * dt

    if gameState.y < 0 then
        gameState.y = 0
        gameState.vy = 0
    end
    if gameState.y + gameState.birdH > areaH then
        bird.Position = UDim2.new(0, gameState.birdX, 0, gameState.y)
        gameOver()
        return
    end

    bird.Position = UDim2.new(0, gameState.birdX, 0, gameState.y)

    local targetRot = math.clamp(gameState.vy * 0.06, -30, 45)
    bird.Rotation = targetRot

    gameState.spawnTimer = gameState.spawnTimer + dt
    if gameState.spawnTimer >= gameState.spawnInterval then
        gameState.spawnTimer = 0
        spawnPipe()
    end

    local px = gameState.birdX
    local pw = gameState.birdW
    local py = gameState.y
    local ph = gameState.birdH

    for i = #gameState.pipes, 1, -1 do
        local p = gameState.pipes[i]
        p.x = p.x - gameState.speed * dt
        p.top.Position = UDim2.new(0, p.x, 0, 0)
        p.bottom.Position = UDim2.new(0, p.x, 0, p.gapY + p.gap)

        if not p.passed and (p.x + p.pipeW) < px then
            p.passed = true
            gameState.score = gameState.score + 1
            scoreLabel.Text = tostring(gameState.score)
            gameState.speed = gameState.speed + 7
            gameState.spawnInterval = math.max(0.85, gameState.spawnInterval - 0.045)
        end

        if (p.x + p.pipeW) < 0 then
            pcall(function() p.top:Destroy() end)
            pcall(function() p.bottom:Destroy() end)
            table.remove(gameState.pipes, i)
        else
            local overlapX = (p.x < px + pw) and (p.x + p.pipeW > px)
            if overlapX then
                if py < p.gapY or (py + ph) > (p.gapY + p.gap) then
                    gameOver()
                    return
                end
            end
        end
    end
end)

local ESPTab = Instance.new("Frame")
ESPTab.Size = UDim2.new(1, 0, 1, 0)
ESPTab.BackgroundTransparency = 1
ESPTab.Visible = false
ESPTab.Parent = ContentArea

local ESPList = Instance.new("ScrollingFrame")
ESPList.Size = UDim2.new(1, 0, 1, 0)
ESPList.BackgroundTransparency = 1
ESPList.BorderSizePixel = 0
ESPList.ScrollBarThickness = 4
ESPList.CanvasSize = UDim2.new(0, 0, 0, 400)
ESPList.Parent = ESPTab

local espLayout = Instance.new("UIListLayout")
espLayout.Padding = UDim.new(0, 4)
espLayout.SortOrder = Enum.SortOrder.LayoutOrder
espLayout.Parent = ESPList
espLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ESPList.CanvasSize = UDim2.new(0, 0, 0, espLayout.AbsoluteContentSize.Y + 12)
end)

local openColorPicker, refreshTeamList

makeCheckRow(ESPList, "Activate ESP", false, function(on)
    ESP.enabled = on
    if not on then clearAllESP() end
    showToast(on and "ESP on" or "ESP off", Color3.fromRGB(70, 70, 90), 1.2)
end)

makeColorRow(ESPList, "ESP Color", ESP.color, function(swatch)
    openColorPicker("ESP Color", ESP.color, function(c)
        ESP.color = c
        swatch.BackgroundColor3 = c
    end)
end)

makeCheckRow(ESPList, "Exclude Own Team", false, function(on) ESP.excludeTeam = on end)

makeCheckRow(ESPList, "Team Color", false, function(on)
    ESP.teamColor = on
    if refreshTeamList then refreshTeamList() end
end)

makeCheckRow(ESPList, "Show Studs (distance)", false, function(on) ESP.showStuds = on end)

makeCheckRow(ESPList, "Show Health Bar", false, function(on) ESP.showHealth = on end)

local TeamHeader = Instance.new("TextLabel")
TeamHeader.Size = UDim2.new(1, -6, 0, 22)
TeamHeader.BackgroundTransparency = 1
TeamHeader.Text = "Team Colors:"
TeamHeader.TextColor3 = Color3.fromRGB(180, 180, 180)
TeamHeader.TextSize = 13
TeamHeader.Font = Enum.Font.GothamBold
TeamHeader.TextXAlignment = Enum.TextXAlignment.Left
TeamHeader.Visible = false
TeamHeader.Parent = ESPList

local teamRowRefs = {}

refreshTeamList = function()
    for _, r in ipairs(teamRowRefs) do r:Destroy() end
    teamRowRefs = {}
    if not ESP.teamColor then TeamHeader.Visible = false; return end
    TeamHeader.Visible = true

    local teams = Teams:GetTeams()
    if #teams == 0 then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 26)
        lbl.BackgroundTransparency = 1
        lbl.Text = "  (No teams in this game)"
        lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        lbl.TextSize = 13
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = ESPList
        table.insert(teamRowRefs, lbl)
        return
    end

    for _, team in ipairs(teams) do
        if not ESP.teamColors[team.Name] then
            ESP.teamColors[team.Name] = team.TeamColor and team.TeamColor.Color or Color3.fromRGB(255, 255, 255)
        end
        local swatch = makeColorRow(ESPList, "  " .. team.Name, ESP.teamColors[team.Name], function(sw)
            openColorPicker(team.Name .. " Color", ESP.teamColors[team.Name], function(c)
                ESP.teamColors[team.Name] = c
                sw.BackgroundColor3 = c
            end)
        end)
        table.insert(teamRowRefs, swatch.Parent)
    end
end

local TPTab = Instance.new("Frame")
TPTab.Size = UDim2.new(1, 0, 1, 0)
TPTab.BackgroundTransparency = 1
TPTab.Visible = false
TPTab.Parent = ContentArea

local giveToolBtn = Instance.new("TextButton")
giveToolBtn.Size = UDim2.new(1, 0, 0, 36)
giveToolBtn.Position = UDim2.new(0, 0, 0, 0)
giveToolBtn.BackgroundColor3 = Color3.fromRGB(70, 120, 120)
giveToolBtn.Text = "Give Click TP Tool"
giveToolBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
giveToolBtn.TextSize = 14
giveToolBtn.Font = Enum.Font.GothamBold
giveToolBtn.Parent = TPTab
corner(giveToolBtn, 6)

local tpLabel = Instance.new("TextLabel")
tpLabel.Size = UDim2.new(1, 0, 0, 22)
tpLabel.Position = UDim2.new(0, 0, 0, 42)
tpLabel.BackgroundTransparency = 1
tpLabel.Text = "Players in server:"
tpLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
tpLabel.TextSize = 13
tpLabel.Font = Enum.Font.GothamBold
tpLabel.TextXAlignment = Enum.TextXAlignment.Left
tpLabel.Parent = TPTab

local TPList = Instance.new("ScrollingFrame")
TPList.Size = UDim2.new(1, 0, 1, -72)
TPList.Position = UDim2.new(0, 0, 0, 68)
TPList.BackgroundTransparency = 1
TPList.BorderSizePixel = 0
TPList.ScrollBarThickness = 4
TPList.CanvasSize = UDim2.new(0, 0, 0, 100)
TPList.Parent = TPTab

local tpLayout = Instance.new("UIListLayout")
tpLayout.Padding = UDim.new(0, 4)
tpLayout.Parent = TPList
tpLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TPList.CanvasSize = UDim2.new(0, 0, 0, tpLayout.AbsoluteContentSize.Y + 8)
end)

local function giveClickTP()
    local char = LocalPlayer.Character
    if not char then showToast("No character", Color3.fromRGB(140, 50, 50), 2) return end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not bp then showToast("No backpack", Color3.fromRGB(140, 50, 50), 2) return end
    local existing = bp:FindFirstChild("ClickTP") or char:FindFirstChild("ClickTP")
    if existing then existing:Destroy() end

    local tool = Instance.new("Tool")
    tool.Name = "ClickTP"
    tool.RequiresHandle = false
    tool.CanBeDropped = false
    tool.Parent = bp

    tool.Activated:Connect(function()
        local mouse = LocalPlayer:GetMouse()
        local hit = mouse.Hit
        if hit then
            local c = LocalPlayer.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0))
                showToast("Teleported to click", Color3.fromRGB(60, 120, 120), 1.5)
            end
        end
    end)
    showToast("Click TP tool given", Color3.fromRGB(60, 120, 120), 2)
end

giveToolBtn.MouseButton1Click:Connect(giveClickTP)

local function refreshTPList()
    for _, c in ipairs(TPList:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -6, 0, 34)
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        btn.Text = "-> " .. p.Name
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 14
        btn.Font = Enum.Font.Gotham
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = TPList
        corner(btn, 6)
        local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 10); pad.Parent = btn

        btn.MouseButton1Click:Connect(function()
            local myChar = LocalPlayer.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local tChar = p.Character
            local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
            if not myHrp or not tHrp then showToast("Target unavailable", Color3.fromRGB(140, 50, 50), 2) return end
            myHrp.CFrame = tHrp.CFrame + Vector3.new(0, 3, 0)
            showToast("Teleported to " .. p.Name, Color3.fromRGB(60, 120, 120), 2)
        end)
    end
end

Players.PlayerAdded:Connect(function() task.wait(0.5); refreshTPList() end)
Players.PlayerRemoving:Connect(function() task.wait(0.5); refreshTPList() end)
task.spawn(function()
    task.wait(0.5)
    refreshTPList()
end)

local CharTab = Instance.new("Frame")
CharTab.Size = UDim2.new(1, 0, 1, 0)
CharTab.BackgroundTransparency = 1
CharTab.Visible = false
CharTab.Parent = ContentArea

local CharList = Instance.new("ScrollingFrame")
CharList.Size = UDim2.new(1, 0, 1, 0)
CharList.BackgroundTransparency = 1
CharList.BorderSizePixel = 0
CharList.ScrollBarThickness = 4
CharList.CanvasSize = UDim2.new(0, 0, 0, 400)
CharList.Parent = CharTab

local charLayout = Instance.new("UIListLayout")
charLayout.Padding = UDim.new(0, 4)
charLayout.SortOrder = Enum.SortOrder.LayoutOrder
charLayout.Parent = CharList
charLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    CharList.CanvasSize = UDim2.new(0, 0, 0, charLayout.AbsoluteContentSize.Y + 12)
end)

local function applyWS(v)
    CharSettings.walkSpeed = v
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end
end

local function applyJP(v)
    CharSettings.jumpPower = v
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = v
        end
    end
end

makeSliderRow(CharList, "WalkSpeed", 8, 500, 16, false,
    function(v) applyWS(v) end,
    true,
    function()
        CharSettings.walkSpeed = nil
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
        showToast("WalkSpeed reset", Color3.fromRGB(70, 90, 70), 1.5)
    end)

makeSliderRow(CharList, "JumpPower", 30, 500, 50, false,
    function(v) applyJP(v) end,
    true,
    function()
        CharSettings.jumpPower = nil
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = 50
            end
        end
        showToast("JumpPower reset", Color3.fromRGB(70, 90, 70), 1.5)
    end)

makeCheckRow(CharList, "Infinite Jump", false, function(on)
    InfiniteJump.enabled = on
    showToast(on and "Infinite Jump on" or "Infinite Jump off", Color3.fromRGB(70, 70, 90), 1.2)
end)

makeCheckRow(CharList, "Noclip", false, function(on)
    Noclip.enabled = on
    if not on then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
    showToast(on and "Noclip on" or "Noclip off", Color3.fromRGB(70, 70, 90), 1.2)
end)

makeCheckRow(CharList, "Freecam", false, function(on)
    Freecam.enabled = on
    local cam = workspace.CurrentCamera
    if not cam then return end
    if on then
        Freecam.saved = {
            CameraType = cam.CameraType,
            CameraSubject = cam.CameraSubject,
            CFrame = cam.CFrame,
        }
        cam.CameraType = Enum.CameraType.Scriptable
        showToast("Freecam on", Color3.fromRGB(70, 70, 90), 2)
    else
        if Freecam.saved then
            pcall(function()
                cam.CameraType = Freecam.saved.CameraType
                cam.CameraSubject = Freecam.saved.CameraSubject
                cam.CFrame = Freecam.saved.CFrame
            end)
        end
        Freecam.saved = nil
        freecamTouch = nil
        showToast("Freecam off", Color3.fromRGB(70, 70, 90), 1.2)
    end
end)

local ServerTab = Instance.new("Frame")
ServerTab.Size = UDim2.new(1, 0, 1, 0)
ServerTab.BackgroundTransparency = 1
ServerTab.Visible = false
ServerTab.Parent = ContentArea

local ServerList = Instance.new("ScrollingFrame")
ServerList.Size = UDim2.new(1, 0, 1, 0)
ServerList.BackgroundTransparency = 1
ServerList.BorderSizePixel = 0
ServerList.ScrollBarThickness = 4
ServerList.CanvasSize = UDim2.new(0, 0, 0, 500)
ServerList.Parent = ServerTab

local serverLayout = Instance.new("UIListLayout")
serverLayout.Padding = UDim.new(0, 6)
serverLayout.SortOrder = Enum.SortOrder.LayoutOrder
serverLayout.Parent = ServerList
serverLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ServerList.CanvasSize = UDim2.new(0, 0, 0, serverLayout.AbsoluteContentSize.Y + 12)
end)

local function infoLabel(text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -6, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = ServerList
    return lbl
end

local placeLbl  = infoLabel("Place: " .. tostring(game.Name))
local pidLbl    = infoLabel("PlaceId: " .. tostring(game.PlaceId))
local jobLbl    = infoLabel("Job ID: " .. tostring(game.JobId))
local playersLbl = infoLabel("Players: ?/?")
local pingLbl   = infoLabel("Ping: ?ms")

local function bigBtn(text, color, onClick)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -6, 0, 34)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 14
    b.Font = Enum.Font.GothamBold
    b.Parent = ServerList
    corner(b, 6)
    b.MouseButton1Click:Connect(onClick)
    return b
end

bigBtn("Copy Job ID", Color3.fromRGB(70, 70, 120), function()
    if typeof(setclipboard) == "function" then
        pcall(setclipboard, game.JobId)
        showToast("Job ID copied", Color3.fromRGB(60, 100, 120), 2)
    else
        showToast("setclipboard not available", Color3.fromRGB(140, 50, 50), 2)
    end
end)

bigBtn("Rejoin Server", Color3.fromRGB(70, 120, 90), function()
    showToast("Rejoining...", Color3.fromRGB(70, 90, 90), 2)
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end)

bigBtn("Server Hop", Color3.fromRGB(70, 100, 140), function()
    showToast("Finding server...", Color3.fromRGB(80, 80, 140), 2)
    task.spawn(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local ok, result = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
        if ok and result and result.data then
            for _, server in ipairs(result.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                    end)
                    showToast("Hopping...", Color3.fromRGB(70, 120, 90), 2)
                    return
                end
            end
            showToast("No servers found", Color3.fromRGB(140, 50, 50), 2)
        else
            showToast("Failed to fetch servers", Color3.fromRGB(140, 50, 50), 2)
        end
    end)
end)

task.spawn(function()
    while task.wait(1) do
        if placeLbl.Parent then
            placeLbl.Text = "Place: " .. tostring(game.Name)
            pidLbl.Text = "PlaceId: " .. tostring(game.PlaceId)
            jobLbl.Text = "Job ID: " .. tostring(game.JobId)
            playersLbl.Text = "Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
            local ok, ping = pcall(function()
                return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
            end)
            pingLbl.Text = "Ping: " .. (ok and string.format("%.0f", ping) or "?") .. "ms"
        end
    end
end)

local UtilityTab = Instance.new("Frame")
UtilityTab.Size = UDim2.new(1, 0, 1, 0)
UtilityTab.BackgroundTransparency = 1
UtilityTab.Visible = false
UtilityTab.Parent = ContentArea

local UtilList = Instance.new("ScrollingFrame")
UtilList.Size = UDim2.new(1, 0, 1, 0)
UtilList.BackgroundTransparency = 1
UtilList.BorderSizePixel = 0
UtilList.ScrollBarThickness = 4
UtilList.CanvasSize = UDim2.new(0, 0, 0, 300)
UtilList.Parent = UtilityTab

local utilLayout = Instance.new("UIListLayout")
utilLayout.Padding = UDim.new(0, 4)
utilLayout.SortOrder = Enum.SortOrder.LayoutOrder
utilLayout.Parent = UtilList
utilLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    UtilList.CanvasSize = UDim2.new(0, 0, 0, utilLayout.AbsoluteContentSize.Y + 8)
end)

makeCheckRow(UtilList, "Fullbright", false, function(on)
    if on then
        if not Fullbright.saved then
            Fullbright.saved = {
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                Brightness = Lighting.Brightness,
                FogEnd = Lighting.FogEnd,
                FogStart = Lighting.FogStart,
            }
        end
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        Lighting.Brightness = 2
        Lighting.FogEnd = 1e6
        Lighting.FogStart = 1e6
        showToast("Fullbright on", Color3.fromRGB(90, 90, 90), 1.5)
    else
        if Fullbright.saved then
            pcall(function()
                Lighting.Ambient = Fullbright.saved.Ambient
                Lighting.OutdoorAmbient = Fullbright.saved.OutdoorAmbient
                Lighting.Brightness = Fullbright.saved.Brightness
                Lighting.FogEnd = Fullbright.saved.FogEnd
                Lighting.FogStart = Fullbright.saved.FogStart
            end)
            Fullbright.saved = nil
        end
        showToast("Fullbright off", Color3.fromRGB(90, 90, 90), 1.5)
    end
end)

makeSliderRow(UtilList, "FPS Cap", 30, 360, 60, false,
    function(v)
        if typeof(setfpscap) == "function" then pcall(setfpscap, math.floor(v)) end
    end,
    true,
    function()
        if typeof(setfpscap) == "function" then pcall(setfpscap, 60) end
        showToast("FPS cap reset to 60", Color3.fromRGB(90, 90, 90), 1.5)
    end)

local ConsoleTab = Instance.new("Frame")
ConsoleTab.Size = UDim2.new(1, 0, 1, 0)
ConsoleTab.BackgroundTransparency = 1
ConsoleTab.Visible = false
ConsoleTab.Parent = ContentArea

local ConsoleList = Instance.new("ScrollingFrame")
ConsoleList.Size = UDim2.new(1, 0, 1, -40)
ConsoleList.Position = UDim2.new(0, 0, 0, 0)
ConsoleList.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
ConsoleList.BorderSizePixel = 0
ConsoleList.ScrollBarThickness = 3
ConsoleList.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
ConsoleList.CanvasSize = UDim2.new(0, 0, 0, 0)
ConsoleList.Parent = ConsoleTab
corner(ConsoleList, 6)

local consoleLayout = Instance.new("UIListLayout")
consoleLayout.Padding = UDim.new(0, 1)
consoleLayout.Parent = ConsoleList
consoleLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ConsoleList.CanvasSize = UDim2.new(0, 0, 0, consoleLayout.AbsoluteContentSize.Y + 4)
end)

local consolePad = Instance.new("UIPadding")
consolePad.PaddingLeft = UDim.new(0, 6)
consolePad.PaddingTop = UDim.new(0, 4)
consolePad.Parent = ConsoleList

consoleUIUpdater = function()
    if not ConsoleList or not ConsoleList.Parent then return end
    for _, c in ipairs(ConsoleList:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    if #ConsoleLogs == 0 then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.Text = "(no output yet)"
        lbl.TextColor3 = Color3.fromRGB(120, 120, 120)
        lbl.TextSize = 11
        lbl.Font = Enum.Font.Code
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = ConsoleList
    else
        for _, log in ipairs(ConsoleLogs) do
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -6, 0, 16)
            lbl.BackgroundTransparency = 1
            lbl.Text = "[" .. log.level .. "] " .. log.text
            if log.level == "warn" then
                lbl.TextColor3 = Color3.fromRGB(255, 200, 100)
            elseif log.level == "error" then
                lbl.TextColor3 = Color3.fromRGB(255, 110, 110)
            else
                lbl.TextColor3 = Color3.fromRGB(200, 220, 200)
            end
            lbl.TextSize = 11
            lbl.Font = Enum.Font.Code
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextTruncate = Enum.TextTruncate.AtEnd
            lbl.Parent = ConsoleList
        end
        task.defer(function()
            pcall(function()
                ConsoleList.CanvasPosition = Vector2.new(0, ConsoleList.AbsoluteCanvasSize.Y)
            end)
        end)
    end
end

local copyConsoleBtn = Instance.new("TextButton")
copyConsoleBtn.Size = UDim2.new(0.5, -4, 0, 32)
copyConsoleBtn.Position = UDim2.new(0, 0, 1, -36)
copyConsoleBtn.BackgroundColor3 = Color3.fromRGB(70, 100, 120)
copyConsoleBtn.Text = "Copy Logs"
copyConsoleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyConsoleBtn.TextSize = 13
copyConsoleBtn.Font = Enum.Font.GothamBold
copyConsoleBtn.Parent = ConsoleTab
corner(copyConsoleBtn, 6)

local clearConsoleBtn = Instance.new("TextButton")
clearConsoleBtn.Size = UDim2.new(0.5, -4, 0, 32)
clearConsoleBtn.Position = UDim2.new(0.5, 4, 1, -36)
clearConsoleBtn.BackgroundColor3 = Color3.fromRGB(120, 70, 70)
clearConsoleBtn.Text = "Clear"
clearConsoleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
clearConsoleBtn.TextSize = 13
clearConsoleBtn.Font = Enum.Font.GothamBold
clearConsoleBtn.Parent = ConsoleTab
corner(clearConsoleBtn, 6)

copyConsoleBtn.MouseButton1Click:Connect(function()
    if typeof(setclipboard) ~= "function" then
        showToast("setclipboard not available", Color3.fromRGB(140, 50, 50), 2)
        return
    end
    local out = {}
    for _, log in ipairs(ConsoleLogs) do
        table.insert(out, "[" .. log.level .. "] " .. log.text)
    end
    pcall(setclipboard, table.concat(out, "\n"))
    showToast("Copied " .. #ConsoleLogs .. " logs", Color3.fromRGB(60, 100, 120), 2)
end)

clearConsoleBtn.MouseButton1Click:Connect(function()
    for i = #ConsoleLogs, 1, -1 do ConsoleLogs[i] = nil end
    if consoleUIUpdater then pcall(consoleUIUpdater) end
    showToast("Console cleared", Color3.fromRGB(80, 60, 60), 1.5)
end)

openColorPicker = function(title, initialColor, onConfirm)
    local picker = Instance.new("Frame")
    picker.Size = UDim2.new(1, -30, 0, 260)
    picker.Position = UDim2.new(0, 15, 0.5, -130)
    picker.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    picker.BorderSizePixel = 0
    picker.ZIndex = 100
    picker.Parent = MainFrame
    corner(picker, 8)

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -20, 0, 25)
    t.Position = UDim2.new(0, 10, 0, 5)
    t.BackgroundTransparency = 1
    t.Text = title or "Pick Color"
    t.TextColor3 = Color3.fromRGB(255, 255, 255)
    t.TextSize = 15
    t.Font = Enum.Font.GothamBold
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.ZIndex = 101
    t.Parent = picker

    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(1, -20, 0, 28)
    preview.Position = UDim2.new(0, 10, 0, 32)
    preview.BackgroundColor3 = initialColor
    preview.BorderSizePixel = 0
    preview.ZIndex = 101
    preview.Parent = picker
    corner(preview, 4)

    local r = math.floor(initialColor.R * 255)
    local g = math.floor(initialColor.G * 255)
    local b = math.floor(initialColor.B * 255)

    local function update()
        preview.BackgroundColor3 = Color3.fromRGB(r, g, b)
    end

    local function makeSlider(y, label, val, setter)
        local cont = Instance.new("Frame")
        cont.Size = UDim2.new(1, -20, 0, 30)
        cont.Position = UDim2.new(0, 10, 0, y)
        cont.BackgroundTransparency = 1
        cont.ZIndex = 101
        cont.Parent = picker

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 20, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.TextSize = 14
        lbl.Font = Enum.Font.GothamBold
        lbl.ZIndex = 101
        lbl.Parent = cont

        local bar = Instance.new("TextButton")
        bar.Size = UDim2.new(1, -70, 0, 10)
        bar.Position = UDim2.new(0, 25, 0.5, -5)
        bar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        bar.Text = ""
        bar.AutoButtonColor = false
        bar.ZIndex = 101
        bar.Parent = cont
        corner(bar, 5)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(val / 255, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(120, 120, 200)
        fill.BorderSizePixel = 0
        fill.ZIndex = 102
        fill.Parent = bar
        corner(fill, 5)

        local vLbl = Instance.new("TextLabel")
        vLbl.Size = UDim2.new(0, 40, 1, 0)
        vLbl.Position = UDim2.new(1, -40, 0, 0)
        vLbl.BackgroundTransparency = 1
        vLbl.Text = tostring(math.floor(val))
        vLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        vLbl.TextSize = 13
        vLbl.Font = Enum.Font.Gotham
        vLbl.ZIndex = 101
        vLbl.Parent = cont

        local function setFromX(x)
            local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
            local v = rel * 255
            fill.Size = UDim2.new(rel, 0, 1, 0)
            vLbl.Text = tostring(math.floor(v))
            setter(v)
        end

        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                setFromX(input.Position.X)
                local c1, c2
                c1 = UserInputService.InputChanged:Connect(function(inp)
                    if inp == input then setFromX(inp.Position.X) end
                end)
                c2 = UserInputService.InputEnded:Connect(function(inp)
                    if inp == input then c1:Disconnect(); c2:Disconnect() end
                end)
            end
        end)
    end

    makeSlider(72,  "R", r, function(v) r = v update() end)
    makeSlider(106, "G", g, function(v) g = v update() end)
    makeSlider(140, "B", b, function(v) b = v update() end)

    local cancel = Instance.new("TextButton")
    cancel.Size = UDim2.new(0.5, -15, 0, 32)
    cancel.Position = UDim2.new(0, 10, 1, -42)
    cancel.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    cancel.Text = "Cancel"
    cancel.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancel.TextSize = 14
    cancel.Font = Enum.Font.Gotham
    cancel.ZIndex = 101
    cancel.Parent = picker
    corner(cancel, 6)

    local confirm = Instance.new("TextButton")
    confirm.Size = UDim2.new(0.5, -15, 0, 32)
    confirm.Position = UDim2.new(0.5, 5, 1, -42)
    confirm.BackgroundColor3 = Color3.fromRGB(60, 140, 60)
    confirm.Text = "OK"
    confirm.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirm.TextSize = 14
    confirm.Font = Enum.Font.GothamBold
    confirm.ZIndex = 101
    confirm.Parent = picker
    corner(confirm, 6)

    cancel.MouseButton1Click:Connect(function() picker:Destroy() end)
    confirm.MouseButton1Click:Connect(function()
        onConfirm(Color3.fromRGB(math.floor(r), math.floor(g), math.floor(b)))
        picker:Destroy()
    end)
end

local tabDefs = {
    { name = "Scripts",   frame = ScriptsTab,   color = Color3.fromRGB(70, 70, 120) },
    { name = "Hubs",      frame = HubsTab,      color = Color3.fromRGB(140, 100, 60) },
    { name = "Games",     frame = GamesTab,     color = Color3.fromRGB(120, 100, 60) },
    { name = "Chat",      frame = ChatTab,      color = Color3.fromRGB(80, 120, 120) },
    { name = "Warrant",   frame = WarrantTab,   color = Color3.fromRGB(200, 130, 50) },
    { name = "Pending",   frame = PendingTab,   color = Color3.fromRGB(180, 160, 60) },
    { name = "Wanted",    frame = WantedTab,    color = Color3.fromRGB(150, 50, 50) },
    { name = "Records",   frame = RecordsTab,   color = Color3.fromRGB(80, 120, 130) },
    { name = "Game",      frame = GameTab,      color = Color3.fromRGB(140, 70, 140) },
    { name = "ESP",       frame = ESPTab,       color = Color3.fromRGB(120, 70, 70) },
    { name = "Teleport",  frame = TPTab,        color = Color3.fromRGB(70, 120, 120) },
    { name = "Character", frame = CharTab,      color = Color3.fromRGB(70, 120, 70) },
    { name = "Server",    frame = ServerTab,    color = Color3.fromRGB(100, 70, 120) },
    { name = "Utility",   frame = UtilityTab,   color = Color3.fromRGB(100, 100, 100) },
    { name = "Console",   frame = ConsoleTab,   color = Color3.fromRGB(60, 80, 100) },
}
local tabButtons = {}

local function selectTab(i)
    for idx, def in ipairs(tabDefs) do
        def.frame.Visible = (idx == i)
        local btn = tabButtons[idx]
        if btn then
            btn.BackgroundColor3 = (idx == i) and def.color or Color3.fromRGB(40, 40, 40)
        end
    end
    if tabDefs[i] and tabDefs[i].frame == ConsoleTab then
        if consoleUIUpdater then pcall(consoleUIUpdater) end
    end
    if tabDefs[i] and tabDefs[i].frame == PendingTab then
        if refreshPending then pcall(refreshPending) end
    end
    if tabDefs[i] and tabDefs[i].frame == WantedTab then
        if refreshWanted then pcall(refreshWanted) end
    end
    if tabDefs[i] and tabDefs[i].frame == RecordsTab then
        if refreshRecordsFor then pcall(refreshRecordsFor) end
    end
end

for i, def in ipairs(tabDefs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 74, 0, 26)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.Text = def.name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.LayoutOrder = i
    btn.Parent = TabBar
    corner(btn, 5)
    btn.MouseButton1Click:Connect(function() selectTab(i) end)
    tabButtons[i] = btn
end

TabBar.CanvasSize = UDim2.new(0, #tabDefs * 78 + 8, 0, 0)
selectTab(1)

local Icon = Instance.new("TextButton")
Icon.Size = UDim2.new(0, 50, 0, 50)
Icon.Position = UDim2.new(0, 100, 0, 100)
Icon.BackgroundColor3 = Color3.fromRGB(50, 50, 200)
Icon.Text = "⚙"
Icon.TextColor3 = Color3.fromRGB(255, 255, 255)
Icon.TextSize = 30
Icon.Font = Enum.Font.GothamBold
Icon.Visible = false
Icon.Parent = ScreenGui
corner(Icon, 25)

local function toggleUI(show)
    MainFrame.Visible = show
    Icon.Visible = not show
end

CloseButton.MouseButton1Click:Connect(function() toggleUI(false) end)
Icon.MouseButton1Click:Connect(function() toggleUI(true) end)

local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
Icon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Icon.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
Icon.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        Icon.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

task.defer(function()
    task.wait(0.2)
    local areaH = gameArea.AbsoluteSize.Y
    if areaH > 80 then
        gameState.y = areaH / 2 - gameState.birdH / 2
        bird.Position = UDim2.new(0, gameState.birdX, 0, gameState.y)
    end
end)

end)

if not buildOk then
    warn("[Executor UI] Build error: " .. tostring(buildErr))
end

Players.PlayerRemoving:Connect(function(p)
    removeESP(p)
    local lbl = wantedLabels[p]
    if lbl then pcall(function() lbl:Destroy() end) end
    wantedLabels[p] = nil
end)

RunService.RenderStepped:Connect(function()
    if not ESP.enabled then return end
    local localChar = LocalPlayer.Character
    local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
    local localTeam = LocalPlayer.Team

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if ESP.excludeTeam and localTeam and player.Team == localTeam then
            removeESP(player); continue
        end
        local data = espObjects[player]
        if not data or data.character ~= player.Character then
            removeESP(player); createESP(player); data = espObjects[player]
        end
        if not data then continue end
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then
            data.billboard.Enabled = false
            data.highlight.Enabled = false
            continue
        end
        data.billboard.Enabled = true
        data.highlight.Enabled = true
        data.billboard.Adornee = hrp

        local color = ESP.color
        if ESP.teamColor and player.Team then
            color = ESP.teamColors[player.Team.Name] or ESP.color
        end
        data.highlight.FillColor = color
        data.highlight.OutlineColor = color
        data.nameLabel.TextColor3 = color
        data.nameLabel.Text = player.Name

        if ESP.showStuds and localHrp then
            local dist = (hrp.Position - localHrp.Position).Magnitude
            data.distLabel.Text = string.format("%d studs", math.floor(dist))
            data.distLabel.Visible = true
        else
            data.distLabel.Visible = false
        end

        if ESP.showHealth then
            data.healthBg.Visible = true
            local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
            data.healthFill.Size = UDim2.new(pct, 0, 1, 0)
            if pct > 0.6 then
                data.healthFill.BackgroundColor3 = Color3.fromRGB(60, 220, 60)
            elseif pct > 0.3 then
                data.healthFill.BackgroundColor3 = Color3.fromRGB(240, 200, 40)
            else
                data.healthFill.BackgroundColor3 = Color3.fromRGB(230, 40, 40)
            end
        else
            data.healthBg.Visible = false
        end
    end
end)

RunService.RenderStepped:Connect(function(dt)
    if not Freecam.enabled then return end
    local cam = workspace.CurrentCamera
    local char = LocalPlayer.Character
    if not cam or not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local move = hum.MoveDirection
    if move.Magnitude > 0 then
        cam.CFrame = cam.CFrame + move * Freecam.speed * dt
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        cam.CFrame = cam.CFrame + Vector3.new(0, Freecam.speed * dt, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        cam.CFrame = cam.CFrame - Vector3.new(0, Freecam.speed * dt, 0)
    end

    if freecamTouch then
        local pos = freecamTouch.Position
        if freecamLastPos then
            local delta = pos - freecamLastPos
            cam.CFrame = cam.CFrame * CFrame.Angles(0, -delta.X * 0.005, 0) * CFrame.Angles(-delta.Y * 0.005, 0, 0)
        end
        freecamLastPos = pos
    else
        freecamLastPos = nil
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not Freecam.enabled then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement and freecamMouseHeld then
        local cam = workspace.CurrentCamera
        if not cam then return end
        local delta = input.Delta
        cam.CFrame = cam.CFrame * CFrame.Angles(0, -delta.X * 0.005, 0) * CFrame.Angles(-delta.Y * 0.005, 0, 0)
    end
end)

task.spawn(function()
    while task.wait(1) do
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local char = player.Character
            local w = hasApprovedWarrant(player.Name)
            local existing = wantedLabels[player]

            if not w or not char then
                if existing then
                    pcall(function() existing:Destroy() end)
                    wantedLabels[player] = nil
                end
            else
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then
                    if existing then
                        pcall(function() existing:Destroy() end)
                        wantedLabels[player] = nil
                    end
                else
                    if existing and existing.Parent ~= char then
                        pcall(function() existing:Destroy() end)
                        wantedLabels[player] = nil
                        existing = nil
                    end
                    if not existing then
                        local bg = Instance.new("BillboardGui")
                        bg.Name = "WantedLabel"
                        bg.Size = UDim2.new(0, 110, 0, 24)
                        bg.StudsOffset = Vector3.new(0, 5, 0)
                        bg.AlwaysOnTop = true
                        bg.Adornee = hrp
                        bg.Parent = char

                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Text = "WANTED"
                        lbl.TextColor3 = Color3.fromRGB(255, 150, 40)
                        lbl.TextStrokeTransparency = 0
                        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        lbl.TextSize = 20
                        lbl.Font = Enum.Font.GothamBold
                        lbl.Parent = bg

                        wantedLabels[player] = bg
                    end
                end
            end
        end
    end
end)

print("[Executor UI] Loaded.")
