local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

if getgenv().Flex_Loaded then 
    getgenv().Flex_Loaded = false
    pcall(function() RunService:UnbindFromRenderStep("Flex_Aimbot_Engine") end)
    pcall(function() RunService:UnbindFromRenderStep("Flex_Core_Engine") end)
end
getgenv().Flex_Loaded = true

local Config = {
    Aimbot = true,
    AimKey = Enum.UserInputType.MouseButton2, 
    VisibleCheck = true, 
    ESP = true,
    TargetHUD = true,       
    BoxThickness = 2.0,       
    SkeletonThickness = 2.0,  
    TracerThickness = 1.5,    
    Speed = false,
    SpeedValue = 50, 
    HighJump = false,
    JumpValue = 50,
    Fly = false,
    FlyTP = false, 
    FlySpeed = 60, 
    FlyTPSpeed = 60, 
    Noclip = false,
    FlightLean = true, 
    FlightFlip = true, 
    ClickTP = false,
    Color_Accent = Color3.fromRGB(0, 255, 120), 
    Color_Friend = Color3.fromRGB(0, 170, 255), 
    MenuKey = Enum.KeyCode.RightShift,
    MenuOpen = true,
    Keybinds = {},
    Friends = {},
    
    -- EXTENSIONS
    TracerOrigin = "Bottom",
    SkeletonESP = false,
    InfJump = false,
    HoldJump = false,
    InfJumpValue = 50,
    Waypoints = {}
}

-- PER-GAME DATA ISOLATION
local PlaceId = game.PlaceId
local ConfigFileName = "Flex_Config_" .. tostring(PlaceId) .. ".json"
local UIStateFileName = "Flex_UI_States_" .. tostring(PlaceId) .. ".json"

local UIStates = {
    TpMenuVisible = false,
    FriendTpMenuVisible = false,
    WaypointMenuVisible = false
}

local function SaveUIStates()
    if writefile then
        pcall(function() writefile(UIStateFileName, HttpService:JSONEncode(UIStates)) end)
    end
end

local function LoadUIStates()
    if isfile and isfile(UIStateFileName) and readfile then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(UIStateFileName)) end)
        if success and type(decoded) == "table" then
            for k, v in pairs(decoded) do UIStates[k] = v end
        end
    end
end
pcall(LoadUIStates)

local function SaveConfig()
    local success, encoded = pcall(function()
        local dataToSave = {}
        for k, v in pairs(Config) do
            if k == "Keybinds" then
                dataToSave[k] = {}
                for kbKey, kbVal in pairs(v) do
                    dataToSave[k][kbKey] = kbVal.Name
                end
            elseif k == "Friends" or k == "Waypoints" then
                dataToSave[k] = v
            elseif typeof(v) == "Color3" then
                dataToSave[k] = {v.R, v.G, v.B}
            elseif typeof(v) == "EnumItem" then
                dataToSave[k] = tostring(v)
            else
                dataToSave[k] = v
            end
        end
        return HttpService:JSONEncode(dataToSave)
    end)
    if success and writefile then
        pcall(function() writefile(ConfigFileName, encoded) end)
    end
end

local function LoadConfig()
    if isfile and isfile(ConfigFileName) and readfile then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(ConfigFileName))
        end)
        if success then
            for k, v in pairs(decoded) do
                if Config[k] ~= nil then
                    if k == "Keybinds" then
                        for kbKey, kbVal in pairs(v) do
                            pcall(function() Config.Keybinds[kbKey] = Enum.KeyCode[kbVal] end)
                        end
                    elseif k == "Friends" then
                        Config.Friends = v or {}
                    elseif k == "Waypoints" then
                        Config.Waypoints = v or {}
                    elseif type(v) == "table" and #v == 3 then
                        Config[k] = Color3.new(v[1], v[2], v[3])
                    elseif k == "AimKey" or k == "MenuKey" then
                        pcall(function()
                            local stringEnum = tostring(v)
                            if string.find(stringEnum, "KeyCode") then
                                Config[k] = Enum.KeyCode[string.split(stringEnum, ".")[3]]
                            elseif string.find(stringEnum, "UserInputType") then
                                Config[k] = Enum.UserInputType[string.split(stringEnum, ".")[3]]
                            end
                        end)
                    else
                        Config[k] = v
                    end
                end
            end
        end
    end
end
pcall(LoadConfig)

local ESP_Cache = {}
local UI_Elements = { Toggles = {}, Sliders = {}, StatusLabels = {}, SectionLabels = {} }
local flightRotation = CFrame.new() 
local WasNoclip = false
local FlyVelocityInstance = nil
local FlyGyroInstance = nil

-- DYNAMIC SCROLL CONTAINER FIX
local function AutoCanvasSize(scrollingFrame, listLayout)
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 15)
    end)
end

local function UpdateSystemColor(newColor)
    Config.Color_Accent = newColor
    SaveConfig()
    if UI_Elements.TopLine then UI_Elements.TopLine.BackgroundColor3 = newColor end
    if UI_Elements.TpTitle then UI_Elements.TpTitle.TextColor3 = newColor end
    if UI_Elements.FriendTpTitle then UI_Elements.FriendTpTitle.TextColor3 = newColor end
    if UI_Elements.WpTitle then UI_Elements.WpTitle.TextColor3 = newColor end
    if UI_Elements.TargetHudStroke then UI_Elements.TargetHudStroke.Color = newColor end
    if UI_Elements.TargetHpFill then UI_Elements.TargetHpFill.BackgroundColor3 = newColor end

    for _, label in ipairs(UI_Elements.SectionLabels) do
        label.TextColor3 = newColor
    end

    if UI_Elements.Tabs then
        for name, btn in pairs(UI_Elements.Tabs) do
            if UI_Elements.CurrentTab == name then btn.TextColor3 = newColor end
        end
    end
 
    for _, item in ipairs(UI_Elements.Toggles) do
        if Config[item.Key] then item.Box.BackgroundColor3 = newColor end
    end
    for _, slider in ipairs(UI_Elements.Sliders) do
        slider.Fill.BackgroundColor3 = newColor
    end
end

local ScreenGui = Instance.new("ScreenGui")
local coreGuiSuccess, _ = pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not coreGuiSuccess or not ScreenGui.Parent then 
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui", 10) 
end
ScreenGui.ResetOnSpawn = false
ScreenGui.Enabled = true

