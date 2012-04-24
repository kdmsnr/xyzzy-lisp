;; review-inline
(defun review-inline()
  (interactive)
  (setq cmd (read-string "ReVIEW inline command: "))
  (insert (concat "@<" cmd ">{}"))
  (backward-char)
)
