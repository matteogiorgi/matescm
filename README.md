# Mate Scheme

A tiny Scheme interpreter, written in Scheme, in about 40 lines of code. It's a toy/educational "meta-circular interpreter": it defines a very minimal language and evaluates it through a classic tree-walking interpreter (`ev`), with no separate parsing or compilation phase — expressions are just s-expressions read by the host Scheme.




## Repo layout

- [`mate.scm`](mate.scm) — the interpreter: environment representation, `bind`, `ev`, and the global environment with the available primitives.
- [`tests.scm`](tests.scm) — test/showcase suite: loads `mate.scm` and runs a series of example expressions, checking each result against an expected value and printing a report.
- [`matescm`](matescm) — executable runner: loads `mate.scm` and evaluates every top-level expression from a file given on the command line, printing `expression => result` for each.
- [`demo.lisp`](demo.lisp) — a showcase file for `matescm`: a tour of the language's features, from arithmetic up to recursion via `letrec` and via the Y (Z) combinator.




## The language

The environment is represented as an association list `(name . box)`, where `box` is a mutable cell (a 1-element vector). This is what enables the "tying the knot" trick used by `letrec` to implement recursion.

The forms supported by `ev` are:

| Form | Meaning |
|---|---|
| `n` (number) | self-evaluating literal |
| `s` (symbol) | variable lookup in the environment |
| `(if test then else)` | `0` is false, anything else is true |
| `(let name val body)` | single, non-recursive binding |
| `(letrec name val body)` | recursive binding, for functions that call themselves |
| `(lambda (param ...) body)` | creates a closure over the current environment |
| `(f arg ...)` | function application (the default case) |

Primitives available in `global`: `+`, `-`, `*`, `<` (the latter returns `1`/`0` instead of `#t`/`#f`, consistent with the language's truthiness convention).

Since there isn't much else, the language lacks: strings, lists, native booleans, a multi-clause `cond`, `set!`, multiple bindings in a single `let`, and any error handling beyond a generic `error` for unbound variables.




## Running it

You need a host Scheme with `load` and `(ice-9 format)` (used to align the test output); the project was developed and tested with [Guile](https://www.gnu.org/software/guile/).

```bash
guile tests.scm
```

To use the interpreter interactively:

```bash
guile
```
```scheme
(load "mate.scm")
(display (ev '(letrec fact (lambda (n) (if (< n 2) 1 (* n (fact (- n 1)))))
                (fact 10))
             global))
```

To run a file of toy-language expressions and see each result, use `matescm` (a small executable Guile script, no `quote` needed — the file is read directly as data):

```bash
./matescm demo.lisp
```

Any file works, not just `demo.lisp`: `matescm` just reads one top-level expression at a time from the given path and evaluates each in `global`, so it doubles as a REPL-less way to try out your own snippets.

`matescm` is a plain executable text file, not a compiled binary. It opens with the classic portable shebang trick for Guile scripts:

```sh
#!/bin/sh
exec guile -q --no-auto-compile -s "$0" "$@"
!#
```

`/bin/sh` runs first — a fixed path present on virtually every Unix system — and immediately `exec`s into `guile -s`, resolved via `$PATH`, passing itself (`$0`) as the script to run and forwarding any extra arguments (`$@`); the `!#` line closes that leading block so Guile's reader treats it as a comment and continues with the Scheme code below it. This two-line indirection is the standard portable shebang trick for Guile scripts: a plain `#!/usr/bin/env guile ...` shebang can't reliably take multiple flags (like `-q --no-auto-compile -s` here) on every system, since the kernel passes everything after the interpreter path as a single, unsplit argument. The rest of the file is ordinary Guile: it finds its own directory via `(command-line)` to `load` `mate.scm` from there (not from the caller's working directory), then reads and evaluates each expression from the file given as an argument.

To run `matescm` from anywhere without the leading `./`, symlink it into a directory on your `PATH`, e.g. `~/.local/bin` (from the repo root, creating the directory first if it doesn't exist yet):

```bash
mkdir -p ~/.local/bin
ln -s "$(pwd)/matescm" ~/.local/bin/matescm
```

With that in place (and `~/.local/bin` on your `$PATH`), `matescm demo.lisp` works from any directory, system-wide for your user.




## Possible future work

Some directions for extending the language or the interpreter:

- **`cond`/`begin`** — a multi-clause `cond` and a `begin` for sequencing multiple expressions (currently `let`/`lambda` bodies are a single expression, with no way to run intermediate side effects).
- **Multi-binding `let`** — today `let` binds a single name; it would be natural to extend it to multiple `(name val)` pairs like standard Scheme, reusing `bind`, which already supports lists.
- **Native booleans and types** — a real boolean type (or at least `#t`/`#f`) instead of the "0 = false" convention, plus strings and/or lists (cons cells) handled by the interpreted language itself.
- **Top-level `define`** — being able to add functions/values to `global` without nesting everything inside `letrec`/`let`.
- **`set!`** — mutating already-bound variables, reusing the boxes already present in the environment.
- **Mutual recursion** — the current `letrec` only binds one name, so two functions can't call each other; a `letrec*` or a multi-binding `letrec` would fix this.
- **Better error messages** — including the position within the original expression, not just the name of the unbound variable.
- **Tail-call optimization** — `ev` currently recurses on the host stack for every call; without TCO, deep recursion (e.g. numeric loops) can exhaust the stack.
- **A dedicated reader/parser** — right now expressions are written as "host" Scheme s-expressions (via `quote`); a parser that reads its own textual syntax would make the project a more self-contained interpreter, less dependent on its host.
- **More examples in `tests.scm` and `demo.lisp`** — `demo.lisp` already shows recursion without `letrec` via the Y (Z) combinator; more such examples would further showcase the language's expressiveness even within its limits.




---

Dedicated to my mates.
