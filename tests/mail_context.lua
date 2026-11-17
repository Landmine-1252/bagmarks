-- The server interaction and the addon flag are independent here. This models
-- the reported missing MAIL_CLOSED notification, not just the normal event path.
return function(M, A, test, eq, mark)
    local function event(name, ...) A.eventFrame:Fire("OnEvent", name, ...) end
    local function poll() A.eventFrame:Fire("OnUpdate", .3) end
    local function openMail()
        M.mailActive = true
        SendMailFrame:Show()
        event("MAIL_SHOW")
    end
    local function bag()
        return mark("Item-SleepingBag", 0, 1, "locked", { itemID = 211527, spellID = 429961 })
    end

    test("missed mailbox close releases reusable holds while retaining Locked marks", function()
        M.reentrantLocks = true
        local sleeping = bag()
        local hearth = mark("Item-Hearthstone", 0, 2, "locked", { itemID = 6948, spellID = 8690 })
        local other = mark("Item-Other", 0, 3, "locked", { itemID = 100 })
        openMail(); M.tick(0)
        eq(sleeping.held, true); eq(hearth.held, true)
        M.mailActive = false; SendMailFrame:Hide()
        -- Deliberately omit MAIL_CLOSED, as in the captured client report.
        poll(); M.tick(0)
        eq(A.mailOpen, false); eq(sleeping.held, nil); eq(hearth.held, nil)
        eq(other.held, nil); eq(A.Store:Get(sleeping.guid), "locked")
        C_Container.UseContainerItem(0, 1); eq(M.used[1], sleeping.guid)
        local queries = M.mailQueries
        poll(); poll(); eq(M.mailQueries, queries, "closed mail must stop idle queries")
    end)

    test("modern mailbox hide handles immediate and deferred client state updates", function()
        local sleeping = bag(); openMail()
        event("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 999)
        eq(A.mailOpen, true); eq(sleeping.held, true)
        event("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.MailInfo)
        eq(sleeping.held, true)
        M.mailActive = false; M.tick(0)
        eq(A.mailOpen, false); eq(sleeping.held, nil)
        openMail(); M.mailActive = false
        event("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.MailInfo)
        eq(A.mailOpen, false); eq(sleeping.held, nil)
    end)

    test("a hidden mailbox UI and overlapping risks do not release active holds", function()
        local sleeping = bag(); openMail(); SendMailFrame:Hide()
        poll(); eq(A.mailOpen, true); eq(sleeping.held, true)
        event("TRADE_SHOW")
        M.mailActive = false; poll()
        eq(A.mailOpen, false); eq(sleeping.held, true)
        event("TRADE_CLOSED"); eq(sleeping.held, nil)
    end)

    test("missing secret or failing mailbox state cannot clear protection", function()
        local sleeping = bag(); openMail()
        local manager = C_PlayerInteractionManager
        local query = manager.IsInteractingWithNpcOfType
        local kind = Enum.PlayerInteractionType
        C_PlayerInteractionManager = nil; poll(); eq(sleeping.held, true)
        C_PlayerInteractionManager = manager
        manager.IsInteractingWithNpcOfType = nil; poll(); eq(sleeping.held, true)
        manager.IsInteractingWithNpcOfType = function() error("unreadable interaction") end
        poll(); eq(sleeping.held, true)
        for _, value in ipairs({ M.secret, "false", 0 }) do
            manager.IsInteractingWithNpcOfType = function() return value end
            poll(); eq(A.mailOpen, true); eq(sleeping.held, true)
        end
        manager.IsInteractingWithNpcOfType = function() end
        poll(); eq(sleeping.held, true)
        manager.IsInteractingWithNpcOfType = query
        Enum.PlayerInteractionType = nil; poll(); eq(sleeping.held, true)
        Enum.PlayerInteractionType = { MailInfo = M.secret }
        event("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", M.secret)
        poll(); eq(sleeping.held, true)
        Enum.PlayerInteractionType = kind
        M.mailActive = false; poll(); eq(sleeping.held, nil)
    end)

    test("a delayed mailbox hide cannot close a newly opened mailbox", function()
        local sleeping = bag(); openMail()
        event("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.MailInfo)
        M.mailActive = false; event("MAIL_CLOSED")
        openMail(); M.tick(0)
        eq(A.mailOpen, true); eq(sleeping.held, true)
        M.mailActive = false; poll(); eq(sleeping.held, nil)
    end)

    test("mailbox reconciliation releases owned reusable holds in combat without inventory scans", function()
        local sleeping = bag(); openMail(); M.tick(0)
        M.combat = true; event("PLAYER_REGEN_DISABLED")
        local frames, reads = #M.frames, M.reads
        M.mailActive = false; poll()
        eq(A.mailOpen, false); eq(sleeping.held, nil)
        eq(A.Store:Get(sleeping.guid), "locked")
        eq(#M.frames, frames); eq(M.reads, reads)
    end)

    test("a missed mailbox close cancels attachments and retains unsent marks", function()
        bag()
        mark("Item-Mail1", 0, 2, "mail", { itemID = 101 })
        local remaining = mark("Item-Mail2", 0, 3, "mail", { itemID = 102 })
        openMail(); A.Operations:AttachMail()
        assert(A.Operations.job)
        M.mailActive = false; SendMailFrame:Hide(); poll(); M.tick(2)
        eq(A.Operations.job, nil); eq(A.mailOpen, false)
        eq(M.bags[0][3], remaining); eq(A.Store:Get(remaining.guid), "mail")
        eq(M.attachments[2], nil)
    end)

    test("mailbox cleanup cancels pending autofill and does not release foreign holds", function()
        local sleeping = mark("Item-SleepingBag", 0, 1, "locked", { itemID = 211527, spellID = 429961, held = true })
        A.char.recipient = "Example"
        openMail(); assert(A.Mail.pending)
        M.mailActive = false; poll(); M.tick(0)
        eq(A.Mail.pending, nil); eq(SendMailNameEditBox:GetText(), "")
        eq(sleeping.held, true); eq(#M.unlockCalls, 0)
    end)
end
