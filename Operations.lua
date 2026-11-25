-- A single queue serves manual sales, automatic sales, and mail attachments.
-- Each job snapshots GUIDs, issues one request, then polls before advancing.
-- Cancellation never clears marks, so unfinished items remain available later.
local _, A = ...
local Ops = {}
A.Operations = Ops

local function ordered(items)
    -- Stable bag/slot order keeps previews and attachment batches predictable.
    local list = {}
    for _, item in pairs(items) do list[#list + 1] = item end
    table.sort(list, function(a, b) return a.bag == b.bag and a.slot < b.slot or a.bag < b.bag end)
    return list
end

function Ops:Eligible(item, state)
    -- A mark alone is insufficient: busy, changed, quest, refundable, and
    -- otherwise ineligible items must also stay out of every automated path.
    if not A.Store:Eligible(item, state) or A.API:IsQuest(item) or A.API:Refundable(item) then return false end
    if state == "junk" then return A.API:BagAllowsJunkSale(item.bag) and A.API:SellPrice(item) ~= nil end
    return A.IsMailMark(state) and A.API:CanMail(item)
end

-- Both sale paths capture exact GUIDs once, then use the same per-item checks.
-- Automatic sales can process all captured candidates; manual previews show 12.
function Ops:CollectJunk(limit)
    A.Store:RefreshInventory()
    local items = A.API:Scan(false)
    local preview, skipped, total = {}, 0, 0
    for _, item in ipairs(ordered(items)) do
        if A.Store:Get(item.guid) == "junk" then
            if (not limit or #preview < limit) and self:Eligible(item, "junk") then
                local price = A.API:SellPrice(item)
                preview[#preview + 1] = { guid = item.guid, count = item.count, itemID = item.itemID,
                    state = "junk", link = item.link, price = price }
                total = total + price * item.count
            else skipped = skipped + 1 end
        end
    end
    return preview, skipped, total
end

function Ops:CancelAutomatic(kind)
    if kind == "junk" then self.autoSalePending = nil
    elseif A.Mail.pending then A.Mail.pending.attach = nil end
    if self.job and self.job.kind == kind and self.job.automatic then self:Cancel(nil, kind) end
end

function Ops:AutoSellJunk()
    if not A.CanAct() or not A.db.autoSellJunk or self.job or self.autoSalePending then return end
    local ticket = {}
    self.autoSalePending = ticket
    -- Merchant frame setup and initial inventory events may follow MERCHANT_SHOW.
    -- A cancelled visit can never reuse this callback at a different merchant.
    C_Timer.After(.2, function()
        if self.autoSalePending ~= ticket then return end
        self.autoSalePending = nil
        if not A.db.autoSellJunk or not A.API:MerchantReady() or self.job
            or (A.UI.confirm and A.UI.confirm:IsShown()) then return end
        local entries = self:CollectJunk()
        if #entries == 0 then return end
        self.job = { kind = "junk", automatic = true, entries = entries, index = 1, completed = 0 }
        self:Step()
    end)
end

function Ops:PreviewJunk()
    if not A.API:MerchantReady() then A.Print("Open the merchant's Buy tab with an empty cursor, outside combat."); return end
    if self.job then return end
    self.autoSalePending = nil -- A deliberate preview takes priority over a delayed auto-sale.
    local preview, skipped, total = self:CollectJunk(12)
    if #preview == 0 then A.Print("No eligible marked junk. Check bag sale exclusions, stack changes, busy items and vendor eligibility."); return end
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

-- Pick the first deliverable stack in bag order when starting a fresh letter.
-- All subsequent entries must resolve to that same character.
function Ops:CollectMail(toField)
    A.Store:RefreshInventory()
    local entries, recipient = {}, nil
    for _, item in ipairs(ordered(A.API:Scan(false))) do
        local state = A.Store:Get(item.guid)
        if A.IsMailMark(state) and not (A.Mail.sentGUIDs and A.Mail.sentGUIDs[item.guid]) and self:Eligible(item, state) then
            local to = A.MailRoutes:Resolve(item.itemID, state)
            if to and (not toField or A.MailRoutes:MatchesToField(toField, to)) then
                -- Pin the saved address for this batch even when To shows a bare name.
                recipient = recipient or A.MailRoutes:Qualify(to)
                if A.MailRoutes:SameRecipient(to, recipient) then
                    entries[#entries + 1] = { guid = item.guid, count = item.count, itemID = item.itemID, state = state }
                end
            end
        end
    end
    return entries, recipient
end

function Ops:AttachMail(automatic)
    if A.Mail:SendPending() then return end
    A.Mail.attachAttempted = true
    if not A.API:MailReady() then
        if not automatic then A.Print("Open Send Mail with an empty cursor, outside combat.") end
        return
    end
    if self.job then return end
    self.autoSalePending = nil
    if not A.API:FreeAttachment() then
        if not automatic then A.Print("All mail attachment slots are occupied.") end
        return
    end
    local entries, recipient = A.Mail:PlanDraft()
    if not entries or #entries == 0 then
        if not automatic then A.Print("No eligible marked stacks for this draft. Check the To field and your recipients in the Mail tab.") end
        return
    end
    A.Mail.batchRecipient, A.Mail.batchComplete = recipient, false
    self.job = { kind = "mail", automatic = automatic, entries = entries, index = 1, completed = 0, recipient = recipient }
    self:Step()
end

function Ops:Cancel(message, kind)
    local active = self.job and (not kind or self.job.kind == kind)
    if active then self.job = nil end
    if kind ~= "mail" then
        self.autoSalePending = nil
        -- A sale confirmation from a previous visit must never sell at this merchant.
        self.generation = (self.generation or 0) + 1
        A.UI:CloseConfirmation()
    end
    if kind ~= "junk" and A.Mail.pending then A.Mail.pending.attach = nil end
    self:RefreshButtons()
    if active and message then A.Print(message) end
end

function Ops:Finish()
    local job = self.job
    self.job = nil
    self:RefreshButtons()
    if job and job.kind == "mail" then
        A.Mail.batchComplete = true
        A.Print(job.completed .. " stack(s) attached for " .. A.MailRoutes:DisplayName(job.recipient) .. ". Review the draft, then click Send.")
    elseif job then
        local skipped = job.skipped and (" Skipped " .. job.skipped .. " moved or busy stack(s).") or ""
        A.Print(job.completed .. " marked stack(s) sold." .. skipped)
    end
end

local function jobReady(job)
    if job.kind == "mail" then
        return A.API:MailReady() and A.Mail:AddressMatches(job.recipient)
            and (not job.automatic or (A.db.autoAttachMail and SendMailFrame.sendMode ~= "reply"))
    end
    return A.API:MerchantReady() and (not job.automatic or A.db.autoSellJunk)
end

function Ops:Step()
    local job = self.job
    if not job then return end
    if not jobReady(job) then
        self:Cancel("Operation stopped. Remaining markings were kept."); return
    end
    if job.kind == "mail" and not A.API:FreeAttachment() then self:Finish(); return end
    A.Store:RefreshInventory()
    local entry = job.entries[job.index]
    if not entry then self:Finish(); return end
    local items = A.API:Scan(false)
    local item = items[entry.guid]
    -- Another seller can claim a captured stack while the previous sale settles.
    -- Skip its GUID. Never use a replacement at the captured bag slot.
    while job.kind == "junk" and A.Store:Get(entry.guid) == "junk" and (not item or item.busy) do
        job.skipped = (job.skipped or 0) + 1
        job.index = job.index + 1
        entry = job.entries[job.index]
        if not entry then self:Finish(); return end
        item = items[entry.guid]
    end
    -- Revalidate identity, mark, size and eligibility immediately before every action.
    if not item or item.itemID ~= entry.itemID or item.count ~= entry.count or not self:Eligible(item, entry.state)
        or (job.kind == "mail" and not A.MailRoutes:SameRecipient(A.MailRoutes:Resolve(item.itemID, entry.state), job.recipient))
        or (job.kind == "junk" and A.API:SellPrice(item) ~= entry.price) then
        self:Cancel("An item changed or is unavailable. Review the remaining marked items and try again.")
        return
    end
    -- Record the in-flight item before calling APIs that can fire events
    -- synchronously. A successful call still needs the checks in Poll below.
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
        -- Table identity separates this job from a cancelled/replaced queue.
        -- The old timer may still run, but it cannot advance the new job.
        if self.job == job then self:Poll() end
    end)
end

function Ops:Poll()
    local job = self.job
    if not job or not job.pending then return end
    if not jobReady(job) then
        self:Cancel("Operation stopped. Remaining markings were kept."); return
    end
    local complete
    if job.kind == "mail" then
        local _, itemID, _, count = GetSendMailItem(job.attachment)
        if A.Safe(itemID) and A.Safe(count) and itemID == job.pending.itemID and count == job.pending.count then
            -- An attached stack can still occupy a locked bag slot. Prefer its
            -- actual attachment GUID; without one, wait for it to leave the bags.
            local guid = C_TooltipInfo and A.Protection:TooltipGUID(C_TooltipInfo.GetSendMailItem, job.attachment)
            if guid then complete = guid == job.pending.guid
            else complete = not A.API:Find(job.pending.guid, false) end
        end
        if complete then
            A.Mail.attached = A.Mail.attached or {}
            A.Mail.attached[job.attachment] = job.pending
            A.Mail:QueueDraftUpdate()
        end
    else
        complete = not A.API:Find(job.pending.guid, false)
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
        local automatic = self.job and self.job.kind == "junk" and self.job.automatic
        self.sellButton:SetText(automatic and "Stop Selling" or "Sell Marked Junk")
        self.sellButton:SetShown(A.IsEnabled() and A.merchantOpen == true)
        self.sellButton:SetEnabled((automatic or not self.job) and A.API:MerchantReady() and true or false)
    end
    if self.mailButton then
        self.mailButton:SetShown(A.IsEnabled() and A.mailOpen == true)
        self.mailButton:SetEnabled(not self.job and not A.Mail:SendPending() and A.API:MailReady() and true or false)
    end
    if self.nativeJunkGuard then
        local block = false
        if A.CanAct() and A.merchantOpen and MerchantSellAllJunkButton:IsVisible() then
            local carried = {}
            for _, id in ipairs(A.API:BagIDs(false)) do carried[id] = true end
            for guid, item in pairs(A.inventory or {}) do
                if carried[item.bag] and item.quality == 0 and A.Protection:GuardsMark(A.Store:Get(guid))
                    and A.API:BagAllowsJunkSale(item.bag) ~= false then
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
        self.sellButton = A.UI.Button(MerchantFrame, "Sell Marked Junk", 150, 0, 0, function()
            if self.job and self.job.kind == "junk" and self.job.automatic then
                self:Cancel("Automatic sale stopped. Remaining markings were kept.")
            else self:PreviewJunk() end
        end)
        self.sellButton:ClearAllPoints()
        self.sellButton:SetPoint("TOPLEFT", MerchantFrame, "BOTTOMLEFT", 14, -3)
        A.UI.Tip(self.sellButton, "Sell Marked Junk", "Preview up to 12 Junk stacks in bags that allow junk selling. During an automatic sale, click Stop Selling to keep the remaining items.")
    end
    if SendMailFrame and not self.mailButton then
        self.mailButton = A.UI.Button(SendMailFrame, "Attach Marked Items", 160, 0, 0, function() self:AttachMail() end)
        self.mailButton:ClearAllPoints()
        self.mailButton:SetPoint("TOPLEFT", SendMailFrame, "BOTTOMLEFT", 14, -3)
        A.UI.Tip(self.mailButton, "Attach Marked Items", "Prepare one recipient's marked stacks. If you enter a To name, only stacks assigned to that character are attached.")
    end
    if MerchantSellAllJunkButton and not self.nativeJunkGuard then
        -- This separate button intercepts clicks only while our guard is shown.
        -- It does not replace Blizzard's handler or veto other addons' sales.
        local guard = CreateFrame("Button", nil, UIParent)
        guard:SetAllPoints(MerchantSellAllJunkButton)
        guard:SetFrameStrata(MerchantSellAllJunkButton:GetFrameStrata())
        guard:SetFrameLevel(MerchantSellAllJunkButton:GetFrameLevel() + 5)
        guard:EnableMouse(true)
        guard:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        guard:SetScript("OnClick", function()
            A.Print("A poor-quality item is marked Locked, Mail, or Disenchant. Use Sell Marked Junk to sell your Junk stacks.")
        end)
        A.UI.Tip(guard, "BagMarks: Protected junk", "Blizzard's Sell All Junk could include a Locked, Mail, or Disenchant item. Use Sell Marked Junk to review your Junk stacks.")
        MerchantSellAllJunkButton:HookScript("OnHide", function() guard:Hide() end)
        self.nativeJunkGuard = guard
    end
    self:RefreshButtons()
end
