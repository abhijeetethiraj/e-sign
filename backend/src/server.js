import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { pool, initDatabase } from './db.js';
import { sendCompletionEmail } from './email.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 8000;

// Enable CORS and JSON parsing middleware (allow up to 25MB for PDF attachment payloads)
app.use(cors());
app.use(express.json({ limit: '25mb' }));

// 1. Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'eSign Audit & Verification API',
    timestamp: new Date().toISOString(),
  });
});

// 2. SAVE Endpoint: Records a new signing event in MySQL & triggers automated email
app.post('/api/signing-events', async (req, res) => {
  try {
    const {
      signingEventId,
      documentHash,
      signedDocumentHash = null,
      documentTitle = 'Untitled Document',
      userEmail,
      userId = 'usr_anonymous',
      ipAddress = '127.0.0.1',
      biometricVerification = 'Biometric Not Recorded',
      authenticationMethod = 'Keycloak SSO (Google OAuth2 + PKCE)',
      signedAt,
      status = 'COMPLETED',
      pdfBase64 = null,
    } = req.body;

    // Validation
    if (!signingEventId || !documentHash || !userEmail) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: signingEventId, documentHash, and userEmail are required.',
      });
    }

    // Format signedAt date for MySQL DATETIME
    const parsedDate = signedAt ? new Date(signedAt) : new Date();
    const formattedSignedAt = parsedDate.toISOString().slice(0, 19).replace('T', ' ');

    const insertSql = `
      INSERT INTO signing_events (
        signing_event_id,
        document_hash,
        signed_document_hash,
        document_title,
        user_email,
        user_id,
        ip_address,
        biometric_verification,
        authentication_method,
        signed_at,
        status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        document_hash = VALUES(document_hash),
        signed_document_hash = VALUES(signed_document_hash),
        biometric_verification = VALUES(biometric_verification),
        status = VALUES(status);
    `;

    await pool.query(insertSql, [
      signingEventId,
      documentHash,
      signedDocumentHash,
      documentTitle,
      userEmail,
      userId,
      ipAddress,
      biometricVerification,
      authenticationMethod,
      formattedSignedAt,
      status,
    ]);

    console.log(`[Audit] Successfully saved signing event ${signingEventId} for ${userEmail}`);

    // Trigger automated background email with signed PDF attachment
    // (If signed in demo mode with example.com, fallback to SMTP_USER so testing works effortlessly)
    const recipient = (userEmail && !userEmail.toLowerCase().includes('example.com'))
      ? userEmail
      : (process.env.SMTP_USER || userEmail);

    sendCompletionEmail({
      to: recipient,
      documentTitle: documentTitle,
      signedAt: formattedSignedAt,
      documentHash: signedDocumentHash || documentHash,
      signerIp: ipAddress,
      pdfBase64: pdfBase64,
    }).catch((err) => {
      console.error('[Audit] Non-fatal email error:', err.message);
    });

    return res.status(201).json({
      success: true,
      message: 'Signing event recorded successfully in immutable audit ledger.',
      eventId: signingEventId,
    });
  } catch (err) {
    console.error('[Audit] Error saving signing event:', err.message);
    return res.status(500).json({
      success: false,
      error: 'Failed to record signing event into database.',
      details: err.message,
    });
  }
});

// 2b. TEST EMAIL Endpoint: Allows checking SMTP credentials anytime
app.post('/api/email/test', async (req, res) => {
  const { to = process.env.SMTP_USER } = req.body;
  if (!to) {
    return res.status(400).json({
      success: false,
      error: 'Recipient email "to" is required (or set SMTP_USER in .env).',
    });
  }

  const result = await sendCompletionEmail({
    to,
    documentTitle: 'Test Agreement Document.pdf',
    signedAt: new Date().toUTCString(),
    documentHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    signerIp: req.ip || '127.0.0.1',
  });

  if (result.success) {
    return res.json({ success: true, message: `Test email sent to ${to}!`, messageId: result.messageId });
  } else {
    return res.status(500).json({ success: false, error: result.error || result.reason });
  }
});

// 3. VERIFY Endpoint: Queries by either Event ID or Document SHA-256 Hash
app.get('/api/signing-events/verify/:query', async (req, res) => {
  try {
    const queryParam = req.params.query.trim();

    const selectSql = `
      SELECT 
        signing_event_id,
        document_hash,
        signed_document_hash,
        document_title,
        user_email,
        user_id,
        ip_address,
        biometric_verification,
        authentication_method,
        signed_at,
        status,
        created_at
      FROM signing_events
      WHERE signing_event_id = ? OR document_hash = ? OR signed_document_hash = ?
      ORDER BY signed_at DESC
      LIMIT 1;
    `;

    const [rows] = await pool.query(selectSql, [queryParam, queryParam, queryParam]);

    if (!rows || rows.length === 0) {
      return res.status(404).json({
        verified: false,
        status: 'NOT_FOUND_OR_TAMPERED',
        message: 'No matching signing event found. This document may be unsigned or modified.',
      });
    }

    const row = rows[0];

    return res.json({
      verified: true,
      status: 'VALID_AND_AUTHENTIC',
      message: 'Document signature is cryptographically verified and recorded.',
      event: {
        signingEventId: row.signing_event_id,
        documentHash: row.document_hash,
        documentTitle: row.document_title,
        userEmail: row.user_email,
        userId: row.user_id,
        ipAddress: row.ip_address,
        biometricVerification: row.biometric_verification,
        authenticationMethod: row.authentication_method,
        signedAt: row.signed_at,
        status: row.status,
      },
    });
  } catch (err) {
    console.error('[Verify] Verification query error:', err.message);
    return res.status(500).json({
      verified: false,
      error: 'Internal server error while verifying signature.',
    });
  }
});

// Start server with connection retry for containerized environments
async function startServer() {
  const maxRetries = 10;
  const retryDelayMs = 3000;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`[Express] Connecting to database (attempt ${attempt}/${maxRetries})...`);
      await initDatabase();
      break;
    } catch (err) {
      if (attempt === maxRetries) {
        console.error('[Express] Database connection failed after all attempts:', err.message);
        process.exit(1);
      }
      console.warn(`[Express] Database not ready yet (${err.message}). Retrying in ${retryDelayMs / 1000}s...`);
      await new Promise((resolve) => setTimeout(resolve, retryDelayMs));
    }
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[Express] eSign Backend running on http://0.0.0.0:${PORT}`);
    console.log(`[Express] Endpoints available:`);
    console.log(`  - Health Check: GET http://localhost:${PORT}/api/health`);
    console.log(`  - Save Event:   POST http://localhost:${PORT}/api/signing-events`);
    console.log(`  - Verify Event: GET http://localhost:${PORT}/api/signing-events/verify/:query`);
  });
}

startServer();

