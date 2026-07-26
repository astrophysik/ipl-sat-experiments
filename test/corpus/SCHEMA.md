# Test Corpus YAML Schema

Each test case is stored as one YAML file under `test/corpus/<source>/`.
There are two case kinds:

- a sequent case, which describes `Ξ | Φ ⊢ ψ` and the expected solver result
- an Rzk case, which points to a self-contained `.rzk` file and records whether
  the typechecker should accept or reject it

## Fields

### `id`

Unique test identifier. Derive this from the relative corpus path so ids stay
stable when files are reordered.

For simple corpus tests, use the format:

```text
ipl.simple.<file-stem>
```

For example, `test/corpus/simple/peirce-law.yaml` has id
`ipl.simple.peirce-law`.

### `source`

Name of the corpus group. This should match the directory name under
`test/corpus/`.

Current corpus groups:

- `simple`: textbook IPL formulas
- `topes`: propositional tope sequents
- `shott`: end-to-end Rzk files exercising the tope layer through the
  typechecker

### `kind`

Case kind. This determines the shape of `input` and `expected`.

Allowed values:

- `sequent`: direct solver case for a sequent `Ξ | Φ ⊢ ψ`
- `rzk`: end-to-end Rzk typechecker case

### `tags`

Inline YAML list of lowercase labels that describe the case. Tags are used
for grouping and filtering tests. Prefer stable semantic tags over incidental
details of a particular harvested query.

Slice and provenance tags:

- `tope-prop`: propositional tope sequent over the cube/tope layer
- `harvested`: selected from instrumented `entailM` output

IPL tags:

- `classical-separator`: valid classically, but not valid intuitionistically;
  use this for pure IPL separators, not for geometric underivability
- `contradiction`: goal or formula expresses inconsistency directly
- `de-morgan`: De Morgan law
- `identity`: identity/axiom-like formula
- `introduction`: introduction rule pattern

Logical connective tags:

- `conjunction`: uses `∧`
- `disjunction`: uses `∨`
- `implication`: uses `→`
- `negation`: uses `¬`
- `top`: uses `⊤`

Tope structure tags:

- `eq`: uses interval/cube-term equality `≡`
- `leq`: uses directed interval order `≤`
- `coverage`: coverage or shape-inclusion condition
- `degenerate`: degenerate face or shape condition
- `horn`: horn-shape condition
- `consistency`: explicitly checks whether premises derive `⊥`

Rule-pattern tags:

- `antisymmetry`: order antisymmetry, typically deriving equality from two
  opposite inequalities
- `linearity`: directed interval linearity, typically deriving one of two
  comparable orders
- `projection`: goal is one component already present in the premises
- `reflexivity`: uses reflexivity of equality or order
- `transitivity`: uses transitivity of implication or directed interval order

### `input` for sequent cases

Input sequent data.

```yaml
input:
  context:
    - "(t, s) : 2 × 2"
  hypotheses:
    - "s ≡ 0₂ ∨ t ≡ 1₂"
  goal: "s ≤ t"
```

`context` is cube-layer context `Ξ`, as a list of declarations. Use `[]` when
the case is purely propositional.

`hypotheses` is tope context `Φ`, as a list of formulas taken conjunctively.
Use `[]` for closed formulas or goals derivable outright.

`goal` is formula string used as sequent goal `ψ`. Keep it quoted.

### `input` for Rzk cases

Input Rzk file data.

```yaml
input:
  rzk: horn-inclusion.rzk
```

`rzk` is the name of the `.rzk` file for an Rzk case. The file is a sibling of
the YAML file and should use the same basename.

### `expected` for sequent cases

Expected logical result.

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

### `expected` for Rzk cases

Expected typechecker result.

```yaml
expected:
  typechecks: accepted
```

Allowed `typechecks` values:

- `accepted`: the Rzk file should typecheck
- `rejected`: the Rzk file should be rejected

For rejected cases, add `error_contains`, a diagnostic substring that should be
present in the error. This guards against passing because of an unrelated
syntax or name-resolution failure.

```yaml
expected:
  typechecks: rejected
  error_contains: "tope"
```

### `provenance`

Structured description of where the task came from. Use this to distinguish
handwritten examples, sHoTT judgments, diagram
rendering goals, or external benchmark converters.

```yaml
provenance:
  kind: handwritten
  note: "handwritten IPL separator"
```

Allowed `kind` values:

- `handwritten`: written by hand for the corpus
- `harvested`: collected by instrumenting a typechecker
- `external`: converted from an external benchmark set
- `speculative`: the judgement, or its syntax, is our own proposal and does not
  correspond to anything Rzk currently accepts

## Formula Grammar

Current corpus formulas use these connectives:

- `¬`
- `∧`
- `∨`
- `→`
- `↔`
- `⊤`
- `⊥`
- `≡`
- `≤`

Atoms are identifiers beginning with a letter and followed by letters, digits,
subscripts, underscores, apostrophes, or hyphens. Parentheses may be used
anywhere to disambiguate. Tope terms additionally use tuple syntax such as
`(t, s)` and projections such as `π₁ x`.

Precedence, from strongest to weakest:

1. Parentheses: `(φ)`
2. Atomic topes: `⊤`, `⊥`, `a ≡ b`, `a ≤ b`
3. Negation: `¬φ`
4. Conjunction: `φ ∧ ψ`, left-associative
5. Disjunction: `φ ∨ ψ`, left-associative
6. Implication: `φ → ψ`, right-associative
7. Biconditional: `φ ↔ ψ`, non-associative; parenthesize chains explicitly

For example, `p ∧ q → p` parses as `(p ∧ q) → p`, and
`p → q → r` parses as `p → (q → r)`.

## Examples

### Sequent case

```yaml
id: topes.horn-inclusion
kind: sequent
source: topes
tags: [tope-prop, eq, leq, horn, coverage, harvested]
provenance:
  kind: harvested
  note: "Horn face condition entails membership in the triangle."
input:
  context:
    - "(t, s) : 2 × 2"
  hypotheses:
    - "s ≡ 0₂ ∨ t ≡ 1₂"
  goal: "s ≤ t"
expected:
  entailment: derivable
  premises_consistency: consistent
```

### Rzk case

```yaml
id: shott.horn-inclusion
kind: rzk
source: shott
tags: [tope-prop, eq, leq, horn, coverage]
provenance:
  kind: handwritten
  note: "The shape inclusion behind every Segal-type horn filler."
input:
  rzk: horn-inclusion.rzk
expected:
  typechecks: accepted
```
