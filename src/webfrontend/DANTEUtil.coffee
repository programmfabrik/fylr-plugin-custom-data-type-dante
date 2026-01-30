# dante-api-endpoint
danteAPIPath = 'https://api.dante.gbv.de/'

# build _standard and _fulltext, facetTerm according to
#   https://docs.easydb.de/en/technical/plugins/customdatatype/#general-keys

class DANTEUtil

  # from https://github.com/programmfabrik/coffeescript-ui/blob/fde25089327791d9aca540567bfa511e64958611/src/base/util.coffee#L506
  # has to be reused here, because cui not be used in updater
  @isEqual: (x, y, debug) ->
    #// if both are function
    if x instanceof Function
      if y instanceof Function
        return x.toString() == y.toString()
      return false

    if x == null or x == undefined or y == null or y == undefined
      return x == y

    if x == y or x.valueOf() == y.valueOf()
      return true

    # if one of them is date, they must had equal valueOf
    if x instanceof Date
      return false

    if y instanceof Date
      return false

    # if they are not function or strictly equal, they both need to be Objects
    if not (x instanceof Object)
      return false

    if not (y instanceof Object)
      return false

    p = Object.keys(x)
    if Object.keys(y).every( (i) -> return p.indexOf(i) != -1 )
      return p.every((i) =>
        eq = @isEqual(x[i], y[i], debug)
        if not eq
          if debug
            console.debug("X: ",x)
            console.debug("Differs to Y:", y)
            console.debug("Key differs: ", i)
            console.debug("Value X:", x[i])
            console.debug("Value Y:", y[i])
          return false
        else
          return true
      )
    else
      return false


  @getDetailAboutRecordViaAPI: (that, uri, cache, opts, cdata, layout, anchorForLabelChoosePopup) ->
    # get full record to get correct preflabel in desired language
    detailAPIPath = danteAPIPath + 'data?uri=' + uri + cache + '&properties=+hiddenLabel,notation,scopeNote,definition,identifier,example,location,startDate,endDate,startPlace,endPlace,ancestors'
    # start suggest-XHR
    dataEntry_xhr = new (CUI.XHR)(url: detailAPIPath)
    dataEntry_xhr.start().done((data_detail, status, statusText) ->
      resultJSKOS = data_detail[0]
      if cdata == null
        cdata = {}

      if resultJSKOS.uri
        labelWithHierarchie = false;
        if that.getCustomMaskSettings().label_with_hierarchie?.value && opts?.mode == 'editor'
          labelWithHierarchie = true
          
        cdata.conceptNameWithHierarchie = labelWithHierarchie
          
        # lock conceptURI in savedata
        cdata.conceptURI = resultJSKOS.uri
        # lock _fulltext in savedata
        cdata._fulltext = DANTEUtil.getFullTextFromJSKOSObject resultJSKOS, that.getDatabaseLanguages()
        # lock _standard in savedata
        cdata._standard = DANTEUtil.getStandardFromJSKOSObject resultJSKOS, that.getDatabaseLanguages(), labelWithHierarchie
        # lock facetTerm in savedata
        cdata.facetTerm = DANTEUtil.getFacetTermFromJSKOSObject resultJSKOS, that.getDatabaseLanguages(), labelWithHierarchie
        # lock conceptAncestors
        cdata.conceptAncestors = DANTEUtil.getConceptAncestorsFromJSKOS resultJSKOS
        # lock geojson
        cdata.conceptGeoJSON = DANTEUtil.getGeoJSONFromDANTEJSKOS resultJSKOS

        # is user allowed to choose label manually from list and not in expert-search?!
        if that.getCustomMaskSettings().allow_label_choice?.value && opts?.mode == 'editor'
          that.__chooseLabelManually(cdata, layout, resultJSKOS, anchorForLabelChoosePopup, opts, labelWithHierarchie)
        # user is not allowed to choose-label manually --> get prefLabel in default language
        else
          cdata.conceptName = DANTEUtil.getConceptNameFromJSKOSObject resultJSKOS, that.getFrontendLanguage(), labelWithHierarchie

          if opts?.data
              opts.data[that.name(opts)] = CUI.util.copyObject(cdata)
          
          if opts?.callfrompoolmanager
            if opts.data
              cdata = CUI.util.copyObject(cdata)

              if opts?.datafieldproxy
                CUI.Events.trigger
                    node: opts.datafieldproxy
                    type: "editor-changed"
                CUI.Events.trigger
                    node: opts.datafieldproxy
                    type: "data-changed"
          else
            CUI.Events.trigger
                node: layout
                type: "editor-changed"
            CUI.Events.trigger
                node: layout
                type: "data-changed"

          # update the layout in form
          that.__updateResult(cdata, layout, opts)
          # close popover
          if that.popover
            that.popover.hide()
          @
    )


  @getConceptAncestorsFromJSKOS: (jskos) ->
      conceptAncestors = []
      if jskos.ancestors.length > 0
        # collect ancestor-uris
        for ancestor in jskos.ancestors
          conceptAncestors.push ancestor.uri
      # add own uri to ancestor-uris
      conceptAncestors.push jskos.uri
      # merge ancestores to string
      conceptAncestors = conceptAncestors.join(' ')
      return conceptAncestors
    

  @getHierarchieLabel: (jskos, desiredLanguage) ->
     hierarchieLabelGenerated = ''
     if typeof $$ != "undefined"
        prefLabelFallback = $$("custom.data.type.dante.modal.form.popup.treeview.nopreflabel")
      else
        prefLabelFallback = 'kein Label gefunden'

      if ! jskos['prefLabel'] || ! jskos['ancestors']
        return prefLabelFallback
        
      # collect all the preflabels of record and ancestors
      givenHierarchieLabels = []
      givenHierarchieLabels = givenHierarchieLabels.concat(jskos['ancestors'].map((x) => x.prefLabel))
      #revers 
      givenHierarchieLabels = givenHierarchieLabels.reverse()
      givenHierarchieLabels.push jskos['prefLabel']
        
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

          # if no conceptName is given yet (f.e. via scripted imports..)
          if ! hierarchieLevelLabel
            if value['de']
              hierarchieLevelLabel = value['de']
            else if value['en']
              hierarchieLevelLabel = value['en']
            else
              hierarchieLevelLabel = value[Object.keys(value)[0]]
          hierarchieParts.push hierarchieLevelLabel
            
      hierarchieLabelGenerated = hierarchieParts.join(' ➔ ')

      if ! hierarchieLabelGenerated
        if jskos.altLabel
          hierarchieLabelGenerated = jskos.altLabel[Object.keys(jskos.altLabel)[0]][0]
        else if jskos.hiddenLabel
          hierarchieLabelGenerated = jskos.hiddenLabel[Object.keys(jskos.hiddenLabel)[0]][0]
        else 
          hierarchieLabelGenerated = $$("custom.data.type.dante.modal.form.popup.treeview.nopreflabel")

      hierarchieLabelGenerated

    
  @getConceptNameFromJSKOSObject: (jskos, desiredLanguage, labelWithHierarchie = false) ->
      prefLabel = '';

      if labelWithHierarchie
        prefLabel = @.getHierarchieLabel(jskos, desiredLanguage)
      else
          if typeof $$ != "undefined"
            prefLabelFallback = $$("custom.data.type.dante.modal.form.popup.treeview.nopreflabel")
          else
            prefLabelFallback = 'kein Label gefunden'
          if ! jskos['prefLabel']
            return prefLabelFallback

          if desiredLanguage.length == 2
            # if a preflabel exists in given frontendLanguage or without language (person / corporate)
            if jskos['prefLabel'][desiredLanguage] || jskos['prefLabel']['zxx'] || jskos['prefLabel']['und'] || jskos['prefLabel']['mus'] || jskos['prefLabel']['mil']
              if jskos['prefLabel']?[desiredLanguage]
                prefLabel = jskos['prefLabel'][desiredLanguage]
              else if jskos['prefLabel']['zxx']
                prefLabel = jskos['prefLabel']['zxx']
              else if jskos['prefLabel']['und']
                prefLabel = jskos['prefLabel']['und']
              else if jskos['prefLabel']['mis']
                prefLabel = jskos['prefLabel']['mis']
              else if jskos['prefLabel']['mul']
                prefLabel = jskos['prefLabel']['mul']

          # if no conceptName is given yet (f.e. via scripted imports..)
          if ! prefLabel
            if jskos.prefLabel?.de
              prefLabel = jskos.prefLabel.de
            else if jskos.prefLabel?.en
              prefLabel = jskos.prefLabel.en
            else
              prefLabel = jskos.prefLabel[Object.keys(jskos.prefLabel)[0]]
              # Fallback if no preflabel exists
              if ! prefLabel && jskos.altLabel
                prefLabel = jskos.altLabel[Object.keys(jskos.altLabel)[0]][0]
              if ! prefLabel && jskos.hiddenLabel
                prefLabel = jskos.hiddenLabel[Object.keys(jskos.hiddenLabel)[0]][0]
              if ! prefLabel
                prefLabel = prefLabelFallback

      prefLabel



  @getFullTextFromJSKOSObject: (object, databaseLanguages = false) ->

    shortenedDatabaseLanguages = databaseLanguages.map((value, key, array) ->
      value.split('-').shift()
    )

    if Array.isArray(object)
      object = object[0]

    _fulltext = {}
    fullTextString = ''
    l10nObject = {}
    l10nObjectWithShortenedLanguages = {}

    # init l10nObject for fulltext
    for language in databaseLanguages
      l10nObject[language] = ''

    for language in shortenedDatabaseLanguages
      l10nObjectWithShortenedLanguages[language] = ''

    objectKeys = [
      'prefLabel'
      'altLabel'
      'hiddenLabel'
      'identifier'
      'notation'
      'uri'
      'scopeNote'
      'definition'
      'startDate'
      'endDate'
      'example'
      'historyNote'
      'note'
      'changeNote'
      'startPlace'
      'endPlace',
      'ancestors'
    ]

    # parse all object-keys and add all values to fulltext
    for key, value of object
      if objectKeys.includes(key)
        propertyType = typeof value

        # string
        if propertyType == 'string'
          fullTextString += value + ' '
          # add to each language in l10n
          for l10nObjectWithShortenedLanguagesKey, l10nObjectWithShortenedLanguagesValue of l10nObjectWithShortenedLanguages
            l10nObjectWithShortenedLanguages[l10nObjectWithShortenedLanguagesKey] = l10nObjectWithShortenedLanguagesValue + value + ' '

        # object / array
        if propertyType == 'object'
          # array?
          if Array.isArray(object[key])
            for arrayValue in object[key]
              if typeof arrayValue == 'string'
                fullTextString += arrayValue + ' '
                # no language: add to every l10n-fulltext
                for l10nObjectWithShortenedLanguagesKey, l10nObjectWithShortenedLanguagesValue of l10nObjectWithShortenedLanguages
                  l10nObjectWithShortenedLanguages[l10nObjectWithShortenedLanguagesKey] = l10nObjectWithShortenedLanguagesValue + arrayValue + ' '
              # startPlace, endPlace
              else if typeof arrayValue == 'object'
                if arrayValue?.prefLabel
                  for prefLabelOfArrayKey, prefLabelOfArrayValue of arrayValue.prefLabel
                    fullTextString += prefLabelOfArrayValue + ' '
                    # no language: add to every l10n-fulltext
                    for l10nObjectWithShortenedLanguagesKey, l10nObjectWithShortenedLanguagesValue of l10nObjectWithShortenedLanguages
                      l10nObjectWithShortenedLanguages[l10nObjectWithShortenedLanguagesKey] = l10nObjectWithShortenedLanguagesValue + prefLabelOfArrayValue + ' '
          else
            # object?
            for objectKey, objectValue of object[key]
              if Array.isArray(objectValue)
                for arrayValueOfObject in objectValue
                  fullTextString += arrayValueOfObject + ' '
                  # check key and also add to l10n
                  if l10nObjectWithShortenedLanguages.hasOwnProperty objectKey
                    l10nObjectWithShortenedLanguages[objectKey] += arrayValueOfObject + ' '
              if typeof objectValue == 'string'
                fullTextString += objectValue + ' '
                # check key and also add to l10n
                if l10nObjectWithShortenedLanguages[objectKey]
                  l10nObjectWithShortenedLanguages[objectKey] += objectValue + ' '
    # finally give l10n-languages the easydb-language-syntax
    for l10nObjectKey, l10nObjectValue of l10nObject
      # get shortened version
      shortenedLanguage = l10nObjectKey.split('-')[0]
      # add to l10n
      if l10nObjectWithShortenedLanguages[shortenedLanguage]
        l10nObject[l10nObjectKey] = l10nObjectWithShortenedLanguages[shortenedLanguage]

    _fulltext.text = fullTextString
    _fulltext.l10ntext = l10nObject

    return _fulltext



  @getStandardFromJSKOSObject: (JSKOS, databaseLanguages = false, labelWithHierarchie = false) ->

    shortenedDatabaseLanguages = databaseLanguages.map((value, key, array) ->
      value.split('-').shift()
    )

    if Array.isArray(JSKOS)
      JSKOS = JSKOS[0]

    _standard = {}
    l10nObject = {}

    # init l10nObject for fulltext
    for language in databaseLanguages
      l10nObject[language] = ''

    hasl10n = false

    #  give l10n-languages the easydb-language-syntax
    for l10nObjectKey, l10nObjectValue of l10nObject
      # get shortened version
      shortenedLanguage = l10nObjectKey.split('-')[0]
      # add to l10n
      prefLabel = @.getConceptNameFromJSKOSObject(JSKOS, shortenedLanguage, labelWithHierarchie)
      if prefLabel
        l10nObject[l10nObjectKey] = prefLabel
        hasl10n = true

    # if l10n, yet not in all languages
    #   --> fill the other languages with something as fallback
    if hasl10n
      for l10nObjectKey, l10nObjectValue of l10nObject
        if l10nObject[l10nObjectKey] == ''
          l10nObject[l10nObjectKey] = JSKOS.prefLabel[Object.keys(JSKOS.prefLabel)[0]]

    # if no l10n yet
    if ! hasl10n
      for l10nObjectKey, l10nObjectValue of l10nObject
        if JSKOS.prefLabel['und']
          l10nObject[l10nObjectKey] = JSKOS.prefLabel['und']
        else if JSKOS.prefLabel['zxx']
          l10nObject[l10nObjectKey] = JSKOS.prefLabel['zxx']
        else if JSKOS.prefLabel['mis']
          l10nObject[l10nObjectKey] = JSKOS.prefLabel['mis']
        else if JSKOS.prefLabel['mul']
          l10nObject[l10nObjectKey] = JSKOS.prefLabel['mul']

    # if l10n-object is not empty
    _standard.l10ntext = l10nObject

    # add geo
    geoJSON = @getGeoJSONFromDANTEJSKOS JSKOS
    if geoJSON
       _standard.geo =  geoJSON

    return _standard


  @getFacetTermFromJSKOSObject: (JSKOS, databaseLanguages, labelWithHierarchie) ->

    shortenedDatabaseLanguages = databaseLanguages.map((value, key, array) ->
      value.split('-').shift()
    )

    if Array.isArray(JSKOS)
      JSKOS = JSKOS[0]

    _facet_term = {}

    l10nObject = {}

    # init l10nObject
    for language in databaseLanguages
      l10nObject[language] = ''

    # build facetTerm upon prefLabels and uri!

    hasl10n = false

    #  give l10n-languages the easydb-language-syntax
    for l10nObjectKey, l10nObjectValue of l10nObject
      # get shortened version
      shortenedLanguage = l10nObjectKey.split('-')[0]
        
      # add to l10n
      prefLabel = @.getConceptNameFromJSKOSObject(JSKOS, shortenedLanguage, labelWithHierarchie)
      if prefLabel
        l10nObject[l10nObjectKey] = prefLabel
        l10nObject[l10nObjectKey] = l10nObject[l10nObjectKey] + '@$@' + JSKOS.uri
        hasl10n = true

    # if l10n, yet not in all languages
    #   --> fill the other languages with something as fallback
    if hasl10n
      for l10nObjectKey, l10nObjectValue of l10nObject
        if l10nObject[l10nObjectKey] == ''
          l10nObject[l10nObjectKey] = prefLabel
          l10nObject[l10nObjectKey] = l10nObject[l10nObjectKey] + '@$@' + JSKOS.uri

    # if no l10n yet
    if ! hasl10n
      for l10nObjectKey, l10nObjectValue of l10nObject
        if JSKOS.prefLabel['und']
          l10nObject[l10nObjectKey] = JSKOS.prefLabel['und']
        else if JSKOS.prefLabel['zxx']
          l10nObject[l10nObjectKey] = JSKOS.prefLabel['zxx']
        else if JSKOS.prefLabel['mis']
          l10nObject[l10nObjectKey] = JSKOS.prefLabel['mis']
        else if JSKOS.prefLabel['mul']
          l10nObject[l10nObjectKey] = JSKOS.prefLabel['mul']

        l10nObject[l10nObjectKey] = l10nObject[l10nObjectKey] + '@$@' + JSKOS.uri

    # if l10n-object is not empty
    _facet_term = l10nObject

    return _facet_term

  @getGeoJSONFromDANTEJSKOS: (jskos) ->
    geoJSON = false

    if jskos?.location
      if jskos.location != {} && jskos.location != []
        geoJSON = jskos.location

    return geoJSON