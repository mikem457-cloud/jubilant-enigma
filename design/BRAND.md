# FloofSync Brand

The logo: a deep-navy medical cross holding a two-tone dog silhouette, with
sync arrows at the jaw — health record + reminder loop in one mark. Wordmark
"FLOOF SYNC" in heavy navy caps. This document reconciles the logo with the
app's warm interface palette (`floofsync-today.html`) so the two read as one
brand.

> **Asset needed:** add the original logo files to `design/logo/` —
> ideally the vector source (SVG/AI) plus a 1024×1024 PNG on transparent.
> The App Store icon must be generated from the vector.

## 1. Palette

Brand blues (sampled from the logo — re-sample from the vector when added):

| Token | Hex | Use |
|---|---|---|
| `brandNavy` | `#1C3A5F` | Logo cross, wordmark; app tint color, primary buttons, tab selection, links |
| `brandSteel` | `#4878A8` | Logo dog-body tone; secondary accents, charts, selected states |
| `brandNavyDeep` | `#12263F` | Dark-mode surfaces, pressed states |

Interface palette (carried from the Today mockup — warm, calm, paper-like):

| Token | Hex | Use |
|---|---|---|
| `paper` | `#FAF6EC` | Cards |
| `background` | `#EEF1EC` | Screen background |
| `ink` | `#2A2926` | Body text |
| `inkSoft` | `#6B6A63` | Secondary text |
| `marigold` | `#E2A33B` | Due-now accent, warnings, highlights |
| `clinicRed` | `#C23B3B` | Overdue, emergency, destructive |
| `sage` | `#6E8B5E` | Done/success |

**How they coordinate:** navy is the *interactive* color (what you can tap),
marigold/red/sage are *status* colors (what needs attention), and the warm
neutrals are the stage. Navy-on-paper reads as trustworthy-medical without the
app feeling clinical; marigold against navy is a classic high-contrast pairing.
Status colors are never used for interaction, and navy is never used for
status — that separation is what keeps the screen legible.

Optional logo refinement (owner's call, not required): recolor the sync arrows
marigold `#E2A33B` to tie the mark to the app's signature accent. The
all-navy mark is also fine — it's stronger at small sizes.

## 2. App icon direction

The cross+dog mark alone (no wordmark) on a `paper` background, navy mark;
dark-mode alternate: paper mark on `brandNavyDeep`. Generate at 1024 from
vector; Phase 4 adds the 6 alternate icons (navy/paper inverted, marigold
accent, etc.).

## 3. Type & UI voice

- System fonts only (SF Pro / SF Rounded for friendly numerals on Today);
  no bundled typefaces — zero-dependency rule applies to fonts too.
- Wordmark stays logo-only; the in-app title is plain text "FloofSync".
- Voice: plain verbs, sentence case, no exclamation marks, no baby talk. The
  app is calm even when a dose is overdue — urgency comes from color and
  position, not copy.

## 4. Accessibility

- All status colors carry an icon + label, never color alone
  (`01-ARCHITECTURE.md` §9).
- Contrast: `brandNavy` on `paper` = ~8.8:1; `marigold` is never used for
  text below 18 pt on paper (3.2:1) — it gets `ink` text on a marigold chip
  instead.
- Tokens are defined once in `DesignSystem` and consumed by name; no raw hex
  in views.
