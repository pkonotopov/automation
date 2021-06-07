--
-- Use this for metric based approach to convert pg_stat_activity into Zabbix metrics
--

SELECT
    md5(query) AS id,
    query,
    datname,
    application_name,
    sum(extract(epoch FROM (now() - query_start))) AS duration,
    count(1) AS count,
    state
FROM
    pg_stat_activity
WHERE
    query !~* '^commit|^end|^begin|^show|^set|^$'
GROUP BY
    id,
    query,
    datname,
    application_name,
    state;

--
-- Dump pg_stat_statements to one-row-json
--
WITH statements AS (
    SELECT
        query,
        calls,
        ROUND(min_exec_time::numeric, 2)::bigint AS min_calls,
        ROUND(mean_exec_time::numeric, 2)::bigint AS avg_calls,
        ROUND(min_exec_time NUMERIC, 2)::bigint AS max_calls,
        ROUND(ROWS / calls)::bigint AS rows_ret,
        ROUND(total_exec_time::numeric, 2)::bigint AS total_time,
        ROUND((100 * total_exec_time / SUM(total_exec_time::numeric) OVER ())::numeric, 2)::bigint AS percentage_cpu
    FROM
        pg_stat_statements
    ORDER BY
        total_exec_time DESC
    LIMIT 50
)
SELECT
    coalesce(json_agg(statements), '[]'::json)
FROM
    statements;

--
-- Dump pg_stat_activity to one-row-json
--

WITH activity AS (
    SELECT
        row_number() OVER () AS id,
        datid::int,
        datname::text,
        pid::int,
        leader_pid::int,
        usesysid::text,
        usename::text,
        application_name::text,
        client_addr::text,
        client_hostname::text,
        client_port::int,
        backend_start::text,
        xact_start::text,
        query_start::text,
        state_change::text,
        wait_event_type::text,
        wait_event::text,
        state::text,
        backend_xid::text,
        backend_xmin::text,
        query::text,
        backend_type::text
    FROM
        pg_stat_activity
)
SELECT
    coalesce(json_agg(activity), '[]'::json)
FROM
    activity;

--
-- Grafana dasboard
--
-- pg_stat_activity metrics based dashboard
--
-- Zabbix 5.2
--

WITH duration AS (
    SELECT
        duration
    FROM (
        SELECT
            h.name,
            d.value AS duration,
            d.clock AS tm,
            row_number() OVER (PARTITION BY d.itemid ORDER BY d.clock DESC) AS rn
    FROM
        public.applications a
        INNER JOIN public.hosts h ON (a.hostid = h.hostid)
        INNER JOIN public.items_applications ia ON (a.applicationid = ia.applicationid)
        LEFT OUTER JOIN public.history d ON (ia.itemid = d.itemid)
    WHERE
        h.name = '$host'
        AND a.name = 'Postgres Stat Activity'
        AND d.value IS NOT NULL
        AND d.clock > EXTRACT(EPOCH FROM NOW()) - 10 * 60) y
    WHERE
        rn = 1
    ORDER BY
        name
),
query AS (
    SELECT
        query
    FROM (
        SELECT
            h.name,
            q.value AS query,
            q.clock AS tm,
            row_number() OVER (PARTITION BY q.itemid ORDER BY q.clock DESC) AS rn
        FROM
            public.applications a
            INNER JOIN public.hosts h ON (a.hostid = h.hostid)
            INNER JOIN public.items_applications ia ON (a.applicationid = ia.applicationid)
            LEFT OUTER JOIN public.history_text q ON (ia.itemid = q.itemid)
        WHERE
            h.name = '$host'
            AND a.name = 'Postgres Stat Activity'
            AND q.value IS NOT NULL
            AND q.clock > EXTRACT(EPOCH FROM NOW()) - 10 * 60) y
    WHERE
        rn = 1
    ORDER BY
        name
)
SELECT
    query,
    sum(duration) / count(duration) AS duration,
    count(query) AS cnt
FROM
    query,
    duration
GROUP BY
    query,
    duration
ORDER BY
    duration DESC;
LIMIT 50;

--
-- Zabbix 5.4
--

