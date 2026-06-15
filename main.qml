import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs


ApplicationWindow {
    id: window
    width: 800
    height: 600
    visible: true
    title: "abcdef editor"

    flags: Qt.Window | Qt.FramelessWindowHint
    
    FontLoader { id: iaWriterLoader; source: "iAWriterDuoV.ttf" }

    property var theme: ({})

    background: Rectangle {
        color: theme.window ? theme.window.background : "#FFFFFF"
    }

    property bool isQuitting: false
    property string pendingFileToOpen: ""

    property int fullScreenWidth: 700
    property int defaultFullScreenWidth: 700

    Component.onCompleted: {
        theme = backend.get_theme()
        title = theme.window.title
        iaWriterLoader.source = theme.editor.fontFamily
        window.fullScreenWidth = backend.get_full_screen_width()
    }

    property int fontSize: theme.editor ? theme.editor.fontSize : 18
    property int defaultFontSize: theme.editor ? theme.editor.fontSize : 18

    signal openFileRequested(string fileUrl)
    signal saveFileRequested(string fileUrl, string text)
    signal checkBeforeQuit(string text)

    function loadDocumentText(plainText) {
        textEditor.text = plainText
    }

    function newDocument() {
        backend.clear_current_filepath()
        textEditor.text = ""
        textEditor.readOnly = false
        textEditor.forceActiveFocus()
    }

    function confirmQuit() {
        Qt.quit()
    }

    function requestOpenFile(fileUrl) {
        if (backend.is_modified(textEditor.text)) {
            window.pendingFileToOpen = fileUrl
            window.isQuitting = false
            textEditor.readOnly = true
            closeConfirmationDialog.open()
        } else {
            window.openFileRequested(fileUrl)
        }
    }


    FileDialog {
        id: openFileDialog
        title: "Open file"
        currentFolder: backend.get_working_dir_url()
        nameFilters: ["Text files (*.txt)", "All files (*)"]
        onAccepted: {
            window.requestOpenFile(openFileDialog.selectedFile)
        }
    }

    FileDialog {
        id: saveFileDialog
        title: "Save file as..."
        currentFolder: backend.get_working_dir_url()
        nameFilters: ["Text files (*.txt)", "All files (*)"]
        fileMode: FileDialog.SaveFile
        onAccepted: {
            window.saveFileRequested(saveFileDialog.selectedFile, textEditor.text)
            if (window.isQuitting) {
                Qt.quit()
            } else if (window.pendingFileToOpen !== "") {
                window.openFileRequested(window.pendingFileToOpen)
                window.pendingFileToOpen = ""
            }
        }
        onRejected: {
            window.isQuitting = false
            textEditor.readOnly = false
            textEditor.forceActiveFocus()
        }
    }

    Dialog {
        id: closeConfirmationDialog

        anchors.centerIn: parent

        modal: true
        focus: true
        padding: theme.dialog ? theme.dialog.padding : 24

        background: Rectangle {
            color: theme.dialog ? theme.dialog.background : "#FFFFFF"
            radius: theme.dialog ? theme.dialog.borderRadius : 10
            border.color: theme.dialog ? theme.dialog.borderColor : "#E0E0E0"
            border.width: theme.dialog ? theme.dialog.borderWidth : 1
        }

        contentItem: Text {
            text: "Document was modified. Save before closing?"
            wrapMode: Text.WordWrap
            color: theme.dialog ? theme.dialog.textColor : "#000000"
        }

        footer: DialogButtonBox {
            id: buttons

            property var saveButtonRef: null
            property var discardButtonRef: null
            property var cancelButtonRef: null

            padding: 12

            background: Rectangle {
                color: theme.dialog ? theme.dialog.footerBackground : "#F8F8F8"
                radius: theme.dialog ? theme.dialog.borderRadius : 10
            }

            standardButtons:
                DialogButtonBox.Save |
                DialogButtonBox.Discard |
                DialogButtonBox.Cancel

            delegate: Button {
                id: dlgBtn
                contentItem: Text {
                    text: dlgBtn.text
                    font.family: iaWriterLoader.name
                    font.pixelSize: 13
                    font.weight: 500
                    color: dlgBtn.activeFocus ? (theme.dialog ? theme.dialog.textColor : "#000000") : (theme.dialog ? theme.dialog.buttonTextColor : "#334155")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 6
                    color: dlgBtn.activeFocus ? (theme.dialog ? theme.dialog.buttonHoverBackground : "#E2E8F0") : (dlgBtn.hovered ? (theme.dialog ? theme.dialog.buttonHoverBackground : "#E2E8F0") : (theme.dialog ? theme.dialog.buttonBackground : "#F1F5F9"))
                    border.color: dlgBtn.activeFocus ? (theme.dialog ? theme.dialog.textColor : "#000000") : (theme.dialog ? theme.dialog.buttonBorderColor : "#D1D5DB")
                    border.width: dlgBtn.activeFocus ? 2 : 1
                }
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    let activeBtn = null
                    
                    if (saveButtonRef && saveButtonRef.activeFocus) {
                        activeBtn = saveButtonRef
                    } else if (discardButtonRef && discardButtonRef.activeFocus) {
                        activeBtn = discardButtonRef
                    } else if (cancelButtonRef && cancelButtonRef.activeFocus) {
                        activeBtn = cancelButtonRef
                    }

                    if (activeBtn) {
                        event.accepted = true
                        activeBtn.click()
                    }
                }
            }

            Component.onCompleted: {
                let saveBtn = standardButton(DialogButtonBox.Save)
                let discardBtn = standardButton(DialogButtonBox.Discard)
                let cancelBtn = standardButton(DialogButtonBox.Cancel)

                if (saveBtn && discardBtn && cancelBtn) {
                    saveButtonRef = saveBtn
                    discardButtonRef = discardBtn
                    cancelButtonRef = cancelBtn

                    saveBtn.focus = true
                    saveBtn.highlighted = true
                    saveBtn.forceActiveFocus()

                    saveBtn.KeyNavigation.right = discardBtn
                    discardBtn.KeyNavigation.left = saveBtn
                    discardBtn.KeyNavigation.right = cancelBtn
                    cancelBtn.KeyNavigation.left = discardBtn

                    saveBtn.KeyNavigation.tab = discardBtn
                    discardBtn.KeyNavigation.tab = cancelBtn
                    cancelBtn.KeyNavigation.tab = saveBtn

                    saveBtn.activeFocusChanged.connect(function() { if (saveBtn.activeFocus) buttons.currentIndex = 0 })
                    discardBtn.activeFocusChanged.connect(function() { if (discardBtn.activeFocus) buttons.currentIndex = 1 })
                    cancelBtn.activeFocusChanged.connect(function() { if (cancelBtn.activeFocus) buttons.currentIndex = 2 })
                }
            }

            onClicked: function(button) {
                if (button === saveButtonRef) {
                    closeConfirmationDialog.close()
                    textEditor.readOnly = false
                    if (backend.has_filepath()) {
                        window.saveFileRequested("", textEditor.text)
                        if (window.isQuitting) {
                            Qt.quit()
                        } else if (window.pendingFileToOpen !== "") {
                            window.openFileRequested(window.pendingFileToOpen)
                            window.pendingFileToOpen = ""
                        }
                    } else {
                        saveFileDialog.currentFolder = backend.get_working_dir_url()
                        saveFileDialog.open()
                    }
                } else if (button === discardButtonRef) {
                    closeConfirmationDialog.close()
                    textEditor.readOnly = false
                    if (window.isQuitting) {
                        Qt.quit()
                    } else if (window.pendingFileToOpen !== "") {
                        window.openFileRequested(window.pendingFileToOpen)
                        window.pendingFileToOpen = ""
                    }
                } else {
                    closeConfirmationDialog.close()
                    window.isQuitting = false
                    window.pendingFileToOpen = ""
                    textEditor.readOnly = false
                    textEditor.forceActiveFocus()
                }
            }
        }

        onOpened: {
            Qt.callLater(function() {
                let saveBtn = buttons.standardButton(DialogButtonBox.Save)
                if (saveBtn) {
                    saveBtn.forceActiveFocus()
                }
            })
        }
    }

    Dialog {
        id: helpDialog

        anchors.centerIn: parent
        width: 480
        modal: true
        focus: true
        padding: 0

        background: Rectangle {
            color: theme.dialog ? theme.dialog.background : "#FFFFFF"
            radius: theme.dialog ? theme.dialog.borderRadius : 10
            border.color: theme.dialog ? theme.dialog.borderColor : "#E0E0E0"
            border.width: theme.dialog ? theme.dialog.borderWidth : 1
        }

        contentItem: Column {
            spacing: 0

            Rectangle {
                width: parent.width
                height: 48
                color: "transparent"

                Text {
                    text: "Keyboard Shortcuts"
                    font.family: iaWriterLoader.name
                    font.pixelSize: theme.helpDialog ? theme.helpDialog.titleFontSize : 16
                    font.weight: theme.helpDialog ? theme.helpDialog.titleFontWeight : 600
                    color: theme.helpDialog ? theme.helpDialog.titleColor : "#0F172A"
                    anchors.centerIn: parent
                }

                Text {
                    text: "v1.0.10"
                    font.family: iaWriterLoader.name
                    font.pixelSize: 11
                    color: theme.helpDialog ? theme.helpDialog.descriptionColor : "#475569"
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: theme.helpDialog ? theme.helpDialog.dividerColor : "#E2E8F0"
                    anchors.bottom: parent.bottom
                }
            }

            Column {
                width: parent.width
                padding: 20
                spacing: 0

                Repeater {
                    model: [
                        { keys: "Ctrl + O",              desc: "Open file" },
                        { keys: "Ctrl + N",              desc: "New document" },
                        { keys: "Ctrl + S",              desc: "Save file" },
                        { keys: "Ctrl + Q / W",          desc: "Quit" },
                        { keys: "Ctrl + \\  /  Ctrl + P", desc: "Toggle command palette" },
                        { keys: "Alt + Enter",           desc: "Toggle fullscreen" },
                        { keys: "F1",                    desc: "Show this help" },
                        { keys: "",                      desc: "" },
                        { keys: "Ctrl + =",              desc: "Increase font size" },
                        { keys: "Ctrl + -",              desc: "Decrease font size" },
                        { keys: "Ctrl + 0",              desc: "Reset font size" },
                        { keys: "",                      desc: "" },
                        { keys: "Ctrl + Alt + =",        desc: "Widen editor (fullscreen only)" },
                        { keys: "Ctrl + Alt + -",        desc: "Narrow editor (fullscreen only)" },
                        { keys: "Ctrl + Alt + 0",        desc: "Reset editor width (fullscreen only)" }
                    ]

                    delegate: Column {
                        width: helpDialog.width - 40
                        spacing: 0

                        Item {
                            width: parent.width
                            height: modelData.keys === "" ? 12 : 32

                            Rectangle {
                                visible: modelData.keys === ""
                                width: 40
                                height: 1
                                color: theme.helpDialog ? theme.helpDialog.dividerColor : "#E2E8F0"
                                anchors.centerIn: parent
                            }

                            Row {
                                visible: modelData.keys !== ""
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                spacing: 0

                                Rectangle {
                                    width: keysLabel.implicitWidth + 16
                                    height: theme.helpDialog ? theme.helpDialog.keyBadgeHeight : 24
                                    radius: theme.helpDialog ? theme.helpDialog.keyBadgeBorderRadius : 5
                                    color: theme.helpDialog ? theme.helpDialog.keyBadgeBackground : "#F1F5F9"
                                    border.color: theme.helpDialog ? theme.helpDialog.keyBadgeBorderColor : "#E2E8F0"
                                    border.width: theme.helpDialog ? theme.helpDialog.keyBadgeBorderWidth : 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: keysLabel
                                        text: modelData.keys
                                        font.family: theme.helpDialog ? theme.helpDialog.keyFontFamily : "Consolas"
                                        font.pixelSize: theme.helpDialog ? theme.helpDialog.keyFontSize : 12
                                        color: theme.helpDialog ? theme.helpDialog.keyTextColor : "#334155"
                                        anchors.centerIn: parent
                                    }
                                }

                                Item {
                                    width: 16
                                    height: 1
                                }

                                Text {
                                    text: modelData.desc
                                    font.family: iaWriterLoader.name
                                    font.pixelSize: theme.helpDialog ? theme.helpDialog.descriptionFontSize : 13
                                    color: theme.helpDialog ? theme.helpDialog.descriptionColor : "#475569"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        footer: DialogButtonBox {
            standardButtons: DialogButtonBox.Ok

            padding: 12

            background: Rectangle {
                color: theme.dialog ? theme.dialog.footerBackground : "#F8F8F8"
                radius: theme.dialog ? theme.dialog.borderRadius : 10
            }

            delegate: Button {
                id: helpBtn
                contentItem: Text {
                    text: helpBtn.text
                    font.family: iaWriterLoader.name
                    font.pixelSize: 13
                    font.weight: 500
                    color: theme.dialog ? theme.dialog.buttonTextColor : "#334155"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 6
                    color: helpBtn.hovered ? (theme.dialog ? theme.dialog.buttonHoverBackground : "#E2E8F0") : (theme.dialog ? theme.dialog.buttonBackground : "#F1F5F9")
                    border.color: theme.dialog ? theme.dialog.buttonBorderColor : "#D1D5DB"
                    border.width: 1
                }
            }

            onAccepted: helpDialog.close()
        }

        onOpened: {
            let okBtn = standardButton(DialogButtonBox.Ok)
            if (okBtn) {
                okBtn.forceActiveFocus()
            }
        }
    }

    MouseArea {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        z: 0

        onPressed: window.startSystemMove()
    }

    ScrollView {
        id: scrollViewer
        width: window.visibility === ApplicationWindow.FullScreen
               ? Math.min(parent.width - 80, window.fullScreenWidth)
               : Math.min(parent.width - 80, 700)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 40
        anchors.bottomMargin: 40
        clip: true

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AlwaysOff
        }

        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AlwaysOff
        }

        TextEdit {
            id: textEditor
            width: scrollViewer.availableWidth
            
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            
            selectionColor: theme.editor ? theme.editor.selectionColor : "#C2E8FF"
            selectedTextColor: theme.editor ? theme.editor.selectedTextColor : "#1A1A1A"

            font.family: iaWriterLoader.name
            font.pixelSize: window.fontSize
            font.weight: theme.editor ? theme.editor.fontWeight : 475
            color: theme.editor ? theme.editor.textColor : "#000000"
            
            font.features: {
                "calt": 1,
                "liga": 1,
                "zero": 0,
                "tnum": 0,
                "pnum": 1,
                "ss01": 0
            }
            renderType: TextEdit.NativeRendering
            font.hintingPreference: Font.PreferFullHinting

            
            cursorDelegate: Rectangle {
                id: caret
                width: theme.editor ? theme.editor.caretWidth : 4
                color: theme.editor ? theme.editor.caretColor : "#007AFF" 
                radius: theme.editor ? theme.editor.caretRadius : 2        
                visible: textEditor.cursorVisible

                SequentialAnimation on opacity {
                    running: caret.visible 
                    loops: Animation.Infinite 
                    
                    NumberAnimation { to: 0; duration: 500; easing.type: Easing.InOutQuad } 
                    NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutQuad } 
                }
            }

            Keys.onPressed: function(event) {
                // Page Up
                if (event.key === Qt.Key_PageUp) {
                    event.accepted = true
                    let flick = scrollViewer.contentItem
                    let pageHeight = flick.height - 20
                    let linesPerPage = Math.max(1, Math.floor(pageHeight / (textEditor.font.pixelSize * 1.4)))
                    let textBefore = textEditor.text.substring(0, textEditor.cursorPosition)
                    let cursorLine = textBefore.split("\n").length - 1
                    let targetLine = Math.max(0, cursorLine - linesPerPage)
                    let pos = 0
                    let lines = textEditor.text.split("\n")
                    for (let i = 0; i < Math.min(targetLine, lines.length); i++) {
                        pos += lines[i].length + 1
                    }
                    textEditor.cursorPosition = Math.min(pos, textEditor.text.length)
                    textEditor.ensureCursorVisible()
                    return
                }

                // Page Down
                if (event.key === Qt.Key_PageDown) {
                    event.accepted = true
                    let flick = scrollViewer.contentItem
                    let pageHeight = flick.height - 20
                    let linesPerPage = Math.max(1, Math.floor(pageHeight / (textEditor.font.pixelSize * 1.4)))
                    let textBefore = textEditor.text.substring(0, textEditor.cursorPosition)
                    let cursorLine = textBefore.split("\n").length - 1
                    let targetLine = cursorLine + linesPerPage
                    let pos = 0
                    let lines = textEditor.text.split("\n")
                    for (let i = 0; i < Math.min(targetLine, lines.length); i++) {
                        pos += lines[i].length + 1
                    }
                    textEditor.cursorPosition = Math.min(pos, textEditor.text.length)
                    textEditor.ensureCursorVisible()
                    return
                }

                // Ctrl + \ or Ctrl + P
                if ((event.key === Qt.Key_Backslash || event.key === Qt.Key_P) && (event.modifiers & Qt.ControlModifier)) {
                    event.accepted = true
                    if (commandPalettePopup.visible) {
                        commandPalettePopup.close()
                    } else {
                        commandPalettePopup.open()
                    }
                    return
                }

                //fullscreen
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.AltModifier)) {
                    event.accepted = true
                    if (window.visibility === ApplicationWindow.FullScreen) {
                        window.visibility = ApplicationWindow.Windowed
                    } else {
                        window.visibility = ApplicationWindow.FullScreen
                    }
                    return
                }

                // Ctrl + Alt + Plus 
                if ((event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) && 
                    (event.modifiers & Qt.ControlModifier) && 
                    (event.modifiers & Qt.AltModifier)) {
                    event.accepted = true
                    if (window.visibility === ApplicationWindow.FullScreen) {
                        window.fullScreenWidth = Math.min(window.fullScreenWidth + 50, window.width - 80)
                        backend.save_full_screen_width(window.fullScreenWidth)
                    }
                    return
                }

                // Ctrl + Plus 
                if ((event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) && (event.modifiers & Qt.ControlModifier)) {
                    event.accepted = true
                    window.fontSize = Math.min(window.fontSize + 2, 72)
                    return
                }

                // Ctrl + Alt + Minus 
                if ((event.key === Qt.Key_Minus || event.key === Qt.Key_Hyphen || event.key === Qt.Key_Underscore) && 
                    (event.modifiers & Qt.ControlModifier) && 
                    (event.modifiers & Qt.AltModifier)) {
                    event.accepted = true
                    if (window.visibility === ApplicationWindow.FullScreen) {
                        window.fullScreenWidth = Math.max(window.fullScreenWidth - 50, 200)
                        backend.save_full_screen_width(window.fullScreenWidth)
                    }
                    return
                }

                // Ctrl + Minus 
                if ((event.key === Qt.Key_Minus || event.key === Qt.Key_Hyphen) && (event.modifiers & Qt.ControlModifier)) {
                    event.accepted = true
                    window.fontSize = Math.max(window.fontSize - 2, 10)
                    return
                }

                // Ctrl + Alt + 0 
                if (event.key === Qt.Key_0 && 
                    (event.modifiers & Qt.ControlModifier) && 
                    (event.modifiers & Qt.AltModifier)) {
                    event.accepted = true
                    if (window.visibility === ApplicationWindow.FullScreen) {
                        window.fullScreenWidth = window.defaultFullScreenWidth
                        backend.save_full_screen_width(window.fullScreenWidth)
                    }
                    return
                }

                // Ctrl + 0 
                if (event.key === Qt.Key_0 && (event.modifiers & Qt.ControlModifier)) {
                    event.accepted = true
                    window.fontSize = window.defaultFontSize
                    return
                }

                // Ctrl + Q or Ctrl + W quit
                if ((event.key === Qt.Key_Q || event.key === Qt.Key_W) && (event.modifiers & Qt.ControlModifier)) {
                    event.accepted = true
                    window.isQuitting = true
                    textEditor.readOnly = true
                    window.checkBeforeQuit(textEditor.text)
                    return
                }

                // Ctrl + S
                if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                    event.accepted = true
                    window.saveFileRequested("", textEditor.text)
                    return
                }

                // Ctrl + O
                if (event.key === Qt.Key_O && (event.modifiers & Qt.ControlModifier)) {
                    event.accepted = true
                    openFileDialog.currentFolder = backend.get_working_dir_url()
                    openFileDialog.open()
                    return
                }

                // Ctrl + N
                if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
                    event.accepted = true
                    window.newDocument()
                    return
                }

                // F1
                if (event.key === Qt.Key_F1) {
                    event.accepted = true
                    helpDialog.open()
                    return
                }
            }

            function ensureCursorVisible() {
                let flick = scrollViewer.contentItem
                let margin = 10

                if (cursorRectangle.y < flick.contentY + margin) {
                    flick.contentY = Math.max(0, cursorRectangle.y - margin)
                }

                if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height - margin) {
                    flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height + margin
                }
            }

            onCursorRectangleChanged: ensureCursorVisible()

            Text {
                text: "Abcdef..."
                font: parent.font
                color: theme.editor ? theme.editor.placeholderColor : "#999999"
                visible: parent.text.length === 0
                renderType: Text.NativeRendering
            }
            
            Component.onCompleted: textEditor.forceActiveFocus()
        }
    }

    MouseArea {
        width: 15
        height: 15
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        z: 10
        cursorShape: Qt.SizeFDiagCursor
        onPressed: window.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
    }

    function openSaveDialog() {
        saveFileDialog.currentFolder = backend.get_working_dir_url()
        saveFileDialog.open()
    }

    function showCloseDialog() {
        textEditor.readOnly = true
        closeConfirmationDialog.open()
    }

    // Background overlay to close palette on click outside
    MouseArea {
        anchors.fill: parent
        visible: commandPalettePopup.visible
        z: 99
        onClicked: {
            commandPalettePopup.close()
        }
    }

    // Command Palette Popup
    Item {
        id: commandPalettePopup
        width: 600
        height: 400
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 50
        z: 100
        visible: false

        // Concentric shadow rectangles for a soft drop-shadow
        Rectangle { anchors.fill: parent; anchors.margins: -1; color: theme.commandPalette ? theme.commandPalette.shadowColor : "#000000"; opacity: 0.05; radius: 9 }
        Rectangle { anchors.fill: parent; anchors.margins: -3; color: theme.commandPalette ? theme.commandPalette.shadowColor : "#000000"; opacity: 0.03; radius: 11 }
        Rectangle { anchors.fill: parent; anchors.margins: -6; color: theme.commandPalette ? theme.commandPalette.shadowColor : "#000000"; opacity: 0.015; radius: 14 }
        Rectangle { anchors.fill: parent; anchors.margins: -10; color: theme.commandPalette ? theme.commandPalette.shadowColor : "#000000"; opacity: 0.005; radius: 18 }

        Rectangle {
            anchors.fill: parent
            color: theme.commandPalette ? theme.commandPalette.background : "#FFFFFF"
            radius: theme.commandPalette ? theme.commandPalette.borderRadius : 8
            border.color: theme.commandPalette ? theme.commandPalette.borderColor : "#E2E8F0"
            border.width: theme.commandPalette ? theme.commandPalette.borderWidth : 1
            clip: true

            Column {
                anchors.fill: parent
                spacing: 0

                // Search input container
                Rectangle {
                    width: parent.width
                    height: 50
                    color: theme.commandPalette ? theme.commandPalette.background : "#FFFFFF"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 15
                        anchors.rightMargin: 15
                        spacing: 10

                        Text {
                            text: ">"
                            font.family: iaWriterLoader.name
                            font.pixelSize: 18
                            font.weight: 500
                            color: theme.commandPalette ? theme.commandPalette.promptColor : "#64748B"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        TextField {
                            id: filterInput
                            width: parent.width - 30
                            height: parent.height
                            placeholderText: "Search files in " + backend.get_working_dir()
                            placeholderTextColor: theme.commandPalette ? theme.commandPalette.placeholderColor : "#94A3B8"
                            font.family: iaWriterLoader.name
                            font.pixelSize: 16
                            color: theme.commandPalette ? theme.commandPalette.inputTextColor : "#0F172A"
                            
                            background: Rectangle {
                                color: "transparent"
                            }

                            onTextChanged: {
                                commandPalettePopup.updateFilteredList()
                            }

                            Keys.onPressed: function(event) {
                                if ((event.key === Qt.Key_Backslash || event.key === Qt.Key_P) && (event.modifiers & Qt.ControlModifier)) {
                                    event.accepted = true
                                    commandPalettePopup.close()
                                    return
                                }
                                if (event.key === Qt.Key_Up) {
                                    event.accepted = true
                                    if (resultsList.count > 0) {
                                        resultsList.currentIndex = (resultsList.currentIndex - 1 + resultsList.count) % resultsList.count
                                    }
                                } else if (event.key === Qt.Key_Down) {
                                    event.accepted = true
                                    if (resultsList.count > 0) {
                                        resultsList.currentIndex = (resultsList.currentIndex + 1) % resultsList.count
                                    }
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    event.accepted = true
                                    commandPalettePopup.selectAndOpenCurrent()
                                } else if (event.key === Qt.Key_Escape) {
                                    event.accepted = true
                                    commandPalettePopup.close()
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: theme.commandPalette ? theme.commandPalette.borderColor : "#E2E8F0"
                        anchors.bottom: parent.bottom
                    }
                }

                // List of results
                Item {
                    width: parent.width
                    height: parent.height - 50

                    ListView {
                        id: resultsList
                        anchors.fill: parent
                        clip: true
                        model: ListModel { id: resultsModel }
                        currentIndex: -1

                        delegate: Rectangle {
                            width: resultsList.width
                            height: 50
                            color: ListView.isCurrentItem ? (theme.commandPalette ? theme.commandPalette.hoverColor : "#F1F5F9") : "transparent"

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    resultsList.currentIndex = index
                                    commandPalettePopup.selectAndOpenCurrent()
                                }
                                onEntered: {
                                    resultsList.currentIndex = index
                                }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                spacing: 10

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width

                                    Text {
                                        text: model.name
                                        font.family: iaWriterLoader.name
                                        font.pixelSize: theme.commandPalette ? theme.commandPalette.fileNameFontSize : 14
                                        font.weight: 500
                                        color: theme.commandPalette ? theme.commandPalette.fileNameColor : "#0F172A"
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Text {
                                        text: model.rel_path
                                        font.family: iaWriterLoader.name
                                        font.pixelSize: theme.commandPalette ? theme.commandPalette.filePathFontSize : 11
                                        color: theme.commandPalette ? theme.commandPalette.filePathColor : "#64748B"
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }
                            }
                        }
                    }

                    // No results placeholder
                    Text {
                        anchors.centerIn: parent
                        text: "No files found"
                        font.family: iaWriterLoader.name
                        font.pixelSize: 14
                        color: theme.commandPalette ? theme.commandPalette.noResultsColor : "#94A3B8"
                        visible: resultsModel.count === 0
                    }
                }
            }
        }

        // JS Array to hold all files retrieved from backend
        property var allFiles: []

        function open() {
            allFiles = backend.get_files_list()
            filterInput.text = ""
            updateFilteredList()
            visible = true
            filterInput.forceActiveFocus()
        }

        function close() {
            visible = false
            textEditor.forceActiveFocus()
        }

        function updateFilteredList() {
            let query = filterInput.text.trim().toLowerCase()
            let results = []
            
            if (query === "") {
                results = allFiles.slice(0, 50)
            } else {
                let substringMatches = []
                let fuzzyMatches = []
                
                for (let i = 0; i < allFiles.length; i++) {
                    let file = allFiles[i]
                    let name = file.name.toLowerCase()
                    let rel = file.rel_path.toLowerCase()
                    
                    if (name.indexOf(query) !== -1 || rel.indexOf(query) !== -1) {
                        substringMatches.push(file)
                    } else if (fuzzyMatch(rel, query)) {
                        fuzzyMatches.push(file)
                    }
                }
                
                results = substringMatches.concat(fuzzyMatches).slice(0, 100)
            }
            
            resultsModel.clear()
            for (let j = 0; j < results.length; j++) {
                resultsModel.append(results[j])
            }
            
            if (resultsModel.count > 0) {
                resultsList.currentIndex = 0
            } else {
                resultsList.currentIndex = -1
            }
        }

        function fuzzyMatch(text, query) {
            let t = text.toLowerCase()
            let q = query.toLowerCase()
            let index = 0
            for (let i = 0; i < q.length; i++) {
                index = t.indexOf(q[i], index)
                if (index === -1) return false
                index++
            }
            return true
        }

        function selectAndOpenCurrent() {
            if (resultsList.currentIndex >= 0 && resultsList.currentIndex < resultsModel.count) {
                let item = resultsModel.get(resultsList.currentIndex)
                close()
                window.requestOpenFile(item.abs_path)
            }
        }
    }

    // Drag & Drop Area for opening files
    DropArea {
        id: dropArea
        anchors.fill: parent
        z: 97 // Below click-outside overlay, but above text editor
        
        onEntered: function(drag) {
            if (drag.hasUrls) {
                drag.acceptProposedAction()
                dropOverlay.visible = true
            }
        }
        
        onExited: {
            dropOverlay.visible = false
        }
        
        onDropped: function(drop) {
            dropOverlay.visible = false
            if (drop.hasUrls && drop.urls.length > 0) {
                window.requestOpenFile(drop.urls[0].toString())
            }
        }
    }

    Rectangle {
        id: dropOverlay
        anchors.fill: parent
        color: theme.dropOverlay ? theme.dropOverlay.backgroundColor : "#F0F9FF"
        opacity: theme.dropOverlay ? theme.dropOverlay.backgroundOpacity : 0.95
        border.color: theme.dropOverlay ? theme.dropOverlay.borderColor : "#007AFF"
        border.width: theme.dropOverlay ? theme.dropOverlay.borderWidth : 3
        visible: false
        z: 98
        
        Column {
            anchors.centerIn: parent
            spacing: 15
            
            Text {
                text: "\uD83D\uDCE5"
                font.pixelSize: theme.dropOverlay ? theme.dropOverlay.iconFontSize : 48
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Drop a file here to open it"
                font.family: iaWriterLoader.name
                font.pixelSize: theme.dropOverlay ? theme.dropOverlay.titleFontSize : 18
                font.weight: 500
                color: theme.dropOverlay ? theme.dropOverlay.titleColor : "#0F172A"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "Supported formats: .txt and .md"
                font.family: iaWriterLoader.name
                font.pixelSize: theme.dropOverlay ? theme.dropOverlay.subtitleFontSize : 14
                color: theme.dropOverlay ? theme.dropOverlay.subtitleColor : "#64748B"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}