local function MakeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            local changedConn
            changedConn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if changedConn then changedConn:Disconnect() end
                end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then 
            dragInput = input 
        end
    end)
    RunService.RenderStepped:Connect(function()
        if dragging and dragInput then
            local delta = dragInput.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local TopTimeLabel = Instance.new("TextLabel", ScreenGui)
TopTimeLabel.BackgroundTransparency = 1
TopTimeLabel.Position = UDim2.new(0.5, -50, 0, 5)
TopTimeLabel.Size = UDim2.new(0, 100, 0, 20)
TopTimeLabel.Font = Enum.Font.Code
TopTimeLabel.Text = "00:00"
TopTimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TopTimeLabel.TextSize = 14
TopTimeLabel.TextStrokeTransparency = 0.5

local function UpdateRightHud() end

local TargetHudFrame = Instance.new("Frame", ScreenGui)
TargetHudFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
TargetHudFrame.Position = UDim2.new(0.5, -100, 0.75, 0) 
TargetHudFrame.Size = UDim2.new(0, 200, 0, 65)
TargetHudFrame.Active = true
TargetHudFrame.Visible = false
MakeDraggable(TargetHudFrame)
Instance.new("UICorner", TargetHudFrame).CornerRadius = UDim.new(0, 6)
local THudStroke = Instance.new("UIStroke", TargetHudFrame)
THudStroke.Color = Config.Color_Accent
THudStroke.Thickness = 1.3
UI_Elements.TargetHudStroke = THudStroke

local TargetName = Instance.new("TextLabel", TargetHudFrame)
TargetName.BackgroundTransparency = 1
TargetName.Position = UDim2.new(0, 12, 0, 8)
TargetName.Size = UDim2.new(1, -24, 0, 16)
TargetName.Font = Enum.Font.Code
TargetName.Text = "Target: None"
TargetName.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetName.TextSize = 12
TargetName.TextXAlignment = Enum.TextXAlignment.Left

local TargetDist = Instance.new("TextLabel", TargetHudFrame)
TargetDist.BackgroundTransparency = 1
TargetDist.Position = UDim2.new(0, 12, 0, 24)
TargetDist.Size = UDim2.new(1, -24, 0, 14)
TargetDist.Font = Enum.Font.Code
TargetDist.Text = "Distance: 0m"
TargetDist.TextColor3 = Color3.fromRGB(160, 160, 165)
TargetDist.TextSize = 10
TargetDist.TextXAlignment = Enum.TextXAlignment.Left

local TargetHpBg = Instance.new("Frame", TargetHudFrame)
TargetHpBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
TargetHpBg.Position = UDim2.new(0, 12, 0, 44)
TargetHpBg.Size = UDim2.new(1, -24, 0, 6)
Instance.new("UICorner", TargetHpBg)

local TargetHpFill = Instance.new("Frame", TargetHpBg)
TargetHpFill.BackgroundColor3 = Config.Color_Accent
TargetHpFill.Size = UDim2.new(1, 0, 1, 0)
Instance.new("UICorner", TargetHpFill)
UI_Elements.TargetHpFill = TargetHpFill

local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
MainFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
MainFrame.Size = UDim2.new(0, 640, 0, 440) 
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MakeDraggable(MainFrame)
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
local MStroke = Instance.new("UIStroke", MainFrame)
MStroke.Color = Color3.fromRGB(35, 35, 40)
MStroke.Thickness = 1.5

local TopBar = Instance.new("Frame", MainFrame)
TopBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BorderSizePixel = 0
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 8)

local Line = Instance.new("Frame", TopBar)
Line.BackgroundColor3 = Config.Color_Accent
Line.Position = UDim2.new(0, 0, 1, -2)
Line.Size = UDim2.new(1, 0, 0, 2)
Line.BorderSizePixel = 0
UI_Elements.TopLine = Line

local Logo = Instance.new("TextLabel", TopBar)
Logo.BackgroundTransparency = 1
Logo.Position = UDim2.new(0, 18, 0, 0)
Logo.Size = UDim2.new(0, 120, 1, -2)
Logo.Font = Enum.Font.GothamBold
Logo.Text = "FLEX // HUD"
Logo.TextColor3 = Color3.fromRGB(255, 255, 255)
Logo.TextSize = 15
Logo.TextXAlignment = Enum.TextXAlignment.Left

local TabContainer = Instance.new("Frame", TopBar)
TabContainer.Position = UDim2.new(1, -360, 0, 0)
TabContainer.Size = UDim2.new(0, 340, 1, -2)
TabContainer.BackgroundTransparency = 1
local TabList = Instance.new("UIListLayout", TabContainer)
TabList.FillDirection = Enum.FillDirection.Horizontal
TabList.HorizontalAlignment = Enum.HorizontalAlignment.Right
TabList.SortOrder = Enum.SortOrder.LayoutOrder
TabList.Padding = UDim.new(0, 18)

local ContentFrame = Instance.new("Frame", MainFrame)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Position = UDim2.new(0, 0, 0, 40)
ContentFrame.Size = UDim2.new(1, 0, 1, -40)

local Pages = {}
local Tabs = {}
UI_Elements.Tabs = Tabs
UI_Elements.CurrentTab = "Combat"

local TpMenu = Instance.new("Frame", ScreenGui)
local FriendTpMenu = Instance.new("Frame", ScreenGui)
local WaypointMenu = Instance.new("Frame", ScreenGui)

local function CreateCloseButton(parent, uiStateKey)
    local btn = Instance.new("TextButton", parent)
    btn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    btn.Position = UDim2.new(1, -28, 0, 4)
    btn.Size = UDim2.new(0, 24, 0, 24)
    btn.Font = Enum.Font.GothamBold
    btn.Text = "X"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(function()
        parent.Visible = false
        if uiStateKey then
            UIStates[uiStateKey] = false
            SaveUIStates()
        end
    end)
end

local function ToggleMenuCursor(open)
    Config.MenuOpen = open
    MainFrame.Visible = open
    if not open then
        TpMenu.Visible = false
        FriendTpMenu.Visible = false
        WaypointMenu.Visible = false
    else
        TpMenu.Visible = UIStates.TpMenuVisible
        FriendTpMenu.Visible = UIStates.FriendTpMenuVisible
        WaypointMenu.Visible = UIStates.WaypointMenuVisible
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end
end

local function CreatePage(pageName)
    local PageLeft = Instance.new("ScrollingFrame", ContentFrame)
    PageLeft.BackgroundTransparency = 1
    PageLeft.Position = UDim2.new(0, 16, 0, 16)
    PageLeft.Size = UDim2.new(0.5, -24, 1, -32)
    PageLeft.ScrollBarThickness = 0
    PageLeft.Visible = false
    local layoutLeft = Instance.new("UIListLayout", PageLeft)
    layoutLeft.Padding = UDim.new(0, 8)
    AutoCanvasSize(PageLeft, layoutLeft)
    
    local PageRight = Instance.new("ScrollingFrame", ContentFrame)
    PageRight.BackgroundTransparency = 1
    PageRight.Position = UDim2.new(0.5, 8, 0, 16)
    PageRight.Size = UDim2.new(0.5, -24, 1, -32)
    PageRight.ScrollBarThickness = 0
    PageRight.Visible = false
    local layoutRight = Instance.new("UIListLayout", PageRight)
    layoutRight.Padding = UDim.new(0, 8)
    AutoCanvasSize(PageRight, layoutRight)

    Pages[pageName] = {Left = PageLeft, Right = PageRight}

    local TabBtn = Instance.new("TextButton", TabContainer)
    TabBtn.BackgroundTransparency = 1
    TabBtn.Size = UDim2.new(0, 60, 1, 0)
    TabBtn.Font = Enum.Font.GothamBold
    TabBtn.Text = pageName:upper()
    TabBtn.TextSize = 11
    TabBtn.TextColor3 = Color3.fromRGB(130, 130, 135)
    Tabs[pageName] = TabBtn

    TabBtn.MouseButton1Click:Connect(function()
        UI_Elements.CurrentTab = pageName
        for name, page in pairs(Pages) do
            page.Left.Visible = (name == pageName)
            page.Right.Visible = (name == pageName)
            Tabs[name].TextColor3 = (name == pageName) and Config.Color_Accent or Color3.fromRGB(130, 130, 135)
        end
    end)
end

