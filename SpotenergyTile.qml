import QtQuick 2.1
import qb.base 1.0
import qb.components 1.0
import BasicUIControls 1.0;


Tile {
	id: spotenergyTile

	// Will be called when widget instantiated
	function init() {}

	// calculate height of bar or text value
	function calculateHeight(maxHeight,tariff) {
		var h = (app.settings.scaleGraph) ?  5 + (maxHeight - 10 - 5) * ((tariff-app.minTariffValue)/(app.maxTariffValue-app.minTariffValue)) :  (maxHeight - 10) * (app.normalizeTariff(tariff)/app.normalizeTariff(app.maxTariffValue))
		return h
	}

	function pickTileTextColor() {
		if (dimState && !app.settings.showColorinDim) {
			return (typeof dimmableColors !== 'undefined') ? dimmableColors.tileTextColor : colors.tileTextColor	
		} else {
			return app.tariffTextColor(app.currentTariffUsage) 
		}

	}

	onClicked: {
		stage.openFullscreen(app.spotenergyScreenUrl);
	}

	Text {
		id: tileTitle
		anchors {
			baseline: parent.top
			baselineOffset: 30
			horizontalCenter: parent.horizontalCenter
		}
		font {
			family: qfont.regular.name
			pixelSize: qfont.tileTitle
		}
		color: (typeof dimmableColors !== 'undefined') ? dimmableColors.tileTitleColor : colors.tileTitleColor
		text: "Huidig tarief"
	}


	Text {
		id: txtTariff
		text: "\u20AC" + app.normalizeTariff(app.currentTariffUsage) 
		color: pickTileTextColor() 
		anchors {
			top: tileTitle.bottom 
			topMargin: 0
			horizontalCenter: parent.horizontalCenter
		}
		horizontalAlignment: Text.AlignHCenter
		font.pixelSize: 20 
		font.family: qfont.regular.name
	}
	Row {
		id: spotenergyTileRow 
		anchors.bottom: parent.bottom
		anchors.bottomMargin: 10
		anchors.horizontalCenter: parent.horizontalCenter
		width: parent.width - 30
		height: isNxt ? 120 : 85
	        Repeater {
			id: spotenergyRowRepeater
			model: app.datapoints
			Item {
				height: spotenergyTileRow.height
				width: (app.datapoints > 0) ? spotenergyTileRow.width / app.datapoints : 0
				Rectangle {
					id: spotenergyHourBars
					anchors.bottom: parent.bottom
					anchors.bottomMargin: 10
					anchors.horizontalCenter: parent.horizontalCenter
                                        border.width: 1
                                        border.color: dimState ? (((index + app.startHour) === app.currentHour) ? "#9ea7a8" : "#9ea7a8") : (app.settings.coloredBars ? app.barColor(index) : (((index + app.startHour) === app.currentHour) ? "#0099ff" : "#ff6600"))
                                        color: ((index + app.startHour) === app.currentHour) ? (dimState ? "#9ea7a8":"#0099ff") : ( app.settings.coloredBars ? (dimState ? "#d7e0e6":app.barColor(index)) : (dimState ? "#d7e0e6":"#ff6600"))
					height: calculateHeight(spotenergyTileRow.height,app.tariffValues[index])
					width: (spotenergyTileRow.width / app.datapoints - 2) // two pixels smaller than the parent item to keep gaps between the bars
				}
				Text {
					anchors.bottom: parent.bottom
					anchors.horizontalCenter: parent.horizontalCenter
					text: (index + app.startHour) % 24
					font.pointSize: 8
					color: (typeof dimmableColors !== 'undefined') ? dimmableColors.tileTextColor : colors.tileTextColor 
					visible: !((index + app.startHour) % 3) //show each 3 hours an x-index
				}
			}
		}
	}
	Rectangle {
		id: spotenergyQ3Line
		anchors.bottom: spotenergyTileRow.bottom
		anchors.left: spotenergyTileRow.left
		width: spotenergyTileRow.width 
		height: 1 
		opacity: 0.5
		color: dimState ? "#ffffff" : "#ff0000"
		anchors.bottomMargin: 10 + calculateHeight(spotenergyTileRow.height,app.tariffQ3)
		border.width: 0
	}
	Rectangle {
		id: spotenergyMedianLine
		anchors.bottom: spotenergyTileRow.bottom
		anchors.left: spotenergyTileRow.left
		width: spotenergyTileRow.width 
		height: 1 
		opacity: 0.5
		color: dimState ? "#ffffff" : "#ffff00"
		anchors.bottomMargin: 10 + calculateHeight(spotenergyTileRow.height,app.tariffMedian)
		border.width: 0
	}
	Rectangle {
		id: spotenergyQ1Line
		anchors.bottom: spotenergyTileRow.bottom
		anchors.left: spotenergyTileRow.left
		width: spotenergyTileRow.width
		height: 1
		opacity: 0.5
		color: dimState ? "#ffffff" : "#00ff00"
		anchors.bottomMargin: 10 + calculateHeight(spotenergyTileRow.height,app.tariffQ1)
		border.width: 0
	}
}
