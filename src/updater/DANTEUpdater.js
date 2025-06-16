const fs = require('fs')
const https = require('https')
const fetch = (...args) => import('node-fetch').then(({
    default: fetch
}) => fetch(...args));

let databaseLanguages = [];
let frontendLanguages = [];
let defaultLanguage = 'de';

let info = {}

let access_token = '';

if (process.argv.length >= 3) {
    info = JSON.parse(process.argv[2])
}

let debug = info?.config?.plugin?.['custom-data-type-dante']?.config?.debug_dante?.enable_debug === true

function hasChanges(objectOne, objectTwo) {
    var len;
    const ref = ["conceptName", "conceptURI", "_standard", "_fulltext", "conceptAncestors", "frontendLanguage", "conceptNameChosenByHand", "conceptNameWithHierarchie", "facetTerm"];
    for (let i = 0, len = ref.length; i < len; i++) {
        let key = ref[i];
        if (!DANTEUtil.isEqual(objectOne[key], objectTwo[key])) {
            return true;
        }
    }
    return false;
}

function getConfigFromAPI() {
        return new Promise((resolve, reject) => {
                var url = 'http://fylr.localhost:8081/api/v1/config?access_token=' + access_token
                fetch(url, {
                                headers: {
                                        'Accept': 'application/json'
                                },
                        })
                        .then(response => {
                                if (response.ok) {
                                        resolve(response.json());
                                } else {
                                        console.error("DANTE-Updater: Fehler bei der Anfrage an /config ");
                                }
                        })
                        .catch(error => {
                                console.error(error);
                                console.error("DANTE-Updater: Fehler bei der Anfrage an /config");
                        });
        });
}

