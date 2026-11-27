# Runtime themes

A theme is a small JSON file that changes how Downtify looks: its colors, card shapes, spacing, fonts, the order of Home, and whether each screen uses the standard or the redesigned layout. Themes are data only. They can't run code, and they never contain account or server information.

- [Choosing, importing and exporting](#choosing-importing-and-exporting)
- [Making a theme](#making-a-theme)
- [File rules](#file-rules)
- [Colors](#colors)
- [Shape and spacing](#shape-and-spacing)
- [Layout and navigation](#layout-and-navigation)
- [Screen styles (`componentStyles`)](#screen-styles-componentstyles)
- [Home sections](#home-sections)
- [Search and Discover tile colors](#search-and-discover-tile-colors)
- [Equalizer colors](#equalizer-colors)
- [What each feature uses](#what-each-feature-uses)
- [Light, dark and OLED](#light-dark-and-oled)
- [Bundled themes](#bundled-themes)
- [Testing a theme](#testing-a-theme)
- [Troubleshooting](#troubleshooting)
- [Example files](#example-files)

## Choosing, importing and exporting

Settings → Appearance has two separate choices:

- **Color mode**: System, Light, Dark or OLED black. This decides which half of each light/dark color pair is used.
- **Theme**: **Original**, **Redesign**, or the theme you imported.

Below them:

- **Import theme…** opens a JSON file from Files. A valid theme is applied immediately and appears in the Theme picker. Importing another file replaces the saved imported theme. An invalid file shows an error and leaves the current theme in place.
- **Export selected theme…** saves the current theme as JSON, a good starting point for your own.

The selected theme stays selected after the app restarts.

## Making a theme

1. Select the theme closest to what you want (**Original** or **Redesign**) and choose **Export selected theme…**.
2. Edit the file. Change `name` so you can tell it apart in the picker.
3. Choose **Import theme…** and pick the edited file.

The smallest valid theme sets only the required fields; everything else falls back to the standard interface. See [`theme-examples/minimal.json`](theme-examples/minimal.json):

```json
{
  "version": 1,
  "name": "Minimal",
  "accentLight": "7B1FA2",
  "accentDark": "CE93D8",
  "backgroundLight": "FAF7FC",
  "backgroundDark": "121016",
  "surfaceLight": "FFFFFF",
  "surfaceDark": "1F1B24",
  "cardCornerRadius": 14,
  "cardPadding": 16,
  "rowSpacing": 12,
  "albumGridMinimum": 142,
  "homeSections": ["recent", "new", "favorites"],
  "shelfLayout": "grid"
}
```

[`theme-examples/full.json`](theme-examples/full.json) sets every field.

## File rules

A file is rejected, and the current theme kept, if it breaks any of these:

| Rule | Detail |
| --- | --- |
| Format | A JSON object, at most 16 KB. Fields not listed in this guide are ignored. |
| `version` | Must be `1`. |
| `name` | Not blank, at most 80 characters. Shown in the Theme picker. |
| Colors | Exactly six hexadecimal digits, RGB, **without** `#`: `"1DB954"`, not `"#1DB954"` or `"1DB"`. Upper or lower case. |
| Color pairs | Optional colors come in `…Light`/`…Dark` pairs. Set both or neither. |
| Numbers | Within the ranges in [Shape and spacing](#shape-and-spacing). |
| Choices | Only the values listed for each field. |
| `homeSections` | See [Home sections](#home-sections). |

## Colors

Each color has a light and a dark value; iOS picks one according to Color mode.

| Token | Fields | Required | When omitted | Used for |
| --- | --- | --- | --- | --- |
| Accent | `accentLight`, `accentDark` | Yes | — | Tint for buttons, links and icons; the current song in lists; selected presets; the Autoplay icon; the Downloaded card icon. |
| Background | `backgroundLight`, `backgroundDark` | Yes | — | Behind every screen. Navigation bars match it. |
| Surface | `surfaceLight`, `surfaceDark` | Yes | — | Cards and grouped rows on the background: Home cards, the queue, Up Next, the Equalizer curve, Downloads sections. With `surfaceStyle: "system"` these values are ignored (see below). |
| Elevated | `elevatedLight`, `elevatedDark` | No | Surface | One step above surface: chips, quick-access tiles, search fields, the Equalizer drag value, the Autoplay icon circle, the redesigned player background without artwork. |
| Brand | `brandLight`, `brandDark` | No | Accent | Filled controls: play buttons, selected chips, switches (Autoplay, Equalizer), the Crossfade slider, Equalizer handles. |
| On brand | `onBrandLight`, `onBrandDark` | No | Standard on-accent color | Text and icons drawn on a brand fill, such as the play triangle. Pick a color with good contrast against brand. |

`surfaceStyle` controls where surface comes from:

| Value | Effect |
| --- | --- |
| `"custom"` or omitted | Uses `surfaceLight`/`surfaceDark`. |
| `"system"` | Uses iOS grouped-list colors, as the Original theme does. The surface fields must still be present and valid, but are not shown. |

Text colors are not themed: primary text follows iOS, and secondary text uses iOS's secondary label color, so text stays readable in both modes. Choose backgrounds and surfaces that suit dark text in light mode and light text in dark mode.

## Shape and spacing

| Field | Range | Used for |
| --- | --- | --- |
| `cardCornerRadius` | 0–40 points | Card corners: Home cards, the queue (redesigned queue style), Downloads sections, the Equalizer curve card, the Autoplay card. `0` gives square cards. |
| `cardPadding` | 4–32 points | Space inside those cards. |
| `rowSpacing` | 4–32 points | Gap between artwork and text in song and album rows. |
| `albumGridMinimum` | 100–240 points | Smallest width of an album or playlist tile in grids. Larger values give fewer, bigger tiles per row. |

## Layout and navigation

| Field | Values | Default | Effect |
| --- | --- | --- | --- |
| `shelfLayout` (required) | `"grid"`, `"list"`, `"carousel"` | — | How Home shelves (Jump back in, Recently added, Favorite playlists, Your artists) are laid out. `carousel` scrolls sideways. At accessibility text sizes every shelf uses the list. |
| `navigationStyle` | `"system"`, `"drawer"` | `system` | `system`: the iOS tab bar with every destination (extra ones under More). `drawer`: a custom bar with Home, Search and Your Library; Downloads, Discover, Podcasts, Pending actions and storage, Trash (administrators), Settings, Refresh library and Sign out move to a menu behind your avatar. |
| `headerStyle` | `"system"`, `"profile"` | `system` | `profile` uses a small inline title instead of the large iOS title. |
| `recentStyle` | `"shelf"`, `"tiles"` | `shelf` | Jump back in as a shelf, or as a two-column grid of compact tiles (up to eight; the rest follow as a shelf). Falls back to the shelf at accessibility text sizes. |
| `playerStyle` | `"standard"`, `"compact"` | `standard` | The mini player at the bottom: `compact` uses tighter corners. |
| `fontDesign` | `"system"`, `"rounded"`, `"serif"`, `"monospaced"` | `system` | Font family for the whole app. Text sizes still follow Dynamic Type. |

## Screen styles (`componentStyles`)

`componentStyles` picks the layout of individual screens. Each key is optional and is `"standard"` (default) or `"redesign"`:

| Key | `"redesign"` changes |
| --- | --- |
| `home` | Time-of-day greeting ("Good morning") as the Home title. |
| `library` | Filter chips instead of the segmented control, an **All** category, and its own remembered list/grid choice. Selected chip uses brand/on brand; others use elevated. |
| `search` | Full-width search field on elevated, Browse tiles, and category chips instead of the picker. |
| `collection` | Album, playlist and artist pages with a large header: artwork, title, byline and song count, over a gradient from the artwork's color (elevated when there's no artwork) into the background. |
| `downloads` | Left-aligned Downloads layout. |
| `player` | Now Playing with a background gradient from the artwork's color (elevated when there's no artwork), left-aligned title and artist, and larger artwork. Its play button is always white with a black icon; it isn't themed. |
| `settings` | Settings on the theme background instead of the iOS grouped background. |
| `connection` | Larger sign-in and server-connection logo. |
| `discover` | Discover sections as chips (brand when selected, elevated otherwise) instead of a segmented control. |
| `podcasts` | Podcasts on the theme background. |
| `queue` | Queue cards use `cardCornerRadius` instead of the standard radius. |

Example: the redesigned player and library with everything else standard:

```json
"componentStyles": { "player": "redesign", "library": "redesign" }
```

## Home sections

`homeSections` (required) lists Home's sections from top to bottom.

| Key | Required | Section |
| --- | --- | --- |
| `recent` | Yes | Jump back in: recent albums, artists and playlists (see `recentStyle`). |
| `new` | Yes | Recently added albums. |
| `favorites` | Yes | Favorite playlists. |
| `discover` | No | A card that opens Discover on For You. |
| `artists` | No | Your artists: up to 12 library artists, most songs first. Shown only with at least two artists. |
| `downloaded` | No | Downloaded to this device: song count and a play button. Shown only when songs are downloaded. |

Rules:

- `recent`, `new` and `favorites` must each appear once. The optional keys may each appear at most once. Leave one out to hide it.
- **A file that lists none of the optional keys** (for example one written before they existed, or the bundled Original theme) shows all three after its own sections, in the order `discover`, `artists`, `downloaded`.
- Sections with nothing to show are skipped automatically.

```json
"homeSections": ["recent", "discover", "new", "favorites", "downloaded"]
```

This shows Discover second, and hides Your artists.

## Search and Discover tile colors

`browseColors` optionally sets the color of individual Browse tiles on Search. Keys are the tile names; values are six-digit colors used in both light and dark mode. Tile text and icons are always white, so pick darker colors.

| Key | Default |
| --- | --- |
| `For You` | `203562` |
| `Charts` | `E33600` |
| `Finder` | `27866F` |
| `Similar` | `8863A8` |
| `Podcasts` | `006450` |
| `Downloads` | `B65B00` |

The Home **Discover card** uses the `For You` color, so it matches the For You tile.

## Equalizer colors

Optional pairs color Settings → Playback → Equalizer. Each falls back to a shared token:

| Fields | When omitted | Colors |
| --- | --- | --- |
| `equalizerAccentLight`, `equalizerAccentDark` | Accent | The curve, its fill, and the selected preset and checkmark. |
| `equalizerHandleLight`, `equalizerHandleDark` | Brand | The band handles. Each has a ring in the surface color, so a handle stays visible on a curve of the same color. |
| `equalizerGridLight`, `equalizerGridDark` | iOS secondary text | dB scale, guide lines, band labels, and the curve while the Equalizer is off. |

The on/off switch uses brand, the value shown while dragging uses elevated, and the curve card uses surface, `cardCornerRadius` and `cardPadding`.

## What each feature uses

| Feature | Tokens and fields |
| --- | --- |
| Equalizer | Brand (switch, handles), accent or `equalizerAccent` (curve, selection), `equalizerGrid`, elevated (drag value), surface + card shape. |
| Autoplay | Settings switch: brand. Now Playing → Up Next: accent icon. Play Queue: Autoplay card on surface + card shape, accent icon on elevated, brand switch. |
| Crossfade | Settings slider: brand. |
| Home: Discover card | `browseColors["For You"]` artwork, surface + card shape. |
| Home: Downloaded card | Accent icon, brand/on brand play button, surface + card shape. |
| Home: Your artists | `shelfLayout`. |
| Library chips, Discover chips, Search chips | Brand/on brand when selected, elevated otherwise. |
| Play buttons | Brand/on brand, except the redesigned Now Playing button (always white). |
| Now Playing and collection pages (redesigned) | Artwork tint, else elevated, fading into background. |

## Light, dark and OLED

- **Light** and **Dark** use the `…Light` and `…Dark` value of each pair. **System** follows the device.
- **OLED black** uses the dark values but always draws a pure black background and a near-black surface, whatever the theme says, to save power on OLED screens.
- A color used in only one mode (such as `browseColors`) looks the same in both.

## Bundled themes

| | Original | Redesign |
| --- | --- | --- |
| Accent | `17623E` / `72D9A0` | `14833B` / `1ED760` |
| Background | `F2F3F5` / `141618` | `FFFFFF` / `121212` |
| Surface | iOS grouped (`surfaceStyle: system`) | `F3F3F3` / `1E1E1E` |
| Elevated, brand, on brand | Defaults | `E8E8E8`/`2A2A2A`, `1DB954`, `000000` |
| Cards | Radius 20, padding 16 | Radius 8, padding 16 |
| Shelves | Grid | Carousel |
| Navigation | iOS tab bar, large titles | Drawer, inline profile header |
| Jump back in | Shelf | Tiles |
| Screens | All standard | All redesigned |
| Home | Recent, new, favorites, then discover, artists, downloaded | Recent, new, discover, favorites, artists, downloaded |

The bundled files are in [`themes/`](../themes). When a bundled theme is updated, a copy saved by an earlier build keeps its old values until it's selected again in Settings.

## Testing a theme

Now Playing adapts its placement to the available sheet size for every theme. Narrow windows stack
the artwork above the controls; sufficiently wide sheets put them side by side.
Accessibility text sizes use the stacked layout. The artwork is bounded by the available width,
so a theme does not need separate coordinates for each device.
On iPad, opening Now Playing in a sufficiently wide window shows it beside the main app. In a
narrow window it opens as a sheet, as it does on iPhone.

On a device, import the file from Files.

In the iOS Simulator you can apply a theme without the file picker by writing it straight into the app's saved settings, then relaunching:

```bash
xcrun simctl spawn booted defaults write app.downtify.ios downtify.theme.json -string "$(cat docs/theme-examples/full.json)"
```

```bash
xcrun simctl spawn booted defaults write app.downtify.ios downtify.appearance -string dark
```

To go back to the default theme:

```bash
xcrun simctl spawn booted defaults delete app.downtify.ios downtify.theme.json
```

Passing the theme as a launch argument (`-downtify.theme.json '{…}'`) doesn't work: iOS reads the JSON as a dictionary instead of a string, and the app ignores it. An invalid theme written this way is also ignored, and the app falls back to the default.

The unit tests decode every file in `docs/theme-examples/` and check that `full.json` sets every field, so the examples stay valid.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| "Could not import this theme" | A rule in [File rules](#file-rules) is broken. Common ones: a `#` in a color, a light value without its dark value, a number out of range, a misspelled choice such as `"carousell"`, or `homeSections` missing `recent`, `new` or `favorites`. |
| Colors don't change in OLED black | OLED keeps its black background and surface; switch Color mode to Dark to see the theme's dark colors. |
| Surface colors have no effect | `surfaceStyle` is `"system"`. |
| A Home section is missing | It's left out of `homeSections`, or it has nothing to show (Your artists needs two artists; Downloaded needs downloaded songs). |
| The theme shows as an imported theme after an update | It was saved from an older copy of a bundled theme; select Original or Redesign again. |
| Brand buttons are hard to read | Set `onBrandLight`/`onBrandDark` to contrast with `brandLight`/`brandDark`. |

## Example files

| File | Shows |
| --- | --- |
| [`theme-examples/minimal.json`](theme-examples/minimal.json) | Only the required fields. |
| [`theme-examples/full.json`](theme-examples/full.json) | Every field, with the redesigned screens. |
| [`theme-examples/high-contrast.json`](theme-examples/high-contrast.json) | Strong contrast: white and black backgrounds, a deep blue accent in light mode and yellow in dark mode, larger tiles, list shelves, standard screens, and Your artists hidden. |
