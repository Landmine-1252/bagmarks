# Validation and in-game checklist

## Automated verification

From the repository root:

```sh
make test
make package
```

Use `LUA=/path/to/lua5.1 LUAC=/path/to/luac5.1` if needed. A different Lua language version is not a substitute for the syntax check. Python 3 is required; Pillow is required only to regenerate the included original icons.

The build entry point is `Makefile`. Run `make package` from the repository root to validate the addon and create `dist/BagMarks-<version>.zip`. `python3 tools/package.py` skips the Lua checks and regression suites but still validates the finished archive; it reads the version from `BagMarks.toc`. See [build and upload instructions](PACKAGING.md) for the corrected 1.0.0 package and CurseForge submission details.

For a new version, update `## Version` in `BagMarks.toc` and `A.version` in `Core.lua` to the same value, update the README's version, add an entry to `CHANGELOG.md`, and run `make package`. The in-game version labels use `A.version`. For a patch release, increment the final number, for example `1.0.0` to `1.0.1`. Packaging does not increment the version automatically. Each version gets its own ZIP filename in `dist/`.

The revised version 1.0.0 passed **175 mocked regression tests under Lua 5.1** and **10 Python archive tests**. Lua tests load every addon Lua file in TOC order, dispatch the addon lifecycle, and exercise state, UI models, and asynchronous queues. Static checks cover every Lua file, manifest completeness, SavedVariables declarations, version consistency, AddOns compartment callbacks, XML, texture dimensions and alpha, and prohibited destructive/global-replacement calls. The mock intentionally throws if the addon attempts to send mail, destroy an item, or automatically sell/attach a nonmatching state.

The initial release remains 1.0.0 because the previous upload was rejected. The reusable-item fix and archive changes are part of that first release, with CurseForge acceptance still pending. SavedVariables still use schema 2, preserving existing preferences and marks. Earlier development numbers through 1.1.4 remain recorded in the [development history](DEVELOPMENT_HISTORY.md).

Archive tests cover an extracted single-folder installation, exact source bytes, reproducible output, explicit directory records, standard file-type metadata, missing TOC dependencies, repository wrappers, duplicate paths, symlinks, unsafe paths, truncated ZIPs, and preserving the previous archive when packaging fails. These are local release-format checks, not an implementation of CurseForge's private verifier. The completed ZIP also receives checksum and manifest validation during every package build.

The test suite covers all four marks, identical items, missing/secret identity, account/character persistence, corrupt/future schemas, bag/bank movement, split/merge review flags, theme refresh, pooled-slot reuse, all mouse-button/modifier choices, cycling, tooltip scope, scoped guards, preview confirmation, stale identity/count/price, queue caps, refusals/timeouts, mail limits and marks, recipient lifecycle, binding conflicts/rollback, minimap movement and collection, combat and idle discovery cost. Schema migration also verifies that saved false values stay false.

The Ellesmere regression first failed against development build 1.1.1 because BagMarks never registered its item painter. It now covers buttons outside Blizzard's container pools, late registration, shared render-table reuse, empty slots, list icon hosts, scaling, hidden parents, combat deferral, bank accessibility, exact gestures, grouped GUID selection, stale menus, mixed-state guards, and sale/mail exclusions.

The destroy-confirmation regression first failed before `Protection.lua` was added because BagMarks left a Locked item on the cursor. The protection suite now also checks native hold ownership and release, identical copies, stale locations, missing/secret APIs, synchronous event reentry, cursor return failures, gamepad warnings, outgoing trade cancellation, Locked mail removal and closure, and serialized buyback recovery. Buyback tests cover historical entries, changing indexes, insufficient funds, full bags, errors, timeouts, disabled protection, and combat. The mock simulates a client honoring native holds; it does not prove that Forever honors them on every action path.

