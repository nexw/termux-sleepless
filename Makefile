SHELL := $(shell command -v bash 2>/dev/null || echo /bin/sh)

NAME := termux-keepalive
VERSION := $(shell sed -n "s/^VERSION='\([^']*\)'$$/\1/p" bin/$(NAME))
DIST_DIR := dist
TARBALL := $(DIST_DIR)/$(NAME)-$(VERSION).tar.gz
SOURCES := \
	bin/$(NAME) \
	install.sh \
	tests/run-tests.sh \
	docs/installation.md \
	docs/how-it-works.md \
	docs/troubleshooting.md \
	README.md \
	README.zh-CN.md \
	LICENSE \
	CHANGELOG.md

.PHONY: all check lint test dist install uninstall clean

all: check

lint:
	shellcheck -x bin/$(NAME) install.sh tests/run-tests.sh
	shfmt -d -i 4 -ci bin/$(NAME) install.sh tests/run-tests.sh

test:
	bash tests/run-tests.sh

check: lint test

dist: $(TARBALL)

$(TARBALL): $(SOURCES)
	@test -n "$(VERSION)" || { echo 'error: VERSION not found in bin/$(NAME)' >&2; exit 1; }
	mkdir -p $(DIST_DIR)
	tar --create --gzip --file $@ \
		--sort=name --owner=0 --group=0 --numeric-owner \
		--transform 's,^,$(NAME)-$(VERSION)/,' \
		bin install.sh tests docs README.md README.zh-CN.md LICENSE CHANGELOG.md
	cd $(DIST_DIR) && sha256sum $(NAME)-$(VERSION).tar.gz > $(NAME)-$(VERSION).tar.gz.sha256

install:
	bash install.sh

uninstall:
	bash install.sh --uninstall

clean:
	rm -rf $(DIST_DIR)
