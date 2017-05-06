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
(use-package atom-tabs :config (global-atom-tabs-mode))
```
