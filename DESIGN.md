# Design

## Source of truth

Status: **Implemented trial product — product name, wind-first mark, layout badges, preferences, and conversion feedback are in the local build; public-release review remains open.**
Date: 2026-11-15.
Product: **바람 입력기 · Baram Input Method**. The local ad-hoc Baram build now has an independent app, input-source, defaults, and IMK identity; recoverable Lab backups remain, but Lab is no longer installed.

Surfaces: macOS input-menu symbols, app icon, preferences, installer/readme, release materials, and the eight-page brand sheet at `docs/brand/baram/sheet.html`. PDF and 1200×750 page PNGs are generated under `docs/brand/baram/brand-sheet/`. The earlier one-page SVG is an overview study only.

Evidence reviewed:

- `README.md:12–21`: lightweight, open-source macOS Korean input and multiple keyboard layouts.
- `OSXCore/HangulComposer.swift:128–155`: libhangul automatic reordering is an option; physical chord recognition is a separate, unproved capability.
- `Preferences/PreferenceViewController.swift:162–321`: revised Input / Shortcuts / Advanced navigation and native settings form.
- `Preferences/PreferenceViewController.swift`: semantic AppKit colors, 13 pt labels / 11 pt help, mini switches, small native popups, footer explanations, and compact rows.
- `OSX/ConfigurationWindow.swift`: the app window owns a centered native preference toolbar, fixed 500 pt content width, one stable height based on the tallest category, and automatic keyboard traversal. The legacy prefPane host retains segmented navigation.
- Reviewed G007 light/dark/minimum/long-value renders, including `/tmp/gureum-preferences-after/preferences-input-light.png` and `preferences-input-dark.png`. These temporary renders are evidence, not shipping brand assets.
- `COPYING:1–8` and `OSX/Icons/COPYING:1–4`: source and inherited icon rights differ. Existing cloud artwork is not the basis of the new mark.
- Historical Baram's own introduction: <https://baramim.blogspot.com/>. It also uses the wish meaning of 바람. Our implementation derives from Gureum; formal continuation of historical Baram is not established.
- User-confirmed name and meaning: wind moves clouds; the input method responds “나의 바람대로.” The user requested a brand sheet before final colors/icons are applied.
- Authoritative family conventions reviewed in `/Users/nexus/Obsidian/kathar0s/Resources/brand_assets/sionyul/README.md`, `sionyul/app-guide/README.md`, `mitten/README.md`, and the Sionyuel brand MOC/logo brief. Required sheet order: cover / story / logo / color / app screen / typography+icons / don't / application, eight pages at 1200×750 pt. Repository source is authoritative; Obsidian holds generated review copies.

Observed implementation and remaining brand-review decisions are distinguished below. This document records the shipped trial implementation; it does not itself change app identifiers, installed icons, or product defaults.

## Brand

Confirmed name: **바람 입력기**. English descriptor: **Baram Input Method**. Short name: **바람 / Baram**. User-confirmed official distribution domain: **baram.sionyuel.com**. Domain selection is a naming decision; deployment and DNS availability require their own verification.

Proposed personality: calm, precise, lightly poetic, dependable, responsive. A tool used all day should make the writing feel effortless and let the user's words lead.

Recommended line: **나의 바람대로, 한글이 흐르다.** Use it in brand/release material; ordinary settings should use direct instructions.

The user-confirmed direction is **바람 궤적 B**: three independent horizontal wind strokes read as wind first. The aligned left terminals and two stacked right-hand curls suggest a Latin B only on a second look. There is no vertical stem, so the mark avoids the earlier literal-B and ₿ silhouettes. This is an intent pending user recognition review, not a measured claim. Geometry is original and centrally defined in `docs/brand/baram/mark.mjs`; master and menu-size paths are separate.

Trust comes from clear settings, preserved typing habits, accurate release claims, source/license provenance, tested rollback, and honest distinction between automatic reorder and physical chording. Avoid performance claims without measurements, official-successor language without agreement, historical artwork reuse, weather illustrations, metallic keyboard/cloud skeuomorphism, and decorative gradients.

## Product goals

- Make Korean input reliable on current macOS, with special attention to Sebeolsik and changed keystroke order.
- Preserve the user's existing layout and shortcuts while making their options easy to understand.
- Make install, identification, trial, and rollback understandable on both Mac Studio and MacBook.
- Establish a consistent formal identity after the experimental gates pass.

Non-goals: changing the user's keyboard layout through branding; disguising a timing heuristic as physical chording; making everyday preferences a marketing canvas; implying historical Baram code or endorsement without evidence.

