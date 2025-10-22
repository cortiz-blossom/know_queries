WITH cert_paid_accounts AS (
    SELECT DISTINCT
        at.div_int_acct as paid_gl_account
    FROM account_types at
    WHERE at.category = 'CERT'
    AND at.div_int_acct IS NOT NULL
),

cert_accrual_accounts AS (
    SELECT DISTINCT
        at.accrual_acct as accrual_gl_account
    FROM account_types at
    WHERE at.category = 'CERT'
    AND at.accrual_acct IS NOT NULL
),

monthly_div_int_amounts AS (
    SELECT
        YEAR(gh.effective_date) as entry_year,
        MONTH(gh.effective_date) as entry_month,
        QUARTER(gh.effective_date) as entry_quarter,
        DATE_FORMAT(gh.effective_date, '%Y-%m') as yearMonth,
        SUM(gh.amount) as div_int_balance,
        COUNT(DISTINCT gh.batch_number) as div_int_transaction_count,
        COUNT(*) as div_int_gl_entry_count,
        MIN(gh.effective_date) as div_int_earliest_date,
        MAX(gh.effective_date) as div_int_latest_date
    FROM cert_paid_accounts cpa
    INNER JOIN gl_history gh ON cpa.paid_gl_account = gh.gl_account_number
    WHERE gh.status != 'D'
    GROUP BY
        entry_year,
        entry_month,
        entry_quarter,
        yearMonth
),

monthly_accrual_amounts AS (
    SELECT
        YEAR(gh.effective_date) as entry_year,
        MONTH(gh.effective_date) as entry_month,
        QUARTER(gh.effective_date) as entry_quarter,
        DATE_FORMAT(gh.effective_date, '%Y-%m') as yearMonth,
        SUM(gh.amount) as total_accrued_amount,
        COUNT(DISTINCT gh.batch_number) as actual_transaction_count,
        COUNT(*) as gl_entry_count,
        MIN(gh.effective_date) as earliest_transaction_date,
        MAX(gh.effective_date) as latest_transaction_date
    FROM cert_accrual_accounts caa
    INNER JOIN gl_history gh ON caa.accrual_gl_account = gh.gl_account_number
    WHERE gh.status != 'D'
    GROUP BY
        entry_year,
        entry_month,
        entry_quarter,
        yearMonth
)

SELECT
    'CERT' as product_type,
    'Dividend' as transaction_type,
    mda.entry_year,
    mda.entry_month,
    mda.entry_quarter,
    mda.yearMonth,
    (mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) as total_paid_amount,
    COALESCE(maa.total_accrued_amount, 0) as total_accrued_amount,
    (mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) - COALESCE(maa.total_accrued_amount, 0) as variance_paid_vs_accrued,
    CASE
        WHEN COALESCE(maa.total_accrued_amount, 0) > 0
        THEN ROUND(((mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) / maa.total_accrued_amount) * 100, 2)
        ELSE NULL
    END as paid_to_accrued_ratio_pct,
    mda.div_int_transaction_count as paid_transaction_count,
    COALESCE(maa.actual_transaction_count, 0) as accrued_transaction_count,
    mda.div_int_gl_entry_count as paid_gl_entries,
    COALESCE(maa.gl_entry_count, 0) as accrued_gl_entries,
    mda.div_int_earliest_date as paid_earliest_date,
    mda.div_int_latest_date as paid_latest_date,
    maa.earliest_transaction_date as accrued_earliest_date,
    maa.latest_transaction_date as accrued_latest_date,
    CASE 
        WHEN (mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) > 0 AND COALESCE(maa.total_accrued_amount, 0) = 0 
        THEN 'PAID_WITHOUT_ACCRUAL'
        WHEN (mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) = 0 AND COALESCE(maa.total_accrued_amount, 0) > 0 
        THEN 'ACCRUED_NOT_PAID'
        WHEN ABS((mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) - COALESCE(maa.total_accrued_amount, 0)) > (ABS(mda.div_int_balance - COALESCE(maa.total_accrued_amount, 0)) * 0.05)
        THEN 'SIGNIFICANT_VARIANCE'
        ELSE 'NORMAL'
    END as alert_status,
    CASE 
        WHEN maa.earliest_transaction_date IS NOT NULL AND mda.div_int_latest_date IS NOT NULL
        THEN DATEDIFF(mda.div_int_latest_date, maa.earliest_transaction_date)
        ELSE NULL
    END as days_between_accrual_and_payment
FROM monthly_div_int_amounts mda
LEFT JOIN monthly_accrual_amounts maa ON mda.yearMonth = maa.yearMonth
WHERE mda.yearMonth IS NOT NULL

UNION

SELECT
    'CERT' as product_type,
    'Dividend' as transaction_type,
    maa.entry_year,
    maa.entry_month,
    maa.entry_quarter,
    maa.yearMonth,
    (0 - maa.total_accrued_amount) as total_paid_amount,
    maa.total_accrued_amount,
    (0 - maa.total_accrued_amount) - maa.total_accrued_amount as variance_paid_vs_accrued,
    CASE
        WHEN maa.total_accrued_amount > 0
        THEN ROUND(((0 - maa.total_accrued_amount) / maa.total_accrued_amount) * 100, 2)
        ELSE NULL
    END as paid_to_accrued_ratio_pct,
    0 as paid_transaction_count,
    maa.actual_transaction_count as accrued_transaction_count,
    0 as paid_gl_entries,
    maa.gl_entry_count as accrued_gl_entries,
    NULL as paid_earliest_date,
    NULL as paid_latest_date,
    maa.earliest_transaction_date as accrued_earliest_date,
    maa.latest_transaction_date as accrued_latest_date,
    'ACCRUED_NOT_PAID' as alert_status,
    NULL as days_between_accrual_and_payment
FROM monthly_accrual_amounts maa
LEFT JOIN monthly_div_int_amounts mda ON maa.yearMonth = mda.yearMonth
WHERE mda.yearMonth IS NULL
AND maa.total_accrued_amount != 0

ORDER BY
    entry_year DESC,
    entry_month DESC