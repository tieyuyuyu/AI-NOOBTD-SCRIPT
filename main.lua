local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = game:GetService("Players").LocalPlayer

-- 1. 账户文件夹
local PlayerName = LocalPlayer.Name
local ConfigFolder = "NoobTD_Configs/" .. PlayerName
local SettingsFile = ConfigFolder .. "/AccountSettings.json"

if not isfolder("NoobTD_Configs") then makefolder("NoobTD_Configs") end
if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end

local Options = { 
    AutoStart = false, AutoReady = false, AutoRestart = false, 
    SpeedMode = "二倍速",
    Difficulty = "None", SelectedFile = "",
    AutoRejoin = false,
}

local SCRIPT_URL = "https://raw.githubusercontent.com/tieyuyuyu/AI-NOOBTD-SCRIPT/refs/heads/main/main.lua"

-- 2. 保存和读取
local function Save() writefile(SettingsFile, HttpService:JSONEncode(Options)) end
if isfile(SettingsFile) then
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SettingsFile)) end)
    if ok then 
        for k,v in pairs(data) do 
            if k == "AutoSpeed" then
                if v == true then Options.SpeedMode = "二倍速" else Options.SpeedMode = "关闭" end
            else
                Options[k] = v 
            end
        end
    end
end

-- 3. 常用变量
local GameRunning = ReplicatedStorage.Values.GameRunning
local ID_Table, SuccessBook, ActivePlan = {}, {}, {}
local Recording, CurrentMacro, RN = false, {}, ""
local PreparationDone = false
local AbilityTimer = 0
local SelectedRecFile = ""
local HasAbilityInPlan = false

-- 跨服函数
local queue_on_teleport = queue_on_teleport or (syn and syn.queue_on_teleport)
local clearteleportqueue = clearteleportqueue or (syn and syn.clearteleportqueue)

local function setupAutoRejoin()
    if not queue_on_teleport then return false end
    if not Options.AutoRejoin then return false end

    local reloadCode = string.format([[
        if not game:IsLoaded() then game.Loaded:Wait() end
        local success, err = pcall(function()
            loadstring(game:HttpGet('%s'))()
        end)
        if not success then warn("NoobTD 复活失败: " .. tostring(err)) end
    ]], SCRIPT_URL)

    queue_on_teleport(reloadCode)
    return true
end

local function clearAutoRejoin()
    if not clearteleportqueue then return false end
    clearteleportqueue()
    return true
end

-- 4. 解析
local function ParseMacro(content)
    local body = content:gsub("local%s+ActionPlan%s*=%s*", ""):gsub("return%s+ActionPlan", "")
    body = body:match("^%s*(.*)%s*$")
    local function tryLoad(testCode)
        local func = loadstring("return " .. testCode)
        if func then
            setfenv(func, { Vector3 = Vector3, table = table, string = string, print = print })
            local ok, res = pcall(func)
            if ok and type(res) == "table" and #res > 0 then return res end
        end
        return nil
    end
    return tryLoad(body) or tryLoad("{" .. body .. "}") or {}
end

local function CheckAbilityInPlan()
    HasAbilityInPlan = false
    for _, data in ipairs(ActivePlan) do
        if data[2] == "Ability" then HasAbilityInPlan = true break end
    end
end

local function RefreshIDTable()
    local ok, constants = pcall(function() return require(ReplicatedStorage.Modules.Data.Constants) end)
    if ok and constants and constants.currentPlrData then
        table.clear(ID_Table)
        for _, v in pairs(constants.currentPlrData.Items.Towers) do
            if type(v) == "table" and v.Locked == true then 
                ID_Table[v.Tower] = v.TowerID or v.ID 
            end
        end
    end
end

