;;; erdoc.el --- launcher for erlang html documentation

;; Copyright (C) 2009  Aliaksey Kandratsenka

;; Author: Aliaksey Kandratsenka <alk@tut.by>
;; Keywords: convenience, docs

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; 

;;; Code:
(require 'ffap)

(defvar *erdoc-errors-log* (expand-file-name "~/erdoc-errors.log"))
(defvar *erdoc-index-file* (expand-file-name "~/erdoc-index.lisp"))
(defvar *erdoc-keys-file* (expand-file-name "~/erdoc-keys"))
(defvar *erdoc-browse-url-function* 'w3m-browse-url)
(defvar *erdoc-index* nil)

(defun erdoc-grab-stdout (&rest call-process-args)
  (with-temp-buffer
    (unwind-protect (let ((status (apply #'call-process
                                         (car call-process-args)
                                         nil
                                         (list (current-buffer) *erdoc-errors-log*)
                                         nil
                                         (cdr call-process-args))))
                      (if (eql status 0)
                          (buffer-string)
                        (message "%s exited with status %d" (car call-process-args) status)
                        (save-excursion
                          (set-buffer "*Messages*")
                          (goto-char (point-max))
                          (insert-file-contents *erdoc-errors-log*))
                        nil))
      (delete-file *erdoc-errors-log*))))

(defun erdoc-read-index ()
  (or *erdoc-index*
      (setq *erdoc-index*
            (let* ((data-string (with-temp-buffer
                                  (insert-file-contents-literally *erdoc-index-file*)
                                  (buffer-string)))
                   (rv (mapcan #'(lambda (entry)
                                   (let ((module (cdr (assoc 'module entry)))
                                         (hash (cdr (assoc 'hash entry)))
                                         (path (cdr (assoc 'path entry))))
                                     (mapcar #'(lambda (cell)
                                                 (cons (concat module ":" (car cell))
                                                       (concat path "#" (cdr cell))))
                                             hash)))
                               (read data-string))))

              (with-temp-file *erdoc-keys-file*
                (dolist (cell rv)
                  (princ (car cell) (current-buffer))
                  (princ "\0" (current-buffer))))

              rv))))

(defun erdoc-doc ()
  (interactive)
  (erdoc-read-index)
  (let* ((key (erdoc-grab-stdout "/bin/sh" "-c"
                                 (concat "gpicker --dir-separator=: "
                                         "--init-filter=" (shell-quote-argument (ffap-string-at-point))
                                         " - < " *erdoc-keys-file*)))
         (cell (assoc key *erdoc-index*)))
    (when cell
      (let* ((bf *erdoc-browse-url-function*)
             (browse-url-browser-function (or (and bf
                                                   (indirect-function bf))
                                              browse-url-browser-function)))
        (when (and (listp browse-url-browser-function)
                   (eql (car browse-url-browser-function) 'autoload))
          (load (cadr browse-url-browser-function))
          (setq browse-url-browser-function (indirect-function bf)))
        (browse-url (concat "file://" (cdr cell)))))))

(provide 'erdoc)
;;; erdoc.el ends here
