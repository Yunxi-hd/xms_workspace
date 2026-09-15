/*
 * wsclient.cpp — WebSocket 通讯管理器实现
 *
 * 使用 QWebSocket 直连 ESP32 的 ws://<IP>:8080/ws 端点。
 * 消息格式：纯文本帧（与 ESP32 端 HTTPD_WS_TYPE_TEXT 对应）。
 *
 * 设备自动发现：ESP32 端每 2 秒向 255.255.255.255:4210 发送 UDP 广播：
 *     XIAOZHI_PANDA_V1|192.168.1.100|8080|ESP32-S3
 * Qt 端 startDiscovery() 绑定相同端口，解析后填入 IP 列表。
 */

#include "wsclient.h"
#include "My_Link/ws_config.h"
#include <QSettings>
#include <QDateTime>
#include <QUrl>
#include <QNetworkInterface>
#include <QHostAddress>

// ============================================================
// 构造 / 析构
// ============================================================

WSClient::WSClient(QObject *parent)
    : QObject(parent)
    , m_socket(new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this))
    , m_reconnectTimer(new QTimer(this))
    , m_pingTimer(new QTimer(this))
    , m_discoverySocket(new QUdpSocket(this))
    , m_discoveryTimer(new QTimer(this))
    , m_serverHost(WS_DEFAULT_HOST)
    , m_serverPort(WS_DEFAULT_PORT)
    , m_serverPath(WS_DEFAULT_PATH)
{
    loadSettings();

    connect(m_socket, &QWebSocket::connected,
            this, &WSClient::onConnected);
    connect(m_socket, &QWebSocket::disconnected,
            this, &WSClient::onDisconnected);
    connect(m_socket, &QWebSocket::textMessageReceived,
            this, &WSClient::onTextMessageReceived);
    connect(m_socket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::errorOccurred),
            this, &WSClient::onErrorOccurred);
    connect(m_socket, &QWebSocket::stateChanged,
            this, &WSClient::onStateChanged);

    // 重连定时器
    m_reconnectTimer->setSingleShot(true);
    m_reconnectTimer->setInterval(WS_RECONNECT_INTERVAL);
    connect(m_reconnectTimer, &QTimer::timeout,
            this, &WSClient::onReconnectTimer);

    // 心跳定时器
    if (WS_PING_INTERVAL > 0) {
        m_pingTimer->setInterval(WS_PING_INTERVAL);
        connect(m_pingTimer, &QTimer::timeout,
                this, &WSClient::onPingTimer);
    }

    // UDP 发现
    connect(m_discoverySocket, &QUdpSocket::readyRead,
            this, &WSClient::onDiscoveryReadyRead);
    m_discoveryTimer->setSingleShot(true);
    connect(m_discoveryTimer, &QTimer::timeout,
            this, &WSClient::onDiscoveryTimeout);
}

WSClient::~WSClient()
{
    stopDiscovery();
    m_manualDisconnect = true;
    if (m_socket->state() != QAbstractSocket::UnconnectedState) {
        m_socket->close();
    }
}

// ============================================================
// getters / setters
// ============================================================

bool WSClient::connected() const { return m_connected; }
QString WSClient::serverHost() const { return m_serverHost; }
int WSClient::serverPort() const { return m_serverPort; }
QString WSClient::serverPath() const { return m_serverPath; }
bool WSClient::discovering() const { return m_discovering; }
QStringList WSClient::discoveredDevices() const { return m_discoveredDevices; }

// ---- 兼容 getters ----
QString WSClient::brokerHost() const { return m_serverHost; }
int WSClient::brokerPort() const { return m_serverPort; }
QString WSClient::clientId() const { return m_clientId; }
QString WSClient::username() const { return m_username; }
QString WSClient::password() const { return m_password; }
QString WSClient::controlTopic() const { return m_controlTopic; }
QString WSClient::statusTopic() const { return m_statusTopic; }
QString WSClient::receivedMessages() const { return m_receivedMessages; }

void WSClient::setServerHost(const QString &v) {
    if (m_serverHost != v) { m_serverHost = v; emit serverHostChanged(); emit brokerHostChanged(); }
}
void WSClient::setServerPort(int v) {
    if (m_serverPort != v) { m_serverPort = v; emit serverPortChanged(); emit brokerPortChanged(); }
}
void WSClient::setServerPath(const QString &v) {
    if (m_serverPath != v) { m_serverPath = v; emit serverPathChanged(); }
}

// ---- 兼容 setters ----
void WSClient::setBrokerHost(const QString &v) { setServerHost(v); }
void WSClient::setBrokerPort(int v) { setServerPort(v); }
void WSClient::setClientId(const QString &v) {
    if (m_clientId != v) { m_clientId = v; emit clientIdChanged(); }
}
void WSClient::setUsername(const QString &v) {
    if (m_username != v) { m_username = v; emit usernameChanged(); }
}
void WSClient::setPassword(const QString &v) {
    if (m_password != v) { m_password = v; emit passwordChanged(); }
}
void WSClient::setControlTopic(const QString &v) {
    if (m_controlTopic != v) { m_controlTopic = v; emit controlTopicChanged(); }
}
void WSClient::setStatusTopic(const QString &v) {
    if (m_statusTopic != v) { m_statusTopic = v; emit statusTopicChanged(); }
}

