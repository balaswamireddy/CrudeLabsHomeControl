#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <WebServer.h>
#include <EEPROM.h>
#include <WiFiClientSecure.h>
#include <ESPmDNS.h>


// ============================================================================
// BOARD CONFIGURATION - CUSTOMIZE FOR EACH DEVICE
// ============================================================================


#define BOARD_ID "BOARD_005"  // UNIQUE ID for each board (BOARD_001, BOARD_002, etc.)
#define FIRMWARE_VERSION "2.0.0"
#define NUM_SWITCHES 4


// Pin Definitions
#define RELAY_PIN_1 13   // GPIO2 - Switch 1 Relay
#define RELAY_PIN_2 12   // GPIO4 - Switch 2 Relay  
#define RELAY_PIN_3 14  // GPIO16 - Switch 3 Relay
#define RELAY_PIN_4 27 // GPIO17 - Switch 4 Relay


#define BUTTON_PIN_1 26 // GPIO18 - Physical button for Switch 1
#define BUTTON_PIN_2 25 // GPIO19 - Physical button for Switch 2
#define BUTTON_PIN_3 33 // GPIO21 - Physical button for Switch 3
#define BUTTON_PIN_4 32 // GPIO22 - Physical button for Switch 4


#define STATUS_LED 2    // GPIO2 - Status LED (built-in)
#define RESET_PIN 5    // GPIO0 - Factory reset button


// Network Configuration
#define CONFIG_SSID "SmartSwitch_" BOARD_ID
#define CONFIG_PASSWORD "12345678"
#define CONFIG_TIMEOUT 300000  // 5 minutes in config mode


// Supabase Configuration - YOUR NEW PROJECT CREDENTIALS
String supabase_url = "https://nchshzvzjwlhquvjzhsi.supabase.co";
String supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5jaHNoenZ6andsaHF1dmp6aHNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwNzU4NDIsImV4cCI6MjA3NTY1MTg0Mn0.ASwxbx9m6a09MT8x31qvkSwy2yBLHAVhOMZ3jutLNS8";
String wifi_ssid = "Stone age";  // YOUR WIFI SSID
String wifi_password = "stoneage";  // YOUR WIFI PASSWORD


// ============================================================================
// GLOBAL VARIABLES
// ============================================================================


WebServer server(80);
HTTPClient http;
WiFiClientSecure client;


// Switch states
bool switchStates[NUM_SWITCHES] = {false, false, false, false};
bool lastSwitchStates[NUM_SWITCHES] = {false, false, false, false};
int relayPins[NUM_SWITCHES] = {RELAY_PIN_1, RELAY_PIN_2, RELAY_PIN_3, RELAY_PIN_4};
int buttonPins[NUM_SWITCHES] = {BUTTON_PIN_1, BUTTON_PIN_2, BUTTON_PIN_3, BUTTON_PIN_4};


// Timing variables
unsigned long lastHeartbeat = 0;
unsigned long lastButtonCheck = 0;
unsigned long lastDatabasePoll = 0;
unsigned long lastStatusPrint = 0;


// State variables
bool isConfigMode = false;
bool isConnectedToWiFi = false;
bool isConnectedToSupabase = false;
String deviceMAC = "";


// Physical switch debouncing and toggle logic
bool lastPhysicalStates[NUM_SWITCHES] = {false, false, false, false};
bool currentPhysicalStates[NUM_SWITCHES] = {false, false, false, false};
unsigned long lastSwitchToggle[NUM_SWITCHES] = {0, 0, 0, 0};


// ============================================================================
// SETUP FUNCTION
// ============================================================================


void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n\n");
  Serial.println("╔════════════════════════════════════════╗");
  Serial.println("║  SMART HOME ESP32 CONTROLLER v2.0.0   ║");
  Serial.println("╚════════════════════════════════════════╝");
  Serial.println("Board ID: " + String(BOARD_ID));
  Serial.println("Firmware: " + String(FIRMWARE_VERSION));

  // Get MAC address
  deviceMAC = WiFi.macAddress();
  Serial.println("MAC Address: " + deviceMAC);
  Serial.println("");

  // Initialize EEPROM for storing WiFi credentials
  EEPROM.begin(512);

  // Initialize pins
  initializePins();

  // Check for factory reset (hold reset button during startup)
  checkFactoryReset();

  // Load WiFi credentials from EEPROM
  loadWiFiCredentials();

  // Check if we should enter config mode
  if (shouldEnterConfigMode()) {
    startConfigMode();
  } else {
    // Try to connect to saved WiFi
    if (wifi_ssid.length() > 0) {
      connectToWiFi();
    } else {
      Serial.println("✗ No WiFi credentials found - entering config mode");
      startConfigMode();
    }
  }
}