-- 5. 执行引擎
local function scanAndFix()
    if not GameRunning.Value or #ActivePlan == 0 then return end
    local coins = LocalPlayer.leaderstats.Coins.Value
    local wave = ReplicatedStorage.Values.Wave.Value

    for i = 1, #ActivePlan do
        if not SuccessBook[i] then
            local data = ActivePlan[i]
            if wave < data[1] or coins < data[4] then break end

            local action, name, extra = data[2], data[3], data[5]
            local success = false
            
            if action == "Place" then
                local tid = ID_Table[name]
                if tid then
                    pcall(function() 
                        ReplicatedStorage.Remotes.Functions.PlaceTower:InvokeServer({
                            towerToPlace = name, towerID = tid,
                            instance = workspace.Map.Map.Baseplate.Placeable.Part,
                            position = (type(extra) == "table") and Vector3.new(extra[1], extra[2], extra[3]) or extra
                        }) 
                    end)
                    Rayfield:Notify({Title = "放塔", Content = "放下 "..name.." (第"..wave.."波)", Duration = 2})
                    success = true
                else RefreshIDTable() break end
            elseif action == "Upgrade" then
                pcall(function() ReplicatedStorage.Remotes.Functions.UpgradeTower:InvokeServer(tostring(extra)) end)
                Rayfield:Notify({Title = "升级", Content = "升级完成，编号: "..tostring(extra), Duration = 2})
                success = true
            elseif action == "Ability" then
                pcall(function()
                    ReplicatedStorage.Remotes.Functions.TowerAbility:InvokeServer(tostring(name), tostring(extra))
                end)
                Rayfield:Notify({Title = "技能", Content = "塔"..tostring(name).." 用了 "..tostring(extra), Duration = 2})
                success = true
            end
            if success then SuccessBook[i] = true task.wait(0.3) end
            break 
        end
    end
end

-- 6. 自动技能
task.spawn(function()
    while true do
        if GameRunning.Value and Options.AutoStart and HasAbilityInPlan then
            if tick() - AbilityTimer >= 31 then
                pcall(function()
                    ReplicatedStorage.Remotes.Functions.TowerAbility:InvokeServer("1", "Rage")
                end)
                Rayfield:Notify({Title = "自动技能", Content = "Rage 已用 (塔1)", Duration = 2})
                AbilityTimer = tick()
            end
        else
            AbilityTimer = tick()
        end
        task.wait(1)
    end
end)

-- 7. UI
local Window = Rayfield:CreateWindow({
   Name = "Noob TD",
   LoadingTitle = "正在加载 " .. PlayerName,
   ConfigurationSaving = { Enabled = false }
})

local TabFarm = Window:CreateTab("挂机", 4483362458)
local TabSet = Window:CreateTab("自动功能", 4483362458)
local TabRec = Window:CreateTab("录制与文件", 4483362458)

local function GetRecFiles()
    local files = {}
    for _, f in ipairs(listfiles(ConfigFolder)) do
        if f:find(".json") and not f:find("Account") then
            table.insert(files, f:match("([^/\\]+)%.%w+$"))
        end
    end
    return files
end

TabFarm:CreateToggle({
   Name = "自动挂机",
   CurrentValue = Options.AutoStart,
   Callback = function(Value) Options.AutoStart = Value Save() end,
})

