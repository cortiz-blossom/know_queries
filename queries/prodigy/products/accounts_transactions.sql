WITH tx_monthly AS (
  SELECT
      th.account_id,
      STR_TO_DATE(DATE_FORMAT(th.date_effective, '%Y-%m-01'), '%Y-%m-%d') AS month_start,

  	  /* Conteo único de transacciones */
      COUNT(DISTINCT th.transaction_history_id) AS Transactions,

      /* Conteo único de depósitos */
      COUNT(DISTINCT CASE WHEN th.total_amount > 0 THEN th.transaction_history_id END) AS Deposits,

      /* Conteo único de retiros */
      COUNT(DISTINCT CASE WHEN th.total_amount < 0 THEN th.transaction_history_id END) AS Withdrawals,

      ROUND(SUM(CASE WHEN th.total_amount > 0 THEN th.total_amount ELSE 0 END), 2)      AS total_credits,
      ROUND(SUM(CASE WHEN th.total_amount < 0 THEN ABS(th.total_amount) ELSE 0 END), 2) AS total_debits,
      ROUND(SUM(th.total_amount), 2) AS net_change_for_month
  FROM transaction_history th
  WHERE th.void_flag = 0
    AND YEAR(th.date_effective) = YEAR(CURDATE())   -- 🔹 solo datos del año actual
  GROUP BY th.account_id, STR_TO_DATE(DATE_FORMAT(th.date_effective, '%Y-%m-01'), '%Y-%m-%d')
),
tx_with_suffix AS (
  SELECT
      t.*,
      SUM(t.net_change_for_month)
        OVER (PARTITION BY t.account_id ORDER BY t.month_start
              ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS net_change_from_this_month_forward
  FROM tx_monthly t
)
SELECT
    DATE_FORMAT(t.month_start, '%Y-%m') AS month_year,
    a.account_number,
    a.member_number,
    CASE a.discriminator
        WHEN 'S' THEN 'SAVINGS'
        WHEN 'D' THEN 'CHECKING'
        WHEN 'C' THEN 'CERTIFICATES'
        WHEN 'L' THEN 'LOANS'
        WHEN 'U' THEN 'SPECIAL'
        ELSE 'OTHER'
    END AS account_category,
    a.account_type,
    a.current_balance,

    /* métricas finales */
    t.Transactions,
    t.Deposits,
    t.Withdrawals,
    t.total_credits,
    t.total_debits,
    t.net_change_for_month,

    /* beginning balance aproximado */
    ROUND(a.current_balance - COALESCE(t.net_change_from_this_month_forward, 0), 2) AS approximate_beginning_balance,

    CASE WHEN t.Transactions > 0 THEN 'Active' ELSE 'Inactive' END AS activity_status

FROM tx_with_suffix t
JOIN account a
  ON a.account_id = t.account_id
WHERE a.member_number > 0
  AND a.discriminator IN ('S','D','C','U')
ORDER BY month_year DESC, account_category, a.account_number