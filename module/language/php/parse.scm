
;; PHP for GNU Guile.

;; Copyright (C) 2010 Jon Herron

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

;;; Code:

;(include "tokenize.scm")

(define-module (language php parse)
  #:use-module (language php tokenize)
  #:use-module (system base lalr)
  #:export (read-php))

(define (syntax-error message . args)
  (apply throw 'ParseSyntaxError message args))

(define *eof-object* 
  (call-with-input-string "" read-char))

(define (read-php port)
  (let ((parse (make-parser)))
    (parse (make-tokenizer port) syntax-error)))

(define (make-parser)
  (lalr-parser 
    (T_ABSTRACT T_AND_EQUAL T_ARRAY T_ARRAY_CAST T_AS T_BAD_CHARACTER 
      T_BOOLEAN_AND T_BOOLEAN_OR T_BOOL_CAST T_BREAK T_CASE T_CATCH 
      T_CLASS T_CLASS_C T_CLONE T_CLOSE_TAG T_COMMENT T_CONCAT_EQUAL 
      T_CONST T_CONSTANT_ENCAPSED_STRING T_CONTINUE T_CURLY_OPEN 
      T_DEC T_DECLARE T_DEFAULT T_DIR T_DIV_EQUAL T_DNUMBER T_DOC_COMMENT 
      T_DO T_DOLLAR_OPEN_CURLY_BRACES T_DOUBLE_ARROW T_DOUBLE_CAST 
      T_DOUBLE_COLON T_ECHO T_ELSE T_ELSEIF T_EMPTY T_ENCAPSED_AND_WHITESPACE 
      T_ENDDECLARE T_ENDFOR T_ENDFOREACH T_ENDIF T_ENDSWITCH T_ENDWHILE 
      T_END_HEREDOC T_EVAL T_EXTENDS T_FILE T_FINAL T_FOR T_FOREACH 
      T_FUNCTION T_FUNC_C T_GLOBAL T_GOTO T_HALT_COMPILER T_IF 
      T_IMPLEMENTS T_INC T_INCLUDE T_INCLUDE_ONCE T_INLINE_HTML T_INSTANCEOF T_INT_CAST 
      T_INTERFACE T_ISSET T_IS_EQUAL T_IS_GREATER_OR_EQUAL T_IS_IDENTICAL 
      T_IS_NOT_EQUAL T_IS_NOT_IDENTICAL T_IS_SMALLER_OR_EQUAL T_LINE T_LIST 
      T_LNUMBER T_LOGICAL_AND T_LOGICAL_OR T_LOGICAL_XOR T_MINUS_EQUAL T_MOD_EQUAL T_MUL_EQUAL 
      T_NS_C T_NUM_STRING T_OBJECT_CAST T_OBJECT_OPERATOR T_OPEN_TAG 
      T_OPEN_TAG_WITH_ECHO T_OR_EQUAL T_PLUS_EQUAL T_PRINT T_PRIVATE T_PUBLIC 
      T_PROTECTED T_REQUIRE T_REQUIRE_ONCE T_RETURN T_SL T_SL_EQUAL T_SR 
      T_SR_EQUAL T_START_HEREDOC T_STATIC T_STRING T_STRING_CAST T_SWITCH 
      T_THROW T_TRY T_UNSET T_UNSET_CAST T_USE T_VAR T_VARIABLE T_WHILE 
      T_WHITESPACE T_XOR_EQUAL 

      open-paren close-paren open-brace close-brace open-bracket close-bracket 
      comma semi asteriks plus minus divide equals dot qmark null label
      greater-than less-than true false colon period)

    (Program   
      (SourceElements) : $1
      (*eoi*) : *eof-object*)

    (SourceElements  
      (SourceElement) : $1 
      (SourceElements SourceElement) : (if (and (pair? $1) (eq? (car $1) 'begin))
                                          `(begin ,@(cdr $1) ,$2)
                                          `(begin ,$1 ,$2)))

    (SourceElement
      (Statement) : $1
      (T_INLINE_HTML) : `(echo (string ,$1))
      (OpenTag) : $1
      (T_CLOSE_TAG) : `(void))

    (Statements
      (Statement) : $1
      (Statements Statement) : (if (and (pair? $1) (eq? (car $1) 'begin))
				   `(begin ,@(cdr $1) ,$2)
				   `(begin ,$1 ,$2)))

    (OpenTag
      (T_OPEN_TAG) : `(void)
      (T_OPEN_TAG_WITH_ECHO Value) : `(echo ,$2)
      (T_OPEN_TAG_WITH_ECHO Value semi) : `(echo ,$2))

    (FunctionDeclaration
      (T_FUNCTION label FormalParameterList FunctionBody) : `(var ,$2 (lambda ,$3 ,$4)))

    (FormalParameterList 
      (open-paren close-paren) : '()
      (open-paren FormalParameterList close-paren) : $2 
      (T_VARIABLE) : `(,$1)
      (FormalParameterList comma T_VARIABLE) : `(,@$1 ,$3))

    (ValueList
      (Value) : `(,$1)
      (ValueList comma Value) : `(,@$1 ,$3))
    
    (Value
      (T_CONSTANT_ENCAPSED_STRING) : `(string ,$1)
      (T_LNUMBER) : `(num ,$1)
      (null) : `(null)
      (true) : `(true)
      (false) : `(false)
      (Variable) : $1
      (Assignment) : $1
      (IncDec) : $1
      (Concat) : $1
      (FunctionCall) : $1)

    (Variable
      (T_VARIABLE) : `(var-resolve ,$1))

    (FunctionBody
      (BracedStatements) : $1)

    (BracedStatements
      (open-brace close-brace) : `(void)
      (open-brace SourceElements close-brace) : $2)

    (Statement
      (open-brace close-brace) : `(void)
      (BracedStatements) : $1
      (FunctionDeclaration) : $1
      (Assignment semi) : $1
      (Echo) : $1
      (Print) : $1
      (IfBlock) : $1
      (FunctionCall semi) : $1
      (Loop) : $1
      (Return) : $1
      (IncDec semi) : $1
      (Break) : $1
      (Continue) : $1
      (Switch) : $1
      (T_WHITESPACE) : `(void)
      (T_COMMENT) : `(void))

    (Break
     (T_BREAK semi) : `(break)
     (T_BREAK T_LNUMBER semi) : `(break ,$1))
    
    (Continue
     (T_CONTINUE semi) : `(continue)
     (T_CONTINUE T_LNUMBER semi) : `(continue ,$1))

    (Return
      (T_RETURN semi) : `(return)
      (T_RETURN Value semi) : `(return ,$2))

    (IncDec
      (T_INC Variable) : `(pre-inc ,$2)
      (Variable T_INC) : `(post-inc ,$1)
      (T_DEC Variable) : `(pre-dec ,$2)
      (Variable T_DEC) : `(post-dec ,$1))

    (Assignment
     (T_VARIABLE equals Value) : `(var ,$1 ,$3)
     (T_VARIABLE T_AND_EQUAL Value) : `(var ,$1 (bit-and (var-resolve ,$1) ,$3))
     (T_VARIABLE T_OR_EQUAL Value) : `(var ,$1 (bit-or (var-resolve ,$1) ,$3))
     (T_VARIABLE T_XOR_EQUAL Value) : `(var ,$1 (bit-xor (var-resolve ,$1) ,$3))
     (T_VARIABLE T_PLUS_EQUAL Value) : `(var ,$1 (add (var-resolve ,$1) ,$3))
     (T_VARIABLE T_MINUS_EQUAL Value) : `(var ,$1 (sub (var-resolve ,$1) ,$3))
     (T_VARIABLE T_MUL_EQUAL Value) : `(var ,$1 (mul (var-resolve ,$1) ,$3))
     (T_VARIABLE T_DIV_EQUAL Value) : `(var ,$1 (div (var-resolve ,$1) ,$3))
     (T_VARIABLE T_MOD_EQUAL Value) : `(var ,$1 (mod (var-resolve ,$1) ,$3))
     (T_VARIABLE T_CONCAT_EQUAL Value) : `(var ,$1 (concat (var-resolve ,$1) ,$3)))

    (FunctionCall
      (label open-paren close-paren) : `(call ,$1)
      (label open-paren ValueList close-paren) : `(call ,$1 ,$3))

    (Echo
      (T_ECHO ValueList semi) : `(echo ,@$2))

    (Print 
      (T_PRINT Value semi) : `(print ,$2))

    (IfBlock
      (T_IF Comparison Statement) : `(if ,$2 ,$3)
      (T_IF Comparison Statement ElseBlock) : `(if ,$2 ,$3 ,$4))

    (ElseBlock
      (T_ELSE IfBlock) : $1
      (T_ELSE Statement) : $2
      (T_ELSEIF Comparison Statement) : `(if ,$2 ,$3)
      (T_ELSEIF Comparison Statement ElseBlock) : `(if ,$2 ,$3 ,$4))

    (Loop
     (T_DO Statement T_WHILE Comparison semi) : `(do ,$2 ,$4)
     (T_WHILE Comparison Statement) : `(while ,$2 ,$3)
     (T_FOR open-paren Assignment semi Comparison semi IncDec close-paren Statement) : `(for ,$3 ,$5 ,$7 ,$9))

    (Switch
     (T_SWITCH open-paren Value close-paren open-brace close-brace) : `(void)
     (T_SWITCH open-paren Value close-paren open-brace SwitchCases close-brace) : `(switch ,$3 ,$6))

    (SwitchCases
     (SwitchCase) : $1 
     (SwitchCases SwitchCase) : (if (and (pair? $1) (eq? (car $1) 'begin))
				    `(begin ,@(cdr $1) ,$2)
				    `(begin ,$1 ,$2)))

    (SwitchCase
     (T_CASE Value colon) : `(void)
     (T_CASE Value colon Statements) : `(case ,$2 ,$4)
     (T_DEFAULT colon) : `(void)
     (T_DEFAULT colon Statements) : `(case-default ,$3))

    (Concat
     (Value period Value) : `(concat ,$1 ,$3)
     (Concat period Value) : `(concat ,@$1 ,$3))
    
    (Comparison
      (open-paren Comparison close-paren) : $2
      (Comparison T_BOOLEAN_AND Comparison) : `(and ,$1 ,$3)
      (Comparison T_BOOLEAN_OR Comparison) : `(or ,$1 ,$3)
      (Value) : `(->bool ,$1)
      (Value T_IS_EQUAL Value) : `(equal ,$1 ,$3)
      (Value T_IS_NOT_EQUAL Value) : `(not (equal ,$1 ,$3))
      (Value greater-than Value) : `(greater-than ,$1 ,$3)
      (Value less-than Value) : `(less-than ,$1 ,$3)
      (Value T_IS_GREATER_OR_EQUAL Value) : `(greater-or-equal ,$1 ,$3)
      (Value T_IS_SMALLER_OR_EQUAL Value) : `(less-or-equal ,$1 ,$3)
      (Value T_IS_IDENTICAL Value) : `(identical ,$1 ,$3)
      (Value T_IS_NOT_IDENTICAL Value) : `(not (identical ,$1 ,$3)))

    ))