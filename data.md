# LeadX Configuration & Credentials (Plain Text)

This document contains all system configuration keys and credentials in plain text without encryption or masking.

---

## 1. Web Installer Step 6 — Pusher (Real-time Notifications)
Use these exact plain-text values if you want to fill in the **Pusher (Real-time Notifications)** section in the installation wizard:

| Field on Screen | Plain Text Value | Description |
|---|---|---|
| **App ID** | `leadx` | Reverb / Pusher Application ID |
| **App Key** | `QcK9STacr/NFbZiRmZCNiQ==` | Reverb / Pusher Public Key |
| **App Secret** | `osvrIDd6ELyY2+s2cMVf1xgYwPQ2nltwGm2+4kyItpc=` | Reverb / Pusher Secret Key |
| **Cluster** | `mt1` | Cluster code (or leave as `mt1`) |

> **Note:** These 4 fields are **optional**. You can also leave them completely blank and proceed; the application will safely use local Reverb and polling.

---

## 2. Real-Time Broadcasting (Laravel Reverb & WebSockets)

| Key | Plain Text Value |
|---|---|
| **BROADCAST_CONNECTION** | `reverb` |
| **REVERB_APP_ID** | `leadx` |
| **REVERB_APP_KEY** | `QcK9STacr/NFbZiRmZCNiQ==` |
| **REVERB_APP_SECRET** | `osvrIDd6ELyY2+s2cMVf1xgYwPQ2nltwGm2+4kyItpc=` |
| **REVERB_HOST** | `127.0.0.1` *(Local)* / `leadx.cloudaspiresolutions.in` *(Production)* |
| **REVERB_PORT** | `8080` *(Local)* / `443` *(Production WSS)* |
| **REVERB_SCHEME** | `http` *(Local)* / `https` *(Production)* |

---

## 3. Pusher Beams (Mobile Push Notifications)

| Key | Plain Text Value |
|---|---|
| **PUSHER_INSTANCE_ID** | `92e6f629-4814-40c1-b65d-b0e7e078066f` |
| **PUSHER_DEVICE_INTEREST** | `hello` |
| **PUSHER_SERVER_KEY** | `25731B87565F690F5B373B2D597F004C5044F4A9FE47DD5826AFAE2753F7CD08` |
| **PUSHER_BEAMS_INSTANCE_ID** | `c144beef-40e3-468e-9b6b-3430167dec63` |
| **PUSHER_BEAMS_SECRET_KEY** | `722F9A2E588EF14BEE675E6F53B3EA8AAFF83E656709151B0E7DF0A241E9FB37` |

---

## 4. Database Configuration

| Key | Plain Text Value |
|---|---|
| **DB_CONNECTION** | `mysql` |
| **DB_HOST** | `127.0.0.1` |
| **DB_PORT** | `3306` |
| **DB_DATABASE** | `leadx` |
| **DB_USERNAME** | `root` |
| **DB_PASSWORD** | *(empty)* |

---

## 5. Mail & SMTP Configuration

| Key | Plain Text Value |
|---|---|
| **MAIL_MAILER** | `log` *(or `smtp`)* |
| **MAIL_PORT** | `587` |
| **MAIL_USERNAME** | `premfxexe` |
| **MAIL_PASSWORD** | `Premfx@2006` |
| **MAIL_FROM_NAME** | `Leadx` |

---

## 6. Firebase Cloud Messaging (FCM — Mobile App)

| Key | Plain Text Value |
|---|---|
| **FCM_PROJECT_ID** | `leadx-eb5c5` |
| **FCM_ANDROID_CHANNEL_ID** | `leadx_general` |

---

## 7. Application & Cron Security Keys

| Key | Plain Text Value |
|---|---|
| **APP_NAME** | `LeadX Production` |
| **APP_URL** | `https://leadx.cloudaspiresolutions.in` |
| **APP_KEY** | `base64:14Cx3V35KSTZB8kJKZ2C8BIvdqf7GfC5MwvqcWTfIXM=` |
| **CRON_SECRET_TOKEN** | `leadx_cron_master_key_2026` |
| **APP_CURRENCY** | `INR` |
| **APP_CURRENCY_SYMBOL** | `₹` |
| **APP_TIMEZONE** | `UTC` |
| **QUEUE_CONNECTION** | `sync` *(or `database`)* |
