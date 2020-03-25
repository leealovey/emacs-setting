;; [[file:~/.emacs.d/myinit.org::*Repos][Repos:1]]
(add-to-list 'package-archives '("org" . "https://orgmode.org/elpa/") t)
;; Repos:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Themes%20and%20modeline][Themes and modeline:1]]
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
;; Themes and modeline:1 ends here

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

;; [[file:~/.emacs.d/myinit.org::*Nlinum][Nlinum:1]]
(use-package linum
:ensure t
:config
:bind (("C-c l" . linum-mode))
)
;; Nlinum:1 ends here

;; [[file:~/.emacs.d/myinit.org::*Goto][Goto:1]]
(use-package goto-chg
:ensure t
:bind (("C-c g c" .  goto-last-change)
       ("C-c g r" . goto-last-chanage-reverse)))

(use-package goto-line-preview
:ensure t
:bind (("C-c g p". goto-line-preview)))
;; Goto:1 ends here
