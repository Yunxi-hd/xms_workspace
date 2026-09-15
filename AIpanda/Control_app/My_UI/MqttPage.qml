import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

/*
   WsPage — WebSocket 通讯设置与设备自动发现页面（线性布局版，绝对不重叠）

   使用流程（不用记 IP！）：
     1. ESP32 小车通电 → 连上 WiFi → 自动 UDP 广播自己的 IP
     2. Qt 端点"搜索设备" → 自动收到广播 → 设备列表显示
     3. 点列表中的设备 → IP 端口自动填入 + 保存
     4. 点"连接"按钮 → 建立 ws://<IP>:8080/ws

   仍然保留手动输入 IP 的文本框（搜索不到时降级方案）。
*/

Item {
    id: page

    Rectangle {
        anchors.fill: parent
        color: "#161616"
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 2
        contentWidth: availableWidth

        // ============================================================
        // 所有控件线性平铺在一个 ColumnLayout 里，从上到下声明顺序排布
        // → 100% 不会重叠，高度自适应
        // ============================================================
        ColumnLayout {
            width: parent.width - 4
            spacing: 0

            // -------------------- 标题区 --------------------
            Label {
                text: qsTr("WebSocket 通讯设置")
                color: "#cccccc"
                font.pixelSize: 20
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                Layout.bottomMargin: 4
            }
            Label {
                text: qsTr("当前目标：ws://%1:%2%3").arg(MqttManager.serverHost).arg(MqttManager.serverPort).arg(MqttManager.serverPath)
                color: "#888888"
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 14
            }

            // ============================================================
            // 区域 1：自动搜索设备（线性平铺，不套额外 Rectangle）
            // ============================================================
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                Layout.bottomMargin: 2

                Label {
                    text: qsTr("① 自动搜索设备")
                    color: "#cccccc"
                    font.pixelSize: 15
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                // 搜索按钮
                Rectangle {
                    implicitWidth: MqttManager.discovering ? 110 : 92
                    implicitHeight: 34
                    radius: 6
                    color: MqttManager.discovering ? "#555555" : "#8e44ad"
                    scale: ma1.pressed ? 0.94 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Text {
                        anchors.centerIn: parent
                        text: MqttManager.discovering ? qsTr("搜索中...") : qsTr("搜索设备")
                        color: "#ffffff"; font.pixelSize: 13; font.bold: true
                    }
                    MouseArea { id: ma1; anchors.fill: parent
                        enabled: !MqttManager.discovering
                        onClicked: MqttManager.startDiscovery()
                    }
                }
            }

            // 搜索中提示
            Label {
                visible: MqttManager.discovering
                text: qsTr("  正在监听 UDP 广播…请确保 ESP32 与电脑连在同一个 WiFi 下")
                color: "#f39c12"
                font.pixelSize: 12
                Layout.leftMargin: 14
                Layout.topMargin: 2
                Layout.bottomMargin: 2
            }

            // 搜到的设备列表（ListView 本身显式 preferredHeight，Layout 不会算错高度）
            ListView {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                Layout.topMargin: 4
                Layout.bottomMargin: 6

                // 高度 = 设备数 × 每行高度 + 上下 2px 内边距；最多 120 像素超出则滚动
                Layout.preferredHeight: {
                    if (MqttManager.discoveredDevices.length === 0) return 1
                    var h = MqttManager.discoveredDevices.length * 38 + 4
                    return h > 124 ? 124 : h
                }
                visible: MqttManager.discoveredDevices.length > 0
                clip: true

                model: MqttManager.discoveredDevices

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 36
                    color: index % 2 === 0 ? "#1a1a1a" : "#202020"
                    border {
                        color: mouseArea1.containsMouse ? "#c0392b" : "#3a3a3a"
                        width: 1
                    }
                    radius: 5
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 8
                        Label {
                            text: "●"; color: "#27ae60"; font.pixelSize: 14
                        }
                        Label {
                            text: model.modelData
                            color: "#dddddd"; font.pixelSize: 13
                            Layout.fillWidth: true
                            font.family: "Consolas, monospace"
                        }
                        Label {
                            text: qsTr("点击选中 →")
                            color: "#aaaaaa"; font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: mouseArea1
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: MqttManager.selectDiscoveredDevice(index)
                    }
                }
            }

            // 提示：搜索不到时用下面手动填
            Label {
                text: qsTr("  搜不到设备时，请在下方手动输入 IP、端口和路径")
                color: "#7f8c8d"
                font.pixelSize: 12
                Layout.leftMargin: 14
                Layout.bottomMargin: 6
            }

            // -------------------- 分隔 --------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                Layout.topMargin: 4
                Layout.bottomMargin: 8
                height: 1
                color: "#2e2e2e"
            }

            // ============================================================
            // 区域 2：手动输入参数（两列 SettingRow，和原 MqttPage 风格一致）
            // ============================================================
            Label {
                text: qsTr("② 手动输入参数")
                color: "#cccccc"
                font.pixelSize: 15
                font.bold: true
                Layout.leftMargin: 14
                Layout.bottomMargin: 4
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                Layout.bottomMargin: 8
                spacing: 20

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 8
                    SettingRow { label: qsTr("服务器 IP"); value: MqttManager.serverHost; onEdited: t => MqttManager.serverHost = t }
                    SettingRow { label: qsTr("路径");       value: MqttManager.serverPath; onEdited: t => MqttManager.serverPath = t }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 8
                    SettingRow { label: qsTr("端口");       value: MqttManager.serverPort.toString(); onEdited: t => MqttManager.serverPort = parseInt(t) || 8080 }
                    Item { Layout.preferredHeight: 36; Layout.fillWidth: true }
                }
            }

            // -------------------- 操作按钮行 --------------------
            RowLayout {
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                Layout.topMargin: 2
                Layout.bottomMargin: 10
                spacing: 14

                OpBtn { text: qsTr("保存"); btnColor: "#2980b9"; onClicked: MqttManager.saveSettings() }
                OpBtn {
                    text: MqttManager.connected ? qsTr("已连接") : qsTr("连接")
                    btnColor: MqttManager.connected ? "#555555" : "#27ae60"
                    onClicked: { if (!MqttManager.connected) MqttManager.connectToBroker() }
                }
                OpBtn {
                    text: qsTr("断开")
                    btnColor: MqttManager.connected ? "#c0392b" : "#555555"
                    onClicked: { if (MqttManager.connected) MqttManager.disconnectFromBroker() }
                }
            }

            // -------------------- 分隔线 --------------------
            Rectangle {
                Layout.fillWidth: true; height: 1; color: "#333333"
                Layout.leftMargin: 12
                Layout.rightMargin: 12
            }

            // -------------------- 收发报文区 --------------------
            Label {
                text: qsTr("收发报文")
                color: "#888888"
                font.pixelSize: 13
                Layout.leftMargin: 14
                Layout.topMargin: 6
                Layout.bottomMargin: 2
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(140, page.height * 0.30)
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.topMargin: 4
                Layout.bottomMargin: 6

                TextArea {
                    id: chatLog
                    readOnly: true
                    text: MqttManager.receivedMessages
                    property int savedCursor: 0
                    // 新内容到来时保持当前滚动位置，不自动跳到顶部或底部
                    onTextChanged: cursorPosition = Math.min(savedCursor, length)
                    onCursorPositionChanged: savedCursor = cursorPosition
                    color: "#cccccc"
                    font.pixelSize: 13
                    font.family: "Consolas, monospace"
                    background: Rectangle {
                        color: "#0f0f0f"
                        border { color: "#2a2a2a"; width: 1 }
                        radius: 6
                    }
                }
            }

            // -------------------- 发送栏 --------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 16
                Layout.topMargin: 2
                spacing: 8

                TextField {
                    id: sendInput
                    Layout.fillWidth: true
                    implicitHeight: 36
                    placeholderText: qsTr("输入要发送的文本或JSON...")
                    color: "#cccccc"
                    font.pixelSize: 14
                    background: Rectangle {
                        color: "#1a1a1a"
                        border { color: "#444444"; width: 1 }
                        radius: 6
                    }
                    onAccepted: doSend()
                }

                OpBtn { text: qsTr("发送"); btnColor: "#c0392b"; onClicked: doSend() }
            }
        }
    }

    function doSend() {
        let msg = sendInput.text.trim()
        if (msg === "") return
        MqttManager.sendMessage("", msg)
        sendInput.text = ""
    }

    // ---- 内联组件：参数输入行 ----
    component SettingRow: ColumnLayout {
        spacing: 2
        Layout.fillWidth: true

        property string label: ""
        property string value: ""
        property int echoMode: TextInput.Normal
        signal edited(string text)

        Label {
            text: parent.label
            color: "#aaaaaa"
            font.pixelSize: 13
            font.bold: true
            leftPadding: 2
        }

        TextField {
            Layout.fillWidth: true
            implicitHeight: 36
            text: parent.value
            color: "#ffffff"
            font.pixelSize: 14
            echoMode: parent.echoMode
            leftPadding: 10
            background: Rectangle {
                color: "#1a1a1a"
                border { color: "#555555"; width: 1 }
                radius: 6
            }
            onTextEdited: parent.edited(text)
        }
    }

    // ---- 内联组件：操作按钮 ----
    component OpBtn: Rectangle {
        implicitWidth: 80; implicitHeight: 36; radius: 6

        property string text: ""
        property color btnColor: "#2980b9"
        signal clicked()

        color: btnColor

        scale: mouseArea2.pressed ? 0.93 : 1.0
        Behavior on scale { NumberAnimation { duration: 80 } }

        Text {
            anchors.centerIn: parent
            text: parent.text
            color: "#ffffff"; font.pixelSize: 14; font.bold: true
        }
        MouseArea {
            id: mouseArea2
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }
}
