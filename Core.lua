local addonName, addon = ...

addon.name = addonName
addon.defaults = {
    orderPreviews = true,
    recipeSpecializations = true,
}

local eventFrame = CreateFrame("Frame")

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
end

function addon:Print(message)
    local icon = "|TInterface\\AddOns\\BetterProfessions\\Media\\Icon.tga:16:16:0:0|t"
    DEFAULT_CHAT_FRAME:AddMessage(icon .. " |cff3fc7ebBetterProfessions:|r " .. tostring(message))
end

function addon:InitializeDatabase()
    BetterProfessionsDB = BetterProfessionsDB or {}
    CopyDefaults(BetterProfessionsDB, self.defaults)
    self.db = BetterProfessionsDB
end

function addon:InitializeBlizzardUI()
    if self.blizzardUIInitialized or not ProfessionsFrame then
        return
    end

    self.blizzardUIInitialized = true
    if self.OrderList then
        self.OrderList:Initialize()
    end
    if self.RecipeSpecializations then
        self.RecipeSpecializations:Initialize()
    end
end

local function SetOption(key, label)
    addon.db[key] = not addon.db[key]
    addon:Print(string.format("%s: %s. %s", label, addon.db[key] and addon.L.ENABLED or addon.L.DISABLED, addon.L.RELOAD_TO_APPLY))
end

local function HandleSlashCommand(text)
    local command = strtrim(text or ""):lower()
    if command == "orders" then
        SetOption("orderPreviews", addon.L.ORDERS_OPTION)
    elseif command == "specs" then
        SetOption("recipeSpecializations", addon.L.SPECS_OPTION)
    elseif command == "reset" then
        wipe(BetterProfessionsDB)
        CopyDefaults(BetterProfessionsDB, addon.defaults)
        addon:Print(addon.L.RESET_DONE .. " " .. addon.L.RELOAD_TO_APPLY)
    else
        addon:Print(addon.L.COMMAND_HELP)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            addon:InitializeDatabase()
            SLASH_BETTERPROFESSIONS1 = "/betterprofessions"
            SLASH_BETTERPROFESSIONS2 = "/bp"
            SlashCmdList.BETTERPROFESSIONS = HandleSlashCommand

            if C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
                addon:InitializeBlizzardUI()
            end
        elseif arg1 == "Blizzard_Professions" and addon.db then
            addon:InitializeBlizzardUI()
        end
        return
    end

    if addon.OrderList and addon.OrderList.OnEvent then
        addon.OrderList:OnEvent(event, arg1, ...)
    end
    if addon.RecipeSpecializations and addon.RecipeSpecializations.OnEvent then
        addon.RecipeSpecializations:OnEvent(event, arg1, ...)
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("CRAFTINGORDERS_CAN_REQUEST")
eventFrame:RegisterEvent("CRAFTINGORDERS_UPDATE_ORDER_COUNT")
eventFrame:RegisterEvent("CRAFTINGORDERS_UPDATE_REWARDS")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("TRAIT_NODE_CHANGED")
eventFrame:RegisterEvent("OPEN_RECIPE_RESPONSE")
