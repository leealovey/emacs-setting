;; [[file:~/.emacs.d/myinit.org::*Repos][Repos:1]]
(add-to-list 'package-archives '("org" . "https://orgmode.org/elpa/") t)
;; Repos:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Interface%20tweaks][Interface tweaks:1]]
(setq inhibit-startup-message t)
(tool-bar-mode -1)
(fset 'yes-or-no-p 'y-or-n-p)
(global-set-key (kbd "<f5>") 'revert-buffer)
;; Interface tweaks:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Themes%20and%20Modeline][Themes and  Modeline:1]]
(use-package color-theme-modern
:ensure t)
(use-package doom-themes
:ensure t)
(use-package doom-modeline
:ensure t)

(require 'doom-modeline)
(doom-modeline-init)

(load-theme 'doom-monokai-classic  t)

;; Enable flashing mode-line on errors
(doom-themes-visual-bell-config)

;; Enable custom neotree (all-the-icons must be installed!)
;; (doom-themes-neotree-config)

;; or for treemacs users
(setq doom-themes-treemacs-theme "doom-colors") ; use the colorful treemacs theme
(doom-themes-treemacs-config)

;; corrects (and improves) org-mode's native fontification
(doom-themes-org-config)
;; Themes and  Modeline:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Org-mode][Org-mode:1]]
(use-package org
:ensure t
:pin org)

