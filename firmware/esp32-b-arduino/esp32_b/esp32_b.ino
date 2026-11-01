#include <Arduino.h>
#include <ArduinoJson.h>
#include <Adafruit_PN532.h>
#include <WebSocketsClient.h>
#include <Wire.h>
#include <WiFi.h>
#include <esp_arduino_version.h>
#include <esp_system.h>
#include <mbedtls/md.h>
#include <time.h>

#include "broker_root_ca.h"
#include "secrets.h"

#if ESP_ARDUINO_VERSION < ESP_ARDUINO_VERSION_VAL(3, 0, 4)
#error "Gunakan Arduino-ESP32 core 3.0.4 atau lebih baru."
#endif

#if WEBSOCKETS_VERSION_MAJOR < 2
#error "Gunakan library WebSockets versi 2 atau lebih baru."
#endif

namespace {

constexpr char kDeviceId[] = "esp2";
constexpr char kBrokerHost[] = "mqtt-smartbin.ramadhanjp.my.id";
constexpr char kBrokerPath[] = "/mqtt";
constexpr uint16_t kBrokerPort = 443;
constexpr char kClientId[] = "smartbin-esp2";
constexpr char kStatusTopic[] = "smartbin/esp2/telemetry/status";
constexpr char kAuthTopic[] = "smartbin/esp2/telemetry/auth";
constexpr char kAuthReplyTopic[] = "smartbin/esp2/command/auth";
constexpr char kControlTopic[] = "smartbin/esp2/command/control";

constexpr int kPn532SdaPin = 21;
constexpr int kPn532SclPin = 22;
constexpr int kCardSlotPin = 4;
constexpr int kUartRxPin = 16;
constexpr int kUartTxPin = 17;
constexpr int kPn532IrqUnusedPin = 34;
constexpr int kPn532ResetUnusedPin = 27;

constexpr uint32_t kHeartbeatIntervalMs = 10000;
constexpr uint32_t kCardSlotDebounceMs = 50;
constexpr uint32_t kAuthTimeoutMs = 5000;
constexpr uint32_t kMqttKeepAliveMs = 15000;
constexpr uint32_t kMqttPingTimeoutMs = 10000;
constexpr size_t kMqttPacketCapacity = 1400;
constexpr size_t kWebSocketPacketCapacity = 2048;
constexpr size_t kUartLineCapacity = 1300;

WebSocketsClient webSocket;
Adafruit_PN532 pn532(kPn532IrqUnusedPin, kPn532ResetUnusedPin, &Wire);

bool websocketConnected = false;
bool mqttConnected = false;
bool pn532Online = false;
bool cardSlotPresent = false;
bool candidateSlotPresent = false;
bool candidateSlotInitialized = false;
bool cardActive = false;
bool authRequestPending = false;
bool authSent = false;
bool mqttPingPending = false;

char cardUidHash[65] = {};
char pendingRequestId[37] = {};
char uartLine[kUartLineCapacity] = {};
size_t uartLineLength = 0;
uint32_t slotCandidateSinceMs = 0;
uint32_t lastHeartbeatMs = 0;
uint32_t lastMqttPacketMs = 0;
uint32_t mqttPingStartedMs = 0;
uint32_t authStartedMs = 0;
uint16_t nextPacketId = 1;
uint8_t webSocketPacket[kWebSocketPacketCapacity] = {};
size_t webSocketPacketLength = 0;
bool collectingWebSocketFragments = false;

bool elapsed(uint32_t now, uint32_t then, uint32_t interval)
{
    return static_cast<uint32_t>(now - then) >= interval;
}

bool makeTimestamp(char *output, size_t outputSize)
{
    const time_t now = time(nullptr);
    if (now < 1700000000 || output == nullptr || outputSize == 0) {
        return false;
    }

    struct tm utcTime;
    if (gmtime_r(&now, &utcTime) == nullptr) {
        return false;
    }
    return strftime(output, outputSize, "%Y-%m-%dT%H:%M:%SZ", &utcTime) > 0;
}

bool makeUuid(char output[37])
{
    uint8_t bytes[16];
    esp_fill_random(bytes, sizeof(bytes));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    const int written = snprintf(
        output,
        37,
        "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6],
        bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13],
        bytes[14], bytes[15]);
    return written == 36;
}