The reusable-item regression failed against the earlier unreleased build because a Locked item with a use spell and nonconsumable metadata stayed held. The 21 new cases cover ordinary use without clearing marks, stricter consumable/unknown-item holds, cursor and deletion guards, immediate context holds, overlapping contexts, ground versus item targeting, item data loading, missing/secret/throwing APIs, foreign holds, reentrant events, refused release, combat, reload, identical copies, Blizzard/Ellesmere input pass-through, tooltips, and helper exclusions even without a native hold. The mock models use separately from vendor sales; it does not establish real sleeping-bag metadata or execute Blizzard's protected click paths.

The automatic-sale regression failed before development build 1.1.4 because opening a merchant sold no marked Junk. The suite covers opted-in visits, default-off migration and persistence, the General checkbox, more than 12 stacks, duplicate events, changed marks/counts/prices, moved GUIDs, manual preview priority, skipped items, delayed callbacks, Stop Selling, refusal timeouts, and cancellation before and during a sale. It also verifies that item-targeting spells cannot turn a sale request into an unintended item action.

**Automated validation does not include an in-game test run.** In particular, mocks do not validate native input routing, secure execution, rendering, real network timing, or true GUID lifecycle. Collector regressions reproduce Ellesmere's inspected API interactions, rather than claiming an end-to-end test of Ellesmere in the client.

## Client preparation

1. Use Forever 1.60.1, starting with default Blizzard bags and no other addons. Record the version/build from `/dump GetBuildInfo()`.
2. Install the packaged `BagMarks` folder and restart the client. Confirm it appears in the AddOns list.
3. Enable errors with `/console scriptErrors 1`. For the taint pass, use `/console taintLog 1`, restart or reload, reproduce the interactions, and inspect the client's `Logs/taint.log` if produced. Restore the previous logging setting afterwards.
4. Use expendable items: at least two identical nonstackable copies, stackable trade goods, poor-quality vendor items, a bound item, and a normal mailable item. Do not use valuable gear for destructive tests.

## Required acceptance cases

Every checkbox below remains **pending in Forever**.

