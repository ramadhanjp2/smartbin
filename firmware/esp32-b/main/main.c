#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "cJSON.h"
#include "driver/gpio.h"
#include "driver/i2c_master.h"
#include "driver/uart.h"
#include "esp_crt_bundle.h"
#include "esp_check.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_mqtt_client.h"
#include "esp_netif.h"
#include "esp_netif_sntp.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "esp_wifi.h"
#include "mbedtls/md.h"
#include "nvs_flash.h"
#include "pn532.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/task.h"

#define DEVICE_ID "esp2"
#define MQTT_URI "wss://mqtt-smartbin.ramadhanjp.my.id:443/mqtt"
#define MQTT_STATUS_TOPIC "smartbin/" DEVICE_ID "/telemetry/status"
#define MQTT_AUTH_TOPIC "smartbin/" DEVICE_ID "/telemetry/auth"
#define MQTT_AUTH_COMMAND_TOPIC "smartbin/" DEVICE_ID "/command/auth"
#define MQTT_CONTROL_TOPIC "smartbin/" DEVICE_ID "/command/control"
#define UART_A_TX_GPIO GPIO_NUM_17
#define UART_A_RX_GPIO GPIO_NUM_16
#define UART_A_PORT UART_NUM_2
#define UART_A_BAUD 115200
#define UART_A_RX_BUFFER_SIZE 256
#define UART_A_LINE_MAX 1200
#define CARD_SLOT_DEBOUNCE_MS 50
#define HEARTBEAT_INTERVAL_MS 10000
#define AUTH_TIMEOUT_MS 5000
#define WIFI_MAX_RETRIES 8
#define MQTT_CONNECTED_BIT BIT0
#define WIFI_CONNECTED_BIT BIT1

static const char *TAG = "smartbin-esp2";
static EventGroupHandle_t event_group;
static esp_mqtt_client_handle_t mqtt_client;
static pn532_t *pn532;
static bool pn532_online;
static SemaphoreHandle_t uart_tx_mutex;
static portMUX_TYPE pending_request_mux = portMUX_INITIALIZER_UNLOCKED;
static char pending_request_id[37];
static int64_t pending_request_started_ms;
static bool pending_request_active;

static bool uart_send_line(const char *line)
{
    if (line == NULL || uart_tx_mutex == NULL ||
        xSemaphoreTake(uart_tx_mutex, pdMS_TO_TICKS(1000)) != pdTRUE) {
        ESP_LOGE(TAG, "Tidak dapat mengirim pesan UART ke ESP32-A");
        return false;
    }

    size_t length = strlen(line);
    int written = uart_write_bytes(UART_A_PORT, line, length);
    if (written != (int)length) {
        ESP_LOGE(TAG, "Pesan UART ke ESP32-A tidak terkirim lengkap");
        xSemaphoreGive(uart_tx_mutex);
        return false;
    }
    if (uart_write_bytes(UART_A_PORT, "\n", 1) != 1) {
        ESP_LOGE(TAG, "Gagal mengirim akhir baris UART");
        xSemaphoreGive(uart_tx_mutex);
        return false;
    }

    xSemaphoreGive(uart_tx_mutex);
    return true;
}

static void send_network_state(bool online)
{
    char line[24];
    snprintf(line, sizeof(line), "NET %s", online ? "online" : "offline");
    uart_send_line(line);
}

static bool get_iso8601_utc(char *buffer, size_t buffer_size)
{
    time_t now = time(NULL);
    if (now < 1700000000) {
        return false;
    }

    struct tm utc_time;
    if (gmtime_r(&now, &utc_time) == NULL) {
        return false;
    }

    return strftime(buffer, buffer_size, "%Y-%m-%dT%H:%M:%SZ", &utc_time) > 0;
}

static bool make_uuid(char uuid[37])
{
    uint8_t bytes[16];
    esp_fill_random(bytes, sizeof(bytes));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    int written = snprintf(
        uuid,
        37,
        "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6],
        bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13],
        bytes[14], bytes[15]);
    return written == 36;
}