Success signals: settings are findable within one category; menu items remain identifiable at 16 pt; no ambiguous selected/disabled states; real-world typing and migration evidence support release claims.

## Personas and jobs

Primary: a Korean-speaking macOS user who types in Sebeolsik, develops or writes across editors, Terminal, browsers, and Electron apps, and expects the same composition across them.

Jobs: select a familiar layout, change a shortcut, enable automatic ordering, diagnose an application-specific issue, and return to writing. Secondary audiences use two-set layouts or need Hanja/emoji and Roman keyboard mapping.

## Information architecture

Observed and retained preferences structure:

- **입력**: Hangul composition, strict combinations, configurable grave/Shift-grave characters, Roman layout, Option behavior, and a keyboard preview generated from the active layout XML.
- **단축키**: Hangul/Roman switch, Hanja/emoji, direct language shortcuts, plus always-visible Right-key Switching and System Shortcuts groups with native Open buttons.
- **고급**: application compatibility, per-application Esc behavior, opt-in automatic Hangul/Roman correction for all or selected apps, stable updates, and clearly labelled experimental physical input. Internal crash verification is not user-facing.

Brand/readme hierarchy: name → one-line purpose → verified capabilities → installation → trial/rollback → provenance. Keep experimental status and ad-hoc/notarization facts near installation decisions.

### Input menu

The system owns the input-source list. The app contributes only a compact native menu:

```text
설정                          ⌘,
업데이트 확인…                 upstream updater capability only
────────────────
도움말 및 지원                 native submenu
    웹사이트 / 사용 도움말     only when valid destinations exist
    문제 신고… / 소스 코드
    후원하기                   upstream donation capability only
    개발자 → 실험 버전 확인…   Debug upstream builds only
────────────────
About
```

Lab contributes Settings, Help & Support containing the fork's Issues and Source, and About. It does not inherit upstream website, help, donation, or update services. About uses the bundle's localized display name. Baram's About metadata names Sionyuel first and retains explicit Gureum author/contributor attribution; upstream metadata remains unchanged. Keep the existing InputController first-responder action routing and native keyboard, VoiceOver, submenu, and validation behavior. Use real NSMenu hierarchy without leading spaces in titles. Functional SF Symbols may appear on the top-level Settings/Update/Support/About items; submenu rows remain text-first.

`GureumMenuCapabilities` owns the product's valid destinations and updater capability; `GureumMenuBuilder` constructs app-owned menu items from that description. MainMenu.xib contains the delegate/outlet shell rather than a second static copy of those items.

## Design principles

1. **The user's rhythm leads.** Show a clear state; avoid visual activity during typing.
2. **Korean identity through structure.** The letterform and typography carry the identity, not a decorative cloud.
3. **Native where it helps operation.** Preserve AppKit menu, keyboard, focus, VoiceOver, and system appearance behavior.
4. **Controlled color, clear hierarchy.** Jade belongs to the product mark and deliberate highlights. A warm second strand may reveal the large app icon's construction; menu symbols remain bold monochrome. Semantic system colors own everyday controls.
5. **Evidence before promise.** Release language names what was tested and the environments that remain uncertain.

## Visual language

Brand tokens used by the brand assets, input-source badges, and conversion HUD:

| Token | Value | Role |
|---|---|---|
| `brand.jade` | `#14675F` | Primary mark and brand emphasis; white text contrast 6.70:1 |
| `brand.ink` | `#172C2C` | Brand-sheet text; warm-paper contrast 13.32:1 |
| `brand.paper` | `#F6F4EE` | Editorial/installer brand surface; not a forced AppKit window background |
| `brand.mist` | `#E5ECE7` | Quiet separators and diagram ground; never body text |
| `brand.secondary` | `#5D6E68` | Secondary text on paper, 4.90:1 |
| `brand.night` | `#162623` | Dark brand surface |
| `brand.mint` | `#A9E2CD` | Dark-surface mark/accent, night contrast 10.82:1 |
| `brand.warm` | `#D9A15F` | Optional rare annotation/accent, night contrast 6.90:1; not error color |
| `brand.roman` | `#7B4A24` | Roman input-source background; paper contrast 6.71:1 and clearly distinct from Hangul jade |

AppKit controls continue to use `labelColor`, `secondaryLabelColor`, `controlBackgroundColor`, `separatorColor`, and the user's system accent. Do not replace error/warning/success semantics with brand colors. Color pair ratios use WCAG relative luminance and apply only to these exact opaque pairs.

