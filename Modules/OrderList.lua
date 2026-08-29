local _, addon = ...

local OrderList = {}
addon.OrderList = OrderList

local ICON_SIZE = 20
local MAX_ICONS = 4
local MAX_REWARD_ICONS = 2
local widgetsByRow = setmetatable({}, { __mode = "k" })
local DEFAULT_ICON_BORDER = { 0.45, 0.48, 0.55, 0.95 }

local function GetOwnedReagentCount(entry)
    local owned = 0
    local seen = {}
    local itemIDs = entry.alternatives or { entry.itemID }
    for _, itemID in ipairs(itemIDs) do
        if itemID and not seen[itemID] then
            seen[itemID] = true
            owned = owned + (C_Item.GetItemCount(itemID, true, false, true, true) or 0)
        end
    end
    return owned
end

local function EntryNeedsPurchase(entry)
    return entry.kind == "item" and GetOwnedReagentCount(entry) < (entry.count or 0)
end

local function TextureMarkup(texture, size)
    if not texture then
        return ""
    end
    size = size or 16
    return string.format("|T%s:%d:%d:0:0|t", tostring(texture), size, size)
end

local function GetItemDisplay(itemID)
    local itemName, itemLink, _, _, _, _, _, _, _, itemTexture, _, _, _, bindType = C_Item.GetItemInfo(itemID)
    if not itemTexture then
        local _, _, _, _, instantTexture = C_Item.GetItemInfoInstant(itemID)
        itemTexture = instantTexture
    end
    if not itemLink then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return itemName or ("Item " .. itemID), itemLink, itemTexture or 134400, bindType
end

local function GetAuctionValue(itemID)
    if not itemID then
        return nil
    end

    if C_AddOns.IsAddOnLoaded("Auctionator") and Auctionator and Auctionator.API and Auctionator.API.v1 then
        local api = Auctionator.API.v1
        if api.GetAuctionPriceByItemID then
            local ok, price = pcall(api.GetAuctionPriceByItemID, addon.name, itemID)
            if ok and price and price > 0 then
                return price, "Auctionator"
            end
        end
    end

    if C_AddOns.IsAddOnLoaded("TradeSkillMaster") and TSM_API and TSM_API.GetCustomPriceValue then
        local ok, price = pcall(TSM_API.GetCustomPriceValue, "dbmarket", "i:" .. itemID)
        if ok and price and price > 0 then
            return price, "TradeSkillMaster"
        end
        ok, price = pcall(TSM_API.GetCustomPriceValue, "dbregionmarketavg", "i:" .. itemID)
        if ok and price and price > 0 then
            return price, "TradeSkillMaster"
        end
    end

    if C_AddOns.IsAddOnLoaded("OribosExchange") and OEMarketInfo then
        local marketInfo = {}
        local ok = pcall(OEMarketInfo, itemID, marketInfo)
        if ok then
            local price = marketInfo.market or marketInfo.region
            if price and price > 0 then
                return price, "Oribos Exchange"
            end
        end
    end

    return nil
end

local function AddEntryToTooltip(entry)
    if entry.kind == "money" then
        GameTooltip:AddDoubleLine(addon.L.COMMISSION, C_CurrencyInfo.GetCoinTextureString(entry.amount or 0), 1, 1, 1, 1, 1, 1)
    elseif entry.kind == "concentration" then
        GameTooltip:AddDoubleLine(addon.L.CONCENTRATION, tostring(entry.amount), 1, 1, 1, 0.35, 0.75, 1)
    elseif entry.kind == "item" then
        local owned = GetOwnedReagentCount(entry)
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
            local owned = GetOwnedReagentCount(entry)
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

    button.missingGlow = button:CreateTexture(nil, "BACKGROUND")
    button.missingGlow:SetPoint("TOPLEFT", -3, 3)
    button.missingGlow:SetPoint("BOTTOMRIGHT", 3, -3)
    button.missingGlow:SetColorTexture(1, 0.02, 0.02, 0.9)
    button.missingGlow:Hide()

    button.missingOverlay = button:CreateTexture(nil, "OVERLAY")
    button.missingOverlay:SetAllPoints()
    button.missingOverlay:SetColorTexture(1, 0, 0, 0.38)
    button.missingOverlay:Hide()

    button.count = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmallOutline")
    button.count:SetPoint("BOTTOMRIGHT", 1, 0)

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", IconOnEnter)
    button:SetScript("OnLeave", IconOnLeave)
    return button
