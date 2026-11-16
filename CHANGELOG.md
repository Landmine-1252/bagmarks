# BagMarks Changelog

## 1.0.2 - Hover marking and clearer controls

### Added

- Mark by hovering over an item and pressing a configurable key. Cycle **Normal → Locked → Junk → Mail → Normal**, with Locked first. Choose **Cycle hovered item** in Marking settings to assign a key; it starts unbound and preserves existing shortcuts.
- Show a small **Marking** badge beside the pointer over supported bag items while Item Marking Mode is active.

### Changed

- Use **Ctrl + Shift + Right Click** as the default marking shortcut for new installs and settings resets, keeping Alt available for other addons. Existing saved shortcuts are preserved; change them in Marking settings to use the new default.
- Use Blizzard-style **General**, **Marking**, and **Appearance** tabs with a distinct selected tab.
- Show a clear **Item Marking Mode: ON/OFF** status, current controls, and an explicit on/off button in the settings footer.
- Configure the hover key and mode-toggle key separately, with independent Clear and Restore controls.
- Explain the new controls in the player guide. Hover marking still asks for an individual stack in Ellesmere's combined views and for review after stack changes.

### Validation

- Offline regression tests cover hover identity, binding conflicts, settings tabs, and mode indicators. Native cursor routing, keyboard behavior, tab rendering, and combat taint still need in-game verification in WoW Forever.

## 1.0.1 - Combat icons and safer marking

### Fixed

- Keep existing Locked, Junk, and Mail icons visible during combat in Blizzard and Ellesmere bags when the item can be identified. Marking clicks and sale/mail helpers still pause.
- Clear uncertain icons when slots are reused or combined stacks change, so an old mark is not shown on another item.
- Finish existing GitHub releases by attaching a missing addon ZIP, and verify matching ZIPs on repeat runs without replacing them.

### Changed

- Put Locked first when cycling marks: **Normal → Locked → Junk → Mail → Normal**, matching the marking menu. The first click on an unmarked item now locks it.
- Shorten the README and put default controls near the top.
- Run release builds on version tags or manual requests. Ordinary commits and pull requests no longer start the workflow.

### Notes

- Saved preferences and item marks are preserved.
- New slots and changed icon hosts wait until combat ends. Unreadable items and uncertain combined stacks may have their icons hidden.
- **185 Lua 5.1 mock tests**, **67 Python tests**, and static checks passed. In-game rendering and taint verification remain pending. See the [testing checklist](docs/TESTING.md) and [protection limits](docs/API_COMPATIBILITY.md).

## 1.0.0 - Initial release

Initial release for **WoW: Forever 1.60.1**.

### Added

- **Item marks:** Mark individual items or stacks as Locked, Junk, or Mail, with small bag icons and tooltip labels.
- **Locked-item protection:** Add safeguards against accidental selling, destruction, trading, and mailing. Clear the mark before moving or transferring a Locked item. Recognized reusable items can still be used.
- **Automatic junk selling:** Optionally sell eligible marked Junk when visiting a merchant, with a **Stop Selling** button to keep the remaining items.
- **Manual junk selling:** Preview and confirm up to 12 marked stacks at a time. Locked, Mail, and unmarked items are excluded from both sale methods.
- **Mail helper:** Attach eligible Mail items and automatically fill a configured default recipient. Review the mail and press Send yourself.
- **Custom controls:** Choose modifier keys and mouse buttons, or cycle through marks with each marking click.
- **Item Marking Mode:** Mark items without holding a modifier, with an optional keyboard shortcut.
- **Three icon themes:** Choose Classic, Minimal, or Colorful and see changes immediately.
- **Minimap button:** Open settings, toggle marking mode, and drag the button into position. Support for common minimap button collectors.
- **Bag support:** Integrate with Blizzard bags and banks, plus EllesmereUI Bags. Choose individual stacks in Ellesmere's combined item views.
- **Saved preferences:** Keep settings across characters and save item marks separately for each character.
- **Version display:** Show the installed version in settings and minimap/AddOns-menu tooltips.

### Fixes before the first release

- Allow locked reusable items, such as the sleeping bag, to be used without clearing their mark when the game identifies them as nonconsumable.
- Keep reusable items held while merchant, mail, trade, bank, or auction windows are open, and during item-targeting spells. Cursor and deletion safeguards remain active between uses.
- Keep stricter locks on consumables and items with missing or unreadable information. Locked items remain excluded from BagMarks' sale and mail helpers.
- Update tooltips to explain when a Locked item can still be used.
- Rebuild the release ZIP with explicit folders and standard file metadata, and validate its contents before replacing the previous build.
- Update installation and upload instructions. The file to upload is **BagMarks-1.0.0.zip** from the `dist` folder.
- Add GitHub Actions checks and automatic GitHub releases from matching version tags or a **Run workflow** request on GitHub's website. Each release includes the installable addon ZIP and changelog notes.

### Getting started

- Hold **Alt** and **right-click** an item to choose its mark.
- Open settings with `/bm` or `/bagmarks`.
- Automatic junk selling is **off by default**. Enable it under **General → Automatically sell marked junk**.

### Known limitations

- Some game actions and other addons can bypass Locked-item protection. See the [protection limits](docs/API_COMPATIBILITY.md).
- Keep the icon column visible when using Ellesmere's List view.
- **175 Lua 5.1 mock tests**, **36 Python archive and release tests**, and static checks passed for this release. In-game behavior, the sleeping bag's item data, visuals, and taint verification were pending. See the [testing checklist](docs/TESTING.md).
- Local archive validation cannot confirm CurseForge acceptance. The corrected package still needs to pass its upload checks.

Licensed under the [MIT License](LICENSE). Earlier build notes are preserved in the [development history](docs/DEVELOPMENT_HISTORY.md).
