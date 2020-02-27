;;; phps-mode-lex-analyzer.el -- Lex analyzer for PHPs -*- lexical-binding: t -*-

;; Copyright (C) 2018-2020  Free Software Foundation, Inc.

;; This file is not part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.


;;; Commentary:

;; This file contains all meta-lexer logic. That is things like:
;;
;; * Executing different kinds of lexers based on conditions
;; * Also supply logic for indentation and imenu-handling
;; * Indentation based on lexer tokens
;; * Imenu based on lexer tokens
;; * Syntax coloring based on lexer tokens


;;; Code:


(require 'phps-mode-lexer)
(require 'phps-mode-macros)
(require 'phps-mode-serial)

(require 'semantic)
(require 'semantic/lex)
(require 'semantic/wisent)

(require 'subr-x)


;; FLAGS


(defvar-local phps-mode-lex-analyzer--allow-after-change-p t
  "Flag to tell us whether after change detection is enabled or not.")

(defvar-local phps-mode-lex-analyzer--change-min nil
  "The minium point of change.");

(defvar-local phps-mode-lex-analyzer--processed-buffer-p nil
  "Flag whether current buffer is processed or not.")


;; VARIABLES


(defvar-local phps-mode-lex-analyzer--idle-timer nil
  "Timer object of idle timer.")

(defvar-local phps-mode-lex-analyzer--imenu nil
  "The Imenu alist for current buffer, nil if none.")

(defvar-local phps-mode-lex-analyzer--lines-indent nil
  "The indentation of each line in buffer, nil if none.")

(defvar-local phps-mode-lex-analyzer--tokens nil
  "Latest tokens.")

(defvar-local phps-mode-lex-analyzer--state nil
  "Latest state.")

(defvar-local phps-mode-lex-analyzer--states nil
  "History of state and stack-stack.")

(defvar-local phps-mode-lex-analyzer--state-stack nil
  "Latest state-stack.")


;; FUNCTIONS


(defun phps-mode-lex-analyzer--reset-local-variables ()
  "Reset local variables."
  (setq phps-mode-lex-analyzer--allow-after-change-p t)
  (setq phps-mode-lex-analyzer--change-min nil)
  (setq phps-mode-lex-analyzer--idle-timer nil)
  (setq phps-mode-lex-analyzer--lines-indent nil)
  (setq phps-mode-lex-analyzer--imenu nil)
  (setq phps-mode-lex-analyzer--processed-buffer-p nil)
  (setq phps-mode-lex-analyzer--tokens nil)
  (setq phps-mode-lex-analyzer--state nil)
  (setq phps-mode-lex-analyzer--states nil)
  (setq phps-mode-lex-analyzer--state-stack nil))

(defun phps-mode-lex-analyzer--set-region-syntax-color (start end properties)
  "Do syntax coloring for region START to END with PROPERTIES."
  (with-silent-modifications (set-text-properties start end properties)))

(defun phps-mode-lex-analyzer--clear-region-syntax-color (start end)
  "Clear region of syntax coloring from START to END."
  (with-silent-modifications (set-text-properties start end nil)))

(defun phps-mode-lex-analyzer--get-token-syntax-color (token)
  "Return syntax color for TOKEN."
  ;; Syntax coloring
  ;; see https://www.gnu.org/software/emacs/manual/html_node/elisp/Faces-for-Font-Lock.html#Faces-for-Font-Lock
  ;; (message "Color token %s %s %s" token start end)
  (cond

   ((or
     (string= token 'T_VARIABLE)
     (string= token 'T_STRING_VARNAME))
    (list 'font-lock-face 'font-lock-variable-name-face))

   ((string= token 'T_COMMENT)
    (list 'font-lock-face 'font-lock-comment-face))

   ((string= token 'T_DOC_COMMENT)
    (list 'font-lock-face 'font-lock-doc-face))

   ((string= token 'T_INLINE_HTML)
    ;; NOTE T_INLINE_HTML is missing by purpose here to distinguish those areas from other entities
    nil)

   ((or
     (string= token 'T_STRING)
     (string= token 'T_CONSTANT_ENCAPSED_STRING)
     (string= token 'T_ENCAPSED_AND_WHITESPACE)
     (string= token 'T_NUM_STRING)
     (string= token 'T_DNUMBER)
     (string= token 'T_LNUMBER))
    (list 'font-lock-face 'font-lock-string-face))

   ((or
     (string= token 'T_DOLLAR_OPEN_CURLY_BRACES)
     (string= token 'T_CURLY_OPEN)
     (string= token 'T_OBJECT_OPERATOR)
     (string= token 'T_PAAMAYIM_NEKUDOTAYIM)
     (string= token 'T_NS_SEPARATOR)
     (string= token 'T_EXIT)
     (string= token 'T_DIE)
     (string= token 'T_RETURN)
     (string= token 'T_YIELD_FROM)
     (string= token 'T_YIELD)
     (string= token 'T_TRY)
     (string= token 'T_CATCH)
     (string= token 'T_FINALLY)
     (string= token 'T_THROW)
     (string= token 'T_IF)
     (string= token 'T_ELSEIF)
     (string= token 'T_ENDIF)
     (string= token 'T_ELSE)
     (string= token 'T_WHILE)
     (string= token 'T_ENDWHILE)
     (string= token 'T_DO)
     (string= token 'T_FUNCTION)
     (string= token 'T_FN)
     (string= token 'T_CONST)
     (string= token 'T_FOREACH)
     (string= token 'T_ENDFOREACH)
     (string= token 'T_FOR)
     (string= token 'T_ENDFOR)
     (string= token 'T_DECLARE)
     (string= token 'T_ENDDECLARE)
     (string= token 'T_INSTANCEOF)
     (string= token 'T_AS)
     (string= token 'T_SWITCH)
     (string= token 'T_ENDSWITCH)
     (string= token 'T_CASE)
     (string= token 'T_DEFAULT)
     (string= token 'T_BREAK)
     (string= token 'T_CONTINUE)
     (string= token 'T_GOTO)
     (string= token 'T_ECHO)
     (string= token 'T_PRINT)
     (string= token 'T_CLASS)
     (string= token 'T_INTERFACE)
     (string= token 'T_TRAIT)
     (string= token 'T_EXTENDS)
     (string= token 'T_IMPLEMENTS)
     (string= token 'T_NEW)
     (string= token 'T_CLONE)
     (string= token 'T_VAR)
     (string= token 'T_EVAL)
     (string= token 'T_INCLUDE_ONCE)
     (string= token 'T_INCLUDE)
     (string= token 'T_REQUIRE_ONCE)
     (string= token 'T_REQUIRE)
     (string= token 'T_NAMESPACE)
     (string= token 'T_USE)
     (string= token 'T_INSTEADOF)
     (string= token 'T_GLOBAL)
     (string= token 'T_ISSET)
     (string= token 'T_EMPTY)
     (string= token 'T_HALT_COMPILER)
     (string= token 'T_STATIC)
     (string= token 'T_ABSTRACT)
     (string= token 'T_FINAL)
     (string= token 'T_PRIVATE)
     (string= token 'T_PROTECTED)
     (string= token 'T_PUBLIC)
     (string= token 'T_UNSET)
     (string= token 'T_LIST)
     (string= token 'T_ARRAY)
     (string= token 'T_CALLABLE)
     )
    (list 'font-lock-face 'font-lock-keyword-face))

   ((or
     (string= token 'T_OPEN_TAG)
     (string= token 'T_OPEN_TAG_WITH_ECHO)
     (string= token 'T_CLOSE_TAG)
     (string= token 'T_START_HEREDOC)
     (string= token 'T_END_HEREDOC)
     (string= token 'T_ELLIPSIS)
     (string= token 'T_COALESCE)
     (string= token 'T_DOUBLE_ARROW)
     (string= token 'T_INC)
     (string= token 'T_DEC)
     (string= token 'T_IS_IDENTICAL)
     (string= token 'T_IS_NOT_IDENTICAL)
     (string= token 'T_IS_EQUAL)
     (string= token 'T_IS_NOT_EQUAL)
     (string= token 'T_SPACESHIP)
     (string= token 'T_IS_SMALLER_OR_EQUAL)
     (string= token 'T_IS_GREATER_OR_EQUAL)
     (string= token 'T_PLUS_EQUAL)
     (string= token 'T_MINUS_EQUAL)
     (string= token 'T_MUL_EQUAL)
     (string= token 'T_POW_EQUAL)
     (string= token 'T_POW)
     (string= token 'T_DIV_EQUAL)
     (string= token 'T_CONCAT_EQUAL)
     (string= token 'T_MOD_EQUAL)
     (string= token 'T_SL_EQUAL)
     (string= token 'T_SR_EQUAL)
     (string= token 'T_AND_EQUAL)
     (string= token 'T_OR_EQUAL)
     (string= token 'T_XOR_EQUAL)
     (string= token 'T_COALESCE_EQUAL)
     (string= token 'T_BOOLEAN_OR)
     (string= token 'T_BOOLEAN_AND)
     (string= token 'T_BOOLEAN_XOR)
     (string= token 'T_LOGICAL_XOR)
     (string= token 'T_LOGICAL_OR)
     (string= token 'T_LOGICAL_AND)
     (string= token 'T_SL)
     (string= token 'T_SR)
     (string= token 'T_CLASS_C)
     (string= token 'T_TRAIT_C)
     (string= token 'T_FUNC_C)
     (string= token 'T_METHOD_C)
     (string= token 'T_LINE)
     (string= token 'T_FILE)
     (string= token 'T_DIR)
     (string= token 'T_NS_C)
     (string= token 'T_INT_CAST)
     (string= token 'T_DOUBLE_CAST)
     (string= token 'T_STRING_CAST)
     (string= token 'T_ARRAY_CAST)
     (string= token 'T_OBJECT_CAST)
     (string= token 'T_BOOL_CAST)
     (string= token 'T_UNSET_CAST)
     )
    (list 'font-lock-face 'font-lock-constant-face))

   ((string= token 'T_ERROR)
    ;; NOTE This token is artificial and not PHP native
    (list 'font-lock-face 'font-lock-warning-face))

   (t (list 'font-lock-face 'font-lock-constant-face))))


;; LEXERS


(define-lex-analyzer phps-mode-lex-analyzer--cached-lex-analyzer
  "Return latest processed tokens or else just return one giant error token."
  t

  (let ((old-start (point)))
    (if phps-mode-lex-analyzer--tokens
        (progn
          ;; Add all updated tokens to semantic
          (phps-mode-debug-message
           (message
            "Updating semantic lexer tokens from point %s, tokens: %s, point-max: %s"
            old-start
            phps-mode-lex-analyzer--tokens
            (point-max)))
          (dolist (token phps-mode-lex-analyzer--tokens)
            (let ((start (car (cdr token)))
                  (end (cdr (cdr token)))
                  (token-name (car token)))

              ;; Apply syntax color on token
              (let ((token-syntax-color
                     (phps-mode-lex-analyzer--get-token-syntax-color token-name)))
                (if token-syntax-color
                    (phps-mode-lex-analyzer--set-region-syntax-color start end token-syntax-color)
                  (phps-mode-lex-analyzer--clear-region-syntax-color start end)))

              (semantic-lex-push-token
               (semantic-lex-token token-name start end))))

          (setq semantic-lex-end-point (point-max)))

      (phps-mode-lex-analyzer--set-region-syntax-color
       (point-min)
       (point-max)
       (list 'font-lock-face 'font-lock-warning-face))

      (semantic-lex-push-token
       (semantic-lex-token 'T_ERROR (point-min) (point-max))))))

;; If multiple rules match, re2c prefers the longest match.
;; If rules match the same string, the earlier rule has priority.
;; @see http://re2c.org/manual/syntax/syntax.html
(define-lex-analyzer phps-mode-lex-analyzer--re2c-lex-analyzer
  "Elisp port of original Zend re2c lexer."
  t
  (phps-mode-lexer--re2c))

(defun phps-mode-lex-analyzer--re2c-run (&optional force-synchronous)
  "Run lexer."
  (interactive)
  (require 'phps-mode-macros)
  (phps-mode-debug-message (message "Lexer run"))

  (let ((buffer-name (buffer-name))
        (buffer-contents (buffer-substring-no-properties (point-min) (point-max)))
        (async (and (boundp 'phps-mode-async-process)
                    phps-mode-async-process))
        (async-by-process (and (boundp 'phps-mode-async-process-using-async-el)
                               phps-mode-async-process-using-async-el)))
    (when force-synchronous
      (setq async nil))
    (phps-mode-serial-commands
     buffer-name
     (lambda() (phps-mode-lex-analyzer--lex-string buffer-contents))
     (lambda(result)
       (when (get-buffer buffer-name)
         (with-current-buffer buffer-name

           ;; Move variables into this buffers local variables
           (setq phps-mode-lex-analyzer--processed-buffer-p nil)
           (setq phps-mode-lex-analyzer--tokens (nth 0 result))
           (setq phps-mode-lex-analyzer--states (nth 1 result))
           (setq phps-mode-lex-analyzer--state (nth 2 result))
           (setq phps-mode-lex-analyzer--state-stack (nth 3 result))
           (phps-mode-lex-analyzer--reset-imenu)

           ;; Apply syntax color on tokens
           (dolist (token phps-mode-lex-analyzer--tokens)
             (let ((start (car (cdr token)))
                   (end (cdr (cdr token)))
                   (token-name (car token)))
               (let ((token-syntax-color (phps-mode-lex-analyzer--get-token-syntax-color token-name)))
                 (if token-syntax-color
                     (phps-mode-lex-analyzer--set-region-syntax-color start end token-syntax-color)
                   (phps-mode-lex-analyzer--clear-region-syntax-color start end)))))

           (let ((errors (nth 4 result))
                 (error-start)
                 (error-end))
             (when errors
               (setq error-start (car (cdr errors)))
               (when error-start
                 (if (car (cdr (cdr errors)))
                     (progn
                       (setq error-end (car (cdr (cdr (cdr errors)))))
                       (phps-mode-lex-analyzer--set-region-syntax-color
                        error-start
                        error-end
                        (list 'font-lock-face 'font-lock-warning-face)))
                   (setq error-end (point-max))
                   (phps-mode-lex-analyzer--set-region-syntax-color
                    error-start
                    error-end
                    (list 'font-lock-face 'font-lock-warning-face))))
               (signal 'error (list (format "Lex Errors: %s" (car errors)))))))))
     async
     async-by-process)))

(defun phps-mode-lex-analyzer--incremental-lex-string
    (buffer-name buffer-contents incremental-start-new-buffer point-max
                 head-states incremental-state incremental-state-stack head-tokens &optional force-synchronous)
  "Incremental lex region."
  (let ((async (and (boundp 'phps-mode-async-process)
                    phps-mode-async-process))
        (async-by-process (and (boundp 'phps-mode-async-process-using-async-el)
                               phps-mode-async-process-using-async-el)))
    (when force-synchronous
      (setq async nil))
    (phps-mode-serial-commands
     buffer-name
     (lambda() (phps-mode-lex-analyzer--lex-string
                buffer-contents
                incremental-start-new-buffer
                point-max
                head-states
                incremental-state
                incremental-state-stack
                head-tokens))
     (lambda(result)
       (when (get-buffer buffer-name)
         (with-current-buffer buffer-name

           (phps-mode-debug-message
            (message "Incrementally-lexed-string: %s" result))

           (setq phps-mode-lex-analyzer--tokens (nth 0 result))
           (setq phps-mode-lex-analyzer--states (nth 1 result))
           (setq phps-mode-lex-analyzer--state (nth 2 result))
           (setq phps-mode-lex-analyzer--state-stack (nth 3 result))
           (setq phps-mode-lex-analyzer--processed-buffer-p nil)
           (phps-mode-lex-analyzer--reset-imenu)

           ;; Apply syntax color on tokens
           (dolist (token phps-mode-lex-analyzer--tokens)
             (let ((start (car (cdr token)))
                   (end (cdr (cdr token)))
                   (token-name (car token)))

               ;; Apply syntax color on token
               (let ((token-syntax-color (phps-mode-lex-analyzer--get-token-syntax-color token-name)))
                 (if token-syntax-color
                     (phps-mode-lex-analyzer--set-region-syntax-color start end token-syntax-color)
                   (phps-mode-lex-analyzer--clear-region-syntax-color start end)))))

           (let ((errors (nth 4 result))
                 (error-start)
                 (error-end))
             (when errors
               (setq error-start (car (cdr errors)))
               (when error-start
                 (if (car (cdr (cdr errors)))
                     (progn
                       (setq error-end (car (cdr (cdr (cdr errors)))))
                       (phps-mode-lex-analyzer--set-region-syntax-color
                        error-start
                        error-end
                        (list 'font-lock-face 'font-lock-warning-face)))
                   (setq error-end (point-max))
                   (phps-mode-lex-analyzer--set-region-syntax-color
                    error-start
                    error-end
                    (list 'font-lock-face 'font-lock-warning-face))))
               (signal 'error (list (format "Incremental Lex Errors: %s" (car errors))))))

           (phps-mode-debug-message
            (message "Incremental tokens: %s" incremental-tokens)))))
     async
     async-by-process)))

(define-lex phps-mode-lex-analyzer--cached-lex
  "Call lexer analyzer action."
  phps-mode-lex-analyzer--cached-lex-analyzer
  semantic-lex-default-action)

(define-lex phps-mode-lex-analyzer--re2c-lex
  "Call lexer analyzer action."
  phps-mode-lex-analyzer--re2c-lex-analyzer
  semantic-lex-default-action)

(defun phps-mode-lex-analyzer--move-states (start diff)
  "Move lexer states after (or equal to) START with modification DIFF."
  (when phps-mode-lex-analyzer--states
    (setq phps-mode-lex-analyzer--states (phps-mode-lex-analyzer--get-moved-states phps-mode-lex-analyzer--states start diff))))

(defun phps-mode-lex-analyzer--get-moved-states (states start diff)
  "Return moved lexer STATES after (or equal to) START with modification DIFF."
  (let ((old-states states)
        (new-states '()))
    (when old-states

      ;; Iterate through states add states before start start unchanged and the others modified with diff
      (dolist (state-object (nreverse old-states))
        (let ((state-start (nth 0 state-object))
              (state-end (nth 1 state-object))
              (state-symbol (nth 2 state-object))
              (state-stack (nth 3 state-object)))
          (if (>= state-start start)
              (let ((new-state-start (+ state-start diff))
                    (new-state-end (+ state-end diff)))
                (push (list new-state-start new-state-end state-symbol state-stack) new-states))
            (if (> state-end start)
                (let ((new-state-end (+ state-end diff)))
                  (push (list state-start new-state-end state-symbol state-stack) new-states))
              (push state-object new-states))))))

    new-states))

(defun phps-mode-lex-analyzer--move-tokens (start diff)
  "Update tokens with moved lexer tokens after or equal to START with modification DIFF."
  (when phps-mode-lex-analyzer--tokens
    (setq phps-mode-lex-analyzer--tokens (phps-mode-lex-analyzer--get-moved-tokens phps-mode-lex-analyzer--tokens start diff))))

(defun phps-mode-lex-analyzer--get-moved-tokens (old-tokens start diff)
  "Return moved lexer OLD-TOKENS positions after (or equal to) START with DIFF points."
  (let ((new-tokens '()))
    (when old-tokens

      ;; Iterate over all tokens, add those that are to be left unchanged and add modified ones that should be changed.
      (dolist (token (nreverse old-tokens))
        (let ((token-symbol (car token))
              (token-start (car (cdr token)))
              (token-end (cdr (cdr token))))
          (if (>= token-start start)
              (let ((new-token-start (+ token-start diff))
                    (new-token-end (+ token-end diff)))
                (push `(,token-symbol ,new-token-start . ,new-token-end) new-tokens))
            (if (> token-end start)
                (let ((new-token-end (+ token-end diff)))
                  (push `(,token-symbol ,token-start . ,new-token-end) new-tokens))
              (push token new-tokens))))))
    new-tokens))

(defun phps-mode-lex-analyzer--reset-changes ()
  "Reset change."
  (setq phps-mode-lex-analyzer--change-min nil))

(defun phps-mode-lex-analyzer--process-changes (&optional buffer force-synchronous)
  "Run incremental lexer on BUFFER.  Return list of performed operations."
  (unless buffer
    (setq buffer (current-buffer)))
  (phps-mode-debug-message
   (message "Run process changes on buffer '%s'" buffer))
  (with-current-buffer buffer
    (let ((run-full-lexer nil)
          (old-tokens phps-mode-lex-analyzer--tokens)
          (old-states phps-mode-lex-analyzer--states)
          (log '()))

      (if phps-mode-lex-analyzer--change-min
          (progn
            (phps-mode-debug-message
             (message "Processing change point minimum: %s" phps-mode-lex-analyzer--change-min))
            (let ((incremental-state nil)
                  (incremental-state-stack nil)
                  (incremental-tokens nil)
                  (head-states '())
                  (head-tokens '())
                  (change-start phps-mode-lex-analyzer--change-min)
                  (incremental-start-new-buffer phps-mode-lex-analyzer--change-min))

              ;; Reset idle timer
              (phps-mode-lex-analyzer--cancel-idle-timer)

              ;; Reset buffer changes minimum index
              (phps-mode-lex-analyzer--reset-changes)

              ;; Reset tokens and states here
              (setq phps-mode-lex-analyzer--tokens nil)
              (setq phps-mode-lex-analyzer--states nil)
              (setq phps-mode-lex-analyzer--state nil)
              (setq phps-mode-lex-analyzer--state-stack nil)

              ;; NOTE Starts are inclusive while ends are exclusive buffer locations

              ;; Some tokens have dynamic length and if a change occurs at token-end
              ;; we must start the incremental process at previous token start

              ;; Build list of tokens from old buffer before start of changes (head-tokens)

              (catch 'quit
                (dolist (token old-tokens)
                  (let ((start (car (cdr token)))
                        (end (cdr (cdr token))))
                    (if (< end change-start)
                        (push token head-tokens)
                      (when (< start change-start)
                        (phps-mode-debug-message
                         (message "New incremental-start-new-buffer: %s" start))
                        (setq incremental-start-new-buffer start))
                      (throw 'quit "break")))))

              (setq head-tokens (nreverse head-tokens))
              (phps-mode-debug-message
               (message "Head tokens: %s" head-tokens)
               (message "Incremental-start-new-buffer: %s" incremental-start-new-buffer))

              ;; Did we find a start for the incremental process?
              (if head-tokens
                  (progn
                    (phps-mode-debug-message
                     (message "Found head tokens"))

                    ;; In old buffer:
                    ;; 1. Determine state (incremental-state) and state-stack (incremental-state-stack) before incremental start
                    ;; 2. Build list of states before incremental start (head-states)
                    (catch 'quit
                      (dolist (state-object (nreverse old-states))
                        (let ((end (nth 1 state-object)))
                          (if (< end change-start)
                              (progn
                                (setq incremental-state (nth 2 state-object))
                                (setq incremental-state-stack (nth 3 state-object))
                                (push state-object head-states))
                            (throw 'quit "break")))))

                    (phps-mode-debug-message
                     (message "Head states: %s" head-states)
                     (message "Incremental state: %s" incremental-state)
                     (message "State stack: %s" incremental-state-stack))

                    (if (and
                         head-states
                         incremental-state)
                        (progn
                          (phps-mode-debug-message
                           (message "Found head states"))


                          (push (list 'INCREMENTAL-LEX incremental-start-new-buffer) log)

                          ;; Do partial lex from previous-token-end to change-stop


                          (phps-mode-lex-analyzer--incremental-lex-string
                           (buffer-name)
                           (buffer-substring-no-properties (point-min) (point-max))
                           incremental-start-new-buffer
                           (point-max)
                           head-states
                           incremental-state
                           incremental-state-stack
                           head-tokens
                           force-synchronous)

                          (phps-mode-debug-message
                           (message "Incremental tokens: %s" incremental-tokens)))

                      (push (list 'FOUND-NO-HEAD-STATES incremental-start-new-buffer) log)
                      (phps-mode-debug-message
                       (message "Found no head states"))

                      (setq run-full-lexer t)))

                (push (list 'FOUND-NO-HEAD-TOKENS incremental-start-new-buffer) log)
                (phps-mode-debug-message
                 (message "Found no head tokens"))

                (setq run-full-lexer t))))
        (push (list 'FOUND-NO-CHANGE-POINT-MINIMUM) log)
        (phps-mode-debug-message
         (message "Found no change point minimum"))

        (setq run-full-lexer t))

      (when run-full-lexer
        (push (list 'RUN-FULL-LEXER) log)
        (phps-mode-debug-message
         (message "Running full lexer"))
        (phps-mode-lex-analyzer--re2c-run force-synchronous))

      log)))

(defun phps-mode-lex-analyzer--process-current-buffer (&optional force)
  "Process current buffer, generate indentations and Imenu, trigger incremental lexer if we have change."
  (interactive)
  (phps-mode-debug-message (message "Process current buffer"))
  (when phps-mode-lex-analyzer--idle-timer
    (phps-mode-debug-message
     (message "Flag buffer as not processed since changes are detected"))
    (setq phps-mode-lex-analyzer--processed-buffer-p nil))
  (if (or
       force
       (and
        (not phps-mode-lex-analyzer--processed-buffer-p)
        (not phps-mode-lex-analyzer--idle-timer)))
      (progn
        (phps-mode-debug-message (message "Buffer is not processed"))
        (let ((processed
               (phps-mode-lex-analyzer--process-tokens-in-string
                phps-mode-lex-analyzer--tokens
                (buffer-substring-no-properties
                 (point-min)
                 (point-max)))))
          (phps-mode-debug-message (message "Processed result: %s" processed))
          (setq phps-mode-lex-analyzer--imenu (nth 0 processed))
          (setq phps-mode-lex-analyzer--lines-indent (nth 1 processed)))
        (phps-mode-lex-analyzer--reset-imenu)
        (setq phps-mode-lex-analyzer--processed-buffer-p t))
    (phps-mode-debug-message
     (when phps-mode-lex-analyzer--processed-buffer-p
       (message "Buffer is already processed"))
     (when phps-mode-lex-analyzer--idle-timer
       (message "Not processing buffer since there are non-lexed changes")))))

(defun phps-mode-lex-analyzer--get-moved-lines-indent (old-lines-indents start-line-number diff)
  "Move OLD-LINES-INDENTS from START-LINE-NUMBER with DIFF points."
  (let ((lines-indents (make-hash-table :test 'equal))
        (line-number 1))
    (when old-lines-indents
      (let ((line-indent (gethash line-number old-lines-indents))
            (new-line-number))
        (while line-indent

          (when (< line-number start-line-number)
            ;; (message "Added new indent 3 %s from %s to %s" line-indent line-number line-number)
            (puthash line-number line-indent lines-indents))

          (when (and (> diff 0)
                     (>= line-number start-line-number)
                     (< line-number (+ start-line-number diff)))
            ;; (message "Added new indent 2 %s from %s to %s" line-indent line-number line-number)
            (puthash line-number (gethash start-line-number old-lines-indents) lines-indents))

          (when (>= line-number start-line-number)
            (setq new-line-number (+ line-number diff))
            ;; (message "Added new indent %s from %s to %s" line-indent line-number new-line-number)
            (puthash new-line-number line-indent lines-indents))

          (setq line-number (1+ line-number))
          (setq line-indent (gethash line-number old-lines-indents))))
      lines-indents)))

(defun phps-mode-lex-analyzer--move-imenu-index (start diff)
  "Moved imenu from START by DIFF points."
  (when phps-mode-lex-analyzer--imenu
    (setq phps-mode-lex-analyzer--imenu
                (phps-mode-lex-analyzer--get-moved-imenu phps-mode-lex-analyzer--imenu start diff))
    (phps-mode-lex-analyzer--reset-imenu)))

(defun phps-mode-lex-analyzer--move-lines-indent (start-line-number diff)
  "Move lines indent from START-LINE-NUMBER with DIFF points."
  (when phps-mode-lex-analyzer--lines-indent
    ;; (message "Moving line-indent index from %s with %s" start-line-number diff)
    (setq
     phps-mode-lex-analyzer--lines-indent
     (phps-mode-lex-analyzer--get-moved-lines-indent
      phps-mode-lex-analyzer--lines-indent
      start-line-number
      diff))))

(defun phps-mode-lex-analyzer--get-lines-indent ()
  "Return lines indent, process buffer if not done already."
  (phps-mode-lex-analyzer--process-current-buffer)
  phps-mode-lex-analyzer--lines-indent)

(defun phps-mode-lex-analyzer--get-imenu ()
  "Return Imenu, process buffer if not done already."
  (phps-mode-lex-analyzer--process-current-buffer)
  phps-mode-lex-analyzer--imenu)

(defun phps-mode-lex-analyzer--get-moved-imenu (old-index start diff)
  "Move imenu-index OLD-INDEX beginning from START with DIFF."
  (let ((new-index '()))

    (when old-index
      (if (and (listp old-index)
               (listp (car old-index)))
          (dolist (item old-index)
            (let ((sub-item (phps-mode-lex-analyzer--get-moved-imenu item start diff)))
              (push (car sub-item) new-index)))
        (let ((item old-index))
          (let ((item-label (car item)))
            (if (listp (cdr item))
                (let ((sub-item (phps-mode-lex-analyzer--get-moved-imenu (cdr item) start diff)))
                  (push `(,item-label . ,sub-item) new-index))
              (let ((item-start (cdr item)))
                (when (>= item-start start)
                  (setq item-start (+ item-start diff)))
                (push `(,item-label . ,item-start) new-index)))))))

    (nreverse new-index)))

(defun phps-mode-lex-analyzer--get-lines-in-buffer (beg end)
  "Return the number of lines in buffer between BEG and END."
  (phps-mode-lex-analyzer--get-lines-in-string (buffer-substring-no-properties beg end)))

(defun phps-mode-lex-analyzer--get-lines-in-string (string)
  "Return the number of lines in STRING."
  (let ((lines-in-string 0)
        (start 0))
    (while (string-match "[\n]" string start)
      (setq start (match-end 0))
      (setq lines-in-string (1+ lines-in-string)))
    lines-in-string))

(defun phps-mode-lex-analyzer--get-inline-html-indentation
    (
     inline-html
     indent
     tag-level
     curly-bracket-level
     square-bracket-level
     round-bracket-level)
  "Generate a list of indentation for each line in INLINE-HTML.
Working incrementally on INDENT, TAG-LEVEL, CURLY-BRACKET-LEVEL,
SQUARE-BRACKET-LEVEL and ROUND-BRACKET-LEVEL."
  (phps-mode-debug-message
   (message "Calculating HTML indent for: '%s'" inline-html))

  ;; Add trailing newline if missing
  (unless (string-match-p "\n$" inline-html)
    (setq inline-html (concat inline-html "\n")))

  (let ((start 0)
        (indent-start indent)
        (indent-end indent)
        (line-indents nil)
        (first-object-on-line t)
        (first-object-is-nesting-decrease nil))
    (while
        (string-match
         "\\([\n]\\)\\|\\(<[a-zA-Z]+\\)\\|\\(</[a-zA-Z]+\\)\\|\\(/>\\)\\|\\(\\[\\)\\|\\()\\)\\|\\((\\)\\|\\({\\|}\\)"
         inline-html
         start)
      (let* ((end (match-end 0))
             (string (substring inline-html (match-beginning 0) end)))

        (cond

         ((string-match-p "\n" string)

          (let ((temp-indent indent))
            (when first-object-is-nesting-decrease
              (phps-mode-debug-message
               (message "Decreasing indent with one since first object was a nesting decrease"))
              (setq temp-indent (1- indent))
              (when (< temp-indent 0)
                (setq temp-indent 0)))
            (push temp-indent line-indents))

          (setq indent-end (+ tag-level curly-bracket-level square-bracket-level round-bracket-level))
          (phps-mode-debug-message "Encountered a new-line")
          (if (> indent-end indent-start)
              (progn
                (phps-mode-debug-message
                 (message "Increasing indent since %s is above %s" indent-end indent-start))
                (setq indent (1+ indent)))
            (when (< indent-end indent-start)
              (phps-mode-debug-message
               (message "Decreasing indent since %s is below %s" indent-end indent-start))
              (setq indent (1- indent))
              (when (< indent 0)
                (setq indent 0))))

          (setq indent-start indent-end)
          (setq first-object-on-line t)
          (setq first-object-is-nesting-decrease nil))

         ((string= string "(")
          (setq round-bracket-level (1+ round-bracket-level)))
         ((string= string ")")
          (setq round-bracket-level (1- round-bracket-level)))

         ((string= string "[")
          (setq square-bracket-level (1+ square-bracket-level)))
         ((string= string "]")
          (setq square-bracket-level (1- square-bracket-level)))

         ((string= string "{")
          (setq curly-bracket-level (1+ curly-bracket-level)))
         ((string= string "}")
          (setq curly-bracket-level (1- curly-bracket-level)))

         ((string-match "<[a-zA-Z]+" string)
          (setq tag-level (1+ tag-level)))

         ((string-match "\\(</[a-zA-Z]+\\)\\|\\(/>\\)" string)
          (setq tag-level (1- tag-level)))

         )

        (when first-object-on-line
          (unless (string-match-p "\n" string)
            (setq first-object-on-line nil)
            (setq indent-end (+ tag-level curly-bracket-level square-bracket-level round-bracket-level))
            (when (< indent-end indent-start)
              (phps-mode-debug-message "First object was nesting decrease")
              (setq first-object-is-nesting-decrease t))))

        (setq start end)))
    (list (nreverse line-indents) indent tag-level curly-bracket-level square-bracket-level round-bracket-level)))

(defun phps-mode-lex-analyzer--process-tokens-in-string (tokens string)
  "Generate indexes for imenu and indentation for TOKENS and STRING one pass.  Complexity: O(n)."
  (if tokens
      (progn
        (phps-mode-debug-message
         (message
          "\nCalculation indentation and imenu for all lines in buffer:\n\n%s"
          string))
        (let ((in-heredoc nil)
              (in-heredoc-started-this-line nil)
              (in-heredoc-ended-this-line nil)
              (in-inline-control-structure nil)
              (inline-html-indent 0)
              (inline-html-indent-start 0)
              (inline-html-tag-level 0)
              (inline-html-curly-bracket-level 0)
              (inline-html-square-bracket-level 0)
              (inline-html-round-bracket-level 0)
              (inline-html-is-whitespace nil)
              (inline-html-rest-is-whitespace nil)
              (first-token-is-inline-html nil)
              (after-special-control-structure nil)
              (after-special-control-structure-token nil)
              (after-extra-special-control-structure nil)
              (after-extra-special-control-structure-first-on-line nil)
              (switch-curly-stack nil)
              (switch-alternative-stack nil)
              (switch-case-alternative-stack nil)
              (curly-bracket-level 0)
              (round-bracket-level 0)
              (square-bracket-level 0)
              (alternative-control-structure-level 0)
              (alternative-control-structure-line 0)
              (in-concatenation nil)
              (in-concatenation-round-bracket-level nil)
              (in-concatenation-square-bracket-level nil)
              (in-concatenation-level 0)
              (in-double-quotes nil)
              (column-level 0)
              (column-level-start 0)
              (tuning-level 0)
              (nesting-start 0)
              (nesting-end 0)
              (last-line-number 0)
              (first-token-on-line t)
              (line-indents (make-hash-table :test 'equal))
              (first-token-is-nesting-decrease nil)
              (token-number 1)
              (allow-custom-column-increment nil)
              (allow-custom-column-decrement nil)
              (in-assignment nil)
              (in-assignment-round-bracket-level nil)
              (in-assignment-square-bracket-level nil)
              (in-assignment-level 0)
              (in-object-operator nil)
              (in-object-operator-round-bracket-level nil)
              (in-object-operator-square-bracket-level nil)
              (after-object-operator nil)
              (in-object-operator-level 0)
              (in-class-declaration nil)
              (in-class-declaration-level 0)
              (in-return nil)
              (in-return-curly-bracket-level nil)
              (in-return-level 0)
              (previous-token nil)
              (token nil)
              (token-start nil)
              (token-end nil)
              (token-start-line-number 0)
              (token-end-line-number 0)
              (tokens (nreverse (copy-sequence tokens)))
              (nesting-stack nil)
              (nesting-key nil)
              (class-declaration-started-this-line nil)
              (special-control-structure-started-this-line nil)
              (temp-pre-indent nil)
              (temp-post-indent nil)
              (imenu-index '())
              (imenu-namespace-index '())
              (imenu-class-index '())
              (imenu-in-namespace-declaration nil)
              (imenu-in-namespace-name nil)
              (imenu-in-namespace-with-brackets nil)
              (imenu-open-namespace-level nil)
              (imenu-in-class-declaration nil)
              (imenu-open-class-level nil)
              (imenu-in-class-name nil)
              (imenu-in-function-declaration nil)
              (imenu-in-function-name nil)
              (imenu-in-function-index nil)
              (imenu-nesting-level 0)
              (incremental-line-number 1))

          (push `(END_PARSE ,(length string) . ,(length string)) tokens)

          ;; Iterate through all buffer tokens from beginning to end
          (dolist (item (nreverse tokens))
            ;; (message "Items: %s %s" item phps-mode-lex-analyzer--tokens)
            (let ((next-token (car item))
                  (next-token-start (car (cdr item)))
                  (next-token-end (cdr (cdr item)))
                  (next-token-start-line-number nil)
                  (next-token-end-line-number nil))

              (when (and token
                         (< token-end next-token-start))
                ;; NOTE We use a incremental-line-number calculation because `line-at-pos' takes a lot of time
                (setq
                 incremental-line-number
                 (+
                  incremental-line-number
                  (phps-mode-lex-analyzer--get-lines-in-string
                   (substring
                    string
                    (1- token-end)
                    (1- next-token-start))))))

              ;; Handle the pseudo-token for last-line
              (if (equal next-token 'END_PARSE)
                  (progn
                    (setq next-token-start-line-number (1+ token-start-line-number))
                    (setq next-token-end-line-number (1+ token-end-line-number)))
                (setq next-token-start-line-number incremental-line-number)

                ;; NOTE We use a incremental-line-number calculation because `line-at-pos' takes a lot of time
                ;; (message "Lines for %s '%s'" next-token (substring string (1- next-token-start) (1- next-token-end)))
                (setq
                 incremental-line-number
                 (+
                  incremental-line-number
                  (phps-mode-lex-analyzer--get-lines-in-string
                   (substring
                    string
                    (1- next-token-start)
                    (1- next-token-end)))))
                (setq next-token-end-line-number incremental-line-number)
                (phps-mode-debug-message
                 (message
                  "Token '%s' pos: %s-%s lines: %s-%s"
                  next-token
                  next-token-start
                  next-token-end
                  next-token-start-line-number
                  next-token-end-line-number)))

              ;; Token logic - we have one-two token look-ahead at this point
              ;; `token' is previous token
              ;; `next-token' is current token
              ;; `previous-token' is maybe two tokens back
              (when token


                ;; IMENU LOGIC

                (cond

                 ((or (string= token "{")
                      (equal token 'T_CURLY_OPEN)
                      (equal token 'T_DOLLAR_OPEN_CURLY_BRACES))
                  (setq imenu-nesting-level (1+ imenu-nesting-level)))

                 ((string= token "}")

                  (when (and imenu-open-namespace-level
                             (= imenu-open-namespace-level imenu-nesting-level)
                             imenu-in-namespace-name
                             imenu-namespace-index)
                    (let ((imenu-add-list (nreverse imenu-namespace-index)))
                      (push `(,imenu-in-namespace-name . ,imenu-add-list) imenu-index))
                    (setq imenu-in-namespace-name nil))

                  (when (and imenu-open-class-level
                             (= imenu-open-class-level imenu-nesting-level)
                             imenu-in-class-name
                             imenu-class-index)
                    (let ((imenu-add-list (nreverse imenu-class-index)))
                      (if imenu-in-namespace-name
                          (push `(,imenu-in-class-name . ,imenu-add-list) imenu-namespace-index)
                        (push `(,imenu-in-class-name . ,imenu-add-list) imenu-index)))
                    (setq imenu-in-class-name nil))

                  (setq imenu-nesting-level (1- imenu-nesting-level))))

                (cond

                 (imenu-in-namespace-declaration
                  (cond

                   ((or (string= token "{")
                        (string= token ";"))
                    (setq imenu-in-namespace-with-brackets (string= token "{"))
                    (setq imenu-open-namespace-level imenu-nesting-level)
                    (setq imenu-namespace-index '())
                    (setq imenu-in-namespace-declaration nil))

                   ((and (or (equal token 'T_STRING)
                             (equal token 'T_NS_SEPARATOR))
                         (setq
                          imenu-in-namespace-name
                          (concat
                           imenu-in-namespace-name
                           (substring
                            string
                            (1- token-start)
                            (1- token-end))))))))

                 (imenu-in-class-declaration
                  (cond

                   ((string= token "{")
                    (setq imenu-open-class-level imenu-nesting-level)
                    (setq imenu-in-class-declaration nil)
                    (setq imenu-class-index '()))

                   ((and (equal token 'T_STRING)
                         (not imenu-in-class-name))
                    (setq imenu-in-class-name (substring string (1- token-start) (1- token-end))))))

                 (imenu-in-function-declaration
                  (cond

                   ((or (string= token "{")
                        (string= token ";"))
                    (when imenu-in-function-name
                      (if imenu-in-class-name
                          (push `(,imenu-in-function-name . ,imenu-in-function-index) imenu-class-index)
                        (if imenu-in-namespace-name
                            (push `(,imenu-in-function-name . ,imenu-in-function-index) imenu-namespace-index)
                          (push `(,imenu-in-function-name . ,imenu-in-function-index) imenu-index))))
                    (setq imenu-in-function-name nil)
                    (setq imenu-in-function-declaration nil))

                   ((and (equal token 'T_STRING)
                         (not imenu-in-function-name))
                    (setq imenu-in-function-name (substring string (1- token-start) (1- token-end)))
                    (setq imenu-in-function-index token-start))))

                 (t (cond

                     ((and (not imenu-in-namespace-name)
                           (equal token 'T_NAMESPACE))
                      (setq imenu-in-namespace-name nil)
                      (setq imenu-in-namespace-declaration t))

                     ((and (not imenu-in-class-name)
                           (or (equal token 'T_CLASS)
                               (equal token 'T_INTERFACE)))
                      (setq imenu-in-class-name nil)
                      (setq imenu-in-class-declaration t))

                     ((and (not imenu-in-function-name)
                           (equal token 'T_FUNCTION))
                      (setq imenu-in-function-name nil)
                      (setq imenu-in-function-declaration t)))))

                (when (and (equal next-token 'END_PARSE)
                           imenu-in-namespace-name
                           (not imenu-in-namespace-with-brackets)
                           imenu-namespace-index)
                  (let ((imenu-add-list (nreverse imenu-namespace-index)))
                    (push `(,imenu-in-namespace-name . ,imenu-add-list) imenu-index))
                  (setq imenu-in-namespace-name nil))


                ;; INDENTATION LOGIC


                ;; Keep track of round bracket level
                (when (string= token "(")
                  (setq round-bracket-level (1+ round-bracket-level)))
                (when (string= token ")")
                  (setq round-bracket-level (1- round-bracket-level))
                  (when first-token-on-line
                    (setq first-token-is-nesting-decrease t)))

                ;; Keep track of opened double quotes
                (when (string= token "\"")
                  (setq in-double-quotes (not in-double-quotes)))

                ;; Keep track of square bracket level
                (when (string= token "[")
                  (setq square-bracket-level (1+ square-bracket-level)))
                (when (and
                       (string= token "]")
                       (not in-double-quotes))
                  ;; You can have stuff like this $var = "abc $b[test]"; and only the closing square bracket will be tokenized
                  (setq square-bracket-level (1- square-bracket-level))
                  (when first-token-on-line
                    (setq first-token-is-nesting-decrease t)))

                ;; Handle INLINE_HTML blocks
                (when (equal token 'T_INLINE_HTML)

                  ;; Flag whether inline-html is whitespace or not
                  (setq
                   inline-html-is-whitespace
                   (string=
                    (string-trim
                     (substring
                      string
                      (1- token-start)
                      (1- token-end))) ""))
                  (setq
                   inline-html-rest-is-whitespace
                   (string-match
                    "^[\ \t\r\f]+\n"
                    (substring
                     string
                     (1- token-start)
                     (1- token-end))))

                  (when first-token-on-line
                    (setq first-token-is-inline-html t))

                  (let ((inline-html-indents
                         (phps-mode-lex-analyzer--get-inline-html-indentation
                          (substring
                           string
                           (1- token-start)
                           (1- token-end))
                          inline-html-indent
                          inline-html-tag-level
                          inline-html-curly-bracket-level
                          inline-html-square-bracket-level
                          inline-html-round-bracket-level)))

                    (phps-mode-debug-message
                     (message
                      "Received inline html indent: %s from inline HTML: '%s'"
                      inline-html-indents
                      (substring
                       string
                       (1- token-start)
                       (1- token-end))))

                    ;; Update indexes
                    (setq inline-html-indent (nth 1 inline-html-indents))
                    (setq inline-html-tag-level (nth 2 inline-html-indents))
                    (setq inline-html-curly-bracket-level (nth 3 inline-html-indents))
                    (setq inline-html-square-bracket-level (nth 4 inline-html-indents))
                    (setq inline-html-round-bracket-level (nth 5 inline-html-indents))

                    (phps-mode-debug-message
                     (message "First token is inline html: %s" first-token-is-inline-html))

                    ;; Does inline html span several lines or starts a new line?
                    (when (or (> token-end-line-number token-start-line-number)
                              first-token-is-inline-html)

                      ;; Token does not only contain white-space?
                      (unless inline-html-is-whitespace
                        (let ((token-line-number-diff token-start-line-number))
                          ;; Iterate lines here and add indents
                          (dolist (item (nth 0 inline-html-indents))
                            ;; Skip first line unless first token on line was inline-html
                            (when (or (not (= token-line-number-diff token-start-line-number))
                                      first-token-is-inline-html)
                              (unless (gethash token-line-number-diff line-indents)
                                (puthash token-line-number-diff (list item 0) line-indents)
                                (phps-mode-debug-message
                                 (message
                                  "Putting indent at line %s to %s from inline HTML"
                                  token-line-number-diff
                                  item))))
                            (setq token-line-number-diff (1+ token-line-number-diff))))))))

                ;; Keep track of when we are inside a class definition
                (if in-class-declaration
                    (if (string= token "{")
                        (progn
                          (setq in-class-declaration nil)
                          (setq in-class-declaration-level 0)

                          (unless class-declaration-started-this-line
                            (setq column-level (1- column-level))
                            (pop nesting-stack))

                          (when first-token-on-line
                            (setq first-token-is-nesting-decrease t))

                          )
                      (when first-token-on-line
                        (setq in-class-declaration-level 1)))

                  ;; If ::class is used as a magical class constant it should not be considered start of a class declaration
                  (when (and (equal token 'T_CLASS)
                             (or (not previous-token)
                                 (not (equal previous-token 'T_PAAMAYIM_NEKUDOTAYIM))))
                    (setq in-class-declaration t)
                    (setq in-class-declaration-level 1)
                    (setq class-declaration-started-this-line t)))

                ;; Keep track of curly bracket level
                (when (or (equal token 'T_CURLY_OPEN)
                          (equal token 'T_DOLLAR_OPEN_CURLY_BRACES)
                          (string= token "{"))
                  (setq curly-bracket-level (1+ curly-bracket-level)))
                (when (string= token "}")
                  (setq curly-bracket-level (1- curly-bracket-level))

                  (when (and switch-curly-stack
                             (= (1+ curly-bracket-level) (car switch-curly-stack)))

                    (phps-mode-debug-message
                     (message "Ended switch curly stack at %s" curly-bracket-level))

                    (setq allow-custom-column-decrement t)
                    (pop nesting-stack)
                    (setq alternative-control-structure-level (1- alternative-control-structure-level))
                    (pop switch-curly-stack))
                  
                  (when first-token-on-line
                    (setq first-token-is-nesting-decrease t)))

                ;; Keep track of ending alternative control structure level
                (when (or (equal token 'T_ENDIF)
                          (equal token 'T_ENDWHILE)
                          (equal token 'T_ENDFOR)
                          (equal token 'T_ENDFOREACH)
                          (equal token 'T_ENDSWITCH))
                  (setq alternative-control-structure-level (1- alternative-control-structure-level))
                  ;; (message "Found ending alternative token %s %s" token alternative-control-structure-level)

                  (when (and (equal token 'T_ENDSWITCH)
                             switch-case-alternative-stack)

                    (phps-mode-debug-message
                     (message "Ended alternative switch stack at %s" alternative-control-structure-level))
                    
                    (pop switch-alternative-stack)
                    (pop switch-case-alternative-stack)
                    (setq allow-custom-column-decrement t)
                    (pop nesting-stack)
                    (setq alternative-control-structure-level (1- alternative-control-structure-level)))

                  (when first-token-on-line
                    (setq first-token-is-nesting-decrease t)))

                ;; When we encounter a token except () after a control-structure
                (when (and after-special-control-structure
                           (= after-special-control-structure round-bracket-level)
                           (not (string= token ")"))
                           (not (string= token "(")))

                  ;; Handle the else if case
                  (if (equal 'T_IF token)
                      (progn
                        (setq after-special-control-structure-token token)
                        (setq alternative-control-structure-line token-start-line-number))

                    ;; Is token not a curly bracket - because that is a ordinary control structure syntax
                    (if (string= token "{")

                        ;; Save curly bracket level when switch starts
                        (when (equal after-special-control-structure-token 'T_SWITCH)

                          (phps-mode-debug-message
                           (message "Started switch curly stack at %s" curly-bracket-level))

                          (push curly-bracket-level switch-curly-stack))

                      ;; Is it the start of an alternative control structure?
                      (if (string= token ":")

                          (progn

                            ;; Save alternative nesting level for switch
                            (when (equal after-special-control-structure-token 'T_SWITCH)

                              (phps-mode-debug-message
                               (message "Started switch alternative stack at %s" alternative-control-structure-level))

                              (push alternative-control-structure-level switch-alternative-stack))

                            (setq alternative-control-structure-level (1+ alternative-control-structure-level))

                            (phps-mode-debug-message
                             (message
                              "\nIncreasing alternative-control-structure after %s %s to %s\n"
                              after-special-control-structure-token
                              token
                              alternative-control-structure-level))
                            )

                        ;; Don't start inline control structures after a while ($condition); expression
                        (unless (string= token ";")
                          (phps-mode-debug-message
                           (message
                            "\nStarted inline control-structure after %s at %s\n"
                            after-special-control-structure-token
                            token))

                          (setq in-inline-control-structure t)
                          (when (< alternative-control-structure-line token-start-line-number)
                            (setq temp-pre-indent (1+ column-level))))))

                    (setq after-special-control-structure nil)
                    (setq after-special-control-structure-token nil)
                    (setq alternative-control-structure-line nil)))

                ;; Support extra special control structures (CASE)
                (when (and after-extra-special-control-structure
                           (string= token ":"))
                  (setq alternative-control-structure-level (1+ alternative-control-structure-level))
                  (when after-extra-special-control-structure-first-on-line
                    (setq first-token-is-nesting-decrease t))
                  (setq after-extra-special-control-structure nil))

                ;; Keep track of concatenation
                (if in-concatenation
                    (when (or (string= token ";")
                              (and (string= token ")")
                                   (< round-bracket-level (car in-concatenation-round-bracket-level)))
                              (and (string= token ",")
                                   (= round-bracket-level (car in-concatenation-round-bracket-level))
                                   (= square-bracket-level (car in-concatenation-square-bracket-level)))
                              (and (string= token"]")
                                   (< square-bracket-level (car in-concatenation-square-bracket-level))))
                      (phps-mode-debug-message "Ended concatenation")
                      (pop in-concatenation-round-bracket-level)
                      (pop in-concatenation-square-bracket-level)
                      (unless in-concatenation-round-bracket-level
                        (setq in-concatenation nil))
                      (setq in-concatenation-level (1- in-concatenation-level)))
                  (when (and (> next-token-start-line-number token-end-line-number)
                             (or (string= token ".")
                                 (string= next-token ".")))
                    (phps-mode-debug-message "Started concatenation")
                    (setq in-concatenation t)
                    (push round-bracket-level in-concatenation-round-bracket-level)
                    (push square-bracket-level in-concatenation-square-bracket-level)
                    (setq in-concatenation-level (1+ in-concatenation-level))))

                ;; Did we reach a semicolon inside a inline block? Close the inline block
                (when (and in-inline-control-structure
                           (string= token ";")
                           (not special-control-structure-started-this-line))
                  (setq in-inline-control-structure nil))

                ;; Did we encounter a token that supports alternative and inline control structures?
                (when (or (equal token 'T_IF)
                          (equal token 'T_WHILE)
                          (equal token 'T_FOR)
                          (equal token 'T_FOREACH)
                          (equal token 'T_SWITCH)
                          (equal token 'T_ELSE)
                          (equal token 'T_ELSEIF)
                          (equal token 'T_DEFAULT))
                  (setq after-special-control-structure round-bracket-level)
                  (setq after-special-control-structure-token token)
                  (setq alternative-control-structure-line token-start-line-number)
                  (setq nesting-key token)
                  (setq special-control-structure-started-this-line t)

                  ;; ELSE and ELSEIF after a IF, ELSE, ELESIF
                  ;; and DEFAULT after a CASE
                  ;; should decrease alternative control structure level
                  (when (and nesting-stack
                             (string= (car (cdr (cdr (cdr (car nesting-stack))))) ":")
                             (or
                              (and (or (equal token 'T_ELSE)
                                       (equal token 'T_ELSEIF))
                                   (or (equal (car (cdr (cdr (car nesting-stack)))) 'T_IF)
                                       (equal (car (cdr (cdr (car nesting-stack)))) 'T_ELSEIF)
                                       (equal (car (cdr (cdr (car nesting-stack)))) 'T_ELSE)))
                              (and (equal token 'T_DEFAULT)
                                   (equal (car (cdr (cdr (car nesting-stack)))) 'T_CASE))))
                    (setq alternative-control-structure-level (1- alternative-control-structure-level))

                    (when first-token-on-line
                      (setq first-token-is-nesting-decrease t))

                    (phps-mode-debug-message
                     (message
                      "\nDecreasing alternative control structure nesting at %s to %s\n"
                      token
                      alternative-control-structure-level)))

                  )

                ;; Keep track of assignments
                (when in-assignment
                  (when (or (string= token ";")
                            (and (string= token ")")
                                 (or (< round-bracket-level (car in-assignment-round-bracket-level))
                                     (and
                                      (= round-bracket-level (car in-assignment-round-bracket-level))
                                      (= square-bracket-level (car in-assignment-square-bracket-level))
                                      (or (string= next-token ")")
                                          (string= next-token "]")))))
                            (and (string= token ",")
                                 (= round-bracket-level (car in-assignment-round-bracket-level))
                                 (= square-bracket-level (car in-assignment-square-bracket-level)))
                            (and (string= token "]")
                                 (or (< square-bracket-level (car in-assignment-square-bracket-level))
                                     (and
                                      (= square-bracket-level (car in-assignment-square-bracket-level))
                                      (= round-bracket-level (car in-assignment-round-bracket-level))
                                      (or (string= next-token "]")
                                          (string= next-token ")")))))
                            (and (equal token 'T_FUNCTION)
                                 (= round-bracket-level (car in-assignment-round-bracket-level))))

                    ;; NOTE Ending an assignment because of a T_FUNCTION token is to support PSR-2 Closures
                    
                    (phps-mode-debug-message
                     (message "Ended assignment %s at %s %s" in-assignment-level token next-token))
                    (pop in-assignment-square-bracket-level)
                    (pop in-assignment-round-bracket-level)
                    (unless in-assignment-round-bracket-level
                      (setq in-assignment nil))
                    (setq in-assignment-level (1- in-assignment-level))

                    ;; Did we end two assignment at once?
                    (when (and
                           in-assignment-round-bracket-level
                           in-assignment-square-bracket-level
                           (= round-bracket-level (car in-assignment-round-bracket-level))
                           (= square-bracket-level (car in-assignment-square-bracket-level))
                           (or (string= next-token ")")
                               (string= next-token "]")))
                      (phps-mode-debug-message
                       (message "Ended another assignment %s at %s %s" in-assignment-level token next-token))
                      (pop in-assignment-square-bracket-level)
                      (pop in-assignment-round-bracket-level)
                      (unless in-assignment-round-bracket-level
                        (setq in-assignment nil))
                      (setq in-assignment-level (1- in-assignment-level)))

                    ))

                (when (and (not after-special-control-structure)
                           (or (string= token "=")
                               (equal token 'T_DOUBLE_ARROW)
                               (equal token 'T_CONCAT_EQUAL)
                               (equal token 'T_POW_EQUAL)
                               (equal token 'T_DIV_EQUAL)
                               (equal token 'T_PLUS_EQUAL)
                               (equal token 'T_MINUS_EQUAL)
                               (equal token 'T_MUL_EQUAL)
                               (equal token 'T_MOD_EQUAL)
                               (equal token 'T_SL_EQUAL)
                               (equal token 'T_SR_EQUAL)
                               (equal token 'T_AND_EQUAL)
                               (equal token 'T_OR_EQUAL)
                               (equal token 'T_XOR_EQUAL)
                               (equal token 'T_COALESCE_EQUAL)))
                  (phps-mode-debug-message "Started assignment")
                  (setq in-assignment t)
                  (push round-bracket-level in-assignment-round-bracket-level)
                  (push square-bracket-level in-assignment-square-bracket-level)
                  (setq in-assignment-level (1+ in-assignment-level)))

                ;; Second token after a object-operator
                (when (and
                       in-object-operator
                       in-object-operator-round-bracket-level
                       in-object-operator-square-bracket-level
                       (<= round-bracket-level (car in-object-operator-round-bracket-level))
                       (<= square-bracket-level (car in-object-operator-square-bracket-level))
                       (not (or
                             (equal next-token 'T_OBJECT_OPERATOR)
                             (equal next-token 'T_PAAMAYIM_NEKUDOTAYIM))))
                  (phps-mode-debug-message
                   (message "Ended object-operator at %s %s at level %s" token next-token in-object-operator-level))
                  (pop in-object-operator-round-bracket-level)
                  (pop in-object-operator-square-bracket-level)
                  (setq in-object-operator-level (1- in-object-operator-level))
                  (when (= in-object-operator-level 0)
                    (setq in-object-operator nil)))

                ;; First token after a object-operator
                (when after-object-operator
                  (when (or (equal next-token 'T_STRING)
                            (string= next-token "("))
                    (progn
                      (phps-mode-debug-message
                       (message
                        "Started object-operator at %s %s on level %s"
                        token
                        next-token
                        in-object-operator-level
                        ))
                      (push round-bracket-level in-object-operator-round-bracket-level)
                      (push square-bracket-level in-object-operator-square-bracket-level)
                      (setq in-object-operator t)
                      (setq in-object-operator-level (1+ in-object-operator-level))))
                  (setq after-object-operator nil))

                ;; Starting object-operator?
                (when (and (or (equal token 'T_OBJECT_OPERATOR)
                               (equal token 'T_PAAMAYIM_NEKUDOTAYIM))
                           (equal next-token 'T_STRING))
                  (phps-mode-debug-message
                   (message "After object-operator at %s level %s"  token in-object-operator-level))
                  (setq after-object-operator t))

                ;; Keep track of return expressions
                (when in-return
                  (when (and (string= token ";")
                             (= curly-bracket-level (car in-return-curly-bracket-level)))

                    (phps-mode-debug-message (message "Ended return at %s" token))
                    (pop in-return-curly-bracket-level)
                    (unless in-return-curly-bracket-level
                      (setq in-return nil))
                    (setq in-return-level (1- in-return-level))))
                (when (equal token 'T_RETURN)
                  (phps-mode-debug-message "Started return")
                  (setq in-return t)
                  (push curly-bracket-level in-return-curly-bracket-level)
                  (setq in-return-level (1+ in-return-level)))

                ;; Did we encounter a token that supports extra special alternative control structures?
                (when (equal token 'T_CASE)
                  (setq after-extra-special-control-structure t)
                  (setq nesting-key token)
                  (setq after-extra-special-control-structure-first-on-line first-token-on-line)

                  (when (and switch-case-alternative-stack
                             (= (1- alternative-control-structure-level) (car switch-case-alternative-stack)))

                    (phps-mode-debug-message
                     (message "Found CASE %s vs %s" (1- alternative-control-structure-level) (car switch-case-alternative-stack)))

                    (setq alternative-control-structure-level (1- alternative-control-structure-level))
                    (when first-token-on-line
                      (setq first-token-is-nesting-decrease t))
                    (pop switch-case-alternative-stack))

                  (push alternative-control-structure-level switch-case-alternative-stack)))

              ;; Do we have one token look-ahead?
              (when token

                (phps-mode-debug-message (message "Processing token: %s" token))
                
                ;; Calculate nesting
                (setq
                 nesting-end
                 (+
                  round-bracket-level
                  square-bracket-level
                  curly-bracket-level
                  alternative-control-structure-level
                  in-assignment-level
                  in-class-declaration-level
                  in-concatenation-level
                  in-return-level
                  in-object-operator-level))

                ;; Keep track of whether we are inside a HEREDOC or NOWDOC
                (when (equal token 'T_START_HEREDOC)
                  (setq in-heredoc t)
                  (setq in-heredoc-started-this-line t))
                (when (equal token 'T_END_HEREDOC)
                  (setq in-heredoc nil)
                  (setq in-heredoc-ended-this-line t))

                ;; Has nesting increased?
                (when (and nesting-stack
                           (<= nesting-end (car (car nesting-stack))))
                  (let ((nesting-decrement 0))

                    ;; Handle case were nesting has decreased less than next as well
                    (while (and nesting-stack
                                (<= nesting-end (car (car nesting-stack))))
                      (phps-mode-debug-message
                       (message
                        "\nPopping %s from nesting-stack since %s is lesser or equal to %s, next value is: %s\n"
                        (car nesting-stack)
                        nesting-end
                        (car (car nesting-stack))
                        (nth 1 nesting-stack)))
                      (pop nesting-stack)
                      (setq nesting-decrement (1+ nesting-decrement)))

                    (if first-token-is-nesting-decrease

                        (progn
                          ;; Decrement column
                          (if allow-custom-column-decrement
                              (progn
                                (phps-mode-debug-message
                                 (message
                                  "Doing custom decrement 1 from %s to %s"
                                  column-level
                                  (- column-level
                                     (- nesting-start nesting-end))))
                                (setq column-level (- column-level (- nesting-start nesting-end)))
                                (setq allow-custom-column-decrement nil))
                            (phps-mode-debug-message
                             (message
                              "Doing regular decrement 1 from %s to %s"
                              column-level
                              (1- column-level)))
                            (setq column-level (- column-level nesting-decrement)))

                          ;; Prevent negative column-values
                          (when (< column-level 0)
                            (setq column-level 0)))

                      (unless temp-post-indent
                        (phps-mode-debug-message
                         (message "Temporary setting post indent %s" column-level))
                        (setq temp-post-indent column-level))

                      ;; Decrement column
                      (if allow-custom-column-decrement
                          (progn
                            (phps-mode-debug-message
                             (message
                              "Doing custom decrement 2 from %s to %s"
                              column-level
                              (- column-level
                                 (- nesting-start nesting-end))))
                            (setq
                             temp-post-indent
                             (- temp-post-indent
                                (- nesting-start nesting-end)))
                            (setq allow-custom-column-decrement nil))
                        (setq temp-post-indent (- temp-post-indent nesting-decrement)))

                      ;; Prevent negative column-values
                      (when (< temp-post-indent 0)
                        (setq temp-post-indent 0))

                      )))

                ;; Are we on a new line or is it the last token of the buffer?
                (if (> next-token-start-line-number token-start-line-number)
                    (progn


                      ;; ;; Start indentation might differ from ending indentation in cases like } else {
                      (setq column-level-start column-level)

                      ;; Support temporarily pre-indent
                      (when temp-pre-indent
                        (setq column-level-start temp-pre-indent)
                        (setq temp-pre-indent nil))

                      ;; HEREDOC lines should have zero indent
                      (when (or (and in-heredoc
                                     (not in-heredoc-started-this-line))
                                in-heredoc-ended-this-line)
                        (setq column-level-start 0))

                      ;; Inline HTML should have zero indent
                      (when (and first-token-is-inline-html
                                 (not inline-html-is-whitespace))
                        (phps-mode-debug-message
                         (message "Setting column-level to inline HTML indent: %s" inline-html-indent-start))
                        (setq column-level-start inline-html-indent-start))

                      ;; Save line indent
                      (phps-mode-debug-message
                       (message
                        "Process line ending.	nesting: %s-%s,	line-number: %s-%s,	indent: %s.%s,	token: %s"
                        nesting-start
                        nesting-end
                        token-start-line-number
                        token-end-line-number
                        column-level-start
                        tuning-level
                        token))

                      (when (and (> token-start-line-number 0)
                                 (or
                                  (not first-token-is-inline-html)
                                  inline-html-is-whitespace
                                  inline-html-rest-is-whitespace))
                        (phps-mode-debug-message
                         (message
                          "Putting indent on line %s to %s at #C"
                          token-start-line-number
                          column-level-start))
                        (puthash
                         token-start-line-number
                         `(,column-level-start ,tuning-level)
                         line-indents))

                      ;; Support trailing indent decrements
                      (when temp-post-indent
                        (setq column-level temp-post-indent)
                        (setq temp-post-indent nil))

                      ;; Increase indentation
                      (when (and (> nesting-end 0)
                                 (or (not nesting-stack)
                                     (> nesting-end (car (cdr (car nesting-stack))))))
                        (let ((nesting-stack-end 0))
                          (when nesting-stack
                            (setq nesting-stack-end (car (cdr (car nesting-stack)))))

                          (if allow-custom-column-increment
                              (progn
                                (setq column-level (+ column-level (- nesting-end nesting-start)))
                                (setq allow-custom-column-increment nil))
                            (setq column-level (1+ column-level)))

                          (phps-mode-debug-message
                           (message
                            "\nPushing (%s %s %s %s) to nesting-stack since %s is greater than %s or stack is empty\n"
                            nesting-start
                            nesting-end
                            nesting-key
                            token
                            nesting-end
                            (car (cdr (car nesting-stack))))
                           )
                          (push `(,nesting-stack-end ,nesting-end ,nesting-key ,token) nesting-stack)))


                      ;; Does token span over several lines and is it not a INLINE_HTML token?
                      (when (and (> token-end-line-number token-start-line-number)
                                 (not (equal token 'T_INLINE_HTML)))
                        (let ((column-level-end column-level))

                          ;; HEREDOC lines should have zero indent
                          (when (or (and in-heredoc
                                         (not in-heredoc-started-this-line))
                                    in-heredoc-ended-this-line)
                            (setq column-level-end 0))

                          ;; Indent doc-comment lines with 1 tuning
                          (when (equal token 'T_DOC_COMMENT)
                            (setq tuning-level 1))

                          (let ((token-line-number-diff (1- (- token-end-line-number token-start-line-number))))
                            (while (>= token-line-number-diff 0)
                              (phps-mode-debug-message
                               (message
                                "Putting indent on line %s to %s at #A"
                                (- token-end-line-number token-line-number-diff)
                                column-level-end))
                              (puthash
                               (- token-end-line-number token-line-number-diff)
                               `(,column-level-end ,tuning-level) line-indents)
                              ;; (message "Saved line %s indent %s %s" (- token-end-line-number token-line-number-diff) column-level tuning-level)
                              (setq token-line-number-diff (1- token-line-number-diff))))

                          ;; Rest tuning-level used for comments
                          (setq tuning-level 0)))

                      ;; Indent token-less lines here in between last tokens if distance is more than 1 line
                      (when (and (> next-token-start-line-number (1+ token-end-line-number))
                                 (not (equal token 'T_CLOSE_TAG)))

                        (phps-mode-debug-message
                         (message
                          "\nDetected token-less lines between %s and %s, should have indent: %s\n"
                          token-end-line-number
                          next-token-start-line-number
                          column-level))

                        (let ((token-line-number-diff (1- (- next-token-start-line-number token-end-line-number))))
                          (while (> token-line-number-diff 0)
                            (phps-mode-debug-message
                             (message
                              "Putting indent at line %s indent %s at #B"
                              (- next-token-start-line-number token-line-number-diff)
                              column-level))
                            (puthash
                             (- next-token-start-line-number token-line-number-diff)
                             `(,column-level ,tuning-level) line-indents)
                            (setq token-line-number-diff (1- token-line-number-diff)))))


                      ;; Calculate indentation level at start of line
                      (setq
                       nesting-start
                       (+
                        round-bracket-level
                        square-bracket-level
                        curly-bracket-level
                        alternative-control-structure-level
                        in-assignment-level
                        in-class-declaration-level
                        in-concatenation-level
                        in-return-level
                        in-object-operator-level))

                      ;; Set initial values for tracking first token
                      (when (> token-start-line-number last-line-number)
                        (setq inline-html-indent-start inline-html-indent)
                        (setq first-token-on-line t)
                        (setq first-token-is-nesting-decrease nil)
                        (setq first-token-is-inline-html nil)
                        (setq in-class-declaration-level 0)
                        (setq class-declaration-started-this-line nil)
                        (setq in-heredoc-started-this-line nil)
                        (setq special-control-structure-started-this-line nil)

                        ;; When line ends with multi-line inline-html flag first token as inline-html
                        (when (and
                               (equal token 'T_INLINE_HTML)
                               (not inline-html-is-whitespace)
                               (> token-end-line-number token-start-line-number))

                          (setq inline-html-is-whitespace
                                (not (null
                                      (string-match "[\r\n][ \f\t]+$" (substring string (1- token-start) (1- token-end))))))
                          (phps-mode-debug-message
                           (message "Trailing inline html line is whitespace: %s" inline-html-is-whitespace))
                          (phps-mode-debug-message
                           (message
                            "Setting first-token-is-inline-html to true since last token on line is inline-html and spans several lines"))
                          (setq first-token-is-inline-html t))))

                  ;; Current token is not first if it's not <?php or <?=
                  (unless (or (equal token 'T_OPEN_TAG)
                              (equal token 'T_OPEN_TAG_WITH_ECHO))
                    (setq first-token-on-line nil))

                  (when (> token-end-line-number token-start-line-number)
                    ;; (message "Token not first on line %s starts at %s and ends at %s" token token-start-line-number token-end-line-number)
                    (when (equal token 'T_DOC_COMMENT)
                      (setq tuning-level 1))

                    (let ((token-line-number-diff (1- (- token-end-line-number token-start-line-number))))
                      (while (>= token-line-number-diff 0)
                        (phps-mode-debug-message
                         (message
                          "Putting indent on line %s to %s at #E"
                          (-
                           token-end-line-number
                           token-line-number-diff)
                          column-level))
                        (puthash
                         (- token-end-line-number token-line-number-diff)
                         `(,column-level ,tuning-level) line-indents)
                        (setq token-line-number-diff (1- token-line-number-diff))))
                    (setq tuning-level 0))))

              ;; Update current token
              (setq previous-token token)
              (setq token next-token)
              (setq token-start next-token-start)
              (setq token-end next-token-end)
              (setq token-start-line-number next-token-start-line-number)
              (setq token-end-line-number next-token-end-line-number)
              (setq token-number (1+ token-number))))
          (list (nreverse imenu-index) line-indents)))
    (list nil nil)))

(defun phps-mode-lex-analyzer--indent-line ()
  "Indent line."
  (phps-mode-debug-message (message "Indent line"))
  (phps-mode-lex-analyzer--process-current-buffer)
  (if phps-mode-lex-analyzer--processed-buffer-p
      (if phps-mode-lex-analyzer--lines-indent
          (let ((line-number (line-number-at-pos (point))))
            (phps-mode-debug-message (message "Found lines indent index, indenting.."))
            (let ((indent (gethash line-number phps-mode-lex-analyzer--lines-indent)))
              (if indent
                  (progn
                    (let ((indent-sum (+ (* (car indent) tab-width) (car (cdr indent))))
                          (old-indentation (current-indentation))
                          (line-start (line-beginning-position)))

                      (unless old-indentation
                        (setq old-indentation 0))

                      ;; Only continue if current indentation is wrong
                      (if (not (equal indent-sum old-indentation))
                          (progn

                            (setq phps-mode-lex-analyzer--allow-after-change-p nil)
                            (indent-line-to indent-sum)
                            (setq phps-mode-lex-analyzer--allow-after-change-p t)

                            (let ((indent-diff (- (current-indentation) old-indentation)))


                              ;; When indent is changed the trailing tokens and states just
                              ;; need to adjust their positions, this will improve speed of indent-region a lot
                              (phps-mode-lex-analyzer--move-tokens line-start indent-diff)
                              (phps-mode-lex-analyzer--move-states line-start indent-diff)
                              (phps-mode-lex-analyzer--move-imenu-index line-start indent-diff)

                              (phps-mode-debug-message
                               (message "Lexer tokens after move: %s" phps-mode-lex-analyzer--tokens)
                               (message "Lexer states after move: %s" phps-mode-lex-analyzer--states))

                              ;; Reset change flag
                              (phps-mode-lex-analyzer--reset-changes)
                              (phps-mode-lex-analyzer--cancel-idle-timer))))))
                (phps-mode-lex-analyzer--alternative-indentation (point))
                (phps-mode-debug-message
                 (message "Did not find indent for line, using alternative indentation..")))))
        (phps-mode-lex-analyzer--alternative-indentation (point))
        (phps-mode-debug-message
         (message "Did not find lines indent index, using alternative indentation..")))
    (phps-mode-lex-analyzer--alternative-indentation (point))
    (phps-mode-debug-message
     (message "Using alternative indentation since buffer is not processed yet"))))

(defun phps-mode-lex-analyzer--alternative-indentation (&optional point)
  "Apply alternative indentation at POINT here."
  (unless point
    (setq point (point)))
  (let ((new-indentation 0)
        (point-at-end-of-line (equal point (line-end-position))))
    (save-excursion
      (let ((line-number (line-number-at-pos point))
            (move-length 0)
            (line-is-empty t)
            line-beginning-position
            line-end-position
            line-string
            current-line-string)
        (goto-char point)
        (setq
         current-line-string
         (buffer-substring-no-properties
          (line-beginning-position)
          (line-end-position))
         )
        (when (> line-number 1)
          (while (and
                  (> line-number 0)
                  line-is-empty)
            (forward-line -1)
            (setq line-number (1- line-number))
            (beginning-of-line)
            (setq line-beginning-position (line-beginning-position))
            (setq line-end-position (line-end-position))
            (setq
             line-string
             (buffer-substring-no-properties line-beginning-position line-end-position)
             )
            (setq line-is-empty (string-match-p "^[ \t\f\r\n]*$" line-string))
            (setq move-length (1+ move-length))
            )

          (unless line-is-empty
            (let* ((old-indentation (current-indentation))
                   (current-line-starts-with-closing-bracket (phps-mode-lex-analyzer--string-starts-with-closing-bracket-p current-line-string))
                   (line-starts-with-closing-bracket (phps-mode-lex-analyzer--string-starts-with-closing-bracket-p line-string))
                   (line-ends-with-assignment (phps-mode-lex-analyzer--string-ends-with-assignment-p line-string))
                   (line-ends-with-semicolon (phps-mode-lex-analyzer--string-ends-with-semicolon-p line-string))
                   (bracket-level (phps-mode-lex-analyzer--get-string-brackets-count line-string)))
              (setq new-indentation old-indentation)
              (forward-line move-length)

              (when (> bracket-level 0)
                (if (< bracket-level tab-width)
                    (setq new-indentation (+ new-indentation 1))
                  (setq new-indentation (+ new-indentation tab-width))))

              (when (= bracket-level -1)
                (setq new-indentation (1- new-indentation)))

              (when (and (= bracket-level 0)
                         line-starts-with-closing-bracket)
                (setq new-indentation (+ new-indentation tab-width)))

              (when current-line-starts-with-closing-bracket
                (setq new-indentation (- new-indentation tab-width)))

              (when line-ends-with-assignment
                (setq new-indentation (+ new-indentation tab-width)))

              (when line-ends-with-semicolon
                ;; Back-trace buffer from previous line
                ;; Determine if semi-colon ended an assignment or not
                (forward-line (* -1 move-length))
                (let ((not-found t)
                      (is-assignment nil))
                  (while (and
                          not-found
                          (search-backward-regexp "\\(;\\|=\\)" nil t))
                    (let ((match (buffer-substring-no-properties (match-beginning 0) (match-end 0))))
                      (setq is-assignment (string= match "="))
                      (setq not-found nil)
                      ))
                  ;; If it ended an assignment, decrease indentation
                  (when (and is-assignment
                             (> bracket-level -1))
                    ;; NOTE stuff like $var = array(\n    4\n);\n
                    ;; will end assignment but also decrease bracket-level
                    (setq new-indentation (- new-indentation tab-width))))

                (goto-char point))

              ;; Decrease indentation if current line decreases in bracket level
              (when (< new-indentation 0)
                (setq new-indentation 0))

              (indent-line-to new-indentation))))))
    ;; Only move to end of line if point is the current point and is at end of line
    (when (equal point (point))
      (if point-at-end-of-line
          (end-of-line)
        (back-to-indentation)))
    new-indentation))

(defun phps-mode-lex-analyzer--get-string-brackets-count (string)
  "Get bracket count for STRING."
  (let ((bracket-level 0)
        (start 0)
        (line-is-empty
         (string-match-p "^[ \t\f\r\n]*$" string)))
    (unless line-is-empty
      (while (string-match
              "\\([\]{}()[]\\|<[a-zA-Z]+\\|</[a-zA-Z]+\\|/>\\|^/\\*\\*\\|^ \\*/\\)"
              string
              start)
        (setq start (match-end 0))
        (let ((bracket (substring string (match-beginning 0) (match-end 0))))
          (cond
           ((or
             (string= bracket "{")
             (string= bracket "[")
             (string= bracket "(")
             (string= bracket "<")
             (string-match "<[a-zA-Z]+" bracket))
            (setq bracket-level (+ bracket-level tab-width)))
           ((string-match "^ \\*/" bracket )
            (setq bracket-level (- bracket-level 1)))
           ((or
             (string-match "^/\\*\\*" bracket)
             (string-match "^ \\*" bracket))
            (setq bracket-level (+ bracket-level 1)))
           (t
            (setq bracket-level (- bracket-level tab-width)))))))
    bracket-level))

(defun phps-mode-lex-analyzer--string-starts-with-closing-bracket-p (string)
  "Get bracket count for STRING."
  (string-match-p "^[\r\t ]*\\([\]})[]\\|</[a-zA-Z]+\\|/>\\)" string))

(defun phps-mode-lex-analyzer--string-ends-with-assignment-p (string)
  "Get bracket count for STRING."
  (string-match-p "[\t ]*=[\t ]*$" string))

(defun phps-mode-lex-analyzer--string-ends-with-semicolon-p (string)
  "Get bracket count for STRING."
  (string-match-p ";[\t ]*$" string))

(defun phps-mode-lex-analyzer--cancel-idle-timer ()
  "Cancel idle timer."
  (phps-mode-debug-message (message "Cancelled idle timer"))
  (when phps-mode-lex-analyzer--idle-timer
    (cancel-timer phps-mode-lex-analyzer--idle-timer)
    (setq phps-mode-lex-analyzer--idle-timer nil)))

(defun phps-mode-lex-analyzer--start-idle-timer ()
  "Start idle timer."
  (phps-mode-debug-message (message "Enqueued idle timer"))
  (when (boundp 'phps-mode-idle-interval)
    (let ((buffer (current-buffer)))
      (setq
       phps-mode-lex-analyzer--idle-timer
       (run-with-idle-timer
        phps-mode-idle-interval
        nil
        #'phps-mode-lex-analyzer--process-changes buffer)))))

(defun phps-mode-lex-analyzer--reset-imenu ()
  "Reset imenu index."
  (when (and (boundp 'imenu--index-alist)
             imenu--index-alist)
    (setq imenu--index-alist nil)
    (phps-mode-debug-message (message "Cleared Imenu index"))))

(defun phps-mode-lex-analyzer--after-change (start stop length)
  "Track buffer change from START to STOP with LENGTH."
  (phps-mode-debug-message
   (message "After change %s - %s, length: %s" start stop length))

  (if phps-mode-lex-analyzer--allow-after-change-p
      (progn
        (phps-mode-debug-message (message "After change registration is enabled"))
        
        ;; If we haven't scheduled incremental lexer before - do it
        (when (and (boundp 'phps-mode-idle-interval)
                   phps-mode-idle-interval
                   (not phps-mode-lex-analyzer--idle-timer))

          (phps-mode-lex-analyzer--reset-imenu)
          (phps-mode-lex-analyzer--start-idle-timer)
          (phps-mode-serial-commands--kill-active (buffer-name)))

        (when (or
               (not phps-mode-lex-analyzer--change-min)
               (< start phps-mode-lex-analyzer--change-min))
          (setq phps-mode-lex-analyzer--change-min start)))
    (phps-mode-debug-message (message "After change registration is disabled"))))

(defun phps-mode-lex-analyzer--imenu-create-index ()
  "Get Imenu for current buffer."
  (phps-mode-lex-analyzer--process-current-buffer)
  phps-mode-lex-analyzer--imenu)

(defun phps-mode-lex-analyzer--comment-region (beg end &optional _arg)
  "Comment region from BEG to END with optional _ARG."
  ;; Iterate tokens from beginning to end and comment out all PHP code
  (when-let ((tokens phps-mode-lex-analyzer--tokens))
    (let ((token-comment-start nil)
          (token-comment-end nil)
          (in-token-comment nil)
          (offset 0))
      (dolist (token tokens)
        (let ((token-label (car token))
              (token-start (car (cdr token)))
              (token-end (cdr (cdr token))))
          (when (and (>= token-start beg)
                     (<= token-end end))

            (if in-token-comment
                (cond
                 ((or
                   (equal token-label 'T_COMMENT)
                   (equal token-label 'T_DOC_COMMENT)
                   (equal token-label 'T_CLOSE_TAG))
                  (phps-mode-debug-message
                   (message
                    "Comment should end at previous token %s %s"
                    token-label
                    token-comment-end))
                  (setq in-token-comment nil))
                 (t (setq token-comment-end token-end)))

              ;; When we have a start and end of comment, comment it out
              (when (and
                     token-comment-start
                     token-comment-end)
                (let ((offset-comment-start (+ token-comment-start offset))
                      (offset-comment-end))
                  (save-excursion
                    (goto-char offset-comment-start)
                    (insert "/* "))
                  (setq offset (+ offset 3))
                  (setq offset-comment-end (+ token-comment-end offset))
                  (save-excursion
                    (goto-char offset-comment-end)
                    (insert " */"))
                  (setq offset (+ offset 3))
                  (phps-mode-debug-message
                   (message "Commented out %s-%s" offset-comment-start offset-comment-end)))
                (setq token-comment-start nil)
                (setq token-comment-end nil))

              (cond
               ((or
                 (equal token-label 'T_INLINE_HTML)
                 (equal token-label 'T_COMMENT)
                 (equal token-label 'T_DOC_COMMENT)
                 (equal token-label 'T_OPEN_TAG)
                 (equal token-label 'T_OPEN_TAG_WITH_ECHO)))
               (t
                (phps-mode-debug-message
                 (message
                  "Comment should start at %s %s-%s"
                  token-label
                  token-start
                  token-end))
                (setq token-comment-start token-start)
                (setq token-comment-end token-end)
                (setq in-token-comment t)))))))

      ;; When we have a start and end of comment, comment it out
      (when (and
             in-token-comment
             token-comment-start
             token-comment-end)
        (let ((offset-comment-start (+ token-comment-start offset))
              (offset-comment-end))
          (save-excursion
            (goto-char offset-comment-start)
            (insert "/* "))
          (setq offset (+ offset 3))
          (setq offset-comment-end (+ token-comment-end offset))
          (save-excursion
            (goto-char offset-comment-end)
            (insert " */"))
          (setq offset (+ offset 3))
          (phps-mode-debug-message
           (message "Commented out trailing %s-%s" offset-comment-start offset-comment-end)))
        (setq token-comment-start nil)
        (setq token-comment-end nil)))))

(defun phps-mode-lex-analyzer--uncomment-region (beg end &optional _arg)
  "Un-comment region from BEG to END with optional ARG."
  ;; Iterate tokens from beginning to end and uncomment out all commented PHP code
  (when-let ((tokens phps-mode-lex-analyzer--tokens))
    (let ((offset 0))
      (dolist (token tokens)
        (let ((token-label (car token))
              (token-start (car (cdr token)))
              (token-end (cdr (cdr token))))
          (when (and (>= token-start beg)
                     (<= token-end end))
            (when (or
                   (equal token-label 'T_COMMENT)
                   (equal token-label 'T_DOC_COMMENT))

              (phps-mode-debug-message
               (message "Un-comment %s comment at %s %s" token-label token-start token-end))

              (let ((offset-comment-start (+ token-start offset))
                    (offset-comment-end))

                (if (equal token-label 'T_DOC_COMMENT)
                    (progn
                      (phps-mode-debug-message
                       (message "Un-comment doc comment at %s-%s" token-start token-end))
                      (save-excursion
                        (goto-char offset-comment-start)
                        (delete-char 4))
                      (setq offset (- offset 4))
                      (setq offset-comment-end (+ token-end offset))
                      (save-excursion
                        (goto-char offset-comment-end)
                        (delete-char -3))
                      (setq offset (- offset 3)))

                  (phps-mode-debug-message
                   (message "Un-comment comment starting at %s" token-start))

                  (cond

                   ((string=
                     (buffer-substring-no-properties offset-comment-start (+ offset-comment-start 1))
                     "#")
                    (save-excursion
                      (goto-char offset-comment-start)
                      (delete-char 1))
                    (setq offset (- offset 1)))
                   ((string=
                     (buffer-substring-no-properties offset-comment-start (+ offset-comment-start 2))
                     "//")
                    (save-excursion
                      (goto-char offset-comment-start)
                      (delete-char 2))
                    (setq offset (- offset 2)))
                   (t
                    (save-excursion
                      (goto-char offset-comment-start)
                      (delete-char 3))
                    (setq offset (- offset 3))))

                  
                  (setq offset-comment-end (+ token-end offset))
                  (if (string=
                       (buffer-substring-no-properties (- offset-comment-end 3) offset-comment-end)
                       " */")
                      (progn
                        (phps-mode-debug-message
                         (message "Un-comment comment ending at %s" token-end))
                        (save-excursion
                          (goto-char offset-comment-end)
                          (delete-char -3))
                        (setq offset (- offset 3)))
                    (phps-mode-debug-message
                     (message
                      "Do not un-comment comment ending at %s"
                      token-end))))))))))))

(defun phps-mode-lex-analyzer--setup (start end)
  "Just prepare other lexers for lexing region START to END."
  (require 'phps-mode-macros)
  (phps-mode-debug-message (message "Lexer setup %s - %s" start end))
  (unless phps-mode-lex-analyzer--state
    (setq phps-mode-lex-analyzer--state 'ST_INITIAL)))

(defun phps-mode-lex-analyzer--lex-string (contents &optional start end states state state-stack tokens)
  "Run lexer on CONTENTS."
  ;; Create a separate buffer, run lexer inside of it, catch errors and return them
  ;; to enable nice presentation
  (require 'phps-mode-macros)
  (let ((errors))
    (let ((buffer (generate-new-buffer "*PHPs Lexer*")))

      ;; Create temporary buffer and run lexer in it
      (save-excursion
        (switch-to-buffer buffer)
        (insert contents)

        (if tokens
            (setq phps-mode-lexer--tokens (nreverse tokens))
          (setq phps-mode-lexer--tokens nil))
        (if state
            (setq phps-mode-lexer--state state)
          (setq phps-mode-lexer--state 'ST_INITIAL))
        (if states
            (setq phps-mode-lexer--states states)
          (setq phps-mode-lexer--states nil))
        (if state-stack
            (setq phps-mode-lexer--state-stack state-stack)
          (setq phps-mode-lexer--state-stack nil))

        ;; Setup lexer settings
        (when (boundp 'phps-mode-syntax-table)
          (setq semantic-lex-syntax-table phps-mode-syntax-table))
        (setq semantic-lex-analyzer #'phps-mode-lex-analyzer--re2c-lex)

        ;; Catch errors to kill generated buffer
        (condition-case conditions
            (progn
              ;; Run lexer or incremental lexer
              (if (and start end)
                  (let ((incremental-tokens (semantic-lex start end)))
                    (setq
                     phps-mode-lex-analyzer--tokens
                     (append tokens incremental-tokens)))
                (setq
                 phps-mode-lex-analyzer--tokens
                 (semantic-lex-buffer))))
          (error (progn
                   (kill-buffer)
                   (signal 'error (cdr conditions)))))

        ;; Copy variables outside of buffer
        (setq state phps-mode-lexer--state)
        (setq state-stack phps-mode-lexer--state-stack)
        (setq states phps-mode-lexer--states)
        (setq tokens (nreverse phps-mode-lexer--tokens))
        (kill-buffer)))
    (list tokens states state state-stack errors)))

(provide 'phps-mode-lex-analyzer)

;;; phps-mode-lex-analyzer.el ends here