CreatePage("Combat")
CreatePage("Visuals")
CreatePage("Misc")
CreatePage("Friends")

Pages["Combat"].Left.Visible = true
Pages["Combat"].Right.Visible = true
Tabs["Combat"].TextColor3 = Config.Color_Accent

ToggleMenuCursor(Config.MenuOpen)

RunService:BindToRenderStep("Flex_Core_Engine", 2000, function()
    Camera = Workspace.CurrentCamera
    if not getgenv().Flex_Loaded then 
        pcall(function() RunService:UnbindFromRenderStep("Flex_Core_Engine") end)
        return 
    end
    
    if Config.MenuOpen then
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
        UserInputService.MouseIconEnabled = true
    else
        local isActualFirstPerson = (Camera.CFrame.Position - Camera.Focus.Position).Magnitude < 1.8
        if isActualFirstPerson then
            UserInputService.MouseIconEnabled = false
        else
            UserInputService.MouseIconEnabled = true
        end
    end
end)

local function AddSection(pageName, side, text)
    local targetPage = Pages[pageName][side]
    local Label = Instance.new("TextLabel", targetPage)
    Label.BackgroundTransparency = 1
    Label.Size = UDim2.new(1, 0, 0, 24)
    Label.Font = Enum.Font.GothamBold
    Label.Text = "[ " .. text .. " ]"
    Label.TextColor3 = Config.Color_Accent
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Center
    table.insert(UI_Elements.SectionLabels, Label)
end

local function AddToggle(pageName, side, text, configKey)
    local targetPage = Pages[pageName][side]
    local Frame = Instance.new("Frame", targetPage)
    Frame.BackgroundTransparency = 1
    Frame.Size = UDim2.new(1, 0, 0, 28)
    
    local Box = Instance.new("TextButton", Frame)
    Box.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    Box.Position = UDim2.new(0, 2, 0.5, -8)
    Box.Size = UDim2.new(0, 16, 0, 16)
    Box.Text = ""
    Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 4)
    Instance.new("UIStroke", Box).Color = Color3.fromRGB(50, 50, 55)
    
    local Label = Instance.new("TextLabel", Frame)
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0, 28, 0, 0)
    Label.Size = UDim2.new(1, -28, 1, 0)
    Label.Font = Enum.Font.GothamSemibold
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(180, 180, 185)
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local function update()
        local bindText = Config.Keybinds[configKey] and (" [" .. Config.Keybinds[configKey].Name .. "]") or ""
        Label.Text = text .. bindText
        if Config[configKey] then
            Box.BackgroundColor3 = Config.Color_Accent
            Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            Box.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
            Label.TextColor3 = Color3.fromRGB(140, 140, 145)
        end
        UpdateRightHud()
        SaveConfig()
    end

    Box.MouseButton1Click:Connect(function() 
        Config[configKey] = not Config[configKey] 
        update() 
    end)

    Box.MouseButton2Click:Connect(function()
        Label.Text = text .. " [Waiting for Key...]"
        local connection
        connection = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
                    Config.Keybinds[configKey] = nil
                else
                    Config.Keybinds[configKey] = input.KeyCode
                end
                update()
                SaveConfig()
                connection:Disconnect()
            elseif input.UserInputType == Enum.UserInputType.MouseButton3 or input.UserInputType == Enum.UserInputType.MouseButton4 or input.UserInputType == Enum.UserInputType.MouseButton5 then
                Config.Keybinds[configKey] = input.UserInputType
                update()
                SaveConfig()
                connection:Disconnect()
            end
        end)
    end)

    table.insert(UI_Elements.Toggles, {Box = Box, Label = Label, Key = configKey})
    update() 
end

local function AddSlider(pageName, side, text, configKey, min, max)
    local targetPage = Pages[pageName][side]
    local Frame = Instance.new("Frame", targetPage)
    Frame.BackgroundTransparency = 1
    Frame.Size = UDim2.new(1, 0, 0, 48)
    
    local Label = Instance.new("TextLabel", Frame)
    Label.BackgroundTransparency = 1
    Label.Size = UDim2.new(1, 0, 0, 18)
    Label.Font = Enum.Font.GothamSemibold
    Label.Text = text .. ": " .. tostring(Config[configKey])
    Label.TextColor3 = Color3.fromRGB(140, 140, 145)
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local SliderBg = Instance.new("Frame", Frame)
    SliderBg.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    SliderBg.Position = UDim2.new(0, 2, 0, 24)
    SliderBg.Size = UDim2.new(1, -20, 0, 10)
    Instance.new("UICorner", SliderBg)
    
    local SliderFill = Instance.new("Frame", SliderBg)
    SliderFill.BackgroundColor3 = Config.Color_Accent
    local initPercent = (Config[configKey] - min) / (max - min)
    SliderFill.Size = UDim2.new(initPercent, 0, 1, 0)
    Instance.new("UICorner", SliderFill)
    
    local SliderBtn = Instance.new("TextButton", SliderBg)
    SliderBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SliderBtn.Position = UDim2.new(initPercent, -8, 0.5, -8)
    SliderBtn.Size = UDim2.new(0, 16, 0, 16)
    SliderBtn.Text = ""
    Instance.new("UICorner", SliderBtn)
    
    local holding = false
    local function move()
        local relativeX = Mouse.X - SliderBg.AbsolutePosition.X
        local percentage = math.clamp(relativeX / SliderBg.AbsoluteSize.X, 0, 1)
        SliderBtn.Position = UDim2.new(percentage, -8, 0.5, -8)
        SliderFill.Size = UDim2.new(percentage, 0, 1, 0)
        local value = math.round(min + (max - min) * percentage)
        Config[configKey] = value
        Label.Text = text .. ": " .. tostring(value)
    end
    SliderBtn.MouseButton1Down:Connect(function() holding = true end)
    UserInputService.InputEnded:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseButton1 then 
            holding = false 
            SaveConfig()
        end 
    end)
    Mouse.Move:Connect(function() if holding then move() end end)
    table.insert(UI_Elements.Sliders, {Fill = SliderFill, Btn = SliderBtn})
end

local function AddButton(pageName, side, text, callback)
    local targetPage = Pages[pageName][side]
    local Btn = Instance.new("TextButton", targetPage)
    Btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    Btn.Size = UDim2.new(1, -10, 0, 28)
    Btn.Font = Enum.Font.GothamBold
    Btn.Text = text
    Btn.TextColor3 = Color3.fromRGB(235, 235, 240)
    Btn.TextSize = 11
    Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 5)
    Instance.new("UIStroke", Btn).Color = Color3.fromRGB(50, 50, 55)
    Btn.MouseButton1Click:Connect(function() callback(Btn) end)
    return Btn
end

