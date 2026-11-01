# Yomidori — command-line build/run/test, so you never have to open Xcode.
#
# The shared targets — generate, build, test, lint, the release lane — come from
# slipway (Scripts/slipway, configured by slipway.yml; see its README.md). This
# Makefile adds what's Yomidori's own: the dictionary, running and the demo, and
# the App Store listing. Run `make` (or `make help`) to list them all.

include Scripts/slipway/slipway.mk

##@ Build & test

# The bundled dictionary is built from JMdict, not committed (~78 MB); the project
# must exist on disk before XcodeGen runs, or the app is generated without it.
DICTIONARY := Sources/Shared/Dictionaries/jmdict.sqlite
$(SLIPWAY_XCODEPROJ): $(DICTIONARY)

.PHONY: coverage
coverage:  ## The logic tests with coverage: a table by file, and the report CI sends to Codecov
	@Scripts/coverage.sh

# markdownlint is pinned like SwiftLint, so CI and a local run agree (npx fetches it).
MARKDOWNLINT := markdownlint-cli2@0.23.3

lint: lint-markdown
.PHONY: lint-markdown
lint-markdown:  ## markdownlint, strict (part of lint)
	@npx --yes $(MARKDOWNLINT) '*.md'

.PHONY: icon
icon:  ## Regenerate the app icon PNGs and Home's bird (pure CoreGraphics; the icon flattened opaque)
	@swift Scripts/assets/make-icon.swift Sources/Shared/Assets.xcassets/AppIcon.appiconset
	@swift Scripts/assets/make-icon.swift Sources/Shared/Assets.xcassets/Bird.imageset --bird

# The dictionary and its downloads survive a clean: they take minutes to rebuild.
# (A prerequisite, so this prints before slipway's "removed …".)
clean: clean-keeps-data
.PHONY: clean-keeps-data
clean-keeps-data:
	@echo "keeping the dictionary and its downloads (delete Sources/Shared/Dictionaries and .build-data by hand)"

##@ Run

.PHONY: run-iphone
run-iphone: $(SLIPWAY_XCODEPROJ)  ## Build + launch on an iPhone simulator (DEVICE="SE" / "17 Pro" to pick)
	@Scripts/run-ios.sh iphone "$(DEVICE)"

.PHONY: run-ipad
run-ipad: $(SLIPWAY_XCODEPROJ)  ## Build + launch on an iPad simulator (DEVICE="Air" / "13-inch" to pick)
	@Scripts/run-ios.sh ipad "$(DEVICE)"

.PHONY: run-device
run-device: $(SLIPWAY_XCODEPROJ)  ## Build + install + launch on a paired iPhone/iPad (DEVICE="<name>" to pick)
	@Scripts/run-device.sh "$(DEVICE)"

.PHONY: run-mac
run-mac: $(SLIPWAY_XCODEPROJ)  ## Build the Mac app signed for this Mac and open it
	@Scripts/run-mac.sh

# The demo launchers install the last simulator build and start it with -yomidori-demo:
# stores in a wiped, reseeded folder, settings in their own suite (YomidoriKit/Demo).
.PHONY: demo-iphone
demo-iphone: build-ios  ## Launch the seeded demo on an iPhone simulator (DEVICE=<pattern>, TAB=, SCREEN=, SEARCH=, SPREAD=1, SELECT=1, PICK=<text>, BEGIN=1)
	@PLATFORM=iphone Scripts/demo.sh

.PHONY: demo-ipad
demo-ipad: build-ios  ## Launch the seeded demo on an iPad simulator
	@PLATFORM=ipad Scripts/demo.sh

.PHONY: demo-mac
demo-mac: $(SLIPWAY_XCODEPROJ)  ## Open the seeded demo on this Mac (TAB=, SCREEN=, SEARCH=, PICK=, DEMO_LANG=)
	@DEMO=1 Scripts/run-mac.sh

##@ Dictionary

