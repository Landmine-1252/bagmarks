# Validation and in-game checklist

## Automated verification

From the repository root:

```sh
make test
make package
```

Use `LUA=/path/to/lua5.1 LUAC=/path/to/luac5.1` if needed. A different Lua language version is not a substitute for the syntax check. Python 3 is required; Pillow is required only to regenerate the included original icons.

Version 1.1.0 passed **62 mocked regression tests under Lua 5.1**. Tests load every addon Lua file in TOC order, dispatch the addon lifecycle, and exercise state, UI models, and asynchronous queues. Static checks cover every Lua file, manifest completeness, SavedVariables declarations, version consistency, AddOns compartment callbacks, XML, texture dimensions and alpha, and prohibited destructive/global-replacement calls. The mock intentionally throws if the addon attempts to send mail or automatically process a nonmatching state.

The test suite covers all four marks, identical items, missing/secret identity, account/character persistence, corrupt/future schemas, bag/bank movement, split/merge review flags, theme refresh, pooled-slot reuse, all mouse-button/modifier choices, cycling, tooltip scope, scoped guards, preview confirmation, stale identity/count/price, queue caps, refusals/timeouts, mail limits and marks, recipient lifecycle, binding conflicts/rollback, minimap movement and collection, combat and idle discovery cost. Schema migration also verifies that saved false values stay false.

**Automated validation does not include an in-game test run.** In particular, mocks do not validate native input routing, secure execution, rendering, real network timing, or true GUID lifecycle. Collector regressions reproduce Ellesmere's inspected API interactions, rather than claiming an end-to-end test of Ellesmere in the client.

## Client preparation

1. Use Forever 1.60.1, starting with default Blizzard bags and no other addons. Record the version/build from `/dump GetBuildInfo()`.
2. Install the packaged `BagMarks` folder and restart the client. Confirm it appears in the AddOns list.
3. Enable errors with `/console scriptErrors 1`. For the taint pass, use `/console taintLog 1`, restart or reload, reproduce the interactions, and inspect the client's `Logs/taint.log` if produced. Restore the previous logging setting afterwards.
4. Use expendable items: at least two identical nonstackable copies, stackable trade goods, poor-quality vendor items, a bound item, and a normal mailable item. Do not use valuable gear for destructive tests.

## Required acceptance cases

Every checkbox below remains **pending in Forever**.

- [ ] **Mark and clear:** Alt + Right Click each test item; select Locked, Junk, Mail and Clear in turn. Verify the correct icon, tooltip label, menu checkmark, and immediate removal. Release Alt while the menu remains open. Select a different item after closing the menu and confirm no state leaks.
- [ ] **Themes with open bags:** Select all three themes, then `/bm theme`. Verify all visible bag and bank indicators repaint immediately, previews match, icons remain readable at 12 to 16 UI pixels, and borders/counts/cooldown readability is retained at several UI scales. Toggle labels and icons separately.
- [ ] **Keyboard shortcut:** Verify initially unbound in settings and Blizzard's normal keybinding list. Capture a key and a modified chord. Reject an occupied gameplay key without changing either binding. Escape cancels capture. Test Clear, Restore, the native binding editor, account/character binding sets, and persistence after reload. Confirm letters do not enter the recipient field during capture.
- [ ] **Minimap:** Left click toggles settings; right click toggles marking mode. Hover lists commands and mode. Drag around the minimap, reload, and check angle persistence. Hide/show with `/bm minimap`. Verify a drag does not also toggle settings. Check the mode indicator and a common named-button collector if installed; record its name/version. Test a square minimap if relevant.
- [ ] **Addon artwork:** Check the satchel icon in the minimap, AddOns list, Blizzard AddOns compartment, and Ellesmere's menu at several UI scales. Check transparency, orientation, and readability. Changing item themes should leave the logo's colors intact; disabling BagMarks should desaturate its minimap icon. Confirm the blue marking-mode indicator stays visible.
- [ ] **Persistence and character isolation:** Change options and mark items, `/reload`, relog, and restart. Verify marks and options persist. Log into another character: preferences carry over but item marks do not. A shared-bank item must not silently become marked on the other character. Confirm reset asks first and preserves marks/bindings.
- [ ] **Movement, sorting and banks:** Drag and swap marked items between bags, use Blizzard sorting, deposit/withdraw through every available character bank bag/page, then reopen the bank. Check the GUID and mark before/after. Verify the account bank only if the character can access it. Do not assume legacy `BankFrameItemN` frames or container `-1`.
- [ ] **Identical copies:** Lock only one of two identical items; mark the other Junk or Mail. Swap slots, sort, reload, and revisit the bank. The selected GUID alone must retain its state. Refuse marking if the identity API gives no usable GUID.
- [ ] **Split and merge:** Split each marked stack. The source GUID keeps its mark; a new GUID starts unmarked. Merge into a Normal, Junk, Mail and Locked stack in both directions. Verify the surviving GUID's state, review tooltip, and exclusion from helpers until explicitly reviewed. Repeat with rapid cursor moves, bank transfer and reload between steps. Record actual GUID replacement behavior.
- [ ] **Locked versus Junk sales:** Preview mixed Normal, Locked, Junk and Mail bags. Nothing sells before confirmation. Only listed Junk sells, up to 12 stacks per batch. Re-mark a preview item Locked, replace its slot, move its GUID, split it, close the merchant, switch to Buyback, or enter combat before confirmation. No newly Locked or replacement item may sell. Check unsellable, refundable, quest, busy, and unloaded item data.
- [ ] **Native junk protection and limits:** With an expendable Locked poor-quality item, test the native Sell All Junk button. Its click must be guarded. Verify ordinary Locked merchant clicks and the explicit warning. Separately confirm that already-open confirmations, macros and other sellers are documented bypasses, not guaranteed protected paths.
- [ ] **Mail:** With mixed marks and eligible/ineligible items, use Attach Marked Items on Send Mail. Only eligible Mail stacks enter free slots. Preserve an existing recipient and attachments. Test a blank recipient default, attachment limit, rejected attachment, mailbox closing midqueue, combat and a nonempty cursor. No mail may send without pressing Blizzard's Send. Remove attachments or close without sending, reopen, and verify markings remain.
- [ ] **Settings during combat:** Open and close with slash commands and minimap left click while fighting. Binding capture, mode, guards and helpers must be inactive; overlays hide. No protected-action error should occur. Leave combat and confirm item displays resume with current data.
- [ ] **Default bag UI:** Test separate and combined bags, all carried bag sizes, bank pages, search/filter shading, pooled slot reuse, right-click equip/use, shift-click linking/splitting, Ctrl-click preview, drag/drop, cooldowns, and bag opening/closing. Marking mode must restore ordinary right clicks immediately when disabled. Test Ctrl and Shift marking modifiers too.