local function AddColorPicker(pageName, side, text)
    local targetPage = Pages[pageName][side]
    local Frame = Instance.new("Frame", targetPage)
    Frame.BackgroundTransparency = 1
    Frame.Size = UDim2.new(1, 0, 0, 50)
    
    local Label = Instance.new("TextLabel", Frame)
    Label.BackgroundTransparency = 1
    Label.Size = UDim2.new(1, 0, 0, 16)
    Label.Font = Enum.Font.GothamBold
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(180, 180, 185)
    Label.TextSize = 11
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local PaletteContainer = Instance.new("Frame", Frame)
    PaletteContainer.BackgroundTransparency = 1
    PaletteContainer.Position = UDim2.new(0, 0, 0, 20)
    PaletteContainer.Size = UDim2.new(1, 0, 0, 24)
    Instance.new("UIListLayout", PaletteContainer).FillDirection = Enum.FillDirection.Horizontal
    PaletteContainer.UIListLayout.Padding = UDim.new(0, 6)

    local Colors = {
        Color3.fromRGB(150, 150, 255), Color3.fromRGB(0, 255, 120), Color3.fromRGB(255, 0, 85),
        Color3.fromRGB(255, 180, 0), Color3.fromRGB(180, 50, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 60, 60)
    }

    for _, color in ipairs(Colors) do
        local ColorCell = Instance.new("TextButton", PaletteContainer)
        ColorCell.BackgroundColor3 = color
        ColorCell.Size = UDim2.new(0, 22, 0, 22)
        ColorCell.Text = ""
        Instance.new("UICorner", ColorCell).CornerRadius = UDim.new(0, 5)
        Instance.new("UIStroke", ColorCell).Color = Color3.fromRGB(0,0,0)
        ColorCell.MouseButton1Click:Connect(function() UpdateSystemColor(color) end)
    end
end

-- MAIN TP MENU
TpMenu.Parent = ScreenGui
TpMenu.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
TpMenu.Position = UDim2.new(0.65, 0, 0.25, 0)
TpMenu.Size = UDim2.new(0, 180, 0, 280)
TpMenu.Visible = false
MakeDraggable(TpMenu)
Instance.new("UICorner", TpMenu).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", TpMenu).Color = Color3.fromRGB(35, 35, 40)

local TpTitle = Instance.new("TextLabel", TpMenu)
TpTitle.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
TpTitle.Size = UDim2.new(1, 0, 0, 32)
TpTitle.Font = Enum.Font.GothamBold
TpTitle.Text = "PLAYER TELEPORT"
TpTitle.TextColor3 = Config.Color_Accent
TpTitle.TextSize = 11
UI_Elements.TpTitle = TpTitle
Instance.new("UICorner", TpTitle)

local TpScroll = Instance.new("ScrollingFrame", TpMenu)
TpScroll.BackgroundTransparency = 1
TpScroll.Position = UDim2.new(0, 6, 0, 38)
TpScroll.Size = UDim2.new(1, -12, 1, -44)
TpScroll.ScrollBarThickness = 2
local TpList = Instance.new("UIListLayout", TpScroll) 
TpList.Padding = UDim.new(0, 5)
AutoCanvasSize(TpScroll, TpList)
CreateCloseButton(TpMenu, "TpMenuVisible")

-- FRIEND TP MENU (SIDE PANEL)
FriendTpMenu.Parent = ScreenGui
FriendTpMenu.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
FriendTpMenu.Position = UDim2.new(0.65, 190, 0.25, 0) 
FriendTpMenu.Size = UDim2.new(0, 180, 0, 280)
FriendTpMenu.Visible = false
MakeDraggable(FriendTpMenu)
Instance.new("UICorner", FriendTpMenu).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", FriendTpMenu).Color = Color3.fromRGB(35, 35, 40)

local FriendTpTitle = Instance.new("TextLabel", FriendTpMenu)
FriendTpTitle.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
FriendTpTitle.Size = UDim2.new(1, 0, 0, 32)
FriendTpTitle.Font = Enum.Font.GothamBold
FriendTpTitle.Text = "FRIEND TELEPORT"
FriendTpTitle.TextColor3 = Config.Color_Accent
FriendTpTitle.TextSize = 11
UI_Elements.FriendTpTitle = FriendTpTitle
Instance.new("UICorner", FriendTpTitle)

local FriendTpScroll = Instance.new("ScrollingFrame", FriendTpMenu)
FriendTpScroll.BackgroundTransparency = 1
FriendTpScroll.Position = UDim2.new(0, 6, 0, 38)
FriendTpScroll.Size = UDim2.new(1, -12, 1, -44)
FriendTpScroll.ScrollBarThickness = 2
local FriendTpListLayout = Instance.new("UIListLayout", FriendTpScroll) 
FriendTpListLayout.Padding = UDim.new(0, 5)
AutoCanvasSize(FriendTpScroll, FriendTpListLayout)
CreateCloseButton(FriendTpMenu, "FriendTpMenuVisible")

-- WAYPOINT MENU
WaypointMenu.Parent = ScreenGui
WaypointMenu.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
WaypointMenu.Position = UDim2.new(0.65, -190, 0.25, 0) 
WaypointMenu.Size = UDim2.new(0, 180, 0, 320)
WaypointMenu.Visible = false
MakeDraggable(WaypointMenu)
Instance.new("UICorner", WaypointMenu).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", WaypointMenu).Color = Color3.fromRGB(35, 35, 40)

local WpTitle = Instance.new("TextLabel", WaypointMenu)
WpTitle.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
WpTitle.Size = UDim2.new(1, 0, 0, 32)
WpTitle.Font = Enum.Font.GothamBold
WpTitle.Text = "WAYPOINTS HUD"
WpTitle.TextColor3 = Config.Color_Accent
WpTitle.TextSize = 11
UI_Elements.WpTitle = WpTitle
Instance.new("UICorner", WpTitle)

local WpInput = Instance.new("TextBox", WaypointMenu)
WpInput.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
WpInput.Position = UDim2.new(0, 6, 0, 38)
WpInput.Size = UDim2.new(1, -12, 0, 24)
WpInput.Font = Enum.Font.Gotham
WpInput.Text = ""
WpInput.PlaceholderText = "Waypoint Name..."
WpInput.TextColor3 = Color3.fromRGB(255, 255, 255)
WpInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 125)
WpInput.TextSize = 11
Instance.new("UICorner", WpInput).CornerRadius = UDim.new(0, 4)
local WpInputStroke = Instance.new("UIStroke", WpInput)
WpInputStroke.Color = Color3.fromRGB(50, 50, 55)

local WpAddBtn = Instance.new("TextButton", WaypointMenu)
WpAddBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 30)
WpAddBtn.Position = UDim2.new(0, 6, 0, 68)
WpAddBtn.Size = UDim2.new(1, -12, 0, 24)
WpAddBtn.Font = Enum.Font.GothamBold
WpAddBtn.Text = "+ CREATE WAYPOINT"
WpAddBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
WpAddBtn.TextSize = 10
Instance.new("UICorner", WpAddBtn).CornerRadius = UDim.new(0, 4)

local WpScroll = Instance.new("ScrollingFrame", WaypointMenu)
WpScroll.BackgroundTransparency = 1
WpScroll.Position = UDim2.new(0, 6, 0, 98)
WpScroll.Size = UDim2.new(1, -12, 1, -104)
WpScroll.ScrollBarThickness = 2
local WpListLayout = Instance.new("UIListLayout", WpScroll) 
WpListLayout.Padding = UDim.new(0, 5)
AutoCanvasSize(WpScroll, WpListLayout)
CreateCloseButton(WaypointMenu, "WaypointMenuVisible")