- [ ] **Installed version:** Check that the BagMarks settings title, Blizzard AddOns settings panel, minimap tooltip, and AddOns-menu hover show **BagMarks 1.0.0**. Confirm the title fits at supported UI scales and the category/menu name remains easy to find. After upgrading a development build, verify that preferences and item marks remain intact.
- [ ] **Mark and clear:** Alt + Right Click each test item; select Locked, Junk, Mail and Clear in turn. Verify the correct icon, tooltip label, menu checkmark, and immediate removal. Release Alt while the menu remains open. Select a different item after closing the menu and confirm no state leaks.
- [ ] **Themes with open bags:** Select all three themes, then `/bm theme`. Verify all visible bag and bank indicators repaint immediately, previews match, icons remain readable at 12 to 16 UI pixels, and borders/counts/cooldown readability is retained at several UI scales. Toggle labels and icons separately.
- [ ] **Keyboard shortcut:** Verify initially unbound in settings and Blizzard's normal keybinding list. Capture a key and a modified chord. Reject an occupied gameplay key without changing either binding. Escape cancels capture. Test Clear, Restore, the native binding editor, account/character binding sets, and persistence after reload. Confirm letters do not enter the recipient field during capture.
- [ ] **Minimap:** Left click toggles settings; right click toggles marking mode. Hover lists commands and mode. Drag around the minimap, reload, and check angle persistence. Hide/show with `/bm minimap`. Verify a drag does not also toggle settings. Check the mode indicator and a common named-button collector if installed; record its name/version. Test a square minimap if relevant.
- [ ] **Addon artwork:** Check the satchel icon in the minimap, AddOns list, Blizzard AddOns compartment, and Ellesmere's menu at several UI scales. Check transparency, orientation, and readability. Changing item themes should leave the logo's colors intact; disabling BagMarks should desaturate its minimap icon. Confirm the blue marking-mode indicator stays visible.
- [ ] **Persistence and character isolation:** Change options and mark items, `/reload`, relog, and restart. Verify marks and options persist. Log into another character: preferences carry over but item marks do not. A shared-bank item must not silently become marked on the other character. Confirm reset asks first and preserves marks/bindings.
- [ ] **Movement, sorting and banks:** Drag, swap, sort, and bank Junk/Mail items and check GUIDs/marks before and after. Locked items should resist movement until their mark is cleared. With expendable items only, disable BagMarks temporarily to move a still-marked Locked GUID, reenable it, and verify the same GUID is held again. Revisit character bank pages and any accessible account bank. Do not assume legacy bank numbering.
- [ ] **Identical copies:** Lock only one of two identical items; mark the other Junk or Mail. The other copy must remain movable and usable. Reload and revisit the bank. The selected GUID alone must retain its state and hold. Refuse marking if the identity API gives no usable GUID.
- [ ] **Split and merge:** Split Junk/Mail stacks and verify the source GUID's mark, new unmarked GUID, and changed-stack review rules. A Locked stack should resist ordinary split/merge actions. With expendable items and protection temporarily disabled, simulate changes to a Locked stack, then reenable and inspect surviving GUIDs and review flags. Repeat with rapid cursor moves, bank transfer and reload. Never infer mark inheritance from the item ID.
- [ ] **Locked versus manual Junk sales:** With automatic selling off, preview mixed Normal, Locked, Junk and Mail bags. Nothing sells before confirmation. Only listed Junk sells, up to 12 stacks per batch. Re-mark a preview item Locked, replace its slot, move its GUID, split it, close the merchant, switch to Buyback, or enter combat before confirmation. No newly Locked or replacement item may sell. Check unsellable, refundable, quest, busy, and unloaded item data.
- [ ] **Native junk protection and limits:** With an expendable Locked poor-quality item, test the native Sell All Junk button and ordinary merchant clicks. Test native holds and buyback recovery with an already-open confirmation and any installed external seller. Record which paths still sell despite the hold. Verify failure warnings and inspect buyback before leaving the merchant.
- [ ] **Mail:** With mixed marks and eligible/ineligible items, use Attach Marked Items on Send Mail. Only eligible Mail stacks enter free slots. Preserve an existing recipient and attachments. Test a blank recipient default, attachment limit, rejected attachment, mailbox closing midqueue, combat and a nonempty cursor. No mail may send without pressing Blizzard's Send. Remove attachments or close without sending, reopen, and verify markings remain.
- [ ] **Settings during combat:** Open and close with slash commands and minimap left click while fighting. Binding capture, mode, bag click guards and helpers must be inactive; overlays hide. Verify native holds remain requested and cursor/transfer checks handle readable items without protected-action errors. Leave combat and confirm displays and helpers resume with current data.
- [ ] **Default bag UI:** Test separate and combined bags, all carried bag sizes, bank pages, search/filter shading, pooled slot reuse, right-click equip/use, shift-click linking/splitting, Ctrl-click preview, drag/drop, cooldowns, and bag opening/closing. Marking mode must restore ordinary right clicks immediately when disabled. Test Ctrl and Shift marking modifiers too.

## Automatic-sale acceptance cases

Every case remains pending in Forever. Use expendable items and verify actual inventory and money changes.