static bool make_uid_hash(const uint8_t *uid, size_t uid_length, char hash_hex[65])
{
    static const char HEX[] = "0123456789ABCDEF";
    char normalized_uid[21];
    uint8_t digest[32];
    const mbedtls_md_info_t *sha256 = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
    if (uid == NULL || uid_length == 0 || uid_length > 10 || sha256 == NULL) {
        return false;
    }

    for (size_t i = 0; i < uid_length; i++) {
        normalized_uid[i * 2] = HEX[uid[i] >> 4];
        normalized_uid[i * 2 + 1] = HEX[uid[i] & 0x0f];
    }
    normalized_uid[uid_length * 2] = '\0';

    if (mbedtls_md_hmac(
            sha256,
            (const unsigned char *)CONFIG_SMARTBIN_CARD_HMAC_SECRET,
            strlen(CONFIG_SMARTBIN_CARD_HMAC_SECRET),
            (const unsigned char *)normalized_uid,
            uid_length * 2,
            digest) != 0) {
        return false;
    }

    for (size_t i = 0; i < sizeof(digest); i++) {
        snprintf(&hash_hex[i * 2], 3, "%02x", digest[i]);
    }
    hash_hex[64] = '\0';
    return true;
}

static bool publish_status(void)
{
    char timestamp[25];
    if (!get_iso8601_utc(timestamp, sizeof(timestamp))) {
        ESP_LOGW(TAG, "Belum ada waktu UTC yang valid; status tidak dikirim");
        return false;
    }

    cJSON *status = cJSON_CreateObject();
    if (status == NULL) {
        ESP_LOGE(TAG, "Tidak dapat membuat payload status");
        return false;
    }
    cJSON_AddNumberToObject(status, "schema_version", 1);
    cJSON_AddStringToObject(status, "device_id", DEVICE_ID);
    cJSON_AddStringToObject(status, "timestamp", timestamp);
    cJSON_AddStringToObject(status, "state", pn532_online ? "IDLE" : "GANGGUAN");
    cJSON_AddBoolToObject(status, "pn532_online", pn532_online);
    cJSON_AddBoolToObject(status, "ai_online", false);
    cJSON_AddNumberToObject(status, "uptime_s", (double)(esp_timer_get_time() / 1000000));

    char *payload = cJSON_PrintUnformatted(status);
    cJSON_Delete(status);
    if (payload == NULL) {
        ESP_LOGE(TAG, "Tidak dapat membuat JSON status");
        return false;
    }

    int message_id = esp_mqtt_client_publish(
        mqtt_client, MQTT_STATUS_TOPIC, payload, 0, 1, 0);
    free(payload);
    if (message_id < 0) {
        ESP_LOGE(TAG, "Gagal mengirim heartbeat status");
        return false;
    }

    ESP_LOGI(TAG, "Heartbeat status terkirim");
    return true;
}

static void clear_pending_request(void)
{
    portENTER_CRITICAL(&pending_request_mux);
    pending_request_active = false;
    pending_request_id[0] = '\0';
    portEXIT_CRITICAL(&pending_request_mux);
}

static void publish_card_auth(const char *uid_hash)
{
    if ((xEventGroupGetBits(event_group) & MQTT_CONNECTED_BIT) == 0) {
        ESP_LOGW(TAG, "Kartu terbaca tetapi MQTT offline; validasi tidak dikirim");
        return;
    }

    char request_id[37];
    char timestamp[25];
    if (!make_uuid(request_id) ||
        !get_iso8601_utc(timestamp, sizeof(timestamp))) {
        ESP_LOGE(TAG, "Gagal menyiapkan permintaan validasi kartu");
        return;
    }

    cJSON *request = cJSON_CreateObject();
    if (request == NULL) {
        ESP_LOGE(TAG, "Tidak dapat membuat payload validasi kartu");
        return;
    }
    cJSON_AddStringToObject(request, "request_id", request_id);
    cJSON_AddStringToObject(request, "uid_hash", uid_hash);
    cJSON_AddStringToObject(request, "timestamp", timestamp);
    char *payload = cJSON_PrintUnformatted(request);
    cJSON_Delete(request);
    if (payload == NULL) {
        ESP_LOGE(TAG, "Tidak dapat membuat JSON validasi kartu");
        return;
    }

    portENTER_CRITICAL(&pending_request_mux);
    snprintf(pending_request_id, sizeof(pending_request_id), "%s", request_id);
    pending_request_started_ms = esp_timer_get_time() / 1000;
    pending_request_active = true;
    portEXIT_CRITICAL(&pending_request_mux);

    int message_id = esp_mqtt_client_publish(
        mqtt_client, MQTT_AUTH_TOPIC, payload, 0, 1, 0);
    free(payload);
    if (message_id < 0) {
        clear_pending_request();
        ESP_LOGE(TAG, "Gagal mengirim permintaan validasi kartu");
        return;
    }

    ESP_LOGI(TAG, "Kartu terbaca; permintaan validasi terkirim (UID tidak dicatat)");
}

