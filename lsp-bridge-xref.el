;;; lsp-bridge-xref.el --- Xref "support" for lsp-bridge.  -*- lexical-binding: t; -*-
;; Copyright (C) 2025  Dimas Firmansyah
;; Author: Dimas Firmansyah <deirn@bai.lol>
;;
;; This file is NOT part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;; Commentary:
;; Xref "support" for lsp-bridge.
;; Call individual lsp-bridge-xref-* command manually,
;; or enable `lsp-bridge-xref-override-mode' to automatically replace the Xref commands.
;;
;;; Code:

(require 'lsp-bridge)
(require 'xref)

(defconst lsp-bridge-xref--call-is-advice nil)
(defun lsp-bridge-xref--call (api fallback display-action)
  "Call backend Xref API, or FALLBACK if no LSP server found.
If `lsp-bridge-xref--call-is-advice' is non-nil, return nil instead if no LSP server found.
DISPLAY-ACTION is the same as in `xref-show-xrefs-function'."
  (cond
   ((lsp-bridge-has-lsp-server-p)
    (lsp-bridge-call-file-api api this-command (lsp-bridge--position) display-action)
    t)
   (lsp-bridge-xref--call-is-advice nil)
   (t (let ((current-prefix-arg nil)
            (this-command fallback))
        (call-interactively fallback)))))

(defun lsp-bridge-xref--callback (cmd response display-action)
  "CMD, RESPONSE, and DISPLAY-ACTION callback from backend."
  (setq this-command cmd)
  (xref-show-xrefs
   (lambda ()
     (mapcar
      (lambda (e)
        (let ((desc (plist-get e :desc))
              (file (plist-get e :file))
              (line (plist-get e :line))
              (col (plist-get e :col)))
          (xref-make (concat (nth 0 desc)
                             (propertize (nth 1 desc) 'face 'xref-match)
                             (nth 2 desc))
                     (xref-make-file-location file line col))))
      response))
   display-action))


;; Same window

;;;###autoload
(defun lsp-bridge-xref-find-references ()
  "Find references of thing at point using Xref."
  (interactive)
  (lsp-bridge-xref--call "xref_find_references" #'xref-find-references nil))

;;;###autoload
(defun lsp-bridge-xref-find-declaration ()
  "Find declaration of thing at point using Xref."
  (interactive)
  (lsp-bridge-xref--call "xref_find_declaration" #'xref-find-definitions nil))

;;;###autoload
(defun lsp-bridge-xref-find-definition ()
  "Find definition of thing at point using Xref."
  (interactive)
  (lsp-bridge-xref--call "xref_find_definition" #'xref-find-definitions nil))

;;;###autoload
(defun lsp-bridge-xref-find-type-definition ()
  "Find type definition of thing at point using Xref."
  (interactive)
  (lsp-bridge-xref--call "xref_find_type_definition" #'xref-find-definitions nil))

;;;###autoload
(defun lsp-bridge-xref-find-implementation ()
  "Find implementation of thing at point using Xref."
  (interactive)
  (lsp-bridge-xref--call "xref_find_implementation" #'xref-find-definitions nil))


;; Other window

;;;###autoload
(defun lsp-bridge-xref-find-declaration-other-window ()
  "Like `lsp-bridge-xref-find-declaration' but switch to other window."
  (interactive)
  (lsp-bridge-xref--call "xref_find_declaration" #'xref-find-definitions 'window))

;;;###autoload
(defun lsp-bridge-xref-find-definition-other-window ()
  "Like `lsp-bridge-xref-find-definition' but switch to other window."
  (interactive)
  (lsp-bridge-xref--call "xref_find_definition" #'xref-find-definitions 'window))

;;;###autoload
(defun lsp-bridge-xref-find-type-definition-other-window ()
  "Like `lsp-bridge-xref-find-type-definition' but switch to other window."
  (interactive)
  (lsp-bridge-xref--call "xref_find_type_definition" #'xref-find-definitions 'window))

;;;###autoload
(defun lsp-bridge-xref-find-implementation-other-window ()
  "Like `lsp-bridge-xref-find-implementation' but switch to other window."
  (interactive)
  (lsp-bridge-xref--call "xref_find_implementation" #'xref-find-definitions 'window))


;; Other frame

;;;###autoload
(defun lsp-bridge-xref-find-declaration-other-frame ()
  "Like `lsp-bridge-xref-find-declaration' but switch to other frame."
  (interactive)
  (lsp-bridge-xref--call "xref_find_declaration" #'xref-find-definitions 'frame))

;;;###autoload
(defun lsp-bridge-xref-find-definition-other-frame ()
  "Like `lsp-bridge-xref-find-definition' but switch to other frame."
  (interactive)
  (lsp-bridge-xref--call "xref_find_definition" #'xref-find-definitions 'frame))

;;;###autoload
(defun lsp-bridge-xref-find-type-definition-other-frame ()
  "Like `lsp-bridge-xref-find-type-definition' but switch to other frame."
  (interactive)
  (lsp-bridge-xref--call "xref_find_type_definition" #'xref-find-definitions 'frame))

;;;###autoload
(defun lsp-bridge-xref-find-implementation-other-frame ()
  "Like `lsp-bridge-xref-find-implementation' but switch to other frame."
  (interactive)
  (lsp-bridge-xref--call "xref_find_implementation" #'xref-find-definitions 'frame))



(defconst lsp-bridge-xref--command-map
  '((xref-find-references . lsp-bridge-xref-find-references)
    (xref-find-definitions . lsp-bridge-xref-find-definition)
    (xref-find-definitions-other-window . lsp-bridge-xref-find-definition-other-window)
    (xref-find-definitions-other-frame . lsp-bridge-xref-find-definition-other-frame)))

;;;###autoload
(define-minor-mode lsp-bridge-xref-override-mode
  "Override Xref functions to try to use LSP first.
See `lsp-bridge-xref--command-map' for the replacement mapping."
  :global t
  :init-value nil
  (cond
   (lsp-bridge-xref-override-mode
    (define-advice xref--read-identifier (:around (orig-fn prompt) lsp-bridge-xref)
      (let ((cmd (cdr (assoc this-command lsp-bridge-xref--command-map))))
        (when (or (not cmd)
                  (not (let ((lsp-bridge-xref--call-is-advice t)
                             (this-command cmd))
                         (when (funcall cmd)
                           ;; Throw an empty error to abort the xref command
                           ;; FIXME: is there a better way to do this?
                           (user-error "")))))
          (funcall orig-fn prompt)))))
   (t (advice-remove 'xref--read-identifier #'xref--read-identifier@lsp-bridge-xref))))

(provide 'lsp-bridge-xref)
;;; lsp-bridge-xref.el ends here
