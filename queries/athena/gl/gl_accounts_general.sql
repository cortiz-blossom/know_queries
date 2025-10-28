WITH months AS (
    SELECT
        CAST(period_start AS date) AS period_start
    FROM UNNEST(
        sequence(
            DATE '2022-01-01',
            date_trunc('month', current_date),
            INTERVAL '1' MONTH
        )
    ) AS t(period_start)
),

acct AS (
    SELECT
        g.credit_union,
        CAST(g.account_number AS varchar) AS account_number,
        g.description,
        g.short_desc,
        UPPER(TRIM(g.account_type)) AS account_type,
        g.inactive,
        CAST(g.created_timestamp AS timestamp(3)) AS created_timestamp,
        CAST(g.modified_timestamp AS timestamp(3)) AS modified_timestamp,
        g.restricted,
        g.controlled,
        g.modified_by_userid,
        g.balance AS current_balance_from_coa
    FROM "AwsDataCatalog"."silver-mvp-know"."gl_chart_of_accounts" g
    WHERE UPPER(TRIM(g.account_type)) IN ('B','I')
),

monthly_stats AS (
    SELECT
        h.credit_union,
        CAST(h.gl_account_number AS varchar) AS account_number,
        CAST(date_trunc('month', h.effective_date) AS date) AS period_start,
        COUNT(*) AS transaction_count,
        SUM(CASE WHEN h.amount < 0 THEN -h.amount ELSE 0 END) AS total_debits,
        SUM(CASE WHEN h.amount > 0 THEN h.amount ELSE 0 END) AS total_credits,
        SUM(h.amount) AS net_activity,
        SUM(ABS(h.amount)) AS total_amount
    FROM "AwsDataCatalog"."silver-mvp-know"."gl_history" h
    WHERE h.effective_date >= DATE '2022-01-01'
    GROUP BY
        h.credit_union,
        CAST(h.gl_account_number AS varchar),
        CAST(date_trunc('month', h.effective_date) AS date)
),

grid AS (
    SELECT
        a.credit_union,
        a.account_number,
        m.period_start
    FROM acct a
    JOIN months m
      ON m.period_start >= date_add('month', -36, date_trunc('month', current_date))
),

stats AS (
    SELECT
        g.credit_union,
        g.account_number,
        g.period_start,
        COALESCE(ms.transaction_count, 0)    AS monthly_transactions,
        COALESCE(ms.total_debits, 0.00)      AS monthly_debits,
        COALESCE(ms.total_credits, 0.00)     AS monthly_credits,
        COALESCE(ms.net_activity, 0.00)      AS monthly_net_activity,
        COALESCE(ms.total_amount, 0.00)      AS monthly_total_amount
    FROM grid g
    LEFT JOIN monthly_stats ms
      ON ms.credit_union  = g.credit_union
     AND ms.account_number = g.account_number
     AND ms.period_start   = g.period_start
),

