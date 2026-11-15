# BagMarks

Mark what you want to keep, sell, or mail, right in your WoW Forever bags.

<img src="https://raw.githubusercontent.com/Landmine-1252/bagmarks/refs/heads/main/Media/BagMarks.png" alt="BagMarks: a leather satchel with a gold lock and red and blue marking tabs" width="144" height="144">

**Version 1.0.1** · **WoW: Forever 1.60.1**

Small icons for Blizzard bags and banks or EllesmereUI Bags. No extra inventory window or dependencies.

CurseForge approval is still pending.

## Default controls

| Control | Action |
| --- | --- |
| **Alt + Right Click** an item | Open its marking menu |
| **Left Click** the minimap button | Open or close settings |
| **Right Click** the minimap button | Toggle Item Marking Mode |
| **Left-drag** the minimap button | Move it around the minimap |
| **`/bm`** or **`/bagmarks`** | Open or close settings |

**Item Marking Mode starts off.** Turn it on for plain right-click marking; turn it off to restore ordinary right-clicks. A blue minimap indicator shows when active. Login or `/reload` turns it off.

On a fresh install, the keyboard shortcut is **unbound**. The minimap button, item icons, and tooltip labels are on, using the **Colorful** theme.

## Choose a mark

Marks belong to the selected item or stack, with an icon and tooltip label. Identical copies keep their own marks.

| Mark | Icon | Purpose |
| --- | --- | --- |
| Locked | Gold padlock | Help protect the item from loss |
| Junk | Red trash can | Set aside for selling |
| Mail | Blue envelope | Set aside for mailing |
| Clear Mark | None | Return the item to Normal |

**Selling:** At a merchant, click **Sell Marked Junk**, review up to 12 stacks, and confirm. Automatic selling starts **off**; enable it in `/bm` → **General** for your next visit. **Stop Selling** cancels remaining sales. Only eligible Junk is sold; Locked, Mail, and unmarked items are excluded.

**Mailing:** Autofill starts **on**, with no recipient set. Add a **Default recipient** in **General** to fill empty Send Mail recipients. Replies and your edits are preserved. At a mailbox, click **Attach Marked Items** for eligible Mail items. Bound items are skipped; unsent items keep their marks. **Review the mail and press Send yourself.** Sending is never automatic.

## Keeping items safe

Clear Locked marks before moving or transferring items. Recognized reusables, such as your sleeping bag, remain usable while Locked. Close merchant, mail, trade, bank, and auction windows and finish item-targeting spells first. Consumables and unrecognized items stay unusable while Locked.

Some game actions and other addons can bypass protection. Disabling BagMarks stops it. See the [protection limits and buyback behavior](docs/API_COMPATIBILITY.md).

## Customize your controls

In `/bm` → **Marking**, choose your modifier keys and mouse button. For Diablo-style marking, choose **Cycle marks**: **Normal → Locked → Junk → Mail → Normal**. The first click locks an unmarked item. **Set Key** lets you bind the mode toggle without overwriting another shortcut.

Under **Appearance**, choose **Classic**, **Minimal**, or **Colorful** icons. Changes apply immediately.

## Install

1. Extract **BagMarks-1.0.1.zip** into `Interface/AddOns`. The file should be at `Interface/AddOns/BagMarks/BagMarks.toc`.
2. Restart WoW Forever and enable **BagMarks** in the AddOns list.

Use the packaged addon ZIP; GitHub's **Download ZIP** contains the source project. To update, replace the **BagMarks** folder. Saved preferences and marks are kept.

## A few things to know

- Settings are shared across characters; item marks are saved per character. Check marks after splitting or merging stacks.
- Marking and sale/mail helpers pause during combat. Existing item icons stay visible when readable; new slots may wait until combat ends. Settings remain accessible.
- **EllesmereUI Bags:** keep the icon column visible in List view. Combined stacks let you choose which stack to mark. If Alt conflicts with Ellesmere's controls, choose another shortcut or use Marking Mode.

## Commands

| Command | Action |
| --- | --- |
| `/bm` or `/bagmarks` | Open or close settings |
| `/bm mode` | Toggle Item Marking Mode |
| `/bm minimap` | Show or hide the minimap button |
| `/bm theme` | Cycle icon themes |
| `/bm reset` | Reset settings after confirmation; keep marks and keybindings |
| `/bm help` | Show the command list |

## Help improve BagMarks

[Browse the code](https://github.com/Landmine-1252/bagmarks), [report a bug or suggest a feature](https://github.com/Landmine-1252/bagmarks/issues), or fork the repository and [open a pull request](https://github.com/Landmine-1252/bagmarks/pulls).

Include your BagMarks version, bag addon, and steps to reproduce any issue.

[MIT licensed](LICENSE). Automated checks pass; in-game verification is still pending.

[What's new](CHANGELOG.md) · [Testing checklist](docs/TESTING.md) · [Compatibility and protection limits](docs/API_COMPATIBILITY.md) · [Build and upload instructions](docs/PACKAGING.md)
