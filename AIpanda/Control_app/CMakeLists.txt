# ============================================================
# CMakeLists.txt — CMake 构建配置文件
# ============================================================
#
# CMake 是什么？
#   它是一个"构建系统生成器"。你写 CMakeLists.txt 描述项目结构，
#   CMake 读取后生成 Makefile 或 Visual Studio 工程文件，
#   然后用 make / ninja / MSBuild 实际编译。
#
#   类比：CMake 是"菜谱"，编译器是"厨师"。
#   CMakeLists.txt 告诉厨师：用什么食材、按什么顺序、做成什么菜。
#
# Qt 项目的编译流程：
#   CMakeLists.txt → cmake 生成 Makefile → make 编译 → 得到 .exe
# ============================================================


# --------------------------------------------------
# 第 1 步：最低 CMake 版本要求
# --------------------------------------------------
# 如果用户的 CMake 版本低于 3.16，cmake 命令会直接报错并退出。
# Qt 6 需要 CMake 3.16 以上才能正常工作。
cmake_minimum_required(VERSION 3.16)


# --------------------------------------------------
# 第 2 步：定义项目
# --------------------------------------------------
# project() 告诉 CMake 这个项目的名字、版本号、用什么编程语言。
#
#   YunxiPanda      → 项目名
#   VERSION 0.1     → 当前版本 0.1
#   LANGUAGES CXX   → 使用 C++（CXX = C++，不是拼写错误）
#
# 这里定义的名字和版本会变成 CMake 变量：
#   ${PROJECT_NAME}    = "YunxiPanda"
#   ${PROJECT_VERSION} = "0.1"
project(YunxiPanda VERSION 0.1 LANGUAGES CXX)


# --------------------------------------------------
# 第 3 步：设置 C++ 标准
# --------------------------------------------------
# CMAKE_CXX_STANDARD_REQUIRED ON 表示：
#   "必须使用我指定的 C++ 标准，如果不支持就报错"
#
# 不指定具体值是因为 Qt 6 内部会自己决定用 C++17 还是更高版本。
# 我们只需要说"必须满足标准要求"即可。
set(CMAKE_CXX_STANDARD_REQUIRED ON)


# --------------------------------------------------
# 第 4 步：查找 Qt 6 依赖包
# --------------------------------------------------
# find_package 是 CMake 最核心的命令之一。
# 它去系统中搜索已安装的库，找到后提供该库的头文件路径、链接库等。
#
#   Qt6 REQUIRED       → 必须找到 Qt6，否则报错停止
#   COMPONENTS Quick   → 我们需要 Qt Quick 模块（QML 界面框架）
#
# 如果以后要加蓝牙控制小车，在这里加：
#   find_package(Qt6 REQUIRED COMPONENTS Quick Bluetooth)
find_package(Qt6 REQUIRED COMPONENTS Quick Network WebSockets)


# --------------------------------------------------
# 第 5 步：Qt 项目标准设置
# --------------------------------------------------
# qt_standard_project_setup 是 Qt 6 提供的便捷宏。
# 它自动做了一系列 Qt 项目需要的设置，包括：
#   - 设置 C++ 标准（至少 C++17）
#   - 启用 Qt 的 MOC（元对象编译器，处理 signal/slot）
#   - 启用 Qt 的资源系统
#   - 设置 Android/iOS 相关的平台选项
#
# REQUIRES 6.10 表示需要 Qt 6.10 或更高版本。
qt_standard_project_setup(REQUIRES 6.10)


# --------------------------------------------------
# 第 6 步：声明可执行文件
# --------------------------------------------------
# qt_add_executable 告诉 CMake 我们要生成一个 .exe 文件。
#
#   appYunxiPanda → 生成的可执行文件的"目标名"（target name）
#   main.cpp      → 参与编译的 C++ 源文件列表
#
# 以后如果有更多 .cpp 文件，都写在后面的列表里：
#   qt_add_executable(appYunxiPanda
#       main.cpp
#       carcontroller.cpp
#       bluetoothmanager.cpp
#   )
qt_add_executable(appYunxiPanda
    main.cpp
    My_Link/ws_config.h
    icon.rc
)


