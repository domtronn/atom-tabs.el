;;; atom-tabs.el --- A Package to display Atom Style tabs at the top of the window

;; Copyright (C) 2017  Dominic Charlesworth <dgc336@gmail.com>

;; Author: Dominic Charlesworth <dgc336@gmail.com>
;; Keywords: tools, convenience
;; Created: 28 Apr 2017

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:
;; (require 'all-the-icons)

;; Forward declarations of optional dependencies
(declare-function projectile-project-p "ext:projectile.el")
(declare-function projectile-project-buffers "ext:projectile.el")
(defvar recentf-list)

(defcustom atom-tabs--buffer-list:type :open-order
  "What buffer listing and sorting function to use."
  :group 'atom-tabs
  :type '(radio
          (const :tag "Open Order - Display buffers in the order they were opened" :open-order)
          (const :tag "Projectile - Display buffers in current projcet with `projectile-project-buffers'" :projectile)
          (const :tag "Recentf    - Display buffers recently used in `recentf-list'" :recentf)
          (const :tag "Mode       - Display buffers with the same `major-mode'" :major-mode)
          (const :tag "Custom     - Display buffers using `atom-tabs--custom-buffer-list-f'" :custom)))

(defvar atom-tabs--buffer-list:plist
  '(:open-order (atom-tabs--buffer-list/open-order . atom-tabs--can-show/open-order)
    :projectile (atom-tabs--buffer-list/projectile . atom-tabs--can-show/projectile)
    :recentf    (atom-tabs--buffer-list/recentf . atom-tabs--can-show/recentf)
    :major-mode (atom-tabs--buffer-list/major-mode . atom-tabs--can-show/major-mode)
    :custom     (atom-tabs--buffer-list/custom . atom-tabs--can-show/custom)))

(defvar atom-tabs--nav-tools:limit 10)
(defcustom atom-tabs--nav-tools:type 'never
  "Whether or not to show the navigation tools to rotate the list of buffers."
  :group 'atom-tabs
  :type '(radio
          (const :tag "never   - Never show the navigation tools" never)
          (const :tag "always  - Show naivgation tools all the time " always)
          (const :tag "limited - Show navigation tools when number of tabs is greater than `atom-tabs--nav-tool-display-limit' " limited)))

