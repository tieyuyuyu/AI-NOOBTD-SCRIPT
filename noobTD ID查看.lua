-- [[ Noob TD 深度 ID 提取器 ]] --
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function deepExportTowers()
    local success, Constants = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("Constants"))
    end)
    
    if not success or not Constants or not Constants.currentPlrData then
        warn("❌ 无法读取 Constants 模块。请确保你已在对局中。")
        return
    end

    local towers = Constants.currentPlrData.Items.Towers
    local resultText = "-- 当前账号防御塔深度数据清单 --\n\n"
    
    for uid, data in pairs(towers) do
        resultText = resultText .. "【唯一ID】: " .. tostring(uid) .. "\n"
        
        if type(data) == "table" then
            -- 自动遍历表里的所有字段，看看哪个是名字
            for key, value in pairs(data) do
                resultText = resultText .. "   -> " .. tostring(key) .. " : " .. tostring(value) .. "\n"
            end
        else
            resultText = resultText .. "   -> 数据内容: " .. tostring(data) .. "\n"
        end
        resultText = resultText .. "------------------------------------------\n"
    end
    
    if setclipboard then
        setclipboard(resultText)
        print("✅ 深度数据已复制到剪贴板！请到记事本查看。")
    else
        warn("❌ 执行器不支持 setclipboard")
    end
end

deepExportTowers()
