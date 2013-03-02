;; review-inline

(push '("\\.re$" . text-mode) *auto-mode-alist*)

(defun review-inline()
  (interactive)
  (setq cmd (read-string "ReVIEW inline command: "))
  (insert (concat "@<" cmd ">{}"))
  (backward-char)
)
(global-set-key '(#\C-c #\l) 'review-inline)

(add-hook '*text-mode-hook*
  (lambda ()
    (make-local-variable 'regexp-keyword-list)
    (setq regexp-keyword-list
	  (compile-regexp-keyword-list '(("^\#@.*$" nil :comment))))))
