import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0
import "spotenergy.js" as SpotenergyJS 


App {
	id: root
	// These are the URL's for the QML resources from which our widgets will be instantiated.
	// By making them a URL type property they will automatically be converted to full paths,
	// preventing problems when passing them around to code that comes from a different path.
	property url trayUrl : "SpotenergyTray.qml";
	property url tileUrl : "SpotenergyTile.qml";
	property url thumbnailIcon: "qrc:/tsc/spotenergyIcon.png"
	property url spotenergyScreenUrl : "SpotenergyScreen.qml"
	property url spotenergySettingsUrl : "SpotenergySettings.qml"

	property SpotenergySettings spotenergySettings
	// these are the default settings
	// for tax values see next site to update if it is changed, defaults are for 2022
	// https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/overige_belastingen/belastingen_op_milieugrondslag/tarieven_milieubelastingen/tabellen_tarieven_milieubelastingen
	property variant settings: { 
		"includeTax" : true, 
                "tariffEnergyTax": 0.03679,
                "tariffODETax": 0.0305,
		"tariffVAT": 21,
		"domoticzEnable": false, 
		"domoticzHost": "domoticz.local",
		"domoticzPort": "8080",
		"domoticzIdx": "1",
		"lookbackHours": 2,
		"lookforwardHours": 18,
		"scaleGraph": true,
		"showColorinDim": true,
		"algoMedian": true,
		"coloredBars": true,
	}

	property variant tariffValues: [] // will contain the collected tariffs
	property real minTariffValue // will contain the min tariff from the collected 
	property real maxTariffValue // will contain the max tariff from the collected 
	property real tariffQ1 // will contain the average low part of the collected (splicing the Q1 and Q2) 
	property real tariffMedian // will contain the average low part of the collected (splicing the Q1 and Q2) 
	property real tariffQ3 // will contain the average high part of the collected (splicing the Q3 and Q4)
	property real currentTariffUsage // will contain the current tariff (usage)
	property real currentTariffReturn // will contain the current tariff (return) *future use*
	property int currentHour // will containt the current hour 
	property int startHour  // will contain the start hour of the collected tariffs
	property int datapoints // will contain the number of datapoints

	function init() {
		registry.registerWidget("screen", spotenergyScreenUrl, this);
		registry.registerWidget("screen", spotenergySettingsUrl, this, "spotenergySettings");
		// disable the systray for now                registry.registerWidget("systrayIcon", trayUrl, this, "spotenergyTray");
		registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: "SpotEnergy", thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, baseTileSolarWeight: 10, thumbIconVAlignment: "center"});
	}

	Component.onCompleted: {
		// load the settings on completed is recommended instead of during init
		loadSettings(); 
		collectTariffsTimer.interval = 1000; // set refresh of timer after 1 sec to get new tariffs in case of parameter changed after load
	}

	function loadSettings()  {
		var settingsFile = new XMLHttpRequest();
		settingsFile.onreadystatechange = function() {
			if (settingsFile.readyState == XMLHttpRequest.DONE) {
				if (settingsFile.responseText.length > 0)  {
					var temp = JSON.parse(settingsFile.responseText);
					for (var setting in settings) {
						if (temp[setting] === undefined )  { temp[setting] = settings[setting]; } // use default if no saved setting exists
					}
					settings = temp;
				}
				else {
					loadSettingsOldApp(); //try to get settings from old easyenergy app
				}
			}
		}
		settingsFile.open("GET", "file:///mnt/data/tsc/spotenergy.userSettings.json", true);
		settingsFile.send();
	}

	function updateDomoticz() {
		var alertStatus = 4;
		if (currentTariffUsage < tariffQ3) { alertStatus = 3; }
		if (currentTariffUsage < tariffMedian) { alertStatus = 2; }
		if (currentTariffUsage < tariffQ1) { alertStatus = 1; }
		var request = ("http://"+settings.domoticzHost+":"+settings.domoticzPort+"/json.htm?type=command&param=udevice&idx="+settings.domoticzIdx+"&nvalue="+alertStatus+"&svalue="+normalizeTariff(currentTariffUsage))
		var xmlhttp = new XMLHttpRequest();
		xmlhttp.open("GET", request, true);
		xmlhttp.send();

	}

	function tariffTextColor(trf) {
		// set tile text color based on calculated averages
		var colorNow = "#FF0000";
		if (trf < tariffQ3) { colorNow = "#FF6600"; } 
		if (trf < tariffQ1) { colorNow = "#00FF00"; }
		return colorNow;
	}

	function numHex(s)
	{
		var a = s.toString(16);
		if ((a.length % 2) > 0) {
			a = "0" + a;
		}
		return a;
	}

	function barColor(index) {
		// set bar color based on calculated averages
                var percent = 100 * (tariffValues[index] - minTariffValue) / (maxTariffValue - minTariffValue);
		const r = percent > 50 ? 255 : Math.round(255 * percent/50);
		const g = percent < 50 ? 255 : Math.round(255 - (255 * (percent-50)/50));
		return "#" + numHex(r) + numHex(g) + "00"; 
	}

	function normalizeTariff(tariff) {
		// adds tax to tariffs if requested and presents in euros with max 4 decimals
		var normalizedTariff = (settings.includeTax) ? parseInt((settings.tariffEnergyTax + settings.tariffODETax + tariff) * ((settings.tariffVAT / 100)+1) * 10000)/10000 : parseInt(tariff * 10000)/10000 ;
		return normalizedTariff;	
	}

	function getCurrentTariffs() {
		// should check a setting later to switch between data providers
		getCurrentTariffsEntsoe()
	}

	function getCurrentTariffsEntsoe() {
		var now = new Date();
		currentHour = now.getHours();
		startHour = currentHour - settings.lookbackHours; // start the graph at the start point set
		now.setHours(startHour,0,0,0);
		var endDate = new Date(now.getTime() + ((settings.lookforwardHours + settings.lookbackHours) * 3600 * 1000)); // end the graph at the end piont set

		var xmlhttp = new XMLHttpRequest();
		xmlhttp.onreadystatechange=function() {
			if (xmlhttp.readyState == 4) {
				if (xmlhttp.status == 200) {
					var res = xmlhttp.responseText
					var tariffsTemp = []
					var i = res.indexOf("<Period>")
					var j = res.indexOf("</Period>")
					while ( i > 0 ) { 
						var period = res.slice(i+8,j)
						res = res.slice(j+9)
						i = period.indexOf("<start>")
						j = period.indexOf("</start>")
						var start = period.slice(i+7,j)
						var quoteTime = Date.parse(start) - 3600000
						i = period.indexOf("<price.amount>")
						while ( i > 0 ) {
							period = period.slice(i+14)
							j = period.indexOf("</price.amount>")
							var quotePrice = period.slice(0,j) / 1000
							var quoteTime = quoteTime + 3600000 // for now this is good, every next index is one hour later
							var quoteTarrif = {timestamp: quoteTime, tariff: quotePrice}
							if (quoteTime >= now.getTime() && quoteTime <= endDate.getTime() ) {
								tariffsTemp.push(quoteTarrif)
							}
							i = period.indexOf("<price.amount>")
						}
						// next period
						i = res.indexOf("<Period>")
						j = res.indexOf("</Period>")
					}
                                        tariffsTemp.sort(function(a, b){return a.timestamp - b.timestamp});
                                        datapoints = tariffsTemp.length;
					if ( ((datapoints - settings.lookbackHours) < 6) && (settings.lookforwardHours > 6 ) ) {
						console.log("SpotEnergy: ENTSOE URL fetch returned not enough datapoints!");
					 	getCurrentTariffsEasyEnergy();	
						return;
					}

					minTariffValue = 1000;
					maxTariffValue = -1000;

                                        var tariffs = [];
                                        for (var i = 0; i < tariffsTemp.length; i++) {
                                                tariffs[i] = tariffsTemp[i].tariff;
                                                if (minTariffValue > tariffs[i]) {
                                                        minTariffValue = tariffs[i];
                                                }
                                                if (maxTariffValue < tariffs[i]) {
                                                        maxTariffValue = tariffs[i];
                                                }
                                        }

                                        tariffValues = tariffs.slice();

                                        // calculate the quartiles for the low and high tariff
					var quartiles;
					if (settings.algoMedian) {
                                        	quartiles = SpotenergyJS.getQuartilesMedian(tariffs);
					} else {
                                        	quartiles = SpotenergyJS.getQuartilesAverage(tariffs);
					}
                                        tariffQ1 = quartiles[0];
                                        tariffMedian = quartiles[1];
                                        tariffQ3 = quartiles[2];

                                        // set the current tariff and normalize
                                        currentTariffUsage = tariffs[settings.lookbackHours];
                                        if (settings.domoticzEnable) { updateDomoticz(); }

				}
				else {
					console.log("SpotEnergy: ENTSOE URL fetch failed!");
				 	getCurrentTariffsEasyEnergy();	
				}
			}
		}
		var urlAppend = "TimeInterval=" + encodeURIComponent(now.toISOString() + "/" + endDate.toISOString());
		var urlEntsoe = "https://transparency.entsoe.eu/api?securityToken=68aa46a3-3b1b-4071-ac6b-4372830b114f&documentType=A44&Out_Domain=10YNL----------L&In_Domain=10YNL----------L&" + urlAppend;
		xmlhttp.open("GET", urlEntsoe, true);
		xmlhttp.send();
	}

	function getCurrentTariffsEasyEnergy() {
		var now = new Date();
		currentHour = now.getHours();
		startHour = currentHour - settings.lookbackHours; // start the graph at the start point set
		now.setHours(startHour,0,0,0);
		var endDate = new Date(now.getTime() + ((settings.lookforwardHours + settings.lookbackHours) * 3600 * 1000)); // end the graph at the end piont set

		var xmlhttp = new XMLHttpRequest();
		xmlhttp.onreadystatechange=function() {
			if (xmlhttp.readyState == 4) {
				if (xmlhttp.status == 200) {
					var res = xmlhttp.responseText;
					var jsonRes = JSON.parse(res);
					datapoints = jsonRes.length;
					var tariffs = [];
					minTariffValue = 1000;
					maxTariffValue = 0;
					// walk trhough the xml result and put the values into a temporary array
					for (var i = 0; i < jsonRes.length; i++) {
						// since a few weeks easyenergy includes tax in the reported tariffusage, but still raw value in tariffreturn so use that 
						tariffs[i] = jsonRes[i].TariffReturn
						if (minTariffValue > tariffs[i]) {
							minTariffValue = tariffs[i];
						}
						if (maxTariffValue < tariffs[i]) {
							maxTariffValue = tariffs[i];
						}
					}
					tariffValues = tariffs.slice(); // copy the collected tarrifs into the app property (somehow not possible without the tariffs array)

					// calculate the quartiles for the low and high tariff 
					var quartiles;
					if (settings.algoMedian) {
						SpotenergyJS.getQuartilesMedian(tariffs);
					} else {
						SpotenergyJS.getQuartilesAverage(tariffs);
					}
					tariffQ1 = quartiles[0];
					tariffMedian = quartiles[1];
					tariffQ3 = quartiles[2];

					// set the current tariff and normalize
					currentTariffUsage = tariffs[settings.lookbackHours];
					if (settings.domoticzEnable) { updateDomoticz(); }
				}
				else {
					console.log("Easyenergy URL fetch failed also!");
				}
			}
		}
		var urlAppend = "startTimestamp=" + encodeURIComponent(now.toISOString()) + "&endTimestamp=" + encodeURIComponent(endDate.toISOString());
		var urlEasyEnergy = "https://mijn.easyenergy.com/nl/api/tariff/getapxtariffs?" + urlAppend;
		xmlhttp.open("GET", urlEasyEnergy, true);
		xmlhttp.send();
	}

	Timer {
		id: collectTariffsTimer
		interval: 300000
		triggeredOnStart: false
		running: true
		repeat: true
		onTriggered: {
			// update interval to only update at the start of the next hour
			var now = new Date();
			var secondsUntilNextHour = ((59 - now.getMinutes()) * 60) + (60 - now.getSeconds());
			collectTariffsTimer.interval = secondsUntilNextHour * 1000;
			getCurrentTariffs();
		}
	}

}