;; this config for linux
;; (setenv "BROWSER" "chromium-browser")
(use-package org-bullets
:ensure t
:config
(add-hook 'org-mode-hook (lambda () (org-bullets-mode 1))))

;; this config for linux
;; (setq org-file-apps (append '(
;; ("\\.pdf\\'" . "evince %s")
;; ("\\.x?html?\\'" . "/usr/bin/chromium-browser %s")
;; ) org-file-apps ))
;; Org-mode:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Treemacs][Treemacs:1]]
(use-package treemacs
  :ensure t
  :defer t
  :init
  (with-eval-after-load 'winum
    (define-key winum-keymap (kbd "M-0") #'treemacs-select-window))
  :config
  (progn
    (setq treemacs-collapse-dirs                 (if treemacs-python-executable 3 0)
          treemacs-deferred-git-apply-delay      0.5
          treemacs-directory-name-transformer    #'identity
          treemacs-display-in-side-window        t
          treemacs-eldoc-display                 t
          treemacs-file-event-delay              5000
          treemacs-file-extension-regex          treemacs-last-period-regex-value
          treemacs-file-follow-delay             0.2
          treemacs-file-name-transformer         #'identity
          treemacs-follow-after-init             t
          treemacs-git-command-pipe              ""
          treemacs-goto-tag-strategy             'refetch-index
          treemacs-indentation                   2
          treemacs-indentation-string            " "
          treemacs-is-never-other-window         nil
          treemacs-max-git-entries               5000
          treemacs-missing-project-action        'ask
          treemacs-no-png-images                 nil
          treemacs-no-delete-other-windows       t
          treemacs-project-follow-cleanup        nil
          treemacs-persist-file                  (expand-file-name ".cache/treemacs-persist" user-emacs-directory)
          treemacs-position                      'left
          treemacs-recenter-distance             0.1
          treemacs-recenter-after-file-follow    nil
          treemacs-recenter-after-tag-follow     nil
          treemacs-recenter-after-project-jump   'always
          treemacs-recenter-after-project-expand 'on-distance
          treemacs-show-cursor                   nil
          treemacs-show-hidden-files             t
          treemacs-silent-filewatch              nil
          treemacs-silent-refresh                nil
          treemacs-sorting                       'alphabetic-asc
          treemacs-space-between-root-nodes      t
          treemacs-tag-follow-cleanup            t
          treemacs-tag-follow-delay              1.5
          treemacs-user-mode-line-format         nil
          treemacs-width                         20)

    ;; The default width and height of the icons is 22 pixels. If you are
    ;; using a Hi-DPI display, uncomment this to double the icon size.
    ;;(treemacs-resize-icons 44)

    (treemacs-follow-mode t)
    (treemacs-filewatch-mode t)
    (treemacs-fringe-indicator-mode t)
    (pcase (cons (not (null (executable-find "git")))
                 (not (null treemacs-python-executable)))
      (`(t . t)
       (treemacs-git-mode 'deferred))
      (`(t . _)
       (treemacs-git-mode 'simple))))
  :bind
  (:map global-map
        ("M-0"       . treemacs-select-window)
        ("C-x t 1"   . treemacs-delete-other-windows)
        ("C-x t t"   . treemacs)
        ("C-x t B"   . treemacs-bookmark)
        ("C-x t C-t" . treemacs-find-file)
        ("C-x t M-t" . treemacs-find-tag)))

(use-package treemacs-evil
  :after treemacs evil
  :ensure t)

(use-package treemacs-projectile
  :after treemacs projectile
  :ensure t)

(use-package treemacs-icons-dired
  :after treemacs dired
  :ensure t
  :config (treemacs-icons-dired-mode))

(use-package treemacs-magit
  :after treemacs magit
  :ensure t)

(use-package treemacs-persp
  :after treemacs persp-mode
  :ensure t
  :config (treemacs-set-scope-type 'Perspectives))
;; Treemacs:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Undo%20tree][Undo tree:1]]
(use-package undo-tree
  :ensure t
  :init
  (global-undo-tree-mode 1)
  (global-set-key (kbd "C-z") 'undo)

  (defalias 'redo 'undo-tree-redo)

   (global-set-key (kbd "C-x r r") 'redo)
)
;; Undo tree:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Ace%20windows][Ace windows:1]]
(use-package ace-window
  :ensure t
  :init 
  (progn 
    (setq aw-scope 'frame)
    (setq aw-background nil)
    (global-set-key (kbd "M-o") 'ace-window)
    (setq aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
  )
)
;; Ace windows:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Which%20key][Which key:1]]
(use-package which-key
  :ensure t
  :config
  (which-key-mode))
;; Which key:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Ibuffer][Ibuffer:1]]
(global-set-key (kbd "C-x C-b") 'ibuffer)

(setq ibuffer-saved-filter-groups
  (quote (("defullt"
    ("dired" (mode . dired-mode))
    ("org" (mode . "^.*org$"))
    ("shell" (or (mode . eshell-mode) (mode . shell-mode)))
    ("programming" (or
    (mode . c++-mode)))
    ("emacs" (or
      (mode . "^\\*scratch\\*$")
      (mode . "^\\*Message\\*$")))
))))

(add-hook 'ibuffer-mode-hook
  (lambda()
    (ibuffer-auto-mode 1)
    (ibuffer-switch-to-saved-filter-groups "default")))

;; Don't show filter groups if there are no buffers in that group
(setq ibuffer-show-empty-filter-groups nil)

;; Don't ask for confirmation to delete marked buffers
(setq ibuffer-expert t)
;; Ibuffer:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Swiper/Ivy/Counsel][Swiper/Ivy/Counsel:1]]
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
;; Swiper/Ivy/Counsel:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Better%20shell][Better shell:1]]
(use-package better-shell
:ensure t
:bind (("C-c s" . better-shell-shell) 
       ("C-c r" . better-shell-remote-open)))
;; Better shell:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Origami][Origami:1]]
(use-package origami
:ensure t
:bind (("C-c o" . origami-mode)) 
)
;; Origami:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Linum][Linum:1]]
(use-package linum
:ensure t
:config
:bind (("C-c l" . linum-mode))
)
;; Linum:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Goto][Goto:1]]
(use-package goto-chg
:ensure t
:bind (("C-c g c" .  goto-last-change)
       ("C-c g r" . goto-last-chanage-reverse)))

(use-package goto-line-preview
:ensure t
:bind (("C-c g p". goto-line-preview)))
;; Goto:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Company][Company:1]]
(use-package company
:ensure t
:config
(setq company-idle-delay 0)
(setq company-minimum-prefix-length 3)
(global-company-mode t))

(use-package company-irony
:ensure t)
;; Company:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Flycheck][Flycheck:1]]
(use-package flycheck
:ensure t
:init 
:config
;; Disable the error indicator on the fringe
(setq flycheck-indication-mode nil)

;; Disable automatic syntax check on new line
(setq flycheck-syntax-automatically '(save 
idle-change 
mode-enable))

;; Immediate syntax checking quite annoying. Slow it down a bit.
(setq flycheck-idle-change-delay 2.0)

;; Customize faces (Colors are copied from solarized definitions

(set-face-attribute 'flycheck-warning nil
:background "#b58900"
:foreground "#262626"
:underline nil)

(set-face-attribute 'flycheck-error nil
:background "dc322f"
:foreground "#262626"
:underline nil)

(global-flycheck-mode t))

