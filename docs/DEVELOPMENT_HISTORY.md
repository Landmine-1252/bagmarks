# Development history

Earlier build notes are kept here for reference. Player-facing release notes are in [CHANGELOG.md](../CHANGELOG.md).

## Release preparation for 1.0.0 - 2026-11-14

- Set the release version to **1.0.0**, including the features developed in the earlier builds below.
- Show the installed version in the BagMarks settings title, Blizzard AddOns settings panel, and minimap/AddOns-menu tooltip.
- Refresh the README with a short introduction, installation steps, marking controls, automatic and manual junk selling, mail setup, and clear protection limits.
- Include individual item marks, Locked-item safeguards, optional automatic junk selling, mail recipient autofill, customizable controls, three icon themes, and Blizzard/Ellesmere bag integration.
- Preserve existing saved preferences and marks. The SavedVariables schema remains 2; renumbering the release does not downgrade saved data.
- Validate the package with 154 mocked Lua 5.1 tests and static checks. In-game behavior, rendering, and taint verification remain pending.

## Development build history

The entries below record earlier work-in-progress build numbers. Their features are included in the 1.0.0 release above.

### Development build 1.1.4 - 2026-11-14

- Add **Automatically sell marked junk** under General. This account-wide option defaults to off and takes effect on the next merchant visit.
- When enabled, sell all eligible marked Junk from that visit's initial selection, one stack at a time, without a confirmation each visit. Keep the manual preview button and its 12-stack limit.
- Reuse the same GUID, mark, count, price, and eligibility checks before every sale. Exclude Locked, Mail, unmarked, quest, refundable, busy, unreadable, and review-needed items.
- Show **Stop Selling** during automatic sales. Stop pending and running sales on merchant closure, combat, logout, reset, or disabling the addon or option. Cancel if the cursor, merchant tab, item targeting, or queued item changes make the action unsafe.
- Prevent duplicate merchant events, inventory changes, and cancelled callbacks from starting another sale. Manual previews take priority; newly marked items wait for another visit or a manual sale.
- Keep the General settings compact and document automatic selling and the existing MIT license.
- Add 37 automated sale regressions, for 154 passing Lua 5.1 tests. In-game sale timing, layout, and taint verification remain pending.

### Development build 1.1.3 - 2026-11-14

- Strengthen Locked marks with native per-item holds, checked by GUID. Clear the mark before moving, equipping, using, selling, trading, or mailing that item. Never hold identical copies by item ID.
- Add a cursor-return safeguard and handle the synchronous destroy-confirmation event using its exact item GUID. Leave Blizzard's deletion functions and confirmation dialogs unchanged.
- Cancel outgoing trades containing a readable Locked GUID. Remove Locked outgoing mail attachments, or request mailbox closure if removal is refused or still pending. Never accept trades or send mail automatically.
- Attempt one sequential buyback per newly sold Locked GUID at the current merchant, with price checks and a bounded acknowledgement timeout. Do not purchase historical entries, guess identities, or retry a refused purchase.
- Release only BagMarks-acquired holds when marks change, the addon is disabled, or the character logs out. Keep native holds and cursor/transfer event checks active during combat where APIs remain readable; UI interactions and helpers still pause.
- Update player guidance and the client checklist to distinguish safeguards from API limits, including gamepad and direct-action bypasses. Only BagMarks files are changed.
- Add 41 mocked protection regressions, bringing the suite to 117 passing Lua 5.1 tests while retaining the Ellesmere integration cases. No in-game protection, visual, or taint results are claimed.

### Development build 1.1.2 - 2026-11-14

- Fix item marking in EllesmereUI Bags by registering with its public item painter. Support live grid, list, reagent-bag, and bank slots, including reused buttons and temporary render data.
- Keep overlays attached to Ellesmere's icon hosts so they follow its scale, scrolling, and visibility. List view requires the icon column to be visible.
- Add a per-stack submenu for combined item buttons. Choose the individual stack to mark, including in cycle mode. Mixed groups report their marks in the tooltip; an icon represents a shared mark only when every represented stack has that mark.
- Keep existing per-character marks and scoped click guards, with no changes to other addons' files.
- Add 14 integration regression tests, bringing the Lua 5.1 mocked suite to 76 passing tests. Native input, rendering, and taint verification still require an in-game pass.

### Development build 1.1.1 - 2026-11-14

- Use the hosted BagMarks icon in the README.
- Add GitHub links for reviewing the code, reporting issues, and contributing changes.
- Document the existing build commands and how to prepare future versions.

### Development build 1.1.0 - 2026-11-14

- Add a distinctive satchel logo to the minimap button, AddOns entry, and README, with gold, red, and blue details for the three marks.
- Rewrite the README with a short introduction and player-focused installation and usage instructions.
- Automatically fill a configured recipient when Send Mail opens and after a successful send. Preserve reply recipients, existing names, deliberate edits and cleared fields. Add an autofill toggle.
- Support Left, Right, Middle, Mouse Button 4 and Mouse Button 5, combined with Alt/Ctrl/Shift combinations, no modifier, or marking-mode-only input.
- Add optional click-to-cycle marking: Normal > Junk > Mail > Locked > Normal. Changed stacks still require menu review.
- Organize settings into compact General, Marking and Appearance tabs.
- Stop re-showing and repositioning collector-managed minimap buttons during ordinary refresh. Preserve collectors' update scripts and disable invisible button hit targets. Audit Ellesmere's collector and flyout source.
- Register a standard Blizzard AddOns compartment entry without replacing its menu button.
- Preserve saved false preferences correctly and migrate schema 1 settings to schema 2 without changing existing marks or the default gesture.
- Stop an active attachment queue when the player sends mail, so leftovers cannot enter the next draft automatically.
- Expand validation to 62 mocked Lua 5.1 tests, including recipient lifecycle, configurable gestures, cycling and collector interactions.

In-game Ellesmere, native input, visual and taint verification remain pending.

### Initial development build (labelled 1.0.0) - 2026-11-14

- Initial Forever 1.60.1 implementation, interface 16001, using verified modern API names.
- Per-character GUID marks for Locked, Junk, and Mail; no item-ID fallback.
- Native bag and pooled-bank integration, tooltips, modifier menus, and Item Marking Mode.
- Conservative stack review flags for splits, merges, and uncertain inventory changes.
- Confirmed merchant batches with per-action revalidation and an eligible mail attachment helper.
- Scoped Locked-item click guards, including the native Sell All Junk button, with documented bypasses.
- Compact native settings, keyboard capture with conflict rejection, and a draggable minimap button.
- Classic, Minimal, and Colorful themes with original transparent icons.
- Validated SavedVariables, schema-zero migration, and protection against newer-data downgrades.
- Lua 5.1 mocked regression tests, static checks, packaging tooling, and a reproducible client checklist.

No in-game runtime, taint, or visual compatibility results are claimed for this release.
