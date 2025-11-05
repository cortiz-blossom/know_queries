WITH cu_info AS (
    SELECT credit_union_name
    FROM credit_union_info
    WHERE flag_inactive <> 'Y'
    ORDER BY record_number
    LIMIT 1
)
SELECT 
    -- Identification
    a.member_number as Member_ID,
    ci.credit_union_name as CU_Name,
    a.account_id as Loan_ID,
    
    -- Loan classification - MAIN CATEGORY
    CASE 
        WHEN a.account_type IN ('CC', 'PCO', 'PCCO') THEN 'Credit Cards'
        WHEN a.account_type IN ('DUAU', 'DNAU', 'ICUL', 'DMO', 'DRV') THEN 'Auto Loans'
        WHEN a.account_type IN ('UNSC', 'IA') THEN 'Unsecured Personal Loans'
        WHEN a.account_type IN ('SSEC', 'SHL', 'SHL2') THEN 'Secured Loans'
        WHEN a.account_type IN ('HELO', 'HE6', 'HE24', 'HE26', 'MORT') THEN 'Mortgage/Home Equity Loans'
        WHEN a.account_type IN ('QREG', 'QSPC', 'FR20') THEN 'Quick/Special Loans'
        WHEN a.account_type = 'OD' THEN 'Overdraft Protection'
        ELSE 'Unknown/Unclassified'
    END as Loan_Main_Category,
    
    -- SUB CATEGORY - Specific loan type description
    CASE 
        WHEN a.account_type = 'UNSC' THEN 'Unsecured Personal Loan'
        WHEN a.account_type = 'IA' THEN 'Immediate Access Loan'
        WHEN a.account_type = 'DUAU' THEN 'Direct Auto Loan'
        WHEN a.account_type = 'CC' THEN 'Credit Card'
        WHEN a.account_type = 'SSEC' THEN 'Share Secured Loan'
        WHEN a.account_type = 'DRV' THEN 'Used Vehicle Loan'
        WHEN a.account_type = 'DMO' THEN 'Direct Mobile Auto Loan'
        WHEN a.account_type = 'DNAU' THEN 'Direct New Auto Loan'
        WHEN a.account_type = 'ICUL' THEN 'Indirect Auto Loan'
        WHEN a.account_type = 'QREG' THEN 'Quick Regular Loan'
        WHEN a.account_type = 'SHL2' THEN 'Share Secured Loan Type 2'
        WHEN a.account_type = 'HELO' THEN 'Home Equity Line of Credit (HELOC)'
        WHEN a.account_type = 'HE26' THEN 'Home Equity Loan 26'
        WHEN a.account_type = 'PCCO' THEN 'Prepaid Credit Card'
        WHEN a.account_type = 'OL' THEN 'Other Loans'
        WHEN a.account_type = 'SHL' THEN 'Share Secured Loan'
        WHEN a.account_type = 'FR20' THEN 'Fast Rate 20 Loan'
        WHEN a.account_type = 'OD' THEN 'Overdraft Protection'
        WHEN a.account_type = 'MORT' THEN 'Mortgage Loan'
        WHEN a.account_type = 'QSPC' THEN 'Quick Special Loan'
        WHEN a.account_type = 'PCO' THEN 'Prepaid Card Loan'
        WHEN a.account_type = 'HE6' THEN 'Home Equity Loan 6'
        WHEN a.account_type = 'SPS' THEN 'Special Purpose Loan'
        WHEN a.account_type = 'HE24' THEN 'Home Equity Loan 24'
        ELSE a.account_type
    END as Loan_Sub_Category,
    
    -- FINANCIAL INFORMATION AND TERMS
    ROUND(al.interest_rate, 3) as Interest_Rate,
    al.number_of_payments as Number_of_Installments,
    
    -- PAID INSTALLMENTS (Estimated calculation based on dates and payments per year)
    CASE 
        WHEN a.date_closed IS NOT NULL THEN al.number_of_payments  -- If closed, all installments were paid
        WHEN al.number_of_payments IS NOT NULL AND al.number_of_payments > 0 AND a.date_opened IS NOT NULL THEN
            GREATEST(0, LEAST(al.number_of_payments, 
                CASE 
                    WHEN al.payments_per_year > 0 THEN 
                        FLOOR(DATEDIFF(COALESCE(a.date_closed, CURDATE()), a.date_opened) * al.payments_per_year / 365.0)
                    ELSE 
                        FLOOR(DATEDIFF(COALESCE(a.date_closed, CURDATE()), a.date_opened) / 30.0)
                END
            ))
        ELSE NULL
    END as Number_of_Paid_Installments,
    
    -- IMPORTANT DATES
    a.date_opened as Creation_Date,
    al.next_payment_date as Next_Payment_Date,
    a.date_closed as Closure_Date,
    
    -- CREDIT INFORMATION
    al.credit_score as Credit_Score,
    
    -- LOAN STATUS (including delinquency status)
    CASE 
        WHEN a.date_closed IS NULL AND a.current_balance > 0 AND al.next_payment_date IS NOT NULL AND al.next_payment_date < CURDATE() THEN 'DELINQUENT'
        WHEN a.date_closed IS NULL AND a.current_balance > 0 THEN 'ACTIVE'
        WHEN a.date_closed IS NOT NULL THEN 'CLOSED'
        WHEN a.current_balance = 0 AND a.date_closed IS NULL THEN 'PAID_OFF'
        ELSE 'INACTIVE'
    END as Status,
    
    -- DAYS PAST DUE (calculated from next_payment_date)
    CASE 
        WHEN al.next_payment_date IS NOT NULL AND al.next_payment_date < CURDATE() 
        THEN DATEDIFF(CURDATE(), al.next_payment_date)
        ELSE 0 
    END as Days_Past_Due,
    
    -- DELINQUENCY BRACKET (day ranges)
    CASE 
        WHEN al.next_payment_date IS NULL OR al.next_payment_date >= CURDATE() THEN 'CURRENT'
        WHEN DATEDIFF(CURDATE(), al.next_payment_date) BETWEEN 1 AND 30 THEN '1-30 days'
        WHEN DATEDIFF(CURDATE(), al.next_payment_date) BETWEEN 31 AND 60 THEN '31-60 days'
        WHEN DATEDIFF(CURDATE(), al.next_payment_date) BETWEEN 61 AND 90 THEN '61-90 days'
        WHEN DATEDIFF(CURDATE(), al.next_payment_date) BETWEEN 91 AND 120 THEN '91-120 days'
        WHEN DATEDIFF(CURDATE(), al.next_payment_date) > 120 THEN 'Over 120 days'
        ELSE 'CURRENT'
    END as Delinquency_Bracket,
    
    -- TOTAL DELINQUENCY OCCURRENCES (sum of all counters)
    COALESCE(al.delq_count_30, 0) + COALESCE(al.delq_count_60, 0) + COALESCE(al.delq_count_90, 0) + 
    COALESCE(al.delq_count_120, 0) + COALESCE(al.delq_count_150, 0) + COALESCE(al.delq_count_180, 0) as Total_Delinquency_Occurrences,
    
    -- FINANCIAL BALANCES
    ROUND(al.opening_balance, 2) as Initial_Balance,
    ROUND(a.current_balance, 2) as Current_Balance,
    
    -- EARNINGS/PROFITABILITY CALCULATIONS
    -- Interest Income (total accumulated interest earned)
    ROUND(COALESCE(al.interest_ytd, 0) + COALESCE(al.interest_lytd, 0), 2) as Total_Interest_Earned,
    ROUND(al.interest_ytd, 2) as Interest_Earned_YTD,
    ROUND(al.interest_lytd, 2) as Interest_Earned_LYTD,
    
    -- Late Fee Income
    ROUND(COALESCE(al.late_fees_ytd, 0) + COALESCE(al.late_fees_lytd, 0), 2) as Total_Late_Fees_Earned,
    ROUND(al.late_fees_ytd, 2) as Late_Fees_YTD,
    ROUND(al.late_fees_lytd, 2) as Late_Fees_LYTD,
    
    -- Total Revenue from Loan
    ROUND(
        COALESCE(al.interest_ytd, 0) + COALESCE(al.interest_lytd, 0) + 
        COALESCE(al.late_fees_ytd, 0) + COALESCE(al.late_fees_lytd, 0), 2
    ) as Total_Revenue_Earned,
    
    -- Profitability Ratios and Metrics
    CASE 
        WHEN al.opening_balance > 0 THEN 
            ROUND((COALESCE(al.interest_ytd, 0) + COALESCE(al.interest_lytd, 0)) / al.opening_balance * 100, 3)
        ELSE 0 
    END as Interest_Yield_Percentage,
    
    -- Monthly Interest Rate (from annual rate)
    ROUND(al.interest_rate / 12, 6) as Monthly_Interest_Rate,
    
    -- Expected vs Actual Interest (for performance analysis)
    CASE 
        WHEN a.date_opened IS NOT NULL AND al.opening_balance > 0 AND al.interest_rate > 0 THEN
            ROUND(
                al.opening_balance * (al.interest_rate / 100) * 
                DATEDIFF(COALESCE(a.date_closed, CURDATE()), a.date_opened) / 365.0, 2
            )
        ELSE 0
    END as Expected_Interest_Simple,
    
    -- Interest Performance Ratio (Actual vs Expected)
    CASE 
        WHEN a.date_opened IS NOT NULL AND al.opening_balance > 0 AND al.interest_rate > 0 THEN
            ROUND(
                (COALESCE(al.interest_ytd, 0) + COALESCE(al.interest_lytd, 0)) / 
                NULLIF(al.opening_balance * (al.interest_rate / 100) * 
                       DATEDIFF(COALESCE(a.date_closed, CURDATE()), a.date_opened) / 365.0, 0) * 100, 2
            )
        ELSE NULL
    END as Interest_Performance_Ratio

FROM account a
INNER JOIN account_loan al ON a.account_id = al.account_id
CROSS JOIN cu_info ci
WHERE a.discriminator = 'L' AND a.account_type NOT IN ('CC', 'PCO', 'PCCO')
ORDER BY a.member_number, a.account_id