local function UpdateTpMenu()
    for _, child in ipairs(TpScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local PBtn = Instance.new("TextButton", TpScroll)
            PBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
            PBtn.Size = UDim2.new(1, -4, 0, 26)
            PBtn.Font = Enum.Font.Gotham
            PBtn.Text = p.Name
            PBtn.TextColor3 = Color3.fromRGB(200, 200, 205)
            PBtn.TextSize = 11
            Instance.new("UICorner", PBtn).CornerRadius = UDim.new(0, 4)
            PBtn.MouseButton1Click:Connect(function()
                if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
                end
            end)
        end
    end
end

local function UpdateFriendTpMenu()
   for _, child in ipairs(FriendTpScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and Config.Friends[p.Name] then
            local PBtn = Instance.new("TextButton", FriendTpScroll)
            PBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
            PBtn.Size = UDim2.new(1, -4, 0, 26)
            PBtn.Font = Enum.Font.GothamBold
            PBtn.Text = p.Name
            PBtn.TextColor3 = Config.Color_Friend
            PBtn.TextSize = 11
            Instance.new("UICorner", PBtn).CornerRadius = UDim.new(0, 4)
            PBtn.MouseButton1Click:Connect(function()
                if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
                end
            end)
        end
    end
end

local function UpdateWaypointMenu()
    for _, child in ipairs(WpScroll:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for name, posTable in pairs(Config.Waypoints) do
        local WpRow = Instance.new("Frame", WpScroll)
        WpRow.BackgroundTransparency = 1
        WpRow.Size = UDim2.new(1, -4, 0, 28)
         
        local TeleBtn = Instance.new("TextButton", WpRow)
        TeleBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        TeleBtn.Size = UDim2.new(0, 120, 1, 0)
        TeleBtn.Font = Enum.Font.Gotham
        TeleBtn.Text = name
        TeleBtn.TextColor3 = Color3.fromRGB(220, 220, 225)
        TeleBtn.TextSize = 10
        Instance.new("UICorner", TeleBtn).CornerRadius = UDim.new(0, 4)
         
        TeleBtn.MouseButton1Click:Connect(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(posTable[1], posTable[2], posTable[3])
            end
        end)
        
        TeleBtn.MouseButton2Click:Connect(function()
            TeleBtn.Visible = false
            local RenameBox = Instance.new("TextBox", WpRow)
            RenameBox.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
            RenameBox.Size = TeleBtn.Size
            RenameBox.Font = Enum.Font.GothamBold
            RenameBox.Text = name
            RenameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            RenameBox.TextSize = 10
            Instance.new("UICorner", RenameBox).CornerRadius = UDim.new(0, 4)
            RenameBox:CaptureFocus()
            
            local hasRenamed = false
            local function completeRename()
                if hasRenamed then return end
                hasRenamed = true
                local requestedName = RenameBox.Text
                if requestedName ~= "" and requestedName ~= name then
                    local coords = Config.Waypoints[name]
                    Config.Waypoints[requestedName] = coords
                    Config.Waypoints[name] = nil
                    SaveConfig()
                end
                UpdateWaypointMenu()
            end
            RenameBox.FocusLost:Connect(completeRename)
        end)
        
        local DelBtn = Instance.new("TextButton", WpRow)
        DelBtn.BackgroundColor3 = Color3.fromRGB(45, 20, 25)
        DelBtn.Position = UDim2.new(0, 124, 0, 0)
        DelBtn.Size = UDim2.new(1, -124, 1, 0)
        DelBtn.Font = Enum.Font.GothamBold
        DelBtn.Text = "X"
        DelBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
        DelBtn.TextSize = 10
        Instance.new("UICorner", DelBtn).CornerRadius = UDim.new(0, 4)
        
        DelBtn.MouseButton1Click:Connect(function()
            Config.Waypoints[name] = nil
            SaveConfig()
            UpdateWaypointMenu()
        end)
    end
end

WpAddBtn.MouseButton1Click:Connect(function()
    local name = WpInput.Text
    if name == "" then name = "WP_" .. tostring(math.random(1000, 9999)) end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local pos = LocalPlayer.Character.HumanoidRootPart.Position
        Config.Waypoints[name] = {pos.X, pos.Y, pos.Z}
        SaveConfig()
        UpdateWaypointMenu()
        WpInput.Text = ""
    end
end)

Players.PlayerAdded:Connect(function() UpdateTpMenu(); UpdateFriendTpMenu() end)
Players.PlayerRemoving:Connect(function() UpdateTpMenu(); UpdateFriendTpMenu() end)

-- FRIENDS MENU SYSTEM 
local FriendTitle = Instance.new("TextLabel", Pages["Friends"].Right)
FriendTitle.BackgroundTransparency = 1
FriendTitle.Size = UDim2.new(1, 0, 0, 20)
FriendTitle.Font = Enum.Font.GothamBold
FriendTitle.Text = "SERVER PLAYERS (Click to Add/Remove)"
FriendTitle.TextColor3 = Color3.fromRGB(180, 180, 185)
FriendTitle.TextSize = 11
FriendTitle.TextXAlignment = Enum.TextXAlignment.Left

local function UpdateFriendsMenu()
    for _, child in ipairs(Pages["Friends"].Right:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local PBtn = Instance.new("TextButton", Pages["Friends"].Right)
            PBtn.Size = UDim2.new(1, -10, 0, 28)
            PBtn.Font = Enum.Font.GothamBold
            PBtn.Text = p.Name
            PBtn.TextSize = 11
            Instance.new("UICorner", PBtn).CornerRadius = UDim.new(0, 4)
            
            local function refreshBtnState()
                if Config.Friends[p.Name] then
                    PBtn.BackgroundColor3 = Config.Color_Friend
                    PBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    PBtn.Text = p.Name .. " [FRIEND]"
                else
                    PBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
                    PBtn.TextColor3 = Color3.fromRGB(200, 200, 205)
                    PBtn.Text = p.Name
                end
            end
            refreshBtnState()
            
            PBtn.MouseButton1Click:Connect(function()
                if Config.Friends[p.Name] then
                    Config.Friends[p.Name] = nil
                else
                    Config.Friends[p.Name] = true
                end
                refreshBtnState()
                SaveConfig()
                UpdateFriendTpMenu()
            end)
        end
    end
end

Players.PlayerAdded:Connect(UpdateFriendsMenu)
Players.PlayerRemoving:Connect(UpdateFriendsMenu)

local InfoLabel = Instance.new("TextLabel", Pages["Friends"].Left)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Size = UDim2.new(1, 0, 0, 60)
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.Text = "Aimbot will ignore friends.\nFriends will have Blue ESP/Hitboxes.\nSelect players from the right list."
InfoLabel.TextColor3 = Color3.fromRGB(150, 150, 155)
InfoLabel.TextSize = 11
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.TextYAlignment = Enum.TextYAlignment.Top

AddButton("Friends", "Left", "Clear All Friends", function()
    Config.Friends = {}
    SaveConfig()
    UpdateFriendsMenu()
    UpdateFriendTpMenu()
end)

-- ADDING UI ELEMENTS
AddSection("Combat", "Left", "AIMBOT MODULE")
AddToggle("Combat", "Left", "Aimbot (Always Active)", "Aimbot")
AddToggle("Combat", "Left", "Visibility Check", "VisibleCheck")

AddSection("Visuals", "Left", "ESP MODULE")
AddToggle("Visuals", "Left", "Master ESP", "ESP")
AddToggle("Visuals", "Left", "Skeleton ESP", "SkeletonESP")
AddToggle("Visuals", "Left", "Target HUD Panel", "TargetHUD")

local TracerBtn = AddButton("Visuals", "Left", "Tracer Origin: " .. Config.TracerOrigin, function(self)
    local modes = {"Bottom", "Center", "Top"}
    local idx = table.find(modes, Config.TracerOrigin) or 1
    idx = idx % #modes + 1
    Config.TracerOrigin = modes[idx]
    self.Text = "Tracer Origin: " .. Config.TracerOrigin
    SaveConfig()
end)

AddSection("Misc", "Left", "MOVEMENT MODULE")
AddToggle("Misc", "Left", "Speed Hack", "Speed")
AddSlider("Misc", "Left", "Speed Value", "SpeedValue", 16, 1000)
AddToggle("Misc", "Left", "High Jump", "HighJump")
AddSlider("Misc", "Left", "Jump Value", "JumpValue", 50, 500)

AddToggle("Misc", "Left", "Infinite Jump", "InfJump")
AddToggle("Misc", "Left", "Hold Jump", "HoldJump")
AddSlider("Misc", "Left", "Inf Jump Power", "InfJumpValue", 10, 200)

AddToggle("Misc", "Left", "Flight Engine", "Fly")
AddToggle("Misc", "Left", "Flight Engine TP", "FlyTP")
AddSlider("Misc", "Left", "Flight Engine Speed", "FlySpeed", 10, 1000)
AddSlider("Misc", "Left", "Flight TP Speed", "FlyTPSpeed", 10, 1000)
AddToggle("Misc", "Left", "Dynamic Tilt", "FlightLean")
AddToggle("Misc", "Left", "Noclip", "Noclip")
AddToggle("Misc", "Left", "Click TP (Ctrl + LClick)", "ClickTP")

AddSection("Misc", "Right", "UTILITIES")
AddButton("Misc", "Right", "Air Flip", function()
    if not Config.Fly and not Config.FlyTP then return end
    Config.FlightFlip = false
    task.spawn(function()
        for i = 1, 360, 15 do
            flightRotation = CFrame.fromEulerAnglesXYZ(math.rad(-i), 0, 0)
            task.wait(0.01)
        end
        flightRotation = CFrame.new()
        Config.FlightFlip = true
    end)
end)

AddButton("Misc", "Right", "Player Teleport Panel", function()
    UpdateTpMenu()
    UpdateFriendTpMenu()
    TpMenu.Visible = not TpMenu.Visible
    UIStates.TpMenuVisible = TpMenu.Visible
    SaveUIStates()
end)

AddButton("Misc", "Right", "Friend Teleport Panel", function()
    UpdateFriendTpMenu()
    FriendTpMenu.Visible = not FriendTpMenu.Visible
    UIStates.FriendTpMenuVisible = FriendTpMenu.Visible
    SaveUIStates()
end)

AddButton("Misc", "Right", "Waypoint Manager Panel", function()
    UpdateWaypointMenu()
    WaypointMenu.Visible = not WaypointMenu.Visible
    UIStates.WaypointMenuVisible = WaypointMenu.Visible
    SaveUIStates()
end)

AddColorPicker("Misc", "Right", "UI Theme Colors")

-- HOOK JUMP REQUEST FOR INFINITE JUMP
UserInputService.JumpRequest:Connect(function()
    if Config.InfJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.Velocity = Vector3.new(
            LocalPlayer.Character.HumanoidRootPart.Velocity.X,
            Config.InfJumpValue,
            LocalPlayer.Character.HumanoidRootPart.Velocity.Z
        )
    end
end)

-- INPUT BEGAN: KEYBOARD/MOUSE OPERATIONS
UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and Config.MenuOpen and not gp then
        local mPos = UserInputService:GetMouseLocation()
        local mX, mY = mPos.X, mPos.Y
        
        local function inFrame(frame)
            if not frame.Visible then return false end
            local pos = frame.AbsolutePosition
            local size = frame.AbsoluteSize
            return mX >= pos.X and mX <= (pos.X + size.X) and mY >= pos.Y and mY <= (pos.Y + size.Y + 36)
        end
        
        if not inFrame(MainFrame) and not inFrame(TpMenu) and not inFrame(FriendTpMenu) and not inFrame(WaypointMenu) then
            ToggleMenuCursor(false)
            SaveConfig()
        end
    end

    if gp and input.KeyCode ~= Config.MenuKey then return end
    if input.KeyCode == Config.MenuKey then
        ToggleMenuCursor(not Config.MenuOpen)
        SaveConfig()
        return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 and Config.ClickTP then
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
            end
        end
    end
    
    for key, bind in pairs(Config.Keybinds) do
        if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind) or (input.UserInputType == bind) then
            Config[key] = not Config[key]
            for _, tgl in ipairs(UI_Elements.Toggles) do
                if tgl.Key == key then
                    if Config[key] then
                        tgl.Box.BackgroundColor3 = Config.Color_Accent
                        tgl.Label.TextColor3 = Color3.fromRGB(255, 255, 255)
                    else
                        tgl.Box.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
                        tgl.Label.TextColor3 = Color3.fromRGB(140, 140, 145)
                    end
                end
            end
            UpdateRightHud()
            SaveConfig()
        end
    end
end)

local function isVisible(targetPart, customChar)
    local checkChar = customChar or (targetPart and targetPart.Parent)
    if not checkChar then return false end
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, checkChar}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(origin, direction, raycastParams)
    return result == nil
end

-- STABLE AIM ASSIST ENGINE (SCREEN DISTANCE BASED)
local function GetAimbotTarget()
    local closest, minDist = nil, math.huge
    local mouseLocation = UserInputService:GetMouseLocation()
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            if not Config.Friends[p.Name] then
                local part = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("HumanoidRootPart")
                if part then
                    if not Config.VisibleCheck or isVisible(part, p.Character) then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mouseLocation).Magnitude
                            if screenDist < minDist then 
                                minDist = screenDist
                                closest = p 
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") then
            if player.Character.Humanoid.Health > 0 then
                
                if Config.VisibleCheck then
                    local parts = Camera:GetPartsObscuringTarget({player.Character.HumanoidRootPart.Position}, {LocalPlayer.Character, player.Character})
                    if #parts > 0 then continue end
                end

                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                
                if distance < shortestDistance then
                    closestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end
    return closestPlayer
