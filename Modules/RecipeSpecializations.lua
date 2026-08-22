local _, addon = ...

local RecipeSpecializations = {}
addon.RecipeSpecializations = RecipeSpecializations

local PANEL_WIDTH = 314
local PANEL_HEIGHT = 430
local CONTENT_WIDTH = PANEL_WIDTH - 52
local ROW_HEIGHT = 48
local ROW_GAP = 5

local function GetNodeVisuals(configID, nodeID, nodeInfo)
    local entryID = nodeInfo and nodeInfo.entryIDs and nodeInfo.entryIDs[1]
    if not entryID then
        return "Node " .. nodeID, 134400
    end

    local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
    local definitionInfo = entryInfo and C_Traits.GetDefinitionInfo(entryInfo.definitionID)
    if not definitionInfo then
        return "Node " .. nodeID, 134400
    end

    return definitionInfo.overrideName or ("Node " .. nodeID), definitionInfo.overrideIcon or 134400
end

local function GetNodeProgress(nodeID, definition, nodeInfo)
    local currentRank = math.max(0, (nodeInfo.activeRank or 0) - 1)
    local maxRank = definition[1] or 0
    if maxRank <= 0 then
        maxRank = nodeInfo.maxRanks and math.max(0, nodeInfo.maxRanks - 1) or nodeInfo.maxRank or currentRank
    end

    local skillPerRank = definition[2] or 0
    local currentSkill = currentRank * skillPerRank
    local maxSkill = maxRank * skillPerRank
    local perks = definition[3] or {}
    local perkProgress = {}

    for _, perk in ipairs(perks) do
        local perkID, skill = perk[1], perk[2]
        local unlockRank = C_ProfSpecs.GetUnlockRankForPerk(perkID) or 0
        local active = currentRank >= unlockRank
        if active then
            currentSkill = currentSkill + skill
        end
        maxSkill = maxSkill + skill
        perkProgress[#perkProgress + 1] = {
            perkID = perkID,
            skill = skill,
            unlockRank = unlockRank,
            active = active,
        }
        if unlockRank > maxRank then
            maxRank = unlockRank
        end
    end

    return currentRank, maxRank, currentSkill, maxSkill, perkProgress
end

local function RowOnEnter(self)
    local data = self.data
    if not data then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(data.name, 1, 0.82, 0)
    local description = C_ProfSpecs.GetDescriptionForPath(data.nodeID)
    if description and description ~= "" then
        GameTooltip:AddLine(description, 1, 1, 1, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(addon.L.RANK, string.format("%d/%d", data.currentRank, data.maxRank), 1, 1, 1, 1, 1, 1)
    if data.maxSkill > 0 then
        GameTooltip:AddDoubleLine(addon.L.SKILL_FROM_SPECS, string.format("+%d / +%d", data.currentSkill, data.maxSkill), 1, 1, 1, 0.35, 0.75, 1)
    end

    for _, perk in ipairs(data.perks) do
        local color = perk.active and "|cff40ff40" or "|cff888888"
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("%s%s %d: +%d %s|r", color, addon.L.RANK, perk.unlockRank, perk.skill, addon.L.SKILL), 1, 1, 1)
        local perkDescription = C_ProfSpecs.GetDescriptionForPerk(perk.perkID)
        if perkDescription and perkDescription ~= "" then
            GameTooltip:AddLine(color .. perkDescription .. "|r", 1, 1, 1, true)
        end
    end
    GameTooltip:Show()
end

