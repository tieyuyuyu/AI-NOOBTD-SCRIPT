local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local VirtualUser = game:GetService("VirtualUser")  


local PlayerName = LocalPlayer.Name
local ConfigFolder = "NoobTD_Configs/" .. PlayerName
local SettingsFile = ConfigFolder .. "/AccountSettings.json"

if not isfolder("NoobTD_Configs") then makefolder("NoobTD_Configs") end
if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end

local Options = { 
    AutoStart = false, AutoReady = false, AutoRestart = false, 
    AutoSpeed = true,
    Difficulty = "None", SelectedFile = "" 
}


local function Save() writefile(SettingsFile, HttpService:JSONEncode(Options)) end
if isfile(SettingsFile) then
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SettingsFile)) end)
    if ok then for k,v in pairs(data) do Options[k] = v end end
end


local GameRunning = ReplicatedStorage.Values.GameRunning
local ID_Table, SuccessBook, ActivePlan = {}, {}, {}
local Recording, CurrentMacro, RN = false, {}, ""
local PreparationDone = false
local AbilityTimer = 0
local SelectedRecFile = ""
local HasAbilityInPlan = false


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
        if data[2] == "Ability" then
            HasAbilityInPlan = true
            break
        end
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
                            ["towerToPlace"] = name, ["towerID"] = tid,
                            ["instance"] = workspace.Map.Map.Baseplate.Placeable.Part,
                            ["position"] = (type(extra) == "table") and Vector3.new(extra[1], extra[2], extra[3]) or extra
                        }) 
                    end)
                    Rayfield:Notify({Title = "自动放置", Content = "已放置: "..name.." (波次: "..wave..")", Duration = 2})
                    success = true
                else RefreshIDTable() break end
            elseif action == "Upgrade" then
                pcall(function() ReplicatedStorage.Remotes.Functions.UpgradeTower:InvokeServer(tostring(extra)) end)
                Rayfield:Notify({Title = "自动升级", Content = "升级成功 (ID: "..tostring(extra)..")", Duration = 2})
                success = true
            elseif action == "Ability" then
                pcall(function()
                    ReplicatedStorage.Remotes.Functions.TowerAbility:InvokeServer(tostring(name), tostring(extra))
                end)
                Rayfield:Notify({Title = "技能释放", Content = "塔"..tostring(name).." 使用 "..tostring(extra), Duration = 2})
                success = true
            end
            if success then SuccessBook[i] = true task.wait(0.3) end
            break 
        end
    end
end


task.spawn(function()
    while true do
        if GameRunning.Value and Options.AutoStart and HasAbilityInPlan then
            if tick() - AbilityTimer >= 31 then
                pcall(function()
                    ReplicatedStorage.Remotes.Functions.TowerAbility:InvokeServer("1", "Rage")
                end)
                Rayfield:Notify({Title = "自动技能", Content = "已释放 Rage (塔1)", Duration = 2})
                AbilityTimer = tick()
            end
        else
            AbilityTimer = tick()
        end
        task.wait(1)
    end
end)


local Window = Rayfield:CreateWindow({
   Name = "Noob TD",
   LoadingTitle = "正在载入账户: " .. PlayerName,
   ConfigurationSaving = { Enabled = false }
})

local TabFarm = Window:CreateTab("自动操作页面", 4483362458)
local TabSet = Window:CreateTab("自动化", 4483362458)
local TabRec = Window:CreateTab("录制", 4483362458)

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
   Name = "开启自动挂机",
   CurrentValue = Options.AutoStart,
   Callback = function(Value) Options.AutoStart = Value Save() end,
})