## Version 1.1.0 acceptance cases

- [ ] **Autofill on opening:** Set a default recipient in General, open the mailbox, and choose Send Mail. Verify it fills without pressing Attach Marked Items. Typing should replace the selected default rather than append. Test a realm-qualified name.
- [ ] **Autofill boundaries:** Preserve an existing recipient and a reply recipient. Change or clear the recipient yourself, switch tabs, attach items, and verify it stays as edited. Close and reopen the mailbox to start a new draft. Disable autofill, reload, and confirm it stays off. A successful send should fill the next blank draft only after Blizzard resets it. Sending partway through attachment processing must leave remaining items in the bags.
- [ ] **New input controls:** In Marking, select each of Left, Right, Middle, Button 4 and Button 5. Test all Alt/Ctrl/Shift combinations, None, and Marking Mode only. Extra modifiers must not match the configured chord. Unselected clicks, default linking/previewing and other addons' shortcuts must remain available. A held cursor item must retain native drop behavior.
- [ ] **Cycle mode:** Set Cycle marks and verify Normal > Junk > Mail > Locked > Normal. Check immediate icons/tooltips, per-instance identity, reload persistence, and clearing. A stack needing review must open its menu without cycling automatically. Verify Locked guards still work when the marking button is Middle or a side button.
- [ ] **Ellesmere grouped menu:** With Ellesmere's minimap button grouping enabled and at least two addon buttons visible, verify BagMarks appears as one entry in the flyout. The shared group toggle and other addon entries must retain their actions. Close the flyout, move items/change themes/toggle marking mode, and confirm an invisible BagMarks button does not cover the toggle. Reopen it and click BagMarks left/right. Repeat after relog and with Ellesmere's ungrouped row/free-move settings.
- [ ] **Collector controls and standard menu:** Confirm BagMarks cannot drag itself out of an Ellesmere flyout or reset the collector's row placement. Hiding/showing BagMarks should communicate only that preference to the collector; if its open grid defers a visibility update, close and reopen the grid. Check Blizzard's AddOns compartment has one BagMarks entry, and that it works with the standalone minimap button hidden.
- [ ] **Migration and settings tabs:** Upgrade a 1.0.0 profile with disabled icons/minimap/tooltips. Those choices, marks, default recipient and modifier must survive. New mouse/action choices default to Right Click/Menu. General, Marking and Appearance tabs must fit and work during combat; switching away from Marking must cancel active key capture.

## Additional protection and polish checks

- [ ] Target a Locked expendable item with Disenchant and with a beneficial enchant through a bag click. Both should be guarded outside combat. Clear the mark and retry. Macro and non-bag targeting paths remain outside the guarantee.
- [ ] Drag a Locked expendable item outside a merchant/mail/targeting context. Confirm ordinary movement works. Confirm that cursor deletion remains a documented bypass and the tooltip/settings warning is clear. Do not interpret a padlock as a secure engine lock.
- [ ] Keep full bags and the bank open, change marks rapidly, sort, and switch bank tabs. Check CPU use and errors. Idle discovery should not repeatedly query all item GUIDs; inventory reconciliation is event-driven.
- [ ] Verify merchant/mail helpers fit below their native windows without covering buttons, tooltips, chat, or off-screen content at the supported resolutions. Verify long sale previews scroll.
- [ ] Repeat the input, combat, merchant and mail tests with other installed addons, especially bag replacements, vendor automation and minimap collectors. Record unsupported integrations rather than treating mock success as compatibility certification.
- [ ] Inspect the taint log and Lua errors after the full pass. Record client build, addon list, test result and reproduction steps for each failure.

## Diagnostic snippets

While out of combat, inspect the GUID in bag 0, slot 1:

```lua
/dump C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(0, 1))
```

Inspect stored marks or review flags for the current character:

```lua
/dump BagMarksCharDB.marks
/dump BagMarksCharDB.review
```

These snippets read state only. For a reviewed stack, reapply a mark through the menu. Do not manually change SavedVariables during normal use.