// ============================================================================
// MAIN LOOP
// ============================================================================


void loop() {
  // Handle config mode
  if (isConfigMode) {
    handleConfigMode();
    return;
  }

  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected, attempting reconnection...");
    connectToWiFi();
    delay(5000);
    return;
  }

  // Check physical buttons (every 50ms)
  if (millis() - lastButtonCheck > 50) {
    checkPhysicalButtons();
    lastButtonCheck = millis();
  }

  // Poll database for switch changes (every 2 seconds)
  if (millis() - lastDatabasePoll > 500) {
    loadSwitchStatesFromDatabase();
    lastDatabasePoll = millis();
  }

  // Send heartbeat (every 30 seconds)
  if (millis() - lastHeartbeat > 30000) {
    sendHeartbeat();
    lastHeartbeat = millis();
  }

  // Print status summary (every 30 seconds)
  if (millis() - lastStatusPrint > 30000) {
    printStatus();
    lastStatusPrint = millis();
  }

  // Status LED - solid on when connected
  digitalWrite(STATUS_LED, isConnectedToWiFi ? HIGH : LOW);

  delay(10);
}


// ============================================================================
// PIN INITIALIZATION
// ============================================================================


void initializePins() {
  // Initialize relay pins as outputs (HIGH = ON, LOW = OFF for this setup)
  for (int i = 0; i < NUM_SWITCHES; i++) {
    pinMode(relayPins[i], OUTPUT);
    digitalWrite(relayPins[i], LOW); // Turn off relay initially (LOW = OFF)

    // Initialize button pins as inputs with pullup
    pinMode(buttonPins[i], INPUT_PULLUP);
  }

  // Initialize status LED
  pinMode(STATUS_LED, OUTPUT);

  Serial.println("✓ GPIO pins initialized");
  Serial.println("✓ All relays initialized to OFF state (LOW)");
}


// ============================================================================
// WIFI CONNECTION
// ============================================================================


void connectToWiFi() {
  Serial.println("\n════════════════════════════════════════");
  Serial.println("CONNECTING TO WIFI");
  Serial.println("════════════════════════════════════════");
  Serial.println("SSID: " + wifi_ssid);

  WiFi.mode(WIFI_STA);
  WiFi.begin(wifi_ssid.c_str(), wifi_password.c_str());

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(1000);
    Serial.print(".");
    attempts++;
  }
  Serial.println("");

  if (WiFi.status() == WL_CONNECTED) {
    isConnectedToWiFi = true;
    Serial.println("✓ WiFi connected!");
    Serial.println("IP address: " + WiFi.localIP().toString());
    Serial.println("Signal strength: " + String(WiFi.RSSI()) + " dBm");

    // Configure HTTPS client
    client.setInsecure();
    isConnectedToSupabase = true;

    Serial.println("\n════════════════════════════════════════");
    Serial.println("✓ BOARD READY");
    Serial.println("════════════════════════════════════════\n");

    // Load initial switch states
    loadSwitchStatesFromDatabase();
  } else {
    Serial.println("✗ WiFi connection failed!");
    isConnectedToWiFi = false;
  }
}


// ============================================================================
// SUPABASE DATABASE FUNCTIONS
// ============================================================================