static void handle_auth_reply(const char *payload)
{
    cJSON *reply = cJSON_Parse(payload);
    if (reply == NULL) {
        ESP_LOGW(TAG, "Balasan auth bukan JSON yang valid");
        return;
    }

    const cJSON *request_id = cJSON_GetObjectItemCaseSensitive(reply, "request_id");
    const cJSON *found = cJSON_GetObjectItemCaseSensitive(reply, "found");
    bool matches_pending = false;

    portENTER_CRITICAL(&pending_request_mux);
    if (pending_request_active &&
        cJSON_IsString(request_id) &&
        strcmp(request_id->valuestring, pending_request_id) == 0) {
        matches_pending = true;
        pending_request_active = false;
        pending_request_id[0] = '\0';
    }
    portEXIT_CRITICAL(&pending_request_mux);

    if (!matches_pending) {
        ESP_LOGW(TAG, "Balasan auth tidak cocok dengan permintaan aktif");
    } else if (cJSON_IsBool(found) && cJSON_IsTrue(found)) {
        ESP_LOGI(TAG, "Kartu terdaftar; balasan backend cocok");
    } else if (cJSON_IsBool(found) && cJSON_IsFalse(found)) {
        ESP_LOGI(TAG, "Kartu belum terdaftar");
    } else {
        ESP_LOGW(TAG, "Format field found pada balasan auth tidak valid");
    }

    cJSON_Delete(reply);
}

static void handle_control_command(const char *payload)
{
    cJSON *command_body = cJSON_Parse(payload);
    if (command_body == NULL) {
        ESP_LOGW(TAG, "Command bukan JSON yang valid");
        return;
    }

    const cJSON *command = cJSON_GetObjectItemCaseSensitive(command_body, "command");
    if (!cJSON_IsString(command)) {
        ESP_LOGW(TAG, "Command MQTT tidak memiliki field command");
    } else if (strcmp(command->valuestring, "ping") == 0) {
        ESP_LOGI(TAG, "Command ping diterima");
        publish_status();
    } else {
        ESP_LOGW(TAG, "Command '%s' diabaikan: firmware uji tidak mengendalikan aktuator",
                 command->valuestring);
    }

    cJSON_Delete(command_body);
}

static void handle_mqtt_data(const esp_mqtt_event_handle_t event)
{
    if (event->current_data_offset != 0 ||
        event->data_len != event->total_data_len ||
        event->topic_len <= 0 ||
        event->data_len < 0 ||
        event->topic == NULL ||
        (event->data_len > 0 && event->data == NULL) ||
        event->topic_len >= 128 ||
        event->data_len >= 1024) {
        ESP_LOGW(TAG, "Pesan MQTT terfragmentasi atau melebihi batas; pesan diabaikan");
        return;
    }

    char topic[128];
    char payload[1024];
    memcpy(topic, event->topic, event->topic_len);
    topic[event->topic_len] = '\0';
    memcpy(payload, event->data, event->data_len);
    payload[event->data_len] = '\0';

    if (strcmp(topic, MQTT_AUTH_COMMAND_TOPIC) == 0) {
        handle_auth_reply(payload);
    } else if (strcmp(topic, MQTT_CONTROL_TOPIC) == 0) {
        handle_control_command(payload);
    } else {
        ESP_LOGW(TAG, "Pesan diterima pada topik yang tidak dikenal");
        return;
    }

    char uart_line[UART_A_LINE_MAX + 160];
    int line_length = snprintf(uart_line, sizeof(uart_line), "MQTT_MSG %s %s", topic, payload);
    if (line_length < 0 || (size_t)line_length >= sizeof(uart_line)) {
        ESP_LOGW(TAG, "Balasan MQTT terlalu panjang untuk diteruskan ke ESP32-A");
        return;
    }
    uart_send_line(uart_line);
}

