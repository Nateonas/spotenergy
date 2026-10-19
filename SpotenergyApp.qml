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
	// for tax values see next site to update if it is changed, defaults are for 2026
	// https://www.belastingdienst.nl/wps/wcm/connect/bldcontentnl/belastingdienst/zakelijk/overige_belastingen/belastingen_op_milieugrondslag/tarieven_milieubelastingen/tabellen_tarieven_milieubelastingen
	property variant settings: {
		"includeTax" : true,
                "tariffEnergyTax": 0.09161157,
                "tariffODETax": 0.0,
		"tariffVAT": 21,
		"tariffBonus": 0.00,
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
		"showQuarterHour": false,
		"entsoeToken": "",
	}

	property variant tariffValues: [] // will contain the collected tariffs
	property real minTariffValue // will contain the min tariff from the collected
	property real maxTariffValue // will contain the max tariff from the collected
	property real tariffQ1 // will contain the average low part of the collected (splicing the Q1 and Q2)
	property real tariffMedian // will contain the average low part of the collected (splicing the Q1 and Q2)
	property real tariffQ3 // will contain the average high part of the collected (splicing the Q3 and Q4)
	property real currentTariffUsage // will contain the current tariff (usage)
	property real currentTariffReturn // will contain the current tariff (return) *future use*
	property int currentHour // will contain the current hour
	property int startHour  // will contain the start hour of the collected tariffs
	property int datapoints // will contain the number of hourly datapoints (always used by tile)
	property int currentBarIndex // will contain the index of the current hourly bar
	property variant tariffValuesQuarter: [] // will contain the 15-min tariff values (only when showQuarterHour)
	property int datapointsQuarter: 0 // will contain the number of 15-min datapoints
	property int currentBarIndexQuarter: 0 // will contain the index of the current 15-min bar

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

	function barColor(value) {
		// set bar color based on min/max range
		var percent = (maxTariffValue > minTariffValue) ? 100 * (value - minTariffValue) / (maxTariffValue - minTariffValue) : 0;
		percent = Math.max(0, Math.min(100, percent));
		const r = percent > 50 ? 255 : Math.round(255 * percent/50);
		const g = percent < 50 ? 255 : Math.round(255 - (255 * (percent-50)/50));
		return "#" + numHex(r) + numHex(g) + "00"; 
	}

	function normalizeTariff(tariff) {
		// adds tax to tariffs if requested and presents in euros with max 4 decimals
		var normalizedTariff = (settings.includeTax) ? parseInt((settings.tariffEnergyTax + settings.tariffODETax + settings.tariffBonus + tariff) * ((settings.tariffVAT / 100)+1) * 10000)/10000 : parseInt(tariff * 10000)/10000 ;
		return normalizedTariff;	
	}

	function formatDateCompact(date) {
		var y = date.getUTCFullYear();
		var mo = ("0" + (date.getUTCMonth() + 1)).slice(-2);
		var d = ("0" + date.getUTCDate()).slice(-2);
		var h = ("0" + date.getUTCHours()).slice(-2);
		var mi = ("0" + date.getUTCMinutes()).slice(-2);
		return y + mo + d + h + mi;
	}

	function getCurrentTariffs() {
		getCurrentTariffsEntsoe()
	}

	function formatDateISO(date) {
		var y = date.getFullYear();
		var mo = ("0" + (date.getMonth() + 1)).slice(-2);
		var d = ("0" + date.getDate()).slice(-2);
		return y + "-" + mo + "-" + d;
	}

	// shared by both entsoe and easyenergy: aggregates raw tariffsTemp (timestamp/tariff pairs)
	// into hourly averages, computes quartiles/min/max/current tariff, and (if enabled) stores
	// the raw 15-min data too. Returns false if there weren't enough datapoints to use.
	function processTariffs(tariffsTemp, now, currentMinutes, sourceLabel) {
		tariffsTemp.sort(function(a, b){return a.timestamp - b.timestamp});

		// always aggregate to hourly averages (used by tile, quartiles, current tariff)
		var hourlyTemp = []
		var idx = 0
		while (idx < tariffsTemp.length) {
			var hourStart = new Date(tariffsTemp[idx].timestamp)
			hourStart.setMinutes(0, 0, 0)
			var sum = 0
			var count = 0
			while (idx < tariffsTemp.length && tariffsTemp[idx].timestamp < hourStart.getTime() + 3600000) {
				sum += tariffsTemp[idx].tariff
				count++
				idx++
			}
			if (count > 0) {
				hourlyTemp.push({timestamp: hourStart.getTime(), tariff: sum / count})
			}
		}

		if (hourlyTemp.length < 2) {
			console.log("SpotEnergy: " + sourceLabel + " returned not enough datapoints!");
			return false;
		}

		// hourlyTemp is packed contiguously from whatever data survived the time filter, but
		// currentBarIndex below assumes tariffs[0] is exactly "now" (the lookback-adjusted start).
		// If the source is missing data for the current period (e.g. an entire day), hourlyTemp[0]
		// silently starts later than "now" and every bar would be shifted — detect that and bail
		// out so the caller can fall back to another source instead of showing misaligned data.
		if (hourlyTemp[0].timestamp !== now.getTime()) {
			console.log("SpotEnergy: " + sourceLabel + " data does not start at the expected time (gap at start), rejecting!");
			return false;
		}

		minTariffValue = 1000;
		maxTariffValue = -1000;

		var tariffs = [];
		for (var i = 0; i < hourlyTemp.length; i++) {
			tariffs[i] = hourlyTemp[i].tariff;
			if (minTariffValue > tariffs[i]) { minTariffValue = tariffs[i]; }
			if (maxTariffValue < tariffs[i]) { maxTariffValue = tariffs[i]; }
		}
		// update the array before datapoints (bound to the Repeater's model) so the
		// Repeater never sees a model count larger than the array backing it
		tariffValues = tariffs.slice();
		datapoints = hourlyTemp.length;

		// calculate quartiles from hourly data
		var quartiles;
		if (settings.algoMedian) {
			quartiles = SpotenergyJS.getQuartilesMedian(tariffs);
		} else {
			quartiles = SpotenergyJS.getQuartilesAverage(tariffs);
		}
		tariffQ1 = quartiles[0];
		tariffMedian = quartiles[1];
		tariffQ3 = quartiles[2];

		// hourly current bar index and tariff
		currentBarIndex = settings.lookbackHours;
		currentTariffUsage = tariffs[currentBarIndex];
		if (settings.domoticzEnable) { updateDomoticz(); }

		// additionally store 15-min data for the large screen when showQuarterHour is on
		if (settings.showQuarterHour) {
			var quarterTariffs = [];
			for (var i = 0; i < tariffsTemp.length; i++) {
				quarterTariffs[i] = tariffsTemp[i].tariff;
			}
			tariffValuesQuarter = quarterTariffs.slice();
			datapointsQuarter = tariffsTemp.length;
			currentBarIndexQuarter = settings.lookbackHours * 4 + Math.floor(currentMinutes / 15);
			currentTariffUsage = quarterTariffs[currentBarIndexQuarter];
		}

		return true;
	}

	function getCurrentTariffsEasyenergy() {
		var now = new Date();
		currentHour = now.getHours();
		var currentMinutes = now.getMinutes();
		startHour = currentHour - settings.lookbackHours;
		now.setHours(startHour,0,0,0);
		var endDate = new Date(now.getTime() + ((settings.lookforwardHours + settings.lookbackHours) * 3600 * 1000));

		// easyenergy takes whole-day ranges [start, end) in local dates, so pad a day on each side
		var startDateStr = formatDateISO(now);
		var endDateStr = formatDateISO(new Date(endDate.getTime() + 24 * 3600 * 1000));

		var xmlhttp = new XMLHttpRequest();
		xmlhttp.onreadystatechange = function() {
			if (xmlhttp.readyState == 4) {
				if (xmlhttp.status == 200) {
					try {
						var data = JSON.parse(xmlhttp.responseText);
						var tariffsTemp = []
						for (var i = 0; i < data.prices.length; i++) {
							var item = data.prices[i];
							var quoteTime = Date.parse(item.from);
							if (quoteTime >= now.getTime() && quoteTime <= endDate.getTime()) {
								tariffsTemp.push({timestamp: quoteTime, tariff: item.price});
							}
						}
						processTariffs(tariffsTemp, now, currentMinutes, "easyenergy backup");
					} catch (e) {
						console.log("SpotEnergy: easyenergy backup parse error: " + e);
					}
				}
				else {
					console.log("SpotEnergy: easyenergy backup URL fetch failed!");
				}
			}
		}
		var urlEasyenergy = "https://price-graph.mijn.easyenergy.com/api/prices?start=" + startDateStr + "&end=" + endDateStr + "&type=electricity&granularity=quarter";
		console.log("SpotEnergy easyenergy backup url: " + urlEasyenergy);
		xmlhttp.open("GET", urlEasyenergy, true);
		xmlhttp.send();
	}

	function getCurrentTariffsEntsoe() {
		var now = new Date();
		currentHour = now.getHours();
		var currentMinutes = now.getMinutes();
		startHour = currentHour - settings.lookbackHours; // start the graph at the start point set
		now.setHours(startHour,0,0,0);
		var endDate = new Date(now.getTime() + ((settings.lookforwardHours + settings.lookbackHours) * 3600 * 1000)); // end the graph at the end point set

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

						// parse the resolution to determine the time step per data point
						var resI = period.indexOf("<resolution>")
						var resJ = period.indexOf("</resolution>")
						var timeStep = 3600000 // default: 1 hour
						if (resI >= 0 && resJ >= 0) {
							var resStr = period.slice(resI+12, resJ)
							if (resStr === "PT15M") { timeStep = 900000 } // 15 minutes
						}

						i = period.indexOf("<start>")
						j = period.indexOf("</start>")
						var start = period.slice(i+7,j)
						var quoteTime = Date.parse(start) - timeStep

						// the period's declared end — used to fill trailing points ENTSOE
						// omits when the price doesn't change through the rest of the period
						var endI = period.indexOf("<end>")
						var endJ = period.indexOf("</end>")
						var periodEnd = (endI >= 0 && endJ >= 0) ? Date.parse(period.slice(endI+5, endJ)) : null

						i = period.indexOf("<price.amount>")
						while ( i > 0 ) {
							var p1 = period.indexOf("<position>")
							var positionString = period.slice(p1+10)
							var p2 = positionString.indexOf("</position>")
							var position = positionString.slice(0,p2) / 1
							period = period.slice(i+14)
							j = period.indexOf("</price.amount>")
							var quotePrice = period.slice(0,j) / 1000
							quoteTime = quoteTime + timeStep
							var quoteTarrif = {timestamp: quoteTime, tariff: quotePrice}
							if (quoteTime >= now.getTime() && quoteTime <= endDate.getTime() ) {
								tariffsTemp.push(quoteTarrif)
							}
							// check if next position skips — fill gap with current price
							var nextp1 = period.indexOf("<position>")
							if (nextp1 > 0) {
								var nextpositionString = period.slice(nextp1+10)
								var nextp2 = nextpositionString.indexOf("</position>")
								var nextposition = nextpositionString.slice(0,nextp2) / 1
								if (nextposition > (position + 1)) {
									console.log("SpotEnergy: gap detected, filling " + (nextposition - position - 1) + " slot(s) at position " + position)
									while (nextposition > (position + 1)) {
										position = position + 1
										quoteTime = quoteTime + timeStep
										quoteTarrif = {timestamp: quoteTime, tariff: quotePrice}
										if (quoteTime >= now.getTime() && quoteTime <= endDate.getTime() ) {
											tariffsTemp.push(quoteTarrif)
										}
									}
								}
							} else if (periodEnd !== null && quoteTime + timeStep <= periodEnd) {
								// last point sent in this period, but the period itself continues —
								// ENTSOE omits trailing points when the price doesn't change, so
								// fill forward with the last known price to the period's real end
								var trailingGaps = Math.round((periodEnd - quoteTime) / timeStep)
								console.log("SpotEnergy: trailing gap at end of period, filling " + trailingGaps + " slot(s)")
								while (quoteTime + timeStep <= periodEnd) {
									quoteTime = quoteTime + timeStep
									quoteTarrif = {timestamp: quoteTime, tariff: quotePrice}
									if (quoteTime >= now.getTime() && quoteTime <= endDate.getTime() ) {
										tariffsTemp.push(quoteTarrif)
									}
								}
							}
							i = period.indexOf("<price.amount>")
						}
						// next period
						i = res.indexOf("<Period>")
						j = res.indexOf("</Period>")
					}
					if (!processTariffs(tariffsTemp, now, currentMinutes, "ENTSOE")) {
						getCurrentTariffsEasyenergy();
					}
				}
				else {
					console.log("SpotEnergy: ENTSOE URL fetch failed!");
					getCurrentTariffsEasyenergy();
				}
			}
		}
		var urlAppend = "periodStart=" + formatDateCompact(now) + "&periodEnd=" + formatDateCompact(endDate);
		var urlEntsoe = "https://web-api.tp.entsoe.eu/api?securityToken=" + settings.entsoeToken + "&documentType=A44&Out_Domain=10YNL----------L&In_Domain=10YNL----------L&" + urlAppend;
		console.log("SpotEnergy entsoe url: " + urlEntsoe);
		xmlhttp.open("GET", urlEntsoe, true);
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