end

-- 100% PERFECT HEAD CENTER LOCK 
local currentTarget = nil
RunService:BindToRenderStep("Flex_Aimbot_Engine", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
    Camera = Workspace.CurrentCamera
    if not getgenv().Flex_Loaded then 
        pcall(function() RunService:UnbindFromRenderStep("Flex_Aimbot_Engine") end)
        return 
    end
    local aimTriggered = Config.Aimbot
    if aimTriggered and not Config.MenuOpen then
        if currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild("Humanoid") and currentTarget.Character.Humanoid.Health > 0 then
            local head = currentTarget.Character:FindFirstChild("Head")
            if Config.VisibleCheck and head and not isVisible(head, currentTarget.Character) then
                currentTarget = GetAimbotTarget()
            end
        else
            currentTarget = GetAimbotTarget()
        end

        if currentTarget and currentTarget.Character then
            -- ONLY AND STRICTLY TARGETS EXACT HEAD CENTER
            local head = currentTarget.Character:FindFirstChild("Head")
            if head then
                local headCenterPos = head.Position
                local velocity = head.AssemblyLinearVelocity or head.Velocity or Vector3.new(0, 0, 0)
                
                -- Slightly predicts the trajectory for 100% stable lock without jitter
                local predictedPos = headCenterPos + (velocity * 0.00) 
                
                local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, predictedPos)
                -- 0.8 Lerp provides an extremely smooth but perfectly strong lock
                Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 1)
            end
        end
    else
        currentTarget = nil
    end