static void handle_uart_command(char *line)
{
    static const char *PUBLISH_PREFIX = "MQTT_PUB ";
    static const char *ALLOWED_TOPIC_PREFIX = "smartbin/" DEVICE_ID "/telemetry/";
    const size_t prefix_length = strlen(PUBLISH_PREFIX);
    const size_t allowed_topic_prefix_length = strlen(ALLOWED_TOPIC_PREFIX);
    if (strncmp(line, PUBLISH_PREFIX, prefix_length) != 0) {
        ESP_LOGW(TAG, "Perintah UART ESP32-A tidak dikenal");
        return;
    }

    char *topic = line + prefix_length;
    char *separator = strchr(topic, ' ');
    if (separator == NULL) {
        ESP_LOGW(TAG, "Format MQTT_PUB dari ESP32-A tidak valid");
        return;
    }
    *separator = '\0';
    const char *payload = separator + 1;
    if (strncmp(topic, ALLOWED_TOPIC_PREFIX, allowed_topic_prefix_length) != 0 ||
        topic[allowed_topic_prefix_length] == '\0' ||
        payload[0] == '\0' ||
        strchr(topic, '#') != NULL ||
        strchr(topic, '+') != NULL ||
        strlen(topic) >= 128 ||
        strlen(payload) >= UART_A_LINE_MAX) {
        ESP_LOGW(TAG, "Topik atau payload MQTT_PUB tidak diizinkan");
        return;
    }
    if ((xEventGroupGetBits(event_group) & MQTT_CONNECTED_BIT) == 0) {
        ESP_LOGW(TAG, "Perintah MQTT_PUB diabaikan: broker sedang offline");
        return;
    }

    int message_id = esp_mqtt_client_publish(mqtt_client, topic, payload, 0, 1, 0);
    if (message_id < 0) {
        ESP_LOGE(TAG, "Gagal meneruskan MQTT_PUB dari ESP32-A");
        return;
    }
    ESP_LOGI(TAG, "Payload dari ESP32-A diterbitkan melalui MQTT");
}

static void uart_rx_task(void *arg)
{
    uint8_t input[UART_A_RX_BUFFER_SIZE];
    char line[UART_A_LINE_MAX];
    size_t line_length = 0;
    bool dropping_line = false;

    while (true) {
        int count = uart_read_bytes(UART_A_PORT, input, sizeof(input), pdMS_TO_TICKS(100));
        for (int i = 0; i < count; i++) {
            if (input[i] == '\r') {
                continue;
            }
            if (input[i] == '\n') {
                if (!dropping_line && line_length > 0) {
                    line[line_length] = '\0';
                    handle_uart_command(line);
                }
                line_length = 0;
                dropping_line = false;
                continue;
            }
            if (!dropping_line) {
                if (line_length + 1 >= sizeof(line)) {
                    dropping_line = true;
                } else {
                    line[line_length++] = (char)input[i];
                }
            }
        }
    }
}

static esp_err_t uart_init(void)
{
    uart_config_t config = {
        .baud_rate = UART_A_BAUD,
        .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_DEFAULT,
    };

    ESP_RETURN_ON_ERROR(uart_driver_install(
        UART_A_PORT, UART_A_RX_BUFFER_SIZE * 2, 0, 0, NULL, 0), TAG,
        "Gagal memasang driver UART2");
    ESP_RETURN_ON_ERROR(uart_param_config(UART_A_PORT, &config), TAG,
        "Gagal mengatur UART2");
    ESP_RETURN_ON_ERROR(uart_set_pin(
        UART_A_PORT, UART_A_TX_GPIO, UART_A_RX_GPIO,
        UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE), TAG,
        "Gagal menetapkan pin UART2");

    uart_tx_mutex = xSemaphoreCreateMutex();
    if (uart_tx_mutex == NULL) {
        ESP_LOGE(TAG, "Gagal membuat mutex TX UART2");
        return ESP_ERR_NO_MEM;
    }
    if (xTaskCreate(uart_rx_task, "smartbin_uart_rx", 4096, NULL, 5, NULL) != pdPASS) {
        ESP_LOGE(TAG, "Gagal membuat task penerima UART2");
        return ESP_ERR_NO_MEM;
    }
    ESP_LOGI(TAG, "UART2 siap: TX GPIO17, RX GPIO16, 115200 baud");
    return ESP_OK;
}

