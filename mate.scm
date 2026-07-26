;; ambiente: lista associativa (nome . box), box = vettore di 1 elemento
(define (box v)     (vector v))
(define (unbox b)   (vector-ref b 0))
(define (set-box! b v) (vector-set! b 0 v))

(define (bind ps vs env)
  (if (null? ps)
    env
    (cons (cons (car ps) (box (car vs)))
          (bind (cdr ps) (cdr vs) env))))

(define (ev x env)
  (cond
    ((number? x) x)
    ((symbol? x) (let ((c (assq x env)))
                   (if c (unbox (cdr c)) (error "unbound" x))))
    ((eq? (car x) 'if)
     (if (eqv? 0 (ev (cadr x) env))
       (ev (cadddr x) env)
       (ev (caddr x) env)))
    ((eq? (car x) 'let)
     (ev (cadddr x) (bind (list (cadr x)) (list (ev (caddr x) env)) env)))
    ((eq? (car x) 'letrec)
     (let* ((b (box 0))
            (e (cons (cons (cadr x) b) env)))
       (set-box! b (ev (caddr x) e))
       (ev (cadddr x) e)))
    ((eq? (car x) 'lambda)
     (lambda args (ev (caddr x) (bind (cadr x) args env))))
    (else
      (apply (ev (car x) env)
             (map (lambda (a) (ev a env)) (cdr x))))))

(define global
  (list (cons '+ (box +))
        (cons '- (box -))
        (cons '* (box *))
        (cons '< (box (lambda (a b) (if (< a b) 1 0))))))

(display (ev '(letrec fact (lambda (n) (if (< n 2) 1 (* n (fact (- n 1)))))
                (fact 10))
             global))
(newline)
