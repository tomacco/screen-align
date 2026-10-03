# Contributing

Thanks for helping. A few things keep reviews quick.

## Before you start

Open an issue for anything larger than a bug fix, so we can agree on the approach first.

## Code standards

ScreenAlign follows [Primera Plana](https://github.com/tomacco/primera-plana), Swift edition:

- Public methods are short lists of named steps. A reviewer should understand a type by reading only its public methods.
- Details go into private methods in a `// MARK: - Leaves` extension below the public API.
- No force unwraps, `try!` or `as!`. Use `guard` with early return.
- Errors are enums with associated values. Operations that can fail return `Result`.
- Anything that touches the system sits behind a protocol (see `DisplayArrangement`), so the logic stays testable.

## Where things go

- Logic that can be tested without a screen goes in `Sources/ScreenAlignCore`, with tests in `Tests/ScreenAlignCoreTests`.
- AppKit code (windows, drawing, input) goes in `Sources/ScreenAlign`.

## Checks

```bash
make test
make install   # then try it on real screens
```

Pull requests run the same build and tests in CI. Keep diffs small and focused on one change.
