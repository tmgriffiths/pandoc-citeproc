pandoc-citeproc
===============

This package provides a library and executable to facilitate the use of
citeproc with pandoc 1.12 and greater.  (Earlier versions of pandoc have
integrated citeproc support.)

`pandoc-citeproc`
-----------------

The `pandoc-citeproc` executable can be used as a filter with pandoc to
resolve and format citations using a bibliography file and a CSL
stylesheet.  It can also be used (with `--bib2yaml` or `--bib2json`
options) to convert a bibliography to a YAML format that can be put
directly into a pandoc markdown document or to CSL JSON.  Bibliographies
can be in any of several formats, but bibtex and biblatex are the best
supported.

For usage and further details, see the [pandoc-citeproc man
page](https://github.com/jgm/pandoc-citeproc/blob/master/man/pandoc-citeproc.1.md).

The current version of the package includes code from citeproc-hs,
which has not been updated for some time.  When citeproc-hs is brought
up to date, this code can be removed and this package will depend
on citeproc-hs.

`Text.CSL.Pandoc`
-----------------

Those who use pandoc as a library (e.g. in a web application) will
need to use this module to process citations.

The module exports two functions, `processCites`, which is pure and
accepts a style and a list of references as arguments, and
`processCites'`, which lives in the IO monad and derives the style
and references from the document's metadata.

My changes **TMG**
------------------

In `src/Text/CSL/Input/Bibtex.hs` added 

line 1488
````
subDate' <- getDates "submitted" <|> getOldDates mempty <|> return []
````

line 1569.

````
, submitted           = subDate'
````


Compiling
---------
Follow instructions for compiling [Pandoc from source](https://pandoc.org/installing.html#compiling-from-source). The stack method is reproduced here:

> Quick stack method
> 
> The easiest way to build pandoc from source is to use stack:
> 
> 1. Install stack. Note that Pandoc requires stack >= 1.7.0.
> 
> 2. Change to the pandoc source directory and issue the following commands:
> 
> ````
> stack setup
> stack install
> ````
> 
> `stack setup` will automatically download the ghc compiler if you don’t have it. `stack install` will install the `pandoc-citeproc` executable into `~/.local/bin`, which you should add to your `PATH`. This process will take a while, and will consume a considerable amount of disk space.

