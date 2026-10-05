MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Directories
DIST_DIR := $(MAKEFILE_DIR)dist

# Required by package: provide when calling make
PKG ?=

# Every directory holding a <name>/<name>.SlackBuild
PACKAGES := $(patsubst %/,%,$(dir $(wildcard $(MAKEFILE_DIR)*/*.SlackBuild)))
PACKAGES := $(notdir $(PACKAGES))

# Recipes run inside Slackware 15.0 containers with the repo mounted on /mnt, so
# paths inside the quoted scripts below are relative to /mnt. Every package is
# x86_64-only, hence the pinned platform (emulated on arm64 hosts).
SLACKWARE_IMAGE ?= aclemons/slackware:15.0
SBO_TOOLS_IMAGE ?= aclemons/sbo-maintainer-tools:latest
DOCKER_RUN := docker run --rm --platform linux/amd64 --volume "$(MAKEFILE_DIR):/mnt" --workdir /mnt

# The slackware image ships without ca-certificates, so wget cannot verify https:
# lend it the host's CA bundle (macOS, Debian, Fedora paths). Override if elsewhere.
CA_BUNDLE ?= $(firstword $(wildcard /etc/ssl/cert.pem /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt))

##@ slackbuilds - personal SlackBuilds for Slackware 15.0
##@ usage: make [target] PKG=<package dir name>

.DEFAULT_GOAL := help

.PHONY: help
help: ## show this help message
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ submission

.PHONY: _check_pkg
_check_pkg:
	@[ -n "$(PKG)" ] || { echo "error: PKG is required  (e.g. make package PKG=age; available: $(PACKAGES))"; exit 1; }
	@[ -f "$(MAKEFILE_DIR)$(PKG)/$(PKG).SlackBuild" ] || { echo "error: $(PKG)/$(PKG).SlackBuild not found  (available: $(PACKAGES))"; exit 1; }

# Fetches what <PKG>.info lists in DOWNLOAD / DOWNLOAD_x86_64 (the two fields this
# repo uses) into <PKG>/, where the SlackBuild expects it ($CWD), and checks each
# file against the matching MD5SUM / MD5SUM_x86_64 entry, paired by position.
# Files already present are not fetched again, only checked. A mismatch keeps the
# file for inspection: delete it to fetch it again.
.PHONY: download
download: _check_pkg ## download the files listed in <PKG>.info and check their MD5SUM. PKG=<name>
	@[ -n "$(CA_BUNDLE)" ] || { echo "error: no host CA bundle found, set CA_BUNDLE=<path to PEM bundle>"; exit 1; }
	@$(DOCKER_RUN) --volume "$(CA_BUNDLE):/etc/ssl/cert.pem:ro" $(SLACKWARE_IMAGE) bash -c ' \
		cd $(PKG) && . ./$(PKG).info && \
		for field in "$$DOWNLOAD|$$MD5SUM" "$$DOWNLOAD_x86_64|$$MD5SUM_x86_64"; do \
			urls=$${field%%|*}; sums=$${field##*|}; \
			[ -n "$$urls" ] && [ "$$urls" != UNSUPPORTED ] || continue; \
			set -- $$sums; \
			for url in $$urls; do \
				file=$${url##*/}; want=$$1; shift; \
				[ -f "$$file" ] || { wget --quiet --output-document="$$file.part" "$$url" && mv "$$file.part" "$$file"; } \
					|| { rm --force "$$file.part"; echo "error: could not download $$url"; exit 1; }; \
				have=$$(md5sum "$$file" | cut --delimiter=" " --fields=1); \
				[ "$$have" = "$$want" ] \
					|| { echo "error: MD5SUM mismatch for $(PKG)/$$file (expected $$want, got $$have)"; exit 1; }; \
				echo "$$file: MD5SUM ok"; \
			done; \
		done'

# slackbuilds.org accepts tar, tar.gz, tar.bz2 or tar.xz holding a directory named
# after the package with $PRGNAM.SlackBuild, $PRGNAM.info, slack-desc and README,
# and rejects uploads that include source code. Anything .info tells the
# downloader to fetch (sources, prebuilt binaries, upstream LICENSE) is excluded;
# everything else in the directory (doinst.sh, patches, config files) is kept.
# Only DOWNLOAD and DOWNLOAD_x86_64 are read, the two fields this repo uses.
.PHONY: package
package: download ## check the .info downloads, then build dist/<PKG>.tar.gz for slackbuilds.org submission. PKG=<name>
	@$(DOCKER_RUN) $(SLACKWARE_IMAGE) bash -c ' \
		for f in $(PKG).SlackBuild $(PKG).info slack-desc README; do \
			[ -f "$(PKG)/$$f" ] || { echo "error: $(PKG)/$$f is required by the submission guidelines"; exit 1; }; \
		done; \
		mkdir --parents dist && \
		excludes=$$( . $(PKG)/$(PKG).info; \
			for u in $$DOWNLOAD $$DOWNLOAD_x86_64; do \
				[ "$$u" = UNSUPPORTED ] || echo "--exclude=$(PKG)/$${u##*/}"; \
			done ) && \
		tar $$excludes --owner=root --group=root --create --gzip --file=dist/$(PKG).tar.gz $(PKG) && \
		echo "created dist/$(PKG).tar.gz:" && \
		tar --list --gzip --file=dist/$(PKG).tar.gz | sed "s/^/  /"'

.PHONY: package_all
package_all: ## build dist/<name>.tar.gz for every package in the repo
	@for p in $(PACKAGES); do \
		$(MAKE) --no-print-directory package PKG=$$p || exit 1; \
	done

##@ lint

# Runs the SlackBuild into dist/ in the sbo-maintainer-tools image rather than the
# slackware one: same Slackware 15.0, but it carries binutils, and without strip
# the binaries ship unstripped.
.PHONY: build
build: download ## run <PKG>.SlackBuild, writing the Slackware package to dist/. PKG=<name>
	@$(DOCKER_RUN) $(SBO_TOOLS_IMAGE) bash -c 'OUTPUT=/mnt/dist bash $(PKG)/$(PKG).SlackBuild'

# sbolint checks the submission tarball, exactly what gets uploaded; sbopkglint
# installs the built package into a scratch root and checks its contents.
.PHONY: lint
lint: package build ## run sbolint on dist/<PKG>.tar.gz and sbopkglint on the built package. PKG=<name>
	@$(DOCKER_RUN) $(SBO_TOOLS_IMAGE) bash -c ' \
		sbolint dist/$(PKG).tar.gz; lint=$$?; \
		sbopkglint dist/$$(PRINT_PACKAGE_NAME=1 bash $(PKG)/$(PKG).SlackBuild) && exit $$lint'

# Smoke test in a throwaway slackware container: build, installpkg, then run RUN.
# This image has no strip, so the binaries stay unstripped: fine for a smoke test,
# use `make lint` to check the package as SBo would build it.
RUN ?= $(PKG) --version

.PHONY: try
try: download ## build, install and run <PKG> in a fresh slackware container. PKG=<name> [RUN="<command>"]
	@$(DOCKER_RUN) $(SLACKWARE_IMAGE) bash -c ' \
		set -o errexit; \
		OUTPUT=/tmp bash $(PKG)/$(PKG).SlackBuild; \
		installpkg /tmp/$$(PRINT_PACKAGE_NAME=1 bash $(PKG)/$(PKG).SlackBuild); \
		echo "+ $(RUN)"; \
		$(RUN)'

.PHONY: lint_all
lint_all: ## run lint for every package in the repo
	@for p in $(PACKAGES); do \
		$(MAKE) --no-print-directory lint PKG=$$p || exit 1; \
	done

##@ cleanup

.PHONY: clean
# Downloaded files are named after the DOWNLOAD / DOWNLOAD_x86_64 URLs in each
# .info, so only those (and leftover .part files) go: tracked files stay. Each
# .info is sourced in a subshell so one package's fields can't leak into the next.
clean: ## remove dist/ and the files `download` fetched into each package directory
	@rm -rfv $(DIST_DIR)
	@for p in $(PACKAGES); do \
		( . $(MAKEFILE_DIR)$$p/$$p.info; \
		for u in $$DOWNLOAD $$DOWNLOAD_x86_64; do \
			[ "$$u" = UNSUPPORTED ] || rm -fv "$(MAKEFILE_DIR)$$p/$${u##*/}" "$(MAKEFILE_DIR)$$p/$${u##*/}.part"; \
		done ); \
	done
	@echo "clean complete!"
