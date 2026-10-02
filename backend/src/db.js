import pg from 'pg';

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL || 'postgres://shadowing:shadowing@localhost:5434/shadowing',
});

export const query = (text, params) => pool.query(text, params);
