WITH cu_info AS (
    SELECT credit_union_name
    FROM "AwsDataCatalog"."silver-mvp-know"."credit_union_info"
    WHERE flag_inactive <> 'Y'
    ORDER BY record_number
    LIMIT 1
)
SELECT
    -- Identification
    a.member_number AS Member_ID,
    ci.credit_union_name AS CU_Name,
    a.account_id AS Loan_ID,

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
    END AS Loan_Main_Category,

    -- SUB CATEGORY - Specific loan type description
    CASE
        WHEN a.account_type = 'UNSC' THEN 'Unsecured Personal Loan'
        WHEN a.account_type = 'IA'   THEN 'Immediate Access Loan'
        WHEN a.account_type = 'DUAU' THEN 'Direct Auto Loan'
        WHEN a.account_type = 'CC'   THEN 'Credit Card'
        WHEN a.account_type = 'SSEC' THEN 'Share Secured Loan'
        WHEN a.account_type = 'DRV'  THEN 'Used Vehicle Loan'
        WHEN a.account_type = 'DMO'  THEN 'Direct Mobile Auto Loan'
        WHEN a.account_type = 'DNAU' THEN 'Direct New Auto Loan'
        WHEN a.account_type = 'ICUL' THEN 'Indirect Auto Loan'
        WHEN a.account_type = 'QREG' THEN 'Quick Regular Loan'
        WHEN a.account_type = 'SHL2' THEN 'Share Secured Loan Type 2'
        WHEN a.account_type = 'HELO' THEN 'Home Equity Line of Credit (HELOC)'
        WHEN a.account_type = 'HE26' THEN 'Home Equity Loan 26'
        WHEN a.account_type = 'PCCO' THEN 'Prepaid Credit Card'
        WHEN a.account_type = 'OL'   THEN 'Other Loans'
        WHEN a.account_type = 'SHL'  THEN 'Share Secured Loan'
        WHEN a.account_type = 'FR20' THEN 'Fast Rate 20 Loan'
        WHEN a.account_type = 'OD'   THEN 'Overdraft Protection'
        WHEN a.account_type = 'MORT' THEN 'Mortgage Loan'
        WHEN a.account_type = 'QSPC' THEN 'Quick Special Loan'
        WHEN a.account_type = 'PCO'  THEN 'Prepaid Card Loan'
        WHEN a.account_type = 'HE6'  THEN 'Home Equity Loan 6'
        WHEN a.account_type = 'SPS'  THEN 'Special Purpose Loan'
        WHEN a.account_type = 'HE24' THEN 'Home Equity Loan 24'
        ELSE a.account_type
    END AS Loan_Sub_Category,

    -- FINANCIAL INFORMATION AND TERMS
    ROUND(al.interest_rate, 3) AS Interest_Rate,
    al.number_of_payments AS Number_of_Installments,

    -- PAID INSTALLMENTS (Estimated)
    CASE
        WHEN a.date_closed IS NOT NULL THEN al.number_of_payments
        WHEN al.number_of_payments IS NOT NULL AND al.number_of_payments > 0 AND a.date_opened IS NOT NULL THEN
            greatest(
                0,
                least(
                    al.number_of_payments,
                    CASE
                        WHEN al.payments_per_year > 0 THEN
                            floor(
                                date_diff('day', a.date_opened, coalesce(a.date_closed, current_date)) * al.payments_per_year / 365.0
                            )
                        ELSE
                            floor(
                                date_diff('day', a.date_opened, coalesce(a.date_closed, current_date)) / 30.0
                            )
                    END
                )
            )
        ELSE NULL
    END AS Number_of_Paid_Installments,

    -- IMPORTANT DATES
    a.date_opened AS Creation_Date,
    al.next_payment_date AS Next_Payment_Date,
    a.date_closed AS Closure_Date,

    -- CREDIT INFORMATION
    al.credit_score AS Credit_Score,

    -- LOAN STATUS
    CASE
        WHEN a.date_closed IS NULL AND a.current_balance > 0 AND al.next_payment_date IS NOT NULL
             AND al.next_payment_date < current_date THEN 'DELINQUENT'
        WHEN a.date_closed IS NULL AND a.current_balance > 0 THEN 'ACTIVE'
        WHEN a.date_closed IS NOT NULL THEN 'CLOSED'
        WHEN a.current_balance = 0 AND a.date_closed IS NULL THEN 'PAID_OFF'
        ELSE 'INACTIVE'
    END AS Status,

    -- DAYS PAST DUE
    CASE
        WHEN al.next_payment_date IS NOT NULL AND al.next_payment_date < current_date
            THEN date_diff('day', al.next_payment_date, current_date)
        ELSE 0
    END AS Days_Past_Due,

    -- DELINQUENCY BRACKET
    CASE
        WHEN al.next_payment_date IS NULL OR al.next_payment_date >= current_date THEN 'CURRENT'
        WHEN date_diff('day', al.next_payment_date, current_date) BETWEEN 1  AND 30  THEN '1-30 days'
        WHEN date_diff('day', al.next_payment_date, current_date) BETWEEN 31 AND 60  THEN '31-60 days'
        WHEN date_diff('day', al.next_payment_date, current_date) BETWEEN 61 AND 90  THEN '61-90 days'
        WHEN date_diff('day', al.next_payment_date, current_date) BETWEEN 91 AND 120 THEN '91-120 days'
        WHEN date_diff('day', al.next_payment_date, current_date) > 120 THEN 'Over 120 days'
        ELSE 'CURRENT'
    END AS Delinquency_Bracket,

    -- TOTAL DELINQUENCY OCCURRENCES
    coalesce(al.delq_count_30, 0) + coalesce(al.delq_count_60, 0) + coalesce(al.delq_count_90, 0) +
    coalesce(al.delq_count_120, 0) + coalesce(al.delq_count_150, 0) + coalesce(al.delq_count_180, 0)
        AS Total_Delinquency_Occurrences,

    -- FINANCIAL BALANCES
    ROUND(al.opening_balance, 2) AS Initial_Balance,
    ROUND(a.current_balance, 2) AS Current_Balance,

    -- EARNINGS / PROFITABILITY
    ROUND(coalesce(al.interest_ytd, 0) + coalesce(al.interest_lytd, 0), 2) AS Total_Interest_Earned,
    ROUND(al.interest_ytd, 2)  AS Interest_Earned_YTD,
    ROUND(al.interest_lytd, 2) AS Interest_Earned_LYTD,

    ROUND(coalesce(al.late_fees_ytd, 0) + coalesce(al.late_fees_lytd, 0), 2) AS Total_Late_Fees_Earned,
    ROUND(al.late_fees_ytd, 2)  AS Late_Fees_YTD,
    ROUND(al.late_fees_lytd, 2) AS Late_Fees_LYTD,

    ROUND(
        coalesce(al.interest_ytd, 0) + coalesce(al.interest_lytd, 0) +
        coalesce(al.late_fees_ytd, 0) + coalesce(al.late_fees_lytd, 0), 2
    ) AS Total_Revenue_Earned,

    CASE
        WHEN al.opening_balance > 0 THEN
            ROUND((coalesce(al.interest_ytd, 0) + coalesce(al.interest_lytd, 0)) / al.opening_balance * 100, 3)
        ELSE 0
    END AS Interest_Yield_Percentage,

    ROUND(al.interest_rate / 12, 6) AS Monthly_Interest_Rate,

    CASE
        WHEN a.date_opened IS NOT NULL AND al.opening_balance > 0 AND al.interest_rate > 0 THEN
            ROUND(
                al.opening_balance * (al.interest_rate / 100) *
                (date_diff('day', a.date_opened, coalesce(a.date_closed, current_date)) / 365.0),
                2
            )
        ELSE 0
    END AS Expected_Interest_Simple,

    CASE
        WHEN a.date_opened IS NOT NULL AND al.opening_balance > 0 AND al.interest_rate > 0 THEN
            ROUND(
                (coalesce(al.interest_ytd, 0) + coalesce(al.interest_lytd, 0)) /
                NULLIF(
                    al.opening_balance * (al.interest_rate / 100) *
                    (date_diff('day', a.date_opened, coalesce(a.date_closed, current_date)) / 365.0),
                    0
                ) * 100,
                2
            )
        ELSE NULL
    END AS Interest_Performance_Ratio

FROM "AwsDataCatalog"."silver-mvp-know"."account" a
INNER JOIN "AwsDataCatalog"."silver-mvp-know"."account_loan" al
    ON a.account_id   = al.account_id
   AND a.credit_union = al.credit_union
CROSS JOIN cu_info ci
WHERE UPPER(TRIM(a.discriminator)) = 'L'
  AND UPPER(TRIM(a.account_type)) NOT IN ('CC','PCO','PCCO')
ORDER BY a.member_number, a.account_id;
