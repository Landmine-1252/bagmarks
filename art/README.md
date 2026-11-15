# BagMarks artwork

The logo is an illustrated leather satchel. Its gold lock, red tab, and blue tab echo the Locked, Junk, and Mail marks. The compact silhouette and broad painted shapes are intended to stay recognizable on a minimap.

Created with the built-in image generation tool using the imagegen skill. This is generated artwork in a hand-painted style, not a claim of a human-painted commission. No existing game artwork was supplied as a reference.

## Files

- [BagMarks-source.png](BagMarks-source.png): the original 1254 x 1254 transparent PNG, preserved unchanged.
- [BagMarks.png](../Media/BagMarks.png): a 256 x 256 transparent PNG for the README and addon listings.
- [BagMarks.tga](../Media/BagMarks.tga): a 64 x 64 uncompressed, 32-bit TGA for WoW's minimap and AddOns entry.

The original source and this production note stay in the repository. The installable addon includes both small exports. Its separate item-state pictograms still use the selected icon theme; the logo keeps its own colors.

To reproduce only the size and format exports, install Pillow and run:

```sh
python3 tools/export_logo.py
```

Exports preserve transparency and do not alter the illustration. Small-size readability has been inspected outside the game; client rendering still needs the checks in [TESTING.md](../docs/TESTING.md).

## Generation prompt

The final prompt used with the built-in tool is recorded verbatim below. The generator returned a 1254 x 1254 source despite the requested 1024 x 1024 canvas. The shipped TGA uses a supported power-of-two size.

```text
Use case: logo-brand
Asset type: the original BagMarks addon icon and logo, used in a World of Warcraft: Forever minimap button, AddOns list, and README.
Primary request: design a distinctive, understated old-school fantasy inventory satchel icon with the character of a carefully painted game item. It must feel specific to an addon for marking what to keep, sell, and mail, and must remain recognizable when reduced to 18 to 32 pixels.
Scene/backdrop: genuinely transparent background. One isolated object only.
Subject: a squat, slightly lopsided adventurer's brown leather satchel, seen mostly from the front with a hint of one side. A broad, angular folded flap has one large simple gold-brass padlock clasp, with a clear dark keyhole. Two short sturdy cloth marking tabs, one muted brick red and one rich mail blue, protrude from the same upper side seam at slightly different lengths. Those two tabs and the gold clasp are the defining BagMarks signature. No long shoulder strap.
Style/medium: original 2D hand-painted RPG inventory art, confident dark ink contours of slightly varied thickness, economical broad brush planes, a few deliberate worn edge highlights and uneven stitches. Handmade and useful rather than ornate. The bag silhouette, flap, clasp and two tabs should carry the whole design. Crisp clean outer silhouette, no noisy texture.
Composition/framing: square 1024 by 1024 canvas, single large centered compact silhouette occupying about 85 percent of the canvas, all details fully inside the canvas with modest transparent padding. No frame or surrounding badge.
Lighting/mood: warm modest painted highlights from upper left; deep chocolate shadows; readable large light-dark shapes, matte surfaces.
Color palette: warm chestnut leather, near-black brown outlines, antique gold clasp, brick red tab, saturated medium blue tab. High enough contrast to read against dark game UI.
Text: none.
Constraints: no words, letters, initials or watermark. Original artwork, do not reproduce an existing game's bag asset. No realistic 3D rendering, plastic shine, airbrushed gradients, glowing edges, particles, sparkles, magic aura, ornate filigree, shields, crests, esports logo styling, circular badge, app tile, background shadow or floating extra symbols. Preserve actual alpha transparency.
```

