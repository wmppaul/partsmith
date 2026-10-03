# Short variable-profile audit, 2026-10-03

No mistaken fixed-layout profile was found among the three complete short sources reviewed: Notte e giorno (4 pages), Verleih uns Frieden (6 pages), and Erlkönig (11 pages). All 21 pages were visually inspected for instrument roster/system grouping. No profile correction, source guard change, production edit or native export is proposed.

This is a bounded three-score audit, not a claim that every variable profile in the 36-score corpus is correct. Current `automaticPage` returns before assignment whenever `requiresSystemAssignment == true`. The bound saved native inventory contains zero assignments on every page of these three scores with precisely that unresolved reason. Its detected staff totals also match the independently read source counts below. No new full native scan was needed to establish this profile gate.

| Complete source | Actual layout | Why disabling the flag is unsafe |
|---|---|---|
| Mozart, Notte e giorno | Page1 systems: Piano, Piano, Voice+Piano, Voice+Piano, Voice+Piano (2+2+3+3+3 physical staves). Pages2–4 each have five Voice+Piano systems. | Two piano-only opening systems cover bars1–9; the vocal staff first appears at bar10. A three-staff cadence would mix the piano systems and put music in the wrong voice. |
| Mendelssohn, Verleih uns Frieden, Righetti organ transcription | Page1: SATB+three-staff organ. Page2: Organ alone, then three Bass+Organ systems. Page3: three Alto/Bass+Organ systems. Page4: Alto/Bass+Organ, then SATB+Organ. Pages5–6: two SATB+Organ systems each. | The named union is five parts/seven physical staves, but real systems contain 3,4,5,or7 staves. The organ is two manual staves plus pedal, never a two-staff piano inferred from a brace alone. |
| Schubert, Erlkönig | Page1: four Piano-only systems beginning bars1/4/7/10, then Voice+Piano at13. Every remaining system on pages2–11 is Voice+Piano, including the final recitative. | Twelve omitted vocal bars precede the printed voice. The constant later layout does not make the whole score fixed. |

The source-derived physical staff totals by page are Notte `[13,15,15,15]`, Mendelssohn `[7,15,15,12,14,14]`, and Erlkönig `[11,15,12,12,12,15,15,15,12,12,9]`. Native totals agree, but that agreement is supporting evidence, not the reason for assigning identities. The roster was read from printed systems, clefs, braces, lyrics and named entries. Full-size first pages and complete three-page contact sheets were inspected. Poppler emitted fontconfig-cache warnings; printed notation and roster labels remained visible in the reviewed renders. This is roster review, not a glyph-completeness/export certification.

## One practical algorithmic path

Add reviewed **system templates with scoped propagation**. A user first identifies one printed Voice+Piano system and one Piano-only system. Match subsequent systems using the observed brace/group boundaries and staff arrangement, plus printed labels/lyric ownership and clefs where they remain consistent. Assign only when exactly one reviewed template has source support; keep uncertain or changed systems for explicit review. Do not decide instrument identity from staff-count modulo or divisibility.

Erlkönig is a small complete test case for this path: it has only two roster templates across 48 systems (four Piano-only and44 Voice+Piano). Source-supported reuse could remove almost all repeated instrument picking while keeping the opening exception. The four omitted vocal spans have printed anchors1/4/7/10/13, supporting four3-bar generated rests (or one12-bar span if layout later merges them). The existing omission-rest model should be used; template propagation must not silently discard time or invent a count when anchors/barlines are uncertain. Notte supplies a second two-template case; the Mendelssohn arrangement supplies a harder four-template holdout.

A profile-wide Boolean can remain a conservative default while per-system reviewed matches create explicit overrides. This reduces initialization work without weakening the existing gate or claiming that the score is fixed. No implementation or changed profile is included in this audit.

`source-roster.json` records every reviewed page's system roster, source/profile hashes and bound saved native counts/reasons. `hashes.json` binds this report and all rendered evidence. Sources remain unchanged; no rendered source was used as a new preservation oracle.
