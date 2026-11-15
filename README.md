# BagMarks

**BagMarks helps you keep track of what to keep, sell, and mail, right in your WoW Forever bags.** Mark items with a small icon, sell your marked junk, and get mail ready for your alts.

<img src="Media/BagMarks.png" alt="BagMarks: a leather satchel with a gold lock and red and blue marking tabs" width="144" height="144">

Made for **WoW: Forever 1.60.1**. Works with Blizzard's bags and bank. No other addons required.

## Choose what happens to your items

| Mark | Icon | What it's for |
| --- | --- | --- |
| Normal | None | Leave the item unmarked. |
| Locked | Gold padlock | Add extra protection for items you want to keep. |
| Junk | Red trash can | Set the item aside to sell at a merchant. |
| Mail | Blue envelope | Set the item aside to mail to another character. |

Hover over a marked item to see its mark in the tooltip. Locked items are always left out of BagMarks' selling and mail helpers, but the lock cannot prevent every accidental action. See the notes below.

## Installation

1. Download and extract the BagMarks ZIP.
2. Put the **BagMarks** folder inside your WoW Forever installation's `Interface/AddOns` folder.
3. Restart the game and enable **BagMarks** in the character selection screen's AddOns list.

Updating? Replace the old addon folder with the new one and restart the game. Your saved settings and item marks are kept.

## Mark your first item

Hold **Alt** and **right-click** an item in your bags or bank. Choose **Lock Item**, **Mark as Junk**, **Mark for Mail**, or **Clear Mark**. The icon changes straight away.

Prefer a different shortcut? Open `/bm` and select **Marking**. You can choose Alt, Ctrl, Shift, combinations of those keys, and any of the five supported mouse buttons, including your mouse's side buttons.

For Diablo-style marking, choose **Cycle marks**. Each marking click moves through:

**Normal → Junk → Mail → Locked → Normal**

Marking lots of items? Right-click the minimap button or type `/bm mode` to turn on **Item Marking Mode**. You can then use your chosen mouse button without holding a key. Turn the mode off when you're finished.

To avoid conflicts with other addons, choose **Marking Mode only** for the modifier setting. Your normal clicks stay unchanged until you turn the mode on. Choosing **None** instead makes your selected mouse button mark items all the time, outside combat.

## Sell your marked junk

Visit a merchant and click **Sell Marked Junk** below the merchant window. Check the list and estimated value, then confirm.

Only items you marked as Junk are sold, up to **12 stacks at a time**. Locked and Mail items stay in your bags. Items that cannot be sold safely are skipped.

## Get mail ready for your alts

Enter your **Default recipient** under `/bm` → **General**. With autofill enabled, that name fills an empty recipient field when you open Send Mail and after a successful send. Replies, existing names, and changes you make yourself are left alone.

At a mailbox, open **Send Mail** and click **Attach Marked Items**. BagMarks fills the available attachment slots with eligible Mail items. Check the recipient and attachments, then click **Send** yourself. BagMarks never sends mail automatically.

Bound items, including account-bound items, are left for you to handle manually. Items you don't send keep their marks, including attachments you remove.

## Make it your own

Type `/bm` or left-click the minimap button to open settings. You can also find BagMarks in Blizzard's AddOns settings and AddOns menu.

- **General:** turn BagMarks on or off, show or hide its minimap button, and set up mail autofill.
- **Marking:** choose your click controls, switch between the menu and cycling, and assign a shortcut to toggle Item Marking Mode.
- **Appearance:** show or hide item icons and tooltip labels, and pick **Classic**, **Minimal**, or **Colorful** icons. Changes apply immediately, with no reload needed.

To assign a keyboard shortcut, click **Set Key** and press your preferred key or combination. BagMarks won't overwrite an existing shortcut. **Clear** removes the binding; **Restore** brings back your previous binding from this session. Escape cancels key selection.

Drag the minimap button to move it. A blue indicator shows when marking mode is on. If Ellesmere or another addon collects your minimap buttons into a menu, look for BagMarks there and use that addon's controls to move it.

## A few things to know

- **A lock is extra protection, not a guarantee.** BagMarks helps block accidental bag clicks when selling, mailing, or targeting items with spells. It cannot stop every deletion or action made through macros or other addons. An item already on your cursor can bypass that protection. Clear its mark before intentionally enchanting or otherwise using a Locked item when a click is blocked.
- **Marking pauses during combat.** Item icons, protection, and the selling/mail helpers pause too. Marking mode turns off, but you can still open settings.
- **Marks belong to individual items.** Locking one copy doesn't lock every identical item. Check your marks after splitting or combining stacks: a new split stack starts unmarked, and a changed stack may ask you to choose its mark again before selling or mailing it.
- **Your choices are remembered.** Settings are shared across your characters; item marks are saved separately for each character.

## Commands

| Command | Action |
| --- | --- |
| `/bm` or `/bagmarks` | Toggle settings |
| `/bm mode` | Toggle Item Marking Mode |
| `/bm minimap` | Show or hide the minimap button |
| `/bm theme` | Cycle themes |
| `/bm reset` | Reset settings after confirmation; keep item marks and keyboard shortcuts |
| `/bm help` | Show the command list |

## More information

Automated checks have passed, but in-game compatibility still needs verification, including with Ellesmere. See the [testing checklist](docs/TESTING.md) for details.

[What's new](CHANGELOG.md) · [Technical notes and protection limits](docs/API_COMPATIBILITY.md)
