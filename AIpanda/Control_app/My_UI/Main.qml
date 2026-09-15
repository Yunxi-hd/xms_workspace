/*
 * @file Main.qml
 * @brief 四足机器人「希宝」安卓上位机主界面
 * @author 开发者
 * @note 开发框架：Qt6 QML + JavaScript，可交叉编译Android APK
 * @desc 界面整体布局：顶部常驻工具栏 + SwipeView左右分页容器
 *
 * 页面划分：
 * 【页面索引0】摇杆控制页：虚拟摇杆 + 预设动作按键（站/坐/趴/摇手）
 * 【页面索引1】通讯配置页：MqttPage自定义组件，MQTT连接ESP32下位机
 *
 * 数据下发协议：JSON字符串，通过全局单例 MqttManager 发送MQTT消息
 * JSON字段定义：
 *   L: 摇杆幅度 magnitude [0 ~ 1.0]
 *   A: 摇杆角度 angle，单位 °（角度）
 *   action: 动作指令码
 *     action = 0 : 摇杆持续运动指令（定时器周期发送）
 *     action = 1 : 站着
 *     action = 2 : 坐下
 *     action = 3 : 趴下
 *     action = 4 : 摇手
 *     action = 255 : 摇杆松手归零指令，下位机停止移动
 *
 * 发送策略：
 *   摇杆按住：启动200ms定时器，持续发送 action=0 摇杆数据（5Hz刷新率）
 *   摇杆松开：停止定时器，单独发送一次 action=255，通知下位机停止运动
 *   动作按钮点击：一次性发送对应action指令，单次触发动作
 *
 * 自定义组件说明（本文件只调用，不定义）
 *   Joystick.qml     虚拟摇杆UI组件，对外暴露 xValue / yValue / angle / magnitude / pressed 属性
 *   ActionButton.qml 自定义圆角按钮组件，支持文字、图标、背景色
 *   MqttPage.qml     MQTT连接配置页面（IP、端口、主题、连接状态）
 *   MqttManager      C++暴露到QML的全局单例对象，提供sendMessage(topic, payload)发送MQTT消息
 */

// Qt模块导入声明，QML必须写在文件最开头
import QtQuick                  // 核心基础QML类型：Item、Rectangle、Text、Timer、MouseArea等
import QtQuick.Layouts         // 布局模块：ColumnLayout、RowLayout、GridLayout，自动适配UI尺寸
import QtQuick.Controls.Basic  // Qt6基础控件：Label、SwipeView（无复杂样式，轻量化适合安卓）