void loadSwitchStatesFromDatabase() {
  if (!isConnectedToWiFi) return;
  
  Serial.println("\n[POLL] Checking switch states...");
  
  HTTPClient http;
  String url = supabase_url + "/rest/v1/switches?board_id=eq." + String(BOARD_ID) + "&order=position&select=id,name,state,position";
  
  http.begin(client, url);
  http.addHeader("apikey", supabase_key);
  http.addHeader("Authorization", "Bearer " + supabase_key);
  http.addHeader("Content-Type", "application/json");
  
  int httpResponseCode = http.GET();
  
  if (httpResponseCode == 200) {
    String response = http.getString();
    
    DynamicJsonDocument doc(2048);
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      JsonArray switches = doc.as<JsonArray>();
      
      for (int i = 0; i < switches.size() && i < NUM_SWITCHES; i++) {
        bool newState = switches[i]["state"];
        
        // Fixed: Proper null check for name field
        String name;
        if (switches[i]["name"].isNull()) {
          name = "Switch " + String(i + 1);
        } else {
          name = switches[i]["name"].as<String>();
        }
        
        // TOGGLE LOGIC: Only update relay if database state differs from current state
        // This allows remote control to override physical switch position
        if (switchStates[i] != newState) {
          Serial.println("  [REMOTE] " + name + ": " + String(switchStates[i] ? "ON" : "OFF") + " → " + String(newState ? "ON" : "OFF"));
          
          // Update relay to match database state (remote control wins)
          controlRelay(i, newState);
          
          // If physical switch is in opposite position, user will need to toggle it to regain physical control
          if (currentPhysicalStates[i] && !newState) {
            Serial.println("      Physical switch is LOW but relay turned OFF by remote - toggle physical switch to regain control");
          } else if (!currentPhysicalStates[i] && newState) {
            Serial.println("     Physical switch is HIGH but relay turned ON by remote - toggle physical switch to regain control");
          }
        }
      }
    }
  } else if (httpResponseCode == 401) {
    Serial.println("[ERROR] 401 Unauthorized - Check database RLS policies!");
  } else if (httpResponseCode != 200) {
    Serial.println("[ERROR] HTTP " + String(httpResponseCode));
  }
  
  http.end();
}


void updateSwitchInDatabase(int switchIndex, bool state, String triggeredBy) {
  if (!isConnectedToWiFi) return;

  Serial.println("\n[UPDATE] Switch " + String(switchIndex + 1) + " → " + String(state ? "ON" : "OFF"));

  HTTPClient http;
  String switchId = String(BOARD_ID) + "_switch_" + String(switchIndex + 1);
  String url = supabase_url + "/rest/v1/switches?id=eq." + switchId;

  http.begin(client, url);
  http.addHeader("apikey", supabase_key);
  http.addHeader("Authorization", "Bearer " + supabase_key);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Prefer", "return=minimal");

  DynamicJsonDocument doc(256);
  doc["state"] = state;

  String requestBody;
  serializeJson(doc, requestBody);

  int httpResponseCode = http.sendRequest("PATCH", requestBody);

  if (httpResponseCode == 200 || httpResponseCode == 204) {
    Serial.println("✓ Database updated");
  } else {
    Serial.println("✗ Update failed: " + String(httpResponseCode));
  }

  http.end();
}


void sendHeartbeat() {
  if (!isConnectedToWiFi) return;

  Serial.println("\n[HEARTBEAT] Sending...");

  HTTPClient http;
  String url = supabase_url + "/rest/v1/boards?id=eq." + String(BOARD_ID);

  http.begin(client, url);
  http.addHeader("apikey", supabase_key);
  http.addHeader("Authorization", "Bearer " + supabase_key);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Prefer", "return=minimal");

  DynamicJsonDocument doc(256);
  doc["status"] = "online";

  String requestBody;
  serializeJson(doc, requestBody);

  int httpResponseCode = http.sendRequest("PATCH", requestBody);

  if (httpResponseCode == 200 || httpResponseCode == 204) {
    Serial.println("✓ Heartbeat sent");
  }

  http.end();
}


// ============================================================================
// PHYSICAL SWITCH CONTROL
// ============================================================================


void controlRelay(int switchIndex, bool state) {
  if (switchIndex >= 0 && switchIndex < NUM_SWITCHES) {
    // Most relay modules are active HIGH (HIGH = ON, LOW = OFF)
    digitalWrite(relayPins[switchIndex], state ? HIGH : LOW);
    switchStates[switchIndex] = state;
    
    Serial.println("[RELAY] Switch " + String(switchIndex + 1) + " relay → " + String(state ? "ON (HIGH)" : "OFF (LOW)"));
  }
}


