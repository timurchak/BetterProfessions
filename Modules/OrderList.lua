local _, addon = ...

local OrderList = {}
addon.OrderList = OrderList

local ICON_SIZE = 20
local MAX_ICONS = 4
local MAX_REWARD_ICONS = 2
local widgetsByRow = setmetatable({}, { __mode = "k" })

local function TextureMarkup(texture, size)
    if not texture then
        return ""
    end
    size = size or 16
    return string.format("|T%s:%d:%d:0:0|t", tostring(texture), size, size)
end

local function GetItemDisplay(itemID)
    local itemName, itemLink, _, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemID)
    if not itemTexture then
        local _, _, _, _, instantTexture = C_Item.GetItemInfoInstant(itemID)
        itemTexture = instantTexture
    end
    if not itemLink then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return itemName or ("Item " .. itemID), itemLink, itemTexture or 134400
end

local function AddEntryToTooltip(entry)
    if entry.kind == "money" then
        GameTooltip:AddDoubleLine(addon.L.COMMISSION, C_CurrencyInfo.GetCoinTextureString(entry.amount or 0), 1, 1, 1, 1, 1, 1)
    elseif entry.kind == "concentration" then
        GameTooltip:AddDoubleLine(addon.L.CONCENTRATION, tostring(entry.amount), 1, 1, 1, 0.35, 0.75, 1)
    elseif entry.kind == "item" then
        local owned = C_Item.GetItemCount(entry.itemID, true, false, true, true)
        GameTooltip:AddDoubleLine(
            TextureMarkup(entry.texture) .. " " .. (entry.link or entry.name),
            string.format("%s: %d   %s: %d", addon.L.REQUIRED, entry.count or 0, addon.L.OWNED, owned or 0),
            1, 1, 1,
            owned >= (entry.count or 0) and 0.25 or 1,
            owned >= (entry.count or 0) and 1 or 0.25,
            0.25
        )
    elseif entry.kind == "rewardItem" then
        GameTooltip:AddDoubleLine(TextureMarkup(entry.texture) .. " " .. (entry.link or entry.name), "×" .. tostring(entry.count or 1), 1, 1, 1, 1, 0.82, 0)
    elseif entry.kind == "currency" then
        GameTooltip:AddDoubleLine(TextureMarkup(entry.texture) .. " " .. (entry.link or entry.name), "×" .. tostring(entry.count or 1), 1, 1, 1, 1, 0.82, 0)
    end
end

