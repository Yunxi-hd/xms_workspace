/*
 * wsclient.h — WebSocket 通讯管理器
 *
 * 使用 Qt WebSockets 模块的 QWebSocket 连接 ESP32 WebSocket 服务器。
 * 接口与原 MqttManager 尽量保持兼容，减少 QML 改动：
 *   - 保留 connected / serverHost / serverPort 属性
 *   - 保留 connectToBroker / disconnectFromBroker / sendMessage 方法名
 *   - sendMessage(topic, payload) 的 topic 参数兼容旧代码，实际被忽略
 *
 * 新增：UDP 局域网设备自动发现
 *   - startDiscovery() 开始监听 UDP 广播（端口 DISCOVERY_UDP_PORT）
 *   - ESP32 端周期性发送 "XIAOZHI_PANDA_V1|<IP>|<WS_PORT>"
 *   - 解析后自动填充 serverHost/serverPort 并发出 deviceFound 信号
 *
 * ESP32 端连接格式：ws://<IP>:8080/ws
 */

#ifndef WSCLIENT_H
#define WSCLIENT_H

#include "ws_config.h"

#include <QObject>
#include <QString>
#include <QStringList>
#include <QWebSocket>
#include <QUdpSocket>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class WSClient : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(MqttManager)
    QML_SINGLETON

    // ---- 连接状态 ----
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

    // ---- 服务器参数 ----
    Q_PROPERTY(QString serverHost READ serverHost WRITE setServerHost NOTIFY serverHostChanged)
    Q_PROPERTY(int serverPort READ serverPort WRITE setServerPort NOTIFY serverPortChanged)
    Q_PROPERTY(QString serverPath READ serverPath WRITE setServerPath NOTIFY serverPathChanged)

    // ---- 设备发现状态 ----
    Q_PROPERTY(bool discovering READ discovering NOTIFY discoveringChanged)
    Q_PROPERTY(QStringList discoveredDevices READ discoveredDevices NOTIFY discoveredDevicesChanged)

    // ---- 兼容旧 MqttManager 接口（QML不改） ----
    Q_PROPERTY(QString brokerHost READ brokerHost WRITE setBrokerHost NOTIFY brokerHostChanged)
    Q_PROPERTY(int brokerPort READ brokerPort WRITE setBrokerPort NOTIFY brokerPortChanged)
    Q_PROPERTY(QString clientId READ clientId WRITE setClientId NOTIFY clientIdChanged)
    Q_PROPERTY(QString username READ username WRITE setUsername NOTIFY usernameChanged)
    Q_PROPERTY(QString password READ password WRITE setPassword NOTIFY passwordChanged)
    Q_PROPERTY(QString controlTopic READ controlTopic WRITE setControlTopic NOTIFY controlTopicChanged)
    Q_PROPERTY(QString statusTopic READ statusTopic WRITE setStatusTopic NOTIFY statusTopicChanged)

    // ---- 消息日志 ----
    Q_PROPERTY(QString receivedMessages READ receivedMessages NOTIFY receivedMessagesChanged)

public:
    explicit WSClient(QObject *parent = nullptr);
    ~WSClient();

    bool connected() const;
    QString serverHost() const;
    int serverPort() const;
    QString serverPath() const;
    bool discovering() const;
    QStringList discoveredDevices() const;

    // 兼容属性 getters
    QString brokerHost() const;
    int brokerPort() const;
    QString clientId() const;
    QString username() const;
    QString password() const;
    QString controlTopic() const;
    QString statusTopic() const;
    QString receivedMessages() const;

    void setServerHost(const QString &v);
    void setServerPort(int v);
    void setServerPath(const QString &v);

    // 兼容属性 setters（实际转发到 serverHost / serverPort）
    void setBrokerHost(const QString &v);
    void setBrokerPort(int v);
    void setClientId(const QString &v);
    void setUsername(const QString &v);
    void setPassword(const QString &v);
    void setControlTopic(const QString &v);
    void setStatusTopic(const QString &v);

    // 与原 MqttManager 相同的方法名
    Q_INVOKABLE void connectToBroker();
    Q_INVOKABLE void disconnectFromBroker();
    Q_INVOKABLE void sendMessage(const QString &topic, const QString &payload);
    Q_INVOKABLE void subscribeTopic(const QString &topic);
    Q_INVOKABLE void saveSettings();
    Q_INVOKABLE void loadSettings();

    // ---- 新增：UDP 设备自动发现 ----
    Q_INVOKABLE void startDiscovery(int timeoutMs = DISCOVERY_TIMEOUT_MS);
    Q_INVOKABLE void stopDiscovery();
    // 点击列表中的某一项，自动填入 IP+端口 并保存
    Q_INVOKABLE void selectDiscoveredDevice(int index);

signals:
    void connectedChanged();
    void serverHostChanged();
    void serverPortChanged();
    void serverPathChanged();
    void discoveringChanged();
    void discoveredDevicesChanged();

    // 找到一个设备（UI 可以弹提示）
    void deviceFound(const QString &ip, int port, const QString &extraInfo);

    // 兼容属性的 changed 信号
    void brokerHostChanged();
    void brokerPortChanged();
    void clientIdChanged();
    void usernameChanged();
    void passwordChanged();
    void controlTopicChanged();
    void statusTopicChanged();

    void receivedMessagesChanged();
    void newMessageReceived(const QString &topic, const QString &payload);

private slots:
    void onConnected();
    void onDisconnected();
    void onTextMessageReceived(const QString &message);
    void onErrorOccurred(QAbstractSocket::SocketError error);
    void onStateChanged(QAbstractSocket::SocketState state);
    void onReconnectTimer();
    void onPingTimer();

    // UDP 发现槽
    void onDiscoveryReadyRead();
    void onDiscoveryTimeout();

private:
    QUrl buildServerUrl() const;
    void appendLog(const QString &line);
    void addDiscoveredDevice(const QString &displayName, const QString &ip, int port);

    QWebSocket *m_socket;
    QTimer *m_reconnectTimer;
    QTimer *m_pingTimer;

    // UDP 发现
    QUdpSocket *m_discoverySocket;
    QTimer *m_discoveryTimer;
    QStringList m_discoveredDevices;  // 显示用（例如 "ESP32-S3 @ 192.168.1.100:8080"）
    QList<QPair<QString,int>> m_discoveredDeviceAddr; // 对应 (ip, port)
    bool m_discovering = false;

    // 服务器参数
    QString m_serverHost;
    int m_serverPort = 8080;
    QString m_serverPath;

    // 兼容占位
    QString m_clientId;
    QString m_username;
    QString m_password;
    QString m_controlTopic;
    QString m_statusTopic;

    QString m_receivedMessages;
    bool m_connected = false;
    bool m_manualDisconnect = false;
};

#endif // WSCLIENT_H