local MacroDropdown = TabFarm:CreateDropdown({
   Name = "选择宏文件",
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
         Rayfield:Notify({Title = "宏已就绪", Content = "已加载 "..#ActivePlan.." 条指令", Duration = 3})
      end
   end,
})

TabSet:CreateToggle({Name = "自动准备 (每局触发)", CurrentValue = Options.AutoReady, Callback = function(v) Options.AutoReady = v Save() end})
TabSet:CreateToggle({Name = "自动重开 (Replay)", CurrentValue = Options.AutoRestart, Callback = function(v) Options.AutoRestart = v Save() end})
TabSet:CreateToggle({Name = "自动二倍速", CurrentValue = Options.AutoSpeed, Callback = function(v) Options.AutoSpeed = v Save() end})
TabSet:CreateDropdown({
   Name = "预设难度", Options = {"None", "Easy", "Medium", "Hard", "Extreme"}, CurrentOption = {Options.Difficulty},
   Callback = function(v) Options.Difficulty = v[1] Save() end,
})

TabRec:CreateInput({Name = "文件名", PlaceholderText = "输入名称...", Callback = function(v) RN = v end})
TabRec:CreateToggle({Name = "🔴 录制模式", CurrentValue = false, Callback = function(v) Recording = v end})

local RecFileDropdown = TabRec:CreateDropdown({
    Name = "选择要删除的录制文件",
    Options = GetRecFiles(),
    CurrentOption = {""},
    Callback = function(Option) SelectedRecFile = Option[1] end,
})

TabRec:CreateButton({
    Name = "删除选中的录制文件",
    Callback = function()
        if SelectedRecFile == "" then
            Rayfield:Notify({Title = "删除失败", Content = "请先选择文件", Duration = 3})
            return
        end
        local filePath = ConfigFolder.."/"..SelectedRecFile..".json"
        if isfile(filePath) then
            delfile(filePath)
            Rayfield:Notify({Title = "删除成功", Content = "已删除 "..SelectedRecFile..".json", Duration = 3})
            SelectedRecFile = ""
            local newFiles = GetRecFiles()
            RecFileDropdown:Set(newFiles)
            if Options.SelectedFile == SelectedRecFile then
                Options.SelectedFile = ""
                ActivePlan = {}
                SuccessBook = {}
                HasAbilityInPlan = false
                Save()
                Rayfield:Notify({Title = "提示", Content = "已删除当前加载的宏，请重新选择", Duration = 3})
            end
        else
            Rayfield:Notify({Title = "删除失败", Content = "文件不存在", Duration = 3})
        end
    end,
})


task.spawn(function()
    while true do
        task.wait(1)
        
        if not GameRunning.Value then
            if Options.AutoReady and not PreparationDone then
                Rayfield:Notify({Title = "准备流程", Content = "检测到房间，10秒后自动准备", Duration = 5})
                task.wait(10)
                
                if not GameRunning.Value then
                    pcall(function() ReplicatedStorage.Remotes.Events.Ready:FireServer() end)
                    Rayfield:Notify({Title = "准备流程", Content = "✅ 已发送【准备】指令", Duration = 2})
                    
                    if Options.Difficulty ~= "None" then
                        task.wait(5)
                        pcall(function() ReplicatedStorage.Remotes.Events.Gamemode:FireServer(Options.Difficulty) end)
                        Rayfield:Notify({Title = "准备流程", Content = "📊 已选择难度: "..Options.Difficulty, Duration = 2})
                    end
                    PreparationDone = true
                end
            end
        else
            if PreparationDone then
                Rayfield:Notify({Title = "游戏状态", Content = "游戏已开始，正在初始化脚本...", Duration = 3})
                task.wait(2)
                if Options.AutoSpeed then
                    pcall(function() ReplicatedStorage.Remotes.Events.InitChangeSpeed:FireServer(1) end)
                    Rayfield:Notify({Title = "游戏状态", Content = "🚀 已开启二倍速", Duration = 2})
                else
                    Rayfield:Notify({Title = "游戏状态", Content = "二倍速已关闭", Duration = 2})
                end
                RefreshIDTable()
                PreparationDone = false
                AbilityTimer = tick()
            end
            
            if Options.AutoStart then scanAndFix() end
        end
    end
end)


GameRunning.Changed:Connect(function(isRunning)
    if not isRunning then
        SuccessBook = {}
        PreparationDone = false
        if Options.AutoRestart then
            Rayfield:Notify({Title = "结算", Content = "8秒后自动 Replay 重开", Duration = 5})
            task.wait(8)
            pcall(function() ReplicatedStorage.Remotes.Events.Replay:FireServer() end)
        end
    end
end)


local OldNC
OldNC = hookmetamethod(game, "__namecall", function(self, ...)
    local Method, Args = getnamecallmethod(), {...}
    if Recording and Method == "InvokeServer" then
        local wave = ReplicatedStorage.Values.Wave.Value
        local actionType = ""
        if self.Name == "PlaceTower" then
            table.insert(CurrentMacro, {wave, 'Place', Args[1].towerToPlace, 0, {Args[1].position.X, Args[1].position.Y, Args[1].position.Z}})
            actionType = "放置 "..Args[1].towerToPlace
        elseif self.Name == "UpgradeTower" then
            table.insert(CurrentMacro, {wave, 'Upgrade', 'Tower', 0, tostring(Args[1])})
            actionType = "升级 ID:"..tostring(Args[1])
        elseif self.Name == "TowerAbility" then
            table.insert(CurrentMacro, {wave, 'Ability', tostring(Args[1]), 0, tostring(Args[2])})
            actionType = "技能 "..tostring(Args[2]).." (塔"..tostring(Args[1])..")"
        end
        if actionType ~= "" then
            Rayfield:Notify({Title = "录制中", Content = "已记录: "..actionType.." (波次 "..wave..")", Duration = 2})
        end
        local s = "local ActionPlan = {\n"
        for _,v in ipairs(CurrentMacro) do s = s .. string.format("    {%d, '%s', '%s', %d, %s},\n", v[1], v[2], v[3], v[4], type(v[5])=="table" and "Vector3.new("..v[5][1]..","..v[5][2]..","..v[5][3]..")" or "'"..v[5].."'") end
        writefile(ConfigFolder.."/"..(RN~="" and RN or "未命名")..".json", s.."}\nreturn ActionPlan")
    end
    return OldNC(self, ...)
end)


if Options.SelectedFile ~= "" then
    local p = ConfigFolder.."/"..Options.SelectedFile..".json"
    if isfile(p) then
        ActivePlan = ParseMacro(readfile(p))
        CheckAbilityInPlan()
    end
end


local VIM = game:GetService("VirtualInputManager")
LocalPlayer.Idled:Connect(function()
    pcall(function()
        VIM:SendMouseButtonEvent(0, 0, 0, true, nil, 1)   
        VIM:SendMouseButtonEvent(0, 0, 0, false, nil, 1)  
    end)
end)
