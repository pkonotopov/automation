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

