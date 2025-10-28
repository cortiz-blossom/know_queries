WITH tx_monthly AS (
    SELECT
        th.credit_union,
        th.account_id,
        CAST(date_trunc('month', CAST(th.date_effective AS date)) AS date) AS month_start,
        COUNT(DISTINCT th.transaction_history_id) AS Transactions,
        COUNT(DISTINCT CASE WHEN th.total_amount > 0 THEN th.transaction_history_id END) AS Deposits,
        COUNT(DISTINCT CASE WHEN th.total_amount < 0 THEN th.transaction_history_id END) AS Withdrawals,
        ROUND(SUM(CASE WHEN th.total_amount > 0 THEN th.total_amount ELSE 0 END), 2) AS total_credits,
        ROUND(SUM(CASE WHEN th.total_amount < 0 THEN ABS(th.total_amount) ELSE 0 END), 2) AS total_debits,
        ROUND(SUM(th.total_amount), 2) AS net_change_for_month
    FROM "AwsDataCatalog"."silver-mvp-know"."transaction_history" th
    WHERE
        th.void_flag = 0
        AND YEAR(CAST(th.date_effective AS date)) = YEAR(current_date)
    GROUP BY
        th.credit_union,
        th.account_id,
        CAST(date_trunc('month', CAST(th.date_effective AS date)) AS date)
),

tx_with_suffix AS (
    SELECT
        t.*,
        SUM(t.net_change_for_month) OVER (
            PARTITION BY t.credit_union, t.account_id
            ORDER BY t.month_start
            ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
        ) AS net_change_from_this_month_forward
    FROM tx_monthly t
)

SELECT
    t.credit_union AS credit_union,
    fi.idfi AS idfi,
    date_format(CAST(t.month_start AS timestamp), '%Y-%m') AS month_year,
    a.account_number,
    a.member_number,
    CASE UPPER(TRIM(a.discriminator))
        WHEN 'S' THEN 'SAVINGS'
        WHEN 'D' THEN 'CHECKING'
        WHEN 'C' THEN 'CERTIFICATES'
        WHEN 'L' THEN 'LOANS'
        WHEN 'U' THEN 'SPECIAL'
        ELSE 'OTHER'
    END AS account_category,
    a.account_type,
    a.current_balance,
    t.Transactions,
    t.Deposits,
    t.Withdrawals,
    t.total_credits,
    t.total_debits,
    t.net_change_for_month,
    ROUND(a.current_balance - COALESCE(t.net_change_from_this_month_forward, 0), 2) AS approximate_beginning_balance,
    CASE WHEN t.Transactions > 0 THEN 'Active' ELSE 'Inactive' END AS activity_status
FROM tx_with_suffix t
JOIN "AwsDataCatalog"."silver-mvp-know"."account" a
  ON a.credit_union = t.credit_union
 AND a.account_id = t.account_id
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
  ON fi.prodigy_code = t.credit_union
WHERE
    a.member_number > 0
    AND UPPER(TRIM(a.discriminator)) IN ('S','D','C','U')
ORDER BY
    month_year DESC,
    account_category,
    a.account_number;
