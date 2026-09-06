local _, addon = ...

local RecipeSpecializations = {}
addon.RecipeSpecializations = RecipeSpecializations

local PANEL_WIDTH = 314
local PANEL_HEIGHT = 430
local PANEL_MIN_HEIGHT = 170
local CONTENT_WIDTH = PANEL_WIDTH - 52
local ROW_HEIGHT = 48
local ROW_GAP = 5
local DOCK_GAP = 8

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

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

local function DockButtonOnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.owner:IsDocked() and addon.L.UNDOCK_PANEL or addon.L.DOCK_PANEL, 1, 0.82, 0)
    if not self.owner:IsDocked() then
        GameTooltip:AddLine(addon.L.DOCK_PANEL_HINT, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function CreateDockButton(parent, owner)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(20, 20)
    button:SetPoint("TOPRIGHT", -12, -11)
    button.owner = owner
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.04, 0.05, 0.07, 0.72)
    button:SetBackdropBorderColor(0.32, 0.35, 0.4, 0.8)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints()
    button.highlight:SetColorTexture(1, 0.82, 0, 0.16)

    button.leftLink = button:CreateTexture(nil, "ARTWORK")
    button.leftLink:SetSize(3, 10)
    button.leftLink:SetPoint("CENTER", -5, 0)
    button.leftLink:SetColorTexture(0.95, 0.78, 0.2, 1)

    button.rightLink = button:CreateTexture(nil, "ARTWORK")
    button.rightLink:SetSize(3, 10)
    button.rightLink:SetPoint("CENTER", 5, 0)
    button.rightLink:SetColorTexture(0.95, 0.78, 0.2, 1)

    button.connector = button:CreateTexture(nil, "ARTWORK")
    button.connector:SetSize(10, 3)
    button.connector:SetPoint("CENTER")
    button.connector:SetColorTexture(0.95, 0.78, 0.2, 1)

    button:SetScript("OnEnter", DockButtonOnEnter)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function()
        owner:SetDocked(not owner:IsDocked())
        DockButtonOnEnter(button)
    end)
    return button
end

function RecipeSpecializations:CreatePanel()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "BetterProfessionsSpecializationFrame", UIParent, "BackdropTemplate")
    -- SavedVariables own the layout; WoW's per-character position cache must not override it.
    frame:SetDontSavePosition(true)
    local layout = type(addon.db.recipeSpecializationsLayout) == "table" and addon.db.recipeSpecializationsLayout or nil
    local savedHeight = layout and tonumber(layout.height)
    local hasSavedPosition = layout and tonumber(layout.x) and tonumber(layout.y)
    if layout and layout.docked == nil and hasSavedPosition then
        -- Positions saved by older versions were always free-floating.
        layout.docked = false
    end
    self.docked = not layout or layout.docked ~= false
    self.dockEdge = layout and layout.dockEdge == "BOTTOM" and "BOTTOM" or "TOP"
    frame:SetSize(PANEL_WIDTH, Clamp(savedHeight or PANEL_HEIGHT, PANEL_MIN_HEIGHT, PANEL_HEIGHT))
    if self.docked then
        local point = self.dockEdge == "BOTTOM" and "BOTTOMLEFT" or "TOPLEFT"
        local relativePoint = self.dockEdge == "BOTTOM" and "BOTTOMRIGHT" or "TOPRIGHT"
        frame:SetPoint(point, ProfessionsFrame, relativePoint, DOCK_GAP, 0)
    elseif hasSavedPosition then
        local maxX = math.max(0, (UIParent:GetWidth() - PANEL_WIDTH) / 2)
        local maxY = math.max(0, (UIParent:GetHeight() - frame:GetHeight()) / 2)
        frame:SetPoint("CENTER", UIParent, "CENTER", Clamp(tonumber(layout.x), -maxX, maxX), Clamp(tonumber(layout.y), -maxY, maxY))
    else
        frame:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", DOCK_GAP, 0)
    end
    frame:SetClampedToScreen(not self.docked)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(PANEL_WIDTH, PANEL_MIN_HEIGHT, PANEL_WIDTH, PANEL_HEIGHT)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if not self:IsDocked() then
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SaveLayout()
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 256,
        edgeSize = 24,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    frame:SetBackdropColor(0.06, 0.07, 0.09, 1)

    frame.logo = frame:CreateTexture(nil, "ARTWORK")
    frame.logo:SetSize(30, 30)
    frame.logo:SetPoint("TOPLEFT", 13, -9)
    frame.logo:SetTexture("Interface\\AddOns\\BetterProfessions\\Media\\Icon.tga")

    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.title:SetPoint("LEFT", frame.logo, "RIGHT", 3, 0)
    frame.title:SetText(addon.L.QUALITY_TITLE)

    frame.dockButton = CreateDockButton(frame, self)
    frame.title:SetPoint("RIGHT", frame.dockButton, "LEFT", -5, 0)

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

    frame.resizeButton = CreateFrame("Button", nil, frame)
    frame.resizeButton:SetSize(16, 16)
    frame.resizeButton:SetPoint("BOTTOMRIGHT", -7, 7)
    frame.resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    frame.resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    frame.resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    frame.resizeButton:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    frame.resizeButton:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            frame:StopMovingOrSizing()
            self:SaveLayout()
        end
    end)

    frame:Hide()
    self.frame = frame
    frame:SetScript("OnShow", function()
        if self:IsDocked() then
            self:ApplyDocking()
        end
        self:SyncFrameLayer()
        self:UpdateDockButton()
    end)
    self:SyncFrameLayer()
    self:UpdateDockButton()
