-- =============================================================================
-- database_statistics.sql
-- Cache Hit Ratios, pg_stat_user_tables, and Index Efficiency Metrics
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

-- =============================================================================
-- 1. BUFFER CACHE HIT RATIO (should be > 99% in production)
-- =============================================================================
SELECT
    'Buffer Cache' AS metric,
    SUM(blks_hit) AS cache_hits,
    SUM(blks_read) AS disk_reads,
    SUM(blks_hit) + SUM(blks_read) AS total_requests,
    ROUND(
        SUM(blks_hit)::NUMERIC / NULLIF(SUM(blks_hit) + SUM(blks_read), 0) * 100, 2
    ) AS hit_ratio_pct,
    CASE
        WHEN SUM(blks_hit)::NUMERIC / NULLIF(SUM(blks_hit) + SUM(blks_read), 0) > 0.99
        THEN '✅ Excellent'
        WHEN SUM(blks_hit)::NUMERIC / NULLIF(SUM(blks_hit) + SUM(blks_read), 0) > 0.95
        THEN '🔶 Acceptable'
        ELSE '🔴 Needs Attention — increase shared_buffers'
    END AS assessment
FROM pg_stat_database
WHERE datname = current_database();

-- =============================================================================
-- 2. INDEX HIT RATIO (should be > 95%)
-- =============================================================================
SELECT
    'Index Cache' AS metric,
    SUM(idx_blks_hit) AS index_cache_hits,
    SUM(idx_blks_read) AS index_disk_reads,
    ROUND(
        SUM(idx_blks_hit)::NUMERIC /
        NULLIF(SUM(idx_blks_hit) + SUM(idx_blks_read), 0) * 100, 2
    ) AS index_hit_ratio_pct
FROM pg_statio_user_indexes;

-- =============================================================================
-- 3. TABLE I/O STATISTICS (identify tables with high disk reads)
-- =============================================================================
SELECT
    schemaname,
    relname AS table_name,
    heap_blks_hit AS table_cache_hits,
    heap_blks_read AS table_disk_reads,
    ROUND(
        heap_blks_hit::NUMERIC /
        NULLIF(heap_blks_hit + heap_blks_read, 0) * 100, 2
    ) AS table_hit_ratio_pct,
    idx_blks_hit AS index_cache_hits,
    idx_blks_read AS index_disk_reads,
    toast_blks_hit + toast_blks_read AS toast_io_total
FROM pg_statio_user_tables
WHERE schemaname = 'app'
ORDER BY heap_blks_read DESC;

-- =============================================================================
-- 4. DATABASE-LEVEL STATISTICS
-- =============================================================================
SELECT
    datname,
    numbackends AS active_connections,
    xact_commit AS transactions_committed,
    xact_rollback AS transactions_rolled_back,
    ROUND(
        xact_rollback::NUMERIC / NULLIF(xact_commit + xact_rollback, 0) * 100, 2
    ) AS rollback_pct,
    blks_read AS disk_blocks_read,
    blks_hit AS cache_blocks_hit,
    tup_returned AS rows_returned,
    tup_fetched AS rows_fetched,
    tup_inserted AS rows_inserted,
    tup_updated AS rows_updated,
    tup_deleted AS rows_deleted,
    conflicts,
    temp_files AS temp_files_created,
    pg_size_pretty(temp_bytes) AS temp_bytes_used,
    deadlocks,
    stats_reset AS last_stats_reset
FROM pg_stat_database
WHERE datname = current_database();

-- =============================================================================
-- 5. TABLE ACCESS PATTERNS (reads vs writes)
-- =============================================================================
SELECT
    schemaname,
    relname AS table_name,
    n_tup_ins AS inserts,
    n_tup_upd AS updates,
    n_tup_del AS deletes,
    n_tup_hot_upd AS hot_updates,
    CASE WHEN n_tup_upd > 0
        THEN ROUND(n_tup_hot_upd::NUMERIC / n_tup_upd * 100, 2)
        ELSE 0
    END AS hot_update_pct,
    seq_scan,
    idx_scan,
    CASE WHEN seq_scan + idx_scan > 0
        THEN ROUND(idx_scan::NUMERIC / (seq_scan + idx_scan) * 100, 2)
        ELSE 0
    END AS index_usage_pct
FROM pg_stat_user_tables
WHERE schemaname = 'app'
ORDER BY n_tup_ins + n_tup_upd + n_tup_del DESC;

-- =============================================================================
-- 6. CHECKPOINT AND WAL STATISTICS
-- =============================================================================
SELECT
    checkpoints_timed,
    checkpoints_req AS checkpoints_requested,
    checkpoint_write_time AS write_time_ms,
    checkpoint_sync_time AS sync_time_ms,
    buffers_checkpoint AS buffers_at_checkpoint,
    buffers_clean AS buffers_by_bgwriter,
    buffers_backend AS buffers_by_backends,
    ROUND(
        buffers_backend::NUMERIC /
        NULLIF(buffers_checkpoint + buffers_clean + buffers_backend, 0) * 100, 2
    ) AS backend_write_pct,
    stats_reset
FROM pg_stat_bgwriter;

-- =============================================================================
-- 7. CONFIGURATION PARAMETERS RELEVANT TO PERFORMANCE
-- =============================================================================
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN (
    'shared_buffers', 'effective_cache_size', 'work_mem',
    'maintenance_work_mem', 'max_connections', 'max_parallel_workers',
    'max_parallel_workers_per_gather', 'random_page_cost',
    'effective_io_concurrency', 'wal_buffers', 'checkpoint_completion_target',
    'default_statistics_target', 'statement_timeout',
    'idle_in_transaction_session_timeout', 'log_min_duration_statement'
)
ORDER BY name;