bool makeUidHash(const uint8_t *uid, size_t uidLength, char output[65])
{
    static constexpr char kHex[] = "0123456789ABCDEF";
    char normalizedUid[21] = {};
    uint8_t digest[32];
    const mbedtls_md_info_t *sha256 =
        mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);

    if (uid == nullptr || uidLength == 0 || uidLength > 10 || sha256 == nullptr) {
        return false;
    }
    for (size_t i = 0; i < uidLength; ++i) {
        normalizedUid[i * 2] = kHex[uid[i] >> 4];
        normalizedUid[i * 2 + 1] = kHex[uid[i] & 0x0f];
    }

    if (mbedtls_md_hmac(
            sha256,
            reinterpret_cast<const unsigned char *>(SMARTBIN_CARD_HMAC_SECRET),
            strlen(SMARTBIN_CARD_HMAC_SECRET),
            reinterpret_cast<const unsigned char *>(normalizedUid),
            uidLength * 2,
            digest) != 0) {
        return false;
    }

    for (size_t i = 0; i < sizeof(digest); ++i) {
        snprintf(&output[i * 2], 3, "%02x", digest[i]);
    }
    output[64] = '\0';
    memset(normalizedUid, 0, sizeof(normalizedUid));
    memset(digest, 0, sizeof(digest));
    return true;
}

bool appendByte(uint8_t *buffer, size_t capacity, size_t &length, uint8_t value)
{
    if (length >= capacity) {
        return false;
    }
    buffer[length++] = value;
    return true;
}

bool appendBytes(
    uint8_t *buffer,
    size_t capacity,
    size_t &length,
    const uint8_t *data,
    size_t dataLength)
{
    if (dataLength > capacity - length) {
        return false;
    }
    memcpy(buffer + length, data, dataLength);
    length += dataLength;
    return true;
}

bool appendMqttString(
    uint8_t *buffer,
    size_t capacity,
    size_t &length,
    const char *value)
{
    if (value == nullptr) {
        return false;
    }
    const size_t valueLength = strlen(value);
    if (valueLength > UINT16_MAX || capacity - length < valueLength + 2) {
        return false;
    }
    buffer[length++] = static_cast<uint8_t>(valueLength >> 8);
    buffer[length++] = static_cast<uint8_t>(valueLength);
    memcpy(buffer + length, value, valueLength);
    length += valueLength;
    return true;
}

size_t encodeRemainingLength(uint8_t output[4], size_t remainingLength)
{
    size_t count = 0;
    do {
        uint8_t digit = static_cast<uint8_t>(remainingLength % 128);
        remainingLength /= 128;
        if (remainingLength > 0) {
            digit |= 0x80;
        }
        output[count++] = digit;
    } while (remainingLength > 0 && count < 4);
    return remainingLength == 0 ? count : 0;
}

bool sendMqttPacket(uint8_t header, const uint8_t *body, size_t bodyLength)
{
    if (!websocketConnected || bodyLength > kMqttPacketCapacity - 5) {
        return false;
    }

    uint8_t packet[kMqttPacketCapacity];
    packet[0] = header;
    uint8_t encodedLength[4];
    const size_t encodedLengthSize = encodeRemainingLength(encodedLength, bodyLength);
    if (encodedLengthSize == 0) {
        return false;
    }

    size_t packetLength = 1;
    if (!appendBytes(
            packet, sizeof(packet), packetLength,
            encodedLength, encodedLengthSize) ||
        !appendBytes(packet, sizeof(packet), packetLength, body, bodyLength)) {
        return false;
    }

    return webSocket.sendBIN(packet, packetLength);
}

uint16_t reservePacketId()
{
    const uint16_t result = nextPacketId++;
    if (nextPacketId == 0) {
        nextPacketId = 1;
    }
    return result == 0 ? reservePacketId() : result;
}

