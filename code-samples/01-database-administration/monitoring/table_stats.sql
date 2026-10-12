-- =============================================================================
-- table_stats.sql
-- Table Bloat, Dead Tuples, Autovacuum Statistics, and Storage Analysis
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

-- =============================================================================
-- 1. TABLE SIZE AND ROW COUNTS
-- =============================================================================
SELECT
    schemaname,
    relname AS table_name,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    CASE WHEN n_live_tup > 0
        THEN ROUND(n_dead_tup::NUMERIC / n_live_tup * 100, 2)
        ELSE 0
    END AS dead_pct,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || relname)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname || '.' || relname)) AS table_size,
    pg_size_pretty(pg_indexes_size(schemaname || '.' || relname)) AS indexes_size
FROM pg_stat_user_tables
WHERE schemaname IN ('app', 'audit', 'analytics')
ORDER BY pg_total_relation_size(schemaname || '.' || relname) DESC;

-- =============================================================================
-- 2. AUTOVACUUM STATUS — Last vacuum/analyze dates
-- =============================================================================
SELECT
    schemaname,
    relname AS table_name,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze,
    vacuum_count,
    autovacuum_count,
    analyze_count,
    autoanalyze_count
FROM pg_stat_user_tables
WHERE schemaname IN ('app', 'audit')
ORDER BY n_dead_tup DESC;

-- =============================================================================
-- 3. TABLES NEEDING VACUUM (dead tuples > threshold)
-- =============================================================================
SELECT
    schemaname || '.' || relname AS table_full_name,
    n_live_tup,
    n_dead_tup,
    ROUND(n_dead_tup::NUMERIC / GREATEST(n_live_tup, 1) * 100, 2) AS dead_pct,
    last_autovacuum,
    EXTRACT(HOURS FROM NOW() - last_autovacuum) AS hours_since_vacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
   OR (n_live_tup > 0 AND n_dead_tup::NUMERIC / n_live_tup > 0.1)
ORDER BY dead_pct DESC;

-- =============================================================================
-- 4. TABLE BLOAT ESTIMATION
-- =============================================================================
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_relation_size(schemaname || '.' || tablename)) AS table_size,
    pg_size_pretty(
        pg_relation_size(schemaname || '.' || tablename) -
        (reltuples * (
            SELECT SUM(avg_width) + 24
            FROM pg_stats
            WHERE pg_stats.schemaname = t.schemaname
              AND pg_stats.tablename = t.tablename
        ))::BIGINT
    ) AS estimated_bloat
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'app'
  AND c.reltuples > 100
ORDER BY pg_relation_size(schemaname || '.' || tablename) DESC;

-- =============================================================================
-- 5. INDEX USAGE STATISTICS — Find unused indexes
-- =============================================================================
SELECT
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan AS times_used,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    CASE WHEN idx_scan = 0 THEN '⚠️ UNUSED' ELSE '✅ ACTIVE' END AS status
FROM pg_stat_user_indexes
WHERE schemaname = 'app'
ORDER BY idx_scan ASC, pg_relation_size(indexrelid) DESC;

-- =============================================================================
-- 6. SEQUENTIAL SCANS vs INDEX SCANS (potential missing indexes)
-- =============================================================================
SELECT
    schemaname,
    relname AS table_name,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    CASE
        WHEN seq_scan > 0 AND idx_scan > 0
        THEN ROUND(idx_scan::NUMERIC / (seq_scan + idx_scan) * 100, 1)
        ELSE 0
    END AS index_usage_pct,
    n_live_tup AS row_count
FROM pg_stat_user_tables
WHERE schemaname = 'app'
  AND n_live_tup > 100
ORDER BY seq_scan DESC;

-- =============================================================================
-- 7. TOAST TABLE SIZES (large object storage)
-- =============================================================================
SELECT
    c.relname AS table_name,
    pg_size_pretty(pg_relation_size(c.oid)) AS table_size,
    pg_size_pretty(pg_relation_size(c.reltoastrelid)) AS toast_size,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'app'
  AND c.relkind = 'r'
  AND c.reltoastrelid > 0
ORDER BY pg_relation_size(c.reltoastrelid) DESC;
