WITH cert_paid_accounts AS (
    SELECT DISTINCT
        at."credit_union" AS "credit_union",
        COALESCE(REGEXP_REPLACE(TRIM(CAST(at.div_int_acct AS varchar)), '^0+', ''), '0') AS paid_gl_account_canon
    FROM "AwsDataCatalog"."silver-mvp-know"."account_types" at
    WHERE UPPER(TRIM(at.category)) = 'CERT'
      AND at.div_int_acct IS NOT NULL
),

cert_accrual_accounts AS (
    SELECT DISTINCT
        at."credit_union" AS "credit_union",
        COALESCE(REGEXP_REPLACE(TRIM(CAST(at.accrual_acct AS varchar)), '^0+', ''), '0') AS accrual_gl_account_canon
    FROM "AwsDataCatalog"."silver-mvp-know"."account_types" at
    WHERE UPPER(TRIM(at.category)) = 'CERT'
      AND at.accrual_acct IS NOT NULL
),

gl_hist AS (
    SELECT
        gh.*,
        COALESCE(REGEXP_REPLACE(TRIM(CAST(gh.gl_account_number AS varchar)), '^0+', ''), '0') AS gl_account_canon
    FROM "AwsDataCatalog"."silver-mvp-know"."gl_history" gh
    WHERE UPPER(TRIM(COALESCE(gh.status,'P'))) = 'P'
),

monthly_div_int_amounts AS (
    SELECT
        year(gh.effective_date) AS entry_year,
        month(gh.effective_date) AS entry_month,
        quarter(gh.effective_date) AS entry_quarter,
        date_format(gh.effective_date, '%Y-%m') AS yearMonth,
        gh."credit_union" AS "credit_union",
        SUM(gh.amount) AS div_int_balance,
        COUNT(DISTINCT gh.batch_number) AS div_int_transaction_count,
        COUNT(*) AS div_int_gl_entry_count,
        MIN(gh.effective_date) AS div_int_earliest_date,
        MAX(gh.effective_date) AS div_int_latest_date
    FROM gl_hist gh
    JOIN cert_paid_accounts cpa
      ON gh.gl_account_canon = cpa.paid_gl_account_canon
     AND gh."credit_union"   = cpa."credit_union"
    GROUP BY
        year(gh.effective_date),
        month(gh.effective_date),
        quarter(gh.effective_date),
        date_format(gh.effective_date, '%Y-%m'),
        gh."credit_union"
),

monthly_accrual_amounts AS (
    SELECT
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
    JOIN cert_accrual_accounts caa
      ON gh.gl_account_canon = caa.accrual_gl_account_canon
     AND gh."credit_union"   = caa."credit_union"
    GROUP BY
        year(gh.effective_date),
        month(gh.effective_date),
        quarter(gh.effective_date),
        date_format(gh.effective_date, '%Y-%m'),
        gh."credit_union"
)

SELECT
    mda."credit_union" AS "credit_union",
    fi.idfi AS idfi,
    'CERT' AS product_type,
    'Dividend' AS transaction_type,
    mda.entry_year,
    mda.entry_month,
    mda.entry_quarter,
    mda.yearMonth,
    (mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) AS total_paid_amount,
    COALESCE(maa.total_accrued_amount, 0) AS total_accrued_amount,
    (mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) - COALESCE(maa.total_accrued_amount, 0) AS variance_paid_vs_accrued,
    CASE
        WHEN COALESCE(maa.total_accrued_amount, 0) > 0
            THEN ROUND(((mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) / maa.total_accrued_amount) * 100, 2)
        ELSE NULL
    END AS paid_to_accrued_ratio_pct,
    mda.div_int_transaction_count AS paid_transaction_count,
    COALESCE(maa.actual_transaction_count, 0) AS accrued_transaction_count,
    mda.div_int_gl_entry_count AS paid_gl_entries,
    COALESCE(maa.gl_entry_count, 0) AS accrued_gl_entries,
    mda.div_int_earliest_date AS paid_earliest_date,
    mda.div_int_latest_date   AS paid_latest_date,
    maa.earliest_transaction_date AS accrued_earliest_date,
    maa.latest_transaction_date   AS accrued_latest_date,
    CASE
        WHEN (mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) > 0 AND COALESCE(maa.total_accrued_amount, 0) = 0 THEN 'PAID_WITHOUT_ACCRUAL'
        WHEN (mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) = 0 AND COALESCE(maa.total_accrued_amount, 0) > 0 THEN 'ACCRUED_NOT_PAID'
        WHEN ABS((mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) - COALESCE(maa.total_accrued_amount, 0)) > (ABS(mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) * 0.05) THEN 'SIGNIFICANT_VARIANCE'
        ELSE 'NORMAL'
    END AS alert_status,
    CASE
        WHEN maa.earliest_transaction_date IS NOT NULL AND mda.div_int_latest_date IS NOT NULL
            THEN date_diff('day', maa.earliest_transaction_date, mda.div_int_latest_date)
        ELSE NULL
    END AS days_between_accrual_and_payment
FROM monthly_div_int_amounts mda
LEFT JOIN monthly_accrual_amounts maa
  ON mda.yearMonth     = maa.yearMonth
 AND mda."credit_union" = maa."credit_union"
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
  ON lower(trim(fi.prodigy_code)) = lower(trim(mda."credit_union"))
WHERE
    mda.yearMonth IS NOT NULL

UNION

SELECT
    maa."credit_union" AS "credit_union",
    fi.idfi AS idfi,
    'CERT' AS product_type,
    'Dividend' AS transaction_type,
    maa.entry_year,
    maa.entry_month,
    maa.entry_quarter,
    maa.yearMonth,
    (0 - maa.total_accrued_amount) AS total_paid_amount,
    maa.total_accrued_amount,
    (0 - maa.total_accrued_amount) - maa.total_accrued_amount AS variance_paid_vs_accrued,
    CASE
        WHEN maa.total_accrued_amount > 0
            THEN ROUND(((0 - maa.total_accrued_amount) / maa.total_accrued_amount) * 100, 2)
        ELSE NULL
    END AS paid_to_accrued_ratio_pct,
    0 AS paid_transaction_count,
    maa.actual_transaction_count AS accrued_transaction_count,
    0 AS paid_gl_entries,
    maa.gl_entry_count AS accrued_gl_entries,
    NULL AS paid_earliest_date,
    NULL AS paid_latest_date,
    maa.earliest_transaction_date AS accrued_earliest_date,
    maa.latest_transaction_date   AS accrued_latest_date,
    'ACCRUED_NOT_PAID' AS alert_status,
    NULL AS days_between_accrual_and_payment
FROM monthly_accrual_amounts maa
LEFT JOIN monthly_div_int_amounts mda
  ON maa.yearMonth     = mda.yearMonth
 AND maa."credit_union" = mda."credit_union"
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
  ON lower(trim(fi.prodigy_code)) = lower(trim(maa."credit_union"))
WHERE
    mda.yearMonth IS NULL
    AND maa.total_accrued_amount <> 0

ORDER BY
    entry_year DESC,
    entry_month DESC;
