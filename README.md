## Installation

You should be able to install this package in the standard way, add it
to the load path and then calling

```el
(package-install 'atom-tabs)

(require 'atom-tabs)
;; or
(use-package atom-tabs)
```

*N.B.* This package is *_highly_* dependent
on [`all-the-icons.el`](https://github.com/domtronn/all-the-icons.el), so make
sure you have the [fonts](https://github.com/domtronn/all-the-icons.el/tree/master/fonts)
installed correctly

## Usage

This package uses the `header-line-format` variable to display tabs,
similar to `mode-line-format` for the mode line or powerline.

You can enable this by calling

```el
;; Locally
(atom-tabs-theme)
(atom-tabs-mode)

;; Globally
(global-atom-tabs-mode)
```

For example, using this with `use-package`, you would have something
like this

```el
(use-package atom-tabs :demand t
  :config (global-atom-tabs-mode)
  :bind (:map atom-tabs-mode-map
         ("<M-right>"   . atom-tabs-forward-tab)
         ("<M-left>"    . atom-tabs-backward-tab)
         ("<M-S-right>" . atom-tabs--rotate/dec)
         ("<M-S-left>"  . atom-tabs--rotate/inc)

         ;; Window selection using Ctrl + Shift
         ("C-!" . atom-tabs-select-tab-1)
         ("C-@" . atom-tabs-select-tab-2)
         ("C-£" . atom-tabs-select-tab-3)
         ("C-$" . atom-tabs-select-tab-4)
         ("C-%" . atom-tabs-select-tab-5)
         ("C-^" . atom-tabs-select-tab-6)
         ("C-&" . atom-tabs-select-tab-7)
         ("C-*" . atom-tabs-select-tab-8)
         ("C-(" . atom-tabs-select-tab-9)))
```

## Customization

There are two different ways to customise this package,

+ Visual
+ Behaviour

### Visual

#### **Tab Numbers** `atom-tabs-show--tab-numbers?` & `atom-tabs--tab-numbers:type`

Setting `atom-tabs--tab-numbers:type` to these values has the
following effects

| Value |  Effect |
|:-|:-|
| `fixed`    | Numbers are fixed for each buffer |
| `relative` | Numbers are relative to visible position, _i.e. **First** tab is always **#1**_ |

#### **File Icons** `atom-tabs-show--file-icons?`

When set to `non-nil` will display the files icon next to it, for
example, a JavaScript file next to the file name.

#### **Color Icons** `atom-tabs-show--color-icons?`

When set to `non-nil` will display buffer mode icons in color when
that buffer is focussed.

#### **Nav Tools** `atom-tabs-show--nav-tools?`

Setting `atom-tabs-show--nav-tools?` to these values has the following effects

| Value |  Effect |
|:-|:-|
| `'never`   | _Never_ show the nav tools |
| `'always`  | _Always_ show the nav tools |
| `'limited` | show nav tools _#tabs_ greater than `atom-tabs--nav-tools:limit` |

#### **Mouse Highlight** `atom-tabs--highlight`

This is a hex value that is used whenever your highlight sections of a
tab with your mouse, for example, the close icon. Defaults to
`#63B2FF`

#### **Tab Length** `atom-tabs--desired-tab-length`

This value is the width, in characters, each tab should be
_(roughly)_. This package tries its best to make each tab uniform in
width.

**Increasing** this will make tabs wider by default, **decreasing**
this will make tabs narrowers. Tabs will still become narrower with
split windows.


### Behavioural

## Listing

You can customise how **Atom Tabs** gets its list of buffers to
display as tabs, by default, it uses **Open Order** _i.e._ the order
which you open files in.

All options can be seen by customizing `atom-tabs--buffer-list:type`,
these are a couple of other options.

| Value | Behaviour |
|:-|:-|
| `:open-order` | The order which you openeded buffers/files in |
| `:projectile` | The list of buffers for the current **Projectile** project |
| `:recentf` | Most recently accessed buffers with `recentf` |
| `:major-mode` | All other buffers with the same major mode |
| `:custom` | Custom rules as defined by `atom-tabs--custom-buffer-list-f` |

Each listing behaviour is made up of a `buffer-list` & `can-show`
function, _e.g._

```el
atom-tabs--buffer-list/projectile
atom-tabs--can-show/projectile
```

The `buffer-list` function lists the buffers for that option, the
`can-show` function is a predicate function to decide whether to show
atom tabs for your current buffer.

This is so that buffers like `*term*`, `*compilation*`, `*Messages*`,
`GIT_COMMIT_EDITMSG` _etc_ don't get tabs.

#### Blacklist & Whitelist

However, **Atom Tabs** comes with a `atom-tabs--filter:blacklist` and
`atom-tabs--filter:whitelist` variable to never or always show tabs in
that buffer respectively.

These are lists of regexps to match against the file name.

#### Custom Listing

Setting `atom-tasb--buffer-list:type` to `:custom` will allow you to
define your own custom function and `can-show` predicate. You can set
these as

+ `atom-tabs--buffer-list/custom`
+ `atom-tabs--can-show/custom`

For example,

```
(defun my-buffer-list () (-filter 'file-exists-p (buffer-list)))

(setq atom-tabs--buffer-list/custom 'my-buffer-list')
```

## Rotation

When there a lot of tabs to display, its not always possible to fit
them in the header. To get around this, you can _rotate_ the list of
buffers using the **Nav Tools**.

However, there are two ways of handling rotation,

+ `local`
+ `global`

Imagine the following example where each letter is a buffer, and the
brackets `[]` denote the visible buffers and the parantheses `()`
denote the current buffer

```
 [ A B (C) D E ] F G H
```

#### `local`

This means that if you rotated the list of buffers to the right
following by  switching to another buffer, say `A`, it'll restore `A`s rotation, _e.g._

```js
 [ A B (C) D E ] F G H       ;; Start in buffer C
 A [ B (C) D E F ] G H       ;; Rotate right one
 [ (A) B C D E ] F G H       ;; Switch to buffer A

 ;; A is visible in the list
```

#### `global`

This means that if you rotated the list of buffers to the right
following by switching to another buffer, say `A`, it'll keep the same
rotation, _e.g._

```js
 [ A B (C) D E ] F G H       ;; Start in buffer C
 A [ B (C) D E F ] G H       ;; Rotate right one
 (A) [ B C D E F ] G H       ;; Switch to buffer A

 ;; A is not visible in the list
```

Both have advantages and disadvantages, so its best to pick the style
that suits you.
