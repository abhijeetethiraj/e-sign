# 🚀 eSign API — Backend Audit Ledger & Verification Service

Lightweight, high-performance Node.js Express microservice for immutable eSign audit recording, SHA-256 cryptographic tamper verification, and automated signed document email delivery.

---

## 🛠️ Tech Stack
* **Runtime**: Node.js 20 LTS (Alpine Docker image)
* **Framework**: Express.js 4.19
* **Database**: MySQL 8.0 (InnoDB) with `mysql2/promise` connection pooling
* **Email Service**: Nodemailer (Gmail App Password SMTP)
* **Containerization**: Docker & Docker Compose (`restart: unless-stopped`)

---

## 📡 API Endpoints

### 1. Health Check
* **Method**: `GET /api/health`
* **Response**:
```json
{
  "status": "ok",
  "service": "eSign Audit & Verification API",
  "timestamp": "2026-10-08T10:31:40.777Z"
}
```

### 2. Record Signing Event
* **Method**: `POST /api/signing-events`
* **Payload**:
```json
{
  "signingEventId": "evt_1791441421855",
  "documentHash": "a1b2c3d4...",
  "signedDocumentHash": "e5f6g7h8...",
  "documentTitle": "Software_License_Agreement.pdf",
  "userEmail": "signer@example.com",
  "userId": "usr_123",
  "ipAddress": "192.168.1.10",
  "biometricVerification": "Device Biometric (Fingerprint/FaceID)",
  "authenticationMethod": "Keycloak SSO (Google OAuth2 + PKCE)",
  "signedAt": "2026-10-08T10:30:00.000Z",
  "status": "COMPLETED",
  "pdfBase64": "JVBERi0xLjQK..."
}
```
* **Response**: `201 Created`
```json
{
  "success": true,
  "message": "Signing event recorded successfully in immutable audit ledger.",
  "eventId": "evt_1791441421855"
}
```

### 3. Public Verification Lookup
* **Method**: `GET /api/signing-events/verify/:query`
* **Param**: `:query` can be either the `signingEventId` OR the `documentHash` (SHA-256).
* **Response**:
```json
{
  "verified": true,
  "status": "VALID_AND_AUTHENTIC",
  "message": "Document signature is cryptographically verified and recorded.",
  "event": {
    "signingEventId": "evt_1791441421855",
    "documentHash": "a1b2c3d4...",
    "documentTitle": "Software_License_Agreement.pdf",
    "userEmail": "signer@example.com",
    "biometricVerification": "Device Biometric (Fingerprint/FaceID)",
    "signedAt": "2026-10-08 10:30:00",
    "status": "COMPLETED"
  }
}
```

---

## 🐳 Quick Start with Docker Compose

1. **Configure Environment**:
   ```bash
   cp .env.example .env
   ```
2. **Start Services**:
   ```bash
   docker compose up -d --build
   ```
3. **Verify Status**:
   ```bash
   docker compose ps
   curl http://localhost:8000/api/health
   ```

---

## 💻 Local Development

1. **Install dependencies**:
   ```bash
   npm install
   ```
2. **Start MySQL locally** or via Docker:
   ```bash
   docker run --name local-mysql -e MYSQL_ROOT_PASSWORD=rootpassword -e MYSQL_DATABASE=esign_db -p 3306:3306 -d mysql:8.0
   ```
3. **Run development server with hot-reload**:
   ```bash
   npm run dev
   ```
