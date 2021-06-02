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