static void mqtt_event_handler(
    void *handler_args,
    esp_event_base_t base,
    int32_t event_id,
    void *event_data)
{
    (void)handler_args;
    (void)base;
    esp_mqtt_event_handle_t event = event_data;
    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_CONNECTED:
        xEventGroupSetBits(event_group, MQTT_CONNECTED_BIT);
        ESP_LOGI(TAG, "MQTT WSS tersambung");
        send_network_state(true);
        if (esp_mqtt_client_subscribe(event->client, MQTT_AUTH_COMMAND_TOPIC, 1) < 0) {
            ESP_LOGE(TAG, "Gagal subscribe ke command/auth");
        }
        if (esp_mqtt_client_subscribe(event->client, MQTT_CONTROL_TOPIC, 1) < 0) {
            ESP_LOGE(TAG, "Gagal subscribe ke command/control");
        }
        publish_status();
        break;
    case MQTT_EVENT_DISCONNECTED:
        xEventGroupClearBits(event_group, MQTT_CONNECTED_BIT);
        send_network_state(false);
        ESP_LOGW(TAG, "MQTT terputus; client akan mencoba menyambung ulang");
        break;
    case MQTT_EVENT_DATA:
        handle_mqtt_data(event);
        break;
    case MQTT_EVENT_ERROR:
        ESP_LOGE(TAG, "Kesalahan koneksi MQTT/TLS");
        break;
    default:
        break;
    }
}

static void wifi_event_handler(
    void *arg,
    esp_event_base_t event_base,
    int32_t event_id,
    void *event_data)
{
    (void)arg;
    (void)event_data;
    static uint8_t retries;
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        xEventGroupClearBits(event_group, WIFI_CONNECTED_BIT);
        if (retries < WIFI_MAX_RETRIES) {
            retries++;
        } else {
            ESP_LOGW(TAG, "Wi-Fi masih terputus; mencoba menyambung ulang");
        }
        esp_wifi_connect();
        if (retries > 0 && retries < WIFI_MAX_RETRIES) {
            ESP_LOGW(TAG, "Mencoba ulang Wi-Fi (%u/%u)", retries, WIFI_MAX_RETRIES);
        }
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        retries = 0;
        xEventGroupSetBits(event_group, WIFI_CONNECTED_BIT);
        ESP_LOGI(TAG, "Wi-Fi tersambung");
    }
}

static esp_err_t wifi_init(void)
{
    wifi_config_t station_config = {0};
    size_t ssid_length = strlen(CONFIG_SMARTBIN_WIFI_SSID);
    size_t password_length = strlen(CONFIG_SMARTBIN_WIFI_PASSWORD);
    if (ssid_length == 0 ||
        ssid_length >= sizeof(station_config.sta.ssid) ||
        password_length >= sizeof(station_config.sta.password)) {
        ESP_LOGE(TAG, "SSID/password Wi-Fi kosong atau terlalu panjang");
        return ESP_ERR_INVALID_STATE;
    }

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t wifi_config = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&wifi_config));
    ESP_ERROR_CHECK(esp_event_handler_register(
        WIFI_EVENT, ESP_EVENT_ANY_ID, wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(
        IP_EVENT, IP_EVENT_STA_GOT_IP, wifi_event_handler, NULL));

    snprintf((char *)station_config.sta.ssid, sizeof(station_config.sta.ssid),
             "%s", CONFIG_SMARTBIN_WIFI_SSID);
    snprintf((char *)station_config.sta.password, sizeof(station_config.sta.password),
             "%s", CONFIG_SMARTBIN_WIFI_PASSWORD);
    station_config.sta.threshold.authmode = password_length == 0
        ? WIFI_AUTH_OPEN
        : WIFI_AUTH_WPA2_PSK;

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &station_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    EventBits_t bits = xEventGroupWaitBits(
        event_group, WIFI_CONNECTED_BIT, pdFALSE, pdFALSE, pdMS_TO_TICKS(60000));
    if ((bits & WIFI_CONNECTED_BIT) == 0) {
        ESP_LOGE(TAG, "Wi-Fi belum tersambung; periksa SSID/password dan sinyal");
        return ESP_ERR_TIMEOUT;
    }
    return ESP_OK;
}

