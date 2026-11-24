import { Pool, PoolClient, QueryResult } from 'pg';
import { env } from './env';

// Initialize PostgreSQL Pool configured for Neon (SSL enabled)
const poolConfig = env.db.connectionString
  ? {
      connectionString: env.db.connectionString,
      ssl: {
        rejectUnauthorized: false,
      },
    }
  : {
      host: env.db.host,
      port: env.db.port,
      user: env.db.user,
      password: env.db.password,
      database: env.db.database,
      ssl: env.db.ssl ? { rejectUnauthorized: false } : undefined,
    };

export const pgPool = new Pool(poolConfig);

/**
 * Preprocesses MySQL-specific syntax to PostgreSQL:
 * 1. Backticks `table` -> table
 * 2. CURDATE() -> CURRENT_DATE
 * 3. DATE_SUB(date, INTERVAL n DAY) -> (date - INTERVAL 'n DAY')
 * 4. SUBSTRING_INDEX(str, delim, 1) -> split_part(str, delim, 1)
 * 5. Replaces '?' parameter placeholders with '$1', '$2', ...
 */
export function preprocessSql(sql: string): string {
  let transformed = sql
    // Backticks to unquoted (PostgreSQL standard lowercase)
    .replace(/`([a-zA-Z0-9_]+)`/g, '$1')
    // CURDATE() -> CURRENT_DATE
    .replace(/\bCURDATE\(\)/gi, 'CURRENT_DATE')
    // DATE_SUB(date, INTERVAL n DAY)
    .replace(/\bDATE_SUB\s*\(\s*([^,]+)\s*,\s*INTERVAL\s+(\d+)\s+DAY\s*\)/gi, "($1 - INTERVAL '$2 DAY')")
    // SUBSTRING_INDEX(str, delim, 1) -> split_part(str, delim, 1)
    .replace(/\bSUBSTRING_INDEX\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*1\s*\)/gi, 'split_part($1, $2, 1)');

  // Convert unquoted '?' to positional '$1', '$2', ...
  let paramIndex = 1;
  let inSingleQuote = false;
  let inDoubleQuote = false;
  let inEscape = false;
  let result = '';

  for (let i = 0; i < transformed.length; i++) {
    const char = transformed[i];

    if (inEscape) {
      result += char;
      inEscape = false;
      continue;
    }

    if (char === '\\') {
      result += char;
      inEscape = true;
      continue;
    }

    if (char === "'" && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote;
      result += char;
      continue;
    }

    if (char === '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
      result += char;
      continue;
    }

    if (char === '?' && !inSingleQuote && !inDoubleQuote) {
      result += `$${paramIndex++}`;
    } else {
      result += char;
    }
  }

  return result;
}

/**
 * Executes a PostgreSQL query and formats the return value to match MySQL2 style:
 * Returns [rows, fields], where rows also carries .affectedRows for ResultSetHeader compatibility.
 */
async function executePgQuery<T = any>(
  executor: Pool | PoolClient,
  sql: string,
  params?: any[]
): Promise<[T, any]> {
  const preparedSql = preprocessSql(sql);
  const normalizedParams = params && params.length > 0 ? params : undefined;

  const res: QueryResult = await executor.query(preparedSql, normalizedParams);

  const rows: any = res.rows || [];
  rows.affectedRows = res.rowCount ?? 0;
  rows.insertId = 0;
  rows.rowCount = res.rowCount ?? 0;

  return [rows as T, res.fields];
}

export class PgConnectionAdapter {
  constructor(public client: PoolClient) {}

  async query<T = any>(sql: string, params?: any[]): Promise<[T, any]> {
    return executePgQuery<T>(this.client, sql, params);
  }

  async execute<T = any>(sql: string, params?: any[]): Promise<[T, any]> {
    return this.query<T>(sql, params);
  }

  async beginTransaction(): Promise<void> {
    await this.client.query('BEGIN');
  }

  async commit(): Promise<void> {
    await this.client.query('COMMIT');
  }

  async rollback(): Promise<void> {
    await this.client.query('ROLLBACK');
  }

  release(): void {
    this.client.release();
  }
}

/**
 * MySQL2-compatible database pool adapter running on top of PostgreSQL / Neon.
 */
export const dbPool = {
  async query<T = any>(sql: string, params?: any[]): Promise<[T, any]> {
    return executePgQuery<T>(pgPool, sql, params);
  },

  async execute<T = any>(sql: string, params?: any[]): Promise<[T, any]> {
    return this.query<T>(sql, params);
  },

  async getConnection(): Promise<PgConnectionAdapter> {
    const client = await pgPool.connect();
    return new PgConnectionAdapter(client);
  },

  async end(): Promise<void> {
    await pgPool.end();
  },
};

/**
 * Verifies database connectivity by executing a lightweight ping query on Neon.
 */
export async function testDbConnection(): Promise<boolean> {
  const client = await pgPool.connect();
  try {
    await client.query('SELECT 1');
    return true;
  } finally {
    client.release();
  }
}