bool sendMqttConnect()
{
    uint8_t body[512];
    size_t bodyLength = 0;
    constexpr uint8_t kConnectFlags =
        0x80 | 0x40 | 0x08 | 0x04 | 0x02;
    const char willMessage[] =
        "{\"schema_version\":1,\"device_id\":\"esp2\",\"state\":\"OFFLINE\"}";

    if (!appendMqttString(body, sizeof(body), bodyLength, "MQTT") ||
        !appendByte(body, sizeof(body), bodyLength, 4) ||
        !appendByte(body, sizeof(body), bodyLength, kConnectFlags) ||
        !appendByte(body, sizeof(body), bodyLength, 0) ||
        !appendByte(body, sizeof(body), bodyLength, 30) ||
        !appendMqttString(body, sizeof(body), bodyLength, kClientId) ||
        !appendMqttString(body, sizeof(body), bodyLength, kStatusTopic) ||
        !appendMqttString(body, sizeof(body), bodyLength, willMessage) ||
        !appendMqttString(body, sizeof(body), bodyLength, SMARTBIN_MQTT_USERNAME) ||
        !appendMqttString(body, sizeof(body), bodyLength, SMARTBIN_MQTT_PASSWORD)) {
        Serial.println("[MQTT] Gagal menyusun CONNECT.");
        return false;
    }
    mqttConnected = false;
    return sendMqttPacket(0x10, body, bodyLength);
}

bool sendMqttSubscribe(const char *topic)
{
    uint8_t body[256];
    size_t bodyLength = 0;
    const uint16_t packetId = reservePacketId();
    if (!appendByte(body, sizeof(body), bodyLength, packetId >> 8) ||
        !appendByte(body, sizeof(body), bodyLength, packetId & 0xff) ||
        !appendMqttString(body, sizeof(body), bodyLength, topic) ||
        !appendByte(body, sizeof(body), bodyLength, 1)) {
        return false;
    }
    return sendMqttPacket(0x82, body, bodyLength);
}

bool sendMqttPublish(const char *topic, const char *payload, uint8_t qos = 1)
{
    if (!mqttConnected || topic == nullptr || payload == nullptr || qos > 1) {
        return false;
    }
    uint8_t body[kMqttPacketCapacity];
    size_t bodyLength = 0;
    if (!appendMqttString(body, sizeof(body), bodyLength, topic)) {
        return false;
    }
    if (qos == 1) {
        const uint16_t packetId = reservePacketId();
        if (!appendByte(body, sizeof(body), bodyLength, packetId >> 8) ||
            !appendByte(body, sizeof(body), bodyLength, packetId & 0xff)) {
            return false;
        }
    }

    const size_t payloadLength = strlen(payload);
    if (!appendBytes(
            body, sizeof(body), bodyLength,
            reinterpret_cast<const uint8_t *>(payload), payloadLength)) {
        return false;
    }
    return sendMqttPacket(qos == 1 ? 0x32 : 0x30, body, bodyLength);
}

bool publishStatus()
{
    char timestamp[25];
    if (!makeTimestamp(timestamp, sizeof(timestamp))) {
        Serial.println("[STATUS] Waktu belum tersinkron; status belum dikirim.");
        return false;
    }

    JsonDocument document;
    document["schema_version"] = 1;
    document["device_id"] = kDeviceId;
    document["timestamp"] = timestamp;
    document["state"] = pn532Online ? "IDLE" : "GANGGUAN";
    document["pn532_online"] = pn532Online;
    document["ai_online"] = false;
    document["uptime_s"] = millis() / 1000;

    String payload;
    serializeJson(document, payload);
    if (!sendMqttPublish(kStatusTopic, payload.c_str())) {
        return false;
    }
    Serial.println("[STATUS] Heartbeat terkirim.");
    lastHeartbeatMs = millis();
    return true;
}

void sendNetworkState(bool online)
{
    Serial2.printf("NET %s\n", online ? "online" : "offline");
}

