local _, A = ...
local Ops = {}
A.Operations = Ops

local function ordered(items)
    local list = {}
    for _, item in pairs(items) do list[#list + 1] = item end
    table.sort(list, function(a, b) return a.bag == b.bag and a.slot < b.slot or a.bag < b.bag end)
    return list
end

function Ops:Eligible(item, state)
    if not A.Store:Eligible(item, state) or A.API:IsQuest(item) or A.API:Refundable(item) then return false end
    if state == "junk" then return A.API:SellPrice(item) ~= nil end
    return state == "mail" and A.API:CanMail(item)
end

function Ops:PreviewJunk()
    if not A.API:MerchantReady() then A.Print("Open the merchant's Buy tab with an empty cursor, outside combat."); return end
    if self.job then return end
    A.Store:RefreshInventory()
    local items = A.API:Scan(false)
    local preview, skipped, total = {}, 0, 0
    for _, item in ipairs(ordered(items)) do
        if A.Store:Get(item.guid) == "junk" then
            if #preview < 12 and self:Eligible(item, "junk") then
                local price = A.API:SellPrice(item)
                preview[#preview + 1] = { guid = item.guid, count = item.count, itemID = item.itemID,
                    link = item.link, price = price }
                total = total + price * item.count
            else skipped = skipped + 1 end
        end
    end
    if #preview == 0 then A.Print("No eligible marked junk. Changed stacks, busy, unsellable, quest and refundable items are skipped."); return end
    local lines = { "Sell these marked stacks? (Up to 12 per batch.)", "" }
    for _, item in ipairs(preview) do
        lines[#lines + 1] = (item.link or ("Item " .. item.itemID)) .. " x" .. item.count
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Estimated total: " .. GetCoinTextureString(total)
    if skipped > 0 then lines[#lines + 1] = skipped .. " other marked stack(s) left in your bags." end
    -- Context generation prevents confirming a preview at a different merchant.
    local generation = self.generation or 0
    A.UI:Confirm("BagMarks: Sell Marked Junk", table.concat(lines, "\n"), "Sell " .. #preview .. " stack(s)", function()
        if generation ~= (self.generation or 0) or not A.API:MerchantReady() or self.job then return end
        self.job = { kind = "junk", entries = preview, index = 1, completed = 0 }
        self:Step()
    end)
end

function Ops:AttachMail()
    if not A.API:MailReady() then A.Print("Open Send Mail with an empty cursor, outside combat."); return end
    if self.job then return end
    if not A.API:FreeAttachment() then A.Print("All mail attachment slots are occupied."); return end
    A.Mail:FillRecipient()
    A.Store:RefreshInventory()
    local items = A.API:Scan(false)
    local entries = {}
    for _, item in ipairs(ordered(items)) do
        if self:Eligible(item, "mail") then
            entries[#entries + 1] = { guid = item.guid, count = item.count, itemID = item.itemID }
        end
    end
    if #entries == 0 then A.Print("No eligible Mail items. Bound, quest, refundable, busy and changed stacks are skipped."); return end
    self.job = { kind = "mail", entries = entries, index = 1, completed = 0 }
    self:Step()
end

function Ops:Cancel(message)
    local active = self.job ~= nil
    self.job = nil
    self.generation = (self.generation or 0) + 1
    A.UI:CloseConfirmation()
    self:RefreshButtons()
    if active and message then A.Print(message) end
end

function Ops:Finish()
    local job = self.job
    self.job = nil
    self:RefreshButtons()
    if job and job.kind == "mail" then
        A.Print(job.completed .. " stack(s) attached. Review the recipient and attachments, then use Blizzard's Send button.")
    elseif job then
        A.Print(job.completed .. " marked stack(s) sold.")
    end
end

function Ops:Step()
    local job = self.job
    if not job then return end
    local ready = job.kind == "junk" and A.API:MerchantReady() or job.kind == "mail" and A.API:MailReady()
    if not ready then self:Cancel("Operation stopped. Remaining markings were kept."); return end
    if job.kind == "mail" and not A.API:FreeAttachment() then self:Finish(); return end
    A.Store:RefreshInventory()
    local entry = job.entries[job.index]
    if not entry then self:Finish(); return end
    local item = A.API:Find(entry.guid, false)
    -- Revalidate identity, mark, size and eligibility immediately before every action.
    if not item or item.itemID ~= entry.itemID or item.count ~= entry.count or not self:Eligible(item, job.kind)
        or (job.kind == "junk" and A.API:SellPrice(item) ~= entry.price) then
        self:Cancel("An item changed or is unavailable. Review the remaining marked items and try again.")
        return
    end
    job.pending = entry
    job.started = GetTime()
    local ok
    if job.kind == "junk" then
        ok = pcall(C_Container.UseContainerItem, item.bag, item.slot)
    else
        local attachment = A.API:FreeAttachment()
        job.attachment = attachment
        ok = pcall(C_Container.PickupContainerItem, item.bag, item.slot)
        if ok and CursorHasItem() then
            ok = pcall(ClickSendMailItemButton, attachment)
            if CursorHasItem() then
                -- Only clear the cursor we just picked up, never a later player cursor.
                ClearCursor()
                ok = false
            end
        else ok = false end
    end
    if not ok then self:Cancel("The client refused the action. Remaining markings were kept."); return end
    self:RefreshButtons()
    self:SchedulePoll(job)
end

function Ops:SchedulePoll(job)
    C_Timer.After(.15, function()
        if self.job == job then self:Poll() end
    end)
end

function Ops:Poll()
    local job = self.job
    if not job or not job.pending then return end
    local ready = job.kind == "junk" and A.API:MerchantReady() or job.kind == "mail" and A.API:MailReady()
    if not ready then self:Cancel("Operation stopped. Remaining markings were kept."); return end
    local present = A.API:Find(job.pending.guid, false)
    local complete = not present
    if job.kind == "mail" then
        local name, itemID, _, count = GetSendMailItem(job.attachment)
        complete = complete and name ~= nil and itemID == job.pending.itemID and count == job.pending.count
    end
    if complete then
        -- Mail marks remain even after success: removing attachments or failed sends
        -- must not lose the mark. Stale GUID records cannot mark a different copy.
        job.completed = job.completed + 1
        job.pending = nil
        job.index = job.index + 1
        self:Step()
    elseif GetTime() - job.started > 2 then
        self:Cancel("The client did not confirm the action. Check the item, then try again.")
    else self:SchedulePoll(job) end
end

function Ops:RefreshButtons()
    if self.sellButton then
        self.sellButton:SetShown(A.IsEnabled() and A.merchantOpen == true)
        self.sellButton:SetEnabled(not self.job and A.API:MerchantReady() and true or false)
    end
    if self.mailButton then
        self.mailButton:SetShown(A.IsEnabled() and A.mailOpen == true)
        self.mailButton:SetEnabled(not self.job and A.API:MailReady() and true or false)
    end
    if self.nativeJunkGuard then
        local block = false
        if A.CanAct() and A.merchantOpen and MerchantSellAllJunkButton:IsVisible() then
            local carried = {}
            for _, id in ipairs(A.API:BagIDs(false)) do carried[id] = true end
            for guid, item in pairs(A.inventory or {}) do
                if carried[item.bag] and item.quality == 0 and A.Store:Get(guid) == "locked" then
                    block = true
                    break
                end
            end
        end
        self.nativeJunkGuard:SetShown(block)
    end
end

function Ops:CreateButtons()
    if A.InCombat() then return end
    if MerchantFrame and not self.sellButton then
        self.sellButton = A.UI.Button(MerchantFrame, "Sell Marked Junk", 150, 0, 0, function() self:PreviewJunk() end)
        self.sellButton:ClearAllPoints()
        self.sellButton:SetPoint("TOPLEFT", MerchantFrame, "BOTTOMLEFT", 14, -3)
        A.UI.Tip(self.sellButton, "Sell Marked Junk", "Preview up to 12 explicitly marked stacks. Locked, Mail and uncertain stacks are excluded.")
    end
    if SendMailFrame and not self.mailButton then
        self.mailButton = A.UI.Button(SendMailFrame, "Attach Marked Items", 160, 0, 0, function() self:AttachMail() end)
        self.mailButton:ClearAllPoints()
        self.mailButton:SetPoint("TOPLEFT", SendMailFrame, "BOTTOMLEFT", 14, -3)
        A.UI.Tip(self.mailButton, "Attach Marked Items", "Attach eligible Mail stacks to free slots. Review them and click Send yourself. Unsent marks are retained.")
    end
    if MerchantSellAllJunkButton and not self.nativeJunkGuard then
        local guard = CreateFrame("Button", nil, UIParent)
        guard:SetAllPoints(MerchantSellAllJunkButton)
        guard:SetFrameStrata(MerchantSellAllJunkButton:GetFrameStrata())
        guard:SetFrameLevel(MerchantSellAllJunkButton:GetFrameLevel() + 5)
        guard:EnableMouse(true)
        guard:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        guard:SetScript("OnClick", function()
            A.Print("A poor-quality item is Locked. Use Sell Marked Junk or clear its mark first.")
        end)
        A.UI.Tip(guard, "BagMarks: Locked junk", "Blizzard's Sell All Junk would include a Locked item. Use Sell Marked Junk to review an explicit selection.")
        MerchantSellAllJunkButton:HookScript("OnHide", function() guard:Hide() end)
        self.nativeJunkGuard = guard
    end
    self:RefreshButtons()
end
