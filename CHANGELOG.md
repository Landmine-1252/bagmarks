# BagMarks Changelog

## 1.0.0 - Initial release

Prepared for **WoW: Forever 1.60.1**. CurseForge approval is still pending; there has not yet been a public release. All fixes below are included in version 1.0.0.

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

### Getting started

- Hold **Alt** and **right-click** an item to choose its mark.
- Open settings with `/bm` or `/bagmarks`.
- Automatic junk selling is **off by default**. Enable it under **General → Automatically sell marked junk**.

### Known limitations

- Some game actions and other addons can bypass Locked-item protection. See the [protection limits](docs/API_COMPATIBILITY.md).
- Keep the icon column visible when using Ellesmere's List view.
- **175 Lua 5.1 mock tests**, **10 archive tests**, and static checks have passed. In-game behavior, the sleeping bag's item data, visuals, and taint verification remain pending. See the [testing checklist](docs/TESTING.md).
- Local archive validation cannot confirm CurseForge acceptance. The corrected package still needs to pass its upload checks.

Licensed under the [MIT License](LICENSE). Earlier build notes are preserved in the [development history](docs/DEVELOPMENT_HISTORY.md).
