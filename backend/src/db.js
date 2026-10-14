import mysql from 'mysql2/promise';
import dotenv from 'dotenv';

dotenv.config();

// Create connection pool for MySQL
export const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'esign_db',
  port: Number(process.env.DB_PORT) || 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

/// Automatically initializes the required table on startup
export async function initDatabase() {
  const createTableSql = `
    CREATE TABLE IF NOT EXISTS signing_events (
      id INT AUTO_INCREMENT PRIMARY KEY,
      signing_event_id VARCHAR(64) UNIQUE NOT NULL,
      document_hash VARCHAR(64) NOT NULL,
      signed_document_hash VARCHAR(64) NULL,
      document_title VARCHAR(255) NOT NULL,
      user_email VARCHAR(255) NOT NULL,
      user_id VARCHAR(128) NOT NULL,
      ip_address VARCHAR(64) NOT NULL,
      biometric_verification VARCHAR(128) NOT NULL,
      authentication_method VARCHAR(128) NOT NULL,
      signed_at DATETIME NOT NULL,
      status VARCHAR(32) DEFAULT 'COMPLETED',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_hash (document_hash),
      INDEX idx_signed_hash (signed_document_hash),
      INDEX idx_event_id (signing_event_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `;

  try {
    const conn = await pool.getConnection();
    await conn.query(createTableSql);
    conn.release();
    console.log('[MySQL] Database and `signing_events` table verified successfully.');
  } catch (err) {
    console.error('[MySQL] Database initialization error:', err.message);
    throw err;
  }
}
