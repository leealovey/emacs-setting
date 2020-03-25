;; [[file:~/.emacs.d/myinit.org::*repos][repos:1]]
(add-to-list 'package-archives '("org" . "https://orgmode.org/elpa/") t)
;; repos:1 ends here

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
(doom-themes-neotree-config)

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

;; this config for macOS
(setq org-file-apps (append '(
("\\.pdf\\'" . "open %s")
) org-file-apps ))
;; Org-mode:1 ends here
