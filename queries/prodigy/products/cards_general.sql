WITH 
-- Debit/ATM Cards from eft_card_file
debit_atm_cards AS (
    SELECT 
        ecf.member_number as member_id,
        CAST(ecf.record_number AS CHAR) as card_id,
        CAST(RIGHT(ecf.record_number, 4) AS CHAR) as last_4_digits,
        
        -- Card Type Classification
        CAST(CASE 
            WHEN ecf.card_type = 'D' THEN 'Debit'
            WHEN ecf.card_type = 'DI' THEN 'Debit Instant'
            WHEN ecf.card_type = 'A' THEN 'ATM'
            ELSE 'Other Debit'
        END AS CHAR) as card_type,
        
        -- Card Brand (derived from vendor or card description)
        CAST(CASE 
            WHEN ecf.card_description LIKE '%VISA%' THEN 'VISA'
            WHEN ecf.card_description LIKE '%MASTER%' THEN 'MASTERCARD'
            WHEN ecf.card_description LIKE '%DISCOVER%' THEN 'DISCOVER'
            WHEN ecf.vendor_number = '1' THEN 'VISA'
            WHEN ecf.vendor_number = '2' THEN 'MASTERCARD'
            ELSE 'Unknown'
        END AS CHAR) as card_brand,
        
        ecf.issue_date as creation_date,
        ecf.block_date as deleted_date,
        ecf.expire_date as expiration_date,
        
        -- Balance (for debit cards, use linked account balance)
        COALESCE(ecf.share_acct_bal, ecf.draft_acct_bal, 0) as balance_or_credit_limit,
        
        -- Credit fields (NULL for debit cards)
        CAST(NULL AS DECIMAL(15,2)) as credit_used,
        CAST(NULL AS DECIMAL(15,2)) as credit_used_percentage,
        
        -- Status Analysis
        CAST(CASE 
            WHEN ecf.block_date IS NOT NULL THEN 'Blocked'
            WHEN ecf.reject_code IN ('34', '43') THEN 'Fraud Block'
            WHEN ecf.reject_code IN ('36', '41') THEN 'Lost/Stolen Block'
            WHEN ecf.reject_code = '07' THEN 'Special Handling'
            WHEN ecf.expire_date < CURDATE() THEN 'Expired'
            WHEN ecf.last_pin_used_date IS NOT NULL THEN 'Active'
            WHEN ecf.issue_date IS NOT NULL THEN 'Issued Not Used'
            ELSE 'Unknown'
        END AS CHAR) as status,
        
        -- Delinquency (N/A for debit cards)
        CAST('N/A' AS CHAR) as delinquency_bracket,
        
        -- Activation Information
        ecf.last_pin_used_date as activation_date,
        CAST(CASE WHEN ecf.last_pin_used_date IS NOT NULL THEN 'True' ELSE 'False' END AS CHAR) as is_activated,
        
        -- Fraud Incident Flag
        CAST(CASE 
            WHEN ecf.reject_code IN ('34', '43') THEN 'True'
            WHEN ecf.lost_or_stolen != ' ' AND ecf.lost_or_stolen IS NOT NULL THEN 'True'
            ELSE 'False'
        END AS CHAR) as fraud_incident,
        
        -- For activity check
        ecf.last_pin_used_date as last_activity_date,
        
        -- Card Source
        CAST('Physical Debit/ATM' AS CHAR) as card_source
        
    FROM eft_card_file ecf
    WHERE ecf.card_type IN ('D', 'DI', 'A')  -- Debit, Debit Instant, and ATM cards only
),

