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
;;
;;; Code:

(require 'lsp-bridge)
(require 'xref)

;;;###autoload
(defun lsp-bridge-xref-find-references ()
  "Find reference of thing at point."
  (interactive)
  (if (lsp-bridge-has-lsp-server-p)
      (lsp-bridge-call-file-api "xref_find_references" (lsp-bridge--position))
    (call-interactively #'xref-find-references)))

(defun lsp-bridge-xref--callback (response)
  "RESPONSE callback from backend."
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
   nil))

(provide 'lsp-bridge-xref)
;;; lsp-bridge-xref.el ends here
