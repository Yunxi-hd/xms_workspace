/*
 * main.cpp — 程序的 C++ 入口点
 */

#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>

#include "My_Link/wsclient.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // 窗口图标（标题栏 + 任务栏）
    app.setWindowIcon(QIcon("assets/panda.ico"));

    // WSClient 通过 QML_NAMED_ELEMENT(MqttManager) + QML_SINGLETON 注册为
    // YunxiPanda 模块下的单例（见 wsclient.h 与 CMakeLists.txt 的 SOURCES）。
    // QML 引擎会在首次访问 MqttManager 时自动创建实例，无需手动注册。
    QQmlApplicationEngine engine;

    // 加载失败时退出
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("YunxiPanda", "Main");

    return QGuiApplication::exec();
}