bool sendMqttAuthRequest()
{
    if (!mqttConnected || !cardActive || authSent) {
        return false;
    }
    char timestamp[25];
    if (!makeUuid(pendingRequestId) ||
        !makeTimestamp(timestamp, sizeof(timestamp))) {
        Serial.println("[AUTH] Gagal membuat ID atau timestamp.");
        return false;
    }

    JsonDocument document;
    document["request_id"] = pendingRequestId;
    document["uid_hash"] = cardUidHash;
    document["timestamp"] = timestamp;
    String payload;
    serializeJson(document, payload);
    if (!sendMqttPublish(kAuthTopic, payload.c_str())) {
        pendingRequestId[0] = '\0';
        return false;
    }

    authSent = true;
    authRequestPending = true;
    authStartedMs = millis();
    Serial.println("[AUTH] Permintaan validasi dikirim (UID tidak dicatat).");
    return true;
}

void sendMqttAck(uint8_t packetType, uint16_t packetId)
{
    uint8_t body[] = {
        static_cast<uint8_t>(packetId >> 8),
        static_cast<uint8_t>(packetId & 0xff),
    };
    sendMqttPacket(packetType, body, sizeof(body));
}

void forwardMqttMessageToEsp32A(const char *topic, const char *payload)
{
    Serial2.printf("MQTT_MSG %s %s\n", topic, payload);
}

void handleAuthReply(const char *payload)
{
    JsonDocument reply;
    if (deserializeJson(reply, payload) != DeserializationError::Ok) {
        Serial.println("[AUTH] Balasan bukan JSON valid.");
        return;
    }
    const char *requestId = reply["request_id"] | "";
    if (!authRequestPending || strcmp(requestId, pendingRequestId) != 0) {
        Serial.println("[AUTH] Balasan tidak cocok dengan permintaan aktif.");
        return;
    }

    authRequestPending = false;
    pendingRequestId[0] = '\0';
    const bool found = reply["found"] | false;
    Serial.println(found ? "[AUTH] Kartu terdaftar." : "[AUTH] Kartu belum terdaftar.");
}

void handleControlCommand(const char *payload)
{
    JsonDocument commandBody;
    if (deserializeJson(commandBody, payload) != DeserializationError::Ok) {
        Serial.println("[MQTT] Command bukan JSON valid.");
        return;
    }
    const char *command = commandBody["command"] | "";
    if (strcmp(command, "ping") == 0) {
        Serial.println("[MQTT] Command ping diterima.");
        publishStatus();
    } else {
        Serial.println("[MQTT] Command aktuator diabaikan pada firmware uji.");
    }
}

bool decodeRemainingLength(
    const uint8_t *packet,
    size_t packetLength,
    size_t &offset,
    size_t &remainingLength)
{
    remainingLength = 0;
    uint32_t multiplier = 1;
    for (uint8_t count = 0; count < 4; ++count) {
        if (offset >= packetLength) {
            return false;
        }
        const uint8_t digit = packet[offset++];
        remainingLength += (digit & 0x7f) * multiplier;
        if ((digit & 0x80) == 0) {
            return true;
        }
        multiplier *= 128;
    }
    return false;
}

bool readMqttString(
    const uint8_t *packet,
    size_t packetEnd,
    size_t &offset,
    char *output,
    size_t outputCapacity)
{
    if (offset + 2 > packetEnd) {
        return false;
    }
    const size_t length =
        (static_cast<size_t>(packet[offset]) << 8) | packet[offset + 1];
    offset += 2;
    if (length + 1 > outputCapacity || offset + length > packetEnd) {
        return false;
    }
    memcpy(output, packet + offset, length);
    output[length] = '\0';
    offset += length;
    return true;
}