-- Physical Credit Cards from eft_card_file
physical_credit_cards AS (
    SELECT 
        ecf.member_number as member_id,
        CAST(ecf.record_number AS CHAR) as card_id,
        CAST(RIGHT(ecf.record_number, 4) AS CHAR) as last_4_digits,
        
        -- Card Type Classification
        CAST(CASE 
            WHEN ecf.card_type = 'C' THEN 'Credit Gold'
            WHEN ecf.card_type = 'PC' THEN 'Credit Platinum'
            ELSE 'Credit Card'
        END AS CHAR) as card_type,
        
        -- Card Brand
        CAST(CASE 
            WHEN ecf.card_description LIKE '%VISA%' THEN 'VISA'
            WHEN ecf.card_description LIKE '%MASTER%' THEN 'MASTERCARD'
            WHEN ecf.card_description LIKE '%DISCOVER%' THEN 'DISCOVER'
            WHEN ecf.vendor_number = '1' THEN 'VISA'
            WHEN ecf.vendor_number = '2' THEN 'MASTERCARD'
            ELSE 'Unknown'
        END AS CHAR) as card_brand,
        
        ecf.issue_date as creation_date,
        ecf.block_date as deleted_date,
        ecf.expire_date as expiration_date,
        
        -- For physical credit cards, try to get credit limit from description or use 0
        CAST(0 AS DECIMAL(15,2)) as balance_or_credit_limit,  -- Credit limit not stored in eft_card_file
        CAST(0 AS DECIMAL(15,2)) as credit_used,
        CAST(0 AS DECIMAL(15,2)) as credit_used_percentage,
        
        -- Status Analysis
        CAST(CASE 
            WHEN ecf.block_date IS NOT NULL THEN 'Blocked'
            WHEN ecf.reject_code IN ('34', '43') THEN 'Fraud Block'
            WHEN ecf.reject_code IN ('36', '41') THEN 'Lost/Stolen Block'
            WHEN ecf.reject_code = '07' THEN 'Special Handling'
            WHEN ecf.expire_date < CURDATE() THEN 'Expired'
            WHEN ecf.last_pin_used_date IS NOT NULL THEN 'Active'
            WHEN ecf.issue_date IS NOT NULL THEN 'Issued Not Used'
            ELSE 'Unknown'
        END AS CHAR) as status,
        
        -- Delinquency (N/A for physical credit cards without account link)
        CAST('N/A' AS CHAR) as delinquency_bracket,
        
        -- Activation Information
        ecf.last_pin_used_date as activation_date,
        CAST(CASE WHEN ecf.last_pin_used_date IS NOT NULL THEN 'True' ELSE 'False' END AS CHAR) as is_activated,
        
        -- Fraud Incident Flag
        CAST(CASE 
            WHEN ecf.reject_code IN ('34', '43') THEN 'True'
            WHEN ecf.lost_or_stolen != ' ' AND ecf.lost_or_stolen IS NOT NULL THEN 'True'
            ELSE 'False'
        END AS CHAR) as fraud_incident,
        
        -- For activity check
        ecf.last_pin_used_date as last_activity_date,
        
        -- Card Source
        CAST('Physical Credit' AS CHAR) as card_source
        
    FROM eft_card_file ecf
    WHERE ecf.card_type IN ('C', 'PC')  -- Credit cards only
),