local MacroDropdown = TabFarm:CreateDropdown({
   Name = "选择方案",
   Options = GetRecFiles(),
   CurrentOption = {Options.SelectedFile},
   Callback = function(Option)
      Options.SelectedFile = Option[1] Save()
      local p = ConfigFolder.."/"..Option[1]..".json"
      if isfile(p) then 
         ActivePlan = ParseMacro(readfile(p))
         SuccessBook = {}
         CheckAbilityInPlan()
         RefreshIDTable()
         Rayfield:Notify({Title = "方案已加载", Content = "一共 "..#ActivePlan.." 步", Duration = 3})
      end
   end,
})

TabSet:CreateToggle({Name = "自动准备", CurrentValue = Options.AutoReady, Callback = function(v) Options.AutoReady = v Save() end})
TabSet:CreateToggle({Name = "自动重开", CurrentValue = Options.AutoRestart, Callback = function(v) Options.AutoRestart = v Save() end})

TabSet:CreateToggle({
    Name = "自动执行",
    CurrentValue = Options.AutoRejoin,
    Callback = function(v)
        Options.AutoRejoin = v
        Save()
        if v then
            local ok = setupAutoRejoin()
            if ok then
                Rayfield:Notify({Title = "自动执行", Content = "开了，换服后脚本自动执行", Duration = 3})
            else
                Rayfield:Notify({Title = "跨服重开", Content = "注入器不支持 queue_on_teleport", Duration = 5})
            end
        else
            clearAutoRejoin()
            Rayfield:Notify({Title = "跨服重开", Content = "关了，换服后不会执行", Duration = 3})
        end
    end,
})

TabSet:CreateDropdown({
    Name = "倍速",
    Options = {"关闭", "二倍速", "三倍速"},
    CurrentOption = {Options.SpeedMode},
    Callback = function(v) Options.SpeedMode = v[1] Save() end,
})

TabSet:CreateDropdown({
   Name = "难度", Options = {"None", "Easy", "Medium", "Hard", "Extreme"}, CurrentOption = {Options.Difficulty},
   Callback = function(v) Options.Difficulty = v[1] Save() end,
})

TabRec:CreateInput({Name = "录制文件名", PlaceholderText = "取个名字...", Callback = function(v) RN = v end})
TabRec:CreateToggle({Name = "开始录制", CurrentValue = false, Callback = function(v) 
    Recording = v 
    if v then 
        CurrentMacro = {}
        Rayfield:Notify({Title = "录制", Content = "录制模式已开启", Duration = 2})
    else
        Rayfield:Notify({Title = "录制", Content = "录制模式已关闭", Duration = 2})
    end
end})

local RecFileDropdown = TabRec:CreateDropdown({
    Name = "删哪个文件",
    Options = GetRecFiles(),
    CurrentOption = {""},
    Callback = function(Option) SelectedRecFile = Option[1] end,
})

TabRec:CreateButton({
    Name = "删掉",
    Callback = function()
        if SelectedRecFile == "" then
            Rayfield:Notify({Title = "出错", Content = "还没选文件", Duration = 3})
            return
        end
        local filePath = ConfigFolder.."/"..SelectedRecFile..".json"
        if isfile(filePath) then
            delfile(filePath)
            Rayfield:Notify({Title = "成功", Content = "删掉了 "..SelectedRecFile..".json", Duration = 3})
            SelectedRecFile = ""
            local newFiles = GetRecFiles()
            RecFileDropdown:Set(newFiles)
            if Options.SelectedFile == SelectedRecFile then
                Options.SelectedFile = ""
                ActivePlan = {}
                SuccessBook = {}
                HasAbilityInPlan = false
                Save()
                Rayfield:Notify({Title = "提醒", Content = "刚才加载的方案被删了，重新选", Duration = 3})
            end
        else
            Rayfield:Notify({Title = "出错", Content = "文件好像没了", Duration = 3})
        end
    end,
})

-- 8. 主循环
task.spawn(function()
    while true do
        task.wait(1)
        
        if not GameRunning.Value then
            if Options.AutoReady and not PreparationDone then
                Rayfield:Notify({Title = "准备", Content = "等10秒就准备", Duration = 5})
                task.wait(10)
                if not GameRunning.Value then
                    pcall(function() ReplicatedStorage.Remotes.Events.Ready:FireServer() end)
                    Rayfield:Notify({Title = "准备", Content = "已准备", Duration = 2})
                    if Options.Difficulty ~= "None" then
                        task.wait(5)
                        pcall(function() ReplicatedStorage.Remotes.Events.Gamemode:FireServer(Options.Difficulty) end)
                        Rayfield:Notify({Title = "准备", Content = "已选难度: "..Options.Difficulty, Duration = 2})
                    end
                    PreparationDone = true
                end
            end
        else
            if PreparationDone then
                Rayfield:Notify({Title = "状态", Content = "开始了，配置中...", Duration = 3})
                task.wait(2)
                local speedParam = nil
                if Options.SpeedMode == "二倍速" then speedParam = 1
                elseif Options.SpeedMode == "三倍速" then speedParam = 2 end
                if speedParam then
                    pcall(function() ReplicatedStorage.Remotes.Events.InitChangeSpeed:FireServer(speedParam) end)
                    Rayfield:Notify({Title = "状态", Content = "已开启 "..Options.SpeedMode, Duration = 2})
                else
                    Rayfield:Notify({Title = "状态", Content = "倍速已关闭", Duration = 2})
                end
                RefreshIDTable()
                PreparationDone = false
                AbilityTimer = tick()
            end
            if Options.AutoStart then scanAndFix() end
        end
    end
end)

-- 结算重开
GameRunning.Changed:Connect(function(isRunning)
    if not isRunning then
        SuccessBook = {}
        PreparationDone = false
        if Options.AutoRestart then
            Rayfield:Notify({Title = "结算", Content = "8秒后重开", Duration = 5})
            task.wait(8)
            pcall(function() ReplicatedStorage.Remotes.Events.Replay:FireServer() end)
        end
    end
end)

-- 9. 录制钩子（通知已确保存在）
local OldNC
OldNC = hookmetamethod(game, "__namecall", function(self, ...)
    local Method = getnamecallmethod()
    local Args = {...}
    
    if not Recording or Method ~= "InvokeServer" then 
        return OldNC(self, ...) 
    end

    local wave = ReplicatedStorage.Values.Wave.Value
    local actionType = ""
    local cost = 0
    local result

    if self.Name == "PlaceTower" then
        local before = LocalPlayer.leaderstats.Coins.Value
        result = OldNC(self, ...)
        task.wait(0.1)
        local after = LocalPlayer.leaderstats.Coins.Value
        cost = math.max(0, before - after)
        if cost <= 0 then cost = Args[1].cost or 0 end
        
        table.insert(CurrentMacro, {wave, 'Place', Args[1].towerToPlace, cost, {Args[1].position.X, Args[1].position.Y, Args[1].position.Z}})
        
        -- 这行就是通知：录了什么塔
        Rayfield:Notify({
            Title = "录到操作", 
            Content = "放塔: "..Args[1].towerToPlace.." 花费: "..cost, 
            Duration = 2
        })

    elseif self.Name == "UpgradeTower" then
        local before = LocalPlayer.leaderstats.Coins.Value
        result = OldNC(self, ...)
        task.wait(0.1)
        local after = LocalPlayer.leaderstats.Coins.Value
        cost = math.max(0, before - after)
        if cost <= 0 then cost = 0 end
        
        table.insert(CurrentMacro, {wave, 'Upgrade', 'Tower', cost, tostring(Args[1])})
        
        -- 这行就是通知：录了什么升级
        Rayfield:Notify({
            Title = "录到操作", 
            Content = "升级: ID "..tostring(Args[1]).." 花费: "..cost, 
            Duration = 2
        })

    elseif self.Name == "TowerAbility" then
        result = OldNC(self, ...)
        table.insert(CurrentMacro, {wave, 'Ability', tostring(Args[1]), 0, tostring(Args[2])})
        
        -- 这行就是通知：录了什么技能
        Rayfield:Notify({
            Title = "录到操作", 
            Content = "技能: 塔"..tostring(Args[1]).." 用了 "..tostring(Args[2]), 
            Duration = 2
        })

    else
        return OldNC(self, ...)
    end

-- 10. 启动加载
if Options.SelectedFile ~= "" then
    local p = ConfigFolder.."/"..Options.SelectedFile..".json"
    if isfile(p) then ActivePlan = ParseMacro(readfile(p)); CheckAbilityInPlan() end
end

-- 防掉线
local VIM = game:GetService("VirtualInputManager")
LocalPlayer.Idled:Connect(function()
    pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 0, true, nil, 1)
        VIM:SendMouseButtonEvent(0, 0, 0, false, nil, 1)
    end)
end)