Typography:

- Preferences: AppKit system font, 13 pt regular labels, 13 pt semibold section headings, 11 pt supporting text. Native text supports OS rendering and accessibility expectations.
- Korean brand wordmark: **Apple SD Gothic Neo Bold** as the reviewable starting point, with modest optical spacing. A later outlined custom wordmark may soften the terminal of ㅂ and echo its opening; do not modify the font file or redistribute Apple fonts.
- English descriptor/body: system sans or Helvetica Neue on the brand sheet; 13/11 pt equivalents in UI. No added downloadable font dependency.
- Poetic line: **AppleMyungjo**, used only in large brand/editorial settings. Fallback to the system Korean serif. Never use it for controls or dense help.
- Shipping vector wordmarks should eventually be outlined after approval; the current sheet keeps live accessible text for review and relies on installed macOS fonts.

Spacing: 4/6/8/10/12/16/20 pt rhythm. The user's System Settings reference and independent advisor supersede both earlier large forms. Content width is fixed at 500 pt with 20 pt edges; the app window uses one stable height based on the tallest category, capped at 680 pt, so switching tabs never resizes the window or inherits a smaller scroll viewport. Rows use a 34 pt minimum plus a 1 pt separator, 10 pt horizontal insets, and true label/control vertical centering. Separators are inset 10 pt. Section headers use 13 pt bold primary text aligned with the row labels; at most one concise 11 pt explanation sits below the group as a footer. Native switches use `.mini` (36×16 pt on macOS 26). Value popups are borderless `.small` native controls with the current System Settings circular up/down-chevron accessory; their width is capped at 220 pt for long-name truncation. Editable single-character fields use a bordered `.small` 72 pt control for clear affordance. Support buttons remain bordered `.small`. Shortcut recorders use MASShortcut's native textured alignment at 120 pt, including its corrected clear-glyph position. Section gaps are 20 pt; no row subtitles or collapsible help.

Shape/elevation: native window chrome and stock `NSBox(.primary)` preference groups with system-owned fill/corners. No custom group fill, border, or radius: on macOS 26 the group should become slightly lighter than its dark window and slightly darker than its light window. Brand document target radii remain 8/12/20 pt plus pill and do not override native control geometry. No nested cards, floating shadows, or gloss. App-icon source master is a full 1024×1024 square with separate background/mark layers; the OS supplies the final mask. Rounded containers shown on the sheet are presentation mockups, not baked production masks.

Motion: retain system menu/switch transitions. Respect Reduce Motion. The automatic-switch HUD uses the bounded family toast motion described below; continuous typing-time decoration, logo animation, and particle effects are excluded.

Iconography: original **바람 궤적 B** mark; system SF Symbols for functional UI. Master geometry uses a 128-unit frame with 9-unit strokes and three open wind curls. The small optical version uses 11-unit strokes and simplified turns; do not scale the master unchanged for the app icon. System input-source assets deliberately omit the brand mark so the active layout stays legible at a glance. Their 22×16 pt badges use 44×32 Retina representations: Hangul jade carries `AHN`, `2`, `3`, `3F`, `390`, or `ROM`; Roman brown carries `A`, `CM`, `DV`, or deprecated `QW`. Every label is optically centered and the wider codes are fitted without reducing their vertical presence. The PNGs ship as direct bundle resources as well as asset-catalog fallbacks because TextInputMenuAgent preserves the wide direct-resource rendition but squeezed the catalog-only rendition. Keep at least 20% clear space around the standalone brand mark.

`brand-sheet/recognition.png` compares the master, optical correction, a ₿ confusion reference, plain Latin B, and plain ㅂ at actual 16/18/32/128 px. It is a structural review grid, not a user study or proof of recall. Before approval, inspect the silhouette without a wordmark for B recognition, ₿ confusion, 3/ε confusion, and curl fill-in. Never claim recognition is established from geometry tests alone.

## Components

