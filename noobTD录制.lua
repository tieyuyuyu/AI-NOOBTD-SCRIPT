-- [[ Noob TD 自动录制并存入文件脚本 ]] --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Coins = Players.LocalPlayer.leaderstats.Coins
local WaveValue = ReplicatedStorage.Values.Wave

local fileName = "NoobTD_Macro_Data.txt"
writefile(fileName, "-- Noob TD 录制操作清单 --\n") -- 创建/初始化文件

print("--- 录制器已启动：结果将实时保存至执行器 workspace/" .. fileName .. " ---")

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if method == "InvokeServer" and (self.Name == "PlaceTower" or self.Name == "UpgradeTower") then
        local moneyBefore = Coins.Value
        local currentWave = WaveValue.Value
        
        -- 执行并获取结果
        local result = oldNamecall(self, ...)
        task.wait(0.1) -- 等待金钱刷新
        
        local cost = moneyBefore - Coins.Value
        local codeLine = ""

        if self.Name == "PlaceTower" then
            local tName = args[1].towerToPlace
            local pos = args[1].position
            codeLine = string.format("{%d, 'Place', '%s', %d, Vector3.new(%.2f, %.2f, %.2f)},", 
                currentWave, tName, cost, pos.X, pos.Y, pos.Z)
        elseif self.Name == "UpgradeTower" then
            local towerIdx = tostring(args[1])
            codeLine = string.format("{%d, 'Upgrade', 'Tower', %d, '%s'},", 
                currentWave, cost, towerIdx)
        end
        
        -- 保存到文件并打印输出
        appendfile(fileName, codeLine .. "\n")
        print("已记录并保存: " .. codeLine)
        
        return result
    end
    return oldNamecall(self, ...)
end)