- [ ] **Opt in and persistence:** Upgrade with existing saved settings and confirm automatic selling starts off. Enable **Automatically sell marked junk** in General, reload, and verify it remains enabled on this account. If enabled while already at a merchant, nothing should sell until the next visit. Check the General panel and tooltip at several UI scales; the new checkbox must not overlap mail controls or the footer.
- [ ] **Sale selection:** Prepare at least 20 marked Junk stacks, including a non-gray item, plus identical Locked, Mail, Normal, and unmarked gray copies. Open a merchant outside combat with an empty cursor. Only eligible marked Junk should sell, one stack at a time, with no confirmation. No bank item or identical unmarked copy may be included. Confirm a single completion message and the correct remaining inventory.
- [ ] **Stop and resume manually:** While sales are running, click **Stop Selling**. The next sale must not be issued, remaining marks must stay, and the button must return to **Sell Marked Junk**. Merchant updates must not restart the queue. Use that button to preview and confirm the remaining items. Turning automatic selling off must also stop an active automatic queue without cancelling an unrelated manual preview.
- [ ] **Cancellation:** Close the merchant quickly before the deferred start, reopen it, and check no old callback sells twice. During a longer sale, close the merchant, enter combat, disable BagMarks, turn automatic selling off, switch to Buyback, pick up another item, or begin targeting an item with a spell. Each action must stop further sales. Logout/reload must not retain an old queue. Verify no protected-action errors.
- [ ] **Identity and changes:** During a sale, change a queued item's mark to Locked, Mail, or Normal; change its count; move it; or replace its old slot with an identical copy. Mark another item Junk after the queue starts. Only original eligible GUIDs may sell, and changed marks/counts/prices must stop the queue. The new mark waits for a manual sale or another visit.
- [ ] **Failure and manual behavior:** Test quest, refundable, busy, unsellable, changed-stack, and uncached items. A refused or unacknowledged sale must stop without retrying. Opening a merchant with no eligible Junk should stay quiet. Clicking the manual button before auto-sale starts must show a preview and prevent background sales. With the option off, preserve the existing 12-stack confirmation behavior.
- [ ] **Bag integrations:** Repeat with separate/combined Blizzard bags and Ellesmere Grid/List/combined-stack views. Keep only one copy Junk in a merged display and verify only that GUID sells. Check the merchant helper remains visible, correctly labelled, and accessible at the supported UI scales.

## Protection acceptance cases

Every case below needs a real Forever test. Use expendable items and compare results with only BagMarks enabled first.

- [ ] **Hold and release:** Mark a non-reusable item Locked. Inspect `C_Item.IsLocked` with the snippet below. Try ordinary pickup, drag, equip/use, merchant sale, player-trade offer, mail attachment, bank deposit/withdrawal, and spell targeting. The client hold should block the item. Clear its mark and repeat; normal behavior must return immediately. The same must work with icons hidden, marking mode off, and both Blizzard and Ellesmere bags.
- [ ] **Locked sleeping bag and other reusable items:** Mark the sleeping bag Locked. With no merchant, mail, trade, bank, or auction window open and no item-targeting spell active, right-click it normally. Its effect should activate, the same item GUID and Locked mark should remain, and its tooltip should explain reusable use. Repeat with a hearthstone, cooldown active, `/reload`, icons hidden, Blizzard bags and Ellesmere Grid/List. Test an existing action-bar or `/use` binding without changing native scripts. Marking mode or a configured unmodified right-click gesture intentionally opens the marking menu instead; turn it off when testing ordinary use.
- [ ] **Reusable protection boundaries:** With an expendable reusable item Locked, test cursor return and deletion cancellation outside all item windows. Open merchant, mail, trade, bank and auction windows in turn; holds should engage immediately and prevent sale, attachment, offer, deposit/withdrawal and posting where the client honors them. Start Disenchant and other item-target spells, including a macro that targets immediately; verify the hold before targeting. Close or cancel each context; ordinary use should resume only after all contexts end. Ground-targeted reusable effects must remain usable. Test combat-capable reusables in combat and check errors/taint logs.
- [ ] **Reusable classification:** Record the sleeping bag's `C_Item.GetItemSpell` and `C_Item.IsConsumableItem` results using its item link. A nonconsumable with a use effect should qualify once data loads. Locked potions, charged consumables, learnable items and expendable quest items must retain the stricter hold when classified consumable. Do not spend a last charge on valuable items to test this. Missing/unreadable metadata must stay held. Unexpected client classification is a protection limit to investigate, not a reason to unlock every copy or assume safety.
- [ ] **Destroy fallback:** Try dragging an expendable Locked item out of the bags. It should stay held or return to its source slot. If a destroy confirmation appears, it should dismiss through Blizzard's empty-cursor handling. Compare a Normal, Junk, and Mail copy; their ordinary confirmations must remain usable. Test quest and high-quality confirmation variants. Record whether the event supplies a GUID and whether clearing the cursor restores the same GUID.
- [ ] **Gamepad and direct deletion:** With gamepad UI active, check whether native holds block deletion and whether any confirmation survives cursor return. Cancel any surviving confirmation manually. Treat noncursor/direct deletion as an explicit API limit, not a passed protection case. Never test on valuable gear.
- [ ] **Player trade:** Use a second player. Try right click, drag, modified-click, and any installed trade helper with a Locked item. If one reaches an outgoing slot, BagMarks should request trade cancellation. Repeat for the enchant slot, acceptance changes, and a preexisting offer when BagMarks is enabled. A Normal identical copy must trade normally. Verify cancellation and item return on both clients; do not infer them from the chat message alone.
- [ ] **Mail attachment:** If a Locked item reaches Send Mail, verify native attachment removal returns it without sending. If removal is delayed or refused, the mailbox should close and the draft's attachments should return. Repeat with multiple attachments, existing Normal/Mail items, full bags, and a separate cursor item. Check preserved marks and recipient handling. A missing tooltip GUID is an unresolved limit, never a reason to remove all identical copies.
- [ ] **Vendor recovery:** Use expendable Locked gray items and an external seller or another known path that bypasses the hold. If sold, only newly sold exact Locked GUIDs should be bought back, at their verified prices. Check each return and reapplied hold. Existing buyback entries and Normal/Junk/Mail copies must stay untouched. Test multiple sales, delayed responses, insufficient funds, full bags, closing the merchant, disabling BagMarks, and combat. A timeout must stop automatic recovery for that visit; inspect buyback manually. Record any GUID changes or overflow losses.
- [ ] **Hold lifecycle and other addons:** Check immediate release on Clear/Junk/Mail, disable, and logout. Reenable/reload/relog and verify saved Locked GUIDs regain their holds. Test inaccessible bank pages becoming available. Separately test any other addon that locks items; BagMarks must not release a hold that already existed when it inspected the item. Shared native locks have no ownership tokens, so record conflicts instead of treating simultaneous lock addons as certified compatible.
- [ ] **Additional transfer paths:** Test auction posting, account-bank movement, profession interfaces, macros, and Ellesmere quick actions with expendable Locked items. Record whether the client honors the hold. These do not have independent secure vetoes. Confirm no global function or native dialog scripts were replaced, and inspect errors and taint logs after the full pass.

