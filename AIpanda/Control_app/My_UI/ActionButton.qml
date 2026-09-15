import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects

/*
   ActionButton — 动作控制按键（深色科技控制台风格）

   · 长胶囊圆角矩形，圆角 20px
   · 底色统 rgba(22,26,32,0.85)，均匀不做大面积渐变
   · 仅最顶部边缘一处极窄白色内高光
   · 极淡半透明白细边框 rgba(255,255,255,0.08)
   · MultiEffect 微弱外阴影模拟凸起悬浮
   · emoji + 中文文字垂直水平居中，白色文字
   · hover 整体轻微提亮 + 底部淡蓝辉光
   · 点击：整体改变色调（叠加动作类别色）
*/


Rectangle {
    id: btn

    property string label: ""
    property color bgColor: "#2980b9"   // 动作类别色，用于点击时的整体色调
    property string icon: ""            // 图标图片路径（透明背景 PNG，qrc:/icons/xxx.png）

    signal clicked()

    implicitWidth: 100
    implicitHeight: 72
    radius: 20                           // 长胶囊圆角
    color: "transparent"                 // 透明底，视觉由子层负责

    // ============================================================
    // 按压动画：按下时整体轻微缩小
    // ============================================================
    scale: mouseArea.pressed ? 0.97 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
    }

    // ============================================================
    // 底色层：均匀深色半透明 + MultiEffect 微弱外阴影（凸起悬浮）
    // ============================================================
    Rectangle {
        id: body
        anchors.fill: parent
        radius: btn.radius
        color: "#D9161A20"   // rgba(22,26,32,0.85)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#4D000000"
            shadowBlur: 0.35
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3
        }
    }

    // ============================================================
    // hover 整体轻微提亮：白色覆盖层，仅悬浮时显现
    // ============================================================
    Rectangle {
        anchors.fill: parent
        radius: btn.radius
        color: "#FFFFFF"
        opacity: mouseArea.containsMouse ? 0.05 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }
    }

    // ============================================================
    // hover 底部淡蓝色辉光：自下而上渐隐
    // ============================================================
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.88
        height: parent.height * 0.5
        radius: btn.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0058C8FF" }
            GradientStop { position: 1.0; color: "#3358C8FF" }
        }
        opacity: mouseArea.containsMouse || mouseArea.pressed ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }
    }

    // ============================================================
    // 点击色调层：叠加动作类别色，整体改变按钮色调
    // ============================================================
    Rectangle {
        anchors.fill: parent
        radius: btn.radius
        color: Qt.alpha(btn.bgColor, 0.16)
        opacity: mouseArea.pressed ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 90 }
        }
    }

    // ============================================================
    // 顶部极窄柔和内高光：仅顶部边缘一条，非大面积渐变
    // ============================================================
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 12
        height: 3
        radius: 1.5
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#33FFFFFF" }
            GradientStop { position: 1.0; color: "#00FFFFFF" }
        }
    }

    // ============================================================
    // 极淡半透明白细边框
    // ============================================================
    Rectangle {
        anchors.fill: parent
        radius: btn.radius
        color: "transparent"
        border { color: "#14FFFFFF"; width: 1 }   // rgba(255,255,255,0.08)
    }

    // ============================================================
    // 内容：emoji + 中文文字，水平居中、垂直居中
    // ============================================================
    Row {
        anchors.centerIn: parent
        spacing: btn.icon !== "" ? 10 : 0

        // 图标（透明背景 PNG）
        Image {
            visible: btn.icon !== ""
            source: btn.icon
            width: btn.height * 0.8
            height: btn.height * 0.8
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        // 文字标签
        Text {
            text: btn.label
            color: "#FFFFFF"
            font.family: "Microsoft YaHei"
            font.weight: Font.DemiBold
            font.pixelSize: btn.height * 0.24
            font.letterSpacing: 1
            height: btn.height * 0.8
            verticalAlignment: Text.AlignVCenter
        }
    }

    // ============================================================
    // 点击区域（hoverEnabled 用于悬浮提亮与辉光）
    // ============================================================
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.clicked()
    }
}