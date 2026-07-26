;; Test/showcase suite for the interpreter defined in mate.scm.
;; This file is plain host Scheme (run directly by e.g. guile), not
;; code executed by the toy interpreter itself. It loads mate.scm to
;; get access to `ev` and `global`, then drives the interpreter with
;; a series of quoted expressions in the toy language, checking each
;; result against an expected value.
(load "mate.scm")
(use-modules (ice-9 format))

;; Running totals, updated by `check` below and printed in the final
;; summary.
(define ok-count 0)
(define fail-count 0)

;; section: print a blank-line-padded "=== title ===" banner, so
;; groups of related checks are visually separated instead of
;; running into each other.
(define (section title)
  (newline)
  (format #t "=== ~A ===~%" title)
  (newline))

;; check: evaluate `expr` (a quoted toy-language expression) in the
;; global environment, compare it against `expected`, and print a
;; one-line PASS/FAIL report labelled `name`. The name column is
;; padded to a fixed width so the "=>" values line up. Side-effects
;; on ok-count/fail-count let the summary at the bottom report totals
;; without threading state through every call.
(define (check name expr expected)
  (let* ((actual (ev expr global))
         (pass? (equal? actual expected)))
    (format #t "  ~16A => ~A" name actual)
    (if pass?
      (begin (display "  [OK]")
             (set! ok-count (+ ok-count 1)))
      (begin (format #t "  [FAIL, expected ~A]" expected)
             (set! fail-count (+ fail-count 1))))
    (newline)))

;; --- Basic arithmetic ---
;; Exercises the three numeric primitives wired up in `global`
;; (+, -, *) plus nested application (an expression's arguments can
;; themselves be arbitrary sub-expressions, not just literals).
(section "basic arithmetic")
(check "sum"            '(+ 1 2)        3)
(check "subtraction"    '(- 10 3)       7)
(check "multiplication" '(* 6 7)        42)
(check "composition"    '(+ (* 2 3) (- 10 4)) 12)

;; --- Comparisons and if ---
;; `<` returns 1/0 (see mate.scm), and `if` treats 0 as false and
;; anything else as true. These cases confirm both the truthy and
;; falsy branches are taken correctly, including when `if` itself is
;; nested inside another `if`'s branch.
(section "comparisons and if")
(check "less-than-true"  '(if (< 3 5) 1 0) 1)
(check "less-than-false" '(if (< 5 3) 1 0) 0)
(check "nested-if"       '(if (< 1 2) (if (< 2 1) 10 20) 30) 20)

;; --- let and shadowing ---
;; `let` binds a single name to the value of an expression evaluated
;; in the *outer* scope, then evaluates its body with that binding
;; added. The second case nests two `let`s using the same name `x`
;; to confirm the inner binding shadows the outer one correctly
;; (env is a list, and `assq` finds the innermost/most-recent match
;; first since it was consed onto the front).
(section "let and shadowing")
(check "simple-let"    '(let x 5 (* x x)) 25)
(check "let-shadowing" '(let x 5 (let x (+ x 1) (* x x))) 36)

;; --- lambda and closures ---
;; A `lambda` immediately applied to arguments; a closure built with
;; `let` that captures its enclosing binding (`add5` closes over the
;; constant 5... actually over nothing free here, just itself); and
;; a curried "adder factory" where the outer lambda returns an inner
;; lambda that closes over the outer parameter `n`, demonstrating
;; that closures correctly retain their defining environment.
(section "lambda and closures")
(check "direct-lambda" '((lambda (x y) (+ x y)) 3 4) 7)
(check "closure"       '(let add5 (lambda (x) (+ x 5)) (add5 10)) 15)
(check "curried-adder"
       '(let make-adder (lambda (n) (lambda (x) (+ x n)))
          (let add5 (make-adder 5) (add5 3)))
       8)

;; --- Higher-order functions ---
;; Functions are first-class values in this language: `apply-twice`
;; takes another function `f` as an argument and calls it twice,
;; showing that closures (like `inc` here) can be passed around and
;; invoked through a parameter just like any other value.
(section "higher-order functions")
(check "apply-twice"
       '(let apply-twice (lambda (f x) (f (f x)))
          (let inc (lambda (x) (+ x 1))
            (apply-twice inc 5)))
       7)

;; --- Recursion via letrec ---
;; `letrec` is what makes a function able to call itself by name
;; (see the detailed explanation in mate.scm). Factorial and
;; Fibonacci are the classic examples; the two-argument Ackermann
;; function additionally shows that `letrec`-bound functions can take
;; multiple parameters and recurse with deeply nested/non-trivial
;; call patterns (still fast enough for these small inputs despite
;; this being a naive, non-optimizing interpreter).
(section "recursion via letrec")
(check "factorial-10"
       '(letrec fact (lambda (n) (if (< n 2) 1 (* n (fact (- n 1)))))
          (fact 10))
       3628800)
(check "fibonacci-10"
       '(letrec fib (lambda (n) (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))
          (fib 10))
       55)
(check "ackermann-2-3"
       '(letrec ack (lambda (m n)
                      (if (< m 1) (+ n 1)
                        (if (< n 1) (ack (- m 1) 1)
                          (ack (- m 1) (ack m (- n 1))))))
          (ack 2 3))
       9)

;; --- Summary ---
;; Final tally of how many `check` calls passed vs. failed.
(section "summary")
(format #t "OK: ~A  FAIL: ~A~%" ok-count fail-count)
(newline)
