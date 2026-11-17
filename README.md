# BagMarks

Mark what you want to keep, sell, or mail, right in your WoW Forever bags.

<img src="https://raw.githubusercontent.com/Landmine-1252/bagmarks/refs/heads/main/Media/BagMarks.png" alt="BagMarks: a leather satchel with a gold lock and red and blue marking tabs" width="144" height="144">

Works with Blizzard bags and banks, plus EllesmereUI Bags.

## Mark your items

Open your bags, hold **Ctrl + Shift**, and **Right Click** an item to choose a mark:

| Mark | Icon | Purpose |
| --- | --- | --- |
| Locked | Gold padlock | Help protect the item from loss |
| Junk | Red trash can | Set aside for selling |
| Mail | Blue envelope | Set aside for mailing |
| Clear Mark | None | Remove the mark |

![BagMarks inventory icons showing Mail, Junk, Locked, and an unmarked item](https://raw.githubusercontent.com/Landmine-1252/bagmarks/refs/heads/main/Media/ItemMarks.png)

From left to right: **Mail**, **Junk**, **Locked**, and **Normal** (unmarked), using the Colorful theme.

The menu checks your current mark. Repeat the shortcut to change or clear it. Identical copies keep separate marks.

To mark future copies automatically, enable **General → Remember Mail and Junk by item type**. It starts off. Mark a **Light Feather** for Mail once and the next feathers you pick up on that character get the Mail mark, including feathers added to an existing stack. Junk works the same way. Each character has its own rules. If your blacksmith marks Linen Cloth for Mail, your tailor can collect that cloth and keep it for crafting.

While remembering is on, choosing Mail or Junk changes the rule for future copies. **Clear Mark** forgets that item type. **Locked** protects just the selected stack. Turning remembering off pauses the rules and keeps your existing marks.

## Configure BagMarks

Type **`/bm`** or **`/bagmarks`**, or **Left Click** the minimap button, to open settings.

| Tab | What you can change |
| --- | --- |
| **General** | Enable BagMarks, show the minimap button, remember item types, and configure junk sales and mail drafts |
| **Marking** | Choose mouse controls, a key to cycle the hovered item, and a key to toggle Item Marking Mode |
| **Appearance** | Choose small or full-size marks, toggle icons and tooltip labels, and preview three icon themes |

The minimap button, icons, and tooltip labels start on, with **Colorful** selected. Theme and visibility changes apply immediately. **Left-drag** the minimap button to move it.

**Larger marks:** Choose **Appearance → Mark size → Full item icon** to fill each marked item's icon square with a translucent symbol. The item artwork remains visible underneath. **Small corner** is the default. Size changes made during combat apply when combat ends.

**Marking controls:** The default is **Ctrl + Shift + Right Click**. Change the modifier combination and mouse button in **Marking** to suit your setup. **None** needs no modifier; **Marking Mode only** enables marking only while the mode is on.

**Upgrading?** Your saved shortcut is kept. To switch to the new default, select **Marking → Modifier keys → Ctrl + Shift** and **Mouse button → Right Click**.

**Cycle marks:** Set **Marking → Click action → Cycle marks** to rotate **Normal → Locked → Junk → Mail → Normal** with each marking click. An unmarked item locks first.

**Hover and press a key:** Under **Marking → Keyboard shortcut**, select **Cycle hovered item**, click **Set Key**, and press an unused key or combination. Then point at an item and press that key to cycle its mark. This works with Item Marking Mode off. Combined or changed stacks ask you to choose a stack or mark.

Both **Cycle hovered item** and **Toggle marking mode** start **unbound**. Select either to set its key. Escape cancels capture, **Clear** removes that binding, and **Restore** undoes its last change this session. Existing shortcuts are never replaced. To use **Space**, first move Jump to another key in WoW's Key Bindings. The assigned hover key is reserved for BagMarks even away from items.

## Mark several items quickly

**Right Click** the minimap button, use **`/bm mode`**, or use the settings footer to toggle Item Marking Mode. It uses your selected mouse button without a modifier: plain right-click by default.

The footer shows **ON/OFF** and explains your current controls. A blue minimap indicator and a small **Marking** badge beside the pointer over bag items show when the mode is active. Turn it off to restore your usual clicks. It starts off and switches off on login, `/reload`, or entering combat.

## Sell marked junk

Visit a merchant, click **Sell Marked Junk**, and confirm the preview of up to 12 stacks. Only eligible items marked **Junk** are sold.

Enable **General → Automatically sell marked junk** to sell without confirmation from your next merchant visit. This starts **off**. Click **Stop Selling** to keep remaining items. Locked, Mail, and unmarked items are excluded.

You can leave automatic selling off and keep using your usual junk seller. BagMarks respects WoW's bag sale exclusions, reserves Mail and Locked stacks at merchants, and skips Junk stacks another seller has already taken. If a seller bypasses a hold, BagMarks tries to buy back that exact stack once while the merchant is open. A full buyback list or a seller that takes it again can still require manual recovery.

## Mail marked items

1. Mark the stacks you want to mail, then open **Send Mail** at the mailbox. BagMarks attaches eligible stacks to free slots. The first attachment supplies a blank subject, including the quantity for a stack.
2. Enter the recipient, or set **General → This character's recipient** using `Character` or `Character-Realm`. With **Automatically fill mail recipient** enabled, each fresh draft starts with this sender's saved name. Type over it to choose someone else.
3. Review the recipient, subject and attachments, then click Blizzard's **Send**. Use **Attach Marked Items** for another batch.

**Automatically attach marked items** starts on. Turn it off in **General** to use the button manually. BagMarks skips replies when attaching automatically, preserves custom subjects, and keeps the marks on unsent items.

If you had a shared default recipient in an older version, open **General** on the character that should use it. Hover over **Use previous recipient** to see the name, then click to save it for that character.

## A few things to know

- **Locked items:** Equip, use, sort, and move them normally. Consumables can still be consumed. Clear the mark before selling, mailing, trading, or deleting them. Close merchant, mail, trade, and auction windows and finish item targeting before ordinary use. Some actions and addons bypass protection; see the [protection limits](docs/API_COMPATIBILITY.md).
- Each character keeps its own item marks, remembered item types and default mail recipient. The switches for remembering, autofill and automatic attachment apply across the account.
- **Combat:** Marking, keybinding changes, and sale/mail helpers pause. Settings remain accessible. Existing icons stay visible when readable; new slots may wait until combat ends.
- **EllesmereUI Bags:** Keep the icon column visible in List view. Combined stacks let you choose which individual stack to mark.

## Commands

| Command | Action |
| --- | --- |
| `/bm` or `/bagmarks` | Open or close settings |
| `/bm mode` | Toggle Item Marking Mode |
| `/bm minimap` | Show or hide the minimap button |
| `/bm theme` | Cycle icon themes |
| `/bm reset` | Restore default preferences and keep marks, remembered item types and keybindings |
| `/bm debug` or `/bmcheck` | Open a copyable status report |
| `/bm help` | Show the command list |

## Help improve BagMarks

[Browse the code](https://github.com/Landmine-1252/bagmarks), [report a bug or suggest a feature](https://github.com/Landmine-1252/bagmarks/issues), or fork the repository and [open a pull request](https://github.com/Landmine-1252/bagmarks/pulls).

When reporting an issue, run **`/bm debug`** (or **`/bmcheck`**), click **Select all**, and press **Ctrl+C**. Include the report with your bag addon, what you tried, and what happened.

[What's new](CHANGELOG.md) · [MIT license](LICENSE)

**Installing or updating?** Get the addon ZIP from [GitHub Releases](https://github.com/Landmine-1252/bagmarks/releases), extract its **BagMarks** folder into `Interface/AddOns`, and restart WoW. Replace the old folder to update; settings and marks are kept.