| Component | Contract |
|---|---|
| Wordmark | Korean name primary; English descriptor secondary; keep “입력기” subordinate |
| App icon | Three open wind strokes with a secondary B impression; generated app-icon assets are installed in the trial build, with final release review still pending |
| Menu symbol | System input-source rows use direct 22×16 jade or Roman-brown code badges without the brand mark; the visible mode name remains the primary textual identifier |
| Category navigation | App path: centered native preference toolbar with Input / Shortcuts / Advanced icons and one stable height based on the tallest page. prefPane fallback: native three-way segmented control |
| Boolean setting | Native mini NSSwitch with VoiceOver name matching its visible row label; explanations belong to the group |
| Value menu | Borderless small NSPopUpButton retaining native menu/hover/focus/type-select behavior, with a semantic-color circular `chevron.up.chevron.down` accessory matching current System Settings |
| Two-choice setting | The same native popup language as other value settings; Option reuses its existing popup/action |
| Special-character key | Two 72 pt native text fields configure unshifted and Shift+grave output; one grapheme only, empty restores the active layout's default |
| Automatic Hangul/Roman correction | Baram-only scope picker under Advanced / App behavior: off, all apps, or multiple selected apps. Both directions support modern two-set (`2-full`) and the supported Sebeolsik layouts; old-Hangul two-set remains manual. The current word remains input-method-owned marked text until whitespace commits it once. Two-set requires a conservative two-syllable result and preserves native resyllabification and Backspace behavior. A complete supported-layout result switches to Hangul; a dictionary-confirmed English word, an audited built-in term (`github`, `tailscale`), or a valid domain switches to Roman. Pure ASCII digit/symbol output is never reverse-corrected. A domain-like label of 4–63 ASCII letters/digits/hyphens with both a vowel and consonant plus incomplete Hangul jamo converts at the period key, so `haezoom.` immediately becomes Roman; numeric, consonant-only, vowel-only, and Korean laughter runs remain Hangul. Leading punctuation cannot be discarded merely to make the remainder look like English (`;vies → 보면`). A known English prefix may be preserved when one unique complete Hangul suffix follows, such as `githubdptj → github에서`. Immediately after a successful conversion, plain Backspace restores the input-method-owned original token and previous internal mode while preserving the boundary; any other input, caret/client change, external commit, or secure input invalidates that undo record. Previously committed document text is never read |
| Automatic-switch HUD | A single nonactivating 220×36 pt solid pill appears 56 pt above the active screen's lower edge after a successful commit. Hangul uses brand jade `#14675F`; Roman uses brand brown `#7B4A24`; both use white text, so direction is recognizable before reading. It follows the 2026-11-15 Sionyuel toast motion: 12 pt rise with the native spring (`mass 1 / stiffness 449 / damping 31.4`), parallel 200 ms opacity, and 180 ms downward exit. Exit retains its transparent presentation endpoint until the panel orders out; an exit interrupted by replacement or immediate undo continues from the current presentation opacity/position without flashing or snapping. The pill layer—not the window—owns transform and opacity; no live blur is composited during motion. Because input-mode feedback can occur repeatedly while typing, Baram uses a shorter 1.8 s base hold instead of the family toast's 2.6 s; long copy still gains 0.1 s per character after 20 up to 6 s. The same text pulses to 1.04 for 160 ms and restarts its timer instead of re-entering. Reduce Motion uses 150 ms opacity only. It never takes focus, ignores the mouse, announces through VoiceOver, and never stacks notices |
| Shortcut capture | Existing MASShortcut behavior with consistent width and accessible label |
| System support | Always-visible compact groups and native Open buttons; no disclosure or inline-bezel links |
| Installer | Straight instructions, concrete version/architecture/signature status, scoped backup/rollback |

Token ownership: `docs/brand/baram/tokens.css` owns brand-document color/font values using family role names. `mark.mjs` and `build.mjs` generate the assets copied into the trial app; generated resources are not edited by hand. AppKit owns everyday control colors, while the conversion HUD uses the existing jade/Roman brand pair. Final asset licensing and release approval remain separate review items.

## Accessibility

Aim for WCAG 2.2 AA-equivalent visual contrast and macOS platform accessibility behavior. Test keyboard traversal, Space/Return menu opening, arrow/type-to-select, popup value announcement, switch label/value, and focus visibility. Enable automatic key-loop recalculation; category changes keep traversal in the active page in row order. Recorder controls accept keyboard focus and use the bundled Korean button-title localization. Do not use color alone to show an enabled mode. The popup accessory is decorative; the underlying native popup remains the accessibility and interaction surface.

The HTML sheet has semantic page labels, headings, live text, and screenshot descriptions; original SVG marks are described in text. PDF and PNG are generated review formats; HTML and the design document remain the accessible source. The earlier SVG overview also retains title/description/live text.

## Responsive behavior

