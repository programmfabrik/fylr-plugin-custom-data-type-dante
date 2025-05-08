ZIP_NAME ?= "customDataTypeDante.zip"
PLUGIN_NAME = "custom-data-type-dante"

# coffescript-files to compile
COFFEE_FILES = commons.coffee \
	DANTEUtil.coffee \
	CustomDataTypeDante.coffee \
	CustomDataTypeDanteFacet.coffee \
	CustomDataTypeDanteTreeview.coffee \
	CustomDataTypeDanteParseJSKOS.coffee

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

all: build ## build all

build: clean ## clean, compile, copy files to build folder

				npm install --save node-fetch # install needed node-module

				mkdir -p build
				mkdir -p build/$(PLUGIN_NAME)
				mkdir -p build/$(PLUGIN_NAME)/webfrontend
				mkdir -p build/$(PLUGIN_NAME)/updater
				mkdir -p build/$(PLUGIN_NAME)/l10n

				mkdir -p src/tmp # build code from coffee
				cp easydb-library/src/commons.coffee src/tmp
				cp src/webfrontend/*.coffee src/tmp
				cd src/tmp && coffee -b --compile ${COFFEE_FILES} # bare-parameter is obligatory!

				cat src/tmp/commons.js >> build/$(PLUGIN_NAME)/webfrontend/customDataTypeDante.js
				cat src/tmp/CustomDataTypeDante.js >> build/$(PLUGIN_NAME)/webfrontend/customDataTypeDante.js
				cat src/tmp/CustomDataTypeDanteFacet.js >> build/$(PLUGIN_NAME)/webfrontend/customDataTypeDante.js
				cat src/tmp/CustomDataTypeDanteParseJSKOS.js >> build/$(PLUGIN_NAME)/webfrontend/customDataTypeDante.js
				cat src/tmp/CustomDataTypeDanteTreeview.js >> build/$(PLUGIN_NAME)/webfrontend/customDataTypeDante.js
				cat src/tmp/DANTEUtil.js >> build/$(PLUGIN_NAME)/webfrontend/customDataTypeDante.js

				cat src/external/geojson-extent.js >> build/$(PLUGIN_NAME)/webfrontend/customDataTypeDante.js # add mapbox
				cat src/external/geo-viewport.js >> build/$(PLUGIN_NAME)/webfrontend/customDataTypeDante.js # add mapbox

				cp src/updater/DANTEUpdater.js build/$(PLUGIN_NAME)/updater/DANTEUpdater.js # build updater
				cat src/tmp/DANTEUtil.js >> build/$(PLUGIN_NAME)/updater/DANTEUpdater.js
				rm -rf src/tmp # clean tmp

				cp l10n/custom-data-type-dante.csv build/$(PLUGIN_NAME)/l10n/customDataTypeDante.csv # copy l10n
				tail -n+2 easydb-library/src/commons.l10n.csv >> build/$(PLUGIN_NAME)/l10n/customDataTypeDante.csv # copy commons

				cp src/webfrontend/css/main.css build/$(PLUGIN_NAME)/webfrontend/customDataTypeDante.css # copy css
				cp manifest.master.yml build/$(PLUGIN_NAME)/manifest.yml # copy manifest

				cp -r node_modules build/$(PLUGIN_NAME)/

clean: ## clean
				rm -rf build

zip: build ## build zip file
			cd build && zip ${ZIP_NAME} -r $(PLUGIN_NAME)/
