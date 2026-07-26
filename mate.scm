;; A minimal Scheme interpreter, written in (host) Scheme.
;;
;; Environments are represented as association lists mapping
;; `name -> box`, where a box is a 1-slot mutable cell (implemented
;; here as a 1-element vector). Using boxes instead of storing raw
;; values directly means that once a binding is created its cell can
;; be mutated in place (see `letrec` below), which is what lets a
;; recursive function's own name resolve to itself.

;; box: allocate a fresh mutable cell holding `v`.
(define (box v)     (vector v))
;; unbox: read the current value stored in a box.
(define (unbox b)   (vector-ref b 0))
;; set-box!: mutate a box in place to hold a new value `v`.
(define (set-box! b v) (vector-set! b 0 v))

;; bind: extend `env` with one box per (parameter, value) pair.
;; `ps` is a list of parameter names, `vs` the list of argument
;; values to bind them to (assumed to be the same length as `ps`).
;; Returns a new environment; the original `env` is left untouched
;; since association lists are extended by consing, never mutated.
(define (bind ps vs env)
  (if (null? ps)
    env
    (cons (cons (car ps) (box (car vs)))
          (bind (cdr ps) (cdr vs) env))))

;; ev: evaluate expression `x` in environment `env`.
;; `x` is a plain host s-expression representing an expression in the
;; toy language; `ev` walks it structurally (a classic tree-walking
;; interpreter, no separate parsing/compilation step).
(define (ev x env)
  (cond
    ;; Self-evaluating literal: a number evaluates to itself.
    ((number? x) x)
    ;; Variable reference: look up `x` in the environment (an alist
    ;; of (name . box)) and unbox its current value. `assq` compares
    ;; keys with `eq?`, which is fine since symbols are interned.
    ;; Referencing an unbound name is a hard error.
    ((symbol? x) (let ((c (assq x env)))
                   (if c (unbox (cdr c)) (error "unbound" x))))
    ;; (if test then else)
    ;; The language has no dedicated boolean type: the numeric value
    ;; 0 stands for "false" and anything else (see the `<` primitive
    ;; below) stands for "true". `eqv? 0` is the falsity test.
    ((eq? (car x) 'if)
     (if (eqv? 0 (ev (cadr x) env))
       (ev (cadddr x) env)
       (ev (caddr x) env)))
    ;; (let name value-expr body)
    ;; Single-binding, non-recursive let: evaluate `value-expr` in
    ;; the *current* environment (the new name is not yet visible to
    ;; it), then evaluate `body` with `name` bound to that value.
    ((eq? (car x) 'let)
     (ev (cadddr x) (bind (list (cadr x)) (list (ev (caddr x) env)) env)))
    ;; (letrec name value-expr body)
    ;; Recursive binding, needed to define self-referencing functions
    ;; (e.g. a `lambda` that calls itself by `name`). The trick:
    ;; 1. Allocate the box first and add `name -> box` to the
    ;;    environment (`e`), with a placeholder value (0) inside.
    ;; 2. Evaluate `value-expr` in `e`, so if it is a `lambda`, the
    ;;    closure it produces captures `e` and can therefore see
    ;;    `name` once the box is filled in.
    ;; 3. Mutate the box in place (`set-box!`) to hold the real
    ;;    value, "tying the knot" so `name` now refers to itself.
    ;; 4. Evaluate `body` in `e`, where `name` is fully available.
    ((eq? (car x) 'letrec)
     (let* ((b (box 0))
            (e (cons (cons (cadr x) b) env)))
       (set-box! b (ev (caddr x) e))
       (ev (cadddr x) e)))
    ;; (lambda (param ...) body)
    ;; Produces a host-language closure over `env`. Calling it later
    ;; (as a host procedure, via `apply` below) runs `body` in an
    ;; environment where each parameter is bound to the
    ;; corresponding argument, on top of the captured `env` — this is
    ;; what gives lexical scoping.
    ((eq? (car x) 'lambda)
     (lambda args (ev (caddr x) (bind (cadr x) args env))))
    ;; Function application: anything that isn't one of the special
    ;; forms above is treated as `(f arg ...)`. Evaluate the operator
    ;; and every operand (left to right, in `env`), then use the
    ;; host's own `apply`/`map` to actually call it. Since `lambda`
    ;; above produces real host procedures, and the primitives in
    ;; `global` are host procedures too, this one clause is enough to
    ;; drive both user-defined and built-in functions.
    (else
      (apply (ev (car x) env)
             (map (lambda (a) (ev a env)) (cdr x))))))

;; global: the initial (top-level) environment, wiring up the only
;; primitives the language provides. Each primitive is boxed just
;; like any user binding, so `ev`'s variable-lookup code path works
;; uniformly for both.
(define global
  (list (cons '+ (box +))
        (cons '- (box -))
        (cons '* (box *))
        ;; `<` is wrapped so it returns 1/0 instead of the host's
        ;; #t/#f, matching this language's "0 is false" convention
        ;; used by `if` above.
        (cons '< (box (lambda (a b) (if (< a b) 1 0))))))
