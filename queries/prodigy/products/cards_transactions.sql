WITH base AS (
  SELECT
    DATE_FORMAT(th.date_actual,'%Y-%m') AS period,
    CASE
      WHEN th.tran_code LIKE 'DRWDA%' OR th.tran_code LIKE 'DRWDAC%' THEN 'ATM'
      WHEN th.tran_code LIKE 'DRWD%' THEN 'DEBIT'
      WHEN th.tran_code LIKE 'TLTC%' THEN 'CREDIT'
      ELSE 'OTHER'
    END AS general_card_type,
    th.transaction_history_id,
    th.member_id,
    th.account_id,
    ABS(th.total_amount) AS amt
  FROM transaction_history th
  WHERE th.date_actual >= '2025-01-01'
    AND (th.tran_code LIKE 'DRWD%' OR th.tran_code LIKE 'TLTC%')
)
SELECT
  period, general_card_type,
  COUNT(DISTINCT member_id)                 AS unique_members,
  COUNT(DISTINCT account_id)                AS unique_accounts,
  COUNT(*)                                  AS total_transactions,
  ROUND(AVG(amt), 2)                        AS avg_transaction_amount,
  ROUND(SUM(amt), 2)                        AS total_transaction_volume
FROM base
GROUP BY period, general_card_type
ORDER BY period DESC, general_card_type