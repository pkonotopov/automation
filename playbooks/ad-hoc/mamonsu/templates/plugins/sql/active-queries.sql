--
-- Query:       Wait queries
-- Metric:      pgsql.pg_stat_activity.wait_queries[]
-- Metric name: PostgresSQL: pg_stat_activity wait queries
--
SELECT
    COALESCE(json_agg(_wait), '[]'::json)
FROM (
    SELECT
        CURRENT_TIMESTAMP - query_start AS runtime,
        datname,
        usename,
        wait_event,
        wait_event_type,
        query
    FROM
        pg_stat_activity
    WHERE
        state NOT IN ('idle')
    ORDER BY
        1 DESC) _wait;

--
-- Query:       Connections in not idle state
-- Metric:      pgsql.pg_stat_activity.active[]
-- Metric name: PostgresSQL: pg_stat_activity active queries
--
SELECT
    COALESCE(json_agg(_not_idle), '[]'::json)
FROM (
    SELECT
        *
    FROM
        pg_stat_activity
    WHERE
        state NOT IN ('idle')) _not_idle;

--
-- Query:       Connections count per database
-- Metric:      pgsql.pg_stat_activity.conn_count[]
-- Metric name: PostgresSQL: pg_stat_activity connections count per database
--
SELECT
    COALESCE(json_agg(_connections_count), '[]'::json)
FROM (
    SELECT
        datname,
        usename,
        state,
        COUNT(1)
    FROM
        pg_stat_activity
    GROUP BY
        datname,
        usename,
        state
    ORDER BY
        4 DESC) _connections_count;

--
-- Query:       Lock queries
-- Metric:      pgsql.pg_stat_activity.locked[]
-- Metric name: PostgresSQL: pg_stat_activity queries locked
--
SELECT
    COALESCE(json_agg(_locks), '[]'::json)
FROM (
    SELECT
        blocked_locks.pid AS blocked_pid,
        blocked_activity.usename AS blocked_user,
        blocked_activity.client_addr AS blocked_client_addr,
        blocked_activity.client_hostname AS blocked_client_hostname,
        blocked_activity.client_port AS blocked_client_port,
        blocked_activity.application_name AS blocked_application_name,
        blocked_activity.wait_event_type AS blocked_wait_event_type,
        blocked_activity.wait_event AS blocked_wait_event,
        blocked_activity.query AS blocked_statement,
        blocked_activity.xact_start AS blocked_xact_start,
        blocking_locks.pid AS blocking_pid,
        blocking_activity.usename AS blocking_user,
        blocking_activity.client_addr AS blocking_user_addr,
        blocking_activity.client_hostname AS blocking_client_hostname,
        blocking_activity.client_port AS blocking_client_port,
        blocking_activity.application_name AS blocking_application_name,
        blocking_activity.wait_event_type AS blocking_wait_event_type,
        blocking_activity.wait_event AS blocking_wait_event,
        blocking_activity.query AS current_statement_in_blocking_process,
        blocking_activity.xact_start AS blocking_xact_start
    FROM
        pg_catalog.pg_locks blocked_locks
        JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
        JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
            AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
            AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
            AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
            AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
            AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
            AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
            AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
            AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
            AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
            AND blocking_locks.pid != blocked_locks.pid
        JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
    WHERE
        NOT blocked_locks.granted
    ORDER BY
        blocked_activity.pid) _locks;