end

function RecipeSpecializations:SyncFrameLayer()
    if not self.frame or not ProfessionsFrame then
        return
    end

    -- Keep the entire panel above HUD frames, whose children can have high levels
    -- within MEDIUM strata. Preserve higher profession-window strata from UI addons.
    local strata = ProfessionsFrame:GetFrameStrata()
    if strata == "BACKGROUND" or strata == "LOW" or strata == "MEDIUM" then
        strata = "HIGH"
    end
    self.frame:SetFrameStrata(strata)
    self.frame:SetFrameLevel(ProfessionsFrame:GetFrameLevel() + 1)
end

function RecipeSpecializations:IsDocked()
    return self.docked == true
end

function RecipeSpecializations:UpdateDockButton()
    if not self.frame or not self.frame.dockButton then
        return
    end

    self.frame.dockButton.connector:SetShown(self:IsDocked())
    local offset = self:IsDocked() and 5 or 6
    self.frame.dockButton.leftLink:ClearAllPoints()
    self.frame.dockButton.leftLink:SetPoint("CENTER", -offset, 0)
    self.frame.dockButton.rightLink:ClearAllPoints()
    self.frame.dockButton.rightLink:SetPoint("CENTER", offset, 0)
end

function RecipeSpecializations:GetNearestDockEdge()
    local frameTop, frameBottom = self.frame:GetTop(), self.frame:GetBottom()
    local professionTop, professionBottom = ProfessionsFrame:GetTop(), ProfessionsFrame:GetBottom()
    if frameTop and frameBottom and professionTop and professionBottom then
        if math.abs(frameBottom - professionBottom) < math.abs(frameTop - professionTop) then
            return "BOTTOM"
        end
    end
    return "TOP"
end

function RecipeSpecializations:ApplyDocking()
    if not self.frame or not ProfessionsFrame then
        return
    end

    self.frame:ClearAllPoints()
    if self:IsDocked() then
        local point = self.dockEdge == "BOTTOM" and "BOTTOMLEFT" or "TOPLEFT"
        local relativePoint = self.dockEdge == "BOTTOM" and "BOTTOMRIGHT" or "TOPRIGHT"
        self.frame:SetClampedToScreen(false)
        self.frame:SetPoint(point, ProfessionsFrame, relativePoint, DOCK_GAP, 0)
    else
        local layout = addon.db and addon.db.recipeSpecializationsLayout
        local x = layout and tonumber(layout.x) or 0
        local y = layout and tonumber(layout.y) or 0
        self.frame:SetClampedToScreen(true)
        self.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
end

function RecipeSpecializations:SetDocked(docked)
    if not self.frame then
        return
    end
    if self:IsDocked() == docked then
        self:ApplyDocking()
        self:UpdateDockButton()
        return
    end

    local layout = type(addon.db.recipeSpecializationsLayout) == "table" and addon.db.recipeSpecializationsLayout or {}
    addon.db.recipeSpecializationsLayout = layout
    local frameX, frameY = self.frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if frameX and frameY and parentX and parentY then
        layout.x = frameX - parentX
        layout.y = frameY - parentY
    end

    if docked then
        self.dockEdge = self:GetNearestDockEdge()
    end
    self.docked = docked
    layout.docked = docked
    layout.dockEdge = self.dockEdge
    self:ApplyDocking()
    self:UpdateDockButton()
end

function RecipeSpecializations:SaveLayout()
    if not addon.db or not self.frame then
        return
    end

    local layout = type(addon.db.recipeSpecializationsLayout) == "table" and addon.db.recipeSpecializationsLayout or {}
    addon.db.recipeSpecializationsLayout = layout
    layout.height = self.frame:GetHeight()
    layout.docked = self:IsDocked()
    layout.dockEdge = self.dockEdge

    if self:IsDocked() then
        self:ApplyDocking()
        return
    end

    local frameX, frameY = self.frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not frameX or not frameY or not parentX or not parentY then
        return
    end
    layout.x = frameX - parentX
    layout.y = frameY - parentY

    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", layout.x, layout.y)
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
    self:SyncFrameLayer()
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
    ProfessionsFrame:HookScript("OnShow", function()
        C_Timer.After(0, function() self:UpdateFromVisibleForm() end)
    end)
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