(defcustom atom-tabs--tab-numbers:type 'fixed
  "Whether the tab numbers should be fixed or relative.
When FIXED, a tab number will remain the same, even when the list is rotated.
when RELATIVE a tab number will change based on rotation through the list of tabs."
  :group 'atom-tabs
  :type '(radio
          (const 'fixed)
          (const 'relative)))

(defcustom atom-tabs--show:tab-numbers? nil
  "Whether or not to display tab numbers in tabs."
  :group 'atom-tabs
  :type 'boolean)

(defcustom atom-tabs--show:color-icons? t
  "Whether or not to display file icons in color."
  :group 'atom-tabs
  :type 'boolean)

(defcustom atom-tabs--show:file-icons? t
  "Whether or not to display file icons next to buffer names."
  :group 'atom-tabs
  :type 'boolean)

(defcustom atom-tabs--highlight "#63B2FF"
  "The color to use for various higlights in the theme."
  :group 'atom-tabs
  :type 'color)

(defvar atom-tabs--filter:blacklist
  '("^\\*" "^ \\*" "^COMMIT_EDITMSG$")
  "List of regexps to not show/add as a tab.")

(defvar atom-tabs--filter:whitelist
  '("^\\*scratch.*\\*$")
  "List of regexps to always show/add as a tab.")

(defvar atom-tabs--desired-tab-length 25
  "The approximate desired maximum length of a tab in characters.")

(defvar atom-tabs--buffer-list/custom nil "Custom function to display buffers.")

(defcustom atom-tabs-keymap-prefix (kbd "C-x t")
  "Atom tabs keymap prefix."
  :group 'atom-tabs
  :type 'key-sequence)

(defvar atom-tabs-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "l") 'atom-tabs-forward-tab)
    (define-key map (kbd "h") 'atom-tabs-backward-tab)
    (define-key map (kbd "1") 'atom-tabs-select-tab-1)
    (define-key map (kbd "2") 'atom-tabs-select-tab-2)
    (define-key map (kbd "3") 'atom-tabs-select-tab-3)
    (define-key map (kbd "4") 'atom-tabs-select-tab-4)
    (define-key map (kbd "5") 'atom-tabs-select-tab-5)
    (define-key map (kbd "6") 'atom-tabs-select-tab-6)
    (define-key map (kbd "7") 'atom-tabs-select-tab-7)
    (define-key map (kbd "8") 'atom-tabs-select-tab-8)
    (define-key map (kbd "9") 'atom-tabs-select-tab-9)
    (define-key map (kbd "0") 'atom-tabs-select-tab-10)
    map)
  "Keymap for Atom Tabs commands after `atom-tabs-keymap-prefix'.")
(fset 'atom-tabs-command-map atom-tabs-command-map)

(defvar atom-tabs-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map atom-tabs-keymap-prefix 'atom-tabs-command-map)
    map)
  "Keymap for Projectile mode.")

;; State variables
(defvar atom-tabs--recent-buffers '() "A list of recently accessed buffers in order of the time they were accessed.")

(defvar atom-tabs--rotate:global 0 "The number with which to rotate the list of buffers globally.")
(defvar-local atom-tabs--rotate:local 0 "The number with which to rotate the list of buffers locally.")
(defcustom atom-tabs--rotate:type 'local
  "Whether tab rotation should be affect globally or locally."
  :group 'atom-tabs
    :type '(radio
            (const 'local)
            (const 'global)) )

(defun atom-tabs--get-buffer-list ()
  "Common code to call to get the list of displayable buffers."
  (if (fboundp (car (plist-get atom-tabs--buffer-list:plist atom-tabs--buffer-list:type)))
       (funcall (car (plist-get atom-tabs--buffer-list:plist atom-tabs--buffer-list:type)))
     (buffer-list)))

(defun atom-tabs--buffer-list ()
  "Call `atom-tabs--buffer-list-f' to get list of buffers."
  (atom-tabs--rotate (atom-tabs--get-buffer-list)))

(defun atom-tabs--buffer-list-length ()
  "Get the length of the buffers being displayed."
  (length (atom-tabs--get-buffer-list)))

(defun atom-tabs--filter:match (buf filter-list)
  "Function to tell whether BUF match a regexp in FILTER-LIST."
  (cl-reduce (lambda (acc it) (or acc (string-match-p it buf))) filter-list :initial-value nil))

(defun atom-tabs--can-show:base (&optional buf)
  "Base predicate to tell that BUF can be shown."
  (let ((buf (or buf (buffer-name (current-buffer)))))
    (or
     (atom-tabs--filter:match buf atom-tabs--filter:whitelist)          ;; Either buffer is on whitelist
     (not (atom-tabs--filter:match buf atom-tabs--filter:blacklist))))) ;; or its not on the blacklist

(defun atom-tabs--can-show? ()
  "Call `atom-tabs--buffer-list-f' predicate to decide whether to show for `current-buffer'."
  (and (atom-tabs--can-show:base)
   (if (fboundp (cdr (plist-get atom-tabs--buffer-list:plist atom-tabs--buffer-list:type)))
       (funcall (cdr (plist-get atom-tabs--buffer-list:plist atom-tabs--buffer-list:type)))
     (buffer-file-name))))

(defun atom-tabs--foreground (&optional active?)
  "Return the foreground color based on whether buffer is ACTIVE?."
  (or (face-foreground (if active? 'default 'powerline-inactive1))
      (face-foreground 'default)))

(defun atom-tabs--background (&optional active?)
  "Return the foreground color based on whether buffer is ACTIVE?."
  (or (face-background (if active? 'default 'powerline-inactive1))
      (face-background 'default)))

(defun atom-tabs--rotate (list-var)
  "Rotate LIST-VAR by N."
  (cl-remove-if (lambda (it) (< (cl-position it list-var)
                           (if (eq atom-tabs--rotate:type 'local)
                               atom-tabs--rotate:local
                             atom-tabs--rotate:global))) list-var))

(defun atom-tabs--rotate/inc ()
  "Increase the rotation."
  (interactive)
  (cl-incf atom-tabs--rotate:local)
  (cl-incf atom-tabs--rotate:global)
  (force-window-update))

(defun atom-tabs--rotate/dec ()
  "Decrease the rotation."
  (interactive)
  (cl-decf atom-tabs--rotate:local)
  (cl-decf atom-tabs--rotate:global)
  (force-window-update))

(defun atom-tabs--rotate/min ()
  "Set rotation back to 0."
  (interactive)
  (setq atom-tabs--rotate:local 0)
  (setq atom-tabs--rotate:global 0)
  (force-window-update))

(defun atom-tabs--rotate/max ()
  "Rotate to the very end of the list.
N.B This only works in `atom-tabs--rotate:type' local mode."
  (interactive)
  (setq atom-tabs--rotate:local (- (atom-tabs--buffer-list-length) 4))
  (setq atom-tabs--rotate:global (- (atom-tabs--buffer-list-length) 4))
  (force-window-update))

(defun atom-tabs--nav-tools ()
  "Function to return the nav tools or nil."
  (when (cl-case atom-tabs--nav-tools:type
          (limited (> (atom-tabs--buffer-list-length) atom-tabs--nav-tools:limit))
          (never nil)
          (t t))
    (concat
     (atom-tabs-rotate-left-icon)
     (atom-tabs-rotate-right-icon))))

(defmacro define-atom-tabs-rotation-icon (name f alt-f icon limit)
  "Macro to define an icon for rotattion.
NAME is the name of the function and F is the function needed to
perform rotation.  ALT-F is the function for the meta modified
keypress.  ICON is the icon to display in the place.  LIMIT is the
rotation index to disable this button."
  `(defun ,(intern (format "atom-tabs-rotate-%s-icon" name)) ()
     ,(format "Rotate the list of buffers %s." name)
     (interactive)
     (let* ((icon-family (all-the-icons-icon-family ,icon))
            (limit (if (functionp ,limit) (funcall ,limit) ,limit))
            (@limit (eq (if (eq atom-tabs--rotate:type 'local) atom-tabs--rotate:local atom-tabs--rotate:global)
                        limit)))
       (propertize (format "  %s  " ,icon)
                   'face `(:family ,icon-family
                           :height 1.2
                           :foreground ,(if @limit (atom-tabs--background t) (atom-tabs--foreground))
                           :background ,(atom-tabs--background))
                   'mouse-face (when (not @limit) `((foreground-color . ,atom-tabs--highlight)))
                   'help-echo (when (not @limit) (format " mouse-1: Rotate list %s
M-mouse-1: Go to %s-most item in list" ,name ,name))
                   'local-map (let ((map (make-sparse-keymap)))
                                (define-key map [header-line down-mouse-1]
                                  `(lambda () (interactive) (select-window ,(get-buffer-window (current-buffer))) (,,f)))
                                (define-key map [header-line M-mouse-1]
                                  `(lambda () (interactive) (select-window ,(get-buffer-window (current-buffer))) (,,alt-f)))
                                (when (not @limit) map))))))

(define-atom-tabs-rotation-icon "left"
  'atom-tabs--rotate/dec
  'atom-tabs--rotate/min
  (all-the-icons-faicon "chevron-left" :v-adjust 0.2) 0)

(define-atom-tabs-rotation-icon "right"
  'atom-tabs--rotate/inc
  'atom-tabs--rotate/max
  (all-the-icons-faicon "chevron-right" :v-adjust 0.2) (lambda () (1- (atom-tabs--buffer-list-length))))

(defun atom-tabs-target-icon ()
  "Icon to target the current buffer if its not visible."
  (let* ((current-id (cl-position (current-buffer) (atom-tabs--get-buffer-list)))
         (visible? (<= (if (eq atom-tabs--rotate:type 'local) atom-tabs--rotate:local atom-tabs--rotate:global) current-id)))
    (concat
     (propertize " " 'face `(:background ,(atom-tabs--background)))
     (propertize
      (all-the-icons-material (if visible? "location_disabled" "location_searching") :v-adjust 0)
      'face `(:family ,(all-the-icons-material-family)
                      :height 1.4
                      :foreground ,(if visible? (atom-tabs--background t) (atom-tabs--foreground))
                      :background ,(atom-tabs--background))
      'help-echo (format "Rotate tab list to focus current buffer `%s'" (current-buffer))
      'mouse-face (when (not visible?) `((foreground-color . ,atom-tabs--highlight)))
      'local-map (let ((map (make-sparse-keymap)))
                   (define-key map [header-line down-mouse-1]
                     `(lambda () (interactive)
                        (select-window ,(get-buffer-window (current-buffer)))
                        (if (eq atom-tabs--rotate:type 'local)
                            (setq-local atom-tabs--rotate:local ,current-id)
                          (setq atom-tabs--rotate:global ,current-id))
                        (force-window-update)))
                   (when (not visible?) map)))
     (unless (atom-tabs--nav-tools) (propertize " " 'face `(:background ,(atom-tabs--background)))))))

(defun atom-tabs-add-icon ()
  "Icon to add a new buffer/tab."
  (concat
   (propertize (propertize " " 'face `(:background ,(atom-tabs--background t) :family "Arial Narrow" :height 2.5)))
   (propertize
    (concat
     (propertize " " 'face `(:background ,(atom-tabs--background)))
     (propertize (all-the-icons-material "add" :v-adjust 0)

                 'face `(:family ,(all-the-icons-material-family)
                                 :height 1.4
                                 :foreground ,(atom-tabs--background t)
                                 :background ,(atom-tabs--background)))
     (propertize " " 'face `(:background ,(atom-tabs--background))))
    'mouse-face `((foreground-color . ,atom-tabs--highlight))
    'local-map (let ((map (make-sparse-keymap)))
                 (define-key map [header-line down-mouse-1]
                   '(lambda () (interactive)
                      (run-with-timer 0.3 nil (lambda () (select-window (active-minibuffer-window)))) ;; Steal focus because
                      (call-interactively                                                        ;; calling interactively
                       (cond                                                                     ;; doesn't give focus
                        ((fboundp 'counsel-find-file) 'counsel-find-file)                        ;; to minibuffer
                        ((fboundp 'helm-find-file) 'helm-find-file)
                        ((fboundp 'ido-find-file) 'ido-find-file)                                ;; sad face :(
                        (t 'find-file)))))
                 map))))

(defun atom-tabs--close-icon (buffer)
  "Create a clickable close icon for BUFFER."
  (let ((active? (eq buffer (current-buffer))))
    (propertize
     (all-the-icons-faicon "times-circle" :v-adjust 0.4)
     'face `(:family ,(all-the-icons-faicon-family)
             :foreground ,(atom-tabs--foreground active?)
             :background ,(atom-tabs--background active?))
     'mouse-face `((foreground-color . ,atom-tabs--highlight))
     'local-map (let ((map (make-sparse-keymap)))
                  (define-key map
                    [header-line down-mouse-1]
                    `(lambda () (interactive) (kill-buffer ,buffer) (force-window-update)))
                  map))))

(defun atom-tabs--modified-icon (buffer)
  "Create a modified icon for BUFFER."
  (let ((active? (eq buffer (current-buffer))))
    (propertize
     (format "  %s  " (if (buffer-modified-p buffer)
                         (all-the-icons-faicon "circle" :v-adjust 1)
                         "   "))
     'face `(:foreground ,atom-tabs--highlight
             :family ,(all-the-icons-faicon-family)
             :height 0.5
             :background ,(atom-tabs--background active?)))))

(defun atom-tabs--num-icon (buffer)
  "Show the number of the current BUFFER tab.
This will only show when `atom-tabs--show:tab-numbers?' is non-nil"
  (when atom-tabs--show:tab-numbers?
    (let ((active? (eq buffer (current-buffer)))
          (pos (cl-position buffer (if (eq atom-tabs--tab-numbers:type 'fixed)
                                       (atom-tabs--get-buffer-list)
                                     (atom-tabs--buffer-list)))))
      (propertize (format "%c" (+ pos 9312))
                  'face `(:background ,(atom-tabs--background active?)
                          :foreground ,(atom-tabs--foreground active?)
                          :height 1.6)
                  'display '(raise 0.2)))))

(defun atom-tabs--name (buffer &optional tab-length)
  "Return the shortened name for BUFFER with its mode icon.
TAB-LENGTH is the desired length of a uniform tab."
  (let* ((active? (eq buffer (current-buffer)))
         (icon (all-the-icons-icon-for-file (buffer-name buffer) :v-adjust 0.3))
         (icon-face `(:height  ,(plist-get (get-text-property 0 'face icon) :height)
                      :family  ,(all-the-icons-icon-family-for-file (buffer-name buffer))
                      :foreground ,(or (when (and active? atom-tabs--show:color-icons?)
                                         (ignore-errors (face-foreground (plist-get (get-text-property 0 'face icon) :inherit))))
                                    (atom-tabs--foreground active?))
                      :background ,(atom-tabs--background active?)))
         (name (buffer-name buffer))
         (name (if (and (numberp tab-length)
                        (> (length name) tab-length))
                   (format "%s… " (substring name 0 (max (- tab-length 2) 1)))
                 name))
         (name (format " %s" name))
         (name-face `(:height 0.9
                      :weight extralight
                      :foreground ,(atom-tabs--foreground active?)
                      :background ,(atom-tabs--background active?))))
    (concat
     (when atom-tabs--show:file-icons? (propertize icon 'face icon-face))
     (propertize name 'face name-face 'display '(raise 0.4)))))

(defun atom-tabs--create-tab (buffer &optional tab-length)
  "Create the string representation of tab for BUFFER.
TAB-LENGTH is the desired length of a uniform tab."
  (let* ((tab-name   (buffer-name buffer))
         (tab-name-l (length tab-name))
         (pad-length (if (and (numberp tab-length)
                              (< tab-name-l tab-length))
                         (max (/ (- tab-length tab-name-l ) 2) 2) 2))

         (active? (eq buffer (current-buffer)))

         (padding-face `(:background ,(if active? (face-background 'default) (face-background 'powerline-inactive1))))
         (left-padding  (propertize (cl-reduce 'concat (make-list (max (- pad-length (if atom-tabs--show:tab-numbers? 3 0)) 2) " ")) 'face padding-face))
         (right-padding (propertize (cl-reduce 'concat (make-list (max (- pad-length 2) 0) " ")) 'face padding-face))
         (main-padding (propertize " " 'face padding-face))

         (separator (propertize " " 'face `(:background ,(if active? atom-tabs--highlight (face-background 'default)) :height  2.5 :family "Arial Narrow"))))

    (concat
     separator
     (propertize
      (concat main-padding
              (atom-tabs--num-icon buffer)
              left-padding
              (atom-tabs--name buffer tab-length)
              right-padding
              (atom-tabs--modified-icon buffer))
      'help-echo  (when (string-match-p "… $" (atom-tabs--name buffer tab-length)) (buffer-name buffer))
      'mouse-face (unless(eq buffer (current-buffer)) `(:foreground ,atom-tabs--highlight :inherit))
      'local-map (let ((map (make-sparse-keymap)))
                   (define-key map
                     [header-line down-mouse-1]
                     `(lambda () (interactive) (switch-to-buffer ,buffer)))
                   map))
     (atom-tabs--close-icon buffer)
     main-padding)))

;; Buffer filter functions

(defun atom-tabs--buffer-list/projectile ()
  "Function to return the list of buffers in projectile."
  (cl-reduce
   (lambda (acc it) (if (buffer-file-name it) (append acc `(,it)) acc))
   (sort (projectile-project-buffers) (lambda (a b) (string< (buffer-name a) (buffer-name b))))
   :initial-value '()))

(defun atom-tabs--buffer-list/recentf ()
  "Function to return the list of buffers in projectile."
  (cl-reduce
   (lambda (acc it)
     (let* ((buf (get-buffer (file-name-nondirectory it)))
            (mem (memq buf acc)))
        (if (and buf (not mem)) (append acc `(,buf)) acc)))
    recentf-list
    :initial-value '()))

(defun atom-tabs--add-recent (&rest args)
  "Advice to add `current-buffer' on `find-file' to `atom-tabs--recent-buffers'.
ARGS is placeholder for when used as advice."
  (when (and (not (memq (current-buffer) atom-tabs--recent-buffers))
             (atom-tabs--can-show:base))
    (setq atom-tabs--recent-buffers (append atom-tabs--recent-buffers `(,(current-buffer))))))

(defun atom-tabs--kill-recent (&rest args)
  "Function to remove dead buffers from `atom-tabs--recent-buffers'.
ARGS is a placeholder for when used as advice."
  (setq atom-tabs--recent-buffers
        (cl-remove-if-not 'buffer-live-p  atom-tabs--recent-buffers)))

(defun atom-tabs--can-show/open-order ()
  "Predicate to decided whether to show tabs for `open-order'."
  (memq (current-buffer) atom-tabs--recent-buffers))

(defun atom-tabs--buffer-list/open-order ()
  "Function to return list of buffers in the order they were opened."
  atom-tabs--recent-buffers)

(defun atom-tabs--buffer-list/major-mode ()
  "Function to return the list of buffers with same major mode."
  (let ((mm major-mode))
    (cl-reduce
     (lambda (acc it) (if (and (buffer-file-name it)
                          (with-current-buffer it (eq mm major-mode)))
                     (append acc `(,it)) acc))
     (sort (buffer-list) (lambda (a b) (string< (buffer-name a) (buffer-name b))))
     :initial-value '())))

;; Navigation
(defun atom-tabs--select-tab (i)
  "Select tab I from the current list of tabs."
  (let ((buf (nth (1- i) (atom-tabs--buffer-list))))
    (when buf (switch-to-buffer buf))))

(defmacro define-atom-tabs-navigation (name f)
  "Macro to define a tab navigation function.
NAME is the direction and F is the function needed to choose next index."
  `(defun ,(intern (format "atom-tabs-%s-tab" name)) ()
     ,(format "Navigate %s in the list of tabs." name)
     (interactive)
     (let* ((buffers (atom-tabs--buffer-list))
            (next-buffer-id (mod (funcall ,f (cl-position (current-buffer) buffers)) (length buffers)))
            (next-buffer (nth next-buffer-id buffers)))
       (switch-to-buffer next-buffer))))

(define-atom-tabs-navigation "forward" '1+)
(define-atom-tabs-navigation "backward" '1-)

(defmacro define-atom-tabs-select (i)
  "Macro to define an integer based tab selection function.
I is the index of the tab to select."
  `(defun ,(intern (format "atom-tabs-select-tab-%s" i)) ()
     ,(format "Select the %sth tab if visible." i)
     (interactive)
     (switch-to-buffer (nth (1- ,i)
                            (if (eq atom-tabs--tab-numbers:type 'fixed)
                                (atom-tabs--get-buffer-list)
                              (atom-tabs--buffer-list))))))

(define-atom-tabs-select 1)
(define-atom-tabs-select 2)
(define-atom-tabs-select 3)
(define-atom-tabs-select 4)
(define-atom-tabs-select 5)
(define-atom-tabs-select 6)
(define-atom-tabs-select 7)
(define-atom-tabs-select 8)
(define-atom-tabs-select 9)
(define-atom-tabs-select 10)

;; Main Theme
(defun atom-tabs--theme ()
  "Method to return the eval list to set as `header-line-format'."
  '("%e" (:eval
          (if (atom-tabs--can-show?)
             (let ((buffers (atom-tabs--buffer-list)))
               (concat
                (atom-tabs-target-icon)
                (atom-tabs--nav-tools)
                (cl-reduce
                 (lambda (acc it)
                    (format "%s%s" (or acc "")
                            (atom-tabs--create-tab it
                             (min atom-tabs--desired-tab-length
                                  (- (/ (window-text-width) (atom-tabs--buffer-list-length)) 6) ))))
                 buffers
                 :initial-value '())
                (atom-tabs-add-icon)))
            (setq-local header-line-format nil)
            (force-window-update)))))

;;;###autoload
(defun atom-tabs-theme ()
  "Set the `header-line-format' to be the tabs theme."
  (interactive)
  (when (eq atom-tabs--buffer-list:type :open-order)
    (atom-tabs--add-recent))
  (advice-add 'find-file :after 'atom-tabs--add-recent)
  (advice-add 'switch-to-buffer :after 'atom-tabs--add-recent)
  (advice-add 'kill-buffer :after 'atom-tabs--kill-recent)
  (setq-default header-line-format (atom-tabs--theme)))

;;;###autoload
(define-minor-mode atom-tabs-minor-mode
  "Minor mode to help with js dependency injection.

When called interactively, toggle `atom-tabs-minor-mode'.  With prefix
ARG, enable `atom-tabs-minor-mode' if ARG is positive, otherwise disable
it.

\\{-mode-map}"
  :keymap atom-tabs-mode-map
  :group 'atom-tabs
  :require 'atom-tabs)

(define-global-minor-mode global-atom-tabs-minor-mode atom-tabs-minor-mode atom-tabs-minor-mode)

(provide 'atom-tabs)
;;; atom-tabs.el ends here
