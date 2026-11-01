-- Relatório de equilíbrio real (SDD-fase-5 4.4): vitórias, duração e rally por modo e nível.
SELECT json_extract(body, '$.mode') AS mode,
       json_extract(body, '$.level') AS level,
       COUNT(*) AS matches,
       ROUND(AVG(json_extract(body, '$.won')) * 100, 1) AS win_pct,
       ROUND(AVG(json_extract(body, '$.duration_s')) / 60.0, 1) AS minutes,
       ROUND(AVG(json_extract(body, '$.rally_avg')), 1) AS rally_avg,
       ROUND(AVG(json_extract(body, '$.perfect_rate')) * 100, 1) AS perfect_pct
FROM events
WHERE event = 'match_end'
GROUP BY mode, level
ORDER BY mode, level;
