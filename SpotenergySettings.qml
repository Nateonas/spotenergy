import QtQuick 2.1
import qb.components 1.0
import BxtClient 1.0

Screen {
	id: spotenergySettingsScreen

	hasBackButton: false
	hasHomeButton: false
	hasCancelButton: true


	property bool firstShown: true;  // we need this because exiting a keyboard will load onShown again. Without this the input will be overwritten with the app settings again


	screenTitle: "Spotenergy configuratie"

	onShown: {
		addCustomTopRightButton("Opslaan");
		if (firstShown) {  // only update the input boxes if this is the first time shown, not while coming back from a keyboard input
			taxToggle.isSwitchedOn = app.settings.includeTax;
			energyTaxValueLabel.rightText = app.settings.tariffEnergyTax;
			odeTaxValueLabel.rightText = app.settings.tariffODETax;
			vatTaxValueLabel.rightText = app.settings.tariffVAT;
			scaleToggle.isSwitchedOn = app.settings.scaleGraph; 
			dimColorToggle.isSwitchedOn = app.settings.showColorinDim;
			lookBackValueLabel.rightText = app.settings.lookbackHours;
			lookForwardValueLabel.rightText = app.settings.lookforwardHours;
			domoticzToggle.isSwitchedOn = app.settings.domoticzEnable;
			domoticzHostLabel.rightText = app.settings.domoticzHost;
			domoticzPortLabel.rightText = app.settings.domoticzPort;
			domoticzIdxLabel.rightText = app.settings.domoticzIdx;
			algoMedianToggle.isSwitchedOn = app.settings.algoMedian;
			coloredBarsToggle.isSwitchedOn = app.settings.coloredBars;
			firstShown = false;
		}
	}

	onCanceled: {
		firstShown = true; // if canceled we can overwrite the input boxes again with the app settings 
	}



	onCustomButtonClicked: {
		hide();
		var temp = app.settings; // updating app property variant is only possible in its whole, not by elements only, so we need this
		temp.includeTax = taxToggle.isSwitchedOn;
		temp.tariffEnergyTax = parseFloat(energyTaxValueLabel.rightText);
		temp.tariffODETax = parseFloat(odeTaxValueLabel.rightText);
		temp.tariffVAT = parseFloat(vatTaxValueLabel.rightText);
		temp.scaleGraph = scaleToggle.isSwitchedOn;
		temp.showColorinDim = dimColorToggle.isSwitchedOn;
		temp.lookbackHours = parseInt(lookBackValueLabel.rightText);
		temp.lookforwardHours = parseInt(lookForwardValueLabel.rightText);
		temp.domoticzEnable = domoticzToggle.isSwitchedOn; 
		temp.domoticzHost = domoticzHostLabel.rightText;
		temp.domoticzPort = domoticzPortLabel.rightText;
		temp.domoticzIdx = domoticzIdxLabel.rightText;
		temp.algoMedian = algoMedianToggle.isSwitchedOn; 
		temp.coloredBars = coloredBarsToggle.isSwitchedOn; 
		app.settings = temp;

		firstShown = true; // we have saved the settings so on a fresh settings screen we can load the input boxes with the new app settings

		// save the new app settings into the json file
		var saveFile = new XMLHttpRequest();
		saveFile.open("PUT", "file:///mnt/data/tsc/spotenergy.userSettings.json");
		saveFile.send(JSON.stringify(app.settings));

		app.getCurrentTariffs(); // fetch new data on each save

	}


	function hostnameValidate(text, isFinal) {
		if (isFinal) {
			if ((text.match(/^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/)) || (text.match(/^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/))) {
				return null;
			}
			else {
				return {content: "Onjuist hostnaam of IP adres"};
			}
			return null;
		}
		return null;
	}

	function numValidate(text, isFinal) {
		if (isFinal) {
			if (text.match(/^[0-9]*$/)) {
				return null;
			}
			else {
				return {content: "Poort nummer onjuist"};
			}
			return null;
		}
		return null;
	}

	function lookbackforwardValidate(text, isFinal) {
		if (isFinal) {
			if (text.match(/^[0-9]*$/)) {
				if (text > 48) { // looking back or forward more than 48 hours makes no sense
					return {content: "Maximaal 48 uur"};
				}
				return null;
			}
			else {
				return {content: "Onjuist getal"};
			}
			return null;
		}
		return null;
	}

	function updateEnergyTaxValueLabel(text) {
		if (text) {
			// need to santize the input to a dot-seperated decimal value
			if (text.match(/,/)) {
				energyTaxValueLabel.rightText = text.replace(",",".");
			}
			else if (text.match(/\./)) {
				energyTaxValueLabel.rightText = text;
			}
			else {
				energyTaxValueLabel.rightText = "0."+text; // invoer in centen omzetten naar euro
			}
		}

	}

	function updateODETaxValueLabel(text) {
		if (text) {
			// need to santize the input to a dot-seperated decimal value
			if (text.match(/,/)) {
				odeTaxValueLabel.rightText = text.replace(",",".");
			}
			else if (text.match(/\./)) {
				odeTaxValueLabel.rightText = text;
			}
			else {
				odeTaxValueLabel.rightText = "0."+text; // invoer in centen omzetten naar euro
			}
		}

	}

	function updateVATTaxValueLabel(text) {
		if (text) {
			// need to check if contains only numbers (hours) 
			if (text.match(/^[0-9]*$/)) {
				vatTaxValueLabel.rightText = text; 
			}
		}
	}

	function updateLookBackValueLabel(text) {
		if (text) {
			// need to check if contains only numbers (hours) 
			if (text.match(/^[0-9]*$/)) {
				lookBackValueLabel.rightText = text; 
			}
		}
	}

	function updateLookForwardValueLabel(text) {
		if (text) {
			// need to check if contains only numbers (hours) 
			if (text.match(/^[0-9]*$/)) {
				lookForwardValueLabel.rightText = text; 
			}
		}
	}

	function updateDomoticzHostLabel(text) {
		if (text) { 
			domoticzHostLabel.rightText = text;
		}
	}

	function updateDomoticzPortLabel(text) {
		if (text) {
			if (text.match(/^[0-9]*$/)) {
				domoticzPortLabel.rightText = text;
			}
		}
	}

	function updateDomoticzIdxLabel(text) {
		if (text) {
			if (text.match(/^[0-9]*$/)) {
				domoticzIdxLabel.rightText = text;
			}
		}
	}

	// tax toggle
	Text {
		id: taxText
		x: 30
		y: 10
		font.pixelSize: 16
		font.family: qfont.semiBold.name
		text: "Belasting meerekenen"
	}

	OnOffToggle {
		id: taxToggle
		height: 36
		anchors.left: taxText.right
		anchors.leftMargin: 20
		anchors.top: taxText.top
		leftIsSwitchedOn: false
	}
	// scale toggle
	Text {
		id: scaleText
		anchors {
			left: taxText.left
			top: taxText.bottom                       
			topMargin: 40
		}
		font.pixelSize: 16
		font.family: qfont.semiBold.name
		text: "Grafiek schalen"
	}

	OnOffToggle {
		id: scaleToggle
		height: 36
		anchors.left: taxToggle.left
		anchors.leftMargin: 0
		anchors.top: scaleText.top
		leftIsSwitchedOn: false
	}

	// dim color state toggle
	Text {
		id: dimColorText
		anchors {
			left: scaleText.left
			top: scaleText.bottom                       
			topMargin: 40
		}
		font.pixelSize: 16
		font.family: qfont.semiBold.name
		text: "Kleur tarief in dim"
	}

	OnOffToggle {
		id: dimColorToggle
		height: 36
		anchors.left: scaleToggle.left
		anchors.leftMargin: 0
		anchors.top: dimColorText.top
		leftIsSwitchedOn: false
	}

	// report to domoticz toggle
	Text {
		id: domoticzToggleText
		anchors {
			left: dimColorText.left
			top: dimColorText.bottom                       
			topMargin: 40
		}
		font.pixelSize: 16
		font.family: qfont.semiBold.name
		text: "Tarief naar Domoticz"
	}

	OnOffToggle {
		id: domoticzToggle
		height: 36
		anchors.left: dimColorToggle.left
		anchors.leftMargin: 0
		anchors.top: domoticzToggleText.top
		leftIsSwitchedOn: false
	}

	// use median or average algoritme 
	Text {
		id: algoMedianToggleText
		anchors {
			left: dimColorText.left
			top: domoticzToggleText.bottom                       
			topMargin: 40
		}
		font.pixelSize: 16
		font.family: qfont.semiBold.name
		text: "Use median as average"
	}

	OnOffToggle {
		id: algoMedianToggle
		height: 36
		anchors.left: domoticzToggle.left
		anchors.leftMargin: 0
		anchors.top: algoMedianToggleText.top
		leftIsSwitchedOn: false
	}

	// use colored bars 
	Text {
		id: coloredBarsToggleText
		anchors {
			left: dimColorText.left
			top: algoMedianToggleText.bottom                       
			topMargin: 40
		}
		font.pixelSize: 16
		font.family: qfont.semiBold.name
		text: "Show colored bars"
	}

	OnOffToggle {
		id: coloredBarsToggle
		height: 36
		anchors.left: algoMedianToggle.left
		anchors.leftMargin: 0
		anchors.top: coloredBarsToggleText.top
		leftIsSwitchedOn: false
	}

	// energy tax values
	SingleLabel {
		id: energyTaxValueLabel
		width: isNxt ? 600 : 350
		height: isNxt ? 45 : 35
		leftText: "Energie belasting"

		anchors {
			left: taxToggle.right
			leftMargin: 20
			top: taxToggle.top
			topMargin: 0 
		}

		onClicked: {
			qnumKeyboard.open("Voer energiebelasting in (ex BTW)", energyTaxValueLabel.rightText, "Euro", 1 , updateEnergyTaxValueLabel);
		}
	}

	IconButton {
		id: energyTaxValueLabelButton;
		width: 40
		iconSource: "qrc:/tsc/edit.png"

		anchors {
			left: energyTaxValueLabel.right
			leftMargin: 6
			top: energyTaxValueLabel.top
		}

		bottomClickMargin: 3
		onClicked: {
			qnumKeyboard.open("Voer energiebelasting in (ex BTW)", energyTaxValueLabel.rightText, "Euro", 1 , updateEnergyTaxValueLabel);
		}
	}
	SingleLabel {
		id: odeTaxValueLabel
		width: isNxt ? 600 : 350
		height: isNxt ? 45 : 35
		leftText: "ODE belasting"

		anchors {
			left: energyTaxValueLabel.left
			leftMargin: 0
			top: energyTaxValueLabel.bottom
			topMargin: 10 
		}

		onClicked: {
			qnumKeyboard.open("Voer ODE belasting in (ex BTW)", odeTaxValueLabel.rightText, "Euro", 1 , updateODETaxValueLabel);
		}
	}

	IconButton {
		id: odeTaxValueLabelButton;
		width: 40
		iconSource: "qrc:/tsc/edit.png"

		anchors {
			left: odeTaxValueLabel.right
			leftMargin: 6
			top: odeTaxValueLabel.top
		}

		bottomClickMargin: 3
		onClicked: {
			qnumKeyboard.open("Voer ODE belasting in (ex BTW)", odeTaxValueLabel.rightText, "Euro", 1 , updateODETaxValueLabel);
		}
	}
	SingleLabel {
		id: vatTaxValueLabel
		width: isNxt ? 600 : 350
		height: isNxt ? 45 : 35
		leftText: "BTW percentage"

		anchors {
			left: odeTaxValueLabel.left
			leftMargin: 0
			top: odeTaxValueLabel.bottom
			topMargin: 10 
		}

		onClicked: {
			qnumKeyboard.open("Voer BTW percentage in", vatTaxValueLabel.rightText, "%", 1 , updateVATTaxValueLabel);
		}
	}

	IconButton {
		id: vatTaxValueLabelButton;
		width: 40
		iconSource: "qrc:/tsc/edit.png"

		anchors {
			left: vatTaxValueLabel.right
			leftMargin: 6
			top: vatTaxValueLabel.top
		}

		bottomClickMargin: 3
		onClicked: {
			qnumKeyboard.open("Voer BTW percentage in", vatTaxValueLabel.rightText, "%", 1 , updateVATTaxValueLabel);
		}
	}
	// lookback
	SingleLabel {
		id: lookBackValueLabel
		width: isNxt ? 600 : 350
		height: isNxt ? 45 : 35
		leftText: "Uren terug"

		anchors {
			left: vatTaxValueLabel.left
			top: vatTaxValueLabel.bottom                       
			topMargin: 10
		}

		onClicked: {
			qnumKeyboard.open("Aantal uren terug", lookBackValueLabel.rightText, "Uren", 1 , updateLookBackValueLabel,lookbackforwardValidate);
		}
	}
	IconButton {
		id: lookBackValueLabelButton;
		width: 40
		iconSource: "qrc:/tsc/edit.png"

		anchors {
			left: lookBackValueLabel.right
			leftMargin: 6
			top: lookBackValueLabel.top
		}

		bottomClickMargin: 3
		onClicked: {
			qnumKeyboard.open("Aantal uren terug", lookBackValueLabel.rightText, "Uren", 1 , updateLookBackValueLabel,lookbackforwardValidate);
		}
	}


	// lookforward
	SingleLabel {
		id: lookForwardValueLabel
		width: isNxt ? 600 : 350
		height: isNxt ? 45 : 35
		leftText: "Uren vooruit"

		anchors {
			left: lookBackValueLabel.left
			top: lookBackValueLabel.bottom                       
			topMargin: 10
		}

		onClicked: {
			qnumKeyboard.open("Aantal uren vooruit", lookForwardValueLabel.rightText, "Uren", 1 , updateLookForwardValueLabel,lookbackforwardValidate);
		}
	}
	IconButton {
		id: lookForwardValueLabelButton;
		width: 40
		iconSource: "qrc:/tsc/edit.png"

		anchors {
			left: lookForwardValueLabel.right
			leftMargin: 6
			top: lookForwardValueLabel.top
		}

		bottomClickMargin: 3
		onClicked: {
			qnumKeyboard.open("Aantal uren vooruit", lookForwardValueLabel.rightText, "Uren", 1 , updateLookForwardValueLabel,lookbackforwardValidate);
		}
	}

	// domoticz
	Text {
		id: domoticzText
		font.pixelSize: 16
		font.family: qfont.semiBold.name
		text: "Domoticz alert device"
		anchors {
			left: lookForwardValueLabel.left
			top: lookForwardValueLabel.bottom                       
			topMargin: 10
		}
	}
	SingleLabel {
		id: domoticzHostLabel
		width: isNxt ? 600 : 350
		height: isNxt ? 45 : 35
		leftText: "Host"

		anchors {
			left: domoticzText.left
			top: domoticzText.bottom                       
			topMargin: 10
		}

		onClicked: {
			qkeyboard.open("Hostnaam", domoticzHostLabel.rightText, updateDomoticzHostLabel,hostnameValidate);
		}
	}
	IconButton {
		id: domoticzHostLabelButton;
		width: 40
		iconSource: "qrc:/tsc/edit.png"

		anchors {
			left: domoticzHostLabel.right
			leftMargin: 6
			top: domoticzHostLabel.top
		}

		bottomClickMargin: 3
		onClicked: {
			qkeyboard.open("Hostnaam", domoticzHostLabel.rightText, updateDomoticzHostLabel,hostnameValidate);
		}
	}


	SingleLabel {
		id: domoticzPortLabel
		width: isNxt ? 600 : 350
		height: isNxt ? 45 : 35
		leftText: "Port"

		anchors {
			left: domoticzHostLabel.left
			top: domoticzHostLabel.bottom                       
			topMargin: 10
		}

		onClicked: {
			qnumKeyboard.open("Poort", domoticzPortLabel.rightText, "Nummer", 1 , updateDomoticzPortLabel,numValidate);
		}
	}
	IconButton {
		id: domoticzPortLabelButton;
		width: 40
		iconSource: "qrc:/tsc/edit.png"

		anchors {
			left: domoticzPortLabel.right
			leftMargin: 6
			top: domoticzPortLabel.top
		}

		bottomClickMargin: 3
		onClicked: {
			qnumKeyboard.open("Poort", domoticzPortLabel.rightText, "Nummer", 1 , updateDomoticzPortLabel,numValidate);
		}
	}


	SingleLabel {
		id: domoticzIdxLabel
		width: isNxt ? 600 : 350
		height: isNxt ? 45 : 35
		leftText: "Idx"

		anchors {
			left: domoticzPortLabel.left
			top: domoticzPortLabel.bottom                       
			topMargin: 10
		}

		onClicked: {
			qnumKeyboard.open("Alert device IDX", domoticzIdxLabel.rightText, "Nummer", 1 , updateDomoticzIdxLabel,numValidate);
		}
	}
	IconButton {
		id: domoticzIdxLabelButton;
		width: 40
		iconSource: "qrc:/tsc/edit.png"

		anchors {
			left: domoticzIdxLabel.right
			leftMargin: 6
			top: domoticzIdxLabel.top
		}

		bottomClickMargin: 3
		onClicked: {
			qnumKeyboard.open("Alert device IDX", domoticzIdxLabel.rightText, "Nummer", 1 , updateDomoticzIdxLabel,numValidate);
		}
	}



}
