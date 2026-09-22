# Yomidori — command-line build/run/test, so you never have to open Xcode.
#
# The Scripts/*.sh do the actual work (one job each); this Makefile wires up the
# dependencies (e.g. the Xcode project is regenerated only when project.yml or
# an Info.plist changes) and gives short targets. Run `make` (or `make help`)
# to list them.

.DEFAULT_GOAL := help

.PHONY: help
help:  ## List the available commands
	@echo "Yomidori — available make targets:"
	@awk 'BEGIN {FS = ":.*## "} \
		/^##@ / {printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next} \
		/^##~ / {printf "  \033[2m%s\033[0m\n", substr($$0, 5); next} \
		/^[a-zA-Z0-9_-]+:.*## / {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ Dev — build, run, test

# Inputs xcodegen reads — regenerate the project when any of these change.
PROJECT_INPUTS := project.yml \
	$(wildcard Sources/Shared/Models/*) \
	$(wildcard Sources/*/Info.plist) \
	$(wildcard Sources/*/*.entitlements) \
	$(wildcard Sources/*/*.xcstrings)

# The bundled dictionary is built from JMdict, not committed (50 MB); the project
# must exist on disk before XcodeGen runs, or the app is generated without it.
DICTIONARY := Sources/Shared/Dictionaries/jmdict.sqlite

$(DICTIONARY): Scripts/data/build-jmdict.py
	@Scripts/data/build-jmdict.py --output $(DICTIONARY)

.PHONY: dictionary
dictionary: $(DICTIONARY)  ## Build the bundled JMdict database (downloads JMdict_e once into .build-data/)

# The manga-ocr models, converted to Core ML into the app target and not committed
# (~210 MB). Optional: the app hides the engine when they are absent, so CI and a
# fresh clone build without them. Needs Homebrew's python@3.13; the venv is local.
MODELS := Sources/Shared/Models/MangaOCREncoder.mlpackage
OCR_VENV := .build-data/ocr-venv
# A stamp, not the venv's python: that is a symlink to Homebrew's binary, whose mtime
# make would compare, and which is older than the requirements, so every build would
# recreate the venv and reconvert the models.
OCR_VENV_READY := $(OCR_VENV)/.ready

$(OCR_VENV_READY): Scripts/data/mangaocr-requirements.txt
	@python3.13 -m venv $(OCR_VENV) && $(OCR_VENV)/bin/pip install -q --upgrade pip \
		&& $(OCR_VENV)/bin/pip install -q -r Scripts/data/mangaocr-requirements.txt \
		&& touch $@

$(MODELS): Scripts/data/build-mangaocr.py $(OCR_VENV_READY)
	@$(OCR_VENV)/bin/python Scripts/data/build-mangaocr.py --output Sources/Shared/Models

.PHONY: models
models: $(MODELS)  ## Convert manga-ocr to Core ML into the app (python3.13 + a local venv; ~210 MB; optional)

.PHONY: clean-models
clean-models:  ## Remove the converted models and nothing else (the reverse of make models)
	@rm -rf Sources/Shared/Models
	@echo "removed Sources/Shared/Models; the next make models rebuilds them (the venv in .build-data stays)"

# File target: the generated project depends on its inputs, so `make` skips the
# regen when nothing changed (and reruns it when project.yml etc. are edited).
Yomidori.xcodeproj: $(PROJECT_INPUTS) $(DICTIONARY)
	@Scripts/generate.sh

.PHONY: generate
generate: Yomidori.xcodeproj  ## Regenerate Yomidori.xcodeproj from project.yml (if stale)

.PHONY: run-iphone
run-iphone: Yomidori.xcodeproj  ## Build + launch on an iPhone simulator (DEVICE="SE" / "17 Pro" to pick)
	@Scripts/run-ios.sh iphone "$(DEVICE)"

.PHONY: run-ipad
run-ipad: Yomidori.xcodeproj  ## Build + launch on an iPad simulator (DEVICE="Air" / "13-inch" to pick)
	@Scripts/run-ios.sh ipad "$(DEVICE)"

.PHONY: run-device
run-device: Yomidori.xcodeproj  ## Build + install + launch on a paired iPhone/iPad (DEVICE="<name>" to pick)
	@Scripts/run-device.sh "$(DEVICE)"

# The demo launchers install the last simulator build and start it with -yomidori-demo:
# stores in a wiped, reseeded folder, settings in their own suite (YomidoriKit/Demo).
.PHONY: demo-iphone
demo-iphone: build-ios  ## Launch the seeded demo on an iPhone simulator (DEVICE=<pattern> to pick)
	@PLATFORM=iphone Scripts/demo.sh