# --------------------------------------------------
# 第 7 步：声明 QML 模块
# --------------------------------------------------
# qt_add_qml_module 把一个目录下的 QML 文件组织成一个"模块"。
#
#   URI YunxiPanda        → 模块的唯一标识符（类似 Java 的包名）
#                           main.cpp 里用这个 URI 来加载 QML：
#                           engine.loadFromModule("YunxiPanda", "Main")
#
#   QML_FILES             → 列出这个模块包含的所有 .qml 文件
#                           新增 QML 文件时要记得加到这里！
#
#   SOURCES               → 包含 C++ 实现（QML_ELEMENT/QML_SINGLETON 的类
#                           必须放在这里，才能被 moc 生成类型信息并注册进模块）
qt_add_qml_module(appYunxiPanda
    URI YunxiPanda
    QML_FILES
        My_UI/Main.qml
        My_UI/Joystick.qml
        My_UI/ActionButton.qml
        My_UI/MqttPage.qml
    SOURCES
        My_Link/wsclient.cpp
        My_Link/wsclient.h
)

# --------------------------------------------------
# 第 7.5 步：把动作图标图片编译进 Qt 资源系统
# --------------------------------------------------
# qt_add_resources 把 PNG 打包进可执行文件，QML 里用 qrc:/icons/xxx.png 访问
# PREFIX "/icons" 定义资源前缀
# BASE 指向 icons 目录，让别名等于文件名（stand.png 而非 My_UI/icons/stand.png）
qt_add_resources(appYunxiPanda "icons"
    PREFIX "/icons"
    BASE ${CMAKE_CURRENT_SOURCE_DIR}/My_UI/icons
    FILES
        My_UI/icons/stand.png
        My_UI/icons/sit.png
        My_UI/icons/lie.png
        My_UI/icons/wave.png
)


# --------------------------------------------------
# 第 8 步：设置目标属性
# --------------------------------------------------
# set_target_properties 给可执行文件设置特定平台的属性。
#
#   WIN32_EXECUTABLE TRUE
#     Windows 专用：标记为 GUI 应用而非控制台应用。
#     设为 TRUE → 启动时不弹出黑框（cmd 窗口）
#     设为 FALSE → 启动时带黑框，适合调试时打印日志
set_target_properties(appYunxiPanda PROPERTIES
    WIN32_EXECUTABLE TRUE
    QT_ANDROID_PACKAGE_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/android
)

# 把 My_Link 目录加入 include 路径：
# qmltyperegistrar 为 QML_NAMED_ELEMENT 生成的注册代码里写的是
#   #include <wsclient.h>（尖括号，只在 include path 里找）
# 而 wsclient.h 位于 My_Link/ 子目录，必须把该目录加入 include path 才能找到。
target_include_directories(appYunxiPanda PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/My_Link)


# --------------------------------------------------
# 第 9 步：链接 Qt 库
# --------------------------------------------------
# target_link_libraries 把 Qt 库链接到我们的可执行文件。
#
#   如果不链接，编译时会报"未定义符号"的错误——
#   因为你的代码用了 Qt 的函数，但编译器找不到这些函数的实现。
#
#   PRIVATE → 链接方式是"私有的"。
#     这意味着只有 appYunxiPanda 自身使用 Qt6::Quick，
#     依赖 appYunxiPanda 的其他目标不会间接获得 Qt6::Quick 的访问权。
#     对于可执行文件来说，PUBLIC/PRIVATE 区别不大，写 PRIVATE 是惯例。
target_link_libraries(appYunxiPanda
    PRIVATE Qt6::Quick Qt6::Network Qt6::WebSockets
)


# --------------------------------------------------
# 第 10 步：安装规则
# --------------------------------------------------
# install() 描述如何把编译产物安装到目标系统。
#
#   TARGETS appYunxiPanda → 我们要安装的可执行文件
#   BUNDLE DESTINATION .  → macOS：.app 捆绑包放到安装根目录
#   LIBRARY DESTINATION   → Linux：.so 动态库放到 lib 目录
#   RUNTIME DESTINATION   → Windows：.exe 放到 bin 目录
#
# 日常开发中不常用 install，主要是在打包发布时才用到。
install(TARGETS appYunxiPanda
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)


