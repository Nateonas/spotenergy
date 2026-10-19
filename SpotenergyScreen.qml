import QtQuick 2.1

import qb.components 1.0

Screen {
	id: spotenergyScreen

	screenTitleIconUrl: "qrc:/tsc/spotenergyIcon.png"

	screenTitle: "SpotEnergy"


	// calculate height of bar or text value
	function calculateHeight(maxHeight,tariff) {
		var h = (app.settings.scaleGraph) ?  10 + (maxHeight - 30 - 10) * ((tariff-app.minTariffValue)/(app.maxTariffValue-app.minTariffValue)) :  (maxHeight - 10) * (app.normalizeTariff(tariff)/app.normalizeTariff(app.maxTariffValue))
		return h
	}


	Rectangle {
		id: mainRectangle
		anchors {
			top: parent.top
			bottom: parent.bottom
			left: parent.left
			right: parent.right
			leftMargin: 20               
			rightMargin: 20               
		}
		color: colors.addDeviceBackgroundRectangle
	}

	StandardButton {
		id: btnConfigScreen
		width: 150
		text: "Instellingen"
		anchors.top : mainRectangle.top
		anchors.right : mainRectangle.right
		anchors.rightMargin : 10 
		anchors.topMargin : 10 
		onClicked: {
			if (app.spotenergySettings) {
				app.spotenergySettings.show();
			}
		}
	}

	Text {
		id: tileTitle
		anchors {
			baseline: mainRectangle.top
			baselineOffset: 30
			horizontalCenter: mainRectangle.horizontalCenter
		}
		font {
			family: qfont.regular.name
			pixelSize: qfont.tileTitle
		}
		color: colors.tileTitleColor
		text: "Huidig tarief"
	}


	Text {
		id: txtTariff
		text: "\u20AC" + app.normalizeTariff(app.currentTariffUsage)
		color: app.tariffTextColor(app.currentTariffUsage)
		anchors {
			top: tileTitle.bottom
			topMargin: 0
			horizontalCenter: mainRectangle.horizontalCenter
		}
		horizontalAlignment: Text.AlignHCenter
		font.pixelSize: 30
		font.family: qfont.regular.name
	}

	Row {
		id: spotenergyScreenRow
		anchors.bottom: mainRectangle.bottom
		anchors.bottomMargin: 10
		anchors.left: mainRectangle.left
		anchors.leftMargin: 60
		anchors.right: mainRectangle.right
		anchors.rightMargin: 60

		height: isNxt ? 340 : 250
		Repeater {
			id: spotenergyRowRepeater
			model: app.settings.showQuarterHour ? app.datapointsQuarter : app.datapoints
			Item {
				property int totalPoints: app.settings.showQuarterHour ? app.datapointsQuarter : app.datapoints
				property real barValue: app.settings.showQuarterHour ? app.tariffValuesQuarter[index] : app.tariffValues[index]
				property bool isCurrent: index === (app.settings.showQuarterHour ? app.currentBarIndexQuarter : app.currentBarIndex)
				property bool isHourBoundary: app.settings.showQuarterHour && (index % 4 === 0) && (index > 0)

				property real barWidth: (totalPoints > 0) ? spotenergyScreenRow.width / totalPoints : 0
				property int barBorder: barWidth > 20 ? 5 : 1
				property int barRadius: barWidth > 20 ? 10 : 2

				height: spotenergyScreenRow.height
				width: barWidth

				// hour boundary separator in 15-min mode
				Rectangle {
					visible: isHourBoundary
					anchors.left: parent.left
					anchors.top: parent.top
					anchors.bottom: parent.bottom
					width: 1
					color: "#ffffff"
					opacity: 0.3
				}

				Rectangle {
					id: spotenergyHourBars
					anchors.bottom: parent.bottom
					anchors.bottomMargin: 30
					anchors.horizontalCenter: parent.horizontalCenter
					radius: barRadius
					border.width: barBorder
					border.color: app.settings.coloredBars ? app.barColor(barValue) : (isCurrent ? "#0099ff" : "#ff6600")
					color: isCurrent ? "#0099ff" : ( app.settings.coloredBars ? app.barColor(barValue) : "#ff6600")
					height: calculateHeight(spotenergyScreenRow.height, barValue)
					width: barWidth - barBorder
				}
				Text {
					anchors.bottom: parent.bottom
					anchors.horizontalCenter: parent.horizontalCenter
					text: app.settings.showQuarterHour ? (Math.floor(index / 4) + app.startHour) % 24 : (index + app.startHour) % 24
					font.pointSize: 12
					color: colors.tileTextColor
					visible: app.settings.showQuarterHour ? (index % 4 === 0 && !((Math.floor(index / 4) + app.startHour) % 3)) : !((index + app.startHour) % 3)
				}
			}
		}
	}		

	Rectangle {
		id: spotenergyQ3Line
		anchors.bottom: spotenergyScreenRow.bottom
		anchors.left: spotenergyScreenRow.left
		width: spotenergyScreenRow.width
		height: 2
		opacity: 0.5
		color: "#ff0000"
		anchors.bottomMargin: 30 + calculateHeight(spotenergyScreenRow.height,app.tariffQ3) 
		border.width: 0
	}

	Text {
		id: q3TariffValue
		text: "\u20AC" + app.normalizeTariff(app.tariffQ3)
		color: colors.tileTitleColor
		anchors.left: mainRectangle.left
		anchors.leftMargin: 5
		anchors.verticalCenterOffset: 0
		anchors.verticalCenter: spotenergyQ3Line.verticalCenter
		horizontalAlignment: Text.AlignHCenter
		font.pixelSize: 12
		font.family: qfont.regular.name
	}

	Rectangle {
		id: spotenergyQ2Line
		anchors.bottom: spotenergyScreenRow.bottom
		anchors.left: spotenergyScreenRow.left
		width: spotenergyScreenRow.width
		height: 2
		opacity: 0.5
		color: "#ffff00"
		anchors.bottomMargin: 30 + calculateHeight(spotenergyScreenRow.height,app.tariffMedian) 
		border.width: 0
	}
	Text {
		id: q2TariffValue
		text: "\u20AC" + app.normalizeTariff(app.tariffMedian)
		color: colors.tileTitleColor
		anchors.left: mainRectangle.left
		anchors.leftMargin: 5
		anchors.verticalCenterOffset: 0
		anchors.verticalCenter: spotenergyQ2Line.verticalCenter
		horizontalAlignment: Text.AlignHCenter
		font.pixelSize: 12
		font.family: qfont.regular.name
	}

	Rectangle {
		id: spotenergyQ1Line
		anchors.bottom: spotenergyScreenRow.bottom
		anchors.left: spotenergyScreenRow.left
		width: spotenergyScreenRow.width
		height: 2
		opacity: 0.5
		color: "#00ff00"
		anchors.bottomMargin: 30 + calculateHeight(spotenergyScreenRow.height,app.tariffQ1) 
		border.width: 0
	}
	Text {
		id: q1TariffValue
		text: "\u20AC" + app.normalizeTariff(app.tariffQ1)
		color: colors.tileTitleColor
		anchors.left: mainRectangle.left
		anchors.leftMargin: 5
		anchors.verticalCenterOffset: 0
		anchors.verticalCenter: spotenergyQ1Line.verticalCenter
		horizontalAlignment: Text.AlignHCenter
		font.pixelSize: 12
		font.family: qfont.regular.name
	}

	Text {
		id: maxTariffValueTxt
		text: "\u20AC" + app.normalizeTariff(app.maxTariffValue)
		color: colors.tileTitleColor
		anchors.right: mainRectangle.right
		anchors.rightMargin: 5
		anchors.bottom: spotenergyScreenRow.bottom
		anchors.bottomMargin: 22 + calculateHeight(spotenergyScreenRow.height,app.maxTariffValue)
		horizontalAlignment: Text.AlignHCenter
		font.pixelSize: 12
		font.family: qfont.regular.name
	}

	Text {
		id: minTariffValueTxt
		text: "\u20AC" + app.normalizeTariff(app.minTariffValue)
		color: colors.tileTitleColor
		anchors.right: mainRectangle.right
		anchors.rightMargin: 5
		anchors.bottom: spotenergyScreenRow.bottom
		anchors.bottomMargin: 22 + calculateHeight(spotenergyScreenRow.height,app.minTariffValue)
		horizontalAlignment: Text.AlignHCenter
		font.pixelSize: 12
		font.family: qfont.regular.name
	}

	Text {
		id: minMaxTxt
		text: "Min/Max"
		color: colors.tileTitleColor
		anchors.right: mainRectangle.right
		anchors.rightMargin: 5
		anchors.bottom: spotenergyScreenRow.bottom
		anchors.bottomMargin: 0 
		horizontalAlignment: Text.AlignHCenter
		font.pixelSize: 12
		font.family: qfont.regular.name
	}

	Text {
		id: laagHoogTxt
		text: "Laag/Hoog"
		color: colors.tileTitleColor
		anchors.left: mainRectangle.left
		anchors.leftMargin: 5
		anchors.bottom: spotenergyScreenRow.bottom
		anchors.bottomMargin: 0 
		horizontalAlignment: Text.AlignHCenter
		font.pixelSize: 12
		font.family: qfont.regular.name
	}
}