void checkPhysicalButtons() {
  for (int i = 0; i < NUM_SWITCHES; i++) {
    // Read current physical switch state (LOW = switch pulled to ground)
    bool physicalSwitchPulledLow = digitalRead(buttonPins[i]) == LOW;
    
    // Store current physical state
    currentPhysicalStates[i] = physicalSwitchPulledLow;
    
    // Detect edge changes (toggle events) with debouncing
    if (currentPhysicalStates[i] != lastPhysicalStates[i]) {
      if (millis() - lastSwitchToggle[i] > 200) { // 200ms debounce for toggle switches
        
        if (currentPhysicalStates[i]) {
          // Physical switch just pulled LOW → Turn relay ON and update database
          Serial.println("\n[PHYSICAL] Switch " + String(i + 1) + " pulled LOW → Turning relay ON");
          
          // Turn relay on immediately
          controlRelay(i, true);
          
          // Update database to reflect the ON state
          updateSwitchInDatabase(i, true, "physical");
          
        } else {
          // Physical switch just released (HIGH) → Turn relay OFF and update database  
          Serial.println("\n[PHYSICAL] Switch " + String(i + 1) + " released HIGH → Turning relay OFF");
          
          // Turn relay off immediately
          controlRelay(i, false);
          
          // Update database to reflect the OFF state
          updateSwitchInDatabase(i, false, "physical");
        }
        
        lastSwitchToggle[i] = millis();
      }
    }
    
    // Update last state for next iteration
    lastPhysicalStates[i] = currentPhysicalStates[i];
  }
}


// ============================================================================
// CONFIG MODE FUNCTIONS
// ============================================================================

void checkFactoryReset() {
  pinMode(RESET_PIN, INPUT_PULLUP);
  
  if (digitalRead(RESET_PIN) == LOW) {
    Serial.println("Factory reset button detected...");
    
    // Wait for 3 seconds while button is held
    int count = 0;
    while (digitalRead(RESET_PIN) == LOW && count < 30) {
      delay(100);
      count++;
      if (count % 10 == 0) {
        Serial.print(".");
      }
    }
    Serial.println("");
    
    if (count >= 30) {
      Serial.println("✓ Factory reset initiated!");
      clearStoredCredentials();
      Serial.println("✓ All stored credentials cleared");
      delay(1000);
    }
  }
}

bool shouldEnterConfigMode() {
  // Enter config mode if:
  // 1. No stored WiFi credentials
  // 2. Reset button pressed during startup
  // 3. Can't connect to stored WiFi after multiple attempts
  
  if (wifi_ssid.length() == 0) {
    Serial.println("No WiFi credentials - entering config mode");
    return true;
  }
  
  return false;
}

void startConfigMode() {
  Serial.println("\n╔════════════════════════════════════════╗");
  Serial.println("║           CONFIG MODE STARTED          ║");
  Serial.println("╚════════════════════════════════════════╝");
  
  isConfigMode = true;
  
  // Set up access point
  WiFi.mode(WIFI_AP);
  String apName = CONFIG_SSID;
  WiFi.softAP(apName.c_str(), CONFIG_PASSWORD);
  
  IPAddress ip = WiFi.softAPIP();
  Serial.println("✓ Access Point Started");
  Serial.println("  SSID: " + apName);
  Serial.println("  Password: " + String(CONFIG_PASSWORD));
  Serial.println("  IP: " + ip.toString());
  Serial.println("  Web Interface: http://" + ip.toString());
  
  // Set up mDNS
  if (MDNS.begin("smartswitch")) {
    Serial.println("  mDNS: http://smartswitch.local");
  }
  
  // Configure web server routes
  setupWebServer();
  server.begin();
  
  Serial.println("\n🌐 Connect to WiFi '" + apName + "' and visit:");
  Serial.println("   http://" + ip.toString() + " or http://smartswitch.local");
  Serial.println("   Password: " + String(CONFIG_PASSWORD));
  Serial.println("\n⏱️  Config mode timeout: " + String(CONFIG_TIMEOUT/1000/60) + " minutes");
  
  // Blink status LED to indicate config mode
  unsigned long configStartTime = millis();
  while (isConfigMode && (millis() - configStartTime < CONFIG_TIMEOUT)) {
    handleConfigMode();
    
    // Blink LED every 500ms in config mode
    digitalWrite(STATUS_LED, (millis() / 500) % 2);
    delay(100);
  }
  
  if (isConfigMode) {
    Serial.println("Config mode timeout - restarting...");
    ESP.restart();
  }
}

void handleConfigMode() {
  server.handleClient();
  // MDNS.update(); // Not available in older ESP32 core versions
}