void handleMqttPublish(
    uint8_t header,
    const uint8_t *packet,
    size_t packetEnd,
    size_t &offset)
{
    char topic[128];
    if (!readMqttString(packet, packetEnd, offset, topic, sizeof(topic))) {
        Serial.println("[MQTT] PUBLISH dengan topic tidak valid.");
        return;
    }

    const uint8_t qos = (header >> 1) & 0x03;
    uint16_t packetId = 0;
    if (qos == 1) {
        if (offset + 2 > packetEnd) {
            return;
        }
        packetId = (static_cast<uint16_t>(packet[offset]) << 8) | packet[offset + 1];
        offset += 2;
    } else if (qos > 1) {
        Serial.println("[MQTT] QoS 2 tidak didukung; koneksi ditutup.");
        webSocket.disconnect();
        return;
    }

    const size_t payloadLength = packetEnd - offset;
    if (payloadLength >= 1024) {
        Serial.println("[MQTT] Payload melebihi batas ukuran.");
        if (qos == 1) {
            sendMqttAck(0x40, packetId);
        }
        return;
    }
    char payload[1024];
    memcpy(payload, packet + offset, payloadLength);
    payload[payloadLength] = '\0';

    if (strcmp(topic, kAuthReplyTopic) == 0) {
        handleAuthReply(payload);
    } else if (strcmp(topic, kControlTopic) == 0) {
        handleControlCommand(payload);
    }
    forwardMqttMessageToEsp32A(topic, payload);
    if (qos == 1) {
        sendMqttAck(0x40, packetId);
    }
}

void processMqttPackets(const uint8_t *data, size_t dataLength)
{
    size_t offset = 0;
    while (offset < dataLength) {
        const uint8_t header = data[offset++];
        size_t remainingLength = 0;
        if (!decodeRemainingLength(data, dataLength, offset, remainingLength) ||
            remainingLength > dataLength - offset) {
            Serial.println("[MQTT] Paket WebSocket bukan frame MQTT lengkap.");
            return;
        }
        const size_t packetEnd = offset + remainingLength;
        const uint8_t packetType = header >> 4;

        switch (packetType) {
        case 2:
            if (remainingLength != 2 || data[offset] != 0 ||
                data[offset + 1] != 0) {
                Serial.println("[MQTT] Broker menolak CONNECT.");
                mqttConnected = false;
                webSocket.disconnect();
                return;
            }
            mqttConnected = true;
            lastMqttPacketMs = millis();
            mqttPingPending = false;
            sendNetworkState(true);
            sendMqttSubscribe(kAuthReplyTopic);
            sendMqttSubscribe(kControlTopic);
            Serial.println("[MQTT] WSS/MQTT tersambung.");
            publishStatus();
            if (cardActive) {
                sendMqttAuthRequest();
            }
            break;
        case 3:
            handleMqttPublish(header, data, packetEnd, offset);
            break;
        case 4:
            if (remainingLength != 2) {
                Serial.println("[MQTT] PUBACK tidak valid.");
                return;
            }
            break;
        case 9:
            if (remainingLength < 3) {
                Serial.println("[MQTT] SUBACK tidak valid.");
                return;
            }
            break;
        case 13:
            mqttPingPending = false;
            break;
        default:
            break;
        }

        offset = packetEnd;
        lastMqttPacketMs = millis();
    }
}

void appendWebSocketFragment(const uint8_t *data, size_t length, bool finish)
{
    if (data == nullptr || length > sizeof(webSocketPacket) - webSocketPacketLength) {
        webSocketPacketLength = 0;
        collectingWebSocketFragments = false;
        Serial.println("[WSS] Fragment melebihi kapasitas; diabaikan.");
        return;
    }
    memcpy(webSocketPacket + webSocketPacketLength, data, length);
    webSocketPacketLength += length;
    if (finish) {
        processMqttPackets(webSocketPacket, webSocketPacketLength);
        webSocketPacketLength = 0;
        collectingWebSocketFragments = false;
    }
}

void webSocketEvent(WStype_t type, uint8_t *payload, size_t length)
{
    switch (type) {
    case WStype_CONNECTED:
        websocketConnected = true;
        mqttConnected = false;
        mqttPingPending = false;
        Serial.println("[WSS] TLS/WebSocket tersambung; mengirim MQTT CONNECT.");
        if (!sendMqttConnect()) {
            Serial.println("[MQTT] Gagal mengirim CONNECT.");
            webSocket.disconnect();
        }
        break;
    case WStype_DISCONNECTED:
        websocketConnected = false;
        mqttConnected = false;
        mqttPingPending = false;
        sendNetworkState(false);
        Serial.println("[WSS] Terputus; akan mencoba menyambung ulang.");
        break;
    case WStype_BIN:
        processMqttPackets(payload, length);
        break;
    case WStype_FRAGMENT_BIN_START:
        webSocketPacketLength = 0;
        collectingWebSocketFragments = true;
        appendWebSocketFragment(payload, length, false);
        break;
    case WStype_FRAGMENT:
        if (collectingWebSocketFragments) {
            appendWebSocketFragment(payload, length, false);
        }
        break;
    case WStype_FRAGMENT_FIN:
        if (collectingWebSocketFragments) {
            appendWebSocketFragment(payload, length, true);
        }
        break;
    case WStype_ERROR:
        Serial.println("[WSS] Error koneksi.");
        break;
    default:
        break;
    }
}

