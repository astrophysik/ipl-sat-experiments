# Existential goals from diagram rendering

Rzk's tope layer has no quantifiers, so the syntax used in this group is our
own proposal and does not correspond to anything Rzk currently accepts:

```text
exists (t : 2), phi
```

with the bound variable declared as in the cube-layer context, and the body an
ordinary tope. Every case here is therefore tagged `draft` and has
`provenance.kind: speculative`, so that the group can be excluded from a slice
until step 6 fixes the syntax. Expected answers are about the mathematics and
should survive a change of notation; the strings will not.

Existential goals arise when a diagram is rendered and we need to know whether
a shape is inhabited, and where. A solver that answers only `derivable` is of
limited use here: rendering needs the witness. Whether witnesses become part of
the expected answer is left open until step 6.