main = (payload) => {
    switch (payload.action) {
        case "start_update":
            logDebug("started logging");
            outputData({
                "state": {
                    "personal": 2
                },
                "log": ["started logging"]
            });
            break;
        case "update":
            ////////////////////////////////////////////////////////////////////////////
            // run dante-api-call for every given uri
            ////////////////////////////////////////////////////////////////////////////

            // collect URIs
            let URIList = [];
            for (var i = 0; i < payload.objects.length; i++) {
                URIList.push(payload.objects[i].data.conceptURI);
            }
            // unique urilist
            URIList = [...new Set(URIList)]

            let requestUrls = [];
            let requests = [];

            URIList.forEach((uri) => {
                let dataRequestUrl = 'https://api.dante.gbv.de/data?cache=1&uri=' + encodeURIComponent(uri) + '&properties=+ancestors,altLabel,hiddenLabel,notation,scopeNote,definition,identifier,example,startDate,endDate,startPlace,endPlace'
                let dataRequest = fetch(dataRequestUrl);
                requests.push({
                    url: dataRequestUrl,
                    uri: uri,
                    request: dataRequest
                });
                requestUrls.push(dataRequest);
            });

            Promise.all(requestUrls).then(function(responses) {
                let results = [];
                // Get a JSON object from each of the responses
                responses.forEach((response, index) => {
                    let url = requests[index].url;
                    let uri = requests[index].uri;
                    let result = {
                        url: url,
                        uri: uri,
                        data: null,
                        error: null
                    };
                    if (response.ok) {
                        result.data = response.json();
                    } else {
                        result.error = "Error fetching data from " + url + ": " + response.status + " " + response.statusText;
                    }
                    results.push(result);
                });
                return Promise.all(results.map(result => result.data));
            }).then(function(data) {
                let updatedObjects = 0;
                let results = [];
                data.forEach((data, index) => {
                    let url = requests[index].url;
                    let uri = requests[index].uri;
                    let result = {
                        url: url,
                        uri: uri,
                        data: data,
                        error: null
                    };
                    if (data instanceof Error) {
                        result.error = "Error parsing data from " + url + ": " + data.message;
                    }
                    results.push(result);
                });

                // build cdata from all api-request-results
                let cdataList = [];
                payload.objects.forEach((result, index) => {
                    let originalCdata = payload.objects[index].data;
                    let newCdata = {};
                    let originalURI = originalCdata.conceptURI;

                    const matchingRecordData = results.find(record => record.uri === originalURI);

                    if (matchingRecordData) {
                        // rematch uri, because maybe uri changed / rewrites ..
                        let uri = matchingRecordData.uri;

                        ///////////////////////////////////////////////////////
                        // conceptName, conceptURI, _standard, _fulltext, facet, frontendLanguage
                        resultJSON = matchingRecordData.data;
                        if (Array.isArray(resultJSON) && resultJSON.length > 0) {

                            resultJSON = resultJSON[0];

                            // basic check if valid jskos
                            if (resultJSON?.uri && resultJSON?.type) {
                                // get desired language for conceptName. This is frontendlanguage from original data or fallback
                                let desiredLanguage = defaultLanguage;
                                if (originalCdata?.frontendLanguage?.length == 2) {
                                    desiredLanguage = originalCdata.frontendLanguage;
                                }
                                // if no frontendLanguage exists in originalData: add
                                else {
                                    originalCdata.frontendLanguage = defaultLanguage;
                                }
                                // save frontend language (same as given or default)
                                newCdata.frontendLanguage = originalCdata.frontendLanguage;

                                // conceptNameWithHierarchie?
                                if (!originalCdata.conceptNameWithHierarchie) {
                                    newCdata.conceptNameWithHierarchie = false;
                                } else {
                                    newCdata.conceptNameWithHierarchie = true;
                                }
                                
                                // save conceptName
                                if (!originalCdata.conceptNameChosenByHand) {
                                    newCdata.conceptName = DANTEUtil.getConceptNameFromJSKOSObject(resultJSON, desiredLanguage, newCdata.conceptNameWithHierarchie);
                                    newCdata.conceptNameChosenByHand = false;
                                } else {
                                    newCdata.conceptName = originalCdata.conceptName;
                                    newCdata.conceptNameChosenByHand = true;
                                }

                                // save conceptURI
                                newCdata.conceptURI = uri;
                                // save _fulltext
                                newCdata._fulltext = DANTEUtil.getFullTextFromJSKOSObject(resultJSON, databaseLanguages);
                                // save _standard
                                newCdata._standard = DANTEUtil.getStandardFromJSKOSObject(resultJSON, databaseLanguages, newCdata.conceptNameWithHierarchie);
                                // save facet
                                newCdata.facetTerm = DANTEUtil.getFacetTermFromJSKOSObject(resultJSON, databaseLanguages, newCdata.conceptNameWithHierarchie);

                                // ancestors
                                newCdata.conceptAncestors = '';
                                let conceptAncestors = [];

                                for (i = 0, len = resultJSON.ancestors.length; i < len; i++) {
                                    conceptAncestors.push(resultJSON.ancestors[i].uri);
                                }
                                // add own uri to ancestor-uris
                                conceptAncestors.push(resultJSON.uri);
                                // merge ancestors to string
                                newCdata.conceptAncestors = conceptAncestors.join(' ');

                                if (hasChanges(payload.objects[index].data, newCdata)) {
                                    payload.objects[index].data = newCdata;
                                    updatedObjects++;
                                } else {}
                            }
                            else {
                                console.error("Empty JSKOS at " + uri + "?")
                            }
                        }
                    } else {
                        console.error('No matching record found');
                    }
                });
                logDebug(payload.objects.length + " objects in payload");
                logDebug(updatedObjects + " Objects with changes.");
                outputData({
                    "payload": payload.objects,
                    "log": [payload.objects.length + " objects in payload"]
                });
            });
            // send data back for update
            break;
        case "end_update":
            logDebug("done logging")
            outputData({
                "state": {
                    "theend": 2,
                    "log": ["done logging"]
                }
            });
            break;
        default:
            outputErr("Unsupported action " + payload.action);
    }
}

outputData = (data) => {
    out = {
        "status_code": 200,
        "body": data
    }
    process.stdout.write(JSON.stringify(out));
    process.exit(0);
}

