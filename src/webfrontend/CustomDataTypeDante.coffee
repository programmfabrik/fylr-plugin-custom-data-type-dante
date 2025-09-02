# get all the dante-vocs, needed later for labeldisplay
DANTEVocs = []
DANTEVocsNotationTranslations = [];
if DANTEVocs.length == 0
  getVocs_xhr = { "xhr" : undefined }
  getVocs_xhr.xhr = new (CUI.XHR)(url: 'https://api.dante.gbv.de/voc&cache=1&limit=1000')
  getVocs_xhr.xhr.start().done((data, status, statusText) ->
    DANTEVocs = data
    for key, voc of DANTEVocs
      DANTEVocsNotationTranslations[voc.notation[0]] = voc.prefLabel
  )

class CustomDataTypeDANTE extends CustomDataTypeWithCommonsAsPlugin

  #######################################################################  
  # return the prefix for localization for this data type.  
  # Note: This function is supposed to be deprecated, but is still used   
  # internally and has to be used here as a workaround because the   
  # default generates incorrect prefixes for camelCase class names 
  getL10NPrefix: ->
    'custom.data.type.dante'

  #######################################################################
  # use custom facet
  getFacet: (opts) ->
      opts.field = @
      new CustomDataTypeDANTEFacet(opts)

  #######################################################################
  # return name of plugin
  getCustomDataTypeName: ->
    return "custom:base.custom-data-type-dante.dante"


  #######################################################################
  # allows usage of "standard (geo)" in maskoptioons
  supportsGeoStandard: 
    ->true 

  #######################################################################
  # overwrite getCustomMaskSettings
  getCustomMaskSettings: ->
    if @ColumnSchema
      return @FieldSchema.custom_settings || {};
    else
      return {}

  #######################################################################
  # temporarily disable cache (after "add-new" / "ingest" - action)
  disableCache: ->
    @FieldSchema.custom_settings.use_cache.value = false
    return

  #######################################################################
  # overwrite getCustomSchemaSettings
  getCustomSchemaSettings: ->
    if @ColumnSchema
      return @ColumnSchema.custom_settings || {};
    else
      return {}

  #######################################################################
  # returns the databaseLanguages
  getDatabaseLanguages: () ->
    databaseLanguages = ez5.loca.getLanguageControl().getLanguages().slice()
    return databaseLanguages

  #######################################################################
  # overwrite getCustomSchemaSettings
  name: (opts = {}) ->
    if ! @ColumnSchema
      if opts?.callfrompoolmanager == true && opts?.name != ''
        return opts.name
      else
        return "noNameSet"
    else
      return @ColumnSchema?.name

  #######################################################################
  # return name (l10n) of plugin
  getCustomDataTypeNameLocalized: ->
    $$("custom.data.type.dante.name")

  #######################################################################
  # returns name of the given vocabulary from datamodel
  getVocabularyNameFromDatamodel: (opts = {}) ->
    # if vocnotation is given in mask, use from masksettings
    fromMask = @getCustomMaskSettings()?.vocabulary_name_overwrite?.value
    if fromMask
      return fromMask

    # else use from datamodel-config
    fromDatamodell = @getCustomSchemaSettings().vocabulary_name?.value
    if ! fromDatamodell
      # maybe the call is from poolmanagerplugin?
      if opts?.callfrompoolmanager == true
        if opts?.voc
          return opts?.voc
      fromDatamodell = 'gender'
    fromDatamodell


  #######################################################################
  # returns, if user is allowed and correctly configured to add new records
  getIngestPermissionStatus: ->
    status = false;
    # check settings in schema
    if @getCustomSchemaSettings()?.insert_allowed?.value == true
      if @getCustomSchemaSettings()?.insert_username?.value != '' && @getCustomSchemaSettings()?.insert_token?.value != ''&& @getCustomSchemaSettings()?.insert_voc_notation?.value != ''
        # check system_right
        if ez5.session.hasSystemRight("plugin.custom-data-type-dante.dante_plugin", "dante_allow_add_records") || ez5.session.hasSystemRight("system.root")
          status = true
    status

  #######################################################################
  # returns an entry for the three-dots-button-bar for addition of new records

  clearIngestForm: (that) ->
      that.form.getFieldsByName('dante_addnew_form_preflabel')[0].setValue("")
      that.form.getFieldsByName('dante_addnew_form_altlabel')[0].setValue("")
      that.form.getFieldsByName('dante_addnew_form_altlabel2')[0].setValue("")
      that.form.getFieldsByName('dante_addnew_form_definition')[0].setValue("")
      that.form.getFieldsByName('dante_addnew_form_example')[0].setValue("")
      that.form.getFieldsByName('dante_addnew_form_note')[0].setValue("")
      @

  enableIngestButtonAndForm: (that) ->
      # enable button
      that.sendToDanteButton.enable()
      # set button text
      that.sendToDanteButton.setText $$('custom.data.type.dante.add_new.modal.ok_send_button')
      # set icon
      that.sendToDanteButton.setIcon new CUI.Icon(class: "fa-arrow-circle-o-right")
      # enable form
      that.form.enable()
      @

  disableIngestButtonAndForm: (that) ->
      # disable this button
      that.sendToDanteButton.disable()
      # change text
      that.sendToDanteButton.setText $$('custom.data.type.commons.controls.addnew.sending')
      # add loader icon
      that.sendToDanteButton.setIcon new CUI.Icon(class: "fa-spinner fa-spin")
      # disable form
      that.form.disable()
      @

  getCustomButtonBarEntryForNewRecordAddition: (that, data, cdata, opts={}) ->
    that.modal = {}
    that.form = {}
    that.confDialog = {}

    that.sendToDanteButton = new CUI.Button
                      text: $$("custom.data.type.dante.add_new.modal.ok_send_button")
                      class: "cui-dialog"
                      icon_left: new CUI.Icon(class: "fa-arrow-circle-o-right")
                      primary: true
                      hidden: true
                      onClick: =>

                        that.disableIngestButtonAndForm that

                        #############################################
                        # build jskos from given information

                        # check if at least "preflabel" ist given
                        prefLabel = that.form.getFieldsByName('dante_addnew_form_preflabel')[0]

                        if ! prefLabel.getValue()
                          CUI.alert(text: $$('custom.data.type.commons.controls.addnew.no_preflabel_given'))
                          that.enableIngestButtonAndForm that
                          return

                        newJSKOSRecord = {}
                        newJSKOSRecord.uri = ''
                        newJSKOSRecord.type = ['http://www.w3.org/2004/02/skos/core#Concept']
                        newJSKOSRecord.inScheme = [{'uri' : 'http://uri.gbv.de/terminology/' + that.getCustomSchemaSettings().insert_voc_notation.value }]
                        newJSKOSRecord.prefLabel = {'de' : that.form.getFieldsByName('dante_addnew_form_preflabel')[0].getValue()}
                        altLabels = []
                        if that.form.getFieldsByName('dante_addnew_form_altlabel')[0].getValue()
                          altLabels.push that.form.getFieldsByName('dante_addnew_form_altlabel')[0].getValue()
                        if that.form.getFieldsByName('dante_addnew_form_altlabel2')[0].getValue()
                          altLabels.push that.form.getFieldsByName('dante_addnew_form_altlabel2')[0].getValue()

                        if altLabels.length > 0
                          newJSKOSRecord.altLabel = {'de' : altLabels }

                        if that.form.getFieldsByName('dante_addnew_form_definition')[0].getValue()
                          newJSKOSRecord.definition = {'de' : [that.form.getFieldsByName('dante_addnew_form_definition')[0].getValue()]}

                        if that.form.getFieldsByName('dante_addnew_form_example')[0].getValue()
                          newJSKOSRecord.example = {'de' : [that.form.getFieldsByName('dante_addnew_form_example')[0].getValue()]}

                        if that.form.getFieldsByName('dante_addnew_form_note')[0].getValue()
                          newJSKOSRecord.note = {'de' : [that.form.getFieldsByName('dante_addnew_form_note')[0].getValue()]}

                        newJSKOS = [newJSKOSRecord]
                        newJSKOSString = JSON.stringify newJSKOS
                        ingestObject = [{ 'username' : that.getCustomSchemaSettings().insert_username.value, 'token' : that.getCustomSchemaSettings().insert_token.value, 'data' : JSON.stringify(newJSKOS)}]
                        newIngestString = JSON.stringify ingestObject

                        #############################################
                        # send jskos to dante and parse result
                        dante_ingest_xhr = new CUI.XHR
                                                  url: "https://api.dante.gbv.de/ingest"
                                                  timeout: 10000
                                                  method: 'POST'
                                                  body: newIngestString

                        dante_ingest_xhr.start()
                        .done (data, status, statusText) =>
                          # disable cache!
                          that.disableCache()
                          # show dialog: "ok" or "take over new record"
                          that.confDialog = new CUI.ConfirmationDialog
                                            markdown: true,
                                            text: $$('custom.data.type.commons.controls.addnew.new_record_message', uri: data[0].uri)
                                            title: $$('custom.data.type.commons.controls.addnew.new_record_title')
                                            icon: "question"
                                            buttons: [
                                              text: $$('custom.data.type.commons.controls.addnew.new_record_not_take_over')
                                              onClick: =>
                                                # dont take over new record
                                                that.sendToDanteButton.hide()
                                                that.enableIngestButtonAndForm that
                                                that.clearIngestForm that
                                                that.confDialog.destroy()
                                                that.modal.destroy()
                                            ,
                                              text: $$('custom.data.type.commons.controls.addnew.new_record_take_over')
                                              primary: true
                                              onClick: =>
                                                that.sendToDanteButton.hide()
                                                that.enableIngestButtonAndForm that
                                                that.clearIngestForm that
                                                that.confDialog.destroy()
                                                that.modal.destroy()
                                                # DO take over new record
                                                if data.length == 1
                                                  resultJSKOS = data[0]
                                                  # lock conceptName (only preflabel)
                                                  cdata.conceptName = DANTEUtil.getConceptNameFromJSKOSObject resultJSKOS, that.getFrontendLanguage(), false
                                                  # lock conceptURI in savedata
                                                  cdata.conceptURI = resultJSKOS.uri
                                                  # no ancestors, because not in hierarchy yet
                                                  cdata.conceptAncestors = []
                                                  # lock _fulltext in savedata
                                                  cdata._fulltext = DANTEUtil.getFullTextFromJSKOSObject resultJSKOS, that.getDatabaseLanguages()
                                                  # lock _standard in savedata
                                                  cdata._standard = DANTEUtil.getStandardFromJSKOSObject resultJSKOS, that.getDatabaseLanguages(), false
                                                  # lock facetTerm in savedata
                                                  cdata.facetTerm = DANTEUtil.getFacetTermFromJSKOSObject resultJSKOS, that.getDatabaseLanguages(), false
                                                  # update layout
                                                  that.__updateResult(cdata, that.layout, opts)
                                            ]
                          that.confDialog.show()
                        .fail (data, status, statusText) =>
                          errorMessage = 'unknown'
                          if data?.Description
                            errorMessage = status + ' ' + statusText + ': ' + data.Description
                          that.enableIngestButtonAndForm that
                          CUI.alert(text: $$('custom.data.type.commons.controls.addnew.error_while_ingest', error: errorMessage))

    addNew =
        text: $$('custom.data.type.commons.controls.addnew.label')
        value: 'new'
        name: 'addnewValueFromDANTEPlugin'
        class: 'addnewValueFromDANTEPlugin'
        icon_left: new CUI.Icon(class: "fa-plus")
        onClick: =>
          # hide dots-menu
          that.dotsButtonMenu.hide()
          # open modal with form for entering of basic record information
          that.modal = new CUI.Modal
              placement: "c"
              pane:
                  content:
                    new CUI.Label
                      text: $$("custom.data.type.dante.add_new.modal.introtext")
                      multiline: true
                  header_left: new CUI.Label( text: $$("custom.data.type.dante.add_new.modal.header_left"))
                  header_right: new CUI.Label( text: $$("custom.data.type.dante.add_new.modal.header_right") + ': ' + that.getCustomSchemaSettings().insert_voc_notation.value)
                  footer_right: =>
                    [
                      new CUI.Button
                        text: $$("custom.data.type.dante.add_new.modal.show_form")
                        class: "cui-dialog"
                        onClick: (e, b) =>
                          b.hide()
                          that.form = new CUI.Form
                              fields: [
                                form:
                                  label: $$("custom.data.type.dante.add_new.modal.form.preflabel") + ' *'
                                  hint: $$("custom.data.type.dante.add_new.modal.form.preflabel.hint")
                                type: CUI.Input
                                name: "dante_addnew_form_preflabel"
                              ,
                                form:
                                  label: $$("custom.data.type.dante.add_new.modal.form.altlabel")
                                type: CUI.Input
                                name: "dante_addnew_form_altlabel"
                              ,
                                form:
                                  label: $$("custom.data.type.dante.add_new.modal.form.altlabel2")
                                type: CUI.Input
                                name: "dante_addnew_form_altlabel2"
                              ,
                                form:
                                  label: $$("custom.data.type.dante.add_new.modal.form.definition")
                                type: CUI.Input
                                textarea: true
                                name: "dante_addnew_form_definition"
                              ,
                                form:
                                  label: $$("custom.data.type.dante.add_new.modal.form.example")
                                type: CUI.Input
                                textarea: true
                                name: "dante_addnew_form_example"
                              ,
                                form:
                                  label: $$("custom.data.type.dante.add_new.modal.form.note")
                                  hint: $$("custom.data.type.dante.add_new.modal.form.note.hint")
                                type: CUI.Input
                                textarea: true
                                name: "dante_addnew_form_note"
                              ]
                          that.form.start()
                          that.modal.setContent(that.form)
                          that.sendToDanteButton.show()
                    ,
                      new CUI.Button
                        text: $$("custom.data.type.dante.add_new.modal.cancel_button")
                        class: "cui-dialog"
                        onClick: =>
                          that.sendToDanteButton.hide()
                          that.modal.destroy()
                    ,
                      that.sendToDanteButton
                    ]
          that.modal.show()

  #######################################################################
  # render popup as treeview?
  renderPopupAsTreeview: (opts) ->
    result = false
    if @.getCustomMaskSettings().editor_style?.value == 'popover_with_treeview'
      result = true
    if opts?.callfrompoolmanager == true
      if opts?.editorstyle == 'popover_with_treeview'
        result = true
    result


  #######################################################################
  # get the active vocabular
  #   a) from vocabulary-dropdown (POPOVER)
  #   b) return all given vocs (inline)
  getActiveVocabularyName: (cdata, opts) ->
    that = @
    # is the voc set in dropdown?
    if cdata?.dante_PopoverVocabularySelect && that.popover?.isShown()
      vocParameter = cdata.dante_PopoverVocabularySelect
    else
      # else all given vocs
      vocParameter = that.getVocabularyNameFromDatamodel(opts);
    vocParameter


  #######################################################################
  # returns markup to display in expert search
  #######################################################################
  renderSearchInput: (data, opts) ->
      that = @
      if not data[@name()]
          data[@name()] = {}

      that.callFromExpertSearch = true

      form = @renderEditorInput(data, '', opts)

      CUI.Events.listen
            type: "data-changed"
            node: form
            call: =>
                CUI.Events.trigger
                    type: "search-input-change"
                    node: form
                CUI.Events.trigger
                    type: "editor-changed"
                    node: form
                CUI.Events.trigger
                    type: "change"
                    node: form
                CUI.Events.trigger
                    type: "input"
                    node: form

      form.DOM

  needsDirectRender: ->
    return true

  #######################################################################
  # make searchfilter for expert-search
  #######################################################################
  getSearchFilter: (data, key=@name()) ->
      that = @

      objecttype = @path()
      objecttype = objecttype.split('.')
      objecttype = objecttype[0]

      # search for empty values
      if data[key+":unset"]
          filter =
              type: "in"
              fields: [ @fullName()+".conceptName" ]
              in: [ null ]
          filter._unnest = true
          filter._unset_filter = true
          return filter

      else if data[key+":has_value"]
        return @getHasValueFilter(data, key)

      # dropdown or popup without tree or use of searchbar: use sameas
      if ! that.renderPopupAsTreeview() || ! data[key]?.experthierarchicalsearchmode
        filter =
            type: "complex"
            search: [
                type: "in"
                mode: "fulltext"
                bool: "must"
                phrase: false
                fields: [ @path() + '.' + @name() + ".conceptURI" ]
            ]
        if ! data[@name()]
            filter.search[0].in = [ null ]
        else if data[@name()]?.conceptURI
            filter.search[0].in = [data[@name()].conceptURI]
        else
            filter = null

      # popup with tree: 3 Modes
      if that.renderPopupAsTreeview()
        # 1. find all records which have the given uri in their ancestors
        if data[key].experthierarchicalsearchmode == 'include_children'
          filter =
              type: "complex"
              search: [
                  type: "match"
                  mode: "token"
                  bool: "must",
                  phrase: true
                  fields: [ @path() + '.' + @name() + ".conceptAncestors" ]
              ]
          if ! data[@name()]
              filter.search[0].string = null
          else if data[@name()]?.conceptURI
              filter.search[0].string = data[@name()].conceptURI
          else
              filter = null
        # 2. find all records which have exact that match
        if data[key].experthierarchicalsearchmode == 'exact'
          filter =
              type: "complex"
              search: [
                  type: "in"
                  mode: "fulltext"
                  bool: "must"
                  phrase: false
                  fields: [ @path() + '.' + @name() + ".conceptURI" ]
              ]
          if ! data[@name()]
              filter.search[0].in = [ null ]
          else if data[@name()]?.conceptURI
              filter.search[0].in = [data[@name()].conceptURI]
          else
              filter = null

      filter


  #######################################################################
  # make tag for expert-search
  #######################################################################
  getQueryFieldBadge: (data) ->
      if data["#{@name()}:unset"]
        value = $$("text.column.badge.without")
      else if data["#{@name()}:has_value"]
        value = $$("field.search.badge.has_value")
      else
          value = data[@name()].conceptName

      if data[@name()]?.experthierarchicalsearchmode == 'exact' || data[@name()]?.experthierarchicalsearchmode == 'include_children'
        searchModeAddition = $$("custom.data.type.dante.modal.form.popup.choose_expertsearchmode_." + data[@name()].experthierarchicalsearchmode + "_short")
        value = searchModeAddition + ': ' + value

      name: @nameLocalized()
      value: value

  #######################################################################
  # choose label manually from popup
  #######################################################################
  __chooseLabelManually: (cdata,  layout, resultJSKOS, anchor, opts, labelWithHierarchie) ->
      that = @
      choiceLabels = []
      choiceLabelsObj = []
      #preflabels
      for key, value of resultJSKOS.prefLabel
        choiceLabelsObj.push {key: key, value: value}
        choiceLabels.push value
      # altlabels
      for key, value of resultJSKOS.altLabel
        for key2, value2 of value
          choiceLabelsObj.push {key: key, value: value2}
          choiceLabels.push value2
            
      # if labelsWithHierarchie, add hierarchie-versions of the labels
      if labelWithHierarchie
          # foreach choicelabel, generate also a label with the hierarchie in matching language
          for choiceLabelsObjKey, choiceLabelsObjValue of choiceLabelsObj
              desiredLanguage = choiceLabelsObjValue.key
              # get hierarchie
              # collect all the preflabels of record and ancestors
              givenHierarchieLabels = []
              givenHierarchieLabels = givenHierarchieLabels.concat(resultJSKOS['ancestors'].map((x) => x.prefLabel))
              hierarchieParts = []
              for value, key in givenHierarchieLabels
                  hierarchieLevelLabel = ''
                  if desiredLanguage.length == 2
                    # if a preflabel exists in given frontendLanguage or without language (person / corporate)
                    if value[desiredLanguage] || value['zxx'] || value['und'] || value['mus'] || value['mil']
                      if value?[desiredLanguage]
                        hierarchieLevelLabel = value[desiredLanguage]
                      else if value['zxx']
                        hierarchieLevelLabel = value['zxx']
                      else if value['und']
                        hierarchieLevelLabel = value['und']
                      else if value['mis']
                        hierarchieLevelLabel = value['mis']
                      else if value['mul']
                        hierarchieLevelLabel = value['mul']
                  hierarchieParts.push hierarchieLevelLabel
              hierarchieLabelGenerated = hierarchieParts.join(' ➔ ')
              # add choicelabel with hierarchie
              choiceLabels.push hierarchieLabelGenerated + ' ➔ ' + choiceLabelsObjValue.value
        
      prefLabelButtons = []
      for key, value of choiceLabels
        button = new CUI.Button
          text: value
          appearance: "flat"
          icon_left: new CUI.Icon(class: "fa-arrow-circle-o-right")
          class: 'dantePlugin_SearchButton'
          onClick: (evt,button) =>
            # lock choosen conceptName in savedata
            cdata.conceptName = button.opts.text
            cdata.conceptNameChosenByHand = true
            # update the layout in form
            that.__updateResult(cdata, layout, opts)
            # close popovers
            if that.popover
              that.popover.hide()
            if chooseLabelPopover
              chooseLabelPopover.hide()
            @
        prefLabelButtons.push button

      # init popover
      chooseLabelPopover = new CUI.Popover
          element: anchor
          placement: "wn"
          class: "commonPlugin_Popover"
      chooseLabelContent = new  CUI.VerticalLayout
          class: "cui-pane"
          top:
            content: [
                new CUI.PaneHeader
                    left:
                        content:
                            new CUI.Label(text: $$('custom.data.type.dante.modal.form.popup.choose_manual_label'))
            ]
          center:
            content: [
              prefLabelButtons
            ]
          bottom: null
      chooseLabelPopover.setContent(chooseLabelContent)
      chooseLabelPopover.show()


  #######################################################################
  # choose search mode for the hierarchical expert search
  #   ("exact" or "with children")
  #######################################################################
  __chooseExpertHierarchicalSearchMode: (cdata,  layout, resultJSKOS, anchor, opts) ->
      that = @

      ConfirmationDialog = new CUI.ConfirmationDialog
        text: $$('custom.data.type.dante.modal.form.popup.choose_expertsearchmode_label2') + '\n\n' +  $$('custom.data.type.dante.modal.form.popup.choose_expertsearchmode_label3') + ': ' + cdata.conceptURI +  '\n'
        title: $$('custom.data.type.dante.modal.form.popup.choose_expertsearchmode_label')
        icon: "question"
        cancel: false
        buttons: [
          text: $$('custom.data.type.dante.modal.form.popup.choose_expertsearchmode_.exact')
          onClick: =>
            # lock choosen searchmode in savedata
            cdata.experthierarchicalsearchmode = 'exact'
            # update the layout in form
            that.__updateResult(cdata, layout, opts)
            ConfirmationDialog.destroy()
        ,
          text: $$('custom.data.type.dante.modal.form.popup.choose_expertsearchmode_.include_children')
          primary: true
          onClick: =>
            # lock choosen searchmode in savedata
            cdata.experthierarchicalsearchmode = 'include_children'
            # update the layout in form
            that.__updateResult(cdata, layout, opts)
            ConfirmationDialog.destroy()
        ]
      ConfirmationDialog.show()


  #######################################################################
  # handle suggestions-menu  (POPOVER)
  #######################################################################
  __updateSuggestionsMenu: (cdata, cdata_form, dante_searchstring, input, suggest_Menu, searchsuggest_xhr, layout, opts) ->
    that = @

    delayMillisseconds = 50

    # show loader
    menu_items = [
        text: $$('custom.data.type.dante.modal.form.loadingSuggestions')
        icon_left: new CUI.Icon(class: "fa-spinner fa-spin")
        disabled: true
    ]
    itemList =
      items: menu_items
    suggest_Menu.setItemList(itemList)

    setTimeout ( ->

        dante_searchstring = dante_searchstring.replace /^\s+|\s+$/g, ""
        if dante_searchstring.length == 0
            return

        suggest_Menu.show()

        # limit-Parameter
        dante_countSuggestions = 50

        # run autocomplete-search via xhr
        if searchsuggest_xhr.xhr != undefined
            # abort eventually running request
            searchsuggest_xhr.xhr.abort()

        # cache?
        cache = '&cache=0'
        if that.getCustomMaskSettings().use_cache?.value
            cache = '&cache=1'

        # voc parameter
        vocParameter = that.getActiveVocabularyName(cdata, opts)
        # voc parameter if called from poolmanagerplugin
        if opts?.callfrompoolmanager
          vocParameter = that.getVocabularyNameFromDatamodel(opts)

        # start request
        searchsuggest_xhr.xhr = new (CUI.XHR)(url: location.protocol + '//api.dante.gbv.de/suggest?search=' + dante_searchstring + '&voc=' + vocParameter + '&language=' + that.getFrontendLanguage() + '&limit=' + dante_countSuggestions + cache)
        searchsuggest_xhr.xhr.start().done((data_1, status, statusText) ->

            extendedInfo_xhr = { "xhr" : undefined }
            detailAPIPath = { "xhr" : undefined }

            # show voc-headlines in selectmenu? default: no headlines
            showHeadlines = false;

            # are there multible vocs in datamodel?
            multibleVocs = false
            vocTest = that.getVocabularyNameFromDatamodel(opts)
            vocTestArr = vocTest.split('|')
            if vocTestArr.length > 1
              multibleVocs = true

            # conditions for headings in searchslot (for documentation reasons very detailed)

            #A. If only search slot (inlineform, popup invisible)
            if ! that.popover?.isShown()
              # A.1. If only 1 vocabulary, then no subheadings
              if multibleVocs == false
                showHeadlines = false
              else
              # A.2. If several vocabularies, then necessarily and always subheadings
              if multibleVocs == true
                showHeadlines = true
            #B. When popover (popup visible)
            else if that.popover?.isShown()
              # B.1. If several vocabularies
              if multibleVocs == true
                # B.1.1 If vocabulary selected from dropdown, then no subheadings
                if cdata?.dante_PopoverVocabularySelect != '' && cdata?.dante_PopoverVocabularySelect != vocTest
                  showHeadlines = false
                else
                # B.2.2 If "All vocabularies" in dropdown, then necessarily and always subheadings
                if cdata?.dante_PopoverVocabularySelect == vocTest
                  showHeadlines = true
              else
                # B.2. If only one vocabulary
                if multibleVocs == false
                  # B.2.1 Don't show subheadings
                  showHeadlines = false

            # the actual vocab (if multible, add headline + divider)
            actualVocab = ''

            # sort by voc/uri-part in tmp-array
            tmp_items = []
            # a list of the unique text suggestions for treeview-suggest
            unique_text_suggestions = []
            unique_text_items = []
            for suggestion, key in data_1[1]
              vocab = 'default'
              if showHeadlines
                vocab = data_1[3][key]
                vocab = vocab.replace('https://', '')
                vocab = vocab.replace('http://', '')
                vocab = vocab.replace('uri.gbv.de/terminology/', '')
                vocab = vocab.split('/').shift()
              if ! Array.isArray tmp_items[vocab]
                tmp_items[vocab] = []
              do(key) ->
                # default item
                item =
                  text: suggestion
                  value: data_1[3][key]
                  tooltip:
                    markdown: true
                    placement: "ne"
                    content: (tooltip) ->
                      # show infopopup
                      encodedURI = encodeURIComponent(data_1[3][key])
                      that.__getAdditionalTooltipInfo(encodedURI, tooltip, extendedInfo_xhr)
                      new CUI.Label(icon: "spinner", text: $$('custom.data.type.dante.modal.form.popup.loadingstring'))
                tmp_items[vocab].push item
                # unique item for treeview
                if suggestion not in unique_text_suggestions
                  unique_text_suggestions.push suggestion
                  item =
                    text: suggestion
                    value: suggestion
                  unique_text_items.push item
            # create new menu with suggestions
            menu_items = []

            actualVocab = ''
            for vocab, part of tmp_items
              if showHeadlines
                if ((actualVocab == '' || actualVocab != vocab) && vocab != 'default')
                     actualVocab = vocab
                     item =
                          divider: true
                     menu_items.push item
                     # try to get translation for vocabNotation
                     actualVocabTranslation = actualVocab
                     if DANTEVocsNotationTranslations
                       if DANTEVocsNotationTranslations[actualVocab]
                         #if DANTEVocsNotationTranslations[actualVocab]
                         frontendLanguage = that.getFrontendLanguage()
                         if DANTEVocsNotationTranslations[actualVocab][frontendLanguage]
                           actualVocabTranslation = DANTEVocsNotationTranslations[actualVocab][frontendLanguage]
                     item =
                          label: actualVocabTranslation
                     menu_items.push item
                     item =
                          divider: true
                     menu_items.push item
              for suggestion,key2 in part
                menu_items.push suggestion

            # set new items to menu
            itemList =
              onClick: (ev2, btn) ->
                # if inline or treeview without popup
                if ! that.renderPopupAsTreeview(opts) || ! that.popover?.isShown()
                  searchUri = btn.getOpt("value")
                  if that.popover
                    # put a loader to popover
                    newLoaderPanel = new CUI.Pane
                        class: "cui-pane"
                        top:
                            content: [
                                new CUI.PaneHeader
                                    left:
                                        content:
                                            new CUI.Label(text: $$('custom.data.type.dante.modal.form.popup.choose'))
                                    right:
                                        content:
                                            new CUI.EmptyLabel
                                              text: that.getVocabularyNameFromDatamodel(opts)
                            ]
                        center:
                            content: [
                                new CUI.HorizontalLayout
                                  maximize: true
                                  left: null
                                  center:
                                    content:
                                      new CUI.Label
                                        centered: true
                                        size: "big"
                                        icon: "spinner"
                                        text: $$('custom.data.type.dante.modal.form.popup.loadingstring')
                                  right: null
                            ]
                    that.popover.setContent(newLoaderPanel)
                    
                  searchUri = encodeURIComponent(searchUri)

                  # fire request for detailed record and save information
                  DANTEUtil.getDetailAboutRecordViaAPI(that, searchUri, cache, opts, cdata, layout, input)

                # if treeview: set choosen suggest-entry to searchbar
                if that.renderPopupAsTreeview(opts) && that.popover
                  if cdata_form
                    cdata_form.getFieldsByName("searchbarInput")[0].setValue(btn.getText())

              items: menu_items

            # if treeview in popup: use unique suggestlist (only one voc and text-search)
            if that.renderPopupAsTreeview(opts) && that.popover?.isShown()
              itemList.items = unique_text_items

            # if no suggestions: set "empty" message to menu
            if itemList.items.length == 0
              itemList =
                items: [
                  text: $$('custom.data.type.dante.modal.form.popup.suggest.nohit')
                  value: undefined
                ]
            suggest_Menu.setItemList(itemList)
            suggest_Menu.show()
        )
    ), delayMillisseconds


  #######################################################################
  # render editorinputform
  renderEditorInput: (data, top_level_data, opts) ->
    that = @
    # if not called from poolmanagerplugin
    if ! opts?.callfrompoolmanager
      if not data[@name()]
          cdata = {}
          # if default values are set in masksettings
          if @getCustomMaskSettings().default_concept_uri?.value && @getCustomMaskSettings().default_concept_name?.value
              cdata = {
                  conceptName : @getCustomMaskSettings().default_concept_name?.value
                  conceptURI : @getCustomMaskSettings().default_concept_uri?.value
                  _fulltext : {}
                  _standard : {}
                  facetTerm : {}
                  conceptAncestors: null
              }
          data[@name()] = cdata
      else
          cdata = data[@name()]
    # if called from poolmanagerplugin
    else
        cdata = data[@name(opts)]
        if ! cdata?.conceptURI
          cdata = {}

    # inline or popover?
    dropdown = false
    if opts?.editorstyle
      editorStyle = opts.editorstyle
    else
      if @getCustomMaskSettings().editor_style?.value == 'dropdown'
        editorStyle = 'dropdown'
      else
        editorStyle = 'popup'
    if editorStyle == 'dropdown'
        @__renderEditorInputInline(data, cdata, opts)
    else
        # add "add-new"-button to menu?
        if that.getIngestPermissionStatus() == true
          customButtonBarEntrys = [that.getCustomButtonBarEntryForNewRecordAddition(that, data, cdata, opts)]
        @__renderEditorInputPopover(data, cdata, opts, customButtonBarEntrys)


  #######################################################################
  # get frontend-language
  getFrontendLanguage: () ->
    # language
    desiredLanguage = ez5?.loca?.getLanguage()
    if desiredLanguage
      desiredLanguage = desiredLanguage.split('-')
      desiredLanguage = desiredLanguage[0]
    else
      desiredLanguage = false

    desiredLanguage

  #######################################################################
  # update dropdown
  __updateDropdown: (cdata, data, layout, opts) ->
      extendedInfo_xhr = { "xhr" : undefined }
      that = @
      fields = []
      select = {
          type: CUI.Select
          undo_and_changed_support: false
          empty_text: $$('custom.data.type.dante.modal.form.dropdown.loadingentries')
          # read select-items from dante-api
          options: (thisSelect) =>
                dfr = new CUI.Deferred()
                values = []

                # cache on?
                cache = '&cache=0'
                if @getCustomMaskSettings()?.use_cache?.value
                    cache = '&cache=1'

                # if multible vocabularys are given, show only the first one in dropdown
                vocTest = @getVocabularyNameFromDatamodel(opts)
                vocTest = vocTest.split('|')
                if(vocTest.length > 1)
                  voc = vocTest[0]
                else
                  voc = @getVocabularyNameFromDatamodel(opts)

                # start new request
                searchsuggest_xhr = new (CUI.XHR)(url: location.protocol + '//api.dante.gbv.de/suggest?search=&voc=' + voc + '&language=' + @getFrontendLanguage() + '&limit=1000' + cache)
                searchsuggest_xhr.start().done((data, status, statusText) ->
                    # read options for select
                    select_items = []
                    item = (
                      text: $$('custom.data.type.dante.modal.form.dropdown.choose')
                      value: null
                    )

                    select_items.push item

                    for suggestion, key in data[1]
                      do(key) ->
                        item = (
                          text: suggestion
                          value: data[3][key]
                        )
                        # only show tooltip, if configures in datamodel
                        if that.getCustomMaskSettings()?.use_dropdown_info_popup?.value
                          item.tooltip =
                            markdown: true
                            placement: 'nw'
                            content: (tooltip) ->
                              # get jskos-details-data
                              that.__getAdditionalTooltipInfo(data[3][key], tooltip, extendedInfo_xhr)
                              # loader, until details are xhred
                              new CUI.Label(icon: "spinner", text: $$('custom.data.type.dante.modal.form.popup.loadingstring'))

                        select_items.push item

                    # if cdata is already set, choose correspondending option from select
                    if cdata?.conceptURI != ''
                        # is this a dante-uri or another "world"-uri?
                        if cdata.conceptURI?.indexOf('uri.gbv.de/terminology') > 0
                          # uuid of already saved entry
                          givenUUID = cdata?.conceptURI.split('/')
                          givenUUID = givenUUID.pop()
                          for givenOpt in select_items
                            if givenOpt.value != null
                              testUUID = givenOpt.value.split('/')
                              testUUID = testUUID.pop()
                              if testUUID == givenUUID
                                thisSelect.setValue(givenOpt.value)
                                thisSelect.setText(givenOpt.text)
                        else
                          for givenOpt in select_items
                            if givenOpt.value != null
                              if givenOpt.value == cdata?.conceptURI
                                thisSelect.setValue(givenOpt.value)
                                thisSelect.setText(givenOpt.text)
                    thisSelect.enable()
                    dfr.resolve(select_items)
                )
                dfr.promise()

          name: 'dante_InlineSelect'
      }

      fields.push select
      if cdata == null || cdata?.length == 0
        cdata = {}

      cdata_form = new CUI.Form
              data: cdata
              # dropdown changed!?
              onDataChanged: (elemData, element) =>
                    cdata.conceptURI = element.getValue()
                    element.displayValue()
                    cdata.conceptName = element.getText()
                    cdata.conceptAncestors = null
                    cdata._fulltext = null
                    cdata._standard = null
                    cdata.facetTerm = null

                    # preset cdata
                    if cdata.conceptURI == null
                      cdata = {}
                    data[that.name(opts)] = cdata
                    data.lastsaved = Date.now()

                    if cdata?.conceptURI && cdata?.conceptURI != null
                      # download data from dante for fulltext
                      fulltext_xhr = new (CUI.XHR)(url: location.protocol + '//api.dante.gbv.de/data?uri=' + encodeURIComponent(cdata.conceptURI) + '&cache=1&properties=+ancestors,hiddenLabel,notation,scopeNote,definition,note,identifier,example,location,depiction,startDate,endDate,startPlace,endPlace')
                      fulltext_xhr.start().done((detail_data, status, statusText) ->
                          cdata._fulltext = DANTEUtil.getFullTextFromJSKOSObject detail_data, that.getDatabaseLanguages()
                          cdata._standard= DANTEUtil.getStandardFromJSKOSObject detail_data, that.getDatabaseLanguages(), false
                          cdata.facetTerm = DANTEUtil.getFacetTermFromJSKOSObject detail_data, that.getDatabaseLanguages(), false                          
                          cdata.conceptGeoJSON = DANTEUtil.getGeoJSONFromDANTEJSKOS detail_data
                          if ! cdata?.conceptURI
                            cdata = {}
                          data[that.name(opts)] = cdata
                          data.lastsaved = Date.now()
                          
                          CUI.Events.trigger
                              node: cdata_form # vorher "element"
                              type: "editor-changed"
                          #CUI.Events.trigger
                          #    node: cdata_form # vorher "element"
                          #    type: "data-changed"
                      )
                    else
                      data[that.name(opts)] = cdata
                      data.lastsaved = Date.now()
                      CUI.Events.trigger
                          node: cdata_form
                          type: "editor-changed"
                      #CUI.Events.trigger
                      #    node: cdata_form # vorher "element"
                      #    type: "data-changed" # vorher "element"
              fields: fields

      # if called from poolmanagerplugin via DataFieldProxys don't call CUI.Form.start(),
      #   because DataFieldProxy also starts the form and double-render-attempt throws error
      if ! opts?.callfrompoolmanager
        cdata_form.start()
      layout.replace(cdata_form, 'center')
      # prevent loop, if deleted from other plugin
      if ! opts?.deleteDataFromPlugin
        that.__setEditorFieldStatus(cdata, layout)


  #######################################################################
  # render form as DROPDOWN
  __renderEditorInputInline: (data, cdata, opts = {}) ->
      that = @
      layout
      # build layout for editor and put the select in the content
      layout = new CUI.HorizontalLayout
          class: 'customPluginEditorLayout dropdown'
          left:
            content: ''
          center:
            content: ''
          right:
            content: ''

      that.__updateDropdown(cdata, data, layout, opts)

      # other plugins can trigger layout-rebuild by deletion of data-value
      CUI.Events.registerEvent
        type: "custom-deleteDataFromPlugin"
        bubble: false

      CUI.Events.listen
        type: "custom-deleteDataFromPlugin"
        instance: that
        node: layout
        call: =>
          cdata = null
          data[that.name()] = cdata
          opts.deleteDataFromPlugin = true
          # update field
          that.__updateDropdown(cdata, data, layout, opts)

      layout

  #######################################################################
  # show tooltip with loader and then additional info (for extended mode)
  __getAdditionalTooltipInfo: (uri, tooltip, extendedInfo_xhr, context = null) ->
    that = @

    if context
      that = context

    # abort eventually running request
    if extendedInfo_xhr.xhr != undefined
      extendedInfo_xhr.xhr.abort()

    if that.getCustomMaskSettings()?.mapbox_access_token?.value
      mapbox_access_token = that.getCustomMaskSettings().mapbox_access_token.value
    # start new request to DANTE-API
    extendedInfo_xhr.xhr = new (CUI.XHR)(url: location.protocol + '//api.dante.gbv.de/data?uri=' + uri + '&format=json&properties=+ancestors,hiddenLabel,notation,scopeNote,definition,note,identifier,example,location,depiction,startDate,endDate,startPlace,endPlace,qualifiedRelations&cache=1')
    extendedInfo_xhr.xhr.start()
    .done((data, status, statusText) ->
      htmlContent = that.getJSKOSPreview(data, mapbox_access_token)
      tooltip.DOM.innerHTML = htmlContent
      tooltip.autoSize()
    )

    return

  #######################################################################
  # build treeview-Layout with treeview
  buildAndSetTreeviewLayout: (popover, layout, cdata, cdata_form, that, returnDfr = false, opts) ->
    # is this a call from expert-search? --> save in opts..
    if @?.callFromExpertSearch
      opts.callFromExpertSearch = @.callFromExpertSearch
    else
      opts.callFromExpertSearch = false

    # get vocparameter from dropdown, if available...
    popoverVocabularySelectTest = cdata_form.getFieldsByName("dante_PopoverVocabularySelect")[0]
    if popoverVocabularySelectTest?.getValue()
      vocParameter = popoverVocabularySelectTest?.getValue()
    else
      # else get first voc from given voclist (1-n)
      vocParameter = that.getActiveVocabularyName(cdata, opts)
      vocParameter = vocParameter.replace /,/g, "|"
      vocParameter = vocParameter.split('|')
      vocParameter = vocParameter[0]

    treeview = new DANTE_ListViewTree(popover, layout, cdata, cdata_form, that, opts, vocParameter)

    # maybe deferred is wanted?
    if returnDfr == false
      treeview.getTopTreeView(vocParameter, 1)
    else
      treeviewDfr = treeview.getTopTreeView(vocParameter, 1)


    treeviewPane = new CUI.Pane
        class: "cui-pane dante_treeviewPane"
        top:
            content: [
                new CUI.PaneHeader
                    left:
                        content:
                            new CUI.Label(text: $$('custom.data.type.dante.modal.form.popup.choose'))
                    right:
                        content:
                            new CUI.EmptyLabel
                              text: that.getVocabularyNameFromDatamodel(opts)
            ]
        center:
            content: [
                treeview.treeview
              ,
                cdata_form
            ]

    @popover.setContent(treeviewPane)

    # maybe deferred is wanted?
    if returnDfr == false
      return treeview
    else
      return treeviewDfr

  ######################################################################
  # update result (with paginator) in popup (not treeview)
  __updateResultMenu: (cdata, cdata_form, dante_searchstring, input, offset, resultPane, resultPaneHeader, search_xhr, layout, opts) ->

    that = @
    resultItemsList = []
    
    # clear existing results    
    resultPane.hide()     
    
    # fire search via dante-api
    delayMillisseconds = 50
    setTimeout ( ->

        dante_searchstring = dante_searchstring.replace /^\s+|\s+$/g, ""
        if dante_searchstring.length == 0
            # refresh popup, because its content has changed (new height etc)
            CUI.Events.trigger
              node: that.popover
              type: "content-resize"
            # leave
            return

        resultPane.show()

        # limit-Parameter
        dante_countSuggestions = 12

        # run autocomplete-search via xhr
        if search_xhr.xhr != undefined
            # abort eventually running request
            search_xhr.xhr.abort()

        # cache?
        cache = '&cache=0'
        if that.getCustomMaskSettings().use_cache?.value
            cache = '&cache=1'

        # voc parameter
        vocParameter = that.getActiveVocabularyName(cdata, opts)
        # voc parameter if called from poolmanagerplugin
        if opts?.callfrompoolmanager
          vocParameter = that.getVocabularyNameFromDatamodel(opts)

        # build property-parameter
        labelWithHierarchie = false;
        queryProperties = '+hiddenLabel,notation,scopeNote,definition,identifier,example,location,depiction,startDate,endDate,startPlace,endPlace'
        if that.getCustomMaskSettings().label_with_hierarchie?.value && opts?.mode == 'editor'
          labelWithHierarchie = true
          queryProperties += ',ancestors'

        # start request
        search_xhr.xhr = new (CUI.XHR)(url: location.protocol + '//api.dante.gbv.de/search?query=' + dante_searchstring + '&properties=' + queryProperties + '&voc=' + vocParameter + '&language=' + that.getFrontendLanguage() + '&limit=' + dante_countSuggestions + cache + '&offset=' + offset)
        search_xhr.xhr.start().done((data, status, statusText) ->
        
            resultPane.removeClass('dante-popover-results-paginator-loading')

            # set hits to "count"-label
            hits = search_xhr.xhr.getResponseHeader('x-total-count')
            resultPaneLabel = document.getElementsByClassName('results-display-pane-count-label')[0]
            if resultPaneLabel?
              cuiLabelContent = resultPaneLabel.getElementsByClassName('cui-label-content')[0]
              if cuiLabelContent?
                cuiLabelContent.innerHTML = $$('custom.data.type.dante.modal.form.popup.paging.label.count') + ' ' + hits

            # build paginator
            pagesCount = Math.ceil(hits / dante_countSuggestions)
            pageButtons = []

            currentPage = Math.floor(offset / dante_countSuggestions) + 1

            if hits > 0
              for page in [1..pagesCount]
                # Always show the first 2 pages, the last 2 pages, and pages around the current page
                if page <= 3 or page >= pagesCount - 1 or (page >= currentPage - 1 and page <= currentPage + 1)
                  active = false
                  activeClass = ''
                  if currentPage == page
                    active = true
                    activeClass = 'active-page'
                  
                  pageButton = new CUI.Button
                                        class: "dante-popover-paginator-button " + activeClass
                                        text: page.toString()
                                        value: page
                                        onClick: (evt,button) =>
                                          if ! button.hasClass('active-page')
                                            offset = (button.opts.value-1) * dante_countSuggestions
                                            # clear resultarea and show loader
                                            resultPane.addClass('dante-popover-results-paginator-loading')
                                            loader = new CUI.Label(icon: "spinner", text: $$('custom.data.type.dante.modal.form.popup.loadingstring'))
                                            resultPane.replace(loader, 'center')
                                            that.__updateResultMenu(cdata, cdata_form, dante_searchstring, input, offset, resultPane, resultPaneHeader, search_xhr, layout, opts)
                                            return
                  pageButtons.push pageButton

                else if page == pagesCount - 3 and page != 0
                  # Add ellipsis (...) for skipped pages
                  ellipsisButton = new CUI.Button
                                        class: "dante-popover-paginator-button ellipsis"
                                        text: "..."
                  pageButtons.push ellipsisButton
              # add paginator
              resultPaneHeader.replace(pageButtons, 'left')
            else 
              # remove existing paginator
              resultPaneHeader.replace('', 'left')

            # create result-items
            resultItemsList = []
            extendedInfo_xhr = { "xhr" : undefined }

            # show voc-headlines in selectmenu? default: no headlines
            showHeadlines = false;

            # are there multible vocs in datamodel?
            multibleVocs = false
            vocTest = that.getVocabularyNameFromDatamodel(opts)
            vocTest = vocTest.replace(/,/g, "|")
            vocTestArr = vocTest.split('|')
            if vocTestArr.length > 1
              multibleVocs = true

            # conditions for headings in results
            showHeadlines = false
            # B.1. If several vocabularies
            if multibleVocs == true
              # B.1.1 If vocabulary selected from dropdown, then no subheadings
              if cdata?.dante_PopoverVocabularySelect != '' && cdata?.dante_PopoverVocabularySelect != vocTest
                showHeadlines = false
              else
              # B.2.2 If "All vocabularies" in dropdown, then necessarily and always subheadings
              if cdata?.dante_PopoverVocabularySelect == vocTest || (cdata?.dante_PopoverVocabularySelect.replace(/,/g, '|') == vocTest)
                showHeadlines = true

            # the actual vocab (if multible, add headline + divider)
            actualVocab = ''

            # sort by voc/uri-part in tmp-array
            tmp_items = []
            for suggestion, key in data
              vocab = 'default'
              
              if showHeadlines
                vocab = suggestion.inScheme[0].notation
              if ! Array.isArray tmp_items[vocab]
                tmp_items[vocab] = []
              do(suggestion) ->
                # get prefLabel
                prefLabel = DANTEUtil.getConceptNameFromJSKOSObject(suggestion, that.getFrontendLanguage(), labelWithHierarchie)
                # default item
                item =
                  text: prefLabel
                  value: suggestion.uri
                  vocabName: suggestion.inScheme[0].prefLabel['de']
                  tooltip:
                    markdown: true
                    placement: "wn"
                    content: (tooltip) ->
                      # show infopopup
                      encodedURI = encodeURIComponent(suggestion.uri)
                      that.__getAdditionalTooltipInfo(encodedURI, tooltip, extendedInfo_xhr)
                      new CUI.Label(icon: "spinner", text: $$('custom.data.type.dante.modal.form.popup.loadingstring'))
                tmp_items[vocab].push item
                           
            # create result and add divider if needed
            actualVocab = ''
            for vocab, part of tmp_items
              if showHeadlines
                # add divider
                if ((actualVocab == '' || actualVocab != vocab) && vocab != 'default')
                  actualVocab = vocab
                  # add result-button
                  vocabDivider = new CUI.Pane
                                    class: "dante-plugin-popover-result-row-pane"
                                    center:
                                        content: [
                                              new CUI.Label
                                                  class: "dante-plugin-popover-result-menu-divider-label"
                                                  text: part[0].vocabName
                                                  icon: new CUI.Icon(class: "fa-tags")
                                        ]
                  resultItemsList.push(vocabDivider)
              for suggestion,key2 in part
                # add result-button
                resultButton = new CUI.Pane
                                  class: "dante-plugin-popover-result-row-pane"
                                  center:
                                      content: [
                                            new CUI.Button
                                                class: "dante-plugin-popover-result-menu-button"
                                                text: suggestion.text
                                                value: suggestion.value
                                                appearance: "flat"
                                                icon_left: new CUI.Icon(class: "fa-plus")
                                                tooltip: suggestion.tooltip
                                                onClick: (evt, button) ->
                                                    # clear resultarea and show loader
                                                    resultPane.addClass('dante-popover-results-paginator-loading')
                                                    loader = new CUI.Label(icon: "spinner", text: $$('custom.data.type.dante.modal.form.popup.loadingstring'))
                                                    resultPane.replace(loader, 'center')
                                                    # hide pagination
                                                    resultPaneHeader.replace('', 'left')
                                                    # save data
                                                    DANTEUtil.getDetailAboutRecordViaAPI(that, button.getValue(), cache, opts, cdata, layout, layout)
                                      ]
                resultItemsList.push(resultButton)
            setTimeout ( -> 
              CUI.Events.trigger
                node: that.popover
                type: "content-resize"
            ), 100

            resultPane.replace(resultItemsList, 'center')
        )
    )
    return
    
  #######################################################################
  # show popover and fill it with the form-elements
  showEditPopover: (btn, data, cdata, layout, opts) ->
    that = @

    # if "reset"-button is pressed, dont use cache for this popup
    that.resettedPopup = false;

    suggest_Menu
    resultPane
    resultPaneHeader
    cdata_form
    offset = 0 # offset if result with paginator

    # init popover
    @popover = new CUI.Popover
      element: btn
      placement: "wn"
      class: "commonPlugin_Popover"
      onHide: =>
        # reset voc-dropdown
        delete cdata.dante_PopoverVocabularySelect
        vocDropdown = cdata_form.getFieldsByName("dante_PopoverVocabularySelect")[0]
        if vocDropdown
          vocDropdown.reload()
        # reset searchbar
        searchbar = cdata_form.getFieldsByName("searchbarInput")[0]
        if searchbar
          searchbar.reset()
          searchbar.setValue('')
        offset = 0

    # init xhr-objects to abort running xhrs
    searchsuggest_xhr = { "xhr" : undefined } # still needed in treeview
    search_xhr = { "xhr" : undefined }
    cdata_form = new CUI.Form
      class: "danteFormWithPadding"
      data: cdata
      fields: that.__getEditorFields(cdata, opts)
      onDataChanged: (data, elem) =>
        that.__updateResult(cdata, layout, opts)
        # update tree, if voc changed
        if elem.opts.name == 'dante_PopoverVocabularySelect' && that.renderPopupAsTreeview(opts)
          @buildAndSetTreeviewLayout(@popover, layout, cdata, cdata_form, that, false, opts)
        that.__setEditorFieldStatus(cdata, layout)
        if elem.opts.name == 'searchbarInput' || elem.opts.name == 'dante_PopoverVocabularySelect'
          #that.__updateSuggestionsMenu(cdata, cdata_form, data.searchbarInput, elem, suggest_Menu, searchsuggest_xhr, layout, opts)
          that.__updateResultMenu(cdata, cdata_form, data.searchbarInput, elem, offset, resultPane, resultPaneHeader, search_xhr, layout, opts)
    .start()

    # init suggestmenu
    suggest_Menu = new CUI.Menu
        element : cdata_form.getFieldsByName("searchbarInput")[0]
        use_element_width_as_min_width: true

    # result pane (normal popup with pagination)
    resultPaneHeader =  new CUI.PaneHeader
                          class: 'resultsDisplayPaneHeader'
                          left:
                              content:
                                  new CUI.Label
                                    class: "results-display-pane-page-label"
                                    text: $$('custom.data.type.dante.modal.form.popup.paging.label.page')
                          right:
                              content:
                                  new CUI.EmptyLabel
                                    class: "results-display-pane-count-label"
                                    text: ' '

    resultPane = new CUI.Pane
          class: "cui-pane resultsDisplayPane"
          top:
              content: [
                  resultPaneHeader
              ]
          center:
             content: []
    resultPane.hide()
        
    # treeview?
    if that.renderPopupAsTreeview(opts)
      # do search-request for all the top-entrys of vocabulary
      @buildAndSetTreeviewLayout(@popover, layout, cdata, cdata_form, that, false, opts)

      # cache on?
      cache = 0
      if @getCustomMaskSettings().use_cache?.value
          cache = 1

      # append button after autocomplete-input
      searchButton =  new CUI.Button
                      text: $$('custom.data.type.dante.modal.form.popup.treeviewsearch')
                      icon_left: new CUI.Icon(class: "fa-search")
                      class: 'dantePlugin_SearchButton'
                      onClick: (evt,button) =>
                        # hide suggest-menü
                        suggest_Menu.hide()
                        # attach info to cdata_form
                        searchTerm = cdata_form.getFieldsByName("searchbarInput")[0].getValue()
                        if searchTerm.length > 2
                          # disable search + reset-buttons
                          searchButton.setEnabled(false)
                          resetButton.setEnabled(false)

                          button.setIcon(new CUI.Icon(class: "fa-spinner fa-spin"))

                          newTreeview = @buildAndSetTreeviewLayout(@popover, layout, cdata, cdata_form, that, false, opts)
                          vocParameter = that.getActiveVocabularyName(cdata, opts)
                          newTreeview.getSearchResultTree(searchTerm, vocParameter, cache)
                          .done =>
                            # enable search + reset-buttons
                            searchButton.setEnabled(true)
                            resetButton.setEnabled(true)

                            button.setIcon(new CUI.Icon(class: "fa-search"))

                            that.popover.position()

                            setTimeout ( ->
                              # refresh popup, because its content has changed (new height etc)
                              CUI.Events.trigger
                                node: that.popover
                                type: "content-resize"
                            ), 100

                          @
      # append "search"-Button
      cdata_form.getFieldsByName("searchbarInput")[0].append(searchButton)

      # append button after autocomplete-input
      resetButton =  new CUI.Button
                      text: $$('custom.data.type.dante.modal.form.popup.treeviewreset')
                      icon_left: new CUI.Icon(class: "fa-undo")
                      class: 'dantePlugin_ResetButton'
                      onClick: (evt,button) =>
                        that.resettedPopup = true

                        # clear searchbar
                        cdata_form.getFieldsByName("searchbarInput")[0].setValue('').displayValue()

                        # disable search + reset-buttons
                        searchButton.setEnabled(false)
                        resetButton.setEnabled(false)

                        button.setIcon(new CUI.Icon(class: "fa-spinner fa-spin"))

                        # attach info to cdata_form
                        newTreeviewDfr = @buildAndSetTreeviewLayout(@popover, layout, cdata, cdata_form, that, true, opts)

                        # if reset complete
                        newTreeviewDfr.done =>
                          # enable search + reset-buttons
                          searchButton.setEnabled(true)
                          resetButton.setEnabled(true)
                          button.setIcon(new CUI.Icon(class: "fa-undo"))

      # append "reset"-Button
      cdata_form.getFieldsByName("searchbarInput")[0].append(resetButton)
    # else not treeview, but default search-popup
    else
      defaultPane = new CUI.Pane
          class: "cui-pane"
          top:
              content: [
                  new CUI.PaneHeader
                      left:
                          content:
                              new CUI.Label(text: $$('custom.data.type.dante.modal.form.popup.choose'))
                      right:
                          content:
                              new CUI.EmptyLabel
                                text: that.getVocabularyNameFromDatamodel(opts)
              ]
          center:
              content: [
                  cdata_form,
                  resultPane
              ]

      @popover.setContent(defaultPane)

    @popover.show()

  #######################################################################
  # create form (POPOVER)
  #######################################################################
  __getEditorFields: (cdata, opts) ->
    that = @
    fields = []
    # dropdown for vocabulary-selection if more then 1 voc
    vocTest = that.getVocabularyNameFromDatamodel(opts)
    vocTest = vocTest.replace(/,/g, "|");
    vocTestArr = vocTest.split('|')
    if vocTestArr.length > 1 or vocTest == '*'
      select =  {
          type: CUI.Select
          undo_and_changed_support: false
          name: 'dante_PopoverVocabularySelect'
          form:
            label: $$("custom.data.type.dante.modal.form.dropdown.selectvocabularyLabel")
          # read select-items from dante-api
          options: (thisSelect) =>
            dfr = new CUI.Deferred()
            values = []

            # search for the wanted vocs or all vocs
            notationStr = '&notation=' + that.getVocabularyNameFromDatamodel(opts)
            if that.getVocabularyNameFromDatamodel(opts) == '*'
              notationStr = '';
            # start new request
            searchsuggest_xhr = new (CUI.XHR)(url: location.protocol + '//api.dante.gbv.de/voc?cache=1' + notationStr)
            searchsuggest_xhr.start().done((data, status, statusText) ->
                # read options for select
                select_items = []
                # allow to choose all vocs only, if not treeview
                if ! that.renderPopupAsTreeview(opts)
                  item = (
                    text: $$('custom.data.type.dante.modal.form.dropdown.choosefromvocall')
                    value: that.getVocabularyNameFromDatamodel(opts)
                  )
                  select_items.push item
                # add vocs to select, keep sorting from parameter
                for vocEntry, vocKey in vocTestArr
                    for entry, key in data
                        if vocEntry == entry.notation[0]
                            item = (
                              text: entry.prefLabel.de
                              value: entry.notation[0]
                            )
                            select_items.push item
                thisSelect.enable()
                dfr.resolve(select_items)
            )
            dfr.promise()
      }
      fields.push select

    # searchfield (autocomplete)
    option =  {
          type: CUI.Input
          class: "commonPlugin_Input"
          undo_and_changed_support: false
          form:
              label: $$("custom.data.type.dante.modal.form.text.searchbar")
          placeholder: $$("custom.data.type.dante.modal.form.text.searchbar.placeholder")
          name: "searchbarInput"
        }
    fields.push option

    fields


  #######################################################################
  # renders the "resultmask" (outside popover)
  __renderButtonByData: (cdata) ->
    that = @
    # when status is empty or invalid --> message

    switch @getDataStatus(cdata)
      when "empty"
        return new CUI.EmptyLabel(text: $$("custom.data.type.dante.edit.no_dante")).DOM
      when "invalid"
        return new CUI.EmptyLabel(text: $$("custom.data.type.dante.edit.no_valid_dante")).DOM

    extendedInfo_xhr = { "xhr" : undefined }

    # output Button with Name of picked dante-Entry and URI
    encodedURI = encodeURIComponent(cdata.conceptURI)
    new CUI.HorizontalLayout
      maximize: true
      left:
        content:
          new CUI.Label
            centered: false
            text: cdata.conceptName
      center:
        content:
          new CUI.ButtonHref
            name: "outputButtonHref"
            class: "pluginResultButton"
            appearance: "link"
            size: "normal"
            href: 'https://uri.gbv.de/terminology/?uri=' + encodedURI
            target: "_blank"
            class: "cdt_dante_smallMarginTop"
            tooltip:
              markdown: true
              placement: 'nw'
              content: (tooltip) ->
                # get jskos-details-data
                that.__getAdditionalTooltipInfo(encodedURI, tooltip, extendedInfo_xhr)
                # loader, until details are xhred
                new CUI.Label(icon: "spinner", text: $$('custom.data.type.dante.modal.form.popup.loadingstring'))
      right: null

    new CUI.Buttonbar
      class: 'dante-render-button-buttonbar'
      buttons: [
          new CUI.Label
            centered: false
            text: cdata.conceptName

          new CUI.ButtonHref
            name: "outputButtonHref"
            class: "pluginResultButton"
            appearance: "link"
            size: "normal"
            href: 'https://uri.gbv.de/terminology/?uri=' + encodedURI
            target: "_blank"
            class: "cdt_dante_smallMarginTop"
            tooltip:
              markdown: true
              placement: 'nw'
              content: (tooltip) ->
                # get jskos-details-data
                that.__getAdditionalTooltipInfo(encodedURI, tooltip, extendedInfo_xhr)
                # loader, until details are xhred
                new CUI.Label(icon: "spinner", text: $$('custom.data.type.dante.modal.form.popup.loadingstring'))
      ]
    .DOM

  #######################################################################
  # zeige die gewählten Optionen im Datenmodell unter dem Button an
  getCustomDataOptionsInDatamodelInfo: (custom_settings) ->
    tags = []

    if custom_settings.vocabulary_name?.value
      tags.push $$("custom.data.type.dante.name") + ': ' + custom_settings.vocabulary_name.value
    else
      tags.push $$("custom.data.type.dante.setting.schema.no_choosen_vocabulary")

    if custom_settings.insert_allowed?.value
      tags.push $$("custom.data.type.commons.controls.addnew.label") + ' ✓'
    else
      tags.push $$("custom.data.type.commons.controls.addnew.label") + ' ✗'
    tags


CustomDataType.register(CustomDataTypeDANTE)
