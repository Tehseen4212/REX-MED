# 🤖 REX-MED

## Smart Hospital Assistance Robot

REX-MED is a healthcare-focused robotic assistant developed to support hospitals and healthcare facilities through automation, navigation, and intelligent assistance.

The project aims to reduce manual workload, improve operational efficiency, and provide a foundation for future AI-powered healthcare support systems.

---

## 🚀 Overview

Hospitals often face challenges such as:

* Manual transportation of medicines and supplies
* Limited staff availability
* Delays in internal logistics
* Need for contactless assistance solutions

REX-MED was developed as a prototype healthcare robot capable of assisting with navigation, delivery, and patient interaction tasks.

---

## ✨ Features

### 🤖 Robotic Mobility

* 4-Wheel Drive (4WD) platform
* Bluetooth-based control
* Forward, backward, left, right movement
* Stop functionality

### 🚧 Obstacle Detection

* HC-SR04 Ultrasonic Sensor
* Real-time distance monitoring
* Collision avoidance support

### 📱 Wireless Control

* Mobile application control
* Bluetooth communication using HC-05

### 🖥️ Visual Feedback

* OLED display integration
* Status display and visual expressions

### 🔊 Audio Support

* DFPlayer Mini integration
* Voice playback functionality
* Speaker support

### 🏥 Healthcare Applications

* Medicine delivery assistance
* Patient guidance
* Internal logistics support
* Contactless interactions

---

## 🏗️ Hardware Components

* Arduino Uno
* ESP32 (Future Integration)
* L298N Motor Driver
* HC-05 Bluetooth Module
* HC-SR04 Ultrasonic Sensor
* OLED Display
* DFPlayer Mini
* PAM8403 Audio Amplifier
* Speaker
* 4 DC Motors
* Chassis and Wheels
* Battery Power Supply

---

## ⚙️ Software & Technologies

### Embedded Systems

* Arduino IDE
* Embedded C/C++

### Communication

* Bluetooth Serial Communication

### Libraries

* Adafruit SSD1306
* Adafruit GFX
* U8g2 Graphics Library

---

## 🔄 System Workflow

```text
Mobile App
     │
     ▼
Bluetooth Commands
     │
     ▼
Arduino Controller
     │
     ├── Motor Driver → Robot Movement
     ├── Ultrasonic Sensor → Obstacle Detection
     ├── OLED Display → Status Feedback
     └── Audio Module → Voice Playback
```

---

## 📋 Working

1. User sends commands through mobile application.
2. HC-05 receives Bluetooth instructions.
3. Arduino processes commands.
4. L298N controls motor movement.
5. Ultrasonic sensor continuously checks for obstacles.
6. OLED displays robot status.
7. Audio module provides voice output when required.

---

## 🎯 Applications

* Hospitals
* Clinics
* Healthcare Centers
* Smart Healthcare Research
* Educational Robotics

---

## 🔮 Future Scope

* Voice Assistant Integration
* AI-based Patient Interaction
* Autonomous Navigation
* Medicine Identification
* Face Recognition
* Emergency Alert System
* Hospital Management Integration
* IoT Connectivity
* Cloud-Based Monitoring

---

## 🧠 Skills Demonstrated

* Robotics
* Embedded Systems
* Arduino Programming
* Sensor Integration
* Mobile App Control
* Hardware-Software Integration
* Problem Solving

---

## 👥 Team

Project: REX-MED

### Tagline

**"Supporting Healthcare Through Intelligent Robotics."**
