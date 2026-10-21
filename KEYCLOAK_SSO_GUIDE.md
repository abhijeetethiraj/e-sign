# Complete Keycloak SSO Integration Guide (Mobile & Web)

This guide is your **standard reference** whenever you need to integrate Keycloak (OneSSO) authentication into any mobile or web application.

---

## 1. The Core Mental Model

Keycloak is a centralized **Identity Provider (IdP)**. Instead of every app building its own password storage and SMS verification from scratch, Keycloak acts as the **central security guard**.

There are **two main ways** a mobile or web app can talk to Keycloak:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      TWO MODES OF AUTHENTICATION                        │
├────────────────────────────────────┬────────────────────────────────────┤
│ Mode A: In-App Browser (PKCE)      │ Mode B: Direct Headless (API)      │
│ (Standard Enterprise OAuth2)       │ (Native In-App Textfields)         │
├────────────────────────────────────┼────────────────────────────────────┤
│ • App opens an In-App Custom Tab   │ • App builds its own textfields    │
│ • Keycloak renders the login UI    │ • App sends user/pass via HTTP POST│
│ • Handles Google & SMS natively    │ • Keycloak returns tokens directly │
│ • Needs "Standard Flow: ON"        │ • Needs "Direct Access Grants: ON" │
└────────────────────────────────────┴────────────────────────────────────┘
```

---

## 2. What Information You MUST Send to the Keycloak Developer

Whenever you start a new app (e.g. `esign-app`, `invoice-app`, `oneflow`), send this checklist to your Keycloak administrator:

### The 7 Essential Parameters

| # | Parameter | What It Means | Example Value |
|---|---|---|---|
| **1** | **Realm Name** | The security partition inside Keycloak | `fstech` |
| **2** | **Client ID** | The unique identifier for your application | `esign-app` |
| **3** | **Client Type** | Public (no secret) vs. Confidential (has secret) | **Public** (for Mobile / React SPA) |
| **4** | **Flow Type** | Standard Flow (PKCE) or Direct Access Grants | Both `ON` |
| **5** | **Valid Redirect URIs** | Where Keycloak is legally allowed to send the user after login | See table below |
| **6** | **Web Origins** | CORS domains allowed to make API calls | `+` (inherits from redirect URIs) |
| **7** | **Identity Providers** | Social logins like Google, Microsoft, Apple | `google` (`kc_idp_hint=google`) |

### Mandatory Redirect URIs for Mobile Apps

Every mobile app needs **three distinct callback URIs** registered in Keycloak:

```text
1. Desktop / Mac / Simulator Testing:
   http://localhost:8080/callback

