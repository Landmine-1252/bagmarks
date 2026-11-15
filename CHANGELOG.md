# Changelog

## 1.1.0 - 2026-11-14

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

## 1.0.0 - 2026-11-14

- Initial Forever 1.60.1 release, interface 16001, using verified modern API names.
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
