-- =============================================================================
-- connection_monitor.sql
-- Active Connection Monitoring, Idle-in-Transaction Detection, Pool Usage
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

-- =============================================================================
-- 1. CONNECTION OVERVIEW — Summary by state
-- =============================================================================
SELECT
    state,
    COUNT(*) AS connection_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_total
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY state
ORDER BY connection_count DESC;

-- =============================================================================
-- 2. CONNECTIONS BY DATABASE AND USER
-- =============================================================================
SELECT
    datname AS database,
    usename AS username,
    client_addr AS client_ip,
    state,
    COUNT(*) AS connections,
    MAX(NOW() - backend_start) AS longest_connected,
    MAX(NOW() - state_change) AS longest_in_state
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY datname, usename, client_addr, state
ORDER BY connections DESC;

-- =============================================================================
-- 3. IDLE-IN-TRANSACTION SESSIONS (potential lock holders)
-- =============================================================================
SELECT
    pid,
    usename AS username,
    datname AS database,
    client_addr,
    application_name,
    state,
    NOW() - xact_start AS transaction_duration,
    NOW() - state_change AS idle_duration,
    LEFT(query, 200) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND NOW() - state_change > INTERVAL '5 minutes'
ORDER BY idle_duration DESC;

-- =============================================================================
-- 4. LONG-RUNNING ACTIVE QUERIES (> 30 seconds)
-- =============================================================================
SELECT
    pid,
    usename,
    datname,
    NOW() - query_start AS query_duration,
    state,
    wait_event_type,
    wait_event,
    LEFT(query, 300) AS query_text
FROM pg_stat_activity
WHERE state = 'active'
  AND NOW() - query_start > INTERVAL '30 seconds'
  AND pid <> pg_backend_pid()
ORDER BY query_duration DESC;

-- =============================================================================
-- 5. CONNECTION LIMIT STATUS (are we approaching max_connections?)
-- =============================================================================
SELECT
    current_setting('max_connections')::INT AS max_connections,
    (SELECT COUNT(*) FROM pg_stat_activity) AS current_connections,
    current_setting('max_connections')::INT - (SELECT COUNT(*) FROM pg_stat_activity) AS available_slots,
    ROUND(
        (SELECT COUNT(*) FROM pg_stat_activity)::NUMERIC /
        current_setting('max_connections')::NUMERIC * 100, 1
    ) AS utilization_pct;

-- =============================================================================
-- 6. CONNECTIONS BY APPLICATION NAME (identify connection pool behavior)
-- =============================================================================
SELECT
    application_name,
    COUNT(*) AS total_connections,
    COUNT(*) FILTER (WHERE state = 'active') AS active,
    COUNT(*) FILTER (WHERE state = 'idle') AS idle,
    COUNT(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_txn,
    MIN(backend_start) AS oldest_connection,
    MAX(backend_start) AS newest_connection
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY application_name
ORDER BY total_connections DESC;

-- =============================================================================
-- 7. TERMINATE PROBLEMATIC SESSIONS (use with caution)
-- =============================================================================

-- Cancel a query (graceful)
-- SELECT pg_cancel_backend(<pid>);

-- Terminate a session (forceful)
-- SELECT pg_terminate_backend(<pid>);

-- Terminate all idle-in-transaction sessions older than 10 minutes
-- SELECT pg_terminate_backend(pid)
-- FROM pg_stat_activity
-- WHERE state = 'idle in transaction'
--   AND NOW() - state_change > INTERVAL '10 minutes';
