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
;; Enable with `lsp-bridge-xref-override-mode'.
;;
;;; Code:

(require 'lsp-bridge)
(require 'xref)

(defun lsp-bridge-xref--call (kind arg display-action)
  "Call LSP backend for KIND with ARG and DISPLAY-ACTION.
Also sends `lsp-bridge-xref--extra-args'."
  (when (lsp-bridge-call-file-api-p)
    (lsp-bridge-call-file-api (concat "xref_" (symbol-name kind))
                              arg
                              (lsp-bridge--position)
                              display-action
                              this-command)
    t))

(defun lsp-bridge-xref--callback (response display-action cmd)
  "RESPONSE, DISPLAY-ACTION, CMD callback from backend."
  (setq this-command cmd)
  (xref-show-xrefs
   (lambda ()
     (mapcar
      (lambda (e)
        (let* ((desc (plist-get e :desc))
               (file (plist-get e :file))
               (line (plist-get e :line))
               (col (plist-get e :col))
               (len (plist-get e :len))
               (summary (concat (nth 0 desc)
                                (propertize (nth 1 desc) 'face 'xref-match)
                                (nth 2 desc)))
               (location (xref-make-file-location file line col)))
          (if len (xref-make-match summary location len)
            (xref-make summary location))))
      response))
   display-action))

(defconst lsp-bridge--xref-is-from-find-def nil)
(defun lsp-bridge-xref-backend () (when (lsp-bridge-call-file-api-p) 'lsp-bridge))

(cl-defmethod xref-backend-identifier-completion-table ((_backend (eql 'lsp-bridge)))
  (list (substring-no-properties (or (thing-at-point 'symbol) ""))))

(cl-defmethod xref-backend-identifier-at-point ((_backend (eql 'lsp-bridge)))
  (substring-no-properties (or (thing-at-point 'symbol) "")))

;;;###autoload
(define-minor-mode lsp-bridge-xref-override-mode
  "Override Xref functions to try to use LSP first.
See `lsp-bridge-xref--command-map' for the replacement mapping."
  :global t
  :init-value nil
  (cond
   (lsp-bridge-xref-override-mode
    (add-hook 'xref-backend-functions #'lsp-bridge-xref-backend)

    (define-advice xref--find-xrefs (:around (orig-fn input kind arg display-action) lsp-bridge)
      (unless (lsp-bridge-xref--call kind arg display-action)
        (funcall orig-fn input kind arg display-action)))

    (define-advice xref--find-definitions (:around (orig-fn id display-action) lsp-bridge)
      (when (or lsp-bridge--xref-is-from-find-def
                (not (lsp-bridge-xref--call 'definitions id display-action)))
        (funcall orig-fn id display-action)))

    (define-advice query-replace-read-from (:around (orig-fn &rest args) lsp-bridge-xref)
      (if (and (eq this-command 'xref-find-references-and-replace)
               (eq (xref-find-backend) 'lsp-bridge))
          (xref-backend-identifier-at-point 'lsp-bridge)
        (apply orig-fn args)))

    (define-advice xref-find-references-and-replace (:around (orig-fn from to) lsp-bridge)
      (if (lsp-bridge-call-file-api-p)
          (lsp-bridge--rename to)
        (funcall orig-fn from to)))

    (define-advice xref-query-replace-in-results (:around (orig-fn from to) lsp-bridge)
      (if-let* ((_ (string= ".*" from))
                (item (save-excursion
                        (goto-char (point-min))
                        (xref--search-property 'xref-item)))
                (location (xref-item-location item))
                (_ (save-excursion
                     (xref--show-location location t)
                     (lsp-bridge-call-file-api-p))))
          (save-excursion
            (xref--show-location location t)
            (lsp-bridge--rename to))
        (funcall orig-fn from to))))
   (t
    (remove-hook 'xref-backend-functions #'lsp-bridge-xref-backend)
    (advice-remove 'xref--find-xrefs #'xref--find-xrefs@lsp-bridge)
    (advice-remove 'xref--find-definitions #'xref--find-definitions@lsp-bridge)
    (advice-remove 'query-replace-read-from #'query-replace-read-from@lsp-bridge-xref)
    (advice-remove 'xref-find-references-and-replace #'xref-find-references-and-replace@lsp-bridge)
    (advice-remove 'xref-query-replace-in-results #'xref-query-replace-in-results@lsp-bridge))))

(defun lsp-bridge-xref--find-def (kind id display-action)
  "Same as `xref-find-definitions' and co, but for other LSP textDocument methods.
KIND ID DISPLAY-ACTION"
  (unless (lsp-bridge-xref--call kind id display-action)
    (let ((lsp-bridge--xref-is-from-find-def t))
      (xref--find-definitions id display-action))))



;;;###autoload
(defun lsp-bridge-xref-find-declarations (identifier)
  "Find declarations of the IDENTIFIER using Xref.
See `xref-find-definitions'"
  (interactive (list (xref--read-identifier "Find declaration of: ")))
  (lsp-bridge-xref--find-def 'declarations identifier nil))

;;;###autoload
(defun lsp-bridge-xref-find-type-definitions (identifier)
  "Find type definitions of the IDENTIFIER using Xref.
See `xref-find-definitions'"
  (interactive (list (xref--read-identifier "Find type definition of: ")))
  (lsp-bridge-xref--find-def 'type_definitions identifier nil))

;;;###autoload
(defun lsp-bridge-xref-find-implementations (identifier)
  "Find implementations of the IDENTIFIER using Xref.
See `xref-find-definitions'"
  (interactive (list (xref--read-identifier "Find implementation of: ")))
  (lsp-bridge-xref--find-def 'implementations identifier nil))



;;;###autoload
(defun lsp-bridge-xref-find-declarations-other-window (identifier)
  "Like `lsp-bridge-xref-find-declarations' but open in other window."
  (interactive (list (xref--read-identifier "Find declaration of: ")))
  (lsp-bridge-xref--find-def 'declarations identifier nil))

;;;###autoload
(defun lsp-bridge-xref-find-type-definitions-other-window (identifier)
  "Like `lsp-bridge-xref-find-type-definitions' but open in other window."
  (interactive (list (xref--read-identifier "Find type definition of: ")))
  (lsp-bridge-xref--find-def 'type_definitions identifier nil))

;;;###autoload
(defun lsp-bridge-xref-find-implementations-other-window (identifier)
  "Like `lsp-bridge-xref-find-implementations' but open in other window."
  (interactive (list (xref--read-identifier "Find implementation of: ")))
  (lsp-bridge-xref--find-def 'implementations identifier nil))



;;;###autoload
(defun lsp-bridge-xref-find-declarations-other-frame (identifier)
  "Like `lsp-bridge-xref-find-declarations' but open in other frame."
  (interactive (list (xref--read-identifier "Find declaration of: ")))
  (lsp-bridge-xref--find-def 'declarations identifier nil))

;;;###autoload
(defun lsp-bridge-xref-find-type-definitions-other-frame (identifier)
  "Like `lsp-bridge-xref-find-type-definitions' but open in other frame."
  (interactive (list (xref--read-identifier "Find type definition of: ")))
  (lsp-bridge-xref--find-def 'type_definitions identifier nil))

;;;###autoload
(defun lsp-bridge-xref-find-implementations-other-frame (identifier)
  "Like `lsp-bridge-xref-find-implementations' but open in other frame."
  (interactive (list (xref--read-identifier "Find implementation of: ")))
  (lsp-bridge-xref--find-def 'implementations identifier nil))

(provide 'lsp-bridge-xref)
;;; lsp-bridge-xref.el ends here
