SELECT 
   query,
   calls, 
   average,
   rows_returned,
   total,
   cpu
   FROM (
SELECT 
   jsonb_path_query(data::jsonb, '$[*].query ? ( (@ != "") && ( (@starts with "select") || (@starts with "with") || (@starts with "update") || (@starts with "delete") || (@starts with "insert") || (@starts with "drop") || (@starts with "create") ) )') as query,
   jsonb_path_query(data::jsonb, '$[*].calls ? (@ != null)') as calls,
   jsonb_path_query(data::jsonb, '$[*]._avg ? (@ != null)') as average,
   jsonb_path_query(data::jsonb, '$[*]._rows ? (@ != null)') as rows_returned,
   jsonb_path_query(data::jsonb, '$[*]._time ? (@ != null)') as total,
   jsonb_path_query(data::jsonb, '$[*]._cpu ? (@ != null)') as cpu
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
  order by cpu desc LIMIT $limit
  ;