outputErr = (err2) => {
    let err = {
        "status_code": 400,
        "body": {
            "error": err2.toString()
        }
    }
    console.error(JSON.stringify(err))
    process.stdout.write(JSON.stringify(err))
    process.exit(0);
}

logDebug = (message) =>{
    if(!debug) return;

    console.error("custom-data-type-dante: " + message)
}

(() => {

    let data = ""

    process.stdin.setEncoding('utf8');

    ////////////////////////////////////////////////////////////////////////////
    // check if hour-restriction is set
    ////////////////////////////////////////////////////////////////////////////
    logDebug("===================================================");
    logDebug("Debug: enabled");
    logDebug("===================================================");
    if(info?.config?.plugin?.['custom-data-type-dante']?.config?.update_dante?.restrict_time === true) {
        dante_config = info.config.plugin['custom-data-type-dante'].config.update_dante;

        
        // check if hours are configured
        if(dante_config?.from_time !== false && dante_config?.to_time !== false) {
            const now = new Date();            
            const hour = now.getHours();

            logDebug("Hour " + hour)
            logDebug("Before " + dante_config.from_time + " " + (hour < dante_config.from_time))
            logDebug("After " + dante_config.to_time + " " + (hour >= dante_config.to_time))
            // check if hours do not match
            if(hour < dante_config.from_time && hour >= dante_config.to_time) {
                // exit if hours do not match
                logDebug("hours do not match, cancel update")
                outputData({
                    "state": {
                        "theend": 2,
                        "log": ["hours do not match, cancel update"]
                    }
                });
            } else {
                logDebug("hours do match, start update")
            }
        }
    }

    access_token = info && info.plugin_user_access_token;
    
    if(access_token) {

        ////////////////////////////////////////////////////////////////////////////
        // get config and read the languages
        ////////////////////////////////////////////////////////////////////////////

        getConfigFromAPI().then(config => {
            databaseLanguages = config.system.config.languages.database;
            databaseLanguages = databaseLanguages.map((value, key, array) => {
                return value.value;
            });

            frontendLanguages = config.system.config.languages.frontend;

            const testDefaultLanguageConfig = config.plugin['custom-data-type-dante'].config.update_dante.default_language;
            if (testDefaultLanguageConfig) {
                if (testDefaultLanguageConfig.length == 2) {
                    defaultLanguage = testDefaultLanguageConfig;
                }
            }

            ////////////////////////////////////////////////////////////////////////////
            // availabilityCheck for dante-api
            ////////////////////////////////////////////////////////////////////////////
            https.get('https://api.dante.gbv.de/concept-types/test?cache=0', res => {
                let testData = [];
                res.on('data', chunk => {
                    testData.push(chunk);
                });
                res.on('end', () => {
                    const types = JSON.parse(Buffer.concat(testData).toString());
                    if (types.length > 0) {
                        if (types[0].uri) {
                            ////////////////////////////////////////////////////////////////////////////
                            // test successfull --> continue with custom-data-type-update
                            ////////////////////////////////////////////////////////////////////////////
                            process.stdin.on('readable', () => {
                                let chunk;
                                while ((chunk = process.stdin.read()) !== null) {
                                    data = data + chunk
                                }
                            });
                            process.stdin.on('end', () => {
                                ///////////////////////////////////////
                                // continue with update-routine
                                ///////////////////////////////////////
                                try {
                                    let payload = JSON.parse(data)
                                    main(payload)
                                } catch (error) {
                                    console.error("caught error", error)
                                    outputErr(error)
                                }
                            });
                        } else {
                            console.error('Error while interpreting data from api.dante.gbv.de: ', err.message);
                        }
                    } else {
                        console.error('Error while interpreting data from api.dante.gbv.de: ', err.message);
                    }
                });
            }).on('error', err => {
                console.error('Error while receiving data from api.dante.gbv.de: ', err.message);
            });
        }).catch(error => {
            console.error('Es gab einen Fehler beim Laden der Konfiguration:', error);
        });
    }
    else {
        console.error("kein Accesstoken gefunden");
    }
})();