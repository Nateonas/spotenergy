import QtQuick 1.1

import qb.components 1.0
import qb.base 1.0

SystrayIcon {
	id: spotenergySystrayIcon
	visible: true
	posIndex: 8000
	property string objectName : "spotenergySystray"

	onClicked: {
		stage.openFullscreen(app.spotenergyScreenUrl);
	}

	Image {
		id: imgSpotenergy
		anchors.centerIn: parent
		source: "./drawables/spotenergyIcon.png"
	}
}
