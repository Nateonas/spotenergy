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
	// for tax values see next site to update if it is changed, defaults are for 2019
	// https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/overige_belastingen/belastingen_op_milieugrondslag/tarieven_milieubelastingen/tabellen_tarieven_milieubelastingen
	property variant settings: { 
		"includeTax" : true, 
		"tariffEnergyTax": 0.0986,
		"tariffODETax": 0.0189,
		"tariffVAT": 21,
		"domoticzEnable": false, 
		"domoticzHost": "domoticz.local",
		"domoticzPort": "8080",
		"domoticzIdx": "1",
		"lookbackHours": 2,
		"lookforwardHours": 18,
		"scaleGraph": true,
		"showColorinDim": true,
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
					collectTariffsTimer.interval = 10000; // set refresh of timer after 10 sec to get new tariffs in case of parameter changed after load
				}
				else {
					loadSettingsOldApp(); //try to get settings from old easyenergy app
				}
			}
		}
		settingsFile.open("GET", "file:///mnt/data/tsc/spotenergy.userSettings.json", true);
		settingsFile.send();
	}

	function loadSettingsOldApp()  {
		var settingsFile = new XMLHttpRequest();
		settingsFile.onreadystatechange = function() {
			if (settingsFile.readyState == XMLHttpRequest.DONE) {
				if (settingsFile.responseText.length > 0)  {
					var temp = JSON.parse(settingsFile.responseText);
					for (var setting in settings) {
						if (temp[setting] === undefined )  { temp[setting] = settings[setting]; } // use default if no saved setting exists
					}
					settings = temp;
					collectTariffsTimer.interval = 10000; // set refresh of timer after 10 sec to get new tariffs in case of parameter changed after load
					// save old easyenergy app settings to new settings file
                			var saveFile = new XMLHttpRequest();
                			saveFile.open("PUT", "file:///mnt/data/tsc/spotenergy.userSettings.json");
			                saveFile.send(JSON.stringify(settings));
				}
			}
		}
		settingsFile.open("GET", "file:///HCBv2/qml/apps/easyenergy/easyenergy.settings", true);
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

	function currentTextColor() {
		// set tile text color based on calculated averages
		var colorNow = "#FF0000";
		if (currentTariffUsage < tariffQ3) { colorNow = "#FF6600"; } 
		if (currentTariffUsage < tariffQ1) { colorNow = "#00FF00"; }
		return colorNow;
	}

	function normalizeTariff(tariff) {
		// adds tax to tariffs if requested and presents in euros with max 4 decimals
		var normalizedTariff = (settings.includeTax) ? parseInt((settings.tariffEnergyTax + settings.tariffODETax + tariff) * ((settings.tariffVAT / 100)+1) * 10000)/10000 : parseInt(tariff * 10000)/10000 ;
		return normalizedTariff;	
	}

	function getCurrentTariffs() {
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
					var tariffsTemp = [];
					minTariffValue = 1000;
					maxTariffValue = 0;
					for (var i = 0; i < jsonRes.quote.length; i++) {
						var quoteDateApplied = jsonRes.quote[i].date_applied;
						var quoteHour = jsonRes.quote[i].values[1].value;
						var quotePrice = jsonRes.quote[i].values[3].value / 1000;
						var quoteTime = quoteDateApplied + (quoteHour - 1) * 3600000 // this works ok in winter time.. need to check this when it is summer time
						var quoteTarrif = {timestamp: quoteTime, tariff: quotePrice};
						if (quoteTime >= now.getTime() && quoteTime <= endDate.getTime() ) {
							tariffsTemp.push(quoteTarrif);
						}
						
					}
					tariffsTemp.sort(function(a, b){return a.timestamp - b.timestamp});
					datapoints = tariffsTemp.length;

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
					var quartiles= SpotenergyJS.getQuartiles(tariffs);
					tariffQ1 = quartiles[0];
					tariffMedian = quartiles[1];
					tariffQ3 = quartiles[2];

					// set the current tariff and normalize
					currentTariffUsage = tariffs[settings.lookbackHours];
					if (settings.domoticzEnable) { updateDomoticz(); }
				}
				else {
					console.log("APX URL fetch failed!");
				}
			}
		}
		var urlAPX = "https://www.apxgroup.com/rest-api/quotes/APX%20Power%20NL%20Hourly?type=all&limit=3"
		xmlhttp.open("GET", urlAPX, true);
		xmlhttp.send();
	}


	Timer {
		id: collectTariffsTimer
		interval: 300000
		triggeredOnStart: true 
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