void readUartCommands()
{
    while (Serial2.available() > 0) {
        const char value = static_cast<char>(Serial2.read());
        if (value == '\r') {
            continue;
        }
        if (value == '\n') {
            uartLine[uartLineLength] = '\0';
            if (strncmp(uartLine, "MQTT_PUB ", 9) == 0) {
                char *topic = uartLine + 9;
                char *separator = strchr(topic, ' ');
                if (separator == nullptr) {
                    Serial.println("[UART] Format MQTT_PUB tidak valid.");
                } else {
                    *separator = '\0';
                    const char *payload = separator + 1;
                    constexpr char kAllowedTopicPrefix[] =
                        "smartbin/esp2/telemetry/";
                    if (strncmp(topic, kAllowedTopicPrefix,
                                sizeof(kAllowedTopicPrefix) - 1) == 0 &&
                        topic[sizeof(kAllowedTopicPrefix) - 1] != '\0' &&
                        strchr(topic, '+') == nullptr &&
                        strchr(topic, '#') == nullptr &&
                        payload[0] != '\0') {
                        if (!sendMqttPublish(topic, payload)) {
                            Serial.println("[UART] Publish MQTT gagal.");
                        }
                    } else {
                        Serial.println("[UART] Topic MQTT_PUB tidak diizinkan.");
                    }
                }
            } else if (uartLineLength > 0) {
                Serial.println("[UART] Perintah ESP32-A diabaikan.");
            }
            uartLineLength = 0;
            continue;
        }
        if (uartLineLength + 1 < sizeof(uartLine)) {
            uartLine[uartLineLength++] = value;
        } else {
            uartLineLength = 0;
            Serial.println("[UART] Baris terlalu panjang; dibuang.");
        }
    }
}

void pollCardReader()
{
    static uint8_t uid[10];
    uint8_t uidLength = 0;
    if (!cardSlotPresent || !pn532Online || cardActive) {
        return;
    }

    if (!pn532.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength, 50)) {
        return;
    }
    if (!makeUidHash(uid, uidLength, cardUidHash)) {
        Serial.println("[PN532] UID tidak valid atau HMAC gagal.");
        memset(uid, 0, sizeof(uid));
        return;
    }

    cardActive = true;
    Serial2.printf("CARD_IN %s\n", cardUidHash);
    Serial.println("[PN532] Kartu terbaca; UID mentah tidak dicatat.");
    sendMqttAuthRequest();
    memset(uid, 0, sizeof(uid));
}

void updateCardSlot()
{
    const uint32_t now = millis();
    const bool rawPresent = digitalRead(kCardSlotPin) == LOW;
    if (!candidateSlotInitialized || rawPresent != candidateSlotPresent) {
        candidateSlotPresent = rawPresent;
        slotCandidateSinceMs = now;
        candidateSlotInitialized = true;
        return;
    }
    if (rawPresent == cardSlotPresent ||
        !elapsed(now, slotCandidateSinceMs, kCardSlotDebounceMs)) {
        return;
    }

    cardSlotPresent = rawPresent;
    if (!cardSlotPresent) {
        if (cardActive) {
            memset(cardUidHash, 0, sizeof(cardUidHash));
            cardActive = false;
        }
        authRequestPending = false;
        authSent = false;
        pendingRequestId[0] = '\0';
        Serial2.println("CARD_OUT");
        Serial.println("[SLOT] KTP dikeluarkan.");
    }
}

