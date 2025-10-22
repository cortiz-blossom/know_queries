WITH loan_paid_accounts AS (
    SELECT DISTINCT
        at.div_int_acct as paid_gl_account
    FROM account_types at
    WHERE at.category = 'LOAN'
    AND at.div_int_acct IS NOT NULL
),

loan_accrual_accounts AS (
    SELECT DISTINCT
        at.accrual_acct as accrual_gl_account
    FROM account_types at
    WHERE at.category = 'LOAN'
    AND at.accrual_acct IS NOT NULL
),

monthly_paid_amounts AS (
    SELECT
        'LOAN' as product_type,
        'Interest' as transaction_type,
        YEAR(gh.effective_date) as entry_year,
        MONTH(gh.effective_date) as entry_month,
        QUARTER(gh.effective_date) as entry_quarter,
        DATE_FORMAT(gh.effective_date, '%Y-%m') as yearMonth,
        SUM(ABS(gh.amount)) as total_paid_amount,
        COUNT(DISTINCT gh.batch_number) as actual_transaction_count,
        COUNT(*) as gl_entry_count,
        MIN(gh.effective_date) as earliest_transaction_date,
        MAX(gh.effective_date) as latest_transaction_date
    FROM loan_paid_accounts lpa
    INNER JOIN gl_history gh ON lpa.paid_gl_account = gh.gl_account_number
    WHERE gh.status != 'D'
    GROUP BY
        entry_year,
        entry_month,
        entry_quarter,
        yearMonth
),

monthly_accrued_amounts AS (
    SELECT
        'LOAN' as product_type,
        'Interest' as transaction_type,
        YEAR(gh.effective_date) as entry_year,
        MONTH(gh.effective_date) as entry_month,
        QUARTER(gh.effective_date) as entry_quarter,
        DATE_FORMAT(gh.effective_date, '%Y-%m') as yearMonth,
        SUM(gh.amount) as total_accrued_amount,
        COUNT(DISTINCT gh.batch_number) as actual_transaction_count,
        COUNT(*) as gl_entry_count,
        MIN(gh.effective_date) as earliest_transaction_date,
        MAX(gh.effective_date) as latest_transaction_date
    FROM loan_accrual_accounts laa
    INNER JOIN gl_history gh ON laa.accrual_gl_account = gh.gl_account_number
    WHERE gh.status != 'D'
    GROUP BY
        entry_year,
        entry_month,
        entry_quarter,
        yearMonth
)

SELECT
    pa.product_type,
    pa.transaction_type,
    pa.entry_year,
    pa.entry_month,
    pa.entry_quarter,
    pa.yearMonth,
    pa.total_paid_amount,
    COALESCE(aa.total_accrued_amount, 0) as total_accrued_amount,
    pa.total_paid_amount - COALESCE(aa.total_accrued_amount, 0) as variance_paid_vs_accrued,
    CASE
        WHEN COALESCE(aa.total_accrued_amount, 0) > 0
        THEN ROUND((pa.total_paid_amount / aa.total_accrued_amount) * 100, 2)
        ELSE NULL
    END as paid_to_accrued_ratio_pct,
    pa.actual_transaction_count as paid_transaction_count,
    COALESCE(aa.actual_transaction_count, 0) as accrued_transaction_count,
    pa.gl_entry_count as paid_gl_entries,
    COALESCE(aa.gl_entry_count, 0) as accrued_gl_entries,
    pa.earliest_transaction_date as paid_earliest_date,
    pa.latest_transaction_date as paid_latest_date,
    aa.earliest_transaction_date as accrued_earliest_date,
    aa.latest_transaction_date as accrued_latest_date,
    CASE 
        WHEN pa.total_paid_amount > 0 AND COALESCE(aa.total_accrued_amount, 0) = 0 
        THEN 'PAID_WITHOUT_ACCRUAL'
        WHEN pa.total_paid_amount = 0 AND COALESCE(aa.total_accrued_amount, 0) > 0 
        THEN 'ACCRUED_NOT_PAID'
        WHEN ABS(pa.total_paid_amount - COALESCE(aa.total_accrued_amount, 0)) > (pa.total_paid_amount * 0.05)
        THEN 'SIGNIFICANT_VARIANCE'
        ELSE 'NORMAL'
    END as alert_status,
    CASE 
        WHEN aa.earliest_transaction_date IS NOT NULL AND pa.latest_transaction_date IS NOT NULL
        THEN DATEDIFF(pa.latest_transaction_date, aa.earliest_transaction_date)
        ELSE NULL
    END as days_between_accrual_and_payment
FROM monthly_paid_amounts pa
LEFT JOIN monthly_accrued_amounts aa
    ON pa.yearMonth = aa.yearMonth
WHERE pa.yearMonth IS NOT NULL
AND pa.total_paid_amount > 0
ORDER BY
    pa.entry_year DESC,
    pa.entry_month DESC