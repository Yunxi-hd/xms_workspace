/*
 * ws_config.h — WebSocket 通讯参数统一配置
 *
 * 对应 ESP32 端 websocket.cc：
 *   端口 8080，路径 /ws，纯文本帧。
 *
 * 使用方式：在 wsclient.cpp 中 #include "ws_config.h"
 */

#ifndef WS_CONFIG_H
#define WS_CONFIG_H

// ============================================================
// WebSocket 服务器连接参数（ESP32 小车端）
// ============================================================

// 服务器地址（默认值仅占位；推荐使用"搜索设备"功能自动发现）
#define WS_DEFAULT_HOST        "192.168.1.100"

// 服务器端口（与 ESP32 websocket.cc 中 config.server_port = 8080 保持一致）
#define WS_DEFAULT_PORT        8080

// WebSocket 路径（与 ESP32 ws_uri.uri = "/ws" 保持一致）
#define WS_DEFAULT_PATH        "/ws"

// 连接超时（毫秒）
#define WS_CONNECT_TIMEOUT     5000

// 心跳（Ping）间隔（毫秒），0 = 关闭
#define WS_PING_INTERVAL       30000

// 断线自动重连
#define WS_AUTO_RECONNECT      true

// 重连间隔（毫秒）
#define WS_RECONNECT_INTERVAL  3000


// ============================================================
// UDP 自动发现（ESP32 广播 + Qt 监听）
// ============================================================

// UDP 广播端口（ESP32 和 Qt 必须一致）
#define DISCOVERY_UDP_PORT     4210

// UDP 广播间隔（毫秒），ESP32 每隔多久发一次自己的 IP
#define DISCOVERY_INTERVAL_MS  2000

// Qt 端搜索时长（毫秒），点"搜索设备"后监听多久
#define DISCOVERY_TIMEOUT_MS   4000

// UDP 广播包开头标识符（过滤无关网络包）
#define DISCOVERY_MAGIC        "XIAOZHI_PANDA_V1"


// ============================================================
// 本地存储键名（QSettings 用）
// ============================================================

#define WS_SETTINGS_GROUP      "WsConfig"
#define WS_SETTINGS_KEY_HOST   "host"
#define WS_SETTINGS_KEY_PORT   "port"
#define WS_SETTINGS_KEY_PATH   "path"

#endif // WS_CONFIG_H