local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(CONTENT_WIDTH, ROW_HEIGHT)
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    row:SetBackdropColor(0.04, 0.05, 0.07, 0.82)
    row:SetBackdropBorderColor(0.22, 0.25, 0.3, 0.9)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(34, 34)
    row.icon:SetPoint("LEFT", 7, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.qualityBadge = row:CreateTexture(nil, "OVERLAY")
    row.qualityBadge:SetSize(15, 15)
    row.qualityBadge:SetPoint("TOPRIGHT", row.icon, "TOPRIGHT", 4, 4)
    row.qualityBadge:SetAtlas("Professions_Icon_FirstTimeCraft", false)

    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 7, -2)
    row.name:SetPoint("RIGHT", -55, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.rank = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.rank:SetPoint("TOPRIGHT", -7, -5)

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.bar:SetPoint("BOTTOMLEFT", row.name, 0, -18)
    row.bar:SetPoint("BOTTOMRIGHT", -49, 8)
    row.bar:SetHeight(8)

    row.barBackground = row.bar:CreateTexture(nil, "BACKGROUND")
    row.barBackground:SetAllPoints()
    row.barBackground:SetColorTexture(0.12, 0.13, 0.16, 1)

    row.skill = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.skill:SetPoint("RIGHT", -7, -12)

    row:SetScript("OnEnter", RowOnEnter)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

function RecipeSpecializations:CreatePanel()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "BetterProfessionsSpecializationFrame", UIParent, "BackdropTemplate")
    frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 8, -54)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 256,
        edgeSize = 24,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    frame:SetBackdropColor(0.06, 0.07, 0.09, 0.97)

    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 18, -16)
    frame.title:SetText(addon.L.QUALITY_TITLE)

    frame.subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -5)
    frame.subtitle:SetPoint("RIGHT", -18, 0)
    frame.subtitle:SetJustifyH("LEFT")
    frame.subtitle:SetText(CreateAtlasMarkup("Professions_Icon_FirstTimeCraft", 14, 14) .. " " .. addon.L.QUALITY_SUBTITLE)

    frame.total = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.total:SetPoint("TOPLEFT", frame.subtitle, "BOTTOMLEFT", 0, -9)
    frame.total:SetPoint("RIGHT", -18, 0)
    frame.total:SetJustifyH("LEFT")

    frame.scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scrollFrame:SetPoint("TOPLEFT", 16, -76)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", -31, 16)

    frame.scrollChild = CreateFrame("Frame", nil, frame.scrollFrame)
    frame.scrollChild:SetSize(CONTENT_WIDTH, 1)
    frame.scrollFrame:SetScrollChild(frame.scrollChild)
    frame.rows = {}

    frame.emptyText = frame.scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.emptyText:SetPoint("TOPLEFT", 8, -20)
    frame.emptyText:SetPoint("RIGHT", -8, 0)
    frame.emptyText:SetJustifyH("CENTER")
    frame.emptyText:SetText(addon.L.NO_RELATED_NODES)

    frame:Hide()
    self.frame = frame
end

function RecipeSpecializations:GetRow(index)
    local row = self.frame.rows[index]
    if row then
        return row
    end

    row = CreateRow(self.frame.scrollChild)
    if index == 1 then
        row:SetPoint("TOPLEFT")
    else
        row:SetPoint("TOPLEFT", self.frame.rows[index - 1], "BOTTOMLEFT", 0, -ROW_GAP)
    end
    self.frame.rows[index] = row
    return row
end

function RecipeSpecializations:GetCurrentSkillLineID(recipeID)
    local professionInfo = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipeID)
    if professionInfo and professionInfo.professionID then
        return professionInfo.professionID
    end
    return C_TradeSkillUI.GetProfessionChildSkillLineID()
end

function RecipeSpecializations:BuildNodeData(recipeID)
    local mapping = addon.SpecializationData and addon.SpecializationData.recipes[recipeID]
    if not mapping then
        return {}
    end

    local skillLineID = self:GetCurrentSkillLineID(recipeID)
    local configID = skillLineID and C_ProfSpecs.GetConfigIDForSkillLine(skillLineID)
    if not configID or configID == 0 then
        return {}
    end

    local result = {}
    for _, nodeID in ipairs(mapping) do
        local definition = addon.SpecializationData.nodes[nodeID]
        local nodeInfo = definition and C_Traits.GetNodeInfo(configID, nodeID)
        if definition and nodeInfo then
            local name, icon = GetNodeVisuals(configID, nodeID, nodeInfo)
            local currentRank, maxRank, currentSkill, maxSkill, perks = GetNodeProgress(nodeID, definition, nodeInfo)
            result[#result + 1] = {
                nodeID = nodeID,
                name = name,
                icon = icon,
                currentRank = currentRank,
                maxRank = maxRank,
                currentSkill = currentSkill,
                maxSkill = maxSkill,
                perks = perks,
            }
        end
    end

    table.sort(result, function(left, right)
        local leftRemaining = left.maxSkill - left.currentSkill
        local rightRemaining = right.maxSkill - right.currentSkill
        if leftRemaining ~= rightRemaining then
            return leftRemaining > rightRemaining
        end
        return left.name < right.name
    end)
    return result