local function IconOnEnter(self)
    local entry = self.entry
    if not entry then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    if entry.kind == "item" or entry.kind == "rewardItem" then
        if entry.link then
            GameTooltip:SetHyperlink(entry.link)
        else
            GameTooltip:SetText(entry.name)
        end
        if entry.kind == "item" then
            local owned = C_Item.GetItemCount(entry.itemID, true, false, true, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(addon.L.REQUIRED, tostring(entry.count or 0), 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine(addon.L.OWNED, tostring(owned or 0), 1, 1, 1, owned >= (entry.count or 0) and 0.25 or 1, owned >= (entry.count or 0) and 1 or 0.25, 0.25)
            GameTooltip:AddLine(addon.L.LOWEST_QUALITY_NOTE, 0.7, 0.7, 0.7, true)
        elseif (entry.count or 1) > 1 then
            GameTooltip:AddLine("×" .. tostring(entry.count), 1, 0.82, 0)
        end
    elseif entry.kind == "currency" and entry.link then
        GameTooltip:SetHyperlink(entry.link)
        GameTooltip:AddLine("×" .. tostring(entry.count or 1), 1, 0.82, 0)
    elseif entry.kind == "extra" then
        GameTooltip:SetText(entry.title)
        for _, extraEntry in ipairs(entry.entries) do
            AddEntryToTooltip(extraEntry)
        end
    else
        GameTooltip:SetText(entry.label)
        if entry.amount then
            GameTooltip:AddLine(entry.kind == "money" and C_CurrencyInfo.GetCoinTextureString(entry.amount) or tostring(entry.amount), 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function IconOnLeave()
    GameTooltip:Hide()
end

local function CreateIcon(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(ICON_SIZE, ICON_SIZE)
    button:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button:SetBackdropBorderColor(0.45, 0.48, 0.55, 0.95)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    button.count = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmallOutline")
    button.count:SetPoint("BOTTOMRIGHT", 1, 0)

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", IconOnEnter)
    button:SetScript("OnLeave", IconOnLeave)
    return button
end

local function CreateSummary(parent, showMoney)
    local summary = CreateFrame("Frame", nil, parent)
    summary:SetAllPoints()
    summary.icons = {}
    summary.showMoney = showMoney

    summary.text = summary:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    summary.text:SetPoint("CENTER")
    summary.text:SetJustifyH("CENTER")

    if showMoney then
        summary.money = summary:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        summary.money:SetPoint("LEFT", 1, 0)
        summary.money:SetPoint("RIGHT", -1, 0)
        summary.money:SetJustifyH("RIGHT")
    end

    for index = 1, MAX_ICONS do
        local icon = CreateIcon(summary)
        if index == 1 then
            icon:SetPoint("LEFT", 2, 0)
        else
            icon:SetPoint("LEFT", summary.icons[index - 1], "RIGHT", 2, 0)
        end
        summary.icons[index] = icon
    end
    return summary
end

local function HideSummary(summary)
    summary:Hide()
    summary.text:SetText("")
    if summary.money then
        summary.money:SetText("")
    end
    for _, icon in ipairs(summary.icons) do
        icon.entry = nil
        icon:Hide()
    end
end

local function DisplayRewards(summary, entries)
    summary:Show()
    summary.text:SetText("")
    for _, icon in ipairs(summary.icons) do
        icon.entry = nil
        icon:Hide()
    end

    local commission = entries[1]
    summary.money:SetText(C_CurrencyInfo.GetCoinTextureString(commission and commission.amount or 0, 11))
    local rewardEntries = {}
    for index = 2, #entries do
        rewardEntries[#rewardEntries + 1] = entries[index]
    end

    if #rewardEntries == 0 then
        summary.money:ClearAllPoints()
        summary.money:SetPoint("LEFT", 1, 0)
        summary.money:SetPoint("RIGHT", -1, 0)
        return
    end

    local visibleCount = math.min(#rewardEntries, MAX_REWARD_ICONS)
    if #rewardEntries > MAX_REWARD_ICONS then
        visibleCount = MAX_REWARD_ICONS - 1
    end
    for index = 1, visibleCount do
        local entry = rewardEntries[index]
        local icon = summary.icons[index]
        icon.entry = entry
        icon.icon:SetTexture(entry.texture)
        icon.icon:SetDesaturated(false)
        icon.count:SetText((entry.count or 0) > 1 and tostring(entry.count) or "")
        icon:Show()
    end
    local lastIcon = summary.icons[visibleCount]
    if #rewardEntries > MAX_REWARD_ICONS then
        local extras = {}
        for index = MAX_REWARD_ICONS, #rewardEntries do
            extras[#extras + 1] = rewardEntries[index]
        end
        local icon = summary.icons[MAX_REWARD_ICONS]
        icon.entry = { kind = "extra", title = addon.L.REWARDS, entries = extras }
        icon.icon:SetTexture(134400)
        icon.icon:SetDesaturated(true)
        icon.count:SetText("+" .. tostring(#extras))
        icon:Show()
        lastIcon = icon
    end

    summary.money:ClearAllPoints()
    summary.money:SetPoint("LEFT", lastIcon, "RIGHT", 3, 0)
    summary.money:SetPoint("RIGHT", -1, 0)
end

local function DisplayEntries(summary, entries, emptyText, extraTitle)
    summary:Show()
    summary.text:SetText("")
    for _, icon in ipairs(summary.icons) do
        icon.entry = nil
        icon:Hide()
    end

    if #entries == 0 then
        summary.text:SetText(emptyText or "")
        return
    end

    local visibleCount = math.min(#entries, MAX_ICONS)
    if #entries > MAX_ICONS then
        visibleCount = MAX_ICONS - 1
    end

    for index = 1, visibleCount do
        local entry = entries[index]
        local icon = summary.icons[index]
        icon.entry = entry
        icon.icon:SetTexture(entry.texture)
        icon.icon:SetDesaturated(false)
        icon.count:SetText((entry.count or 0) > 1 and tostring(entry.count) or "")
        icon:Show()
    end

    if #entries > MAX_ICONS then
        local icon = summary.icons[MAX_ICONS]
        local extras = {}
        for index = MAX_ICONS, #entries do
            extras[#extras + 1] = entries[index]
        end
        icon.entry = {
            kind = "extra",
            title = extraTitle,
            entries = extras,
        }
        icon.icon:SetTexture(134400)
        icon.icon:SetDesaturated(true)
        icon.count:SetText("+" .. tostring(#extras))
        icon:Show()
    end
end

local function GetProvidedReagents(order)
    local provided = {}
    for _, entry in ipairs(order.reagents or {}) do
        local reagentInfo = entry.reagentInfo
        local reagent = reagentInfo and reagentInfo.reagent
        local itemID = reagent and reagent.itemID
        if itemID then
            provided[itemID] = (provided[itemID] or 0) + (reagentInfo.quantity or 0)
        end
    end
    return provided
end

local function GetMissingReagents(order)
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, order.spellID, order.isRecraft or false)
    if not ok or not schematic then
        return {}, {}
    end

    local provided = GetProvidedReagents(order)
    local missing = {}
    local operationReagents = {}

    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        local providedCount = 0
        local providedItemID
        for _, reagent in ipairs(slot.reagents or {}) do
            local count = provided[reagent.itemID] or 0
            if count > 0 then
                providedCount = providedCount + count
                providedItemID = providedItemID or reagent.itemID
            end
        end

        local firstReagent = slot.reagents and slot.reagents[1]
        local selectedItemID = providedItemID or (firstReagent and firstReagent.itemID)
        local requiredCount = slot.quantityRequired or 0

        if slot.required and selectedItemID and providedCount < requiredCount then
            local itemName, itemLink, itemTexture = GetItemDisplay(selectedItemID)
            missing[#missing + 1] = {
                kind = "item",
                itemID = selectedItemID,
                name = itemName,
                link = itemLink,
                texture = itemTexture,
                count = requiredCount - providedCount,
            }
        end

        if selectedItemID and slot.dataSlotType == Enum.TradeskillSlotDataType.ModifiedReagent then
            operationReagents[#operationReagents + 1] = {
                reagent = { itemID = selectedItemID },
                dataSlotIndex = slot.dataSlotIndex,
                quantity = requiredCount,
            }
        end
    end

    return missing, operationReagents
end

local function GetRewards(order)
    local rewards = {}
    local commission = math.max(0, (order.tipAmount or 0) - (order.consortiumCut or 0))
    rewards[#rewards + 1] = {
        kind = "money",
        label = addon.L.COMMISSION,
        amount = commission,
        texture = C_CurrencyInfo.GetCoinIcon(commission),
    }

    for _, reward in ipairs(order.npcOrderRewards or {}) do
        if reward.itemLink then
            local itemID = C_Item.GetItemInfoInstant(reward.itemLink)
            if itemID then
                local itemName, itemLink, itemTexture = GetItemDisplay(itemID)
                rewards[#rewards + 1] = {
                    kind = "rewardItem",
                    itemID = itemID,
                    name = itemName,
                    link = itemLink or reward.itemLink,
                    texture = itemTexture,
                    count = reward.count or 1,
                }
            end
        elseif reward.currencyType then
            local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(reward.currencyType)
            rewards[#rewards + 1] = {
                kind = "currency",
                name = currencyInfo and currencyInfo.name or ("Currency " .. reward.currencyType),
                link = C_CurrencyInfo.GetCurrencyLink(reward.currencyType, reward.count),
                texture = currencyInfo and currencyInfo.iconFileID or 134400,
                count = reward.count or 1,
            }
        end
    end
    return rewards
end

local function GetConcentration(order, operationReagents)
    if not order.minQuality or order.minQuality <= 0 or not C_TradeSkillUI.GetCraftingOperationInfoForOrder then
        return nil
    end

    local ok, operationInfo = pcall(
        C_TradeSkillUI.GetCraftingOperationInfoForOrder,
        order.spellID,
        operationReagents,
        order.orderID,
        false
    )
    if ok and operationInfo and operationInfo.craftingQuality and operationInfo.craftingQuality < order.minQuality and (operationInfo.concentrationCost or 0) > 0 then
        return operationInfo.concentrationCost
    end
    return nil
end

local function HideNativeWidgets(row)
    local cells = row.cells
    if not cells then
        return
    end

    local rewardCell = cells[3]
    local reagentCell = cells[4]
    if rewardCell then
        if rewardCell.RewardIcon then rewardCell.RewardIcon:Hide() end
        if rewardCell.RewardsContainer then rewardCell.RewardsContainer:Hide() end
        if rewardCell.TipMoneyDisplayFrame then rewardCell.TipMoneyDisplayFrame:Hide() end
        if rewardCell.Text then rewardCell.Text:Hide() end
    end
    if reagentCell and reagentCell.Text then
        reagentCell.Text:Hide()
    end
end

local function GetWidgets(row)
    local widgets = widgetsByRow[row]
    if widgets then
        return widgets
    end

    widgets = {
        rewards = CreateSummary(row.cells[3], true),
        reagents = CreateSummary(row.cells[4], false),
        generation = 0,
    }
    widgetsByRow[row] = widgets
    return widgets
end

function OrderList:UpdateRow(row, elementData)
    if not addon.db.orderPreviews or not row or not row.cells then
        return
    end

    local order = elementData and elementData.option
    if not order or not order.orderID or not order.spellID then
        local widgets = widgetsByRow[row]
        if widgets then
            HideSummary(widgets.rewards)
            HideSummary(widgets.reagents)
            widgets.order = nil
        end
        return
    end

    local widgets = GetWidgets(row)
    widgets.generation = widgets.generation + 1
    local generation = widgets.generation
    widgets.order = order
    widgets.orderID = order.orderID

    C_Timer.After(0, function()
        if widgets.generation ~= generation or widgets.orderID ~= order.orderID or not row:IsVisible() then
            return
        end

        HideNativeWidgets(row)
        local missingReagents, operationReagents = GetMissingReagents(order)
        local concentration = GetConcentration(order, operationReagents)
        if concentration then
            missingReagents[#missingReagents + 1] = {
                kind = "concentration",
                label = addon.L.CONCENTRATION,
                amount = concentration,
                texture = 5747318,
            }
        end

        DisplayRewards(widgets.rewards, GetRewards(order))
        DisplayEntries(widgets.reagents, missingReagents, addon.L.ALL_PROVIDED, addon.L.YOU_PROVIDE)
    end)
end

function OrderList:TryRegisterRows()
    if self.rowsRegistered or not addon.db.orderPreviews or not ProfessionsFrame then
        return
    end

    local browseFrame = ProfessionsFrame.OrdersPage and ProfessionsFrame.OrdersPage.BrowseFrame
    local orderList = browseFrame and browseFrame.OrderList
    local scrollBox = orderList and orderList.ScrollBox
    if not scrollBox then
        return
    end

    self.rowsRegistered = true
    self.scrollBox = scrollBox
    ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, row, elementData)
        self:UpdateRow(row, elementData)
    end, nil, true)
end

function OrderList:RefreshRows()
    for row, widgets in pairs(widgetsByRow) do
        if widgets.order and row:IsVisible() then
            self:UpdateRow(row, { option = widgets.order })
        end
    end
end

function OrderList:Initialize()
    self:TryRegisterRows()
end

function OrderList:OnEvent(event)
    if event == "CRAFTINGORDERS_CAN_REQUEST" or event == "CRAFTINGORDERS_UPDATE_ORDER_COUNT" then
        self:TryRegisterRows()
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "BAG_UPDATE_DELAYED" or event == "CRAFTINGORDERS_UPDATE_REWARDS" then
        self:RefreshRows()
    end
end
