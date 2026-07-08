# Test Corpus YAML Schema

Each test case is stored as one YAML file under `test/corpus/<source>/`.
The file describes one formula and the expected solver result for that
formula.

## Required Fields

### `id`

Unique test identifier.

For simple corpus tests, use the format:

```text
ipl.simple.<number>
```

Numbers should be unique within the corpus.

### `source`

Name of the corpus group. This should match the directory name under
`test/corpus/`.

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

Expected logical result. This field contains two nested fields.

```yaml
expected:
  validity: valid
  satisfiability: sat
```

Allowed `validity` values:

- `valid`: the formula is valid
- `invalid`: the formula is not valid

Allowed `satisfiability` values:

- `sat`: the formula is satisfiable
- `unsat`: the formula is not satisfiable

### `formula`

Formula string to test. Keep it quoted.

Current corpus formulas use these connectives:

- `not`
- `and`
- `or`
- `->`
- `<->`
