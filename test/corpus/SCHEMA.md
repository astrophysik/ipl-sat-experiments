# Test Corpus YAML Schema

Each test case is stored as one YAML file under `test/corpus/<source>/`. There
are two kinds of case.

A **sequent case** describes one entailment judgement

```text
Ξ | Φ ⊢ ψ
```

together with the expected result. Here `Ξ` is the cube-layer context (variable
declarations), `Φ` is the tope context (a set of topes, understood
conjunctively), and `ψ` is the goal. Such a case tests a tope solver on its own.

An **Rzk case** is a small Rzk file together with the expectation that Rzk's
typechecker accepts or rejects it. Such a case tests a solver in place, wired
into the typechecker, and so also covers how queries reach it. See
`shott/README.md`.

The judgement is intuitionistic throughout. Formulas valid classically but not
intuitionistically are expected to be *underivable*.

## Corpus groups

- `simple/` — textbook IPL formulas, in particular those separating classical
  from intuitionistic logic (sequent cases)
- `topes/` — propositional tope judgements over the directed interval (sequent
  cases)
- `shott/` — Rzk files exercising the tope layer, headed for whole sHoTT files
  (Rzk cases)
- `diagrams/` — existential goals from diagram rendering (sequent cases)

Where a fact appears in both forms, the two cases cross-reference each other in
`provenance.note`, and they should be changed together.

## Syntax

Formulas in YAML use Rzk's ASCII tope syntax, in every group. The `.rzk` files
of an Rzk case instead use Rzk's Unicode notation, as sHoTT does, so that they
can be read and copied verbatim; the two are the same language.

| notation  | meaning                        |
| --------- | ------------------------------ |
| `TOP`     | ⊤                              |
| `BOT`     | ⊥                              |
| `/\`      | conjunction                    |
| `\/`      | disjunction                    |
| `->`      | implication                    |
| `===`     | equality of cube terms         |
| `<=`      | order on the directed interval |
| `2`       | the directed interval cube     |
| `0_2`     | its bottom point               |
| `1_2`     | its top point                  |
| `*`       | product of cubes               |

There is no primitive negation: write `phi -> BOT`.

Note that Rzk's tope layer proper has no implication either — it is built from
`TOP`, `BOT`, `/\`, `\/`, `===` and `<=`, and entailment is a judgement rather
than a connective. Implication therefore appears only in the `simple/` group,
where the textbook formulas need it. This is also why cases are recorded as
sequents rather than as single formulas: a tope judgement cannot in general be
internalised into one formula.

Always quote formulas with **single** quotes. In double-quoted YAML scalars a
backslash starts an escape sequence, so `"s <= t /\ t <= s"` is either a parse
error or silently mangled; single-quoted scalars have no escapes.

## Fields common to both kinds

### `id`

Unique test identifier, of the form `<source>.<number>`, e.g. `topes.3`.
Numbers are unique within a group.

### `source`

Name of the corpus group, matching the directory name under `test/corpus/`.

### `tags`

Inline YAML list of lowercase labels. Every case carries at least one *slice*
tag, which is what the corpus is filtered by:

- `ipl`: pure intuitionistic propositional logic, no cube or tope structure
- `tope-prop`: propositional tope judgement
- `eq`: uses equality `===`
- `leq`: uses the order `<=`
- `exists`, `forall`: uses quantifiers
- `coverage`: a covering condition, as demanded by `recOR`

The remaining tags are descriptive and free-form: `classical-separator`,
`de-morgan`, `antisymmetry`, `transitivity`, `linearity`, `horn`, `boundary`,
`degenerate`, `draft`, and so on.

Use `classical-separator` for cases that are classically but not
intuitionistically derivable. These are the sharpest tests in the corpus: a
solver that accepts them is not intuitionistic.

Use `draft` for cases whose syntax is provisional, so that they can be excluded
from a slice until the syntax settles.

### `provenance`

Where the case comes from.

```yaml
provenance:
  kind: handwritten
  note: "antisymmetry of <= on the directed interval"
```

Allowed `kind` values:

- `handwritten`: written by hand for the corpus
- `harvested`: collected by instrumenting a typechecker
- `external`: converted from an external benchmark set
- `speculative`: the judgement, or its syntax, is our own proposal and does not
  correspond to anything Rzk currently accepts

For `external`, add a `ref` field identifying the source problem. External sets
are pulled in through a converter and not copied into the repository, so an
`external` case is a checked-in expectation about a problem that lives
elsewhere.

## Fields of a sequent case

### `context`

Cube-layer context `Ξ`, as a list of declarations `name : cube`. Empty list
when the case is purely propositional.

```yaml
context:
  - "t : 2"
  - "s : 2"
```

### `premises`

Tope context `Φ`, as a list of topes, taken conjunctively. Empty list for a
goal that should be derivable outright.

### `goal`

The goal tope `ψ`.

### `expected`

```yaml
expected:
  entailment: derivable
  premises_consistency: consistent
```

`entailment` is `derivable` or `underivable`: whether `Ξ | Φ ⊢ ψ` is derivable
intuitionistically.

`premises_consistency` is `consistent` or `inconsistent`: whether `Ξ | Φ ⊢ BOT`
is *not* derivable. This is a property of `Φ` alone, independent of the goal, so
two cases sharing a context agree on it. It is recorded separately because it is
its own query in Rzk's typechecker, and because it explains away the cases where
a goal is derivable only from an exploded context.

Note that we deliberately avoid the words `sat` and `unsat`. Satisfiability
presupposes an assignment of truth values, whereas a model of IPL is a Kripke
frame; consistency, `Φ ⊬ ⊥`, is what we actually check and is purely
proof-theoretic.

## Fields of an Rzk case

### `rzk`

Name of the `.rzk` file holding the case, a sibling of the YAML file with the
same basename.

### `expected`

```yaml
expected:
  typechecks: accepted
```

`typechecks` is `accepted` or `rejected`. For `rejected`, add `error_contains`,
a substring the diagnostic must mention, so that the case cannot pass because
the file failed for an unrelated reason such as a typo.

### `queries`

The tope queries the typechecker issues while checking the file, in the format
of a sequent case. Filled in by instrumentation, not by hand; `[]` until then.

## Example (sequent case)

```yaml
id: topes.3
source: topes
tags: [tope-prop, leq, eq, antisymmetry]
provenance:
  kind: handwritten
  note: "antisymmetry of <=; special case of a rule in entailM"
context:
  - "t : 2"
  - "s : 2"
premises:
  - "t <= s"
  - "s <= t"
goal: "t === s"
expected:
  entailment: derivable
  premises_consistency: consistent
```

## Example (Rzk case)

```yaml
id: shott.2
source: shott
tags: [tope-prop, eq, leq, horn, coverage]
provenance:
  kind: handwritten
  note: "accepting this file makes the horn inclusion an equality"
rzk: horn-inclusion-converse.rzk
expected:
  typechecks: rejected
  error_contains: "tope"
queries: []
```
