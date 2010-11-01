;; pdic.l
;;
;; 履歴
;; 03.05.18 メニューに関する不具合を修正
;; 03.05.17 初版


;; 使い方 .xyzzy に以下を追加
;;(load-library "pdic.l")


; PDICの場所
(defvar *pdic-path* "c:/Program Files/Personal Dictionary/pdicw32.exe")
; 単語帳バッファの名前
(defvar *pdic-wordbook* "*PDIC Wordbook*")
; ポップアップ表示をするか否か
(defvar *pdic-output-popup-p* t)

; 辞書を引く単語を取ってくる
(defun pdic-get-current-words-or-selection ()
  (if (pre-selection-p)
      (buffer-substring (selection-point) (selection-mark))
    (save-excursion
      (buffer-substring
       (progn
         (skip-chars-forward "A-Za-z")
         (skip-chars-backward "A-Za-z")
         (point))
       (progn
         (goto-eol)
         (point))))))

(defun pdic-get-current-words ()
  (save-excursion
    (buffer-substring
     (progn
       (skip-chars-forward "A-Za-z")
       (skip-chars-backward "A-Za-z")
       (point))
     (progn
       (goto-eol)
       (point)))))

; PDICとDDE通信でやりとり
(defun pdic-dde-comunicate (words)
  (setq chan (dde-initiate "PDICW" "Dictionary"))
  (when chan
    (dde-poke chan "Open" "")
    (dde-poke chan "PopupSearchConfig" "w2")
    (dde-poke chan "PopupSearch" words)
    (setq answer (dde-request chan "PopupSearch"))
    (if (string-equal answer "")
        (progn
          (dde-poke chan "Close" "")
              (dde-terminate chan)
          (popup-string "見つかりません。" (point))
          (return-from pdic-dde-comunicate nil)))
    (dde-poke chan "Format" "$w@@$j@@$x")
    (dde-poke chan "Config" "t3")
    (dde-poke chan "Find" answer)
    (setq answer (substitute-string (substitute-string (dde-request chan "Find")  "

" "") "@@" "\n"))
    (dde-poke chan "Close" "")
    (dde-terminate chan)
    (return-from pdic-dde-comunicate answer))
  (message "DDEセッションの初期化に失敗しました。")
  (return-from pdic-dde-comunicate nil))

; PDICで辞書を引く
(defun pdic-consult-dictionary ()
  (interactive)
  (continue-pre-selection)
  (setq words (pdic-get-current-words-or-selection))
  (setq answer (pdic-dde-comunicate words))
; エラーだったら何もせずにリターン
  (unless answer (return-from pdic-consult-dictionary nil))
; 結果表示
  (if *pdic-output-popup-p*
      (popup-string answer (point))
    (with-output-to-temp-buffer ("*PDIC output*")
      (format t "~A" answer))))

; PDICで辞書を引いて、単語帳に追加する
(defun pdic-add-words ()
  (interactive)
  (continue-pre-selection)
  (setq words (pdic-get-current-words-or-selection))
  (setq answer (pdic-dde-comunicate words))
; エラーだったら何もせずにリターン
  (unless answer (return-from pdic-add-words nil))
; 結果表示
  (if *pdic-output-popup-p*
      (popup-string answer (point))
    (with-output-to-temp-buffer ("*PDIC output*")
      (format t "~A" answer)))
; 単語帳に追加
  (setq buffer (get-buffer-create *pdic-wordbook*))
  (save-excursion
    (set-buffer buffer)
    (goto-char (point-max))
    (insert answer)))

; 辞書引きモード（PDIC版）
(defvar-local pdic-mode nil)
(defvar *pdic-mode-map*
  (let ((keymap (make-sparse-keymap)))
    (define-key keymap #\MouseMove 'pdic-mouse-lookup)
    (define-key keymap #\C-MouseMove 'pdic-mouse-lookup-conjugation)
    keymap))

(defvar *pdic-last-range-begin* nil)
(defvar *pdic-last-range-end* nil)

(defun pdic-mode (&optional (arg nil sv))
  (interactive "p")
  (ed::toggle-mode 'pdic-mode arg sv)
  (if pdic-mode
      (set-minor-mode-map *pdic-mode-map*)
    (unset-minor-mode-map *pdic-mode-map*))
  (setq *pdic-last-range-begin* nil)
  (update-mode-line t))

(defun pdic-mouse-lookup (&optional conjugation)
  (interactive)
  (continue-pre-selection)
  (when pdic-mode
    (with-selected-window
      (set-window *last-mouse-window*)
      (save-excursion
        (goto-last-mouse-point)
        (cond ((eolp)
               (setq *pdic-last-range-begin* nil)
               (return-from pdic-mouse-lookup nil))
              ((and *pdic-last-range-begin*
                    (<= *pdic-last-range-begin* (point))
                    (< (point) *pdic-last-range-end*))
               (continue-popup)
               (return-from pdic-mouse-lookup t))
              (t
               (save-excursion
                 (skip-chars-forward "A-Za-z") (setq *pdic-last-range-end*  (point))
                 (skip-chars-backward "A-Za-z") (setq *pdic-last-range-begin*  (point)))
               (setq answer (pdic-dde-comunicate (pdic-get-current-words)))
               (unless answer (return-from pdic-mouse-lookup nil))
               (popup-string answer (point))))))))

(pushnew '(pdic-mode . "Pdic") *minor-mode-alist* :key #'car)


;================================
; メニュー や キーバインドの設定
;================================
; ツールバーやポップアップメニューの辞書を引くコマンドの差し替え
; 位置(=21とか8)については、自分で調整してください。
; デフォルトのままであれば、「21(あるいは8)」で OK のはず。
(add-hook '*post-startup-hook*
          #'(lambda ()
              (let ((tools (get-menu *app-menu* 'ed::tools)))
; もともとの辞書を引くコマンドを消して
                (delete-menu tools 21 t)
                (delete-menu *app-popup-menu* 8 t)
; かわりに、PDIC で辞書を引くコマンドの追加
                (setq *dictionary-popup-menu*
                      (define-popup-menu
                        (:item nil "辞書引き(&E)"
                         'pdic-consult-dictionary)
                        (:item nil "辞書引き＋単語帳追加(&R)"
                         'pdic-add-words)
                        :sep
                        (:item nil "辞書引きモード(&J)"
                         'pdic-mode
                         #'(lambda () (if pdic-mode :check)))))
                (insert-popup-menu tools 21 *dictionary-popup-menu* "辞書(&I)")
                (insert-popup-menu *app-popup-menu* 8 *dictionary-popup-menu* " 辞書(&I)"))))
; キーバインドの設定
; 元の辞書引きコマンドを上書きします。
(define-key spec-map #\e 'pdic-consult-dictionary)
(define-key spec-map #\r 'pdic-add-words)
(define-key spec-map #\j 'pdic-mode)

