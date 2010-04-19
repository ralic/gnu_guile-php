;;; PHP for GNU Guile

;; Copyright (C) 2009 Free Software Foundation, Inc.

;; This library is free software; you can redistribute it and/or
;; modify it under the terms of the GNU Lesser General Public
;; License as published by the Free Software Foundation; either
;; version 3 of the License, or (at your option) any later version.
;; 
;; This library is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; Lesser General Public License for more details.
;; 
;; You should have received a copy of the GNU Lesser General Public
;; License along with this library; if not, write to the Free Software
;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
;; 02110-1301 USA

;;; Commentary:

;;; Code:

(define-module (language php compile-tree-il)
  #:use-module (language tree-il)
  #:use-module (ice-9 format)
  #:use-module (system base pmatch)
  #:export (compile-tree-il comp))

(define-syntax ->
  (syntax-rules ()
    ((_ (type arg ...))
     `(type ,arg ...))))

(define-syntax @implv
  (syntax-rules ()
    ((_ sym)
     (-> (@ '(language php impl) 'sym)))))

(define-syntax @impl
  (syntax-rules ()
    ((_ sym arg ...)
     (-> (apply (@implv sym) arg ...)))))

(define (empty-lexical-environment)
  '())

(define (compile-tree-il exp env opts)
  (values
   (parse-tree-il
    (comp exp (empty-lexical-environment)))
   env
   env))

(define (comp exp env)

  (pmatch exp
    
    ((begin ,form)
      (comp form env))
    ((begin . ,forms)
      `(begin ,@(map (lambda (x) (comp x env)) forms)))
    ((num ,n)
      (-> (const n)))
    ((string ,s)
      (-> (const s)))
    ((print ,x)
      (-> (apply (-> (primitive 'display)) (-> (const x)))))
    ((print-var ,x)
      (-> (apply (-> (primitive 'display)) (-> (toplevel (string->symbol x))))))
    ((var ,varname ,val)
      (-> (define (string->symbol varname) (comp val env))))
    ((var ,varname)
      (-> (define (string->symbol varname) (-> (const 'NULL)))))
    ((lambda ,formals ,body)
      (-> (lambda formals (comp body env))))
    ((call ,proc)
      (-> (apply (-> (primitive (string->symbol proc))))))
    ((call ,proc ,args)
      `(apply (primitive ,(string->symbol proc)) ,@(map (lambda(x) (comp x env)) args)))
    ((void)
      (-> (void)))

    (else
      (apply throw 'CompileError "Exp not implemented: " exp))))

