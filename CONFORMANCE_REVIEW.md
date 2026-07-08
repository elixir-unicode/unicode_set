# unicode_set v1.6.2 — Conformance & Robustness Review

Assessed against CLDR TR35 (LDML Part 1, "Unicode Sets"), the draft UTS #61 "UnicodeSet" formalization, UTS #18 "Unicode Regular Expressions" (Level 1), and the ICU UnicodeSet / ICU regex reference implementations. All findings below were reproduced against the running library at Elixir 1.20.1 / OTP 29, unicode_set 1.6.2, unless explicitly marked otherwise.

> **Method.** Each of the four specifications was read and reduced to a checklist of atomic, testable requirements; the six code areas (parser/grammar, set operations, transforms/output, regex integration, matching/search, property resolution) were inventoried against the running library; and every candidate finding was then re-executed against `unicode_set` v1.6.2 on Elixir 1.20.1 / OTP 29 and confirmed by observed output before being recorded. Findings that could not be reproduced were dropped. Behaviours that turned out to be correct (e.g. operator *chains* without a juxtaposition boundary, the `[[:Lu:]-A]` illegal-operand rule, `match?/2` membership, and the broad enumerated-property surface) are noted as conformant rather than flagged. Severities: **critical** = silent wrong result or crash on common input; **high** = documented/common feature broken; **medium** = edge case or contract violation on lightly-malformed input; **low** = documentation or cosmetic.

## 1. Executive summary and overall verdict

unicode_set is a capable, cleanly layered library that gets the common cases of TR35 UnicodeSet syntax right: bracketed character classes and ranges, union by juxtaposition, the single-character `&` and `-` operators, POSIX `[:prop:]` and Perl `\p{}`/`\P{}` property sets with negation and the `≠` (U+2260) operator, `{curly-brace}` string members, top-level `[^...]` complement, and a fast `:in`/`:not_in` reduction strategy that avoids materialising a complement over the entire codespace whenever no intersection or difference forces expansion. Its 13 POSIX compatibility properties (`alpha`, `punct`, `xdigit`, `graph`, `print`, `word`, …) match the UTS18 Annex C Standard-Recommendation table exactly. For well-formed single-class and single-operator patterns it is a reasonable TR35 implementation.