static esp_err_t synchronize_time(void)
{
    esp_sntp_config_t config = ESP_NETIF_SNTP_DEFAULT_CONFIG("pool.ntp.org");
    esp_err_t err = esp_netif_sntp_init(&config);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Gagal memulai SNTP: %s", esp_err_to_name(err));
        return err;
    }

    for (int attempt = 0; attempt < 30; attempt++) {
        if (time(NULL) >= 1700000000) {
            ESP_LOGI(TAG, "Waktu UTC tersinkron");
            return ESP_OK;
        }
        vTaskDelay(pdMS_TO_TICKS(1000));
    }

    ESP_LOGE(TAG, "Waktu belum tersinkron; koneksi TLS tidak dimulai");
    return ESP_ERR_TIMEOUT;
}

static esp_err_t mqtt_init(void)
{
    if (CONFIG_SMARTBIN_MQTT_PASSWORD[0] == '\0' ||
        CONFIG_SMARTBIN_CARD_HMAC_SECRET[0] == '\0') {
        ESP_LOGE(TAG, "Isi MQTT password dan CARD_HMAC_SECRET melalui idf.py menuconfig");
        return ESP_ERR_INVALID_STATE;
    }

    const esp_mqtt_client_config_t config = {
        .broker.address.uri = MQTT_URI,
        .broker.verification.crt_bundle_attach = esp_crt_bundle_attach,
        .credentials.client_id = "smartbin-esp2",
        .credentials.username = CONFIG_SMARTBIN_MQTT_USERNAME,
        .credentials.authentication.password = CONFIG_SMARTBIN_MQTT_PASSWORD,
        .session.keepalive = 30,
        .session.last_will.topic = MQTT_STATUS_TOPIC,
        .session.last_will.msg =
            "{\"schema_version\":1,\"device_id\":\"esp2\",\"state\":\"OFFLINE\"}",
        .session.last_will.qos = 1,
        .session.last_will.retain = false,
    };

    mqtt_client = esp_mqtt_client_init(&config);
    if (mqtt_client == NULL) {
        ESP_LOGE(TAG, "Gagal membuat MQTT client");
        return ESP_FAIL;
    }
    ESP_ERROR_CHECK(esp_mqtt_client_register_event(
        mqtt_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL));
    return esp_mqtt_client_start(mqtt_client);
}

static void initialize_pn532(void)
{
    gpio_num_t reset_gpio = CONFIG_SMARTBIN_PN532_RESET_GPIO < 0
        ? GPIO_NUM_NC
        : (gpio_num_t)CONFIG_SMARTBIN_PN532_RESET_GPIO;
    pn532_bus_t *bus = pn532_i2c_init(
        I2C_NUM_0,
        (gpio_num_t)CONFIG_SMARTBIN_PN532_SCL_GPIO,
        (gpio_num_t)CONFIG_SMARTBIN_PN532_SDA_GPIO,
        0,
        100000);
    if (bus == NULL) {
        ESP_LOGE(TAG, "Gagal menginisialisasi bus I2C PN532");
        return;
    }

    pn532 = pn532_init(bus, GPIO_NUM_NC, reset_gpio);
    if (pn532 == NULL) {
        ESP_LOGE(TAG, "PN532 tidak terdeteksi; periksa kabel dan mode I2C");
        pn532_bus_destroy(bus);
        return;
    }
    pn532_online = true;
    ESP_LOGI(TAG, "PN532 siap pada I2C SDA=%d SCL=%d",
             CONFIG_SMARTBIN_PN532_SDA_GPIO, CONFIG_SMARTBIN_PN532_SCL_GPIO);
}