## Ellesmere bag acceptance cases

These checks target the installed EllesmereUI Bags 9.8.6. No files in Ellesmere or ItemLockForever are changed by this release.

- [ ] **First marking click:** Install the current package, reload, and reopen Ellesmere bags. Out of combat, turn on `/bm mode` and right-click a normal item. Check that the BagMarks menu opens and that each mark and Clear updates the icon and tooltip immediately. Turn the mode off and test the configured modifier.
- [ ] **Bag layouts:** Repeat in Grid, List with the icon column visible, One Bag, Multi Bag, reagent bag, and live bank views. Scroll through rows, resize/scale/raise the window, switch categories and bank tabs, hide/reopen the window, and open an offline character view. Icons must stay on the item icon; hidden or offline views must not leave clickable overlays behind. List view without the icon column is outside the integration's input support.
- [ ] **Combined stacks:** With two identical stacks, open the grouped item's marking menu. Choose only one stack and verify the other remains Normal. A mixed group must say Mixed marks in its tooltip instead of showing a whole-group lock. Mark both the same to see the group icon. Clear one. Repeat in Cycle marks mode, which must still ask which stack to change.
- [ ] **Menu identity and helpers:** Open a stack submenu, then move that stack before choosing its mark. It must follow the GUID, not mark the replacement slot. Test grouped Locked, Junk, and Mail copies through both BagMarks helpers. Only the matching eligible GUIDs may be processed.
- [ ] **Input and combat:** Test customized modifier/mouse buttons, mode on/off, native clicks, dragging, links, and overlays disabled. Test Ellesmere's Alt quick actions separately; use another modifier or marking mode when they capture the item. Enter combat while bags are open, then repaint or change layout and leave combat. Marking must pause and resume without taint errors or changing Ellesmere's scripts.

## Mail, controls, and minimap acceptance cases

