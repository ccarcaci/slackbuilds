MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Directories
DIST_DIR := $(MAKEFILE_DIR)dist

# Required by package: provide when calling make
PKG ?=

# Every directory holding a <name>/<name>.SlackBuild
PACKAGES := $(patsubst %/,%,$(dir $(wildcard $(MAKEFILE_DIR)*/*.SlackBuild)))
PACKAGES := $(notdir $(PACKAGES))

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
	@cd $(MAKEFILE_DIR)$(PKG) && . ./$(PKG).info && \
	for field in "$$DOWNLOAD|$$MD5SUM" "$$DOWNLOAD_x86_64|$$MD5SUM_x86_64"; do \
		urls=$${field%%|*}; sums=$${field##*|}; \
		[ -n "$$urls" ] && [ "$$urls" != UNSUPPORTED ] || continue; \
		set -- $$sums; \
		for url in $$urls; do \
			file=$${url##*/}; want=$$1; shift; \
			[ -f "$$file" ] || { curl -fsSL -o "$$file.part" "$$url" && mv "$$file.part" "$$file"; } \
				|| { rm -f "$$file.part"; echo "error: could not download $$url"; exit 1; }; \
			have=$$(md5sum "$$file" | cut -d' ' -f1); \
			[ "$$have" = "$$want" ] \
				|| { echo "error: MD5SUM mismatch for $(PKG)/$$file (expected '$$want', got $$have)"; exit 1; }; \
			echo "$$file: MD5SUM ok"; \
		done; \
	done

# slackbuilds.org accepts tar, tar.gz, tar.bz2 or tar.xz holding a directory named
# after the package with $PRGNAM.SlackBuild, $PRGNAM.info, slack-desc and README,
# and rejects uploads that include source code. Anything .info tells the
# downloader to fetch (sources, prebuilt binaries, upstream LICENSE) is excluded;
# everything else in the directory (doinst.sh, patches, config files) is kept.
# Only DOWNLOAD and DOWNLOAD_x86_64 are read, the two fields this repo uses.
.PHONY: package
package: download ## check the .info downloads, then build dist/<PKG>.tar.gz for slackbuilds.org submission. PKG=<name>
	@for f in $(PKG).SlackBuild $(PKG).info slack-desc README; do \
		[ -f "$(MAKEFILE_DIR)$(PKG)/$$f" ] || { echo "error: $(PKG)/$$f is required by the submission guidelines"; exit 1; }; \
	done
	@mkdir -p $(DIST_DIR)
	@excludes=$$( . $(MAKEFILE_DIR)$(PKG)/$(PKG).info; \
		for u in $$DOWNLOAD $$DOWNLOAD_x86_64; do \
			[ "$$u" = UNSUPPORTED ] || echo "--exclude=$(PKG)/$${u##*/}"; \
		done ); \
	tar $$excludes --owner=root --group=root \
		-czf $(DIST_DIR)/$(PKG).tar.gz -C $(MAKEFILE_DIR) $(PKG)
	@echo "created $(DIST_DIR)/$(PKG).tar.gz:"
	@tar -tzf $(DIST_DIR)/$(PKG).tar.gz | sed 's/^/  /'

.PHONY: package_all
package_all: ## build dist/<name>.tar.gz for every package in the repo
	@for p in $(PACKAGES); do \
		$(MAKE) --no-print-directory package PKG=$$p || exit 1; \
	done

##@ cleanup

.PHONY: clean
clean: ## remove dist/
	@rm -rf $(DIST_DIR)
	@echo "clean complete!"
