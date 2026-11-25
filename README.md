# BagMarks

Mark what you want to keep, sell, mail, or disenchant, right in your WoW Forever bags.

<img src="https://raw.githubusercontent.com/Landmine-1252/bagmarks/refs/heads/main/Media/BagMarks.png" alt="BagMarks: a leather satchel with a gold lock and red and blue marking tabs" width="144" height="144">

Works with Blizzard bags and banks, plus EllesmereUI Bags.

## Mark your items

Open your bags, hold **Ctrl + Shift**, and **Right Click** an item to choose a mark:

| Mark | Icon | Purpose |
| --- | --- | --- |
| Locked | Gold padlock | Help protect the item from loss |
| Junk | Red trash can | Set aside for selling |
| Mail | Blue envelope | Set aside for mailing |
| Disenchant | Violet crystal shard | Set aside for your disenchanter |
| Clear Mark | None | Remove the mark |

![BagMarks inventory icons showing Mail, Junk, Locked, and an unmarked item](https://raw.githubusercontent.com/Landmine-1252/bagmarks/refs/heads/main/Media/ItemMarks.png)

From left to right: **Mail**, **Junk**, **Locked**, and **Normal** (unmarked), using the Colorful theme.

The menu checks your current mark. Repeat the shortcut to change or clear it. Identical copies keep separate marks.

To mark future copies automatically, enable **General → Remember Mail, Junk and Disenchant by item type**. It starts off. Mark a **Light Feather** for Mail once and the next feathers you pick up on that character get the Mail mark, including feathers added to an existing stack. Junk and Disenchant work the same way. Each character has its own rules. If your blacksmith marks Linen Cloth for Mail, your tailor can collect that cloth and keep it for crafting.

While remembering is on, choosing Mail, Junk or Disenchant changes the rule for future copies. If the item has a remembered mark, **Clear mark and forget future mark** clears the selected stack and stops applying that mark to future copies on this character. **Locked** protects just the selected stack. Turning remembering off pauses the rules and keeps your existing marks.

## Configure BagMarks

Type **`/bm`** or **`/bagmarks`**, or **Left Click** the minimap button, to open settings.

| Sidebar page | What you can change |
| --- | --- |
| **General** | See your current marking shortcut, enable BagMarks, show the minimap button, remember item types, and configure junk sales |
| **Marking** | Choose mouse controls, a key to cycle the hovered item, and a key to toggle Item Marking Mode |
| **Mail** | Choose your disenchanter, material and recipe recipients, and bank alt. Control draft preparation. |
| **Item rules** | Search by item name, ID, mark or recipient. Filter by future mark and mail destination while adding, editing or removing rules. |
| **Appearance** | Preview twelve themes on inventory artwork, choose a mark size, and toggle bag icons and tooltip labels |

The minimap button, icons, and tooltip labels start on, with **Colorful** selected. Visibility changes apply immediately. **Left-drag** the minimap button to move it.

In **Appearance → Mark size**, choose **Small corner** for the default badge, **Medium corner** for a larger solid mark in the top right, or **Full item icon** for a translucent mark over the artwork. Medium scales to the icon column in Ellesmere list view. The preview updates immediately. Size changes in your bags and bank take effect after combat.

**Border** draws a colored outline around the full item icon and leaves the artwork visible in the center. Switching away restores your chosen mark size. **Circles** draws a plain dot at your chosen size. Both use gold for Locked, red for Junk, blue for Mail and violet for Disenchant.

Choose **Appearance → Letters** for a blue **M** for Mail, a red **J** for Junk, a violet **D** for Disenchant and a gold **L** for Locked. Each letter has a dark outline to keep it readable over item artwork.

**Marking controls:** The default is **Ctrl + Shift + Right Click**. Change the modifier combination and mouse button in **Marking** to suit your setup. **None** needs no modifier; **Marking Mode only** enables marking only while the mode is on.

**Upgrading?** Your saved shortcut is kept. To switch to the new default, select **Marking → Modifier keys → Ctrl + Shift** and **Mouse button → Right Click**.

Set **Marking → Click action → Cycle marks** to rotate **Normal → Locked → Junk → Mail → Disenchant → Normal** with each marking click. An unmarked item locks first.

**Hover and press a key:** Under **Marking → Keyboard shortcut**, select **Cycle hovered item**, click **Set Key**, and press an unused key or combination. Then point at an item and press that key to cycle its mark. This works with Item Marking Mode off. Combined or changed stacks ask you to choose a stack or mark.

Both **Cycle hovered item** and **Toggle marking mode** start **unbound**. Select either to set its key. Escape cancels capture, **Clear** removes that binding, and **Restore** undoes its last change this session. Existing shortcuts are never replaced. To use **Space**, first move Jump to another key in WoW's Key Bindings. The assigned hover key is reserved for BagMarks even away from items.

## Mark several items quickly

**Right Click** the minimap button, use **`/bm mode`**, or use the settings footer to toggle Item Marking Mode. It uses your selected mouse button without a modifier: plain right-click by default.

The footer shows **ON/OFF** and explains your current controls. A blue minimap indicator and a small **Marking** badge beside the pointer over bag items show when the mode is active. Turn it off to restore your usual clicks. It starts off and switches off on login, `/reload`, or entering combat.

## Sell marked junk

Visit a merchant, click **Sell Marked Junk**, and confirm the preview of up to 12 stacks. Only eligible items marked **Junk** are sold.

Enable **General → Automatically sell marked junk** to sell without confirmation from your next merchant visit. This starts **off**. Click **Stop Selling** to keep remaining items.

You can leave automatic selling off and keep using your usual junk seller. BagMarks respects WoW's bag sale exclusions, reserves Locked, Mail and Disenchant stacks at merchants, and skips Junk stacks another seller has already taken. If a seller bypasses a hold, BagMarks tries to buy back that exact stack once while the merchant is open. A full buyback list or a seller that takes it again can still require manual recovery.

## Mail marked items

Open **`/bm` → Mail**. Choose an alt from the list or type the player's full character name, such as **Landmine Ill**. Settings, tooltips and the mailbox show that name on every character. Existing saved recipients work automatically.

| Setting | What goes there |
| --- | --- |
| **Account default** | Set a recipient such as your bank alt once for all your characters. It receives Mail-marked items with no item or category recipient. |
| **Character override** | Set a different default recipient for mail from the character you are playing. Leave this blank to use the account default. |
| **Cloth** | Cloth materials such as Linen Cloth and bolts |
| **Cooking** | Meat, fish, eggs, spices and other meal or drink ingredients. Cooking recipes also go here by default. |
| **Herbs** | Herbalism materials such as Peacebloom |
| **Leather and hides** | Leatherworking materials such as Light Leather and Light Hide |
| **Ore, bars and stone** | Mining materials such as Copper Ore, Copper Bars and Rough Stone |
| **Disenchanter** | Items you mark **Disenchant** use this account-wide recipient, even when the item has a separate Mail rule. Leave it blank or choose your current character to keep those stacks in your bags. |
| **Mage scrolls** | Untranslated scrolls a mage can decipher with Comprehension. Ordinary power-up scrolls follow your default. |
| **Profession recipes** | Set a default recipient for recipe items or choose a different character for each profession. |

For example, set **Account default** to **Oak** and your priest's **Character override** to **Ash**. Mail-marked gear with no matching rule goes to Ash from your priest and to Oak from your other characters. Clearing the priest's override sends that gear to Oak again.

If **Cloth** goes to **Landmine Tailor**, a Mail-marked **Pattern: Red Linen Robe** follows it. To send the pattern elsewhere, open **Profession recipes** and enter a **Tailoring** recipient. A profession override takes priority, followed by **Recipe default**, then a related material recipient, then **Character override**, then **Account default**. Each blank profession field previews its inherited recipient when a recipe or material destination is available.

Cooking recognizes ingredients even when they are filed as consumables, such as Raw Winter Squid. For shared ingredients, a configured material recipient takes priority. For example, Peacebloom used in tea still goes to your Herbs recipient. Finished meals follow your usual fallback unless they are ingredients themselves.

For an exception, open **Item rules → Add rule**, enter an item ID or paste an item link, and set a **Mail recipient**. You can also open an item's editor from its bag menu. This destination takes priority over its category for every Mail-marked copy on your account.

To review mail automations, select **Mail** or **Disenchant** under **All future marks**, then choose a character under **All mail recipients**. A Disenchant rule shows the disenchanter. Other rows show the destination for copies marked Mail. Choose **Use mail settings** for inherited destinations or **Item-specific recipient** for per-item overrides. If automatic marks are paused, these recipients still apply to stacks you mark by hand. **Clear filters** restores the full list.

Choose **Edit** on any row to change its Mail recipient or its **Future copies** mark. For example, give Light Feather a Mail mark on your priest and set its recipient to your mage. Future marks apply when **Remember Mail, Junk and Disenchant by item type** is on for the account. To keep just one part of a rule, clear the other field and save. **Remove rule** clears both settings for that item. Stacks already in your bags retain their marks.

Mark the stacks you want to mail. Hover over a marked stack to see its destination. If you mark Linen Cloth and a cloth robe, the cloth goes to your cloth recipient and the robe follows your default unless it has its own item rule. Items addressed to your current character or without a destination stay marked in your bags.

Open **Send Mail**. BagMarks fills the recipient, attaches that character's eligible stacks up to the available slots, and fills a blank subject from the first attachment. Review the draft and click **Send**. After a successful send, BagMarks can prepare the next letter. Sending partway through a batch or removing an attachment pauses automatic batching.

Turn off **Automatically attach marked items** to start each batch with **Attach Marked Items**. With **Automatically fill the To field** off, enter the recipient and click **Attach Marked Items**. The button uses that address to select matching stacks. BagMarks skips replies and preserves custom subjects.

If you used a shared recipient in an older version, **Use previous recipient** in the Mail tab imports it into **Character override** for the character you are playing.

## A few things to know

- **Locked items:** Equip, use, sort, and move them normally. Consumables can still be consumed. Clear the mark before selling, mailing, trading, or deleting them. Close merchant, mail, trade, and auction windows and finish item targeting before ordinary use. Some actions and addons bypass protection; see the [protection limits](docs/API_COMPATIBILITY.md).
- Each character keeps its own item marks, remembered item types and character override. Category recipients, exact item recipients, the account default and automation preferences apply across the account.
- Your configured mouse marking shortcut works on readable stacks in combat. If you choose **Shift + Left Click**, it uses your selected mark menu or cycle action. Keybinding changes, hover-key marking and sale/mail helpers resume after combat.
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