end

local function SetIconNeedsPurchase(icon, needsPurchase)
    icon.missingGlow:SetShown(needsPurchase)
    icon.missingOverlay:SetShown(needsPurchase)
    if needsPurchase then
        icon:SetBackdropBorderColor(1, 0.08, 0.08, 1)
        icon.icon:SetVertexColor(1, 0.55, 0.55)
    else
        icon:SetBackdropBorderColor(unpack(DEFAULT_ICON_BORDER))
        icon.icon:SetVertexColor(1, 1, 1)
    end
end

local RewardSummaryOnEnter

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
        summary:EnableMouse(true)
        summary:SetScript("OnEnter", RewardSummaryOnEnter)
        summary:SetScript("OnLeave", IconOnLeave)
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
    summary.profitInfo = nil
    summary.text:SetText("")
    if summary.money then
        summary.money:SetText("")
    end
    for _, icon in ipairs(summary.icons) do
        icon.entry = nil
        SetIconNeedsPurchase(icon, false)
        icon:Hide()
    end
end

local function HideRecipeState(widgets)
    if widgets and widgets.unlearned then
        widgets.unlearned:Hide()
    end
    if widgets and widgets.unlearnedText then
        widgets.unlearnedText:Hide()
    end
end

local function ShowUnlearnedRecipeState(widgets)
    HideSummary(widgets.rewards)
    HideSummary(widgets.reagents)
    widgets.unlearned:Show()
    widgets.unlearnedText:Show()
end

local function SignedMoney(amount)
    if amount < 0 then
        return "- " .. C_CurrencyInfo.GetCoinTextureString(-amount, 11)
    end
    return C_CurrencyInfo.GetCoinTextureString(amount, 11)
end

local function RoundToGold(amount)
    if amount >= 0 then
        return math.floor((amount + 5000) / 10000) * 10000
    end
    return math.ceil((amount - 5000) / 10000) * 10000
end