An adversarial review, however, confirms a substantial set of defects that prevent a claim of full conformance. The most consequential are: (a) documented escape forms that are silently wrong or crash — `is_hex_digit` treats every ASCII letter as a hex digit, bracketed `\u{...}`/`\x{...}` (including the README's own `\u{1F600}`) crash, and `\U`, `\v`, octal, `\c`, `\N`, and single-quote quoting are unsupported or mis-decoded; (b) set-operation precedence that is not left-to-right associative across a juxtaposition boundary, contradicting the library's own README and every governing spec (a known, unchecked `TODO.md` item); (c) a regex emitter that produces silently-wrong or uncompilable output for string members (no PCRE escaping), surrogate-bearing ranges, multi-string sets (a bogus `[[][]]` class), and ungrouped string-range alternations; and (d) `parse/1` and the other tagged-tuple functions routinely violating their `@spec` by raising instead of returning `{:error, _}`.

**Calibrated verdict:** partial conformance to TR35 with material, confirmed correctness and robustness defects; a UTS18 Level-1 property surface that is close but incomplete (Script_Extensions and several standard enumerated properties are unresolvable); and only minimal alignment with the draft TR61 grammar. None of the defects affect the single-class happy path, so the library is suitable for production use on well-formed single-class / single-operator patterns, but it cannot presently be represented as fully conformant to TR35 or UTS18, and it is far from TR61.

## 2. Architecture overview

The processing pipeline is:

```
pattern string
  -> Unicode.Set.Parser (NimbleParsec grammar)         # AST of {:in,_}/{:not_in,_}/{:union,_}/{:intersection,_}/{:difference,_}
  -> Unicode.Set.Operation.reduce/1                     # :in/:not_in preservation strategy, or full expansion
  -> Unicode.Set.Transform.{guard_clause,pattern,utf8_char,regex,...}   # target emitters
  -> Unicode.Regex (splitter) for embedding sets in a larger regex
```

**Parser.** `basic_set/0` (parser.ex:20) consumes `[`, an optional `^` → `:not`, a `min: 1` sequence, and `]`. Ranges, string values, escapes, and properties are all leaf productions; `maybe_repeated_set/0` (parser.ex:46) folds `&`/`-` operators between nested sets. This is a conventional, readable grammar. Its weak points are the escape lexer (`is_hex_digit` at parser.ex:8 conflates letters with hex digits; `hex_to_codepoint/1` at parser.ex:438-452 has named branches only for `\t`/`\n`/`\r`) and the absence of productions for single-quote quoting, boundary literal hyphens, `[]`, `[{}]`, `\U`, octal, and `\c`.

**Reduce and the `:in`/`:not_in` preservation strategy.** `reduce/1` (operation.ex:64-82) is the cleverest part of the design. It calls `has_difference_or_intersection?/1` (operation.ex:244-259); if the AST contains no `&`/`-`, it keeps the compact `:in`/`:not_in` form via `combine/1` (so `[^a-z]` stays `{:not_in, [{97,122}]}` and never expands over 0..0x10FFFF), and only fully expands to code-point ranges when an intersection/difference forces it. This is a genuine performance win. The strategy's Achilles heel is that the range primitives it delegates to — `union/2`, `intersect/2`, `difference/2` (operation.ex:269-683) — carry an **unenforced** sorted-and-disjoint precondition, and `union/2` does not compact at all (the correct merge-walk is commented out at operation.ex:278-315; confirmed by inspection). Whenever a `{:union, ...}` node with a non-`:in` operand feeds a difference or intersection, the overlapping list silently corrupts membership.

**Transform layer.** Four target emitters share the reduced AST: a boolean guard AST for `match?/2` in guard context, a `:binary.compile_pattern` list, nimble_parsec `utf8_char` terms, and a regex string. The multi-target design is good, but the regex emitter (`Transform.to_binary/1,2`, transform.ex:130-147, and the assembly in unicode_set.ex) interpolates string members and surrogate-bearing ranges without escaping or block-splitting, which is the source of the entire RE-* cluster.

**Search tree.** `build_search_tree/1` (search.ex) builds a balanced binary tree of ranges, but `member?/2` (search.ex:104) recurses **both** subtrees unconditionally because the tree carries no separator keys — membership is O(n) in leaf ranges, not O(log n), a fact acknowledged in-code. It also lacks clauses for the empty binary and the union-of-complements reduced form.

**Regex splitter.** `Unicode.Regex.split_character_classes/2` (regex.ex:194-268) is a hand-rolled scanner that extracts `[...]` and `\p{}` segments and hands each to `to_regex_string`. It special-cases `\[` and `\]` but not `\\`, has no awareness of `\Q...\E` literal spans or `(?#...)` comments, and `expand_unicode_sets` (regex.ex:272-300) matches only `{:ok,_}`/`{:error,_}` without rescuing the raises that `to_regex_string` can produce.

**Honest assessment.** The reduce strategy and multi-target Transform layer are well-conceived, and the happy path is correct and fast. But four systemic weaknesses — unvalidated range primitives, a letter/hex-conflating escape lexer, a `Regex.CompileError`-only rescue boundary, and an unescaping regex emitter / unaware splitter — generate the large majority of the confirmed defects. All four are fixable without redesigning the pipeline.

## 3. Conformance matrix

Legend: **full** = conformant; **partial** = conformant on the common case with a confirmed gap; **divergent** = intentional or spec-differing behavior; **buggy** = confirmed defect; **missing** = unimplemented.

| Feature | TR35 | TR61 | UTS18 / ICU | Status | Note |
|---|---|---|---|---|---|
| Bracketed set, ranges, union by juxtaposition | req | req | req | full | Correct common case (parser.ex basic_set/0, character_range/0). |
| Complement `[^...]` over code points (top level) | req | req | req | full | `:not_in` preserved without universe expansion. |
| Single-operator `&` / `-` between grouped sets | req | req | req | full | `&&`/`--` correctly rejected in the standalone parser. |
| Precedence: equal, **left-to-right associative** | req | req | req | **buggy** | SOP-1: trailing `&`/`-` re-associates only to the immediate right operand across a juxtaposition boundary. parser.ex:120-123. Open TODO. |
| Illegal bare-operand rule `[[:Lu:]-A]` rejected | req | req | req | full | Matches ICU exactly. |
| POSIX / Perl property syntax, negation, `≠` | req | req | req | partial | PS-1: hyphen in property NAME breaks loose matching. |
| Property loose matching (UAX44-LM3) | req | req | req | partial | Case/ws/underscore handled; hyphen not (PS-1); `Is`→Block shadows real names (`\p{IsAlphabetic}` fails). |
| gc / Script / Block / CCC / break properties | req | req | req | partial | PS-2 `scx` (UTS18 MUST) missing; PS-3 Age/Bidi_Class/Numeric_* missing; PS-7 `Latin-1 Supplement` fails on the digit. |
| UTS18 Annex C compatibility properties | n/a | n/a | req | full | All 13 match the reference table (property.ex:12-63). |
| `\uhhhh` (4-hex), `\xhh` (2-hex) | req | req | req | partial | 2-digit `\x` and 4-digit `\u` work; single-digit `\x9` raises. |
| `\Uhhhhhhhh` (8-hex) | req | req | req | **missing** | No `?U` branch; `[\U00000041]` raises (LEX-2). |
| Bracketed hex `\u{...}`/`\x{...}` | div | req | req | **buggy** | LEX-3: single-cp crashes (README's own `\u{1F600}`); multi-cp yields undecoded garbage. |
| Named control escapes `\a \b \t \n \v \f \r \\` | req | req | req | **buggy** | GAP-CTRL-ESC-1: only `\t \n \r \\` correct; `\a→\n`, `\b→\v`, `\f→\x0F`; `\v` raises. |
| Backslash+char → literal char | req | req | req | **buggy** | LEX-1/ROB-02: `\d→\r` silently, `\w` raises. parser.ex:8. |
| Octal `\ooo`, `\cX` | n/a | req | req | **missing** | `[\101]`→U+0001 then '0','1'; `[\cH]`→U+000C then 'H'. |
| `\N{UNICODE NAME}` | req | req (3 forms) | req | **missing** | Documented omission; `[\N{SPACE}]` raises from parse/1. |
| Single-quote quoting `'...'`, `''` | req | n/a | req | **missing** | LEX-4: unimplemented; `['a-z']` silently keeps the a-z range. |
| Whitespace ignored inside a set | req | req | req | partial | LEX-5: first whitespace run after `[`/`[^` becomes a literal U+0020. |
| Leading/trailing bare hyphen as literal | n/a | req | req | **missing** | GAP-HYPHEN-1: `[-a]`, `[a-]`, `[a-z-]` all ParseError. |
| String members `{abc}`, `[abc{def}]`, `[{a}]==[a]` | req | req | req | partial | Parse/reduce correct; regex emission broken (RE-1/RE-3/SR-1). |
| Empty-string `{}` and empty set `[]` | `[]` ok | `[]`=∅, `[{}]`={""} | both (ICU 69+) | **missing** | SR-6/ROB-03: neither representable; `[-]` crashes reduce. |
| String ranges `{ab}-{cd}` | ext | disallowed | ICU4J allows | divergent | Cross-product supported; SR-2 crash, SR-4 reversed, RE-4 ungrouped. |
| Complement affects only code points, not strings | req | req | req | divergent | SR-5/CU-2: string folded into `:not_in` then set rejected. |
| Surrogate handling in regex output (RL1.7) | n/a | n/a | req | **buggy** | CU-1/RE-2/RE-5: dangling hyphen, dropped ranges, uncompilable `[]`. |
| Regex emission of string members (escaping) | n/a | n/a | RL2.2.1 | **buggy** | RE-1: unescaped metacharacters → false positives / uncompilable. |
| Regex embedding (`\Q..\E`, `\\`, `(?#..)`) | n/a | n/a | n/a | **buggy** | RS-1/RS-2/RS-3. |
| `parse/1` tagged-tuple contract | n/a | C1/C2 | n/a | **buggy** | ROB-01/PS-4: raises on many inputs. |
| TR61 conformance profile (C1/C2/C3) | n/a | req | n/a | **missing** | No declared restriction/tailoring set. |

## 4. Confirmed correctness bugs (by severity)

### Critical

**RE-1 — String members emitted verbatim into the regex with no PCRE escaping.** `to_regex_string("[a{b.c}]")` → `{:ok, "(?:[\x{61}]|b.c)"}`, and `Regex.match?(re, "bxc")` is `true` (false positive), while the `match?/2` macro correctly returns `false` — so the regex path diverges from set semantics. Worse, `to_regex_string("[x{a)b}]")` → `{:ok, "(?:[\x{78}]|a)b)"}`, an **uncompilable** regex handed back as `{:ok, _}`. Root cause: `form_string_ranges` / `join_regex_strings` interpolate `List.to_string` output unescaped (transform.ex:175-179, unicode_set.ex:524,567). Each branch must be PCRE-escaped and the output must always compile.

**RE-2 — Surrogate endpoints corrupt the emitted class.** `to_regex_string("[a\uD800-\uDFFF]")` → `{:ok, "[\x{61}-]"}` and `Regex.match?(re, "-")` is `true`; `to_regex_string("[휀-\uD900]")` → `{:ok, "[\x{D700}-]"}`, dropping D701..D7FF. `to_binary/1` returns `""` for a surrogate and `to_binary/2` joins `first <> "-" <> last`, leaving a bare trailing hyphen (transform.ex:130,141,145). The surrogate block must be split out.

**LEX-3 — Bracketed hex `\u{..}`/`\x{..}` broken.** `parse("[\u{1F600}]")` raises `FunctionClauseError` in `check_valid_range/5` — this is the README's own example (README:331). The multi-codepoint form `parse("[\u{41 42 43}]")` yields `[in: [{[~c"41", ~c"42", ~c"43"], ...}]]` — raw hex charlists that are never decoded. `bracketed_hex` never runs its charlists through `String.to_integer` (parser.ex:409-428,444).

**LEX-1 / ROB-02 — `is_hex_digit` treats every ASCII letter as a hex digit (corrected severity: high).** `parse!("[\d]").parsed` → `[in: [{13, 13}]]` — silently U+000D, because `String.to_integer("d", 16) == 13`, where the README (line 333) requires the literal `'d'` = U+0064. `parse("[\w]")` raises `ArgumentError`. `defguard is_hex_digit(c) when c in ?0..?9 or c in ?a..?z or c in ?A..?Z` (parser.ex:8) means the literal-letter fallthrough at parser.ex:441 is never reached. The silent-wrong-value half is the dangerous one.

**SOP-1 — Set-operation precedence is not left-to-right associative (corrected severity: high).** `parse!("[[a-f]-[b][g]&[g-z]]")` reduces to `{:in, [{97,97},{99,103}]}` (a,c,d,e,f,g), but left-to-right evaluation requires `{g}`. Verified through the public macro: `match?(0x0041, <README letter/number set>)` returns `true` where the README itself requires `false`; the explicitly-grouped variant returns the correct `false`. The final `reduce_set_operations` clause wraps `set_a` in `{:union, [set_a, reduce_set_operations(rest)]}`, reducing `rest` **independently**, so a trailing operator binds only inside `rest` (parser.ex:120-123). This is the unchecked `TODO.md` item "Left to right association of set operations". Note the README's *other* documented example `[[ace][bdf] - [abc][def]]` yields the correct `{def}` only incidentally, because adjacent plain `:in` sets are pre-merged before the difference sees them.

### High

**GAP-CTRL-ESC-1 — Half the documented control escapes are wrong or crash.** Only `\t`, `\n`, `\r`, `\\` are correct. `[\a]`→U+000A, `[\b]`→U+000B, `[\f]`→U+000F (all silently wrong), and `[\v]` raises. `hex_to_codepoint/1` has named branches only for `?t`/`?n`/`?r` (parser.ex:438-440); the rest fall through to base-16. This is **additive** to LEX-1: fixing `is_hex_digit` only turns `\a`/`\b`/`\f` into the literal letters (97/98/102), still not the control codes — new named branches are required.

**SOC-1 — A bracket-grouped union feeding a difference keeps subtracted code points.** `parse_and_reduce!("[[\P{L}[0-9]]-[5]]")` still contains 53 ("contains 5? true"); `parse_and_reduce!("[[[:^Lu:][a-z]]-[m]]")` still contains `m`. `expand({:union,...})` (operation.ex:97) uses the non-compacting `union/2`, and `difference/2` clause 14 (operation.ex:680) emits the leftover overlapping A-range verbatim once B is exhausted. Reachable via ordinary syntax whenever a union has a non-`:in` operand feeding a top-level difference.

**SR-1 / RE-3 — Multi-string sets emit a bogus `[[][]]` class.** `to_regex_string!("[{abc}{def}]")` → `"(?:[[][]]|def|abc)"`, and `Regex.match?(re, "[]")` is `true`. The empty `(strings, classes)` accumulator `{[], []}` dispatches to the `[list_one, list_two]` clause (unicode_set.ex:555), producing `[[][]]` which PCRE reads as `[[]` then `[]]`.

**CU-1 — Surrogate range endpoint corrupts complement/regex output and diverges from `match?/2`.** `to_regex_string("[^\uDB00-￿]")` → `{:ok, "[^-\x{FFFF}]"}` (whole DB00..FFFF dropped, dangling hyphen), while the runtime `match?/2` for the same set is correct — the two paths disagree. Same `to_binary` root cause as RE-2, via the complement path.

**RS-1 — Splitter ignores `\Q...\E` literal spans.** `compile("^\Qa[b]c\E$")` → `~r/^\Qa[\x{62}]c\E$/u`, and `Regex.match?(re, "a[b]c")` is `false` (must be `true`): `[b]` inside the literal span is extracted and expanded, and because `\Q..\E` makes everything literal the compiled pattern now requires the expanded text. `split_character_classes` has no `\Q`/`\E` awareness (regex.ex:188).

**RS-2 — `extract_character_class` has no `\\` clause.** `split_character_classes("[a\]xyz")` swallows `xyz` into the class; `compile("[\][:Lu:]")` fails to compile. Only `\[` and `\]` are special-cased (regex.ex:241,246), so a trailing `\]` byte pair is misread as an escaped `]`. `[\\]` (match a backslash) is a common idiom.

**RE-4 / SR-3 — String-range-only sets emit an ungrouped alternation.** `expand_regex("x[{ab}-{cd}]y")` → `"xab|ac|ad|bb|bc|bd|cb|cc|cdy"`; `Regex.match?(re, "cdy")` is `true` with no leading `x`. `form_string_ranges` interposes `|` with no `(?:...)` wrapper (unicode_set.ex:567), unlike the mixed clause at unicode_set.ex:551.

**ROB-03 — The documented empty set `[-]` crashes every consumer.** `parse("[-]")` → `{:ok, ...}` with `parsed: ["[-]"]` (raw string), but `parse_and_reduce("[-]")` → `FunctionClauseError` in `compact_ranges/1`. `empty_set/0` returns the raw matched string instead of an empty range structure (parser.ex:30).

**ROB-04 — Union of complements crashes function-context callers but works as a guard.** `to_regex_string("[[^a][^b]]")` → `FunctionClauseError` in `not_in_has_no_string_ranges/1`; `match?(?z, "[[^a][^b]]")` in function context → `FunctionClauseError` in `build_search_tree/1`, yet the identical set returns `true` in guard context. Both functions are non-exhaustive on the bare-list wrapper produced by the union of two complements (unicode_set.ex:462, search.ex:6).

**LEX-4 — Single-quote quoting entirely unimplemented.** `parse("['a-z']")` → `{:in, [{39,39},{39,39},{97,122}]}` — the quotes become literal apostrophes and `a-z` is *still* a range, the opposite of quoting. `char/0` has no single-quote clause (parser.ex:384-389).

**ROB-01 / LEX-2 — `parse/1` rescues only `Regex.CompileError`.** `parse("[\u{61}]")` → `FunctionClauseError`; `parse("[\U00000061]")` → `ArgumentError`; `parse("\p{emoji=yes}")` → `UndefinedFunctionError`. All escape the rescue at unicode_set.ex:67-70, violating the tagged-tuple `@spec`. Every downstream function inherits the crash.

**PS-4 — `\p{emoji=...}` raises `UndefinedFunctionError`.** The `emoji` server module is registered but does not export `fetch/1` (property.ex:84), and the exception escapes the `Regex.CompileError`-only rescue.

**PS-1 — Loose matching does not ignore hyphens in property NAMES.** `\p{White-Space}` → ParseError, while `\p{Line_Break=Break-After}` (hyphen in *value*) parses. `property_name/0` admits only alphanumerics plus `_` and space (parser.ex:333). UAX44-LM3 (a MUST via UTS18 RL1.2) requires hyphen be ignored in name matching.

**PS-2 — Script_Extensions (`scx`) is not resolvable.** `\p{scx=Hira}` → error; `Unicode.fetch_property("scx")` → `:error`. `scx` is a UTS18 RL1.2 MUST property; no server module is registered (root cause in the `unicode` dep, surfaced here).

### Medium and low

The medium tier is dominated by the range-primitive weaknesses (**SOC-2** union never compacts — the merge-walk is commented out at operation.ex:278-315; **SOC-3** symmetric_difference returns the union for overlapping inputs; **SOC-4** intersect/difference silently drop/retain on unsorted input), string-range validation gaps (**SR-2** unequal-length endpoints crash, including at macro-compile time; **SR-4/ROB-07** reversed `[z-a]` accepted then diverges across targets), complement-of-strings divergence (**SR-5/CU-2**), several contract violations on complement sets (**ROB-05** to_pattern raises, **ROB-06** generate_matches crashes, **ROB-09/RE-5** single surrogate → uncompilable `[]`), **ROB-08** empty-string input to `match?/2` crashes, **LEX-5** leading whitespace captured as U+0020, **PS-3/PS-7** missing/mis-normalised properties and blocks, **GAP-HYPHEN-1** boundary hyphen rejected, and **RS-3** compile/expand_regex raising instead of `{:error, {message, index}}`. The low tier is documentation and cosmetics: **PS-5** `\p{Category=...}` doc example does not resolve, **PS-6** `Sundanese` misspelled as `sudanese`, **RE-6** misleading `[:Zs]` doc example, **SR-6** `[{}]` unsupported, and **ROB-10** dead `:parse_many` combinator plus cryptic label-chain error messages.

## 5. Functional and conformance gaps

Beyond the bugs above, the following features required or defined by the specs are absent or divergent:

* **`\Uhhhhhhhh` (8-hex) is entirely missing** (UTS18 RL1.1 / TR35 / ICU / TR61 mandatory, and README-documented): `quoted/0` has no `?U` branch, so `[\U00000041]` raises.
* **Octal `\ooo` and `\cX`** (ICU, TR61 §2) are unimplemented and silently mis-decode.
* **Single-digit `\x`** (TR35/ICU/TR61 define `\x` as 1–2 hex) raises.
* **`Is` prefix shadows real property names** (UAX44-LM3): `block_prefix/0` hard-maps every `Is*` name to `block=<rest>`, so `\p{IsAlphabetic}` and `[:IsLowercase:]` error instead of resolving to the binary properties.
* **Neither TR61 empty concept is representable**: `[]` (empty set) and `[{}]` (empty-string member) both ParseError; only `[-]` parses, and then crashes reduce.
* **`\N{...}` is unsupported and raises** rather than returning a clean error; TR61's three forms (`\N{NAME}`, `\N{HEX:NAME}`, `\N{HEX:literal:NAME}`) are not modelled.
* **UTS18/ICU-regex double operators `&&` `--` (`||` `~~`)** are not accepted by the standalone parser. This is an intentional TR35 choice — the library implements the single-operator form — but it should be declared as a TR61-C2/C3 restriction/tailoring rather than left implicit.
* **String-literal space-sensitivity** (TR61 Draft 2) and the single- vs double-operator token choice are not documented as tailorings.
* **No TR61 conformance profile** (C1 syntactically complete + minimally consistent, C2 declared lexical restrictions, C3 declared tailorings) is published; several lexical elements currently raise rather than reject, which fails C1 minimal consistency outright.

## 6. Robustness issues

The recurring robustness theme is that the public API's tagged-tuple contract is porous. `parse/1` is specced `{:ok, t} | {:error, {module, binary}}` but raises `ArgumentError` (bad hex / `\U` / `\N`), `FunctionClauseError` (`\u{...}`, `[-]`, union-of-complements, unequal string ranges — the last even at macro-**compile** time, aborting the whole compilation unit), and `UndefinedFunctionError` (`\p{emoji=...}`). `to_pattern`/`compile_pattern` raise on complement sets; `to_regex_string` returns `{:ok, uncompilable}` for reversed and single-surrogate ranges; `compile/2`/`expand_regex/1` raise instead of returning `{:error, {message, index}}`; and `match?/2` crashes on an empty-string input. None of these are happy-path, but they are all reachable from ordinary or lightly-malformed input, and the guard-vs-function divergence (a set that compiles as a guard but crashes as a function, ROB-04) is a particularly surprising trap.

## 7. Recommendations

**Architecture.**

1. Make the range primitives self-defending. Reinstate the merging `union/2` (operation.ex:278-315) so it compacts, and have `intersect/2` / `difference/2` either normalise (sort + compact) or assert their sorted-disjoint precondition. This one change fixes SOC-1/2/3/4 and removes the SOP-1 corruption path.
2. Rebuild the escape lexer once, comprehensively: split `is_hex_digit` into a true hex guard; add named control branches for `\a \b \e \v \f`; add `\U`, single-digit `\x`, bracketed `\u{...}`/`\x{...}` (including multi-codepoint), octal, and `\cX`; and route every unresolved backslash+char to the literal character.
3. Seal the contract boundary: wrap the parser and property resolution so *any* exception becomes `{:error, {Unicode.Set.ParseError, message}}`. No specced tagged-tuple function should ever raise.
4. Escape string members and split surrogate blocks in the regex emitter; wrap all string/string-range alternations in `(?:...)`; and represent `[-]` as `{:in, []}` rather than the raw string.
5. Harden the `Unicode.Regex` splitter for `\Q...\E`, escaped backslashes inside classes, and `(?#...)` comments, or document these as unsupported.

**API.**

* Fix the guard-vs-function divergence so a set behaves identically in both `match?/2` contexts.
* Either implement single-quote quoting, `\N{...}`, `[]`/`[{}]`, and boundary hyphens, or reject them with a clean tagged error and document the restriction — never mis-parse silently.
* Correct the README (Sundanese, `\p{gc=...}`, the `[:Zs:]` example) and publish a TR61 C1/C2/C3 conformance statement enumerating the supported lexical-element subset and the deliberate tailorings (single-operator tokens, string-range extension, `[-]` for the empty set).

## 8. Phased implementation plan

**Phase 0 — Documentation quick wins (~0.5 day).** Fix README typos (Sundanese, `\p{gc=}`, single-dash `print`), fix the `to_regex_string/1` doc example, remove the dead `:parse_many` combinator. Zero risk; ship immediately.

**Phase 1 — Contract boundary / stop the crashes (~2–3 days).** Convert all lower-layer raises into `{:error, _}` (ROB-01, PS-4, RS-3); make `[-]` reduce to `{:in, []}` end-to-end (ROB-03); add the missing exhaustiveness clauses (empty-binary `member?/2` ROB-08, `:not_in` in `reject_string_range/3` ROB-06, union-of-complements in `not_in_has_no_string_ranges/1` and `build_search_tree/1` ROB-04); convert complement raises in `to_pattern`/`compile_pattern` to tagged errors and handle single-surrogate sets (ROB-05, ROB-09/RE-5). Highest-leverage robustness work; unblocks safe use on untrusted input.

**Phase 2 — Escape lexer correctness (~3–4 days).** Split `is_hex_digit` (LEX-1/ROB-02); add named control branches (GAP-CTRL-ESC-1); add `\U`, single-digit `\x`, bracketed `\u{...}`/`\x{...}` incl. multi-codepoint (LEX-3, LEX-2, GAP-XSINGLE); add octal and `\cX` (GAP-OCTAL-C); implement or cleanly reject single-quote quoting (LEX-4); fix leading-whitespace capture (LEX-5).

**Phase 3 — Set-operation correctness (~3–5 days).** Reinstate the merging `union/2` (SOC-2); normalise/assert in `intersect`/`difference` (SOC-4, which also fixes SOC-1 and SOC-3); implement left-to-right associativity across juxtaposition boundaries by threading an accumulator through `reduce_set_operations` (SOP-1); add range-ordering and string-range-length validation (SR-4/ROB-07, SR-2).

**Phase 4 — Regex emission correctness (~4–6 days).** PCRE-escape string branches and guarantee compilable output (RE-1); split surrogate blocks (RE-2, CU-1); fix the `[[][]]` class and wrap all string alternations in `(?:...)` (SR-1/RE-3, RE-4/SR-3); harden the splitter for `\Q..\E`, `\\`, and `(?#..)` (RS-1, RS-2, RS-4); model complement-of-strings per ICU (SR-5/CU-2).

**Phase 5 — Property coverage (~3–5 days, partly upstream in the `unicode` dep).** Add `scx` with containment semantics (PS-2); add Age/Bidi_Class/Numeric_Value/Numeric_Type (PS-3); ignore hyphens in property-name matching and resolve loose-matched names before the `Is`→Block fallback (PS-1, GAP-ISPREFIX); fix the block normalizer for digit-bearing names (PS-7); optionally accept the `In` prefix (PS-8).

**Phase 6 — TR61 formalization alignment (~1–2 weeks).** Support `[]` and `[{}]` distinctly (GAP-EMPTY); support boundary literal hyphens (GAP-HYPHEN-1); implement or cleanly reject `\N{...}` in TR61's three forms (GAP-N-CLEAN); decide and document string-literal space sensitivity and the operator-token choice (GAP-STRING-SPACE, GAP-DOUBLE-OP); publish the C1/C2/C3 conformance profile (GAP-TR61-CONF). Lowest priority — do this after the core is correct.

Sequencing rationale: quick wins and the contract boundary first (they stop crashes and are prerequisites for trusting later test output), then the two silent-wrong-output clusters (escapes, then set operations), then the regex emitter, then property breadth, and finally TR61 formalization once the foundation is sound.