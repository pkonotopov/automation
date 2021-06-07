-- 
-- extractions from pg_stat_statements
SELECT coalesce(json_agg(stats), '[]'::json)
FROM (
SELECT 
    round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 2)::float percent,
    round(total_exec_time) AS total,
    calls,
    round(mean_exec_time::numeric, 2)::float AS mean,
    lower(query) as query
FROM pg_stat_statements
where lower(query) not in ('begin','commit','end','rollback','set')
group by query, total_exec_time, calls,mean_exec_time
ORDER BY mean_exec_time DESC
LIMIT 50) stats;