end)

-- ORIGINAL ESP DRAWING ENGINE
local function createDrawings()
    local allowed, drawing = pcall(function()
        return {
            Box = Drawing.new("Square"),
            HealthBar = Drawing.new("Square"),
            Name = Drawing.new("Text"),
            Tracer = Drawing.new("Line"),
            Spine = Drawing.new("Line"),
            LeftArm = Drawing.new("Line"),
            RightArm = Drawing.new("Line"),
            LeftLeg = Drawing.new("Line"),
            RightLeg = Drawing.new("Line")
        }
    end)
    if not allowed then return nil end
    drawing.Box.Thickness = Config.BoxThickness
    drawing.Box.Filled = false
    drawing.Box.Visible = false
    drawing.HealthBar.Filled = true
    drawing.HealthBar.Visible = false
    drawing.Name.Center = true
    drawing.Name.Outline = true
    drawing.Name.OutlineColor = Color3.fromRGB(0,0,0)
    drawing.Name.Size = 14
    drawing.Name.Visible = false
    drawing.Tracer.Thickness = Config.TracerThickness
    drawing.Tracer.Visible = false
    local skeletonParts = {"Spine", "LeftArm", "RightArm", "LeftLeg", "RightLeg"}
    for _, bone in ipairs(skeletonParts) do
        drawing[bone].Thickness = Config.SkeletonThickness
        drawing[bone].Visible = false
    end
    return drawing
end

local function clearESP(esp)
    if esp then
        pcall(function()
            esp.Box:Remove() esp.HealthBar:Remove() esp.Name:Remove() esp.Tracer:Remove()
            esp.Spine:Remove() esp.LeftArm:Remove() esp.RightArm:Remove() esp.LeftLeg:Remove() esp.RightLeg:Remove()
        end)
    end
end

local function initESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not ESP_Cache[p] then ESP_Cache[p] = createDrawings() end
    end
    Players.PlayerAdded:Connect(function(p)
        if p ~= LocalPlayer then ESP_Cache[p] = createDrawings() end
    end)
    Players.PlayerRemoving:Connect(function(p)
        if ESP_Cache[p] then clearESP(ESP_Cache[p]); ESP_Cache[p] = nil end
    end)
end
initESP()

local function getScreenPos(part)
    if not part then return nil end
    local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
    return onScreen and Vector2.new(pos.X, pos.Y) or nil
end