void checkAuthTimeout()
{
    if (authRequestPending && elapsed(millis(), authStartedMs, kAuthTimeoutMs)) {
        authRequestPending = false;
        pendingRequestId[0] = '\0';
        Serial.println("[AUTH] Waktu tunggu validasi habis.");
    }
}

void maintainMqttConnection()
{
    if (!mqttConnected) {
        return;
    }

    const uint32_t now = millis();
    if (mqttPingPending && elapsed(now, mqttPingStartedMs, kMqttPingTimeoutMs)) {
        Serial.println("[MQTT] PINGRESP timeout; memutus koneksi.");
        webSocket.disconnect();
        return;
    }
    if (!mqttPingPending && elapsed(now, lastMqttPacketMs, kMqttKeepAliveMs)) {
        const uint8_t pingRequest[] = {0xC0, 0x00};
        if (webSocket.sendBIN(pingRequest, sizeof(pingRequest))) {
            mqttPingPending = true;
            mqttPingStartedMs = now;
        }
    }
}

void connectWifi()
{
    if (WiFi.status() == WL_CONNECTED) {
        return;
    }
    Serial.printf("[WiFi] Menyambung ke %s...\n", SMARTBIN_WIFI_SSID);
    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    WiFi.begin(SMARTBIN_WIFI_SSID, SMARTBIN_WIFI_PASSWORD);
    const uint32_t started = millis();
    while (WiFi.status() != WL_CONNECTED && !elapsed(millis(), started, 30000)) {
        delay(250);
    }
    if (WiFi.status() == WL_CONNECTED) {
        Serial.print("[WiFi] Tersambung, IP ");
        Serial.println(WiFi.localIP());
    } else {
        Serial.println("[WiFi] Belum tersambung; koneksi otomatis aktif.");
    }
}

void synchronizeClock()
{
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");
    const uint32_t started = millis();
    while (time(nullptr) < 1700000000 &&
           !elapsed(millis(), started, 30000)) {
        delay(250);
    }
    if (time(nullptr) >= 1700000000) {
        Serial.println("[NTP] Waktu UTC tersinkron.");
    } else {
        Serial.println("[NTP] Belum tersinkron; timestamp belum bisa dipakai.");
    }
}

void startSecureWebSocket()
{
    webSocket.onEvent(webSocketEvent);
    webSocket.setReconnectInterval(5000);
    webSocket.enableHeartbeat(15000, 3000, 2);
    webSocket.beginSslWithCA(
        kBrokerHost, kBrokerPort, kBrokerPath, kBrokerRootCa, "mqtt");
    Serial.println("[WSS] Memulai koneksi TLS dengan verifikasi GTS Root R4.");
}

void initializePn532()
{
    Wire.begin(kPn532SdaPin, kPn532SclPin);
    pn532.begin();
    const uint32_t version = pn532.getFirmwareVersion();
    if (version == 0 || !pn532.SAMConfig()) {
        Serial.println("[PN532] Tidak terdeteksi; periksa mode I2C dan wiring.");
        pn532Online = false;
        return;
    }
    pn532Online = true;
    Serial.printf("[PN532] Siap, firmware 0x%08lX.\n",
                  static_cast<unsigned long>(version));
}

}  // namespace

void setup()
{
    Serial.begin(115200);
    Serial2.begin(115200, SERIAL_8N1, kUartRxPin, kUartTxPin);
    pinMode(kCardSlotPin, INPUT_PULLUP);

    Serial.println();
    Serial.println("SmartBIN ESP32-B Arduino test firmware");
    initializePn532();
    connectWifi();
    if (WiFi.status() == WL_CONNECTED) {
        synchronizeClock();
    }
    startSecureWebSocket();
}

void loop()
{
    webSocket.loop();
    readUartCommands();
    updateCardSlot();
    pollCardReader();
    checkAuthTimeout();
    maintainMqttConnection();

    if (mqttConnected && elapsed(millis(), lastHeartbeatMs, kHeartbeatIntervalMs)) {
        publishStatus();
    }
    if (cardActive && !authSent && mqttConnected) {
        sendMqttAuthRequest();
    }
    delay(5);
}