RewardSummaryOnEnter = function(self)
    local info = self.profitInfo
    if not info then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    if info.complete then
        local color = info.profit >= 0 and "|cff40c040" or "|cffff4040"
        GameTooltip:AddDoubleLine(addon.L.PROFIT, color .. SignedMoney(info.profit) .. "|r", 1, 0.82, 0, 1, 1, 1)
    else
        GameTooltip:AddLine(addon.L.MISSING_PRICES, 1, 0.65, 0, true)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(addon.L.COMMISSION, C_CurrencyInfo.GetCoinTextureString(info.commission), 1, 1, 1, 0.4, 1, 0.4)
    for _, reward in ipairs(info.rewardEntries) do
        GameTooltip:AddDoubleLine(
            TextureMarkup(reward.texture) .. " " .. (reward.link or reward.name) .. " ×" .. tostring(reward.count or 1),
            C_CurrencyInfo.GetCoinTextureString(reward.totalPrice),
            1, 1, 1, 0.4, 1, 0.4
        )
    end

    if #info.costEntries > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(addon.L.COSTS, 1, 0.82, 0)
        for _, reagent in ipairs(info.costEntries) do
            local amount = reagent.totalPrice or 0
            GameTooltip:AddDoubleLine(
                TextureMarkup(reagent.texture) .. " " .. (reagent.link or reagent.name) .. " ×" .. tostring(reagent.count or 0),
                "|cffff4040- " .. C_CurrencyInfo.GetCoinTextureString(amount) .. "|r",
                1, 1, 1, 1, 1, 1
            )
        end
    end

    if info.unpricedRewards then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(addon.L.UNPRICED_REWARDS, 0.7, 0.7, 0.7, true)
    end
    if info.sources ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(addon.L.PRICE_SOURCE, info.sources, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
    elseif not info.complete and not info.hasPriceSource then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(addon.L.NO_PRICE_SOURCE, 1, 0.65, 0, true)
    end
    GameTooltip:Show()
end

local function DisplayRewards(summary, entries, profitInfo)
    summary:Show()
    summary.profitInfo = profitInfo
    summary.text:SetText("")
    for _, icon in ipairs(summary.icons) do
        icon.entry = nil
        SetIconNeedsPurchase(icon, false)
        icon:Hide()
    end

    if profitInfo.complete then
        local color = profitInfo.profit >= 0 and "|cff40c040" or "|cffff4040"
        summary.money:SetText(color .. SignedMoney(RoundToGold(profitInfo.profit)) .. "|r")
    else
        summary.money:SetText("|cffffb000?|r")
    end
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
        SetIconNeedsPurchase(icon, false)
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
        SetIconNeedsPurchase(icon, false)
        icon.count:SetText("+" .. tostring(#extras))
        icon:Show()
        lastIcon = icon
    end

    summary.money:ClearAllPoints()
    summary.money:SetPoint("LEFT", lastIcon, "RIGHT", 3, 0)
    summary.money:SetPoint("RIGHT", -1, 0)
end

local function DisplayEntries(summary, entries, extraTitle)
    if #entries == 0 then
        HideSummary(summary)
        return
    end

    summary:Show()
    summary.text:SetText("")
    for _, icon in ipairs(summary.icons) do
        icon.entry = nil
        SetIconNeedsPurchase(icon, false)
        icon:Hide()
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
        SetIconNeedsPurchase(icon, EntryNeedsPurchase(entry))
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
        local extrasNeedPurchase = false
        for _, entry in ipairs(extras) do
            if EntryNeedsPurchase(entry) then
                extrasNeedPurchase = true
                break
            end
        end
        SetIconNeedsPurchase(icon, extrasNeedPurchase)
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

    for schematicIndex, slot in ipairs(schematic.reagentSlotSchematics or {}) do
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
            local itemName, itemLink, itemTexture, bindType = GetItemDisplay(selectedItemID)
            local alternatives = {}
            for _, reagent in ipairs(slot.reagents or {}) do
                if reagent.itemID then
                    alternatives[#alternatives + 1] = reagent.itemID
                end
            end
            missing[#missing + 1] = {
                kind = "item",
                itemID = selectedItemID,
                name = itemName,
                link = itemLink,
                texture = itemTexture,
                count = requiredCount - providedCount,
                bindType = bindType,
                alternatives = alternatives,
                sortIndex = slot.dataSlotIndex or schematicIndex,
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

    table.sort(missing, function(left, right)
        if left.sortIndex ~= right.sortIndex then
            return left.sortIndex < right.sortIndex
        end
        return left.itemID < right.itemID
    end)

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

local function HasAuctionPriceSource()
    return C_AddOns.IsAddOnLoaded("Auctionator")
        or C_AddOns.IsAddOnLoaded("TradeSkillMaster")
        or C_AddOns.IsAddOnLoaded("OribosExchange")
end

local function CalculateProfit(missingReagents, rewards)
    local commission = rewards[1] and rewards[1].amount or 0
    local income = commission
    local costs = 0
    local missingPrices = false
    local unpricedRewards = false
    local costEntries = {}
    local rewardEntries = {}
    local sources = {}

    for _, reagent in ipairs(missingReagents) do
        if reagent.kind == "item" then
            local cheapestPrice, cheapestItemID, cheapestSource
            for _, itemID in ipairs(reagent.alternatives or { reagent.itemID }) do
                local price, source = GetAuctionValue(itemID)
                if price and (not cheapestPrice or price < cheapestPrice) then
                    cheapestPrice = price
                    cheapestItemID = itemID
                    cheapestSource = source
                end
            end

            if cheapestPrice then
                local itemName, itemLink, itemTexture, bindType = GetItemDisplay(cheapestItemID)
                local costEntry = {
                    itemID = cheapestItemID,
                    name = itemName,
                    link = itemLink,
                    texture = itemTexture,
                    bindType = bindType,
                    count = reagent.count,
                    unitPrice = cheapestPrice,
                    priceSource = cheapestSource,
                    totalPrice = cheapestPrice * (reagent.count or 0),
                }
                costs = costs + costEntry.totalPrice
                sources[cheapestSource] = true
                costEntries[#costEntries + 1] = costEntry
            elseif reagent.bindType and reagent.bindType ~= 0 then
                reagent.totalPrice = 0
                costEntries[#costEntries + 1] = reagent
            else
                missingPrices = true
            end
        end
    end

    for index = 2, #rewards do
        local reward = rewards[index]
        if reward.kind == "rewardItem" then
            local price, source = GetAuctionValue(reward.itemID)
            if price then
                reward.unitPrice = price
                reward.totalPrice = price * (reward.count or 1)
                income = income + reward.totalPrice
                sources[source] = true
                rewardEntries[#rewardEntries + 1] = reward
            else
                unpricedRewards = true
            end
        end
    end

    local sourceNames = {}
    for source in pairs(sources) do
        sourceNames[#sourceNames + 1] = source
    end
    table.sort(sourceNames)

    return {
        complete = not missingPrices,
        hasPriceSource = HasAuctionPriceSource(),
        commission = commission,
        income = income,
        costs = costs,
        profit = income - costs,
        costEntries = costEntries,
        rewardEntries = rewardEntries,
        sources = table.concat(sourceNames, ", "),
        unpricedRewards = unpricedRewards,
    }
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

local function SnapshotOrder(order)
    local snapshot = {
        orderID = order.orderID,
        spellID = order.spellID,
        isRecraft = order.isRecraft,
        minQuality = order.minQuality,
        tipAmount = order.tipAmount,
        consortiumCut = order.consortiumCut,
        reagents = {},
        npcOrderRewards = {},
    }

    for _, entry in ipairs(order.reagents or {}) do
        local reagentInfo = entry.reagentInfo
        local reagent = reagentInfo and reagentInfo.reagent
        if reagent and reagent.itemID then
            snapshot.reagents[#snapshot.reagents + 1] = {
                reagentInfo = {
                    reagent = { itemID = reagent.itemID },
                    quantity = reagentInfo.quantity,
                },
            }
        end
    end

    for _, reward in ipairs(order.npcOrderRewards or {}) do
        snapshot.npcOrderRewards[#snapshot.npcOrderRewards + 1] = {
            itemLink = reward.itemLink,
            currencyType = reward.currencyType,
            count = reward.count,
        }
    end
    return snapshot
end

local function BuildOrderModel(order)
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

    local rewards = GetRewards(order)
    return {
        missingReagents = missingReagents,
        rewards = rewards,
        profitInfo = CalculateProfit(missingReagents, rewards),
    }
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
    local recipeCell = row.cells[1]
    local rewardCell = row.cells[3]
    local reagentCell = row.cells[4]
    if widgets
        and widgets.recipeCell == recipeCell
        and widgets.rewardCell == rewardCell
        and widgets.reagentCell == reagentCell then
        return widgets
    end

    if widgets then
        HideSummary(widgets.rewards)
        HideSummary(widgets.reagents)
        HideRecipeState(widgets)
    end

    local unlearned = recipeCell:CreateTexture(nil, "OVERLAY")
    unlearned:SetSize(18, 18)
    unlearned:SetPoint("RIGHT", -8, 0)
    unlearned:SetAtlas("common-icon-redx", false)
    unlearned:Hide()

    local unlearnedText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    unlearnedText:SetPoint("LEFT", rewardCell, "LEFT", 4, 0)
    unlearnedText:SetPoint("RIGHT", reagentCell, "RIGHT", -4, 0)
    unlearnedText:SetJustifyH("CENTER")
    unlearnedText:SetText(addon.L.RECIPE_NOT_LEARNED)
    unlearnedText:SetTextColor(1, 0.35, 0.35)
    unlearnedText:Hide()

    widgets = {
        rewards = CreateSummary(rewardCell, true),
        reagents = CreateSummary(reagentCell, false),
        unlearned = unlearned,
        unlearnedText = unlearnedText,
        recipeCell = recipeCell,
        rewardCell = rewardCell,
        reagentCell = reagentCell,
    }
    widgetsByRow[row] = widgets
    if not row.betterProfessionsHideHooked then
        row.betterProfessionsHideHooked = true
        row:HookScript("OnHide", function(hiddenRow)
            local currentWidgets = widgetsByRow[hiddenRow]
            if currentWidgets then
                HideSummary(currentWidgets.rewards)
                HideSummary(currentWidgets.reagents)
                HideRecipeState(currentWidgets)
                currentWidgets.orderID = nil
                currentWidgets.spellID = nil
            end
        end)
    end
    return widgets
end

function OrderList:UpdateRow(row)
    if not addon.db.orderPreviews or not row or not row.cells then
        return
    end

    -- Blizzard's row mixin renders and opens the order from row.option. Using
    -- that same field keeps our preview bound to the exact order visible in
    -- the row, including after a server-side sort replaces the data provider.
    local liveOrder = row.option
    if not liveOrder or not liveOrder.orderID or not liveOrder.spellID then
        local widgets = widgetsByRow[row]
        if widgets then
            HideSummary(widgets.rewards)
            HideSummary(widgets.reagents)
            HideRecipeState(widgets)
            widgets.orderID = nil
            widgets.spellID = nil
        end
        return
    end

    local widgets = GetWidgets(row)
    widgets.orderID = liveOrder.orderID
    widgets.spellID = liveOrder.spellID

    HideNativeWidgets(row)
    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(liveOrder.spellID)
    if recipeInfo and recipeInfo.learned == false then
        ShowUnlearnedRecipeState(widgets)
        return
    end

    HideRecipeState(widgets)
    local model = BuildOrderModel(SnapshotOrder(liveOrder))

    local currentOrder = row.option
    if currentOrder ~= liveOrder
        or currentOrder.orderID ~= widgets.orderID
        or currentOrder.spellID ~= widgets.spellID then
        HideSummary(widgets.rewards)
        HideSummary(widgets.reagents)
        HideRecipeState(widgets)
        self:ScheduleRefreshRows()
        return
    end

    DisplayRewards(widgets.rewards, model.rewards, model.profitInfo)
    DisplayEntries(widgets.reagents, model.missingReagents, addon.L.YOU_PROVIDE)
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
    ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, row)
        self:UpdateRow(row)
    end, nil, true)
end

function OrderList:RefreshRows()
    if not self.scrollBox then
        return
    end
    self.scrollBox:ForEachFrame(function(row)
        self:UpdateRow(row)
    end)
end

function OrderList:ScheduleRefreshRows()
    if self.refreshPending then
        return
    end

    self.refreshPending = true
    C_Timer.After(0, function()
        self.refreshPending = false
        self:RefreshRows()
    end)
end

function OrderList:Initialize()
    self:TryRegisterRows()
end

function OrderList:OnEvent(event)
    if event == "CRAFTINGORDERS_CAN_REQUEST" or event == "CRAFTINGORDERS_UPDATE_ORDER_COUNT" then
        self:TryRegisterRows()
    elseif event == "CRAFTINGORDERS_UPDATE_REWARDS" then
        self:ScheduleRefreshRows()
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "BAG_UPDATE_DELAYED" then
        self:ScheduleRefreshRows()
    end
end
