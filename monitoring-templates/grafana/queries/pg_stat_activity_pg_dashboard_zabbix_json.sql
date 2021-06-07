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
