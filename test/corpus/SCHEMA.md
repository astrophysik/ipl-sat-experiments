# Test Corpus YAML Schema

Each test case is stored as one YAML file under `test/corpus/<source>/`.
The file describes one sequent and the expected solver result for that
sequent.

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
- `topes`: propositional tope sequents harvested from sHoTT `entailM` queries

### `tags`

Inline YAML list of lowercase labels that describe the formula. Tags are used
for grouping and filtering tests.

Common tags:

- `classical-separator`: valid classically, but not valid intuitionistically
- `conjunction`
- `contradiction`
- `de-morgan`
- `disjunction`
- `identity`
- `implication`
- `introduction`
- `negation`
- `projection`
- `transitivity`

### `expected`

Expected logical result.

```yaml
expected:
  validity: valid
```

Allowed `validity` values:

- `valid`: the formula is valid
- `invalid`: the formula is not valid

For tope sequents, `validity` means derivability of `Ξ | Φ ⊢ ψ`.

Optional `premises_consistency` values for sequent cases:

- `consistent`: `Ξ | Φ ⊬ ⊥`
- `inconsistent`: `Ξ | Φ ⊢ ⊥`

For IPL proof search, `validity` is the primary result: the solver checks
derivability of the sequent `hypotheses ⊢ goal`. Do not add
`satisfiability` to IPL proof-search cases. A formula may be neither derivable
nor refutable intuitionistically, so classical `sat`/`unsat` is not the solver
contract here.

Allowed `satisfiability` values for future existential/model-search tasks:

- `sat`: the formula is satisfiable
- `unsat`: the formula is not satisfiable

### `hypotheses`

Optional list of formula strings used as the left side of the sequent. Use an
empty list for closed formulas. New corpus entries should include this field
explicitly, even when it is empty, because instrumented `entailM` cases are
sequents rather than closed formulas.

```yaml
hypotheses: []
goal: "p → p"
```

### `context`

Optional cube-layer context `Ξ`, as a list of declarations. This is empty or
absent for pure IPL cases and explicit for tope cases.

```yaml
context:
  - "(t, s) : 2 × 2"
```

### `goal`

Formula string used as the sequent goal. Keep it quoted.

### `provenance`

Structured description of where the task came from. Use this to distinguish
handwritten examples, instrumented `entailM` queries, sHoTT judgments, diagram
rendering goals, or external benchmark converters.

```yaml
provenance:
  kind: handwritten
  note: "handwritten IPL separator"
```

Common `kind` values are `handwritten`, `harvested`, `external`, and
`speculative`. Add `ref` when the task comes from a file, log line, or external
benchmark id.

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
