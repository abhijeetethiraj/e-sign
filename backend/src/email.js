import nodemailer from 'nodemailer';
import dotenv from 'dotenv';

dotenv.config();

/**
 * Creates and returns a reusable Nodemailer SMTP transport instance
 * using Gmail App Password credentials configured in .env.
 */
function createTransporter() {
  dotenv.config();
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  if (!user || !pass) {
    return null;
  }

  return nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 465,
    secure: true,
    auth: {
      user: user.trim(),
      pass: pass.replace(/\s+/g, ''), // Remove any accidental spaces in app password
    },
  });
}

/**
 * Sends an official document completion email with PDF attachment.
 * 
 * @param {Object} options
 * @param {string} options.to - Recipient email address
 * @param {string} options.documentTitle - Name of the signed document
 * @param {string} options.signedAt - Formatted timestamp
 * @param {string} options.documentHash - SHA-256 cryptographic tamper hash
 * @param {string} options.signerIp - IP address of the signer
 * @param {string} [options.pdfBase64] - Optional base64 encoded signed PDF to attach
 */
export async function sendCompletionEmail({
  to,
  documentTitle,
  signedAt,
  documentHash,
  signerIp,
  pdfBase64,
}) {
  const transporter = createTransporter();

  if (!transporter) {
    console.log('[EmailService] SMTP_USER or SMTP_PASS not set in .env. Skipping automated email.');
    return { success: false, reason: 'SMTP credentials not configured in .env' };
  }

  const senderAddress = process.env.SMTP_USER;

  // Prepare attachments if PDF base64 data was supplied
  const attachments = [];
  if (pdfBase64) {
    const filename = documentTitle.endsWith('.pdf') ? documentTitle : `${documentTitle}.pdf`;
    attachments.push({
      filename: filename,
      content: Buffer.from(pdfBase64, 'base64'),
      contentType: 'application/pdf',
    });
  }

  const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f4f4f5; margin: 0; padding: 24px; color: #18181b; }
        .card { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 14px; overflow: hidden; border: 1px solid #e4e4e7; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }
        .header { background: #E9203B; padding: 28px 24px; color: #ffffff; text-align: center; }
        .header h1 { margin: 0 0 6px; font-size: 20px; font-weight: 700; letter-spacing: -0.3px; }
        .header p { margin: 0; font-size: 13px; opacity: 0.9; }
        .body { padding: 24px; font-size: 14px; line-height: 1.6; }
        .details-box { background: #f8fafc; border-radius: 10px; border: 1px solid #e2e8f0; padding: 16px; margin: 18px 0; }
        .row { display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 13px; }
        .row:last-child { margin-bottom: 0; }
        .label { color: #64748b; font-weight: 500; }
        .value { color: #0f172a; font-weight: 600; text-align: right; }
        .hash-code { font-family: monospace; font-size: 11px; word-break: break-all; background: #f1f5f9; padding: 8px; border-radius: 6px; color: #334155; margin-top: 6px; }
        .badge { display: inline-block; background: #dcfce7; color: #15803d; font-size: 12px; font-weight: 700; padding: 4px 10px; border-radius: 20px; }
        .footer { padding: 16px 24px; background: #f4f4f5; text-align: center; font-size: 11px; color: #71717a; border-top: 1px solid #e4e4e7; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="header">
          <h1>Document Completed & Cryptographically Sealed</h1>
          <p>eSign Platform • Official Execution Notice</p>
        </div>
        <div class="body">
          <p>Hello,</p>
          <p>All requested signatures for <strong>"${documentTitle}"</strong> have been successfully completed.</p>
          <p>A legally binding copy of your signed document has been attached to this email.</p>

          <div class="details-box">
            <div class="row">
              <span class="label">Document Name</span>
              <span class="value">${documentTitle}</span>
            </div>
            <div class="row">
              <span class="label">Signer Email</span>
              <span class="value">${to}</span>
            </div>
            <div class="row">
              <span class="label">Completed Date</span>
              <span class="value">${signedAt}</span>
            </div>
            <div class="row">
              <span class="label">Signer IP Address</span>
              <span class="value">${signerIp || '127.0.0.1'}</span>
            </div>
            <div class="row">
              <span class="label">Execution Status</span>
              <span class="badge">✓ VALID & UNTAMPERED</span>
            </div>
            <div style="margin-top: 12px;">
              <span class="label">Cryptographic SHA-256 Tamper Seal:</span>
              <div class="hash-code">${documentHash}</div>
            </div>
          </div>

          <p style="font-size: 12px; color: #64748b;">
            <strong>Tamper Evidence Notice:</strong> This document contains an embedded cryptographic digest. Any post-signing modifications to the attached PDF will invalidate its legal authenticity.
          </p>
        </div>
        <div class="footer">
          This is an automated legal notification sent by eSign Platform.<br>
          Please keep this copy for your records.
        </div>
      </div>
    </body>
    </html>
  `;

  try {
    const info = await transporter.sendMail({
      from: `"eSign Platform" <${senderAddress}>`,
      to: to,
      subject: `Completed: ${documentTitle} has been signed`,
      html: htmlContent,
      attachments: attachments,
    });

    console.log(`[EmailService] ✓ Successfully sent completion email to ${to}. MessageId: ${info.messageId}`);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error(`[EmailService] ✕ Error sending completion email to ${to}:`, error.message);
    return { success: false, error: error.message };
  }
}
