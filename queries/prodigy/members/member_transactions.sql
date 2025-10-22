-- Transaction KPIs Query
SELECT 
    a.member_number as member_id,
    
    -- LIFETIME TRANSACTION METRICS (All Time)
    COUNT(*) as total_transactions_lifetime,
    ROUND(SUM(ABS(th.total_amount)), 2) as total_transaction_amount_lifetime,
    ROUND(AVG(ABS(th.total_amount)), 2) as avg_transaction_amount_lifetime,
    COUNT(CASE WHEN th.total_amount < 0 THEN 1 END) as debit_transactions_lifetime,
    COUNT(CASE WHEN th.total_amount > 0 THEN 1 END) as credit_transactions_lifetime,
    ROUND(SUM(CASE WHEN th.total_amount < 0 THEN ABS(th.total_amount) ELSE 0 END), 2) as debit_amount_lifetime,
    ROUND(SUM(CASE WHEN th.total_amount > 0 THEN th.total_amount ELSE 0 END), 2) as credit_amount_lifetime,
    
    -- MONTH-TO-DATE (MTD)
    COUNT(CASE WHEN YEAR(th.date_effective) = YEAR(CURDATE()) AND MONTH(th.date_effective) = MONTH(CURDATE()) THEN 1 END) as total_transactions_mtd,
    ROUND(SUM(CASE WHEN YEAR(th.date_effective) = YEAR(CURDATE()) AND MONTH(th.date_effective) = MONTH(CURDATE()) THEN ABS(th.total_amount) ELSE 0 END), 2) as total_transaction_amount_mtd,
    ROUND(AVG(CASE WHEN YEAR(th.date_effective) = YEAR(CURDATE()) AND MONTH(th.date_effective) = MONTH(CURDATE()) THEN ABS(th.total_amount) END), 2) as avg_transaction_amount_mtd,
    COUNT(CASE WHEN YEAR(th.date_effective) = YEAR(CURDATE()) AND MONTH(th.date_effective) = MONTH(CURDATE()) AND th.total_amount < 0 THEN 1 END) as debit_transactions_mtd,
    COUNT(CASE WHEN YEAR(th.date_effective) = YEAR(CURDATE()) AND MONTH(th.date_effective) = MONTH(CURDATE()) AND th.total_amount > 0 THEN 1 END) as credit_transactions_mtd,
    ROUND(SUM(CASE WHEN YEAR(th.date_effective) = YEAR(CURDATE()) AND MONTH(th.date_effective) = MONTH(CURDATE()) AND th.total_amount < 0 THEN ABS(th.total_amount) ELSE 0 END), 2) as debit_amount_mtd,
    ROUND(SUM(CASE WHEN YEAR(th.date_effective) = YEAR(CURDATE()) AND MONTH(th.date_effective) = MONTH(CURDATE()) AND th.total_amount > 0 THEN th.total_amount ELSE 0 END), 2) as credit_amount_mtd,

    -- LAST 30 DAYS
    COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) as total_transactions_30d,
    ROUND(SUM(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN ABS(th.total_amount) ELSE 0 END), 2) as total_transaction_amount_30d,
    ROUND(AVG(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN ABS(th.total_amount) END), 2) as avg_transaction_amount_30d,
    COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) AND th.total_amount < 0 THEN 1 END) as debit_transactions_30d,
    COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) AND th.total_amount > 0 THEN 1 END) as credit_transactions_30d,
    ROUND(SUM(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) AND th.total_amount < 0 THEN ABS(th.total_amount) ELSE 0 END), 2) as debit_amount_30d,
    ROUND(SUM(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) AND th.total_amount > 0 THEN th.total_amount ELSE 0 END), 2) as credit_amount_30d,
    
    -- LAST 90 DAYS
    COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN 1 END) as total_transactions_90d,
    ROUND(SUM(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN ABS(th.total_amount) ELSE 0 END), 2) as total_transaction_amount_90d,
    ROUND(AVG(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN ABS(th.total_amount) END), 2) as avg_transaction_amount_90d,
    COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) AND th.total_amount < 0 THEN 1 END) as debit_transactions_90d,
    COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) AND th.total_amount > 0 THEN 1 END) as credit_transactions_90d,
    ROUND(SUM(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) AND th.total_amount < 0 THEN ABS(th.total_amount) ELSE 0 END), 2) as debit_amount_90d,
    ROUND(SUM(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) AND th.total_amount > 0 THEN th.total_amount ELSE 0 END), 2) as credit_amount_90d,
    
    -- LAST 12 MONTHS
    COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) THEN 1 END) as total_transactions_12m,
    ROUND(SUM(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) THEN ABS(th.total_amount) ELSE 0 END), 2) as total_transaction_amount_12m,
    ROUND(AVG(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) THEN ABS(th.total_amount) END), 2) as avg_transaction_amount_12m,
    COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) AND th.total_amount < 0 THEN 1 END) as debit_transactions_12m,
    COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) AND th.total_amount > 0 THEN 1 END) as credit_transactions_12m,
    ROUND(SUM(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) AND th.total_amount < 0 THEN ABS(th.total_amount) ELSE 0 END), 2) as debit_amount_12m,
    ROUND(SUM(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) AND th.total_amount > 0 THEN th.total_amount ELSE 0 END), 2) as credit_amount_12m,
    
    -- CREDIT CARD SPECIFIC METRICS (Last 12 Months)
    COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) AND COALESCE(at2.credit_card, 0) = 1 THEN 1 END) as credit_card_transactions_12m,
    ROUND(SUM(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) AND COALESCE(at2.credit_card, 0) = 1 THEN ABS(th.total_amount) ELSE 0 END), 2) as credit_card_amount_12m,
    
    -- TRANSACTION ACTIVITY INDICATORS
    CASE 
        WHEN COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) > 0 THEN 'Active'
        ELSE 'Inactive'
    END as transaction_activity_30d,
    
    CASE 
        WHEN COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN 1 END) > 0 THEN 'Active'
        ELSE 'Inactive'
    END as transaction_activity_90d,
    
    -- TRANSACTION VOLUME CATEGORIES
    CASE 
        WHEN COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) THEN 1 END) = 0 THEN 'No Transactions'
        WHEN COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) THEN 1 END) <= 12 THEN 'Low Volume (≤12/year)'
        WHEN COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) THEN 1 END) <= 52 THEN 'Medium Volume (13-52/year)'
        WHEN COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) THEN 1 END) <= 156 THEN 'High Volume (53-156/year)'
        ELSE 'Very High Volume (>156/year)'
    END as transaction_volume_category,
    
    -- TRANSACTION ENGAGEMENT SCORE COMPONENTS (0-50 points)
    CASE WHEN COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) > 0 THEN 20 ELSE 0 END as transaction_score_30d,
    CASE WHEN COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) > 5 THEN 10 ELSE 0 END as transaction_score_volume,
    CASE WHEN COUNT(CASE WHEN th.date_effective >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) THEN 1 END) > 52 THEN 20 ELSE 0 END as transaction_score_annual,
    
    -- TRANSACTION DATE RANGE
    MIN(th.date_effective) as first_transaction_date,
    MAX(th.date_effective) as last_transaction_date,
    
    -- DAYS SINCE LAST TRANSACTION
    CASE 
        WHEN MAX(th.date_effective) IS NOT NULL THEN DATEDIFF(CURDATE(), MAX(th.date_effective))
        ELSE NULL 
    END as days_since_last_transaction,
    
    -- CURRENT DATE FOR REFRESH TRACKING
    CURDATE() as transaction_data_extract_date

FROM transaction_history th 
INNER JOIN account a ON a.account_id = th.account_id 
LEFT JOIN account_types at2 ON a.account_type = at2.account_type
WHERE a.member_number IS NOT NULL
GROUP BY a.member_number
ORDER BY a.member_number