running AS (
    SELECT
        s.*,
        SUM(s.monthly_net_activity) OVER (
            PARTITION BY s.credit_union, s.account_number
            ORDER BY s.period_start
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS calculated_balance
    FROM stats s
)

SELECT
    r.credit_union AS credit_union,
    fi.idfi AS idfi,
    CAST(r.period_start AS date) AS Period_Date,
    date_format(CAST(r.period_start AS timestamp), '%Y-%m') AS Period_Year_Month,
    year(r.period_start) AS Year,
    month(r.period_start) AS Month,
    format_datetime(CAST(r.period_start AS timestamp), 'MMMM') AS Month_Name,
    a.account_number AS GL_ID,
    a.description AS GL_Name,
    a.short_desc AS Short_Description,
    CASE
        WHEN a.account_type = 'B' THEN 'Balance Sheet'
        WHEN a.account_type = 'I' THEN 'Income Statement'
        ELSE 'Other'
    END AS GL_Category,
    CASE
        WHEN a.account_type = 'B' AND try_cast(split_part(a.account_number, '.', 1) AS integer) BETWEEN 701 AND 799 AND r.calculated_balance > 0 THEN 'ASSETS - Loans to Members'
        WHEN a.account_type = 'B' AND try_cast(split_part(a.account_number, '.', 1) AS integer) BETWEEN 740 AND 750 AND r.calculated_balance > 0 THEN 'ASSETS - Investments'
        WHEN a.account_type = 'B' AND try_cast(split_part(a.account_number, '.', 1) AS integer) BETWEEN 770 AND 780 AND r.calculated_balance > 0 THEN 'ASSETS - Property & Equipment'
        WHEN a.account_type = 'B' AND try_cast(split_part(a.account_number, '.', 1) AS integer) BETWEEN 700 AND 799 AND r.calculated_balance < 0 THEN 'CONTRA-ASSETS - Allowances/Provisions'
        WHEN a.account_type = 'B' AND try_cast(split_part(a.account_number, '.', 1) AS integer) BETWEEN 800 AND 899 AND r.calculated_balance < 0 THEN 'LIABILITIES - Accounts Payable'
        WHEN a.account_type = 'B' AND try_cast(split_part(a.account_number, '.', 1) AS integer) BETWEEN 900 AND 989 AND r.calculated_balance < 0 THEN 'LIABILITIES - Member Deposits'
        WHEN a.account_type = 'B' AND try_cast(split_part(a.account_number, '.', 1) AS integer) BETWEEN 990 AND 999 AND r.calculated_balance < 0 THEN 'EQUITY - Capital & Reserves'
        WHEN a.account_type = 'I' AND try_cast(split_part(a.account_number, '.', 1) AS integer) BETWEEN 110 AND 199 THEN 'INCOME - Interest & Fees'
        WHEN a.account_type = 'I' AND try_cast(split_part(a.account_number, '.', 1) AS integer) BETWEEN 200 AND 299 THEN 'EXPENSES - Personnel'
        WHEN a.account_type = 'I' AND try_cast(split_part(a.account_number, '.', 1) AS integer) BETWEEN 300 AND 399 THEN 'EXPENSES - Operations'
        WHEN a.account_type = 'I' AND try_cast(split_part(a.account_number, '.', 1) AS integer) BETWEEN 400 AND 499 THEN 'OTHER - Income/Expense'
        ELSE 'OTHER'
    END AS GL_Subcategory,
    CASE
        WHEN a.account_type = 'B' AND a.current_balance_from_coa > 0  THEN 'ASSET'
        WHEN a.account_type = 'B' AND a.current_balance_from_coa < 0  THEN 'LIABILITY/EQUITY'
        WHEN a.account_type = 'B' AND a.current_balance_from_coa = 0  THEN 'ZERO BALANCE'
        WHEN a.account_type = 'I' THEN 'INCOME/EXPENSE'
        ELSE 'OTHER'
    END AS Asset_Liability_Type,
    CASE WHEN a.inactive = 0 THEN 'Active' ELSE 'Inactive' END AS Status,
    a.created_timestamp AS Open_Date,
    CASE WHEN a.inactive = 1 THEN a.modified_timestamp ELSE NULL END AS Close_Date,
    r.calculated_balance AS Historical_Balance,
    a.current_balance_from_coa AS Current_Balance_From_COA,
    (r.calculated_balance - LAG(r.calculated_balance, 1) OVER (PARTITION BY r.credit_union, r.account_number ORDER BY r.period_start)) AS Period_Balance_Change,
    r.monthly_transactions AS Monthly_Transaction_Count,
    r.monthly_debits AS Monthly_Debits,
    r.monthly_credits AS Monthly_Credits,
    r.monthly_net_activity AS Monthly_Net_Activity,
    r.monthly_total_amount AS Monthly_Total_Amount,
    CASE
        WHEN COALESCE(r.monthly_transactions, 0) = 0 THEN 'No Activity'
        WHEN r.monthly_transactions <= 10  THEN 'Low Activity'
        WHEN r.monthly_transactions <= 50  THEN 'Medium Activity'
        WHEN r.monthly_transactions <= 200 THEN 'High Activity'
        ELSE 'Very High Activity'
    END AS Activity_Level,
    CASE WHEN a.restricted = 1 THEN 'Yes' ELSE 'No' END AS Restricted,
    CASE WHEN UPPER(TRIM(CAST(a.controlled AS varchar))) = 'Y' THEN 'Yes' ELSE 'No' END AS Controlled,
    a.modified_timestamp AS Last_Modified,
    a.modified_by_userid AS Last_Modified_By
FROM running r
JOIN acct a
  ON a.account_number = r.account_number
 AND a.credit_union  = r.credit_union
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
  ON fi.prodigy_code = r.credit_union
ORDER BY
    r.period_start DESC,
    a.account_type,
    a.account_number;
