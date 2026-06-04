// ------------------- Pins -------------------
#define IN1 7
#define IN2 6
#define IN3 5
#define IN4 4
#define ENA 3
#define ENB 11

#define TRIG_PIN 10
#define ECHO_PIN 9
#define SERVO_PIN 2

#define LED1 8
#define LED2 12

// Line Sensors
#define SENSOR_LEFT A0
#define SENSOR_CENTER A1
#define SENSOR_RIGHT 13

// DFPlayer
#include <SoftwareSerial.h>
SoftwareSerial dfSerial(A2, A3); // RX, TX

#include <DFRobotDFPlayerMini.h>
DFRobotDFPlayerMini myDFPlayer;

// OLED
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Servo.h>

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

Servo scanServo;

// ------------------- Variables -------------------
int baseSpeed = 90;
int speedFast = 120;

char command;
bool movingForward = false;
bool lineMode = false;

unsigned long lastBlink = 0;
bool ledState = false;

String currentAction = "";
unsigned long actionDisplayStart = 0;

// ------------------- Setup -------------------
void setup() {

  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
  pinMode(ENA, OUTPUT); pinMode(ENB, OUTPUT);

  pinMode(TRIG_PIN, OUTPUT); pinMode(ECHO_PIN, INPUT);
  pinMode(LED1, OUTPUT); pinMode(LED2, OUTPUT);

  pinMode(SENSOR_LEFT, INPUT);
  pinMode(SENSOR_CENTER, INPUT);
  pinMode(SENSOR_RIGHT, INPUT);

  Serial.begin(9600);
  dfSerial.begin(9600);

  // DFPlayer Init
  if (!myDFPlayer.begin(dfSerial)) {
    Serial.println("DFPlayer ERROR");
  }
  myDFPlayer.volume(30);

  // OLED Init
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  display.clearDisplay();

  scanServo.attach(SERVO_PIN);
  scanServo.write(115);
}

// ------------------- LOOP -------------------
void loop() {

  updateLEDs();
  handleActionDisplay();

  // ---------- Bluetooth Commands ----------
  if (Serial.available()) {
    command = Serial.read();

    if (command == 'F') { movingForward = true; lineMode = false; showAction("FORWARD"); playVoice(1); }
    else if (command == 'B') { movingForward = false; backward(); playVoice(48); }
    else if (command == 'L') { movingForward = false; tightLeftTurn(); playVoice(3); }
    else if (command == 'R') { movingForward = false; tightRightTurn(); playVoice(4); }
    else if (command == 'S') { movingForward = false; stopMotors(); showAction("STOP"); playVoice(2); }

    else if (command == 'T') { lineMode = true; movingForward = false; showAction("LINE ON"); }
    else if (command == 'D') { lineMode = false; stopMotors(); showAction("LINE OFF"); }
  }

  // ---------- LINE TRACK MODE ----------
  if (lineMode) {
    lineTracking();
    return;
  }

  // ---------- NORMAL FORWARD ----------
  if (movingForward) {
    if (!obstacleDetected()) moveForward();
    else {
      stopMotors();
      movingForward = false;
      showAction("OBSTACLE");
      playVoice(17);
    }
  }
}

// ------------------- LINE TRACK -------------------
void lineTracking() {
  int left = digitalRead(SENSOR_LEFT);
  int center = digitalRead(SENSOR_CENTER);
  int right = digitalRead(SENSOR_RIGHT);

  if (center == LOW) moveForward();
  else if (left == LOW) tightLeftTurn();
  else if (right == LOW) tightRightTurn();
  else stopMotors();
}

// ------------------- MOTOR -------------------
void moveForward() {
  digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);  digitalWrite(IN4, HIGH);
  analogWrite(ENA, baseSpeed);
  analogWrite(ENB, baseSpeed);
}

void backward() {
  digitalWrite(IN1, LOW); digitalWrite(IN2, HIGH);
  digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW);
  analogWrite(ENA, baseSpeed);
  analogWrite(ENB, baseSpeed);
  delay(800);
  stopMotors();
}

void stopMotors() {
  digitalWrite(IN1, HIGH); digitalWrite(IN2, HIGH);
  digitalWrite(IN3, HIGH); digitalWrite(IN4, HIGH);
  analogWrite(ENA, 0);
  analogWrite(ENB, 0);
}

// ------------------- TURN -------------------
void tightLeftTurn() {
  digitalWrite(IN1, LOW); digitalWrite(IN2, HIGH);
  digitalWrite(IN3, LOW); digitalWrite(IN4, HIGH);
  delay(500);
  stopMotors();
}

void tightRightTurn() {
  digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
  digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW);
  delay(500);
  stopMotors();
}

// ------------------- OBSTACLE -------------------
bool obstacleDetected() {
  digitalWrite(TRIG_PIN, LOW); delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH);
  int d = duration * 0.034 / 2;

  return (d > 0 && d <= 20);
}

// ------------------- VOICE -------------------
void playVoice(int track) {
  myDFPlayer.play(track);
}

// ------------------- LED -------------------
void updateLEDs() {
  if (millis() - lastBlink > 300) {
    digitalWrite(LED1, ledState);
    digitalWrite(LED2, !ledState);
    ledState = !ledState;
    lastBlink = millis();
  }
}

// ------------------- OLED -------------------
void showAction(const char* text) {
  currentAction = text;
  actionDisplayStart = millis();
}

void handleActionDisplay() {
  if (millis() - actionDisplayStart <= 3000) {
    display.clearDisplay();
    display.setTextSize(2);
    display.setCursor(10, 20);
    display.println(currentAction);
    display.display();
  }
}void setup() {
  // put your setup code here, to run once:

}

void loop() {
  // put your main code here, to run repeatedly:

}