$(DICTIONARY): Scripts/data/build-jmdict.py
	@Scripts/data/build-jmdict.py --output $(DICTIONARY)
	@if [ -x $(PITCH_VENV)/bin/python ]; then \
		$(PITCH_VENV)/bin/python Scripts/data/estimate-pitch.py --database $(DICTIONARY); fi

.PHONY: dictionary
dictionary: $(DICTIONARY)  ## Build the bundled JMdict database (downloads JMdict_e once into .build-data/)

# EDRDG rebuilds JMdict, KANJIDIC2 and KRADFILE nightly, but the downloads above are fetched
# once and kept, so the bundle ages until someone throws them away. This does that and
# builds again — with the pitch estimates, when the venv is there. Kanjium's accents and
# KanjiVG stay: the one has not moved in years, the other is a release pinned in the script.
EDRDG_DOWNLOADS := $(addprefix .build-data/,JMdict_e.gz kanjidic2.xml.gz kradfile.gz)

.PHONY: dictionary-fresh
dictionary-fresh:  ## Refetch JMdict, KANJIDIC2 and KRADFILE from EDRDG and rebuild the dictionary (do this before a release)
	@rm -f $(EDRDG_DOWNLOADS) $(DICTIONARY)
	@$(MAKE) --no-print-directory dictionary
	@sqlite3 $(DICTIONARY) "SELECT 'JMdict of ' || value FROM meta WHERE key = 'created'"

# The pitch of the words Kanjium has none for, estimated into the dictionary by Open JTalk
# and the habits of Kanjium's own compounds. Optional: the app shows no estimates without
# it. pyopenjtalk builds from source, with a CMake from PyPI and the policy floor its old
# CMake files need; once the venv is there, a rebuilt dictionary gets its estimates again.
PITCH_VENV := .build-data/pitch-venv
PITCH_VENV_READY := $(PITCH_VENV)/.ready

$(PITCH_VENV_READY): Scripts/data/pitch-requirements.txt
	@python3.13 -m venv $(PITCH_VENV) \
		&& $(PITCH_VENV)/bin/pip install -q --upgrade pip setuptools wheel cmake cython numpy \
		&& PATH="$(CURDIR)/$(PITCH_VENV)/bin:$$PATH" CMAKE_POLICY_VERSION_MINIMUM=3.5 \
			$(PITCH_VENV)/bin/pip install -q --no-build-isolation -r Scripts/data/pitch-requirements.txt \
		&& touch $@

.PHONY: pitch
pitch: $(DICTIONARY) $(PITCH_VENV_READY)  ## Estimate the pitch Kanjium lacks into the dictionary (python3.13 + a local venv; optional)
	@$(PITCH_VENV)/bin/python Scripts/data/estimate-pitch.py --database $(DICTIONARY)

.PHONY: pitch-measure
pitch-measure: $(DICTIONARY) $(PITCH_VENV_READY)  ## How often the estimate agrees with Kanjium, on compounds held out
	@$(PITCH_VENV)/bin/python Scripts/data/estimate-pitch.py --database $(DICTIONARY) --measure

##@ App Store (Scripts/asc: listing.json and shots.json are the sources; asc-* are dry runs, -apply writes)

.PHONY: shots
shots: $(SLIPWAY_XCODEPROJ)  ## Capture the store screenshots from the demo: PLATFORM=iphone|ipad|mac [LANGS=en,ja] [OUT=shots] [PAUSE=1] [ONLY=a,b]
	@Scripts/shoot.sh

.PHONY: asc-listing
asc-listing:  ## Show what the listing text in listing.json would change in ASC
	@Scripts/asc/run.sh listing

.PHONY: asc-listing-apply
asc-listing-apply:  ## Write the listing text to ASC
	@Scripts/asc/run.sh listing --apply

.PHONY: asc-screenshots
asc-screenshots:  ## Show the screenshot upload plan from shots/
	@Scripts/asc/run.sh screens

.PHONY: asc-screenshots-apply
asc-screenshots-apply:  ## Replace the ASC screenshot sets with shots/
	@Scripts/asc/run.sh screens --apply
