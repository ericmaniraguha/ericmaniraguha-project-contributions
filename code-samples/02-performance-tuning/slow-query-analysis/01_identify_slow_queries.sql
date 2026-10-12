-- =============================================================================
-- 01_identify_slow_queries.sql
-- Using pg_stat_statements to Find the Most Expensive Queries
-- Target: PostgreSQL 15+ with pg_stat_statements extension
-- Author: Eric Maniraguha
-- =============================================================================

-- Ensure pg_stat_statements is enabled
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- =============================================================================
-- 1. TOP 20 SLOWEST QUERIES BY TOTAL EXECUTION TIME
-- =============================================================================
SELECT
    queryid,
    calls,
    ROUND(total_exec_time::NUMERIC, 2) AS total_time_ms,
    ROUND(mean_exec_time::NUMERIC, 2) AS avg_time_ms,
    ROUND(max_exec_time::NUMERIC, 2) AS max_time_ms,
    ROUND(min_exec_time::NUMERIC, 2) AS min_time_ms,
    ROUND(stddev_exec_time::NUMERIC, 2) AS stddev_ms,
    rows AS total_rows_returned,
    ROUND(rows::NUMERIC / GREATEST(calls, 1), 0) AS avg_rows_per_call,
    shared_blks_hit,
    shared_blks_read,
    CASE WHEN shared_blks_hit + shared_blks_read > 0
        THEN ROUND(shared_blks_hit::NUMERIC / (shared_blks_hit + shared_blks_read) * 100, 2)
        ELSE 100
    END AS cache_hit_pct,
    LEFT(query, 300) AS query_preview
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
ORDER BY total_exec_time DESC
LIMIT 20;

-- =============================================================================
-- 2. TOP 20 MOST FREQUENTLY CALLED QUERIES
-- =============================================================================
SELECT
    queryid,
    calls,
    ROUND(total_exec_time::NUMERIC, 2) AS total_time_ms,
    ROUND(mean_exec_time::NUMERIC, 2) AS avg_time_ms,
    rows AS total_rows,
    LEFT(query, 300) AS query_preview
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
ORDER BY calls DESC
LIMIT 20;

-- =============================================================================
-- 3. QUERIES WITH WORST CACHE HIT RATIO (I/O intensive)
-- =============================================================================
SELECT
    queryid,
    calls,
    shared_blks_hit,
    shared_blks_read,
    ROUND(shared_blks_hit::NUMERIC / GREATEST(shared_blks_hit + shared_blks_read, 1) * 100, 2) AS cache_hit_pct,
    ROUND(total_exec_time::NUMERIC, 2) AS total_time_ms,
    ROUND(mean_exec_time::NUMERIC, 2) AS avg_time_ms,
    LEFT(query, 300) AS query_preview
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
  AND shared_blks_hit + shared_blks_read > 100
  AND calls > 5
ORDER BY cache_hit_pct ASC
LIMIT 20;

-- =============================================================================
-- 4. QUERIES WITH HIGHEST TEMP FILE USAGE (memory pressure)
-- =============================================================================
SELECT
    queryid,
    calls,
    temp_blks_read,
    temp_blks_written,
    ROUND(total_exec_time::NUMERIC, 2) AS total_time_ms,
    ROUND(mean_exec_time::NUMERIC, 2) AS avg_time_ms,
    LEFT(query, 300) AS query_preview
FROM pg_stat_statements
WHERE temp_blks_read + temp_blks_written > 0
ORDER BY temp_blks_read + temp_blks_written DESC
LIMIT 20;

-- =============================================================================
-- 5. RESET STATISTICS (after baseline capture — use with caution)
-- =============================================================================
-- SELECT pg_stat_statements_reset();
