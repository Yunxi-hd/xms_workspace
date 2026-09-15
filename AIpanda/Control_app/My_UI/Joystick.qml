import QtQuick
import QtQuick.Controls.Basic

/*
  Joystick — 手机游戏风格的虚拟摇杆

  使用方法：
      Joystick { id: joystick; width: 300; height: 300 }
  读取 joystick.xValue / joystick.yValue（-1..1）控制小车。

  交互规则：
      - 必须按住小圆球拖动才有效，点在大圆空白处不会触发
      - 拖动时球不能超出大圆边界
      - 松手时球自动回弹到中心
*/

Item {
    id: joystick

    // ============================================================
    // 公开属性
    // ============================================================

    property real xValue: 0
    property real yValue: 0
    property real angle: -1
    property real magnitude: 0
    property bool pressed: _dragging    // 是否正在被触摸/拖动

    // ============================================================
    // 内部尺寸
    // ============================================================

    readonly property real _r: Math.min(width, height) / 2
    readonly property real _thumbR: _r * 0.38
    readonly property real _maxDist: _r - _thumbR
    readonly property real _cx: width / 2
    readonly property real _cy: height / 2

    property real _grabDX: 0
    property real _grabDY: 0
    property bool _dragging: false


    // ============================================================
    // 底座 —— 多层叠加模拟物理摇杆底座的金属/塑料质感
    // ============================================================
    Item {
        id: base
        anchors.centerIn: parent
        width: _r * 2
        height: _r * 2

        // ---- 第 1 层：底座投影（外圈阴影，浮空感） ----
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.04
            height: parent.height * 1.04
            radius: width / 2
            color: "#22000000"
        }

        // ---- 第 2 层：外圈斜面暗边（最外层，模拟倒角暗面） ----
        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            color: "#0d0d0d"
        }

        // ---- 第 3 层：外圈斜面亮边（稍内收，模拟倒角受光面） ----
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.97
            height: parent.height * 0.97
            radius: width / 2
            color: "#2a2a2a"
        }

        // ---- 第 4 层：底座主平面（金属拉丝灰色） ----
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.94
            height: parent.height * 0.94
            radius: width / 2
            color: "#1e1e1e"
        }

        // ---- 第 5 层：内圈凹槽暗环（模拟 CNC 铣出的环形槽） ----
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.78
            height: parent.height * 0.78
            radius: width / 2
            color: "#141414"
        }

        // ---- 第 6 层：凹槽内壁亮边（凹槽受光一侧） ----
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.75
            height: parent.height * 0.75
            radius: width / 2
            color: "#222222"
        }

        // ---- 第 7 层：内圈底面（摇杆活动区域的底衬） ----
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.72
            height: parent.height * 0.72
            radius: width / 2
            color: "#181818"
        }

        // ---- 第 8 层：中心圆点装饰（CNC 定位点） ----
        Rectangle {
            anchors.centerIn: parent
            width: _r * 0.1
            height: _r * 0.1
            radius: width / 2
            color: "#111111"
        }

        // ---- 十字参考线（水平） ----
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.88
            height: 1
            color: "#2a2a2a"
        }
        // ---- 十字参考线（垂直） ----
        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: parent.height * 0.88
            color: "#2a2a2a"
        }

        // ---- 对角线标记（45° 短线，增加精密感） ----
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.50
            height: 1
            color: "#252525"
            rotation: 45
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.50
            height: 1
            color: "#252525"
            rotation: -45
        }
    }


    // ============================================================
    // 3D 球体拇指
    // ============================================================
    Item {
        id: thumb
        width: _thumbR * 2
        height: _thumbR * 2
        x: _cx - _thumbR
        y: _cy - _thumbR

        // ---- 投影 ----
        Rectangle {
            anchors.top: parent.bottom
            anchors.topMargin: -_thumbR * 0.3
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.75
            height: _thumbR * 0.35
            radius: width / 2
            color: "#33000000"
        }

        // ---- 第 1 层：球体暗色边缘 ----
        Rectangle {
            anchors.fill: parent
            radius: _thumbR
            color: "#5c0000"
        }

        // ---- 第 2 层：主体过渡 ----
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.88
            height: parent.height * 0.88
            radius: width / 2
            color: "#991515"
        }

        // ---- 第 3 层：中心亮区 ----
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.70
            height: parent.height * 0.70
            radius: width / 2
            color: "#c62828"
        }

        // ---- 第 4 层：内核亮斑 ----
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.45
            height: parent.height * 0.45
            radius: width / 2
            color: "#e53935"
        }

        // ---- 第 5 层：镜面高光（左上光源） ----
        Rectangle {
            x: parent.width * 0.18
            y: parent.height * 0.10
            width: parent.width * 0.38
            height: parent.height * 0.30
            radius: width / 2
            color: "#44ffffff"
        }

        // ---- 第 6 层：针尖高光 ----
        Rectangle {
            x: parent.width * 0.28
            y: parent.height * 0.18
            width: parent.width * 0.18
            height: parent.height * 0.14
            radius: width / 2
            color: "#77ffffff"
        }

        // ---- 第 7 层：底部环境补光 ----
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.08
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.55
            height: parent.height * 0.12
            radius: width / 2
            color: "#18ffffff"
        }

        // ---- 回弹动画 ----
        Behavior on x {
            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
        }
        Behavior on y {
            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
        }

        // ---- 触控区域 ----
        MultiPointTouchArea {
            anchors.fill: parent
            maximumTouchPoints: 1
            onPressed: touch => _startDrag(touch.x, touch.y)
            onUpdated: touch => _moveDrag(touch.x, touch.y)
            onReleased: _endDrag()

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                onPressed: mouse => _startDrag(mouse.x, mouse.y)
                onPositionChanged: mouse => _moveDrag(mouse.x, mouse.y)
                onReleased: _endDrag()
            }
        }
    }


    // ============================================================
    // 核心逻辑
    // ============================================================

    function _startDrag(mx, my) {
        let touchItemX = thumb.x + mx
        let touchItemY = thumb.y + my
        let thumbCX = thumb.x + _thumbR
        let thumbCY = thumb.y + _thumbR
        _grabDX = touchItemX - thumbCX
        _grabDY = touchItemY - thumbCY
        _dragging = true
    }

    function _moveDrag(mx, my) {
        if (!_dragging) return
        let touchItemX = thumb.x + mx
        let touchItemY = thumb.y + my
        _setCenter(touchItemX - _grabDX, touchItemY - _grabDY)
    }

    function _endDrag() {
        _dragging = false
        _reset()
    }

    function _setCenter(cx, cy) {
        let dx = cx - _cx
        let dy = cy - _cy
        let dist = Math.sqrt(dx * dx + dy * dy)

        if (dist > _maxDist) {
            dx = dx / dist * _maxDist
            dy = dy / dist * _maxDist
            dist = _maxDist
        }

        thumb.x = _cx + dx - _thumbR
        thumb.y = _cy + dy - _thumbR

        magnitude = _maxDist > 0 ? dist / _maxDist : 0
        xValue = _maxDist > 0 ? dx / _maxDist : 0
        yValue = _maxDist > 0 ? -dy / _maxDist : 0
        angle = Math.atan2(-dy, dx) * 180 / Math.PI
        if (angle < 0) angle += 360
    }

    function _reset() {
        thumb.x = _cx - _thumbR
        thumb.y = _cy - _thumbR
        xValue = 0
        yValue = 0
        magnitude = 0
        angle = -1
    }
}