end

function RecipeSpecializations:Update(recipeID)
    self.currentRecipeID = recipeID
    if not addon.db.recipeSpecializations or not recipeID then
        self.frame:Hide()
        return
    end

    local mapping = addon.SpecializationData and addon.SpecializationData.recipes[recipeID]
    if not mapping then
        self.frame:Hide()
        return
    end

    local nodes = self:BuildNodeData(recipeID)
    local totalCurrent, totalMax = 0, 0
    for index, data in ipairs(nodes) do
        local row = self:GetRow(index)
        row.data = data
        row.icon:SetTexture(data.icon)
        row.name:SetText(data.name)
        row.qualityBadge:SetShown(data.maxSkill > 0)
        row.rank:SetText(string.format("%d/%d", data.currentRank, data.maxRank))
        row.skill:SetText(data.maxSkill > 0 and string.format("+%d/%d", data.currentSkill, data.maxSkill) or "")
        row.bar:SetMinMaxValues(0, math.max(1, data.maxRank))
        row.bar:SetValue(data.currentRank)
        if data.currentRank >= data.maxRank and data.maxRank > 0 then
            row.bar:SetStatusBarColor(0.25, 0.85, 0.35)
        elseif data.currentRank > 0 then
            row.bar:SetStatusBarColor(0.2, 0.55, 0.95)
        else
            row.bar:SetStatusBarColor(0.35, 0.35, 0.38)
        end
        row:Show()
        totalCurrent = totalCurrent + data.currentSkill
        totalMax = totalMax + data.maxSkill
    end

    for index = #nodes + 1, #self.frame.rows do
        self.frame.rows[index].data = nil
        self.frame.rows[index]:Hide()
    end

    self.frame.emptyText:SetShown(#nodes == 0)
    self.frame.total:SetText(string.format("%s: |cff59bfff+%d|r / +%d", addon.L.SKILL_FROM_SPECS, totalCurrent, totalMax))
    self.frame.scrollChild:SetHeight(math.max(1, #nodes * (ROW_HEIGHT + ROW_GAP) - ROW_GAP))
    self.frame:Show()
end

function RecipeSpecializations:UpdateFromVisibleForm()
    if not ProfessionsFrame or not ProfessionsFrame:IsShown() then
        self.frame:Hide()
        return
    end

    local craftingForm = ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
    local orderDetails = ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.OrderView and ProfessionsFrame.OrdersPage.OrderView.OrderDetails
    local orderForm = orderDetails and orderDetails.SchematicForm
    local form
    if craftingForm and craftingForm:IsVisible() then
        form = craftingForm
    elseif orderForm and orderForm:IsVisible() then
        form = orderForm
    end

    local recipeInfo = form and form.GetRecipeInfo and form:GetRecipeInfo()
    self:Update(recipeInfo and recipeInfo.recipeID)
end

function RecipeSpecializations:HookForm(form)
    if not form then
        return
    end
    hooksecurefunc(form, "Init", function(_, recipeInfo)
        if recipeInfo and form:IsVisible() then
            self:Update(recipeInfo.recipeID)
        end
    end)
    form:HookScript("OnHide", function()
        C_Timer.After(0, function() self:UpdateFromVisibleForm() end)
    end)
end

function RecipeSpecializations:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    self:CreatePanel()

    self:HookForm(ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm)
    local orderDetails = ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.OrderView and ProfessionsFrame.OrdersPage.OrderView.OrderDetails
    self:HookForm(orderDetails and orderDetails.SchematicForm)

    ProfessionsFrame:HookScript("OnHide", function() self.frame:Hide() end)
    EventRegistry:RegisterCallback("ProfessionsRecipeListMixin.Event.OnRecipeSelected", function(_, recipeInfo)
        if recipeInfo then
            self:Update(recipeInfo.recipeID)
        end
    end, self)
    self:UpdateFromVisibleForm()
end

function RecipeSpecializations:OnEvent(event, arg1)
    if not self.initialized then
        return
    end
    if event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_NODE_CHANGED" then
        if self.currentRecipeID and self.frame:IsShown() then
            self:Update(self.currentRecipeID)
        end
    elseif event == "OPEN_RECIPE_RESPONSE" then
        self:Update(arg1)
    end
end
