import QtQuick 2.6
import QtQuick.Controls 2.2
import QtQml.Models 2.1
import QtGraphicalEffects 1.0
import "../controls-uit" as HifiControls
import "../styles-uit"
import "avatarapp"

Rectangle {
    id: root
    width: 480
	height: 706
    color: style.colors.white
    property string getAvatarsMethod: 'getAvatars'

    signal sendToScript(var message);
    function emitSendToScript(message) {
        console.debug('AvatarApp.qml: emitting sendToScript: ', JSON.stringify(message, null, '\t'));
        sendToScript(message);
    }

    ListModel { // the only purpose of this model is to convert JS object to ListElement
        id: currentAvatarModel
        dynamicRoles: true;
        function makeAvatarEntry(avatarObject) {
            clear();
            append(avatarObject);
            return get(count - 1);
        }
    }

    property var jointNames;
    property var currentAvatarSettings;

    function getAvatarName() {
        if(avatarName !== '') {
            return avatarName;
        }

        if(currentAvatar === null) {
            return '';
        }

        var avatarUrl = currentAvatar.entry.avatarUrl;
        var splitted = avatarUrl.split('/');

        return splitted[splitted.length - 1];
    }

    property string avatarName: currentAvatar ? currentAvatar.name : ''
    property string avatarUrl: currentAvatar ? currentAvatar.thumbnailUrl : null
    property bool isAvatarInFavorites: currentAvatar ? allAvatars.findAvatar(currentAvatar.name) !== undefined : false
    property int avatarWearablesCount: currentAvatar ? currentAvatar.wearables.count : 0
    property var currentAvatar: null;
    function setCurrentAvatar(avatar, bookmarkName) {

        var currentAvatarObject = allAvatars.makeAvatarObject(avatar, bookmarkName);
        currentAvatar = currentAvatarModel.makeAvatarEntry(currentAvatarObject);

        console.debug('AvatarApp.qml: currentAvatarObject: ', currentAvatarObject, 'currentAvatar: ', currentAvatar, JSON.stringify(currentAvatar.wearables, 0, 4));
        console.debug('currentAvatar.wearables: ', currentAvatar.wearables);
    }

    property url externalAvatarThumbnailUrl: '../../images/avatarapp/guy-in-circle.svg'

    function fromScript(message) {
        console.debug('AvatarApp.qml: fromScript: ', JSON.stringify(message, null, '\t'))

        if(message.method === 'initialize') {
            jointNames = message.data.jointNames;
            emitSendToScript({'method' : getAvatarsMethod});
        } else if(message.method === 'wearableUpdated') {
            adjustWearables.refreshWearable(message.entityID, message.wearableIndex, message.properties);
        } else if(message.method === 'wearablesUpdated') {
            var wearablesModel = currentAvatar.wearables;

            console.debug('handling wearablesUpdated, new wearables count:', message.wearables.length, ': old wearables: ');
            for(var i = 0; i < wearablesModel.count; ++i) {
                console.debug('wearable: ', wearablesModel.get(i).properties.id);
            }

            wearablesModel.clear();
            message.wearables.forEach(function(wearable) {
                wearablesModel.append(wearable);
            });

            console.debug('handling wearablesUpdated: new wearables: ');
            for(var i = 0; i < wearablesModel.count; ++i) {
                console.debug('wearable: ', wearablesModel.get(i).properties.id);
            }

            adjustWearables.refresh(currentAvatar);
        } else if(message.method === 'scaleChanged') {
            currentAvatar.avatarScale = message.value;
            updateCurrentAvatarInBookmarks(currentAvatar);
        } else if(message.method === 'externalAvatarApplied') {
            currentAvatar.isExternal = true;
            currentAvatar.name = allAvatars.encodedName('', true);
            currentAvatar.thumbnailUrl = externalAvatarThumbnailUrl.toString();
            updateCurrentAvatarInBookmarks(currentAvatar);
        } else if(message.method === 'settingChanged') {
            currentAvatarSettings[message.name] = message.value;
        } else if(message.method === 'changeSettings') {
            currentAvatarSettings = message.settings;
        } else if(message.method === 'bookmarkLoaded') {
            setCurrentAvatar(message.data.currentAvatar, message.data.name);
            var avatarIndex = allAvatars.findAvatarIndex(currentAvatar.name);
            allAvatars.move(avatarIndex, 0, 1);
            view.setPage(0);
        } else if(message.method === 'bookmarkAdded') {
            var avatarIndex = allAvatars.addAvatarEntry(message.bookmark, message.bookmarkName);
            updateCurrentAvatarInBookmarks(currentAvatar);
        } else if(message.method === 'bookmarkDeleted') {
            pageOfAvatars.isUpdating = true;

            var index = pageOfAvatars.findAvatarIndex(message.name);
            var absoluteIndex = view.currentPage * view.itemsPerPage + index
            console.debug('removed ', absoluteIndex, 'view.currentPage', view.currentPage,
                          'view.itemsPerPage: ', view.itemsPerPage, 'index', index, 'pageOfAvatars', pageOfAvatars, 'pageOfAvatars.count', pageOfAvatars)

            allAvatars.remove(absoluteIndex)
            pageOfAvatars.remove(index);

            var itemsOnPage = pageOfAvatars.count;
            var newItemIndex = view.currentPage * view.itemsPerPage + itemsOnPage;

            console.debug('newItemIndex: ', newItemIndex, 'allAvatars.count - 1: ', allAvatars.count - 1, 'pageOfAvatars.count:', pageOfAvatars.count);

            if(newItemIndex <= (allAvatars.count - 1)) {
                pageOfAvatars.append(allAvatars.get(newItemIndex));
            } else {
                if(!pageOfAvatars.hasGetAvatars())
                    pageOfAvatars.appendGetAvatars();
            }

            console.debug('removed ', absoluteIndex, 'newItemIndex: ', newItemIndex, 'allAvatars.count:', allAvatars.count, 'pageOfAvatars.count:', pageOfAvatars.count)
            pageOfAvatars.isUpdating = false;
        } else if(message.method === getAvatarsMethod) {
            var getAvatarsData = message.data;
            allAvatars.populate(getAvatarsData.bookmarks);
            setCurrentAvatar(getAvatarsData.currentAvatar, '');
            displayNameInput.text = getAvatarsData.displayName;
            currentAvatarSettings = getAvatarsData.currentAvatarSettings;

            console.debug('currentAvatar: ', JSON.stringify(currentAvatar, null, '\t'));
            updateCurrentAvatarInBookmarks(currentAvatar);
        } else if(message.method === 'updateAvatarInBookmarks') {
            updateCurrentAvatarInBookmarks(currentAvatar);
        } else if(message.method === 'selectAvatarEntity') {
            adjustWearables.selectWearableByID(message.entityID);
        }
    }

    function updateCurrentAvatarInBookmarks(avatar) {
        console.debug('searching avatar in bookmarks... ');

        var bookmarkAvatarIndex = allAvatars.findAvatarIndexByValue(avatar);

        if(bookmarkAvatarIndex === -1) {
            console.debug('bookmarkAvatarIndex = -1, avatar is not favorite')
            avatar.name = '';
            view.setPage(0);
        } else {
            console.debug('bookmarkAvatarIndex = ', bookmarkAvatarIndex, 'avatar is among favorites!')
            var bookmarkAvatar = allAvatars.get(bookmarkAvatarIndex);
            avatar.name = bookmarkAvatar.name;
            view.selectAvatar(bookmarkAvatar);
        }
    }

    property bool isInManageState: false

    Component.onCompleted: {
    }

    AvatarAppStyle {
        id: style
    }

    AvatarAppHeader {
        id: header
        z: 100

        property string currentPage: "Avatar"
        property bool mainPageVisible: !settings.visible && !adjustWearables.visible

        Binding on currentPage {
            when: settings.visible
            value: "Avatar Settings"
        }
        Binding on currentPage {
            when: adjustWearables.visible
            value: "Adjust Wearables"
        }
        Binding on currentPage {
            when: header.mainPageVisible
            value: "Avatar"
        }

        pageTitle: currentPage
        avatarIconVisible: mainPageVisible
        settingsButtonVisible: mainPageVisible
        onSettingsClicked: {
            settings.open(currentAvatarSettings, currentAvatar.avatarScale);
        }
    }

    Settings {
        id: settings
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom

        z: 3

        onSaveClicked: function() {
            var avatarSettings = {
                dominantHand : settings.dominantHandIsLeft ? 'left' : 'right',
                collisionsEnabled : settings.avatarCollisionsOn,
                animGraphUrl : settings.avatarAnimationJSON,
                collisionSoundUrl : settings.avatarCollisionSoundUrl
            };

            emitSendToScript({'method' : 'saveSettings', 'settings' : avatarSettings, 'avatarScale': settings.scaleValue})

            close();
        }
        onCancelClicked: function() {
            close();
        }
    }

    AdjustWearables {
        id: adjustWearables
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        jointNames: root.jointNames
        onWearableUpdated: {
            emitSendToScript({'method' : 'adjustWearable', 'entityID' : id, 'wearableIndex' : index, 'properties' : properties})
        }
        onWearableDeleted: {
            emitSendToScript({'method' : 'deleteWearable', 'entityID' : id, 'avatarName' : avatarName});
        }
        onAdjustWearablesOpened: {
            emitSendToScript({'method' : 'adjustWearablesOpened', 'avatarName' : avatarName});
        }
        onAdjustWearablesClosed: {
            emitSendToScript({'method' : 'adjustWearablesClosed', 'save' : status, 'avatarName' : avatarName});
        }
        onWearableSelected: {
            emitSendToScript({'method' : 'selectWearable', 'entityID' : id});
        }

        z: 3
    }

    Rectangle {
        id: mainBlock
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: favoritesBlock.top

        TextStyle1 {
            anchors.left: parent.left
            anchors.leftMargin: 30
            anchors.top: parent.top
            anchors.topMargin: 34
        }

        TextStyle1 {
            id: displayNameLabel
            anchors.left: parent.left
            anchors.leftMargin: 30
            anchors.top: parent.top
            anchors.topMargin: 25
            text: 'Display Name'
        }

        InputField {
            id: displayNameInput

            font.family: "Fira Sans"
            font.pixelSize: 15
            anchors.left: displayNameLabel.right
            anchors.leftMargin: 30
            anchors.verticalCenter: displayNameLabel.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 30
            width: 232

            text: 'ThisIsDisplayName'

            onEditingFinished: {
                emitSendToScript({'method' : 'changeDisplayName', 'displayName' : text})
                focus = false;
            }
        }

        ShadowImage {
            id: avatarImage
            width: 134
            height: 134
            anchors.left: displayNameLabel.left
            anchors.top: displayNameLabel.bottom
            anchors.topMargin: 31
            source: avatarUrl
        }

        AvatarWearablesIndicator {
            anchors.right: avatarImage.right
            anchors.bottom: avatarImage.bottom
            anchors.rightMargin: -radius
            anchors.bottomMargin: 6.08
            wearablesCount: avatarWearablesCount
            visible: avatarWearablesCount !== 0
        }

        Row {
            id: star
            anchors.top: avatarImage.top
            anchors.topMargin: 11
            anchors.left: avatarImage.right
            anchors.leftMargin: 30.5

            spacing: 12.3

            Image {
                width: 21.2
                height: 19.3
                source: isAvatarInFavorites ? '../../images/FavoriteIconActive.svg' : '../../images/FavoriteIconInActive.svg'
                anchors.verticalCenter: parent.verticalCenter
            }

            TextStyle5 {
                text: isAvatarInFavorites ? avatarName : "Add to Favorites"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            enabled: !isAvatarInFavorites
            anchors.fill: star
            onClicked: {
                createFavorite.onSaveClicked = function() {
                    var entry = currentAvatar.entry;
                    console.debug('was: ', JSON.stringify(entry, 0, 4));

                    var wearables = [];
                    for(var i = 0; i < currentAvatar.wearables.count; ++i) {
                        wearables.push(currentAvatar.wearables.get(i));
                    }

                    entry.avatarEntites = wearables;
                    currentAvatar.name = allAvatars.encodedName(createFavorite.favoriteNameText, currentAvatar.isExternal);
                    console.debug('became: ', JSON.stringify(entry, 0, 4));

                    emitSendToScript({'method': 'addAvatar', 'name' : currentAvatar.name});
                    createFavorite.close();
                }

                createFavorite.open(root.currentAvatar);
            }
        }

        TextStyle3 {
            id: avatarNameLabel
            text: getAvatarName()
            anchors.left: avatarImage.right
            anchors.leftMargin: 30
            anchors.top: star.bottom
            anchors.topMargin: 11
        }

        TextStyle3 {
            id: wearablesLabel
            anchors.left: avatarImage.right
            anchors.leftMargin: 30
            anchors.top: avatarNameLabel.bottom
            anchors.topMargin: 16
            color: 'black'
            text: 'Wearables'
        }

        SquareLabel {
            anchors.right: parent.right
            anchors.rightMargin: 30
            anchors.verticalCenter: avatarNameLabel.verticalCenter
            glyphText: "."
            glyphSize: 22

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    popup.showSpecifyAvatarUrl(function() {
                        var url = popup.inputText.text;
                        emitSendToScript({'method' : 'applyExternalAvatar', 'avatarURL' : url})
                    }, function(link) {
                        console.debug('link clicked', link);
                        emitSendToScript({'method' : 'navigate', 'url' : link})
                    });
                }
            }
        }

        SquareLabel {
            anchors.right: parent.right
            anchors.rightMargin: 30
            anchors.verticalCenter: wearablesLabel.verticalCenter
            glyphText: "\ue02e"

            visible: avatarWearablesCount !== 0

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    console.debug('adjustWearables.open');
                    adjustWearables.open(currentAvatar);
                }
            }
        }

        TextStyle3 {
            anchors.right: parent.right
            anchors.rightMargin: 30
            anchors.verticalCenter: wearablesLabel.verticalCenter
            font.underline: true
            text: "Add"
            color: 'black'
            visible: avatarWearablesCount === 0

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    popup.showGetWearables(function() {
                        emitSendToScript({'method' : 'navigate', 'url' : 'hifi://AvatarIsland'})
                    }, function(link) {
                        console.debug('link clicked', link);
                        emitSendToScript({'method' : 'navigate', 'url' : link})
                    });
                }
            }
        }
    }

    Rectangle {
        id: favoritesBlock
        height: 407

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        color: style.colors.lightGrayBackground

        TextStyle1 {
            id: favoritesLabel
            anchors.top: parent.top
            anchors.topMargin: 15
            anchors.left: parent.left
            anchors.leftMargin: 30
            text: "Favorites"
        }

        TextStyle8 {
            id: manageLabel
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 30
            text: isInManageState ? "Back" : "Manage"
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    isInManageState = isInManageState ? false : true;
                }
            }
        }

        Item {
            anchors.left: parent.left
            anchors.leftMargin: 30
            anchors.right: parent.right
            anchors.rightMargin: 0

            anchors.top: favoritesLabel.bottom
            anchors.topMargin: 20
            anchors.bottom: parent.bottom

            GridView {
                id: view
                anchors.fill: parent
                interactive: false;
                currentIndex: currentAvatarIndexInBookmarksPage();

                function currentAvatarIndexInBookmarksPage() {
                    return (currentAvatar && currentAvatar.name !== '' && !pageOfAvatars.isUpdating) ? pageOfAvatars.findAvatarIndex(currentAvatar.name) : -1;
                }

                property int horizontalSpacing: 18
                property int verticalSpacing: 44

                function selectAvatar(avatar) {
                    emitSendToScript({'method' : 'selectAvatar', 'name' : allAvatars.encodedName(avatar.name, avatar.isExternal)})
                }

                function deleteAvatar(avatar) {
                    emitSendToScript({'method' : 'deleteAvatar', 'name' : allAvatars.encodedName(avatar.name, avatar.isExternal)})
                }

                AvatarsModel {
                    id: allAvatars
                    externalAvatarThumbnailUrl: root.externalAvatarThumbnailUrl
                }

                property int itemsPerPage: 8
                property int totalPages: Math.ceil((allAvatars.count + 1) / itemsPerPage)
                onTotalPagesChanged: {
                    console.debug('total pages: ', totalPages)
                }

                property int currentPage: 0;
                onCurrentPageChanged: {
                    console.debug('currentPage: ', currentPage)
                    currentIndex = Qt.binding(currentAvatarIndexInBookmarksPage);
                }

                property bool hasNext: currentPage < (totalPages - 1)
                onHasNextChanged: {
                    console.debug('hasNext: ', hasNext)
                }

                property bool hasPrev: currentPage > 0
                onHasPrevChanged: {
                    console.debug('hasPrev: ', hasPrev)
                }

                function setPage(pageIndex) {
                    pageOfAvatars.isUpdating = true;
                    pageOfAvatars.clear();
                    var start = pageIndex * itemsPerPage;
                    var end = Math.min(start + itemsPerPage, allAvatars.count);

                    for(var itemIndex = 0; start < end; ++start, ++itemIndex) {
                        var avatarItem = allAvatars.get(start)
                        console.debug('getting ', start, avatarItem)
                        pageOfAvatars.append(avatarItem);
                    }

                    if(pageOfAvatars.count !== itemsPerPage)
                        pageOfAvatars.appendGetAvatars();

                    currentPage = pageIndex;
                    console.debug('switched to the page with', pageOfAvatars.count, 'items')
                    pageOfAvatars.isUpdating = false;
                }

                model: AvatarsModel {
                    id: pageOfAvatars

                    property bool isUpdating: false;
                    property var getMoreAvatarsEntry: {'thumbnailUrl' : '', 'name' : '', 'getMoreAvatars' : true}

                    function appendGetAvatars() {
                        append(getMoreAvatarsEntry);
                    }

                    function hasGetAvatars() {
                        return count != 0 && get(count - 1).getMoreAvatars
                    }

                    function removeGetAvatars() {
                        if(hasGetAvatars()) {
                            remove(count - 1)
                            console.debug('removed get avatars...');
                        }
                    }
                }

                flow: GridView.FlowLeftToRight

                cellHeight: 92 + verticalSpacing
                cellWidth: 92 + horizontalSpacing

                delegate: Item {
                    id: delegateRoot
                    height: GridView.view.cellHeight
                    width: GridView.view.cellWidth

                    Item {
                        id: container
                        width: 92
                        height: 92

                        states: [
                            State {
                                name: "hovered"
                                when: favoriteAvatarMouseArea.containsMouse;
                                PropertyChanges { target: container; y: -5 }
                                PropertyChanges { target: favoriteAvatarImage; dropShadowRadius: 10 }
                                PropertyChanges { target: favoriteAvatarImage; dropShadowVerticalOffset: 6 }
                            }
                        ]

                        property bool highlighted: delegateRoot.GridView.isCurrentItem

                        AvatarThumbnail {
                            id: favoriteAvatarImage
                            imageUrl: thumbnailUrl
                            border.color: container.highlighted ? style.colors.blueHighlight : 'transparent'
                            border.width: container.highlighted ? 4 : 0
                            wearablesCount: {
                                console.debug('getMoreAvatars: ', getMoreAvatars, 'name: ', name);
                                return !getMoreAvatars ? wearables.count : 0
                            }
                            onWearablesCountChanged: {
                                console.debug('delegate: AvatarThumbnail.wearablesCount: ', wearablesCount)
                            }

                            visible: !getMoreAvatars

                            MouseArea {
                                id: favoriteAvatarMouseArea
                                anchors.fill: parent
                                enabled: !container.highlighted
                                hoverEnabled: enabled

                                onClicked: {
                                    if(isInManageState) {
                                        var currentItem = delegateRoot.GridView.view.model.get(index);
                                        popup.showDeleteFavorite(currentItem.name, function() {
                                            view.deleteAvatar(currentItem);
                                        });
                                    } else {
                                        if(delegateRoot.GridView.view.currentIndex !== index) {
                                            var currentItem = delegateRoot.GridView.view.model.get(index);
                                            popup.showLoadFavorite(currentItem.name, function() {
                                                view.selectAvatar(currentItem);
                                            });
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: favoriteAvatarImage
                            color: '#AFAFAF'
                            opacity: 0.4
                            radius: 5
                            visible: isInManageState && !container.highlighted && thumbnailUrl !== ''
                        }

                        HiFiGlyphs {
                            anchors.fill: parent
                            text: "{"
                            visible: isInManageState && !container.highlighted && thumbnailUrl !== ''
                            horizontalAlignment: Text.AlignHCenter
                            size: 56
                        }

                        ShadowRectangle {
                            width: 92
                            height: 92
                            radius: 5
                            color: style.colors.blueHighlight
                            visible: getMoreAvatars && !isInManageState

                            HiFiGlyphs {
                                anchors.centerIn: parent

                                color: 'white'
                                size: 60
                                text: "K"
                            }

                            MouseArea {
                                anchors.fill: parent

                                onClicked: {
                                    popup.showBuyAvatars(function() {
                                        emitSendToScript({'method' : 'navigate', 'url' : 'hifi://BodyMart'})
                                    }, function(link) {
                                        console.debug('link clicked', link);
                                        emitSendToScript({'method' : 'navigate', 'url' : link})
                                    });
                                }
                            }
                        }
                    }

                    TextStyle7 {
                        id: text
                        width: 92
                        anchors.top: container.bottom
                        anchors.topMargin: 8
                        anchors.horizontalCenter: container.horizontalCenter
                        verticalAlignment: Text.AlignTop
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        text: getMoreAvatars ? 'Get More Avatars' : name
                        visible: !getMoreAvatars || !isInManageState
                    }
                }
            }

        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: 40
                height: 40
                color: 'transparent'

                PageIndicator {
                    x: 1
                    hasNext: view.hasNext
                    hasPrev: view.hasPrev
                    onClicked: view.setPage(view.currentPage - 1)
                }
            }

            spacing: 0

            Rectangle {
                width: 40
                height: 40
                color: 'transparent'

                PageIndicator {
                    x: -1
                    isPrevious: false
                    hasNext: view.hasNext
                    hasPrev: view.hasPrev
                    onClicked: view.setPage(view.currentPage + 1)
                }
            }

            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
        }
    }

    MessageBoxes {
        id: popup
    }

    CreateFavoriteDialog {
        id: createFavorite
    }
}
