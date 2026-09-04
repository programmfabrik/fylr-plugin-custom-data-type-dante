const fs = require('fs')
const https = require('https')

let databaseLanguages = [];
let frontendLanguages = [];
let defaultLanguage = 'de';

let info = {}

let access_token = '';

let plugin_name = 'fylr-plugin';
let instance_name = 'fylr-instance';

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
        var url = info.api_url + '/api/v1/config?access_token=' + access_token
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

function isInTimeRange(currentHour, fromHour, toHour) {
    if (fromHour === toHour) {
        return true;
    }

    if (fromHour < toHour) { // same day
        return currentHour >= fromHour && currentHour < toHour;
    } else { // through the night
        return currentHour >= fromHour || currentHour < toHour;
    }
}

function getNewCustomExpiresAt() {
    const newExpiresAt = new Date()
    const customExpirationConfig = info?.config?.plugin?.['custom-data-type-dante']?.config?.update_dante?.custom_expires_days || 1

    newExpiresAt.setDate(newExpiresAt.getDate() + customExpirationConfig);

    return newExpiresAt.toISOString()
}

let errorInProcess = false;

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

            ////////////////////////////////////////////////////////////////////////////
            // Replace URIs?
            ////////////////////////////////////////////////////////////////////////////

            // check if replacements are configured for the URIs
            let replacements = false;
            let replaceURIs = info.config.plugin['custom-data-type-dante']?.config?.update_dante?.replace_dante_uri;

            if (typeof replaceURIs === 'string' && replaceURIs.trim() !== '') {
                try {
                    replaceURIs = JSON.parse(replaceURIs);
                } catch (e) {
                    console.error('Fehler beim Parsen von replace_dante_uri:', e);
                    replaceURIs = false;
                }
            } else {
                replaceURIs = false;
            }            
            
            if(replaceURIs?.data_table?.length > 0) {
                replaceURIs = replaceURIs.data_table;
                const uriMap = replaceURIs.reduce((acc, item) => {
                        acc[item.from] = item.to;
                        return acc;
                    }, {});
                replaceURIs = uriMap;
                if(Object.keys(replaceURIs).length) {
                    replacements = replaceURIs;
                }
            }         
            
            console.error("replaceURIs", replaceURIs);

            URIList.forEach((uri) => {
                if (uri) {
                    // check for replacement
                    let effectiveURI = (replacements && replacements[uri]) ? replacements[uri] : uri;
                    let dataRequestUrl = 'https://api.dante.gbv.de/data?cache=1&uri=' + encodeURIComponent(effectiveURI) + '&properties=+ancestors,altLabel,hiddenLabel,notation,scopeNote,definition,identifier,example,startDate,endDate,startPlace,endPlace'
                    let dataRequest = fetch(dataRequestUrl);
                    requests.push({
                        url: dataRequestUrl,
                        uri: uri,
                        request: dataRequest
                    });
                    requestUrls.push(dataRequest);
                }
            });

            Promise.all(requestUrls).then(function (responses) {
                // Konvertiere alle Responses korrekt in JSON-Promises
                let jsonPromises = responses.map((response, index) => {
                    if (response.ok) {
                        return response.json();
                    } else {
                        return Promise.resolve(null);
                    }
                });
                return Promise.all(jsonPromises);
            }).then(function (dataList) {
                let updatedObjects = 0;
                let results = [];

                dataList.forEach((data, index) => {
                    let url = requests[index].url;
                    let uri = requests[index].uri;
                    results.push({
                        url: url,
                        uri: uri,
                        data: data
                    });
                });

                // build cdata from all api-request-results
                payload.objects.forEach((result, index) => {
                    let originalCdata = payload.objects[index].data;
                    let newCdata = {};
                    let originalURI = originalCdata.conceptURI;

                    const matchingRecordData = results.find(record => record.uri === originalURI);
                    
                    if (matchingRecordData && matchingRecordData.data) {
                        let resultJSON = matchingRecordData.data;

                        if (Array.isArray(resultJSON) && resultJSON.length > 0) {
                            resultJSON = resultJSON[0];

                            // basic check if valid jskos
                            if (resultJSON?.uri && resultJSON?.type) {
                                // get desired language for conceptName
                                let desiredLanguage = defaultLanguage;
                                if (originalCdata?.frontendLanguage?.length == 2) {
                                    desiredLanguage = originalCdata.frontendLanguage;
                                } else {
                                    originalCdata.frontendLanguage = defaultLanguage;
                                }
                                newCdata.frontendLanguage = originalCdata.frontendLanguage;

                                newCdata.conceptNameWithHierarchie = !!originalCdata.conceptNameWithHierarchie;

                                // save conceptName
                                if (!originalCdata.conceptNameChosenByHand) {
                                    newCdata.conceptName = DANTEUtil.getConceptNameFromJSKOSObject(resultJSON, desiredLanguage, newCdata.conceptNameWithHierarchie);
                                    newCdata.conceptNameChosenByHand = false;
                                } else {
                                    newCdata.conceptName = originalCdata.conceptName;
                                    newCdata.conceptNameChosenByHand = true;
                                }
                                
                                newCdata.conceptURI = resultJSON.uri;
                                newCdata._fulltext = DANTEUtil.getFullTextFromJSKOSObject(resultJSON, databaseLanguages);
                                newCdata._standard = DANTEUtil.getStandardFromJSKOSObject(resultJSON, databaseLanguages, newCdata.conceptNameWithHierarchie);
                                newCdata.facetTerm = DANTEUtil.getFacetTermFromJSKOSObject(resultJSON, databaseLanguages, newCdata.conceptNameWithHierarchie);

                                // ancestors
                                newCdata.conceptAncestors = '';
                                let conceptAncestors = [];
                                if (Array.isArray(resultJSON.ancestors)) {
                                    for (let i = 0, len = resultJSON.ancestors.length; i < len; i++) {
                                        if (resultJSON.ancestors[i]?.uri) {
                                            conceptAncestors.push(resultJSON.ancestors[i].uri);
                                        }
                                    }
                                }
                                conceptAncestors.push(resultJSON.uri);
                                newCdata.conceptAncestors = conceptAncestors.join(' ');

                                if (hasChanges(payload.objects[index].data, newCdata)) {
                                    payload.objects[index].data = newCdata;
                                    updatedObjects++;
                                } else { 
                                    payload.objects[index].data = originalCdata;
                                }
                                payload.objects[index].data._expires_at = getNewCustomExpiresAt();
                            } else {
                                console.error("No valid DANTE-record found: " + originalURI);
                                outputErr('No valid DANTE-record found: ' + originalURI);
                                errorInProcess = true;
                            }
                        } else {
                            console.error("No valid DANTE-record found: " + originalURI);
                            outputErr('No valid DANTE-record found: ' + originalURI);
                            errorInProcess = true;
                        }
                    } else {
                        console.error('No valid DANTE-record found: ' + originalURI);
                        outputErr('No valid DANTE-record found: ' + originalURI);
                        errorInProcess = true;
                    }
                });

                if (!errorInProcess) {
                    logDebug(payload.objects.length + " objects in payload");
                    logDebug(updatedObjects + " Objects with changes.");
                    outputData({
                        "payload": payload.objects,
                        "log": [payload.objects.length + " objects in payload"]
                    });
                }
            }).catch(error => {
                console.error("DANTE-Updater Error:", error);
                outputErr(error);
            });
            break;

        case "end_update":
            if (!errorInProcess) {
                logDebug("done logging");
                outputData({
                    "state": {
                        "theend": 2,
                        "log": ["done logging"]
                    }
                });
            }
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