-- RENDER STEP (HUD AND ESP UPDATES)
RunService.RenderStepped:Connect(function(deltaTime)
    deltaTime = deltaTime or 0.016
    if not getgenv().Flex_Loaded then return end
    
    local hudTarget = GetClosestPlayerScreen()
    if Config.TargetHUD and hudTarget and hudTarget.Character and hudTarget.Character:FindFirstChild("Humanoid") and hudTarget.Character:FindFirstChild("HumanoidRootPart") then
        local targetHum = hudTarget.Character.Humanoid
        local targetRoot = hudTarget.Character.HumanoidRootPart
        local distance = math.floor((Camera.CFrame.Position - targetRoot.Position).Magnitude)
        TargetName.Text = "Target: " .. hudTarget.Name
        TargetDist.Text = string.format("Distance: %dm | HP: %d/%d", distance, math.round(targetHum.Health), math.round(targetHum.MaxHealth))
        local hpPercent = math.clamp(targetHum.Health / targetHum.MaxHealth, 0, 1)
        TargetHpFill.Size = UDim2.new(hpPercent, 0, 1, 0)
        TargetHudFrame.Visible = true
    else
        TargetHudFrame.Visible = false
    end
    
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local humanoid = LocalPlayer.Character.Humanoid
        local rootPart = LocalPlayer.Character.HumanoidRootPart
        local forwardVec = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z).Unit

        if Config.Fly then
            if rootPart.Anchored then rootPart.Anchored = false end
            humanoid.PlatformStand = true
            
            if not FlyVelocityInstance or FlyVelocityInstance.Parent ~= rootPart then
                if FlyVelocityInstance then FlyVelocityInstance:Destroy() end
                FlyVelocityInstance = Instance.new("BodyVelocity")
                FlyVelocityInstance.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                FlyVelocityInstance.Parent = rootPart
            end

            if not FlyGyroInstance or FlyGyroInstance.Parent ~= rootPart then
                if FlyGyroInstance then FlyGyroInstance:Destroy() end
                FlyGyroInstance = Instance.new("BodyGyro")
                FlyGyroInstance.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
                FlyGyroInstance.P = 20000 
                FlyGyroInstance.D = 500   
                FlyGyroInstance.Parent = rootPart
            end
            
            rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            
            local right = Camera.CFrame.RightVector
            local rightVec = Vector3.new(right.X, 0, right.Z).Unit
            local moveDir = Vector3.new(0, 0, 0)
            local leanPitch, leanRoll = 0, 0
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forwardVec leanPitch = -5 end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forwardVec leanPitch = 5 end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - rightVec leanRoll = 8 end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + rightVec leanRoll = -8 end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
            
            if moveDir.Magnitude > 0 then
                FlyVelocityInstance.Velocity = moveDir.Unit * Config.FlySpeed
                local flatMoveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
                local baseCFrame
                if flatMoveDir.Magnitude > 0.001 then
                    baseCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flatMoveDir.Unit)
                else
                    baseCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + forwardVec)
                end

                if Config.FlightLean then
                    FlyGyroInstance.CFrame = baseCFrame * CFrame.fromEulerAnglesXYZ(math.rad(leanPitch), 0, math.rad(leanRoll)) * flightRotation
                else
                    FlyGyroInstance.CFrame = baseCFrame * flightRotation
                end
            else
                FlyVelocityInstance.Velocity = Vector3.new(0, 0, 0)
                local baseCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + forwardVec)
                FlyGyroInstance.CFrame = baseCFrame * flightRotation
            end
            
        elseif Config.FlyTP then
            if FlyVelocityInstance then FlyVelocityInstance:Destroy() FlyVelocityInstance = nil end
            if FlyGyroInstance then FlyGyroInstance:Destroy() FlyGyroInstance = nil end 
            humanoid.PlatformStand = true
            rootPart.Anchored = true
            rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            
            local right = Camera.CFrame.RightVector
            local rightVec = Vector3.new(right.X, 0, right.Z).Unit
            local moveDir = Vector3.new(0,0,0)
            local leanPitch, leanRoll = 0, 0
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forwardVec leanPitch = -5 end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forwardVec leanPitch = 5 end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - rightVec leanRoll = 8 end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + rightVec leanRoll = -8 end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
            
            if moveDir.Magnitude > 0 then
                local targetPosition = rootPart.Position + (moveDir.Unit * ((Config.FlyTPSpeed / 60) * (deltaTime * 60)))
                local flatMoveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
                local baseCFrame
                if flatMoveDir.Magnitude > 0.001 then
                    baseCFrame = CFrame.lookAt(targetPosition, targetPosition + flatMoveDir.Unit)
                else
                    baseCFrame = CFrame.lookAt(targetPosition, targetPosition + forwardVec)
                end

                if Config.FlightLean then
                    rootPart.CFrame = baseCFrame * CFrame.fromEulerAnglesXYZ(math.rad(leanPitch), 0, math.rad(leanRoll)) * flightRotation
                else
                    rootPart.CFrame = baseCFrame * flightRotation
                end
            else
                rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + forwardVec) * flightRotation
            end
        else
            if FlyVelocityInstance then FlyVelocityInstance:Destroy() FlyVelocityInstance = nil end
            if FlyGyroInstance then FlyGyroInstance:Destroy() FlyGyroInstance = nil end 
            if rootPart.Anchored then rootPart.Anchored = false end
            if humanoid.PlatformStand then humanoid.PlatformStand = false end
            if Config.Speed then 
                humanoid.WalkSpeed = Config.SpeedValue 
            else
                if humanoid.WalkSpeed == Config.SpeedValue then humanoid.WalkSpeed = 16 end
            end
            
            if Config.HighJump then
                humanoid.UseJumpPower = true
                humanoid.JumpPower = Config.JumpValue
            else
                if humanoid.JumpPower == Config.JumpValue then humanoid.JumpPower = 50 end
            end
        end
    end
    
    for player, esp in pairs(ESP_Cache) do
        if not esp then continue end
        local char = player and player.Character
        local isAlive = char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0
        local root = isAlive and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
        local head = isAlive and char:FindFirstChild("Head")
        
        if isAlive and root and head and Config.ESP then
            local headP, headOnScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local legP, legOnScreen = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
            
            if headOnScreen or legOnScreen then
                local boxHeight = math.abs(headP.Y - legP.Y)
                local boxWidth = boxHeight * 0.6
                local boxX = headP.X - (boxWidth / 2)
                local boxY = headP.Y
                
                local isFriend = Config.Friends[player.Name] == true
                local isPlayerVisible = isVisible(head, char) or isVisible(root, char)
                local dynamicEspColor

                if isFriend then
                    dynamicEspColor = Config.Color_Friend 
                else
                    dynamicEspColor = isPlayerVisible and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
                end
                
                esp.Box.Size = Vector2.new(boxWidth, boxHeight)
                esp.Box.Position = Vector2.new(boxX, boxY)
                esp.Box.Color = dynamicEspColor
                esp.Box.Visible = true

                local hpPercent = char.Humanoid.Health / char.Humanoid.MaxHealth
                local barHeight = boxHeight * hpPercent
                esp.HealthBar.Size = Vector2.new(2, barHeight)
                esp.HealthBar.Position = Vector2.new(boxX - 5, boxY + (boxHeight - barHeight))
                esp.HealthBar.Color = Color3.fromRGB(255 - (255 * hpPercent), 255 * hpPercent, 0)
                esp.HealthBar.Visible = true
                
                local dist = math.floor((Camera.CFrame.Position - root.Position).Magnitude)
                local friendTag = isFriend and "[FRIEND] " or ""
                local currentHp = math.round(char.Humanoid.Health)
                local maxHp = math.round(char.Humanoid.MaxHealth)
                esp.Name.Text = string.format("%s%s [%d/%d] [%dm]", friendTag, player.Name, currentHp, maxHp, dist)
                esp.Name.Position = Vector2.new(headP.X, boxY - 16)
                esp.Name.Color = isFriend and Config.Color_Friend or Color3.fromRGB(255, 255, 255)
                esp.Name.Visible = true
                
                local fromPosition = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                if Config.TracerOrigin == "Center" then
                    fromPosition = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                elseif Config.TracerOrigin == "Top" then
                    fromPosition = Vector2.new(Camera.ViewportSize.X / 2, 0)
                end
                
                esp.Tracer.From = fromPosition
                esp.Tracer.To = Vector2.new(headP.X, legP.Y)
                esp.Tracer.Color = dynamicEspColor
                esp.Tracer.Visible = true
                
                if Config.SkeletonESP then
                    local sHead = getScreenPos(head)
                    local sTorso = getScreenPos(char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or root)
                    local sLArm = getScreenPos(char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm"))
                    local sRArm = getScreenPos(char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm"))
                    local sLLeg = getScreenPos(char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg"))
                    local sRLeg = getScreenPos(char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Arm"))
                    
                    if sHead and sTorso then esp.Spine.From = sHead esp.Spine.To = sTorso esp.Spine.Color = dynamicEspColor esp.Spine.Visible = true else esp.Spine.Visible = false end
                    if sTorso and sLArm then esp.LeftArm.From = sTorso esp.LeftArm.To = sLArm esp.LeftArm.Color = dynamicEspColor esp.LeftArm.Visible = true else esp.LeftArm.Visible = false end
                    if sTorso and sRArm then esp.RightArm.From = sTorso esp.RightArm.To = sRArm esp.RightArm.Color = dynamicEspColor esp.RightArm.Visible = true else esp.RightArm.Visible = false end
                    if sTorso and sLLeg then esp.LeftLeg.From = sTorso esp.LeftLeg.To = sLLeg esp.LeftLeg.Color = dynamicEspColor esp.LeftLeg.Visible = true else esp.LeftLeg.Visible = false end
                    if sTorso and sRLeg then esp.RightLeg.From = sTorso esp.RightLeg.To = sRLeg esp.RightLeg.Color = dynamicEspColor esp.RightLeg.Visible = true else esp.RightLeg.Visible = false end
                else
                    esp.Spine.Visible = false esp.LeftArm.Visible = false esp.RightArm.Visible = false esp.LeftLeg.Visible = false esp.RightLeg.Visible = false
                end
                
            else
                esp.Box.Visible = false esp.HealthBar.Visible = false esp.Name.Visible = false esp.Tracer.Visible = false
                esp.Spine.Visible = false esp.LeftArm.Visible = false esp.RightArm.Visible = false esp.LeftLeg.Visible = false esp.RightLeg.Visible = false
            end
        else
            if esp.Box then
                esp.Box.Visible = false esp.HealthBar.Visible = false esp.Name.Visible = false esp.Tracer.Visible = false
                esp.Spine.Visible = false esp.LeftArm.Visible = false esp.RightArm.Visible = false esp.LeftLeg.Visible = false esp.RightLeg.Visible = false
            end
        end
    end
end)

RunService.Stepped:Connect(function()
    if LocalPlayer.Character then
        if Config.HoldJump and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.Jump = true
            end
        end

        if Config.Noclip then
            WasNoclip = true
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        else
            if WasNoclip then
                WasNoclip = false
                local torso = LocalPlayer.Character:FindFirstChild("UpperTorso") or LocalPlayer.Character:FindFirstChild("Torso")
                local head = LocalPlayer.Character:FindFirstChild("Head")
                local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if torso then torso.CanCollide = true end
                if head then head.CanCollide = true end
                if root then root.CanCollide = true end
            end
        end
        if Config.Speed and not Config.Fly and not Config.FlyTP and LocalPlayer.Character:FindFirstChild("Humanoid") then
            local hum = LocalPlayer.Character.Humanoid
            hum.PlatformStand = false
            if LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local root = LocalPlayer.Character.HumanoidRootPart
                if root.Velocity.Y < -50 then
                    root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
                end
            end
        end
    end
end)

UpdateTpMenu()
UpdateFriendTpMenu()
UpdateWaypointMenu()
UpdateFriendsMenu()