;; [[file:~/.emacs.d/myinit.org::*repos][repos:1]]
(add-to-list 'package-archives '("org" . "https://orgmode.org/elpa/") t)
;; repos:1 ends here

;; [[file:~/.emacs.d/myinit.org::*interface%20tweaks][interface tweaks:1]]
(setq inhibit-startup-message t)
(tool-bar-mode -1)
(fset 'yes-or-no-p 'y-or-n-p)
(global-set-key (kbd "<f5>") 'revert-buffer)
;; interface tweaks:1 ends here

;; [[file:~/.emacs.d/myinit.org::*which%20key][which key:1]]
(use-package which-key
:ensure t
:config 
(which-key-mode))
;; which key:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Themes%20and%20modeline][Themes and modeline:1]]
(use-package color-theme-modern
:ensure t)
(use-package monokai-pro-theme
:ensure t)
(use-package doom-themes
:ensure t)
(use-package doom-modeline
:ensure t)
(require 'doom-modeline)
(doom-modeline-init)
(load-theme 'monokai-pro t)
;; Themes and modeline:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Ace%20windows%20for%20easywindow%20switching][Ace windows for easywindow switching:1]]
(use-package ace-window
:ensure t
:init
(progn
(setq aw-scope 'global)
(global-set-key (kbd "C-x O") 'other-frame)
(global-set-key [remap other-window] 'ace-window)
(custom-set-faces
'(aw-leading-char-face
((t (:inherit ace-jump-face-foreground :height 3.0)))))
))
;; Ace windows for easywindow switching:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Org%20mode][Org mode:1]]
(use-package org 
      :ensure t
      :pin org)

    (setenv "BROWSER" "chromium-browser")
    (use-package org-bullets
      :ensure t
      :config
      (add-hook 'org-mode-hook (lambda () (org-bullets-mode 1))))
    (custom-set-variables
     '(org-directory "~/Sync/orgfiles")
     '(org-default-notes-file (concat org-directory "/notes.org"))
     '(org-export-html-postamble nil)
     '(org-hide-leading-stars t)
     '(org-startup-folded (quote overview))
     '(org-startup-indented t)
     '(org-confirm-babel-evaluate nil)
     '(org-src-fontify-natively t)
     )

    (setq org-file-apps
          (append '(
                    ("\\.pdf\\'" . "evince %s")
                    ("\\.x?html?\\'" . "/usr/bin/chromium-browser %s")
                    ) org-file-apps ))

    (global-set-key "\C-ca" 'org-agenda)
    (setq org-agenda-start-on-weekday nil)
    (setq org-agenda-custom-commands
          '(("c" "Simple agenda view"
             ((agenda "")
              (alltodo "")))))

    (global-set-key (kbd "C-c c") 'org-capture)

    (setq org-agenda-files (list "~/Sync/orgfiles/gcal.org"
                                 "~/Sync/orgfiles/soe-cal.org"
                                 "~/Sync/orgfiles/i.org"
                                 "~/Sync/orgfiles/schedule.org"))
    (setq org-capture-templates
          '(("a" "Appointment" entry (file  "~/Sync/orgfiles/gcal.org" )
             "* %?\n\n%^T\n\n:PROPERTIES:\n\n:END:\n\n")
            ("l" "Link" entry (file+headline "~/Sync/orgfiles/links.org" "Links")
             "* %? %^L %^g \n%T" :prepend t)
            ("b" "Blog idea" entry (file+headline "~/Sync/orgfiles/i.org" "Blog Topics:")
             "* %?\n%T" :prepend t)
            ("t" "To Do Item" entry (file+headline "~/Sync/orgfiles/i.org" "To Do and Notes")
             "* TODO %?\n%u" :prepend t)
            ("m" "Mail To Do" entry (file+headline "~/Sync/orgfiles/i.org" "To Do and Notes")
             "* TODO %a\n %?" :prepend t)
            ("g" "GMail To Do" entry (file+headline "~/Sync/orgfiles/i.org" "To Do and Notes")
             "* TODO %^L\n %?" :prepend t)
            ("n" "Note" entry (file+headline "~/Sync/orgfiles/i.org" "Notes")
             "* %u %? " :prepend t)
            ))
  

    (defadvice org-capture-finalize 
        (after delete-capture-frame activate)  
      "Advise capture-finalize to close the frame"  
      (if (equal "capture" (frame-parameter nil 'name))  
          (delete-frame)))

    (defadvice org-capture-destroy 
        (after delete-capture-frame activate)  
      "Advise capture-destroy to close the frame"  
      (if (equal "capture" (frame-parameter nil 'name))  
          (delete-frame)))  

    (use-package noflet
      :ensure t )
    (defun make-capture-frame ()
      "Create a new frame and run org-capture."
      (interactive)
      (make-frame '((name . "capture")))
      (select-frame-by-name "capture")
      (delete-other-windows)
      (noflet ((switch-to-buffer-other-window (buf) (switch-to-buffer buf)))
        (org-capture)))
;; (require 'ox-beamer)
;; for inserting inactive dates
    (define-key org-mode-map (kbd "C-c >") (lambda () (interactive (org-time-stamp-inactive))))

    (use-package htmlize :ensure t)

    (setq org-ditaa-jar-path "/usr/share/ditaa/ditaa.jar")
;; Org mode:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Swiper%20/%20Ivy%20/%20Counsel][Swiper / Ivy / Counsel:1]]
(use-package counsel
:ensure t
  :bind
  (("M-y" . counsel-yank-pop)
   :map ivy-minibuffer-map
   ("M-y" . ivy-next-line)))




  (use-package ivy
  :ensure t
  :diminish (ivy-mode)
  :bind (("C-x b" . ivy-switch-buffer))
  :config
  (ivy-mode 1)
  (setq ivy-use-virtual-buffers t)
  (setq ivy-count-format "%d/%d ")
  (setq ivy-display-style 'fancy))


  (use-package swiper
  :ensure t
  :bind (("C-s" . swiper-isearch)
	 ("C-r" . swiper-isearch)
	 ("C-c C-r" . ivy-resume)
	 ("M-x" . counsel-M-x)
	 ("C-x C-f" . counsel-find-file))
  :config
  (progn
    (ivy-mode 1)
    (setq ivy-use-virtual-buffers t)
    (setq ivy-display-style 'fancy)
    (define-key read-expression-map (kbd "C-r") 'counsel-expression-history)
    ))
;; Swiper / Ivy / Counsel:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Avy%20-%20navigate%20by%20searching%20for%20a%20letter%20on%20the%20screen%20and%20jumping%20to%20it][Avy - navigate by searching for a letter on the screen and jumping to it:1]]
(use-package avy
:ensure t
:bind ("M-s" . avy-goto-word-1)) ;; changed from char as per jcs
;; Avy - navigate by searching for a letter on the screen and jumping to it:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Yasnippet][Yasnippet:1]]
(use-package yasnippet
      :ensure t
      :init
        (yas-global-mode 1))

;    (use-package yasnippet-snippets
;      :ensure t)
;; Yasnippet:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Undo%20Tree][Undo Tree:1]]
(use-package undo-tree
  :ensure t
  :init
  (global-undo-tree-mode))
;; Undo Tree:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Misc%20packages][Misc packages:1]]
; Highlights the current cursor line
  (global-hl-line-mode t)
  
  ; flashes the cursor's line when you scroll
  (use-package beacon
  :ensure t
  :config
  (beacon-mode 1)
  ; (setq beacon-color "#666600")
  )
  
  ; deletes all the whitespace when you hit backspace or delete
  (use-package hungry-delete
  :ensure t
  :config
  (global-hungry-delete-mode))
  

  (use-package multiple-cursors
  :ensure t)

  ; expand the marked region in semantic increments (negative prefix to reduce region)
  (use-package expand-region
  :ensure t
  :config 
  (global-set-key (kbd "C-=") 'er/expand-region))

(setq save-interprogram-paste-before-kill t)


(global-auto-revert-mode 1) ;; you might not want this
(setq auto-revert-verbose nil) ;; or this
(global-set-key (kbd "<f5>") 'revert-buffer)
(global-set-key (kbd "<f6>") 'revert-buffer)
;; Misc packages:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Origami%20folding][Origami folding:1]]
(use-package origami
:ensure t)
;; Origami folding:1 ends here

;; [[file:~/.emacs.d/myinit.org::*IBUFFER][IBUFFER:1]]
(global-set-key (kbd "C-x C-b") 'ibuffer)
(setq ibuffer-saved-filter-groups
      (quote (("default"
               ("dired" (mode . dired-mode))
               ("org" (name . "^.*org$"))
               ("magit" (mode . magit-mode))
               ("IRC" (or (mode . circe-channel-mode) (mode . circe-server-mode)))
               ("web" (or (mode . web-mode) (mode . js2-mode)))
               ("shell" (or (mode . eshell-mode) (mode . shell-mode)))
               ("mu4e" (or

                        (mode . mu4e-compose-mode)
                        (name . "\*mu4e\*")
                        ))
               ("programming" (or
                               (mode . clojure-mode)
                               (mode . clojurescript-mode)
                               (mode . python-mode)
                               (mode . c++-mode)))
               ("emacs" (or
                         (name . "^\\*scratch\\*$")
                         (name . "^\\*Messages\\*$")))
               ))))
(add-hook 'ibuffer-mode-hook
          (lambda ()
            (ibuffer-auto-mode 1)
            (ibuffer-switch-to-saved-filter-groups "default")))

;; don't show these
                                        ;(add-to-list 'ibuffer-never-show-predicates "zowie")
;; Don't show filter groups if there are no buffers in that group
(setq ibuffer-show-empty-filter-groups nil)

;; Don't ask for confirmation to delete marked buffers
(setq ibuffer-expert t)
;; IBUFFER:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Company][Company:1]]
(use-package company
:ensure t
:config
(setq company-idle-delay 0)
(setq company-minimum-prefix-length 3)
(global-company-mode t))
;; Company:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Go-mode][Go-mode:1]]
(add-hook 'go-mode-hook (lambda ()
(add-hook 'before-save-hook 'gofmt-before-save)
(setq tab-width 4)
(setq indent-tabs-mode 1)))
;; Go-mode:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Flycheck][Flycheck:1]]
(use-package flycheck
:ensure t
:init
(global-flycheck-mode t))
;; Flycheck:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Python][Python:1]]
(setq py-python-command "python3")
(setq python-shell-interpreter "python3")
;; Python:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Python][Python:2]]
;; Preset `nlinum-format' for minimum width.
(defun my-nlinum-mode-hook ()
  (when nlinum-mode
    (setq-local nlinum-format
                (concat "%" (number-to-string
                             ;; Guesstimate number of buffer lines.
                             (ceiling (log (max 1 (/ (buffer-size) 80)) 10)))
                        "d"))))
(add-hook 'nlinum-mode-hook #'my-nlinum-mode-hook)
;; Python:2 ends here

;; [[file:~/.emacs.d/myinit.org::*Linum][Linum:1]]

;; Linum:1 ends here

;; [[file:~/.emacs.d/myinit.org::*TypeScript][TypeScript:1]]
(defun setup-tide-mode ()
  (interactive)
  (tide-setup)
  (flycheck-mode +1)
  (setq flycheck-check-syntax-automatically '(save mode-enabled))
  (eldoc-mode +1)
  (tide-hl-identifier-mode +1)
  ;; company is an optional dependency. You have to
  ;; install it separately via package-install
  ;; `M-x package-install [ret] company`
  (company-mode +1))

;; aligns annotation to the right hand side
(setq company-tooltip-align-annotations t)

;; formats the buffer before saving
(add-hook 'before-save-hook 'tide-format-before-save)

(add-hook 'typescript-mode-hook #'setup-tide-mode)
;; TypeScript:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Rust][Rust:1]]
(add-to-list 'load-path "./elpa/rust-mode-20190927.2329")
(autoload 'rust-mode "rust-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-mode))
;; Rust:1 ends here

;; [[file:~/.emacs.d/myinit.org::*PHP][PHP:1]]
(add-hook 'php-mode-hook 'my-php-mode-stuff)

(defun my-php-mode-stuff ()
  (local-set-key (kbd "<f1>") 'my-php-symbol-lookup))


(defun my-php-symbol-lookup ()
  (interactive)
  (let ((symbol (symbol-at-point)))
    (if (not symbol)
        (message "No symbol at point.")

      (browse-url (concat "http://php.net/manual-lookup.php?pattern="
                          (symbol-name symbol))))))
;; PHP:1 ends here
