#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// UUIDs
#define SERVICE_UUID        "12345678-1234-1234-1234-1234567890ab"
#define CHARACTERISTIC_UUID "12345678-1234-1234-1234-1234567890cd"

// GPIO-Pin für den Button
#define BUTTON_PIN 18

BLECharacteristic* pCharacteristic;

// BLE-Server und Advertising-Objekt
BLEServer* pServer;
BLEAdvertising* pAdvertising;

bool deviceConnected = false;
bool timerRunning = false;
unsigned long startTime = 0;
unsigned long stopTime = 0;

// BLE-Server-Callback-Klasse
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    Serial.println("Client connected!");
    deviceConnected = true;
  }

  void onDisconnect(BLEServer* pServer) {
    Serial.println("Client disconnected!");
    deviceConnected = false;
    // Werbung erneut starten, wenn kein Gerät verbunden ist
    pAdvertising->start();
    Serial.println("Advertising restarted.");
  }
};

void initBLE() {
  // BLE initialisieren
  BLEDevice::init("ESP32_Bluetooth_Device");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_NOTIFY
  );

  // Standardwert setzen
  pCharacteristic->setValue("Hello BLE");
  pCharacteristic->addDescriptor(new BLE2902());

  // Service starten
  pService->start();

  pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->start();
  Serial.println("Advertising started.");
}

void setup() {
  Serial.begin(115200); 

  pinMode(BUTTON_PIN, INPUT_PULLUP);

  initBLE();
}

void loop() {
  int buttonState = digitalRead(BUTTON_PIN);

  if (buttonState == LOW && deviceConnected) { // LOW bedeutet gedrückt (wegen INPUT_PULLUP)
    pCharacteristic->setValue("1");
    pCharacteristic->notify();

   
    if (!timerRunning) {
      startTime = millis();
      timerRunning = true;
    }else{
      stopTime = millis();
      timerRunning = false;
      long elapsedTime = (long)stopTime - (long)startTime - 16930;
      String timeStr = "t" + String(elapsedTime);
      pCharacteristic->setValue(timeStr.c_str());
      pCharacteristic->notify();
      timerRunning = false;
    }

    
    while (digitalRead(BUTTON_PIN) == LOW) {
      delay(10);
    }
  }

  delay(50); 
}