-- Credit Card Accounts from account_loan joined with account for member info
credit_card_accounts AS (
    SELECT 
        a.member_number as member_id,
        CAST(al.account_id AS CHAR) as card_id,
        CAST('****' AS CHAR) as last_4_digits,  -- Card numbers not stored in loan table
        
        CAST('Credit Account' AS CHAR) as card_type,
        CAST('Unknown' AS CHAR) as card_brand,  -- Brand info not available in loan table
        
        COALESCE(al.funded_date, a.date_opened) as creation_date,
        a.date_closed as deleted_date,
        al.credit_expiration as expiration_date,
        
        -- Credit Card Financial Information
        al.credit_limit as balance_or_credit_limit,
        a.current_balance as credit_used,
        CASE 
            WHEN al.credit_limit > 0 THEN ROUND((a.current_balance * 100.0) / al.credit_limit, 2)
            ELSE 0 
        END as credit_used_percentage,
        
        -- Status Analysis - CORRECTED to use next_payment_date for delinquency
        CAST(CASE 
            WHEN a.date_closed IS NOT NULL THEN 'Closed'
            WHEN a.charge_off_date IS NOT NULL THEN 'Charged Off'
            WHEN al.next_payment_date IS NOT NULL AND DATEDIFF(CURDATE(), al.next_payment_date) > 30 THEN 'Delinquent'
            WHEN a.current_balance > al.credit_limit THEN 'Over Limit'
            WHEN a.status = 'ACTIVE' THEN 'Active'
            WHEN a.status = 'CLOSED' THEN 'Closed'
            WHEN a.status = 'FROZEN' THEN 'Frozen'
            ELSE 'Active'
        END AS CHAR) as status,
        
        -- Delinquency Bracket in 30-day blocks - CORRECTED to use next_payment_date
        CAST(CASE 
            WHEN al.next_payment_date IS NULL THEN 'Unknown'
            WHEN DATEDIFF(CURDATE(), al.next_payment_date) <= 0 THEN 'Current'
            WHEN DATEDIFF(CURDATE(), al.next_payment_date) BETWEEN 1 AND 30 THEN '1-30 Days'
            WHEN DATEDIFF(CURDATE(), al.next_payment_date) BETWEEN 31 AND 60 THEN '31-60 Days'
            WHEN DATEDIFF(CURDATE(), al.next_payment_date) BETWEEN 61 AND 90 THEN '61-90 Days'
            WHEN DATEDIFF(CURDATE(), al.next_payment_date) BETWEEN 91 AND 120 THEN '91-120 Days'
            WHEN DATEDIFF(CURDATE(), al.next_payment_date) > 120 THEN '120+ Days'
            ELSE 'Current'
        END AS CHAR) as delinquency_bracket,
        
        -- Activation (assume funded_date or opened_date as activation for credit cards)
        COALESCE(al.funded_date, a.date_opened) as activation_date,
        CAST(CASE WHEN COALESCE(al.funded_date, a.date_opened) IS NOT NULL THEN 'True' ELSE 'False' END AS CHAR) as is_activated,
        
        -- Fraud Incident (based on charge-offs or specific indicators)
        CAST(CASE 
            WHEN a.charge_off_date IS NOT NULL THEN 'True'
            WHEN a.status = 'FRAUD' THEN 'True'
            ELSE 'False'
        END AS CHAR) as fraud_incident,
        
        -- For activity check (use last payment date)
        al.last_payment_date as last_activity_date,
        
        -- Card Source
        CAST('Credit Account' AS CHAR) as card_source
        
    FROM account_loan al
    INNER JOIN account a ON al.account_id = a.account_id
    WHERE al.credit_limit > 0  -- Credit Card loans only
    AND a.discriminator = 'L'  -- Loan accounts
    AND a.member_number > 0
),

-- Member card type analysis
member_card_types AS (
    SELECT 
        member_id,
        CASE 
            WHEN COUNT(CASE WHEN card_source IN ('Physical Debit/ATM') THEN 1 END) > 0 
                AND COUNT(CASE WHEN card_source IN ('Physical Credit', 'Credit Account') THEN 1 END) > 0 
            THEN 'Both'
            WHEN COUNT(CASE WHEN card_source IN ('Physical Debit/ATM') THEN 1 END) > 0 
            THEN 'Debit Only'
            WHEN COUNT(CASE WHEN card_source IN ('Physical Credit', 'Credit Account') THEN 1 END) > 0 
            THEN 'Credit Only'
            ELSE 'Unknown'
        END as member_card_portfolio
    FROM (
        SELECT member_id, card_source FROM debit_atm_cards
        UNION ALL
        SELECT member_id, card_source FROM physical_credit_cards
        UNION ALL
        SELECT member_id, card_source FROM credit_card_accounts
    ) all_cards
    GROUP BY member_id
)

-- Final unified result
SELECT 
    uc.member_id,
    uc.card_id,
    uc.last_4_digits,
    uc.card_type,
    uc.card_brand,
    uc.creation_date,
    uc.deleted_date,
    uc.expiration_date,
    uc.balance_or_credit_limit,
    uc.credit_used,
    uc.credit_used_percentage,
    uc.status,
    uc.delinquency_bracket,
    uc.activation_date,
    uc.is_activated,
    
    -- Inactivity flag (no activity in 3 months)
    CASE 
        WHEN uc.last_activity_date IS NULL THEN 'True'
        WHEN DATEDIFF(CURDATE(), uc.last_activity_date) > 90 THEN 'True'
        ELSE 'False'
    END as inactivity_flag,
    
    uc.fraud_incident,
    uc.card_source,
    
    -- Member card portfolio type
    mct.member_card_portfolio

FROM (
    SELECT * FROM debit_atm_cards
    UNION ALL
    SELECT * FROM physical_credit_cards
    UNION ALL
    SELECT * FROM credit_card_accounts
) uc
LEFT JOIN member_card_types mct ON uc.member_id = mct.member_id

ORDER BY 
    uc.member_id, 
    uc.card_source,
    uc.card_type, 
    uc.creation_date desc