WITH query AS (
    SELECT
        query
    FROM (
        SELECT
            i.name,
            q.value AS query,
            q.clock AS tm,
            row_number() OVER (PARTITION BY i.name ORDER BY q.clock DESC) AS rn
    FROM
        items i
        INNER JOIN hosts h ON i.hostid = h.hostid
        INNER JOIN item_tag t ON t.itemid = i.itemid
        INNER JOIN history_text q ON i.itemid = q.itemid
    WHERE
        h.name = '$host'
        AND t.tag = 'Application'
        AND t.value = 'Postgres Stat Activity'
        AND q.clock > EXTRACT(EPOCH FROM NOW()) - 10 * 60) y
    WHERE
        rn = 1
    ORDER BY
        name
),
duration AS (
    SELECT
        duration
    FROM (
        SELECT
            i.name,
            d.value AS duration,
            d.clock AS tm,
            row_number() OVER (PARTITION BY i.name ORDER BY d.clock DESC) AS rn
        FROM
            items i
            INNER JOIN hosts h ON i.hostid = h.hostid
            INNER JOIN item_tag t ON t.itemid = i.itemid
            INNER JOIN history d ON i.itemid = d.itemid
        WHERE
            h.name = '$host'
            AND t.tag = 'Application'
            AND t.value = 'Postgres Stat Activity'
            AND d.clock > EXTRACT(EPOCH FROM NOW()) - 10 * 60) y
    WHERE
        rn = 1
    ORDER BY
        name
)
SELECT
    query,
    sum(duration) / count(duration) AS duration,
    count(query) AS cnt
FROM
    query,
    duration
GROUP BY
    query,
    duration
ORDER BY
    duration DESC
LIMIT 50;

--
-- pg_stat_activity JSON based dashboard
-- 

SELECT 
   query::text, 
   extract(epoch from(now() - ((query_start::text)::timestamptz))) as duration
   FROM (
SELECT 
   jsonb_path_query(data::jsonb, '$[*].query ? ( (@ != "") && ( (@starts with "select") || (@starts with "with") || (@starts with "update") || (@starts with "delete") || (@starts with "insert") || (@starts with "drop") || (@starts with "create") ) )') as query,
   jsonb_path_query(data::jsonb, '$[*].query_start ? (@ != null)') as query_start,
   jsonb_path_query(data::jsonb, '$[*].datname ? (@ != "")') as datname
FROM (
  SELECT 
    lower(q.value) as data
  FROM 
    public.items i 
  INNER JOIN public.hosts h
  ON
    (
      h.hostid = i.hostid )
  INNER JOIN 
    public.history_text q
  ON 
    ( 
        i.itemid = q.itemid) 
  WHERE 
    h.name = '$host'
    AND i.name = 'PostgreSQL: pg_stat_activity dump'
    AND q.clock > EXTRACT(EPOCH FROM NOW()) - 10 * 60
  ORDER BY q.clock DESC LIMIT 1) j) u
  WHERE query is not null
  AND datname::text ~ '$database'
  order by duration desc LIMIT $limit;


--
-- pg_stat_statements JSON based dashboard
--

SELECT 
   query::text,
   calls::bigint, 
   minimum::bigint,
   maximum::bigint,
   average::bigint,
   rows_returned::bigint,
   total::bigint,
   cpu::bigint
   FROM (
SELECT 
   jsonb_path_query(data::jsonb, '$[*].query ? ( (@ != "") && ( (@starts with "select") || (@starts with "with") || (@starts with "update") || (@starts with "delete") || (@starts with "insert") || (@starts with "drop") || (@starts with "create") ) )') as query,
   jsonb_path_query(data::jsonb, '$[*].calls ? (@ != null)') as calls,
   jsonb_path_query(data::jsonb, '$[*].min_calls ? (@ != null)') as minimum,
   jsonb_path_query(data::jsonb, '$[*].avg_calls ? (@ != null)') as average,
   jsonb_path_query(data::jsonb, '$[*].max_calls ? (@ != null)') as maximum,
   jsonb_path_query(data::jsonb, '$[*].rows_ret ? (@ != null)') as rows_returned,
   jsonb_path_query(data::jsonb, '$[*].total_time ? (@ != null)') as total,
   jsonb_path_query(data::jsonb, '$[*].percentage_cpu ? (@ != null)') as cpu
FROM (
  SELECT 
    lower(q.value) as data
  FROM 
    public.items i 
  INNER JOIN public.hosts h
  ON
    (
      h.hostid = i.hostid )
  INNER JOIN 
    public.history_text q
  ON 
    ( 
        i.itemid = q.itemid) 
  WHERE 
    h.name = '$host'
    AND i.name = 'PostgreSQL: pg_stat_statements dump'
    AND q.clock > EXTRACT(EPOCH FROM NOW()) - 10 * 60
  ORDER BY q.clock DESC LIMIT 1) j) u
  WHERE query is not null
  order by calls desc LIMIT $limit;
