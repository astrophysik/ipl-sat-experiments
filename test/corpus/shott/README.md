# End-to-end cases: Rzk code

This group differs in kind from the others. A case is not an entailment
judgement but a small Rzk file, and the expected result is whether Rzk's
typechecker accepts it. The corpus is therefore usable for instrumenting Rzk
with different tope solvers — the current `entailM`, or ours — and checking the
solver in place, together with the typechecker.

That is strictly stronger than checking the solver in isolation, and catches
what `topes/` cannot: a context passed to the solver incomplete, premises lost
under substitution, or the saturation bailing out at its 100-tope cap. A solver
can answer every query in `topes/` correctly and still make Rzk reject a valid
file.

Each case is a pair of files with the same basename:

- `<name>.rzk` — a self-contained Rzk file, starting with `#lang rzk-1`
- `<name>.yaml` — the metadata, with `rzk: <name>.rzk`

Cases are self-contained on purpose: they define the shapes they use rather
than importing sHoTT, so that a failure localises to the case. Once the corpus
is wired to a real Rzk, the natural next step is to add whole sHoTT files as
`kind: harvested` cases, which is what makes "no regression on sHoTT" a
concrete claim.

## Expected result

```yaml
expected:
  typechecks: accepted
```

or, for a file that must be rejected,

```yaml
expected:
  typechecks: rejected
  error_contains: "TopeContext"
```

`error_contains` is a substring the diagnostic is expected to mention. Record
it for every rejected case: without it the case passes when the file fails for
an unrelated reason, a typo above all, and a rejected-case corpus that cannot
tell a solver failure from a syntax error is worse than no corpus.

## Solver queries

```yaml
queries: []
```

The list of tope queries the typechecker issues while checking the file. It is
left empty here: which queries are asked is a fact about the typechecker's
implementation, not something that can be derived from the file, so it has to
be filled in by instrumentation rather than by hand.

Once filled in, it turns each case into a golden test on the interaction
itself. Two solvers agreeing on `accepted` while disagreeing on the queries
asked is exactly the situation worth seeing — it is how a solver that is
correct but ten times as expensive shows up.

## Caveat

**These files have not been run through `rzk`.** They were written without a
local checkout, from the shapes as they are defined in sHoTT, so the syntax is
plausible but unverified — in particular the form of `recOR` (older versions
take the topes and branches as four arguments) and whether a `TOPE`-valued
definition may be used directly in a binder. Run them before relying on any of
it, and treat a `rejected` expectation as unconfirmed until the diagnostic has
been seen.
