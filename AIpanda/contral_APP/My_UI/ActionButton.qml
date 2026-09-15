import QtQuick
import QtQuick.Controls.Basic

/*
   ActionButton — 动作控制按键

   3D 风格按钮：顶部高光条 + 渐变主体 + 底部阴影 + 按压反馈
*/

Rectangle {
    id: btn

    property string label: ""
    property color bgColor: "#2980b9"
    property string icon: ""       // emoji 图标

    signal clicked()

    implicitWidth: 100
    implicitHeight: 80
    radius: 14
    color: "transparent"           // 透明底，子层负责视觉

    // ============================================================
    // 按压动画
    // ============================================================
    scale: mouseArea.pressed ? 0.93 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
    }

    // ============================================================
    // 按钮投影
    // ============================================================
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        radius: btn.radius
        color: Qt.darker(bgColor, 2.2)
        opacity: 0.5
    }

    // ============================================================
    // 按钮主体
    // ============================================================
    Rectangle {
        anchors.fill: parent
        radius: btn.radius
        color: bgColor
    }

    // ============================================================
    // 底部暗区（模拟曲面暗面）
    // ============================================================
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.45
        radius: btn.radius
        color: "#18000000"

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: parent.height * 0.6
            radius: btn.radius
            color: "#10000000"
        }
    }

    // ============================================================
    // 顶部高光条（模拟曲面受光）
    // ============================================================
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 2
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 4
        height: parent.height * 0.30
        radius: btn.radius
        color: "#22ffffff"
    }

    // ============================================================
    // 边框（微弱的内发光效果）
    // ============================================================
    Rectangle {
        anchors.fill: parent
        radius: btn.radius
        color: "transparent"
        border { color: "#33ffffff"; width: 1 }
    }

    // ============================================================
    // 图标（emoji）
    // ============================================================
    Text {
        id: iconText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.14
        text: btn.icon
        font.pixelSize: parent.height * 0.28
        visible: btn.icon !== ""
    }

    // ============================================================
    // 文字标签
    // ============================================================
    Text {
        anchors.centerIn: parent
        // 有图标时文字下移
        anchors.verticalCenterOffset: btn.icon !== "" ? parent.height * 0.12 : 0
        text: btn.label
        color: "#ffffff"
        font.pixelSize: btn.icon !== "" ? parent.height * 0.18 : parent.height * 0.22
        font.bold: true
    }

    // ============================================================
    // 点击区域
    // ============================================================
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: btn.clicked()
    }
}