(use-package flycheck-irony
:ensure t)
;; Flycheck:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Yasnippet][Yasnippet:1]]
(use-package yasnippet
:ensure t
:init
(bind-key "C-c y" 'yas-about)
:config
(setq yas-snippet-dirs '("~/.emacs.d/snippets"))
(yas-global-mode 1))

;; a collection of yasnippet snippets for many languages
(use-package yasnippet-snippets
:ensure t)
;; Yasnippet:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Elpy][Elpy:1]]
(use-package elpy
:ensure t
:init
(setq python-indent-guess-indent-offset-verbose nil)
(setq python-shell-interpreter "python3.7"
      python-shell-interpreter-args "-i")
(setq elpy-rpc-python-command "python3")
(elpy-enable))
;; Elpy:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Go%20mode][Go mode:1]]
(use-package go-mode
:ensure t
:config
(setq tab-width 4)
)
;; Go mode:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Magit][Magit:1]]
(use-package magit
:ensure t
:bind (
("C-c m c" . magit-commit))
)
;; Magit:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Rust][Rust:1]]
(use-package rust-mode
:ensure t
:config
(setq tab-width 4))

(use-package racer
:ensure t)
;; Rust:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Yaml%20mode][Yaml mode:1]]
(use-package yaml-mode
:ensure t)
;; Yaml mode:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Web%20mode][Web mode:1]]
(use-package web-mode
:ensure t
:config
(progn
(add-to-list 'auto-mode-alist '("\\.phtml\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.tpl\\.php\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.[agj]sp\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.as[cp]x\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.erb\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.mustache\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.djhtml\\'" . web-mode))

(setq web-mode-ac-sources-alist
  '(("php" . (ac-source-yasnippet ac-source-php-auto-yasnippets))
    ("html" . (ac-source-emmet-html-aliases ac-source-emmet-html-snippets))
    ("css" . (ac-source-css-property ac-source-emmet-css-snippets))))

(add-hook 'web-mode-before-auto-complete-hooks
          '(lambda ()
             (let ((web-mode-cur-language
                    (web-mode-language-at-pos)))
               (if (string= web-mode-cur-language "php")
                   (yas-activate-extra-mode 'php-mode)
                 (yas-deactivate-extra-mode 'php-mode))
               (if (string= web-mode-cur-language "css")
                   (setq emmet-use-css-transform t)
		 (setq emment-use-css-transform nil)))))
))
;; Web mode:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Markdown%20mode][Markdown mode:1]]
(use-package markdown-mode
  :ensure t
  :commands (markdown-mode gfm-mode)
  :mode (("README\\.md\\'" . gfm-mode)
         ("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode))
  :init (setq markdown-command "pandoc"))
;; Markdown mode:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Auctex][Auctex:1]]
(use-package tex-site
:defer t
:ensure auctex
:config
(setq TeX-auto-save t))
;; Auctex:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Irony][Irony:1]]
(use-package irony
:ensure t
:config
(progn
  (add-hook 'c++-mode-hook 'irony-mode)
  (add-hook 'c-mode-hook 'irony-mode)
  (add-hook 'objc-mode-hook 'irony-mode)

  (add-hook 'irony-mode-hook 'irony-cdb-autosetup-compile-options)
))

(use-package flycheck-irony
:ensure t)
;; Irony:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Meghanada%20mode][Meghanada mode:1]]
(use-package meghanada
:ensure t
:config
(progn
  (add-hook 'java-mode-hook
    (lambda ()
      ;; meghanada-mode on
      (meghanada-mode t)
      ;; enable telemetry
      (meghanada-telemetry-enable t)
      (flycheck-mode +1)
      (setq c-basic-offset 2)
      ;; use code format
      (add-hook 'before-save-hook 'meghanada-code-beautify-before-save)))
))
;; Meghanada mode:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Php%20mode][Php mode:1]]
(use-package php-mode
:ensure t
:config
(progn 
  (setq tab-width 4)
  (add-hook 'php-mode-hook 'php-enable-default-coding-style)
  (add-hook 'php-mode-hook (lambda () (subword-mode 1)))
  (with-eval-after-load 'php-mode
    (define-key php-mode-map (kbd "C-c C--") 'php-current-class)
    (define-key php-mode-map (kbd "C-c C-=") 'php-current-namespace))
))
;; Php mode:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Docker][Docker:1]]
(use-package docker
:ensure t
:bind ("C-c d" . docker))
;; Docker:1 ends here