static esp_err_t initialize_card_slot(void)
{
    gpio_config_t config = {
        .pin_bit_mask = 1ULL << CONFIG_SMARTBIN_CARD_SLOT_GPIO,
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    ESP_RETURN_ON_ERROR(gpio_config(&config), TAG,
        "Gagal menginisialisasi microswitch slot KTP");
    ESP_LOGI(TAG, "Microswitch slot KTP siap pada GPIO%d (aktif LOW)",
             CONFIG_SMARTBIN_CARD_SLOT_GPIO);
    return ESP_OK;
}

static void process_card_slot(void)
{
    static bool slot_present;
    static bool candidate_present;
    static bool candidate_initialized;
    static bool active_card;
    static char active_uid_hash[65];
    static int64_t candidate_since_ms;
    int64_t now_ms = esp_timer_get_time() / 1000;
    bool raw_present = gpio_get_level(CONFIG_SMARTBIN_CARD_SLOT_GPIO) == 0;

    if (!candidate_initialized || raw_present != candidate_present) {
        candidate_present = raw_present;
        candidate_since_ms = now_ms;
        candidate_initialized = true;
    } else if (slot_present != candidate_present &&
               now_ms - candidate_since_ms >= CARD_SLOT_DEBOUNCE_MS) {
        slot_present = candidate_present;
        if (!slot_present) {
            if (active_card) {
                memset(active_uid_hash, 0, sizeof(active_uid_hash));
                active_card = false;
            }
            uart_send_line("CARD_OUT");
            ESP_LOGI(TAG, "KTP dikeluarkan dari slot");
            clear_pending_request();
        }
    }

    if (!slot_present || !pn532_online) {
        return;
    }

    pn532_poll_status_t status;
    pn532_uids_array_t *cards = pn532_14443_get_all_uids_ex(pn532, &status);

    if (status == PN532_POLL_FOUND && cards != NULL) {
        if (cards->uids_count > 0) {
            pn532_uid_t *card = &cards->uids[0];
            char uid_hash[65];
            bool valid_uid = card->uid_length > 0 &&
                card->uid_length <= (int8_t)sizeof(card->uid) &&
                make_uid_hash(card->uid, (size_t)card->uid_length, uid_hash);

            if (!valid_uid) {
                ESP_LOGW(TAG, "Panjang UID kartu tidak didukung atau HMAC gagal");
            } else if (!active_card) {
                snprintf(active_uid_hash, sizeof(active_uid_hash), "%s", uid_hash);
                active_card = true;
                char card_line[80];
                snprintf(card_line, sizeof(card_line), "CARD_IN %s", uid_hash);
                uart_send_line(card_line);
                publish_card_auth(uid_hash);
                ESP_LOGI(TAG, "KTP terbaca pada slot; UID mentah tidak dicatat");
            }
            if (!pn532_release_target(pn532)) {
                ESP_LOGW(TAG, "Gagal melepaskan target PN532");
            }
        }
    } else if (status == PN532_POLL_TRANSPORT_ERROR) {
        ESP_LOGE(TAG, "Kesalahan komunikasi PN532; mencoba pemulihan");
        if (!pn532_recover(pn532)) {
            pn532_online = false;
        }
    } else if (status == PN532_POLL_FOUND) {
        ESP_LOGW(TAG, "PN532 melaporkan kartu tetapi data UID kosong");
    } else if (status != PN532_POLL_NO_TARGET) {
        ESP_LOGW(TAG, "Polling PN532 gagal dengan status %d", status);
    }

    free(cards);
    if (!pn532_set_rf_off(pn532)) {
        ESP_LOGW(TAG, "Gagal mematikan field RF PN532");
    }
}

static void report_auth_timeout(void)
{
    int64_t now_ms = esp_timer_get_time() / 1000;
    bool timed_out = false;
    portENTER_CRITICAL(&pending_request_mux);
    if (pending_request_active &&
        now_ms - pending_request_started_ms > AUTH_TIMEOUT_MS) {
        pending_request_active = false;
        pending_request_id[0] = '\0';
        timed_out = true;
    }
    portEXIT_CRITICAL(&pending_request_mux);
    if (timed_out) {
        ESP_LOGW(TAG, "Waktu tunggu validasi kartu habis");
    }
}

void app_main(void)
{
    esp_err_t err = nvs_flash_init();
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Gagal menginisialisasi NVS: %s", esp_err_to_name(err));
        return;
    }

    event_group = xEventGroupCreate();
    if (event_group == NULL) {
        ESP_LOGE(TAG, "Gagal membuat event group");
        return;
    }

    if (uart_init() != ESP_OK || initialize_card_slot() != ESP_OK) {
        return;
    }
    initialize_pn532();
    if (wifi_init() != ESP_OK || synchronize_time() != ESP_OK) {
        return;
    }
    if (mqtt_init() != ESP_OK) {
        ESP_LOGE(TAG, "Gagal memulai MQTT client");
        return;
    }

    int64_t last_heartbeat_ms = 0;
    while (true) {
        process_card_slot();

        int64_t now_ms = esp_timer_get_time() / 1000;
        if ((xEventGroupGetBits(event_group) & MQTT_CONNECTED_BIT) != 0 &&
            now_ms - last_heartbeat_ms >= HEARTBEAT_INTERVAL_MS) {
            publish_status();
            last_heartbeat_ms = now_ms;
        }
        report_auth_timeout();
        vTaskDelay(pdMS_TO_TICKS(200));
    }
}