// ============================================================
// 公共接口
// ============================================================

void WSClient::connectToBroker()
{
    if (m_connected) {
        appendLog("[警告] 已连接");
        return;
    }
    QUrl url = buildServerUrl();
    appendLog(QString("[连接] 正在连接 %1 ...").arg(url.toString()));
    m_manualDisconnect = false;
    m_socket->open(url);
}

void WSClient::disconnectFromBroker()
{
    if (!m_connected) {
        appendLog("[警告] 未连接");
        return;
    }
    appendLog("[断开] 正在断开...");
    m_manualDisconnect = true;
    m_pingTimer->stop();
    m_reconnectTimer->stop();
    m_socket->close();
}

void WSClient::sendMessage(const QString &topic, const QString &payload)
{
    Q_UNUSED(topic)
    if (!m_connected) {
        appendLog("[错误] 未连接，无法发送");
        return;
    }
    m_socket->sendTextMessage(payload);
    appendLog(QString("[发送] %1").arg(payload));
}

void WSClient::subscribeTopic(const QString &topic)
{
    Q_UNUSED(topic)
    appendLog("[提示] WebSocket 模式无需订阅");
}

// ============================================================
// 设置保存 / 加载
// ============================================================

void WSClient::saveSettings()
{
    QSettings s;
    s.beginGroup(WS_SETTINGS_GROUP);
    s.setValue(WS_SETTINGS_KEY_HOST, m_serverHost);
    s.setValue(WS_SETTINGS_KEY_PORT, m_serverPort);
    s.setValue(WS_SETTINGS_KEY_PATH, m_serverPath);
    s.endGroup();
    appendLog("[保存] 参数已保存");
}

void WSClient::loadSettings()
{
    QSettings s;
    s.beginGroup(WS_SETTINGS_GROUP);
    if (s.contains(WS_SETTINGS_KEY_HOST)) m_serverHost = s.value(WS_SETTINGS_KEY_HOST).toString();
    if (s.contains(WS_SETTINGS_KEY_PORT)) m_serverPort = s.value(WS_SETTINGS_KEY_PORT).toInt();
    if (s.contains(WS_SETTINGS_KEY_PATH)) m_serverPath = s.value(WS_SETTINGS_KEY_PATH).toString();
    s.endGroup();
}

// ============================================================
// UDP 设备自动发现
// ============================================================

void WSClient::startDiscovery(int timeoutMs)
{
    // 清理上一次结果
    if (!m_discoveredDevices.isEmpty()) {
        m_discoveredDevices.clear();
        m_discoveredDeviceAddr.clear();
        emit discoveredDevicesChanged();
    }

    // 关闭已有绑定（防止端口占用）
    if (m_discoverySocket->state() != QAbstractSocket::UnconnectedState) {
        m_discoverySocket->close();
    }

    // 绑定到 AnyIPv4 + ShareAddress，允许多网卡多程序同时监听此广播端口
    bool ok = m_discoverySocket->bind(
        QHostAddress::AnyIPv4,
        DISCOVERY_UDP_PORT,
        QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint);

    if (!ok) {
        appendLog(QString("[搜索失败] 无法绑定 UDP 端口 %1: %2")
                      .arg(DISCOVERY_UDP_PORT)
                      .arg(m_discoverySocket->errorString()));
        return;
    }

    // 加入所有活动 IPv4 接口的广播组
    for (const QNetworkInterface &iface : QNetworkInterface::allInterfaces()) {
        if (!(iface.flags() & QNetworkInterface::IsUp) ||
            (iface.flags() & QNetworkInterface::IsLoopBack))
            continue;
        for (const QNetworkAddressEntry &entry : iface.addressEntries()) {
            if (entry.ip().protocol() != QAbstractSocket::IPv4Protocol)
                continue;
            QHostAddress broadcast = entry.broadcast();
            if (!broadcast.isNull()) {
                // QUdpSocket 会自动在所有绑定接口上接收广播，这里只需要确保绑定成功即可
                Q_UNUSED(broadcast)
            }
        }
    }

    m_discovering = true;
    emit discoveringChanged();
    appendLog(QString("[搜索] 开始搜索设备，监听端口 %1，%2ms 后停止...")
                  .arg(DISCOVERY_UDP_PORT).arg(timeoutMs));
    m_discoveryTimer->start(timeoutMs);
}

void WSClient::stopDiscovery()
{
    if (m_discoveryTimer->isActive()) m_discoveryTimer->stop();
    if (m_discoverySocket->state() != QAbstractSocket::UnconnectedState) {
        m_discoverySocket->close();
    }
    if (m_discovering) {
        m_discovering = false;
        emit discoveringChanged();
    }
}

