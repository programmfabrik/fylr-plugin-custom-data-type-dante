> This Plugin / Repo is being maintained by a community of developers.
There is no warranty given or bug fixing guarantee; especially not by
Programmfabrik GmbH. Please use the github issue tracking to report bugs
and self organize bug fixing. Feel free to directly contact the committing
developers.

# custom-data-type-dante

This is a plugin for [fylr](mentation.fylr.cloud/docs) with Custom Data Type `CustomDataTypeDante` for references to entities of the [DANTE-Vokabulary-Server (https://dante.gbv.de)](https://dante.gbv.de).
For easydb5-instances use [easydb-custom-data-type-dante](https://github.com/programmfabrik/easydb-custom-data-type-dante).

The Plugins uses <https://api.dante.gbv.de/> for the communication with DANTE.

## installation

The latest version of this plugin can be found [here](https://github.com/programmfabrik/fylr-plugin-custom-data-type-dante/releases/latest/download/customDataTypeDante.zip).

The ZIP can be downloaded and installed using the plugin manager, or used directly (recommended).

Github has an overview page to get a list of [all releases](https://github.com/programmfabrik/fylr-plugin-custom-data-type-dante/releases/).

## requirements
This plugin requires https://github.com/programmfabrik/fylr-plugin-commons-library. In order to use this Plugin, you need to add the [commons-library-plugin](https://github.com/programmfabrik/fylr-plugin-commons-library) to your pluginmanager.

## configuration

As defined in `manifest.master.yml` this datatype can be configured:

### Schema options

* which "vocabulary_name" to use. List of Vocabularys [in DANTE](https://dante.gbv.de/search?ot=vocabulary) or [as JSKOS via API](https://api.dante.gbv.de/voc) or [uri.gbv.de/terminology](http://uri.gbv.de/terminology/)
  * for the popup-modes multible vocabularys can be set as a "|"-splitted list
* add new: allow
* add new: target vocabulary for new records
* add new: username for adding
* add new: token for adding

### Mask options

* editorstyle: dropdown, popup, popup with treeview
* cache: on / off
* default values
* editordisplay: default or condensed (oneline)
* labelhierarchie: on / off
* infopopup for dropdown: on / off
* allow manual label choose: on / off
* mapbox-token
* overwrite vocabulary-notation from datamodell
* Default-URI
* Default-Label


## saved data
* conceptName
    * Preferred label of the linked record
* conceptNameChosenByHand
* conceptURI
    * URI to linked record
* conceptFulltext
    * fulltext-string which contains: PrefLabels, AltLabels, HiddenLabels, Notations
* conceptAncestors
    * URI's of all given ancestors
* _fulltext
    * easydb-fulltext
* _standard
    * easydb-standard
* facetTerm
* frontendLanguage

## sources

The source code of this plugin is managed in a git repository at <https://github.com/programmfabrik/fylr-plugin-custom-data-type-dante>.
