select 
    tm,
    query::text,
    extract(epoch from(now() - (query_start::text)::timestamptz)) as duration
-- Parse JSON
from (
SELECT
    tm,
    jsonb_path_query(datax::jsonb, '$[*].query ? ( (@ !="")  && ( (@starts with "select") || (@starts with "with") || (@starts with "update") || (@starts with "delete") || (@starts with "insert") || (@starts with "drop") || (@starts with "create") ) )') as query,
    jsonb_path_query(datax::jsonb, '$[*].query_start ? (@ != null)') as query_start,
    jsonb_path_query(datax::jsonb, '$[*].datname ? (@ != "")') as datname
    FROM
        -- get 1 row in JSON format from Zabbix history_text table
        (SELECT 
            q.clock as tm,
            lower(q.value) as datax
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
            h.name = 'Zabbix server'
            AND i.name = 'PostgreSQL: pg_stat_activity dump'
--            AND $__unixEpochFilter(q.clock)
            AND q.clock > EXTRACT(EPOCH FROM NOW()) - 10 * 60
        order by q.clock desc
        LIMIT 1) z ) x
--where $__unixEpochFilter(tm)
--AND datname::text ~ '$database'
where query != 'null'
order by duration desc;