2. Real Android & iOS Devices (Deep Link):
   <your-app-scheme>://login-callback
   (Example: esign://login-callback or invoice://login-callback)

3. Staging / Cloud Server (if hosted):
   http://<server-ip-or-domain>/auth/oidc/callback/
```

> [!IMPORTANT]
> If a redirect URI is **even 1 character different** (e.g. missing a trailing slash or wrong scheme), Keycloak will immediately block the request with `Invalid parameter: redirect_uri`.

---

## 3. The Golden Copy-Paste Prompt for Your Developer

Whenever you start a new project, copy this exact prompt, replace the bracketed values `<...>`, and send it to your Keycloak developer:

```text
Hi,

We are configuring Keycloak SSO for a new application. Please create/configure the client in our realm with the following settings:

1. Target Realm & Client:
   - Server: https://stgsso.cubeone.in (or https://sso.cubeone.in for Production)
   - Realm: <realm-name, e.g. fstech>
   - Client ID: <client-id, e.g. esign-app>
   - Client Name: <App Name, e.g. eSign Platform>

2. Capability Configuration:
   - Client authentication: OFF (Public client — mobile apps must not store client secrets)
   - Standard Flow: ON (Authorization Code with PKCE S256)
   - Direct Access Grants: ON (Required so our native in-app textfields can authenticate directly via REST API)

3. Valid Redirect URIs:
   - http://localhost:8080/callback
   - <app-scheme>://login-callback
   - http://<server-ip>/auth/oidc/callback/

4. Valid Post-Logout Redirect URIs:
   - http://localhost:8080/
   - <app-scheme>://login-callback

5. Web Origins:
   - +

6. Identity Provider (Google):
   - Please ensure the Google broker alias 'google' is linked to this realm so kc_idp_hint=google works directly.

7. SMS OTP (if applicable):
   - Please let us know if there is a REST endpoint to trigger SMS OTP for mobile (e.g. POST /sms/send-otp), or if SMS is handled via the web flow.

Please confirm once saved. Thank you!
```

---

## 4. How to Test & Verify with cURL (In 10 Seconds)

Before writing any frontend code, test Keycloak from your terminal using these four commands:

### Test 1: Check if the Realm is Online
```bash
curl -s https://<keycloak-host>/realms/<realm>/.well-known/openid-configuration | head -n 10
```
* **Success:** Returns a JSON object with `"issuer": "https://..."`.

### Test 2: Check if Direct Access Grants is ON
```bash
curl -s -X POST "https://<keycloak-host>/realms/<realm>/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=<client-id>&username=test&password=test"
```
* **SUCCESS (Direct Grants is ON):**
  `{"error":"invalid_grant","error_description":"Invalid user credentials"}`
  *(This means the server accepted the direct API request, and only failed because test/test is not a real user!)*
* **FAILURE (Direct Grants is OFF):**
  `{"error":"unauthorized_client","error_description":"Client not allowed for direct access grants"}`
  *(This means your developer forgot to turn Direct Access Grants ON).*

### Test 3: Check if Redirect URIs are Registered
```bash
curl -s -I "https://<keycloak-host>/realms/<realm>/protocol/openid-connect/auth?client_id=<client-id>&response_type=code&redirect_uri=http://localhost:8080/callback&scope=openid"
```
* **SUCCESS:** `HTTP/1.1 200 OK` (or `302 Found`).
* **FAILURE:** Page displays HTML with error `Invalid parameter: redirect_uri`.

### Test 4: Check if Google One-Click Works
```bash
curl -s -I "https://<keycloak-host>/realms/<realm>/protocol/openid-connect/auth?client_id=<client-id>&response_type=code&redirect_uri=http://localhost:8080/callback&scope=openid&kc_idp_hint=google"
```
* **SUCCESS:** `HTTP/1.1 200 OK` (redirects or loads Google broker).

---

## 5. Common Error Messages & How to Fix Them

| Error Message | Why It Happened | The Fix |
|---|---|---|
| `unauthorized_client: Client not allowed for direct access grants` | Your Flutter app is trying to send username/password directly via REST, but Keycloak has Direct Grants turned OFF. | In Keycloak Admin → Clients → Select Client → Turn **Direct Access Grants: ON**. |
| `Invalid parameter: redirect_uri` | The redirect URI sent by the app doesn't match the list in Keycloak. | Add the exact URL (e.g. `http://localhost:8080/callback` or `esign://login-callback`) into **Valid Redirect URIs**. |
| `invalid_grant: Invalid user credentials` | Direct grants is working, but the password or mobile number is wrong. | Check username and password in Keycloak Users panel. |
| `disallowed_useragent` (Google Error) | Google blocks OAuth logins inside embedded WebViews for security reasons. | Use `launchUrl(..., mode: LaunchMode.inAppBrowserView)` (Chrome Custom Tab) or the official `google_sign_in` SDK. |
| `CORS policy: No 'Access-Control-Allow-Origin'` | A web browser app is making API calls to Keycloak, but the domain isn't whitelisted. | Add `+` or your app's origin domain to **Web Origins** in Keycloak client settings. |

---

## 6. How Flutter Handles Both Flows

### Flow 1: Direct In-App Password Authentication (Zero Browser Popup)
```dart
// POST to Keycloak's token endpoint
final response = await dio.post(
  'https://stgsso.cubeone.in/realms/fstech/protocol/openid-connect/token',
  data: {
    'grant_type': 'password',
    'client_id': 'esign-app',
    'username': username,
    'password': password,
    'scope': 'openid profile email',
  },
  options: Options(contentType: Headers.formUrlEncodedContentType),
);

// Response contains:
// - access_token (JWT)
// - id_token (User identity claims)
// - refresh_token (Session refresh)
```

### Flow 2: In-App Browser Sheet (for Google OAuth & SMS)
```dart
// Launch via In-App Custom Tab with Google hint
final uri = Uri.parse(
  'https://stgsso.cubeone.in/realms/fstech/protocol/openid-connect/auth'
  '?client_id=esign-app'
  '&response_type=code'
  '&redirect_uri=http://localhost:8080/callback'
  '&scope=openid profile email'
  '&kc_idp_hint=google' // Direct to Google!
);

await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
```

---

## 7. Golden Security Rules

1. **NEVER store client secrets in mobile apps:** Mobile APKs and IPAs can be decompiled. Always use **Public Clients + PKCE (`S256`)**.
2. **Never use wildcard redirect URIs (`*`):** Always specify exact URLs (`http://localhost:8080/callback`, `esign://login-callback`).
3. **Always validate the JWT signature and audience (`aud`):** Ensure the token was issued by your Keycloak issuer and intended for your client ID.