// 应用顶层窗口对象，整个APP根容器
ApplicationWindow {
    id: window                  // 对象ID，QML内唯一标识，可被其他元素引用
    width: 640                  // 窗口默认宽度（PC预览尺寸，安卓会自动适配屏幕dp）
    height: 480                 // 窗口默认高度（PC预览尺寸）
    minimumWidth: 320           // 窗口允许的最小宽度，防止小手机UI被压缩变形
    minimumHeight: 300          // 窗口允许的最小高度
    visible: true               // 程序启动后，窗口立刻显示；false则后台隐藏
    title: qsTr("希宝")         // APP窗口标题，qsTr()是Qt多语言翻译函数，方便后续国际化
    color: "#121212"            // 窗口底层背景颜色，深黑灰色，深色主题

    // ColumnLayout：纵向线性布局，从上往下排列子元素
    // 作用：承载【顶部工具栏】和【滑动页面容器SwipeView】，保证工具栏固定置顶
    ColumnLayout {
        anchors.fill: parent    // 锚定：填满父窗口全部可用区域
        spacing: 0              // 子元素之间空白间距设置为0，消除缝隙

        //======================================================================
        // 第一块：顶部工具栏 RowLayout（横向布局，常驻页面顶部，翻页不会消失）
        // 内容：4个摇杆实时读数Label + 页面切换分段开关
        //======================================================================
        RowLayout {
            Layout.fillWidth: true     // Layout附加属性：横向占满父ColumnLayout宽度
            Layout.margins: 12         // 容器内四边留白边距12px
            spacing: 8                 // RowLayout内部各个子控件横向间隔8px

            // Label标签：显示摇杆X轴数值，调用JS函数read5做格式化
            Label {
                text: qsTr("X: %1").arg(read5(joystick.xValue))
                color: "#cccccc"        // 文字浅灰色
                font.pixelSize: 12      // 字体像素大小12
                font.family: "monospace"// 等宽字体，保证数字对齐，读数不会左右抖动
            }

            // Label标签：显示摇杆Y轴数值
            Label {
                text: qsTr("Y: %1").arg(read5(joystick.yValue))
                color: "#cccccc"
                font.pixelSize: 12
                font.family: "monospace"
            }

            // Label标签：显示摇杆角度，单位度°，调用read6格式化角度
            Label {
                text: qsTr("A: %1°").arg(read6(joystick.angle))
                color: "#cccccc"
                font.pixelSize: 12
                font.family: "monospace"
            }

            // Label标签：显示摇杆幅度（摇杆中心点到拖动点的距离，0~1）
            Label {
                text: qsTr("M: %1").arg(read5(joystick.magnitude))
                color: "#cccccc"
                font.pixelSize: 12
                font.family: "monospace"
            }

            // 空白占位Item：Layout.fillWidth: true，会自动挤占剩余横向空间
            // 效果：把后面的分段开关整体推到RowLayout最右侧
            Item { Layout.fillWidth: true }

            // ---------------------- 两段式页面切换开关 组件 ----------------------
            Rectangle {
                id: toggle              // 分段开关外框ID
                implicitWidth: 100      // 控件默认宽度（没有锚定的时候生效）
                implicitHeight: 32      // 控件默认高度
                radius: 16              // 外框圆角半径，刚好是高度一半，做成胶囊形状
                color: "#1a1a1a"        // 外框背景深色
                border {                // 边框属性组
                    color: "#444444"    // 边框颜色
                    width: 1            // 边框粗细1像素
                }

                // QML内联Component：定义可复用子组件 ToggleSegment，分段按钮单元
                // 只在当前Rectangle内部可用，减少重复代码
                component ToggleSegment: Rectangle {
                    property int pageIdx: 0     // 自定义属性：绑定SwipeView页面索引
                    property string label: ""   // 自定义属性：按钮显示文字

                    anchors.top: parent.top     // 锚定顶部对齐父胶囊框
                    anchors.bottom: parent.bottom // 锚定底部对齐父胶囊框
                    anchors.margins: 3          // 上下留白3px，让按钮比外框小一圈
                    width: (parent.width - 6) / 2 // 总宽度减去左右3*2边距，平均分成两半
                    radius: 13                  // 内部按钮圆角，略小于外框圆角
                    // 三元表达式：当前选中页面，则背景红色；否则透明
                    color: swipeView.currentIndex === pageIdx ? "#c0392b" : "transparent"

                    // Behavior：属性变化动画，监听color属性变化
                    Behavior on color {
                        ColorAnimation { duration: 150 } // 颜色渐变动画时长150毫秒
                    }

                    // 文字显示
                    Text {
                        anchors.centerIn: parent // 文字在当前按钮矩形居中
                        text: parent.label
                        // 选中白色文字，未选中浅灰色
                        color: swipeView.currentIndex === parent.pageIdx ? "#ffffff" : "#888888"
                        font.pixelSize: 12
                        font.bold: swipeView.currentIndex === parent.pageIdx // 选中加粗
                    }

                    // MouseArea：鼠标/触摸感应区域，铺满整个按钮
                    MouseArea {
                        anchors.fill: parent
                        onClicked: swipeView.currentIndex = parent.pageIdx // 点击切换页面索引
                    }
                }

                // 实例化ToggleSegment：左侧按钮，页面0 摇杆页
                ToggleSegment {
                    anchors.left: parent.left
                    pageIdx: 0
                    label: qsTr("摇杆")
                }
                // 实例化ToggleSegment：右侧按钮，页面1 通讯页
                ToggleSegment {
                    anchors.right: parent.right
                    pageIdx: 1
                    label: qsTr("通讯")
                }
            }
        }

        //======================================================================
        // 第二块：SwipeView 滑动页面容器
        // 作用：承载多个页面Item，支持切换currentIndex切换页面
        //======================================================================
        SwipeView {
            id: swipeView
            Layout.fillWidth: true     // 横向填满父布局
            Layout.fillHeight: true    // 纵向填满父布局剩余高度（扣除顶部工具栏）
            interactive: false         // 【重要】关闭手指左右滑动翻页，只能点顶部按钮切换，防止安卓误触
            currentIndex: 0            // 默认打开页面索引0：摇杆控制页

            // -------------------------- SwipeView 页面 0：摇杆控制页面 --------------------------
            Item {
                // GridLayout网格布局：2行2列动作按钮组
                GridLayout {
                    id: actionGrid
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 8       // 距离父Item顶部外边距8px
                    anchors.leftMargin: 8      // 左边外边距8px
                    anchors.rightMargin: 8     // 右边外边距8px
                    height: parent.height * 0.3// 高度占当前页面总高度30%
                    columns: 2                 // 设置网格列数固定2列，自动换行
                    rowSpacing: 8              // 行与行垂直间距
                    columnSpacing: 8           // 列与列水平间距

                    // 自定义动作按钮：站着 actionId = 1
                    ActionButton {
                        label: qsTr("站着"); icon: "qrc:/icons/stand.png"; bgColor: "#2980b9"
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.minimumWidth: 0; Layout.minimumHeight: 0
                        onClicked: sendJson(1) // 点击触发：调用JS函数发送action=1指令
                    }
                    // 自定义动作按钮：坐下 actionId = 2
                    ActionButton {
                        label: qsTr("坐下"); icon: "qrc:/icons/sit.png"; bgColor: "#27ae60"
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.minimumWidth: 0; Layout.minimumHeight: 0
                        onClicked: sendJson(2)
                    }
                    // 自定义动作按钮：趴下 actionId = 3
                    ActionButton {
                        label: qsTr("趴下"); icon: "qrc:/icons/lie.png"; bgColor: "#8e44ad"
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.minimumWidth: 0; Layout.minimumHeight: 0
                        onClicked: sendJson(3)
                    }
                    // 自定义动作按钮：摇手 actionId = 4
                    ActionButton {
                        label: qsTr("摇手"); icon: "qrc:/icons/wave.png"; bgColor: "#d35400"
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.minimumWidth: 0; Layout.minimumHeight: 0
                        onClicked: sendJson(4)
                    }
                }

                // 虚拟摇杆组件，占据页面剩下70%高度
                Joystick {
                    id: joystick
                    anchors.top: actionGrid.bottom    // 顶部锚定在按钮网格底部
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 8
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.bottomMargin: 8

                    // 信号回调：摇杆 pressed 按压状态发生改变时触发
                    // pressed: true=手指按住摇杆；false=手指松开摇杆
                    onPressedChanged: {
                        if (joystick.pressed) {
                            txTimer.start()  // 按下：启动周期发送定时器，持续上报摇杆数据
                        } else {
                            txTimer.stop()   // 松开：停止定时器
                            sendJson(255)    // 发送归零指令，下位机停止运动
                        }
                    }
                }
            }

            // -------------------------- SwipeView 页面 1：通讯配置页面 --------------------------
            // 注意：MqttPage 必须作为 SwipeView 的直接子项，SwipeView 才会把它自动
            // 撑满到视口大小。若外面再多包一层 Item，MqttPage 的根 Item 会保持 0×0，
            // 导致整个通讯页内容不显示。
            MqttPage { }
        }
    }

    //======================================================================
    // 定时器控件：摇杆数据周期发送定时器
    //======================================================================
    Timer {
        id: txTimer
        interval: 200               // 定时周期：200毫秒，1000/200 = 5帧每秒
        repeat: true                // true=循环重复触发；false=只触发一次
        running: false              // 初始化默认不运行，摇杆按下才启动
        onTriggered: sendJson(0)    // 每次定时到期触发回调：发送action=0摇杆运动数据
    }

    //======================================================================
    // QML内嵌 JavaScript 函数：组装JSON载荷，调用MQTT发送消息
    // @param actionId int 动作指令编号
    //======================================================================
    function sendJson(actionId) {
        // 判断摇杆按压状态：按住取实时幅度；松手幅度强制0.00
        let L = joystick.pressed ? joystick.magnitude.toFixed(2) : "0.00"
        // 判断摇杆按压状态：按住取实时角度并四舍五入取整数；松手角度置0
        let A = joystick.pressed ? Math.round(joystick.angle) : 0
        // 拼接JSON字符串，作为MQTT消息payload下发给ESP32
        let json = '{"L":' + L + ',"A":' + A + ',"action":' + actionId + '}'
        // 调用全局单例MqttManager，向控制主题发送组装好的JSON报文
        MqttManager.sendMessage(MqttManager.controlTopic, json)
    }

    //======================================================================
    // JS辅助格式化函数 read5
    // 功能：把摇杆X/Y/M数值格式化为固定长度字符串，带正负号，保留2位小数
    // 输出样例：+0.50，-0.75
    // @param v number 输入原始浮点数值
    // @return string 格式化后的字符串
    //======================================================================
    function read5(v) {
        let sign = v < 0 ? "-" : "+"    // 判断正负，生成符号
        return sign + Math.abs(v).toFixed(2) // 取绝对值，保留2位小数，拼接符号
    }

    //======================================================================
    // JS辅助格式化函数 read6
    // 功能：摇杆角度格式化，带正负号，整数部分固定3位，不足补前导0，保留1位小数
    // 输出样例：+090.0，-005.5
    // @param v number 输入角度浮点数
    // @return string 格式化后的角度字符串
    //======================================================================
    function read6(v) {
        let sign = v < 0 ? "-" : "+"    // 判断正负号
        let s = Math.abs(v).toFixed(1)  // 取绝对值，保留1位小数转为字符串，例 "90.0"
        let p = s.split(".")            // 用小数点分割字符串，得到数组 [整数部分,小数部分]
        let intPart = p[0]
        // while循环：整数部分长度不足3，前面补0，直到3位
        while (intPart.length < 3) intPart = "0" + intPart
        return sign + intPart + "." + p[1]
    }
}