void WSClient::selectDiscoveredDevice(int index)
{
    if (index < 0 || index >= m_discoveredDeviceAddr.size()) return;
    const auto &addr = m_discoveredDeviceAddr.at(index);
    setServerHost(addr.first);
    setServerPort(addr.second);
    appendLog(QString("[选中设备] %1:%2（点击「连接」按钮开始连接）")
                  .arg(addr.first).arg(addr.second));
    saveSettings();
}

void WSClient::onDiscoveryReadyRead()
{
    while (m_discoverySocket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(static_cast<int>(m_discoverySocket->pendingDatagramSize()));
        QHostAddress senderAddr;
        quint16 senderPort = 0;
        m_discoverySocket->readDatagram(datagram.data(), datagram.size(),
                                         &senderAddr, &senderPort);

        QString text = QString::fromUtf8(datagram).trimmed();

        // 格式: XIAOZHI_PANDA_V1|<ip>|<ws_port>[|<extra>]
        QStringList parts = text.split('|');
        if (parts.size() < 3) continue;
        if (parts[0] != QStringLiteral(DISCOVERY_MAGIC)) continue;

        QString ip = parts[1];
        int port = parts[2].toInt();
        QString extra = parts.size() >= 4 ? parts[3] : QString();

        // 避免重复添加
        bool duplicate = false;
        for (const auto &a : m_discoveredDeviceAddr) {
            if (a.first == ip && a.second == port) { duplicate = true; break; }
        }
        if (duplicate) continue;

        QString display = extra.isEmpty()
            ? QString("%1:%2").arg(ip).arg(port)
            : QString("%3 @ %1:%2").arg(ip).arg(port).arg(extra);

        addDiscoveredDevice(display, ip, port);
        appendLog(QString("[发现设备] %1").arg(display));
        emit deviceFound(ip, port, extra);
    }
}

void WSClient::onDiscoveryTimeout()
{
    if (!m_discovering) return;
    m_discovering = false;
    emit discoveringChanged();
    if (m_discoverySocket->state() != QAbstractSocket::UnconnectedState) {
        m_discoverySocket->close();
    }
    appendLog(QString("[搜索完成] 共找到 %1 台设备").arg(m_discoveredDevices.size()));
}

void WSClient::addDiscoveredDevice(const QString &displayName,
                                     const QString &ip, int port)
{
    m_discoveredDevices.append(displayName);
    m_discoveredDeviceAddr.append(qMakePair(ip, port));
    emit discoveredDevicesChanged();
}

// ============================================================
// QWebSocket 槽函数
// ============================================================

void WSClient::onConnected()
{
    m_connected = true;
    appendLog(QString("[WebSocket] 已连接 %1").arg(buildServerUrl().toString()));
    if (WS_PING_INTERVAL > 0) m_pingTimer->start();
    emit connectedChanged();
}

void WSClient::onDisconnected()
{
    m_connected = false;
    m_pingTimer->stop();
    appendLog(QString("[断开] 连接已关闭 (code=%1, reason=%2)")
                  .arg(m_socket->closeCode())
                  .arg(m_socket->closeReason().isEmpty() ? "-" : m_socket->closeReason()));
    emit connectedChanged();

    if (WS_AUTO_RECONNECT && !m_manualDisconnect) {
        appendLog(QString("[自动重连] %1ms 后重试...").arg(WS_RECONNECT_INTERVAL));
        m_reconnectTimer->start();
    }
}

void WSClient::onTextMessageReceived(const QString &message)
{
    appendLog(QString("[收到] %1").arg(message));
    emit newMessageReceived(QString(), message);
}

void WSClient::onErrorOccurred(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error)
    appendLog(QString("[错误] %1").arg(m_socket->errorString()));
}

void WSClient::onStateChanged(QAbstractSocket::SocketState state)
{
    switch (state) {
    case QAbstractSocket::ConnectingState:
        appendLog("[状态] 正在建立连接..."); break;
    case QAbstractSocket::ClosingState:
        appendLog("[状态] 正在关闭连接..."); break;
    default:
        break;
    }
}

void WSClient::onReconnectTimer()
{
    if (!m_connected && !m_manualDisconnect) {
        connectToBroker();
    }
}

void WSClient::onPingTimer()
{
    if (m_connected) {
        m_socket->ping();
    }
}

// ============================================================
// 工具
// ============================================================

QUrl WSClient::buildServerUrl() const
{
    QUrl url;
    url.setScheme("ws");
    url.setHost(m_serverHost);
    url.setPort(m_serverPort);
    url.setPath(m_serverPath.startsWith("/") ? m_serverPath : "/" + m_serverPath);
    return url;
}

void WSClient::appendLog(const QString &line)
{
    QString ts = QDateTime::currentDateTime().toString("hh:mm:ss");
    m_receivedMessages.append(QString("[%1] %2\n").arg(ts, line));
    emit receivedMessagesChanged();
}
