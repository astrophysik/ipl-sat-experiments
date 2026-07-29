# ipl-sat


## Tests

### ILTP corpus

The ILTP propositional benchmarks are treated as an external generated corpus
and are not stored in this repository. To download the ILTP archive and generate
the local YAML corpus, run:

```sh
scripts/fetch-iltp.sh
```

The script downloads the archive into `.cache/iltp/`, verifies its checksum,
extracts it, and runs the ILTP converter. The generated YAML files are written
to `test/corpus/iltp/` and should not be edited by hand.
