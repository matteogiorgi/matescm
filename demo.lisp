;; demo.lisp — a little show-off tour of the mate.scm language.
;;
;; Run it with:
;;   ./matescm demo.lisp
;;
;; Each expression below is evaluated in turn by the interpreter and
;; printed as `expr => result`. Nothing here is special syntax: this
;; is exactly the same s-expression language `ev` understands, just
;; read from a file instead of being passed as a quoted form.

;; --- arithmetic ---
(+ 1 2)
(* 6 7)
(+ (* 2 3) (- 10 4))

;; --- comparisons and if (0 is false, anything else is true) ---
(if (< 3 5) 1 0)
(if (< 5 3) 1 0)

;; --- let: a single binding, visible only in the body ---
(let x 5 (* x x))

;; shadowing: the inner `x` hides the outer one within its own body
(let x 5 (let x (+ x 1) (* x x)))

;; --- lambda and closures ---
((lambda (x y) (+ x y)) 3 4)

;; a closure that captures its defining environment
(let add5 (lambda (x) (+ x 5)) (add5 10))

;; a curried "adder factory": the inner lambda closes over `n`
(let make-adder (lambda (n) (lambda (x) (+ x n)))
  (let add5 (make-adder 5) (add5 3)))

;; --- higher-order functions: closures passed around like any value ---
(let apply-twice (lambda (f x) (f (f x)))
  (let inc (lambda (x) (+ x 1))
    (apply-twice inc 5)))

;; --- letrec: recursion by name ---
(letrec fact (lambda (n) (if (< n 2) 1 (* n (fact (- n 1)))))
  (fact 10))

(letrec fib (lambda (n) (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))
  (fib 10))

(letrec ack (lambda (m n)
              (if (< m 1) (+ n 1)
                (if (< n 1) (ack (- m 1) 1)
                  (ack (- m 1) (ack m (- n 1))))))
  (ack 2 3))

;; --- recursion without letrec, via the Z (applicative-order Y)
;; combinator: self-reference built purely from lambda and
;; self-application, no help from the interpreter needed.
(let Z (lambda (f)
         ((lambda (x) (f (lambda (v) ((x x) v))))
          (lambda (x) (f (lambda (v) ((x x) v))))))
  (let fact-gen (lambda (self) (lambda (n) (if (< n 2) 1 (* n (self (- n 1))))))
    ((Z fact-gen) 10)))
