(push '("\\.re$" . text-mode) *auto-mode-alist*)

(defun review-inline()
  (interactive)
  (setq input (read-string "ReVIEW inline command: "))
  (if (equal input "") (setq cmd "b") (setq cmd input))
  (insert (concat "@<" cmd ">{}"))
  (backward-char)
)
(global-set-key '(#\C-c #\l) 'review-inline)

(defun review-paragraph()
  (interactive)
  (setq input (read-string "ReVIEW paragraph command: "))
  (if (equal input "") (setq cmd "comment") (setq cmd input))
  (insert (concat "//" cmd "{\n\n//}"))
  (previous-line)
)
(global-set-key '(#\C-x #\l) 'review-paragraph)


(add-hook '*text-mode-hook*
  (lambda ()
    (make-local-variable 'regexp-keyword-list)
    (setq regexp-keyword-list
	  (compile-regexp-keyword-list '(("^\#@.*$" nil :comment))))))