outputErr = async (err2) => {
    errorMessage = err2.toString();

    // call slack-notification-plugin (if it exists, fire & forget)
    try {
        var slackUrl = instance_name.replace(/\/+$/, '') + "/api/v1/plugin/extension/slack-notification/slack_notification?access_token=" + access_token + "&source_instance=" + instance_name + "&source_name=" + plugin_name + "&message=" + encodeURIComponent(errorMessage);
        await fetch(slackUrl, { signal: AbortSignal.timeout(2000) }).catch(function() {});
    } catch (e) {}    

    let err = {
        "status_code": 400,
        "body": {
            "error": errorMessage
        }
    }
    console.error(JSON.stringify(err))
    process.stdout.write(JSON.stringify(err))
    process.exit(0);
}

logDebug = (message) => {
    if (!debug) return;
    console.error("custom-data-type-dante: " + message)
}

(() => {
    let data = ""
    process.stdin.setEncoding('utf8');

    logDebug("===================================================");
    logDebug("Debug: enabled");
    logDebug("===================================================");

    if (info?.config?.plugin?.['custom-data-type-dante']?.config?.update_dante?.restrict_time === true) {
        dante_config = info.config.plugin['custom-data-type-dante'].config.update_dante;

        if (dante_config?.from_time !== false && dante_config?.to_time !== false) {
            const now = new Date();
            const hour = now.getHours();

            if (isInTimeRange(hour, dante_config.from_time, dante_config.to_time)) {
                logDebug("hours do match, start update")
            } else {
                logDebug("hours do not match, cancel update")
                outputData({
                    "state": {
                        "theend": 2,
                        "log": ["hours do not match, cancel update"]
                    }
                });
            }
        }
    }

    instance_name = info?.external_url || 'fylr-instance';
    plugin_name = Object.keys(info?.config?.plugin || 'fylr-plugin')[0];
    access_token = info && info.plugin_user_access_token;

    if (access_token) {
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

            https.get('https://api.dante.gbv.de/concept-types/test?cache=0', res => {
                let testData = [];
                res.on('data', chunk => {
                    testData.push(chunk);
                });
                res.on('end', () => {
                    try {
                        const types = JSON.parse(Buffer.concat(testData).toString());
                        if (types.length > 0 && types[0].uri) {
                            process.stdin.on('readable', () => {
                                let chunk;
                                while ((chunk = process.stdin.read()) !== null) {
                                    data = data + chunk
                                }
                            });
                            process.stdin.on('end', () => {
                                try {
                                    let payload = JSON.parse(data)
                                    main(payload)
                                } catch (error) {
                                    console.error("caught error", error)
                                    outputErr(error)
                                }
                            });
                        } else {
                            console.error('Error while interpreting data from api.dante.gbv.de');
                            outputErr('Error while interpreting data from api.dante.gbv.de');
                        }
                    } catch (e) {
                        console.error('Error parsing JSON from api.dante.gbv.de', e);
                        outputErr(e);
                    }
                });
            }).on('error', err => {
                console.error('Error while receiving data from api.dante.gbv.de: ', err.message);
                outputErr(err);
            });
        }).catch(error => {
            console.error('Es gab einen Fehler beim Laden der Konfiguration:', error);
            outputErr(error);
        });
    } else {
        console.error("kein Accesstoken gefunden");
        outputErr("kein Accesstoken gefunden");
    }
})();