.PHONY: demo-ipad
demo-ipad: build-ios  ## Launch the seeded demo on an iPad simulator
	@PLATFORM=ipad Scripts/demo.sh

.PHONY: build-ios
build-ios: Yomidori.xcodeproj  ## Build the iOS app (simulator, unsigned)
	@Scripts/build.sh ios

# Logic tests run straight from the Swift package — no Xcode project involved.
.PHONY: test
test:  ## Run the package logic tests (no Xcode project needed)
	@Scripts/test.sh

.PHONY: lint
lint:  ## SwiftLint + swift-format, both strict (as CI runs them)
	@swiftlint lint --strict
	@swift format lint --strict --recursive --configuration .swift-format \
		Packages/YomidoriCore/Sources Packages/YomidoriCore/Tests Sources

.PHONY: format
format:  ## Rewrite sources with swift-format
	@swift format --in-place --recursive --configuration .swift-format \
		Packages/YomidoriCore/Sources Packages/YomidoriCore/Tests Sources

.PHONY: icon
icon:  ## Regenerate the app icon PNG (pure CoreGraphics; flattened opaque)
	@swift Scripts/assets/make-icon.swift Sources/Shared/Assets.xcassets/AppIcon.appiconset

.PHONY: clean
clean:  ## Remove the generated project + local build output
	@rm -rf Yomidori.xcodeproj .build-xcode Packages/YomidoriCore/.build dist
	@echo "removed Yomidori.xcodeproj, .build-xcode, package .build, dist (the dictionary, the models and the downloads stay: make clean-models, or delete Sources/Shared/Dictionaries and .build-data by hand)"

##@ Release lane
##~ Cut a build: make release — runs preflight → publish → tag → distribute

# The cut is split by concern, one script each, chained here in order:
#   preflight → publish → tag → distribute
# The pure ends (preflight, tag, distribute) re-derive their inputs from git +
# project.yml, so each runs standalone. The dirty middle (publish: version-bump
# prompts + auto-merging PR + CI-wait) is the one stateful script; state crosses
# to the later steps via the merged commit on main, not through Make.
#
# PLATFORM is ios — the only target there will be; the scripts' macos/all scope
# is inherited machinery. UPLOAD=0 stops after export (no ASC upload). The
# steps are a linear dependency chain so they stay ordered even under
# `make -j`. Run from a clean, up-to-date main.
PLATFORM ?= ios
UPLOAD ?= 1
DIST_FLAGS := $(if $(filter 0,$(UPLOAD)),--no-upload,)

.PHONY: release
release: release-distribute  ## Cut a release (UPLOAD=0 to skip the ASC upload)
	@echo "✓ release complete (PLATFORM=$(PLATFORM))."

.PHONY: release-build
release-build:  ## Like `release` but stop after export (no upload)
	@$(MAKE) release UPLOAD=0

.PHONY: release-preflight
release-preflight:  ## Release step 1: verify a clean, up-to-date base (main or release/X.Y.x)
	@Scripts/release-preflight.sh

.PHONY: release-publish
release-publish: release-preflight  ## Release step 2: bump, open auto-merging PR, wait for CI
	@Scripts/release-publish.sh $(PLATFORM)

.PHONY: release-tag
release-tag: release-publish  ## Release step 3: tag the merge commit + publish GitHub releases
	@Scripts/release-tag.sh $(PLATFORM)

.PHONY: release-distribute
release-distribute: release-tag  ## Release step 4: archive/export (+ upload unless UPLOAD=0)
	@Scripts/release-distribute.sh $(PLATFORM) $(DIST_FLAGS)

# Distribute is the likeliest step to fail (archive/export/ASC upload) and is
# safe to repeat. This standalone retry has NO prereqs — it re-distributes an
# already-tagged release without touching git/PR/tags, after verifying the tag
# for the current version+build exists.
.PHONY: release-distribute-retry
release-distribute-retry:  ## Re-distribute an already-tagged release (no PR/tag steps)
	@Scripts/release-distribute.sh $(PLATFORM) $(DIST_FLAGS) --require-tag

# Upload the package already in dist/ (from a prior `release-build`) without
# rebuilding — for when export succeeded but only the ASC upload failed.
.PHONY: release-upload
release-upload:  ## Upload the already-built dist/ package (no rebuild)
	@Scripts/release-distribute.sh $(PLATFORM) --upload-only