- [ ] **Autofill on opening:** Set a default recipient in General, open the mailbox, and choose Send Mail. Verify it fills without pressing Attach Marked Items. Typing should replace the selected default rather than append. Test a realm-qualified name.
- [ ] **Autofill boundaries:** Preserve an existing recipient and a reply recipient. Change or clear the recipient yourself, switch tabs, attach items, and verify it stays as edited. Close and reopen the mailbox to start a new draft. Disable autofill, reload, and confirm it stays off. A successful send should fill the next blank draft only after Blizzard resets it. Sending partway through attachment processing must leave remaining items in the bags.
- [ ] **New input controls:** In Marking, select each of Left, Right, Middle, Button 4 and Button 5. Test all Alt/Ctrl/Shift combinations, None, and Marking Mode only. Extra modifiers must not match the configured chord. Unselected clicks, default linking/previewing and other addons' shortcuts must remain available. A held cursor item must retain native drop behavior.
- [ ] **Cycle mode:** Set Cycle marks and verify Normal > Junk > Mail > Locked > Normal. Check immediate icons/tooltips, per-instance identity, reload persistence, and clearing. A stack needing review must open its menu without cycling automatically. Verify Locked guards still work when the marking button is Middle or a side button.
- [ ] **Ellesmere grouped menu:** With Ellesmere's minimap button grouping enabled and at least two addon buttons visible, verify BagMarks appears as one entry in the flyout. The shared group toggle and other addon entries must retain their actions. Close the flyout, move items/change themes/toggle marking mode, and confirm an invisible BagMarks button does not cover the toggle. Reopen it and click BagMarks left/right. Repeat after relog and with Ellesmere's ungrouped row/free-move settings.
- [ ] **Collector controls and standard menu:** Confirm BagMarks cannot drag itself out of an Ellesmere flyout or reset the collector's row placement. Hiding/showing BagMarks should communicate only that preference to the collector; if its open grid defers a visibility update, close and reopen the grid. Check Blizzard's AddOns compartment has one BagMarks entry, and that it works with the standalone minimap button hidden.
- [ ] **Migration and settings tabs:** Upgrade a schema 1 development profile with disabled icons/minimap/tooltips. Those choices, marks, default recipient and modifier must survive. New mouse/action choices default to Right Click/Menu. General, Marking and Appearance tabs must fit and work during combat; switching away from Marking must cancel active key capture.

## Additional protection and polish checks

- [ ] Target a Locked expendable item with Disenchant and with a beneficial enchant. Native holds and supported bag click guards should block both. Clear the mark and retry. Check profession and non-bag targeting paths separately and record any bypass.
- [ ] Verify the tooltip and settings explain that Locked items must be unlocked before moving or transferring them, while recognized reusable items can still be used outside risky contexts. Disabling BagMarks must release its own holds while preserving saved marks. No wording should promise universal protection or successful recovery before it is verified.
- [ ] Keep full bags and the bank open, change marks rapidly, sort, and switch bank tabs. Check CPU use and errors. Idle discovery should not repeatedly query all item GUIDs; inventory reconciliation is event-driven.
- [ ] Verify merchant/mail helpers fit below their native windows without covering buttons, tooltips, chat, or off-screen content at the supported resolutions. Verify long sale previews scroll.
- [ ] Repeat the input, combat, merchant and mail tests with other installed addons, especially bag replacements, vendor automation and minimap collectors. Record unsupported integrations rather than treating mock success as compatibility certification.
- [ ] Inspect the taint log and Lua errors after the full pass. Record client build, addon list, test result and reproduction steps for each failure.

## Diagnostic snippets

While out of combat, inspect the GUID in bag 0, slot 1:

```lua
/dump C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(0, 1))
```

Inspect the native hold for that slot:

```lua
/dump C_Item.IsLocked(ItemLocation:CreateFromBagAndSlot(0, 1))
```

Inspect stored marks or review flags for the current character:

```lua
/dump BagMarksCharDB.marks
/dump BagMarksCharDB.review
```

These snippets read state only. For a reviewed stack, reapply a mark through the menu. Do not manually change SavedVariables during normal use.
