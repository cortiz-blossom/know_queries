WITH loan_paid_accounts AS (
    SELECT DISTINCT
        at."credit_union" AS "credit_union",
        COALESCE(REGEXP_REPLACE(TRIM(CAST(at.div_int_acct AS varchar)), '^0+', ''), '0') AS paid_gl_account_canon
    FROM "AwsDataCatalog"."silver-mvp-know"."account_types" at
    WHERE UPPER(TRIM(at.category)) = 'LOAN'
      AND at.div_int_acct IS NOT NULL
),

loan_accrual_accounts AS (
    SELECT DISTINCT
        at."credit_union" AS "credit_union",
        COALESCE(REGEXP_REPLACE(TRIM(CAST(at.accrual_acct AS varchar)), '^0+', ''), '0') AS accrual_gl_account_canon
    FROM "AwsDataCatalog"."silver-mvp-know"."account_types" at
    WHERE UPPER(TRIM(at.category)) = 'LOAN'
      AND at.accrual_acct IS NOT NULL
),

gl_hist AS (
    SELECT
        gh.*,
        COALESCE(REGEXP_REPLACE(TRIM(CAST(gh.gl_account_number AS varchar)), '^0+', ''), '0') AS gl_account_canon
    FROM "AwsDataCatalog"."silver-mvp-know"."gl_history" gh
    WHERE UPPER(TRIM(COALESCE(gh.status,'P'))) = 'P'
),

monthly_paid_amounts AS (
    SELECT
        'LOAN' AS product_type,
        'Interest' AS transaction_type,
        year(gh.effective_date) AS entry_year,
        month(gh.effective_date) AS entry_month,
        quarter(gh.effective_date) AS entry_quarter,
        date_format(gh.effective_date, '%Y-%m') AS yearMonth,
        gh."credit_union" AS "credit_union",
        SUM(ABS(gh.amount)) AS total_paid_amount,
        COUNT(DISTINCT gh.batch_number) AS actual_transaction_count,
        COUNT(*) AS gl_entry_count,
        MIN(gh.effective_date) AS earliest_transaction_date,
        MAX(gh.effective_date) AS latest_transaction_date
    FROM gl_hist gh
    JOIN loan_paid_accounts lpa
      ON gh.gl_account_canon = lpa.paid_gl_account_canon
     AND gh."credit_union"   = lpa."credit_union"
    GROUP BY
        year(gh.effective_date),
        month(gh.effective_date),
        quarter(gh.effective_date),
        date_format(gh.effective_date, '%Y-%m'),
        gh."credit_union"
),

monthly_accrued_amounts AS (
    SELECT
        'LOAN' AS product_type,
        'Interest' AS transaction_type,
        year(gh.effective_date) AS entry_year,
        month(gh.effective_date) AS entry_month,
        quarter(gh.effective_date) AS entry_quarter,
        date_format(gh.effective_date, '%Y-%m') AS yearMonth,
        gh."credit_union" AS "credit_union",
        SUM(gh.amount) AS total_accrued_amount,
        COUNT(DISTINCT gh.batch_number) AS actual_transaction_count,
        COUNT(*) AS gl_entry_count,
        MIN(gh.effective_date) AS earliest_transaction_date,
        MAX(gh.effective_date) AS latest_transaction_date
    FROM gl_hist gh
    JOIN loan_accrual_accounts laa
      ON gh.gl_account_canon = laa.accrual_gl_account_canon
     AND gh."credit_union"   = laa."credit_union"
    GROUP BY
        year(gh.effective_date),
        month(gh.effective_date),
        quarter(gh.effective_date),
        date_format(gh.effective_date, '%Y-%m'),
        gh."credit_union"
)

SELECT
    pa."credit_union" AS "credit_union",
    fi.idfi AS idfi,
    pa.product_type,
    pa.transaction_type,
    pa.entry_year,
    pa.entry_month,
    pa.entry_quarter,
    pa.yearMonth,
    pa.total_paid_amount,
    COALESCE(aa.total_accrued_amount, 0) AS total_accrued_amount,
    pa.total_paid_amount - COALESCE(aa.total_accrued_amount, 0) AS variance_paid_vs_accrued,
    CASE
        WHEN COALESCE(aa.total_accrued_amount, 0) > 0
            THEN ROUND((pa.total_paid_amount / aa.total_accrued_amount) * 100, 2)
        ELSE NULL
    END AS paid_to_accrued_ratio_pct,
    pa.actual_transaction_count AS paid_transaction_count,
    COALESCE(aa.actual_transaction_count, 0) AS accrued_transaction_count,
    pa.gl_entry_count AS paid_gl_entries,
    COALESCE(aa.gl_entry_count, 0) AS accrued_gl_entries,
    pa.earliest_transaction_date AS paid_earliest_date,
    pa.latest_transaction_date   AS paid_latest_date,
    aa.earliest_transaction_date AS accrued_earliest_date,
    aa.latest_transaction_date   AS accrued_latest_date,
    CASE
        WHEN pa.total_paid_amount > 0 AND COALESCE(aa.total_accrued_amount, 0) = 0 THEN 'PAID_WITHOUT_ACCRUAL'
        WHEN pa.total_paid_amount = 0 AND COALESCE(aa.total_accrued_amount, 0) > 0 THEN 'ACCRUED_NOT_PAID'
        WHEN ABS(pa.total_paid_amount - COALESCE(aa.total_accrued_amount, 0)) > (pa.total_paid_amount * 0.05) THEN 'SIGNIFICANT_VARIANCE'
        ELSE 'NORMAL'
    END AS alert_status,
    CASE
        WHEN aa.earliest_transaction_date IS NOT NULL
         AND pa.latest_transaction_date   IS NOT NULL
            THEN date_diff('day', aa.earliest_transaction_date, pa.latest_transaction_date)
        ELSE NULL
    END AS days_between_accrual_and_payment
FROM monthly_paid_amounts pa
LEFT JOIN monthly_accrued_amounts aa
  ON pa.yearMonth     = aa.yearMonth
 AND pa."credit_union" = aa."credit_union"
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
  ON lower(trim(fi.prodigy_code)) = lower(trim(pa."credit_union"))
WHERE
    pa.yearMonth IS NOT NULL
ORDER BY
    pa.entry_year DESC,
    pa.entry_month DESC;