void setupWebServer() {
  // Serve main configuration page
  server.on("/", HTTP_GET, handleRoot);
  
  // Handle WiFi scan
  server.on("/scan", HTTP_GET, handleScan);
  
  // Handle WiFi configuration
  server.on("/config", HTTP_POST, handleConfig);
  
  // Handle board information
  server.on("/info", HTTP_GET, handleInfo);
  
  // Handle restart
  server.on("/restart", HTTP_POST, handleRestart);
  
  // Serve CSS
  server.on("/style.css", HTTP_GET, handleCSS);
  
  // Handle 404
  server.onNotFound(handleNotFound);
}

void handleRoot() {
  String html = generateConfigHTML();
  server.send(200, "text/html", html);
}

void handleScan() {
  Serial.println("Scanning for WiFi networks...");
  
  String json = "{\"networks\":[";
  int n = WiFi.scanNetworks();
  
  for (int i = 0; i < n; i++) {
    if (i > 0) json += ",";
    json += "{";
    json += "\"ssid\":\"" + WiFi.SSID(i) + "\",";
    json += "\"rssi\":" + String(WiFi.RSSI(i)) + ",";
    json += "\"secure\":" + String(WiFi.encryptionType(i) != WIFI_AUTH_OPEN ? "true" : "false");
    json += "}";
  }
  
  json += "],\"count\":" + String(n) + "}";
  
  server.send(200, "application/json", json);
}

void handleConfig() {
  String ssid = server.arg("ssid");
  String password = server.arg("password");
  
  Serial.println("Received WiFi configuration:");
  Serial.println("  SSID: " + ssid);
  Serial.println("  Password: [" + String(password.length()) + " chars]");
  
  if (ssid.length() > 0) {
    // Save credentials to EEPROM
    saveWiFiCredentials(ssid, password);
    
    String response = "{\"status\":\"success\",\"message\":\"WiFi credentials saved. Restarting...\"}";
    server.send(200, "application/json", response);
    
    delay(1000);
    ESP.restart();
  } else {
    String response = "{\"status\":\"error\",\"message\":\"SSID cannot be empty\"}";
    server.send(400, "application/json", response);
  }
}

void handleInfo() {
  String json = "{";
  json += "\"board_id\":\"" + String(BOARD_ID) + "\",";
  json += "\"firmware\":\"" + String(FIRMWARE_VERSION) + "\",";
  json += "\"mac\":\"" + deviceMAC + "\",";
  json += "\"ip\":\"" + WiFi.softAPIP().toString() + "\",";
  json += "\"uptime\":" + String(millis() / 1000) + ",";
  json += "\"free_heap\":" + String(ESP.getFreeHeap()) + ",";
  json += "\"switches\":" + String(NUM_SWITCHES);
  json += "}";
  
  server.send(200, "application/json", json);
}

void handleRestart() {
  String response = "{\"status\":\"success\",\"message\":\"Restarting device...\"}";
  server.send(200, "application/json", response);
  delay(1000);
  ESP.restart();
}

void handleCSS() {
  String css = generateCSS();
  server.send(200, "text/css", css);
}

void handleNotFound() {
  String response = "{\"status\":\"error\",\"message\":\"Not found\"}";
  server.send(404, "application/json", response);
}

// ============================================================================
// EEPROM FUNCTIONS
// ============================================================================

void saveWiFiCredentials(String ssid, String password) {
  Serial.println("Saving WiFi credentials to EEPROM...");
  
  // Clear EEPROM
  for (int i = 0; i < 512; i++) {
    EEPROM.write(i, 0);
  }
  
  // Write SSID
  EEPROM.write(0, ssid.length());
  for (int i = 0; i < ssid.length(); i++) {
    EEPROM.write(i + 1, ssid[i]);
  }
  
  // Write Password
  EEPROM.write(100, password.length());
  for (int i = 0; i < password.length(); i++) {
    EEPROM.write(i + 101, password[i]);
  }
  
  EEPROM.commit();
  Serial.println("✓ WiFi credentials saved");
}

void loadWiFiCredentials() {
  Serial.println("Loading WiFi credentials from EEPROM...");
  
  // Read SSID
  int ssidLength = EEPROM.read(0);
  if (ssidLength > 0 && ssidLength < 32) {
    wifi_ssid = "";
    for (int i = 0; i < ssidLength; i++) {
      wifi_ssid += char(EEPROM.read(i + 1));
    }
  }
  
  // Read Password
  int passwordLength = EEPROM.read(100);
  if (passwordLength > 0 && passwordLength < 64) {
    wifi_password = "";
    for (int i = 0; i < passwordLength; i++) {
      wifi_password += char(EEPROM.read(i + 101));
    }
  }
  
  if (wifi_ssid.length() > 0) {
    Serial.println("✓ Found stored credentials for: " + wifi_ssid);
  } else {
    Serial.println("✗ No stored WiFi credentials found");
  }
}

