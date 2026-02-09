import QtQuick 2.15
import Qt.labs.folderlistmodel 2.15
import Qt.labs.platform 1.1

Item {
    id: root
    property bool videoMode: false
    property string folder: videoMode
        ? StandardPaths.writableLocation(StandardPaths.MoviesLocation) + "/furios-camera"
        : StandardPaths.writableLocation(StandardPaths.PicturesLocation) + "/furios-camera"

    property string lastFileUrl: ""
    property string thumbnailSource: ""

    FolderListModel {
        id: model
        folder: root.folder
        showDirs: false
        nameFilters: root.videoMode ? ["*.mkv"] : ["*.jpg"]

        onStatusChanged: if (status === FolderListModel.Ready) root.pickLatest()
        onCountChanged: root.pickLatest()
    }

    function pickLatest() {
        if (model.count <= 0) {
            lastFileUrl = ""
            thumbnailSource = ""
            return
        }

        var bestUrl = ""
        var bestT = -1

        for (var i = 0; i < model.count; i++) {
            var u = model.get(i, "fileUrl")
            if (!u) continue
            var urlStr = u.toString()

            var t = fileManager.getMediaEpochMs(urlStr)
            if (t > bestT) {
                bestT = t
                bestUrl = urlStr
            }
        }

        lastFileUrl = bestUrl

        if (!lastFileUrl) {
            thumbnailSource = ""
            return
        }

        if (!videoMode) {
            thumbnailSource = lastFileUrl
        } else {
            thumbnailSource = ""
            if (typeof thumbnailGenerator !== "undefined" && thumbnailGenerator.setVideoSource)
                thumbnailGenerator.setVideoSource(lastFileUrl)
        }
    }

    Connections {
        target: (typeof thumbnailGenerator !== "undefined") ? thumbnailGenerator : null
        function onThumbnailGenerated(image) {
            if (!root.videoMode || !root.lastFileUrl) return
            root.thumbnailSource = thumbnailGenerator.toQmlImage ? thumbnailGenerator.toQmlImage(image) : image
        }
    }
}