This is a macOS desktop input method. Preferences keep a 500 pt content width and one stable height based on the tallest category, capped at 680 pt. Switching tabs does not resize the window or inherit a smaller viewport. A vertical scroller remains a fallback for constrained screens and the prefPane host. Long values truncate before labels and footer explanations wrap. No mobile layout is implied. The canonical brand sheet is eight landscape pages at 1200×750 pt (1600×1000 CSS px); PNG previews render each page at 1200×750 px.

## Interaction states

- Selected: native segment/checkmark/switch state; brand highlights must not obscure it.
- Disabled: retain label legibility and give a short reason where needed, including Lab updater isolation.
- Error: state the failed action and recovery, especially registration or preferences loading.
- Loading: avoid a blocking overlay for local preference changes; show progress only for meaningful work such as package/build steps.
- Empty/unknown layout: preserve a safe fallback and name the missing selection rather than showing an unlabeled menu.
- Offline: input remains local; update/network errors do not interrupt typing.
- Debug: experimental capture and developer actions are clearly separated and disabled in Release.

## Content voice

Use calm Korean with short, concrete labels. A setting title names the behavior; one secondary sentence explains the effect or compatibility target. “모아치기” describes libhangul's automatic choseong/jungseong/jongseong role reorder; it does not claim timing-aware physical chord capture or reverse every same-role pair. “세벌식 정석 조합” selects the dedicated 3F/390 combination tables that constrain compound vowels and final clusters. “물리적 동시입력” is reserved for verified key-hold grouping. Avoid “완벽한”, “가장 빠른”, or “모든 앱 지원” without evidence.

Brand line proposal: **나의 바람대로, 한글이 흐르다.** Alternative short signature: **손끝의 바람, 글이 되다.** The line is a brand promise of intention, not a technical claim of perfect recognition.

Provenance wording for release review: “구름 입력기를 기반으로 새롭게 개발한 독립 오픈소스 입력기입니다. 과거의 한글입력기 바람과 구름 입력기가 남긴 발자취를 존중합니다.” Do not imply endorsement or formal succession until confirmed.

## Implementation constraints

- Existing stack: Swift/AppKit, XIB/storyboard, InputMethodKit, libhangul, MASShortcut. No web frontend/package framework was found for these surfaces.
- Minimum target: macOS 12; Apple Silicon and Intel packaging require architecture verification.
- Retain existing configuration values, shortcut behavior, localization, and client-composition boundaries during visual changes.
- Baram identity is fixed locally as `Baram.app`, bundle/input-source prefix `com.sionyuel.inputmethod.Baram`, defaults suite `com.sionyuel.Baram`, and IMK connection `Baram_Connection`. Gureum and GureumChordLab identities remain unchanged for rollback.
- Existing cloud icons have separate CC-BY-NC-ND terms (`OSX/Icons/COPYING`); the sheet's geometry is newly authored and does not trace them.
- No historical Baram artwork is included. No third-party font binaries or stock images are added.
- Rebuild with `node docs/brand/baram/build.mjs`; add `--sync-obsidian` to refresh only named PDF/page copies in `/Users/nexus/Obsidian/kathar0s/Resources/brand_assets/baram/`. That folder's README records the source path, provenance, and remaining work.
- Validate preference light/dark, minimum height, long values, always-visible system/developer groups, keyboard focus, native menu interaction, and VoiceOver. Offscreen non-key renders do not prove live accent/focus contrast; current macOS 26 evidence does not establish macOS 12–15 runtime parity.
- Before changing shipping icons, render 16/18/32/128/512/1024 px and inspect silhouettes at actual size. Trial `.icns` and menu assets are generated from the repository; brand-sheet previews remain review evidence.
- The builder exports original master/small SVGs, 16/32/128 PNG comparisons, a 1024-square two-tone app-icon study, and a no-wordmark recognition grid from `mark.mjs`. Generated assets are not edited by hand.

## Open questions

- [ ] User: approve or revise final 바람 궤적 B geometry after actual-size/no-wordmark comparison; wind-first reading and secondary B impression are the confirmed directions.
- [ ] Release owner: complete official trademark/name clearance and attempt contact with historical Baram developer; determines public naming/relationship language, not this draft's ability to be reviewed.
- [x] Engineering: add independent Baram bundle/defaults/IMK/input-source identities and one-time Lab settings migration without removing either predecessor.
- [ ] Engineering: prove or reject physical key-up delivery across required clients; determines feature language and architecture.
- [ ] Design/release: approve final outlined Korean wordmark and original icon license; determines shipping asset provenance.
- [ ] QA: verify actual native menu and VoiceOver interaction on both target Macs; sheet illustrations do not prove interaction.
