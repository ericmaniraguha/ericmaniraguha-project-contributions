# 02 — Performance Tuning

> Slow-query identification, EXPLAIN ANALYZE analysis, index optimization, advanced SQL with CTEs and window functions.

---

## 📋 Contents

### `slow-query-analysis/` — End-to-End Tuning Case Study
A complete performance tuning workflow: identify → analyze → optimize → verify.

| File | Description |
|:-----|:------------|
| `01_identify_slow_queries.sql` | pg_stat_statements: find the costliest queries |
| `02_explain_analyze_before.sql` | EXPLAIN ANALYZE of unoptimized query showing sequential scans |
| `03_index_improvements.sql` | Targeted index creation based on execution plan analysis |
| `04_query_rewrite.sql` | Optimized query version with structural improvements |
| `05_explain_analyze_after.sql` | EXPLAIN ANALYZE confirming performance improvement |

### `cte-window-functions/` — Advanced SQL
| File | Description |
|:-----|:------------|
| `advanced_ctes.sql` | Recursive CTEs, data generation, hierarchical queries |
| `window_functions.sql` | ROW_NUMBER, RANK, LEAD/LAG, running totals, moving averages |

### `statistics/` — Database Statistics
| File | Description |
|:-----|:------------|
| `database_statistics.sql` | Cache hit ratios, pg_stat_user_tables, index efficiency |

---

## 📊 Tuning Results Summary

| Metric | Before Optimization | After Optimization | Improvement |
|:-------|:--------------------|:-------------------|:------------|
| Monthly revenue report | 4,200 ms (Seq Scan) | 45 ms (Index Scan) | **93x faster** |
| Customer search by name | 1,800 ms (Seq Scan) | 12 ms (GIN Trigram) | **150x faster** |
| Failed transaction report | 890 ms (full scan) | 28 ms (Partial Index) | **32x faster** |
| Top customers ranking | 3,100 ms (Sort + Agg) | 180 ms (CTE + Index) | **17x faster** |

---

## 🔗 Related Sections
- Schema design and indexes: [01-database-administration](../01-database-administration/)
- Applied on client work: [Upanzi Mojaloop reporting optimization](../../case-studies/Upanzi-Mojaloop/)
- ⬅️ [Back to portfolio overview](../../README.md)