void clearStoredCredentials() {
  for (int i = 0; i < 512; i++) {
    EEPROM.write(i, 0);
  }
  EEPROM.commit();
  wifi_ssid = "";
  wifi_password = "";
}

// ============================================================================
// HTML GENERATION FUNCTIONS
// ============================================================================

String generateConfigHTML() {
  String html = "<!DOCTYPE html><html><head>";
  html += "<meta charset='UTF-8'>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>";
  html += "<title>Smart Switch Configuration</title>";
  html += "<style>";
  html += "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;";
  html += "background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);";
  html += "min-height:100vh;padding:20px;margin:0;}";
  html += ".container{max-width:600px;margin:0 auto;background:rgba(255,255,255,0.95);";
  html += "border-radius:20px;padding:30px;box-shadow:0 20px 40px rgba(0,0,0,0.1);}";
  html += ".header{text-align:center;margin-bottom:30px;}";
  html += ".header h1{color:#333;margin-bottom:10px;font-size:2.5em;}";
  html += ".section{margin-bottom:30px;padding:20px;background:rgba(255,255,255,0.7);";
  html += "border-radius:15px;border:1px solid rgba(255,255,255,0.3);}";
  html += ".btn{padding:12px 24px;border:none;border-radius:10px;font-size:1em;";
  html += "font-weight:600;cursor:pointer;margin:5px;}";
  html += ".btn-primary{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:white;}";
  html += ".btn-secondary{background:#f8f9fa;color:#333;border:2px solid #dee2e6;}";
  html += ".btn-danger{background:linear-gradient(135deg,#ff6b6b 0%,#ee5a52 100%);color:white;}";
  html += ".form-group{margin-bottom:20px;}";
  html += ".form-group label{display:block;margin-bottom:8px;font-weight:600;color:#333;}";
  html += ".form-group input{width:100%;padding:12px 15px;border:2px solid #dee2e6;";
  html += "border-radius:10px;font-size:1em;box-sizing:border-box;}";
  html += ".network-list{margin:20px 0;max-height:300px;overflow-y:auto;}";
  html += ".network-item{padding:15px;margin-bottom:10px;background:rgba(255,255,255,0.8);";
  html += "border:2px solid transparent;border-radius:10px;cursor:pointer;}";
  html += ".network-item:hover{background:rgba(102,126,234,0.1);border-color:#667eea;}";
  html += ".network-item.selected{background:rgba(102,126,234,0.2);border-color:#667eea;}";
  html += ".info-grid{display:grid;grid-template-columns:1fr 1fr;gap:15px;margin-bottom:20px;}";
  html += ".info-item{padding:12px;background:rgba(255,255,255,0.8);border-radius:8px;}";
  html += "</style></head><body>";
  
  html += "<div class='container'>";
  html += "<div class='header'>";
  html += "<h1>Smart Switch Setup</h1>";
  html += "<p>Board ID: <strong>" + String(BOARD_ID) + "</strong></p>";
  html += "</div>";
  
  html += "<div class='section'>";
  html += "<h2>WiFi Configuration</h2>";
  html += "<button onclick='scanNetworks()' class='btn btn-secondary' id='scanBtn'>Scan Networks</button>";
  html += "<div id='networkList' class='network-list'></div>";
  
  html += "<form onsubmit='submitConfig(event)'>";
  html += "<div class='form-group'>";
  html += "<label for='ssid'>Network Name (SSID):</label>";
  html += "<input type='text' id='ssid' name='ssid' required>";
  html += "</div>";
  html += "<div class='form-group'>";
  html += "<label for='password'>Password:</label>";
  html += "<input type='password' id='password' name='password'>";
  html += "<small>Leave empty for open networks</small>";
  html += "</div>";
  html += "<button type='submit' class='btn btn-primary'>Connect to WiFi</button>";
  html += "</form></div>";
  
  html += "<div class='section'>";
  html += "<h2>Device Information</h2>";
  html += "<div class='info-grid'>";
  html += "<div class='info-item'><strong>Board ID:</strong> " + String(BOARD_ID) + "</div>";
  html += "<div class='info-item'><strong>Firmware:</strong> " + String(FIRMWARE_VERSION) + "</div>";
  html += "<div class='info-item'><strong>MAC Address:</strong> " + deviceMAC + "</div>";
  html += "<div class='info-item'><strong>Switches:</strong> " + String(NUM_SWITCHES) + "</div>";
  html += "</div>";
  html += "<button onclick='restartDevice()' class='btn btn-danger'>Restart Device</button>";
  html += "</div></div>";
  
  html += "<script>";
  html += "let networks = [];";
  html += "function scanNetworks() {";
  html += "  fetch('/scan').then(r => r.json()).then(data => {";
  html += "    networks = data.networks;";
  html += "    displayNetworks(networks);";
  html += "  });";
  html += "}";
  html += "function displayNetworks(networks) {";
  html += "  const list = document.getElementById('networkList');";
  html += "  list.innerHTML = '';";
  html += "  if(networks.length === 0) {";
  html += "    list.innerHTML = '<p>No networks found</p>';";
  html += "    return;";
  html += "  }";
  html += "  networks.sort((a,b) => b.rssi - a.rssi);";
  html += "  networks.forEach(network => {";
  html += "    const div = document.createElement('div');";
  html += "    div.className = 'network-item';";
  html += "    div.onclick = () => selectNetwork(network.ssid);";
  html += "    const signal = network.rssi > -60 ? '***' : network.rssi > -80 ? '**' : '*';";
  html += "    const secure = network.secure ? '[SECURE]' : '[OPEN]';";
  html += "    div.innerHTML = '<strong>' + network.ssid + '</strong><br>' + secure + ' ' + signal + ' ' + network.rssi + 'dBm';";
  html += "    list.appendChild(div);";
  html += "  });";
  html += "}";
  html += "function selectNetwork(ssid) {";
  html += "  document.getElementById('ssid').value = ssid;";
  html += "  document.querySelectorAll('.network-item').forEach(item => item.classList.remove('selected'));";
  html += "  event.currentTarget.classList.add('selected');";
  html += "}";
  html += "function submitConfig(event) {";
  html += "  event.preventDefault();";
  html += "  const formData = new FormData(event.target);";
  html += "  fetch('/config', { method: 'POST', body: formData })";
  html += "    .then(r => r.json())";
  html += "    .then(result => {";
  html += "      if(result.status === 'success') {";
  html += "        alert('SUCCESS: ' + result.message);";
  html += "      } else {";
  html += "        alert('ERROR: ' + result.message);";
  html += "      }";
  html += "    });";
  html += "}";
  html += "function restartDevice() {";
  html += "  if(confirm('Are you sure you want to restart the device?')) {";
  html += "    fetch('/restart', { method: 'POST' });";
  html += "    alert('Device is restarting...');";
  html += "  }";
  html += "}";
  html += "window.onload = function() { scanNetworks(); };";
  html += "</script>";
  html += "</body></html>";
  
  return html;
}

String generateCSS() {
  // CSS is now embedded in the HTML
  return "body{margin:0;padding:20px;font-family:Arial,sans-serif;}";
}

// ============================================================================
// STATUS PRINTING
// ============================================================================


void printStatus() {
  Serial.println("\n╔════════════════════════════════════════╗");
  Serial.println("║         SYSTEM STATUS SUMMARY          ║");
  Serial.println("╚════════════════════════════════════════╝");
  Serial.println("Board ID: " + String(BOARD_ID));
  Serial.println("WiFi: " + String(isConnectedToWiFi ? "✓ Connected" : "✗ Disconnected"));
  if (isConnectedToWiFi) {
    Serial.println("  IP: " + WiFi.localIP().toString());
    Serial.println("  Signal: " + String(WiFi.RSSI()) + " dBm");
  }
  Serial.println("Uptime: " + String(millis() / 1000) + "s");

  Serial.println("\nSwitch States:");
  for (int i = 0; i < NUM_SWITCHES; i++) {
    Serial.println("  Switch " + String(i + 1) + ": " + String(switchStates[i] ? "ON ⚡" : "OFF"));
  }

  Serial.println("════════════════════════════════════════\n");
}


// ============================================================================
// END OF CODE
// ============================================================================