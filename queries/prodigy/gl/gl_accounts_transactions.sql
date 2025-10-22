+
SELECT 
    -- ===== TRANSACTION IDENTIFICATION =====
    h.record_number AS Transaction_ID,
    CAST(h.gl_account_number AS CHAR) AS GL_ID,
    gl.description AS GL_Name,
    gl.short_desc AS GL_Short_Name,
    h.description AS Transaction_Description,
    CONCAT(h.gl_account_number, '-', gl.short_desc) AS GL_Account_Concat,
    -- ===== BRANCH INFORMATION =====
    h.branch_config_id AS Branch_Config_ID,
    bc.branch_number AS Branch_Number,
    CASE 
        WHEN be.name_last = 'MINNEQUA WORKS CREDIT UNION - PAULINE MONTOYA' THEN 'MINNEQUA WORKS CR'
        WHEN be.name_last IS NULL THEN 'Unknown Branch'
        ELSE TRIM(be.name_last)
    END AS Branch_Name,
    CASE 
        WHEN bc.branch_number = '0' THEN 'HEADQUARTERS/CORPORATE'
        WHEN bc.branch_number = '1' THEN 'MAIN_BRANCH/PRIMARY'
        WHEN bc.branch_number = '2' THEN 'REGENCY/BUSINESS_SERVICES'
        WHEN bc.branch_number = '3' THEN 'PUEBLO_WEST/COMMUNITY'
        WHEN bc.branch_number = '4' THEN 'EAGLERIDGE/HIGH_VOLUME'
        WHEN bc.branch_number = '5' THEN 'NEPCO/MIXED_SERVICES'
        WHEN bc.branch_number = '6' THEN 'REMOTE_SERVICES/DIGITAL'
        ELSE 'OTHER_BRANCH'
    END AS Branch_Category,
    
    -- Enhanced branch activity level based on member distribution and transaction volume
    CASE 
        WHEN bc.branch_number = '0' THEN 'VERY_HIGH_ACTIVITY'     -- Headquarters: 28% members, 53% transactions
        WHEN bc.branch_number = '1' THEN 'HIGHEST_ACTIVITY'       -- Main: 39% members, 28% transactions
        WHEN bc.branch_number = '4' THEN 'HIGH_ACTIVITY'          -- Eagleridge: 17% members, 8% transactions
        WHEN bc.branch_number = '5' THEN 'MEDIUM_ACTIVITY'        -- NEPCO: 10% members, 8% transactions
        WHEN bc.branch_number = '3' THEN 'LOW_ACTIVITY'           -- Pueblo West: 3% members, 2% transactions
        WHEN bc.branch_number = '2' THEN 'MINIMAL_ACTIVITY'       -- Regency: 2% members, 1% transactions
        WHEN bc.branch_number = '6' THEN 'DIGITAL_ONLY'           -- Remote Services: <1% members, <1% transactions
        ELSE 'UNKNOWN_ACTIVITY'
    END AS Branch_Activity_Level,
    
    -- Member composition and specialization based on view_member analysis
    CASE 
        WHEN bc.branch_number = '0' THEN 'Corporate/Administrative Members'    -- Mixed eligibility, corporate functions
        WHEN bc.branch_number = '1' THEN 'Family/General Membership'          -- 39% total members, diverse eligibility
        WHEN bc.branch_number = '4' THEN 'Family/Community Focused'           -- High family eligibility concentration
        WHEN bc.branch_number = '5' THEN 'Mixed Community/Business'           -- Balanced member types
        WHEN bc.branch_number = '3' THEN 'Family/Community Satellite'         -- Family-focused satellite branch
        WHEN bc.branch_number = '2' THEN 'Customer/Business Services'         -- Highest CUS (Customer) eligibility ratio
        WHEN bc.branch_number = '6' THEN 'Digital/Remote Services'            -- Minimal physical presence
        ELSE 'Unknown Specialization'
    END AS Branch_Specialization,
    
    -- Member density indicator (members served per branch)
    CASE 
        WHEN bc.branch_number = '1' THEN 'HIGHEST_DENSITY'      -- 20,135 members
        WHEN bc.branch_number = '0' THEN 'VERY_HIGH_DENSITY'    -- 14,466 members
        WHEN bc.branch_number = '4' THEN 'HIGH_DENSITY'         -- 8,939 members
        WHEN bc.branch_number = '5' THEN 'MEDIUM_DENSITY'       -- 5,344 members
        WHEN bc.branch_number = '3' THEN 'LOW_DENSITY'          -- 1,675 members
        WHEN bc.branch_number = '2' THEN 'MINIMAL_DENSITY'      -- 975 members
        WHEN bc.branch_number = '6' THEN 'ULTRA_LOW_DENSITY'    -- 13 members
        ELSE 'UNKNOWN_DENSITY'
    END AS Branch_Member_Density,
    
    -- ===== ACCOUNT CLASSIFICATION =====
    gl.account_type AS Account_Type,
    CASE 
        WHEN gl.account_type = 'B' THEN 'Balance Sheet'
        WHEN gl.account_type = 'I' THEN 'Income Statement'
        ELSE 'Other'
    END AS Account_Category,
    
    -- Detailed subcategorization
    CASE 
        -- Balance Sheet Accounts
        WHEN gl.account_type = 'B' AND gl.account_number BETWEEN 700 AND 799 THEN 'ASSETS - Loans & Investments'
        WHEN gl.account_type = 'B' AND gl.account_number BETWEEN 800 AND 899 THEN 'ASSETS/LIABILITIES - Clearing & Payables'
        WHEN gl.account_type = 'B' AND gl.account_number BETWEEN 900 AND 999 THEN 'LIABILITIES - Deposits & Equity'
        -- Income Statement Accounts
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 110 AND 199 THEN 'INCOME - Interest & Fees'
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 200 AND 299 THEN 'EXPENSES - Personnel & Operations'
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 300 AND 399 THEN 'EXPENSES - Operations & Provisions'
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 400 AND 499 THEN 'OTHER - Miscellaneous Income/Expense'
        ELSE 'OTHER'
    END AS GL_Subcategory,
    
    -- ===== ACCOUNTING NATURE OF ACCOUNT =====
    -- Based on accounting principles: Assets/Expenses (Debit normal) vs Liabilities/Equity/Revenue (Credit normal)
    CASE 
        -- DEBIT NATURE: Assets and Expenses
        WHEN gl.account_type = 'B' AND gl.account_number BETWEEN 700 AND 899 THEN 'DEBIT_NATURE'  -- Assets (Loans, Investments, Clearing)
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 200 AND 399 THEN 'DEBIT_NATURE'  -- Expenses (Personnel, Operations)
        
        -- CREDIT NATURE: Liabilities, Equity and Revenue  
        WHEN gl.account_type = 'B' AND gl.account_number BETWEEN 900 AND 999 THEN 'CREDIT_NATURE' -- Liabilities/Equity (Deposits, Equity)
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 110 AND 199 THEN 'CREDIT_NATURE' -- Revenue (Interest, Fees)
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 400 AND 499 THEN 'CREDIT_NATURE' -- Other Revenue
        
        ELSE 'MIXED_NATURE'
    END AS Account_Nature,
    
    -- Detailed description of accounting nature
    CASE 
        WHEN gl.account_type = 'B' AND gl.account_number BETWEEN 700 AND 899 THEN 'ASSETS (Increase with Debits, Decrease with Credits)'
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 200 AND 399 THEN 'EXPENSES (Increase with Debits, Decrease with Credits)'
        WHEN gl.account_type = 'B' AND gl.account_number BETWEEN 900 AND 999 THEN 'LIABILITIES/EQUITY (Increase with Credits, Decrease with Debits)'
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 110 AND 199 THEN 'REVENUE (Increase with Credits, Decrease with Debits)'
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 400 AND 499 THEN 'OTHER REVENUE (Increase with Credits, Decrease with Debits)'
        ELSE 'MIXED OR UNCLASSIFIED NATURE'
    END AS Account_Nature_Description,
    
    -- ===== DATE AND TIME INFORMATION =====
    h.effective_date AS Effective_Date,
    h.reference_date AS Reference_Date,
    h.actual_date AS Posting_Date,
    
    -- Detailed temporal analysis
    DATE_FORMAT(h.effective_date, '%Y-%m') AS YearMonth,
    YEAR(h.effective_date) AS TransactionYear,
    MONTH(h.effective_date) AS TransactionMonth,
    MONTHNAME(h.effective_date) AS MonthName,
    QUARTER(h.effective_date) AS TransactionQuarter,
    DAY(h.effective_date) AS DayOfMonth,
    DAYNAME(h.effective_date) AS DayOfWeek,
    WEEKDAY(h.effective_date) + 1 AS DayOfWeekNumber,
    WEEK(h.effective_date, 3) AS ISOWeek,
    DAYOFYEAR(h.effective_date) AS DayOfYear,
    
    -- Business temporal classification
    CASE 
        WHEN WEEKDAY(h.effective_date) IN (5, 6) THEN 'Weekend'
        ELSE 'Weekday'
    END AS BusinessDayType,
    
    CASE 
        WHEN DAY(h.effective_date) <= 7 THEN 'First Week'
        WHEN DAY(h.effective_date) <= 14 THEN 'Second Week'
        WHEN DAY(h.effective_date) <= 21 THEN 'Third Week'
        ELSE 'Fourth Week+'
    END AS WeekOfMonth,
    
    -- ===== TRANSACTION INFORMATION =====
    h.source AS Txn_Source,
    CASE 
        WHEN h.source = 'CU' THEN 'Credit Union System (EOD Processing)'
        WHEN h.source = 'JE' THEN 'Journal Entry (Manual/System)'
        WHEN h.source = 'CT' THEN 'Certificate/Time Deposit'
        WHEN h.source = 'AP' THEN 'Accounts Payable'
        WHEN h.source = 'FA' THEN 'Fixed Assets/Depreciation'
        ELSE CONCAT('Other: ', h.source)
    END AS Txn_Source_Description,
    
    h.entry_desc AS Txn_Type,
    CASE 
        WHEN h.entry_desc = 'EOD' THEN 'End of Day Processing'
        WHEN h.entry_desc LIKE '%-%' THEN CONCAT('Manual Entry - User ', SUBSTRING(h.entry_desc, 1, 2))
        WHEN h.entry_desc = 'CERT ACCRUAL' THEN 'Certificate Interest Accrual'
        WHEN h.entry_desc = 'INVOICE' THEN 'Invoice Payment/Processing'
        WHEN h.entry_desc = 'Depreciation' THEN 'Asset Depreciation'
        WHEN h.entry_desc LIKE 'ME Loan%' THEN 'Member Loan Accrual'
        ELSE h.entry_desc
    END AS Txn_Type_Description,
    
    -- ===== AMOUNTS AND DEBIT/CREDIT =====
    h.amount AS Amount,
    ABS(h.amount) AS Abs_Amount,
    CASE 
        WHEN h.amount > 0 THEN 'Debit' -- In GL, positive amounts are debits
        WHEN h.amount < 0 THEN 'Credit' -- In GL, negative amounts are credits
        ELSE 'Zero'
    END AS Debit_Credit,
    
    CASE 
        WHEN h.amount > 0 THEN h.amount
        ELSE 0
    END AS Debit_Amount,
    
    CASE 
        WHEN h.amount < 0 THEN ABS(h.amount)
        ELSE 0
    END AS Credit_Amount,
    
    -- ===== ACCOUNTING IMPACT BASED ON ACCOUNT NATURE =====
    -- Determines if the movement increases or decreases the account according to its accounting nature
    CASE 
        -- For DEBIT NATURE accounts (Assets/Expenses): Debit increases, Credit decreases
        WHEN (gl.account_type = 'B' AND gl.account_number BETWEEN 700 AND 899) OR 
             (gl.account_type = 'I' AND gl.account_number BETWEEN 200 AND 399) THEN
            CASE 
                WHEN h.amount > 0 THEN 'INCREASE' -- Debit increases debit nature account
                WHEN h.amount < 0 THEN 'DECREASE' -- Credit decreases debit nature account
                ELSE 'NO_CHANGE'
            END
        
        -- For CREDIT NATURE accounts (Liabilities/Equity/Revenue): Credit increases, Debit decreases  
        WHEN (gl.account_type = 'B' AND gl.account_number BETWEEN 900 AND 999) OR
             (gl.account_type = 'I' AND gl.account_number BETWEEN 110 AND 199) OR
             (gl.account_type = 'I' AND gl.account_number BETWEEN 400 AND 499) THEN
            CASE 
                WHEN h.amount > 0 THEN 'DECREASE' -- Debit decreases credit nature account
                WHEN h.amount < 0 THEN 'INCREASE' -- Credit increases credit nature account
                ELSE 'NO_CHANGE'
            END
        
        ELSE 'UNKNOWN_IMPACT'
    END AS Account_Impact,
    
    -- Detailed description of accounting impact
    CASE 
        -- For DEBIT NATURE accounts (Assets/Expenses)
        WHEN (gl.account_type = 'B' AND gl.account_number BETWEEN 700 AND 899) OR 
             (gl.account_type = 'I' AND gl.account_number BETWEEN 200 AND 399) THEN
            CASE 
                WHEN h.amount > 0 THEN CONCAT('INCREASES ', 
                    CASE WHEN gl.account_type = 'B' THEN 'ASSET' ELSE 'EXPENSE' END,
                    ' (Normal Debit)')
                WHEN h.amount < 0 THEN CONCAT('DECREASES ', 
                    CASE WHEN gl.account_type = 'B' THEN 'ASSET' ELSE 'EXPENSE' END,
                    ' (Contra Credit)')
                ELSE 'NO CHANGE'
            END
        
        -- For CREDIT NATURE accounts (Liabilities/Equity/Revenue)
        WHEN (gl.account_type = 'B' AND gl.account_number BETWEEN 900 AND 999) OR
             (gl.account_type = 'I' AND gl.account_number BETWEEN 110 AND 199) OR
             (gl.account_type = 'I' AND gl.account_number BETWEEN 400 AND 499) THEN
            CASE 
                WHEN h.amount > 0 THEN CONCAT('DECREASES ', 
                    CASE 
                        WHEN gl.account_type = 'B' THEN 'LIABILITY/EQUITY'
                        ELSE 'REVENUE' 
                    END,
                    ' (Contra Debit)')
                WHEN h.amount < 0 THEN CONCAT('INCREASES ', 
                    CASE 
                        WHEN gl.account_type = 'B' THEN 'LIABILITY/EQUITY'
                        ELSE 'REVENUE' 
                    END,
                    ' (Normal Credit)')
                ELSE 'NO CHANGE'
            END
        
        ELSE 'IMPACT NOT DETERMINED'
    END AS Account_Impact_Description,
    
    -- Transaction size classification
    CASE 
        WHEN ABS(h.amount) = 0 THEN 'Zero Amount'
        WHEN ABS(h.amount) < 100 THEN 'Small (< $100)'
        WHEN ABS(h.amount) < 1000 THEN 'Medium ($100 - $1K)'
        WHEN ABS(h.amount) < 10000 THEN 'Large ($1K - $10K)'
        WHEN ABS(h.amount) < 100000 THEN 'Very Large ($10K - $100K)'
        ELSE 'Exceptional ($100K+)'
    END AS Transaction_Size_Category,
    
    -- ===== PROCESSING INFORMATION =====
    h.batch_number AS Batch_Number,
    h.group_id AS Group_ID,
    h.group_seq AS Group_Sequence,
    h.posted_by_user AS Posted_By_User,
    
    -- ===== SPECIAL CHARACTERISTICS =====
    CASE 
        WHEN UPPER(h.description) LIKE '%DIVIDEND%' OR UPPER(h.description) LIKE '%DIV-%' THEN 'Dividend Transaction'
        WHEN UPPER(h.description) LIKE '%INTEREST%' OR UPPER(h.description) LIKE '%INT-%' THEN 'Interest Transaction'
        WHEN UPPER(h.description) LIKE '%FEE%' OR UPPER(h.description) LIKE '%CHARGE%' THEN 'Fee Transaction'
        WHEN UPPER(h.description) LIKE '%SUMMARY%' THEN 'Summary/Aggregated Transaction'
        WHEN UPPER(h.description) LIKE '%ACCRUAL%' OR UPPER(h.description) LIKE '%ACCR%' THEN 'Accrual Transaction'
        WHEN UPPER(h.description) LIKE '%REVERSAL%' OR UPPER(h.description) LIKE '%REV%' THEN 'Reversal Transaction'
        WHEN UPPER(h.description) LIKE '%CORRECTION%' OR UPPER(h.description) LIKE '%CORR%' THEN 'Correction Transaction'
        WHEN UPPER(h.description) LIKE '%ADJUSTMENT%' OR UPPER(h.description) LIKE '%ADJ%' THEN 'Adjustment Transaction'
        ELSE 'Regular Transaction'
    END AS Transaction_Nature,
    
    -- Automatic vs manual transaction indicators
    CASE 
        WHEN h.source = 'CU' AND h.entry_desc = 'EOD' THEN 'Automated EOD'
        WHEN h.source = 'JE' AND h.entry_desc LIKE '%-%' THEN 'Manual Entry'
        WHEN h.source IN ('CT', 'AP', 'FA') THEN 'System Generated'
        ELSE 'Other Processing'
    END AS Processing_Type,
    
    -- ===== AUDIT INFORMATION =====
    h.status AS Record_Status,
    h.modified AS Modified_Flag,
    h.version AS Record_Version,
    h.created_timestamp AS Record_Created,
    h.created_by_userid AS Created_By_User,
    h.modified_timestamp AS Record_Modified,
    h.modified_by_userid AS Modified_By_User,
    
    -- ===== ADDITIONAL ACCOUNT INFORMATION =====
    gl.inactive AS Account_Inactive,
    gl.restricted AS Account_Restricted,
    gl.controlled AS Account_Controlled,
    gl.balance AS Current_Account_Balance,
    
    -- ===== ANALYSIS INDICATORS =====
    -- Volume classification based on standard ranges
    CASE 
        WHEN ABS(h.amount) > 500000 THEN 'Exceptional Volume'
        WHEN ABS(h.amount) > 100000 THEN 'Very High Volume'
        WHEN ABS(h.amount) > 10000 THEN 'High Volume'
        ELSE 'Standard Volume'
    END AS Volume_Indicator,
    
    -- Account frequency indicator (simplified for performance)
    -- Note: For detailed frequency analysis, run separate query
    CASE 
        WHEN gl.account_type = 'B' AND gl.account_number BETWEEN 860 AND 899 THEN 'High Activity Account'
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 110 AND 199 THEN 'High Activity Account'
        ELSE 'Standard Activity Account'
    END AS Expected_Activity_Level,
    
    -- ===== ADVANCED ACCOUNTING ANALYSIS =====
    -- Accounting consistency and transaction pattern indicators
    
    -- Consistency with account nature
    CASE 
        -- Transactions that follow the account's normal nature
        WHEN (gl.account_type = 'B' AND gl.account_number BETWEEN 700 AND 899 AND h.amount > 0) OR -- Assets with debit
             (gl.account_type = 'I' AND gl.account_number BETWEEN 200 AND 399 AND h.amount > 0) OR -- Expenses with debit
             (gl.account_type = 'B' AND gl.account_number BETWEEN 900 AND 999 AND h.amount < 0) OR -- Liabilities/Equity with credit
             (gl.account_type = 'I' AND gl.account_number BETWEEN 110 AND 199 AND h.amount < 0) OR -- Revenue with credit
             (gl.account_type = 'I' AND gl.account_number BETWEEN 400 AND 499 AND h.amount < 0)    -- Other revenue with credit
        THEN 'NORMAL_PATTERN'
        
        -- Transactions against nature (may be adjustments, reversals, etc.)
        WHEN (gl.account_type = 'B' AND gl.account_number BETWEEN 700 AND 899 AND h.amount < 0) OR -- Assets with credit
             (gl.account_type = 'I' AND gl.account_number BETWEEN 200 AND 399 AND h.amount < 0) OR -- Expenses with credit
             (gl.account_type = 'B' AND gl.account_number BETWEEN 900 AND 999 AND h.amount > 0) OR -- Liabilities/Equity with debit
             (gl.account_type = 'I' AND gl.account_number BETWEEN 110 AND 199 AND h.amount > 0) OR -- Revenue with debit
             (gl.account_type = 'I' AND gl.account_number BETWEEN 400 AND 499 AND h.amount > 0)    -- Other revenue with debit
        THEN 'CONTRA_PATTERN'
        
        ELSE 'UNDEFINED_PATTERN'
    END AS Transaction_Pattern,
    
    -- Accounting risk analysis
    CASE 
        WHEN h.amount = 0 THEN 'ZERO_RISK'
        WHEN ABS(h.amount) > 100000 AND 
             ((gl.account_type = 'B' AND gl.account_number BETWEEN 700 AND 899 AND h.amount < 0) OR
              (gl.account_type = 'B' AND gl.account_number BETWEEN 900 AND 999 AND h.amount > 0))
        THEN 'HIGH_RISK_LARGE_CONTRA'
        WHEN h.source = 'JE' AND h.entry_desc LIKE '%-%' AND ABS(h.amount) > 10000
        THEN 'MEDIUM_RISK_MANUAL_LARGE'
        WHEN UPPER(h.description) LIKE '%REVERSAL%' OR UPPER(h.description) LIKE '%CORRECTION%'
        THEN 'MEDIUM_RISK_ADJUSTMENT'
        ELSE 'LOW_RISK'
    END AS Risk_Level,
    
    -- Final simplified accounting category
    CASE 
        WHEN gl.account_type = 'B' AND gl.account_number BETWEEN 700 AND 899 THEN 'ASSETS'
        WHEN gl.account_type = 'B' AND gl.account_number BETWEEN 900 AND 999 THEN 'LIABILITIES_EQUITY'
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 110 AND 199 THEN 'REVENUE'
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 200 AND 399 THEN 'EXPENSES'
        WHEN gl.account_type = 'I' AND gl.account_number BETWEEN 400 AND 499 THEN 'OTHER_INCOME'
        ELSE 'UNCATEGORIZED'
    END AS Accounting_Category,
    
    -- ===== BRANCH ANALYSIS =====
    -- Branch-specific transaction patterns and risk assessment
    CASE 
        WHEN bc.branch_number = '0' AND ABS(h.amount) > 1000000 THEN 'HQ_LARGE_TRANSACTION'
        WHEN bc.branch_number != '0' AND ABS(h.amount) > 100000 THEN 'BRANCH_LARGE_TRANSACTION'
        WHEN bc.branch_number = '6' AND ABS(h.amount) > 1000 THEN 'REMOTE_UNUSUAL_AMOUNT'
        ELSE 'NORMAL_BRANCH_TRANSACTION'
    END AS Branch_Transaction_Pattern,
    
    -- Cross-branch transaction indicator
    CASE 
        WHEN h.source = 'JE' AND bc.branch_number != '0' THEN 'BRANCH_MANUAL_ENTRY'
        WHEN h.source = 'CU' AND bc.branch_number = '0' THEN 'HQ_SYSTEM_TRANSACTION'
        WHEN h.source = 'CU' AND bc.branch_number != '0' THEN 'BRANCH_SYSTEM_TRANSACTION'
        ELSE 'OTHER_BRANCH_TRANSACTION'
    END AS Branch_Transaction_Type

FROM gl_history h
INNER JOIN gl_chart_of_accounts gl ON gl.account_number = h.gl_account_number
LEFT JOIN branch_config bc ON h.branch_config_id = bc.branch_config_id
LEFT JOIN entity be ON bc.branch_entity_id = be.entity_id

-- Filter by specific period (last 36 months for better performance)
WHERE h.effective_date >= DATE_SUB(CURDATE(), INTERVAL 36 MONTH)
  AND gl.account_type IN ('B', 'I')

ORDER BY 
    h.effective_date DESC,
    h.record_number DESC