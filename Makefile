# ============================================================
# Makefile -- build the CV.
#   make                     build cv_master.pdf, then report its page count
#   make check MAX_PAGES=3   fail if the PDF is longer than 3 pages
#   make test                record-engine regression tests (after editing 97_entries.sty)
#   make clean               remove build artifacts (keeps the PDF)
#   make DOC=cv_short        build another main file (cv_short.tex)
# Needs pdfLaTeX and latexmk from TeX Live 2023 or newer (97_entries.sty uses
# recent expl3). latexmk runs pdfLaTeX as many times as "Page x of y" needs.
# ============================================================

DOC       ?= cv_master
MAX_PAGES ?=
LATEXMK   := latexmk -pdf -interaction=nonstopmode -halt-on-error

.PHONY: all pdf check test clean

all: pdf check

pdf:
	$(LATEXMK) $(DOC).tex

# Page count: pdfinfo when available, otherwise the "Output written on" log line.
check:
	@if [ ! -f $(DOC).pdf ]; then echo "MISSING  $(DOC).pdf (run make first)"; exit 1; fi; \
	n=$$(pdfinfo $(DOC).pdf 2>/dev/null | awk '/^Pages:/{print $$2}'); \
	[ -n "$$n" ] || n=$$(sed -n 's/^Output written on .*(\([0-9]*\) pages\{0,1\},.*/\1/p' $(DOC).log 2>/dev/null | tail -1); \
	max="$(MAX_PAGES)"; \
	if [ -z "$$n" ]; then echo "UNKNOWN  $(DOC).pdf: could not read page count"; exit 1; \
	elif [ -z "$$max" ]; then echo "ok       $(DOC).pdf: $$n page(s) (no limit)"; \
	elif [ $$n -gt $$max ]; then echo "OVERFLOW $(DOC).pdf: $$n page(s) (limit $$max)"; exit 1; \
	else echo "ok       $(DOC).pdf: $$n page(s) (limit $$max)"; fi

test:
	bash tests/engine_tests.sh

clean:
	@latexmk -c $(DOC).tex >/dev/null 2>&1; echo "cleaned"
