# Save-list chapter title abbreviations

Investigation date: 2026-11-16.

## Problem

Long English main-mission titles overlap the turn/time column or extend beyond the save-list panel. This occurs in the saved-games preview on the system-file selection screen and in the save selection screen inside a profile.

The observed examples include `13Ch. Main: Silent City` and `11Ch. Main: Bloodstained Valley`. Side-mission rows such as `12Ch. Side: Here...` already use an abbreviated title.

## How the existing ellipsis works

The visible ellipsis is literal text in a separate abbreviated resource entry. The traced save-list selection paths do not calculate an abbreviation from the rendered title width or enable ellipsis through a flag.

The entries are present in `Script/14/sysfont.ar.txt`, with corresponding entries in `Script/549.msg.txt`:

| Resource key | Text | Role |
| --- | --- | --- |
| `quest084` | `The Heretic God` | Full side-mission title |
| `quest_s084` | `Here...` | Abbreviated side-mission title |
| `mission011` | `Bloodstained Valley` | Main-mission title |
| `mission013` | `Silent City` | Main-mission title |

Other side missions follow the same convention, for example `quest002 = Looters` and `quest_s002 = Loot...`. No `mission_s` entries were found in `Script/14/sysfont.ar.txt`.

## Executable findings

The investigation used `Utils/MipsInspect.cjs` to inspect `BinaryTexts/Source/SLPS_254.97` and compared the relevant instruction words with the current root-level `SLPS_254.97`. The instructions listed below are identical in both files.

All offsets below are hexadecimal **file offsets**, not runtime addresses. For this executable, the relevant runtime addresses equal file offsets plus `0x000FFF00`.

The save-list code selects a title prefix and a numeric ID. Main missions use `mission`; side missions use `quest_s`. With three-digit IDs, these resolve to resource names such as `mission011` and `quest_s084`.

| String file offset | Runtime address | String |
| --- | --- | --- |
| `0x003B0B30` | `0x004B0A30` | `mission` |
| `0x003B0B38` | `0x004B0A38` | `%s%03d` |
| `0x003B0BA0` | `0x004B0AA0` | `quest_s` |

Two selection paths use these prefixes:

| Path | Main-mission prefix instructions | Side-mission prefix instructions |
| --- | --- | --- |
| Function beginning at `0x0023CB80` | `0x0023CC38`: `lui v1, 0x004B`; `0x0023CC40`: `addiu v1, v1, 0x0A30` | `0x0023CC90`: `lui v1, 0x004B`; `0x0023CC98`: `addiu v1, v1, 0x0AA0` |
| Second list path | `0x0023D060`: `lui t0, 0x004B`; `0x0023D06C`: `addiu t0, t0, 0x0A30` | `0x0023D090`: `lui t0, 0x004B`; `0x0023D098`: `addiu t0, t0, 0x0AA0` |

These findings explain why side-mission titles have ellipses while long main-mission titles overflow: the side-mission list selects a separate short resource, whereas the main-mission list selects the full title.

## Proposed fix

Extend the existing resource convention to main missions:

1. Add separate abbreviated entries such as `mission_s011` and `mission_s013`.
2. Store a null-terminated `mission_s` prefix in suitable executable storage and redirect both main-mission list paths to it.
3. Keep the existing `missionNNN` resources for full titles.
4. Choose abbreviations using the available rendered width, including the chapter/type prefix and space reserved for the turn/time column.

For example, `mission_s011 = Blood...` illustrates the mechanism; the final wording and fit have not been tested.

The new `mission_s` string requires 10 bytes including its terminator. The existing `mission` string occupies 8 bytes including its terminator and is immediately followed by `%s%03d`, so it must not simply be overwritten in place.

Shortening `mission011` directly is not a list-specific fix: it can affect other consumers of the full title. Separate short entries allow the list to be abbreviated while retaining full titles elsewhere.

## Implementation and verification still required

This investigation did not patch the executable, edit title resources, rebuild the tool, or pack an ISO. Adding resource keys and redirecting the two paths is a proposed implementation, not a verified patch.

Before shipping a fix:

- Confirm how new named entries must be included in the packed resource archives, including the relationship between `14/sysfont.ar` and `549`.
- Check that both list paths use the new entries on the system-file selection screen and inside a profile.
- Verify long main-mission titles with turn counters, completed saves, and city saves.
- Verify that existing side-mission abbreviations still work and full titles remain visible in the detail panel and other screens.
- Check the actual translated text and font widths in game; character counts alone do not establish fit.

The static investigation establishes the existing abbreviation mechanism and the relevant prefix-selection instructions. In-game behavior of a new main-mission abbreviation patch remains unverified.
