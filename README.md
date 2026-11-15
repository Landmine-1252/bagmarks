# BagMarks

Mark what you want to keep, sell, or mail, right in your WoW Forever bags.

<img src="https://raw.githubusercontent.com/Landmine-1252/bagmarks/refs/heads/main/Media/BagMarks.png" alt="BagMarks: a leather satchel with a gold lock and red and blue marking tabs" width="144" height="144">

**Version 1.0.0** · **WoW: Forever 1.60.1**

Small icons, familiar controls, and no extra inventory window. Supports Blizzard's bags and bank, plus EllesmereUI Bags. No other addons required.

Version 1.0.0 is being prepared for its first public release. CurseForge approval is still pending.

## Install

1. Extract **BagMarks-1.0.0.zip** into your WoW Forever `Interface/AddOns` folder.
2. Check that the file is at `Interface/AddOns/BagMarks/BagMarks.toc`, without an extra folder around it.
3. Restart the game, enable **BagMarks** in the AddOns list, and type `/bm` to open settings.

Updating? Replace the existing **BagMarks** folder and restart the game. Your saved settings and item marks are kept.

Use the packaged addon ZIP for installation. GitHub's **Download ZIP** contains the source project for contributors.

## Mark an item

Hold **Alt** and **right-click** an item in your bags or bank. Choose a mark, or select **Clear Mark** to return it to Normal.

| Mark | Icon | What it does |
| --- | --- | --- |
| Normal | None | Leaves the item unmarked. |
| Locked | Gold padlock | Helps protect the item from loss. Reusable items can still be used. |
| Junk | Red trash can | Sets the item aside for selling. |
| Mail | Blue envelope | Sets the item aside for mailing. |

The icon updates immediately, and hovering over the item shows its mark. Each mark belongs to the individual item or stack you select. Other copies keep their own marks.

## Sell your marked junk

**Automatically:** Open `/bm` → **General** and enable **Automatically sell marked junk**. Starting with your next merchant visit, BagMarks sells all eligible marked Junk without asking for confirmation each time. This option is off by default.

**Manually:** Click **Sell Marked Junk** below the merchant window, review the list and estimated value, then confirm. Each manual preview includes up to **12 stacks**.

During an automatic sale, click **Stop Selling** to keep the remaining items. Closing the merchant, entering combat, or turning the option off also stops further sales. Items marked after the sale starts wait for your next visit or a manual sale.

Only eligible items explicitly marked Junk are sold. Locked, Mail, and unmarked items are excluded, including unmarked gray items. Quest, refundable, busy, unsellable, and uncertain items are skipped.

## Get mail ready for your alts

Set a **Default recipient** in `/bm` → **General**. With autofill enabled, BagMarks fills an empty recipient field when you open Send Mail and after a successful send. Replies, existing recipients, and your own edits are preserved.

At a mailbox, open **Send Mail** and click **Attach Marked Items**. BagMarks attaches eligible Mail items to the available slots. **Check the recipient and attachments, then click Send yourself.** BagMarks never sends mail automatically.

Bound items, including account-bound items, are skipped. Items you do not send keep their marks, including attachments you remove.

## Protect the items you want to keep

**Reusable items can stay Locked while you use them.** This lets you keep items such as your sleeping bag protected without clearing their mark every time. Close merchant, mail, trade, bank, and auction windows and finish any item-targeting spell before using one.

**Clear a Locked mark before moving or transferring the item.** Consumables and items the game cannot identify as reusable keep the stricter lock, including blocking use. Locked items may look dimmed while the game holds them in place.

BagMarks adds safeguards for cursor deletion, outgoing trades, and mail attachments. If a Locked item is sold despite its hold, BagMarks attempts to buy it back while the merchant is open. Recovery uses the buyback price, needs enough money and bag space, and can fail.

Some game actions and other addons can bypass protection. BagMarks cannot recover an item after it has been destroyed, sent, or successfully traded. See the [protection limits](docs/API_COMPATIBILITY.md) for details.

## Make it your own

Open settings with `/bm`, `/bagmarks`, or a left click on the minimap button. BagMarks is also available through Blizzard's AddOns settings and AddOns menu.

- **General:** enable BagMarks, show or hide the minimap button, turn on automatic junk selling, and set up mail autofill.
- **Marking:** choose your modifier keys and mouse button, switch between the menu and cycling, and bind a key to toggle Item Marking Mode.
- **Appearance:** show or hide icons and tooltip labels, and choose **Classic**, **Minimal**, or **Colorful** icons. Theme changes apply immediately.

For Diablo-style marking, select **Cycle marks**. Each marking click rotates through **Normal → Junk → Mail → Locked → Normal**.

For a shortcut without held keys, right-click the minimap button or type `/bm mode`. While **Item Marking Mode** is on, your chosen mouse button opens the menu or cycles marks without modifiers. A blue minimap indicator shows when the mode is active.

To avoid shortcut conflicts, choose another modifier/button combination, or select **Marking Mode only**. The **None** modifier captures your chosen mouse button all the time outside combat, so use that option only if you want it.

To assign the mode shortcut, click **Set Key** and press your preferred key combination. Existing bindings are not overwritten. **Clear** removes the binding; **Restore** restores the binding from before your last change in this session. Escape cancels key capture.

Drag the minimap button to move it. If a minimap collector places BagMarks in a menu, use that addon's controls to arrange it.

## Using EllesmereUI Bags

Marking works on live bag and bank items. When a button combines several stacks, the marking menu lets you choose the individual stack. Mixed groups explain their marks in the tooltip; a shared icon appears when all represented stacks have the same mark.

Keep the icon column visible in List view. If Ellesmere's Alt quick actions capture your shortcut, choose another modifier or use Item Marking Mode without Alt.

## A few things to know

- Settings are shared across your characters. Item marks are saved separately for each character and survive reloads and relogging.
- Check your marks after splitting or merging stacks. A new split stack starts unmarked, and a changed stack may need its mark reapplied before selling or mailing.
- Marking, item icons, bag click guards, and sale/mail helpers pause during combat. Item holds and cursor/transfer safeguards continue where the game allows them. You can still open settings.
- Disabling BagMarks releases its own holds and stops its protection. Saved marks apply again when you enable it.

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

When reporting a problem, include your BagMarks version, bag addon, and steps to reproduce it. Find the installed version in the settings title or by hovering over the minimap button.

BagMarks uses the [MIT License](LICENSE). Automated checks pass; in-game behavior, visuals, and addon compatibility still need verification.

[What's new](CHANGELOG.md) · [Testing checklist](docs/TESTING.md) · [Compatibility and protection limits](docs/API_COMPATIBILITY.md) · [Build and upload instructions](docs/PACKAGING.md)
