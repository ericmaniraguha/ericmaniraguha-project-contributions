-- =============================================================================
-- lock_investigation.sql
-- Lock Detection, Blocking Queries, and Deadlock Investigation
-- Target: PostgreSQL 15+
-- Author: Eric Maniraguha
-- =============================================================================

-- =============================================================================
-- 1. CURRENT LOCKS — Overview of all active locks
-- =============================================================================
SELECT
    l.locktype,
    l.mode,
    l.granted,
    l.pid,
    a.usename,
    a.application_name,
    a.client_addr,
    l.relation::regclass AS locked_table,
    a.state,
    NOW() - a.query_start AS query_duration,
    LEFT(a.query, 200) AS query_text
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.locktype = 'relation'
  AND a.pid <> pg_backend_pid()
ORDER BY l.granted, query_duration DESC;

-- =============================================================================
-- 2. BLOCKING AND BLOCKED QUERIES (who is waiting on whom?)
-- =============================================================================
SELECT
    blocked.pid AS blocked_pid,
    blocked.usename AS blocked_user,
    LEFT(blocked.query, 200) AS blocked_query,
    NOW() - blocked.query_start AS blocked_duration,
    blocking.pid AS blocking_pid,
    blocking.usename AS blocking_user,
    LEFT(blocking.query, 200) AS blocking_query,
    NOW() - blocking.query_start AS blocking_duration,
    blocking.state AS blocking_state
FROM pg_stat_activity blocked
JOIN pg_locks bl ON bl.pid = blocked.pid AND NOT bl.granted
JOIN pg_locks gl ON gl.pid <> blocked.pid
    AND gl.locktype = bl.locktype
    AND gl.database IS NOT DISTINCT FROM bl.database
    AND gl.relation IS NOT DISTINCT FROM bl.relation
    AND gl.page IS NOT DISTINCT FROM bl.page
    AND gl.tuple IS NOT DISTINCT FROM bl.tuple
    AND gl.virtualxid IS NOT DISTINCT FROM bl.virtualxid
    AND gl.transactionid IS NOT DISTINCT FROM bl.transactionid
    AND gl.classid IS NOT DISTINCT FROM bl.classid
    AND gl.objid IS NOT DISTINCT FROM bl.objid
    AND gl.objsubid IS NOT DISTINCT FROM bl.objsubid
    AND gl.granted
JOIN pg_stat_activity blocking ON blocking.pid = gl.pid
ORDER BY blocked_duration DESC;

-- =============================================================================
-- 3. LOCK WAIT TREE (hierarchical view of lock chains)
-- =============================================================================
WITH RECURSIVE lock_tree AS (
    -- Root: processes that are blocking others but are not themselves blocked
    SELECT
        gl.pid AS blocking_pid,
        NULL::INTEGER AS blocked_pid,
        a.usename,
        a.state,
        LEFT(a.query, 150) AS query_text,
        0 AS depth,
        ARRAY[gl.pid] AS path
    FROM pg_locks gl
    JOIN pg_stat_activity a ON a.pid = gl.pid
    WHERE gl.granted
      AND EXISTS (
          SELECT 1 FROM pg_locks bl
          WHERE NOT bl.granted
            AND bl.locktype = gl.locktype
            AND bl.relation IS NOT DISTINCT FROM gl.relation
      )
      AND NOT EXISTS (
          SELECT 1 FROM pg_locks wl
          WHERE wl.pid = gl.pid AND NOT wl.granted
      )

    UNION ALL

    -- Recursive: processes blocked by the ones above
    SELECT
        bl.pid AS blocking_pid,
        lt.blocking_pid AS blocked_by,
        a.usename,
        a.state,
        LEFT(a.query, 150) AS query_text,
        lt.depth + 1,
        lt.path || bl.pid
    FROM lock_tree lt
    JOIN pg_locks gl ON gl.pid = lt.blocking_pid AND gl.granted
    JOIN pg_locks bl ON NOT bl.granted
        AND bl.locktype = gl.locktype
        AND bl.relation IS NOT DISTINCT FROM gl.relation
        AND bl.pid <> lt.blocking_pid
    JOIN pg_stat_activity a ON a.pid = bl.pid
    WHERE NOT bl.pid = ANY(lt.path)  -- prevent cycles
)
SELECT
    REPEAT('  ', depth) || blocking_pid::TEXT AS process_tree,
    blocked_pid AS blocked_by,
    usename,
    state,
    query_text,
    depth
FROM lock_tree
ORDER BY path;

-- =============================================================================
-- 4. ADVISORY LOCKS (application-level locks)
-- =============================================================================
SELECT
    l.pid,
    a.usename,
    a.application_name,
    l.objid AS lock_id,
    l.granted,
    a.state,
    LEFT(a.query, 200) AS query_text
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.locktype = 'advisory'
ORDER BY l.granted, l.objid;

-- =============================================================================
-- 5. DEADLOCK DETECTION — Check PostgreSQL logs for recent deadlocks
-- =============================================================================

-- PostgreSQL logs deadlocks automatically. Query the log for patterns:
-- In pg_stat_activity, look for processes in 'idle in transaction (aborted)' state
SELECT
    pid,
    usename,
    datname,
    state,
    NOW() - xact_start AS transaction_age,
    LEFT(query, 200) AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction (aborted)'
ORDER BY transaction_age DESC;

-- =============================================================================
-- 6. TABLE-LEVEL LOCK SUMMARY
-- =============================================================================
SELECT
    c.relname AS table_name,
    l.mode AS lock_mode,
    COUNT(*) AS lock_count,
    COUNT(*) FILTER (WHERE l.granted) AS granted_count,
    COUNT(*) FILTER (WHERE NOT l.granted) AS waiting_count
FROM pg_locks l
JOIN pg_class c ON l.relation = c.oid
WHERE c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'app')
GROUP BY c.relname, l.mode
ORDER BY c.relname, l.mode;

-- =============================================================================
-- 7. RESOLVE: Terminate blocking sessions (use with caution)
-- =============================================================================

-- Terminate a specific blocking process
-- SELECT pg_terminate_backend(<blocking_pid>);

-- Terminate all sessions blocking others for more than 5 minutes
-- SELECT pg_terminate_backend(blocking.pid)
-- FROM pg_stat_activity blocked
-- JOIN pg_locks bl ON bl.pid = blocked.pid AND NOT bl.granted
-- JOIN pg_locks gl ON gl.granted
--     AND gl.locktype = bl.locktype
--     AND gl.relation IS NOT DISTINCT FROM bl.relation
-- JOIN pg_stat_activity blocking ON blocking.pid = gl.pid
-- WHERE NOW() - blocking.query_start > INTERVAL '5 minutes';
