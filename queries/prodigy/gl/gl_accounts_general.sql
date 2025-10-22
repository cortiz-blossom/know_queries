WITH RECURSIVE months AS (
  /* Primer día de cada mes desde 2022-01-01 hasta el mes actual */
  SELECT DATE('2022-01-01') AS period_start
  UNION ALL
  SELECT DATE_ADD(period_start, INTERVAL 1 MONTH)
  FROM months
  WHERE period_start < DATE(DATE_FORMAT(CURDATE(), '%Y-%m-01'))
),
acct AS (
  SELECT
      CAST(g.account_number AS CHAR) as account_number,
      g.description,
      g.short_desc,
      g.account_type,
      g.inactive,
      g.created_timestamp,
      g.modified_timestamp,
      g.restricted,
      g.controlled,
      g.modified_by_userid,
      g.balance AS current_balance_from_coa
  FROM gl_chart_of_accounts g
  WHERE g.account_type IN ('B','I')
),
/* Agrega por cuenta / mes */
monthly_stats AS (
  SELECT
      CAST(h.gl_account_number AS CHAR) AS account_number,
      /* Primer día del mes de effective_date (tipo DATE) */
      DATE(CONCAT(YEAR(h.effective_date), '-', LPAD(MONTH(h.effective_date), 2, '0'), '-01')) AS period_start,
      COUNT(*) AS transaction_count,
      SUM(CASE WHEN h.amount < 0 THEN -h.amount ELSE 0 END) AS total_debits,
      SUM(CASE WHEN h.amount > 0 THEN  h.amount ELSE 0 END) AS total_credits,
      SUM(h.amount) AS net_activity,
      SUM(ABS(h.amount)) AS total_amount
  FROM gl_history h
  WHERE h.effective_date >= '2022-01-01'
  GROUP BY h.gl_account_number,
           DATE(CONCAT(YEAR(h.effective_date), '-', LPAD(MONTH(h.effective_date), 2, '0'), '-01'))
),
/* Grid cuentas x meses SOLO últimos 36 meses */
grid AS (
  SELECT
      a.account_number,
      m.period_start
  FROM acct a
  JOIN months m
    ON m.period_start >= DATE_SUB(DATE(DATE_FORMAT(CURDATE(), '%Y-%m-01')), INTERVAL 36 MONTH)
),
/* Mezcla grid con stats (rellena ceros) */
stats AS (
  SELECT
      g.account_number,
      g.period_start,
      COALESCE(ms.transaction_count, 0)  AS monthly_transactions,
      COALESCE(ms.total_debits, 0.00)    AS monthly_debits,
      COALESCE(ms.total_credits, 0.00)   AS monthly_credits,
      COALESCE(ms.net_activity, 0.00)    AS monthly_net_activity,
      COALESCE(ms.total_amount, 0.00)    AS monthly_total_amount
  FROM grid g
  LEFT JOIN monthly_stats ms
    ON ms.account_number = g.account_number
   AND ms.period_start  = g.period_start
),
/* Saldo acumulado por cuenta con ventana (SIN anidar ventanas) */
running AS (
  SELECT
      s.*,
      SUM(s.monthly_net_activity)
        OVER (PARTITION BY s.account_number
              ORDER BY s.period_start
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS calculated_balance
  FROM stats s
)
SELECT
    /* Time Period Information */
    r.period_start AS Period_Date,
    DATE_FORMAT(r.period_start, '%Y-%m') AS Period_Year_Month,
    YEAR(r.period_start)  AS Year,
    MONTH(r.period_start) AS Month,
    MONTHNAME(r.period_start) AS Month_Name,

    /* Account Identification */
    a.account_number AS GL_ID,
    a.description    AS GL_Name,
    a.short_desc     AS Short_Description,

    /* GL Category */
    CASE 
      WHEN a.account_type = 'B' THEN 'Balance Sheet'
      WHEN a.account_type = 'I' THEN 'Income Statement'
      ELSE 'Other'
    END AS GL_Category,

    /* Subcategoría (usa calculated_balance) */
    CASE 
      WHEN a.account_type = 'B' AND a.account_number BETWEEN 701 AND 799 AND r.calculated_balance > 0 THEN 'ASSETS - Loans to Members'
      WHEN a.account_type = 'B' AND a.account_number BETWEEN 740 AND 750 AND r.calculated_balance > 0 THEN 'ASSETS - Investments'
      WHEN a.account_type = 'B' AND a.account_number BETWEEN 770 AND 780 AND r.calculated_balance > 0 THEN 'ASSETS - Property & Equipment'
      WHEN a.account_type = 'B' AND a.account_number BETWEEN 700 AND 799 AND r.calculated_balance < 0 THEN 'CONTRA-ASSETS - Allowances/Provisions'
      WHEN a.account_type = 'B' AND a.account_number BETWEEN 800 AND 899 AND r.calculated_balance < 0 THEN 'LIABILITIES - Accounts Payable'
      WHEN a.account_type = 'B' AND a.account_number BETWEEN 900 AND 989 AND r.calculated_balance < 0 THEN 'LIABILITIES - Member Deposits'
      WHEN a.account_type = 'B' AND a.account_number BETWEEN 990 AND 999 AND r.calculated_balance < 0 THEN 'EQUITY - Capital & Reserves'
      WHEN a.account_type = 'I' AND a.account_number BETWEEN 110 AND 199 THEN 'INCOME - Interest & Fees'
      WHEN a.account_type = 'I' AND a.account_number BETWEEN 200 AND 299 THEN 'EXPENSES - Personnel'
      WHEN a.account_type = 'I' AND a.account_number BETWEEN 300 AND 399 THEN 'EXPENSES - Operations'
      WHEN a.account_type = 'I' AND a.account_number BETWEEN 400 AND 499 THEN 'OTHER - Income/Expense'
      ELSE 'OTHER'
    END AS GL_Subcategory,

    /* Asset/Liability */
    CASE 
      WHEN a.account_type = 'B' AND a.current_balance_from_coa > 0 THEN 'ASSET'
      WHEN a.account_type = 'B' AND a.current_balance_from_coa < 0 THEN 'LIABILITY/EQUITY'
      WHEN a.account_type = 'B' AND a.current_balance_from_coa = 0 THEN 'ZERO BALANCE'
      WHEN a.account_type = 'I' THEN 'INCOME/EXPENSE'
      ELSE 'OTHER'
    END AS Asset_Liability_Type,

    /* Estado y fechas */
    CASE WHEN a.inactive = 0 THEN 'Active' ELSE 'Inactive' END AS Status,
    a.created_timestamp AS Open_Date,
    CASE WHEN a.inactive = 1 THEN a.modified_timestamp ELSE NULL END AS Close_Date,

    /* Saldos y actividad mensual */
    r.calculated_balance                 AS Historical_Balance,
    a.current_balance_from_coa           AS Current_Balance_From_COA,

    /* Cambio vs mes anterior (LAG sobre el running ya calculado) */
    (r.calculated_balance
     - LAG(r.calculated_balance, 1) OVER (PARTITION BY r.account_number ORDER BY r.period_start)
    ) AS Period_Balance_Change,

    r.monthly_transactions AS Monthly_Transaction_Count,
    r.monthly_debits       AS Monthly_Debits,
    r.monthly_credits      AS Monthly_Credits,
    r.monthly_net_activity AS Monthly_Net_Activity,
    r.monthly_total_amount AS Monthly_Total_Amount,

    /* Nivel de actividad - Clasificación mejorada basada en análisis de datos */
    CASE
      WHEN COALESCE(r.monthly_transactions,0) = 0 THEN 'No Activity'
      WHEN r.monthly_transactions <= 10     THEN 'Low Activity'
      WHEN r.monthly_transactions <= 50     THEN 'Medium Activity'
      WHEN r.monthly_transactions <= 200    THEN 'High Activity'
      ELSE 'Very High Activity'
    END AS Activity_Level,

    /* Flags y auditoría */
    CASE WHEN a.restricted = 1 THEN 'Yes' ELSE 'No' END AS Restricted,
    CASE WHEN a.controlled = 'Y' THEN 'Yes' ELSE 'No' END AS Controlled,
    a.modified_timestamp AS Last_Modified,
    a.modified_by_userid AS Last_Modified_By

FROM running r
JOIN acct a
  ON a.account_number = r.account_number

ORDER BY r.period_start DESC, a.account_type, a.account_number