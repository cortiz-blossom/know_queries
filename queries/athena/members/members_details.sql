SELECT
    a."credit_union" AS credit_union,
    fi.idfi AS idfi,
    a.account_id,
    a.account_number,
    COALESCE(a.description, '') AS description,
    a.current_balance,
    CASE
        WHEN a.date_closed IS NULL THEN 'Still Open'
        ELSE date_format(CAST(a.date_closed AS date), '%Y-%m-%d')
    END AS date_closed,
    a.date_opened,
    CASE
        WHEN a.date_closed IS NULL THEN 'Active'
        ELSE 'Closed'
    END AS product_status,
    CASE TRIM(a.discriminator)
        WHEN 'S' THEN 'Savings'
        WHEN 'D' THEN 'Checkings'
        WHEN 'L' THEN 'Loan'
        WHEN 'C' THEN 'Certificate'
        WHEN 'U' THEN 'Custom'
    END AS product_type,
    m.member_id,
    m.member_number,
    
    -- NEW: Filter columns for dashboard (same as other queries)
    CASE WHEN m.member_number > 0 THEN 'Valid' ELSE 'Invalid' END AS member_number_is_valid,
    CASE WHEN m.inactive_flag = 'I' THEN 'Inactive Flag' ELSE 'Active Flag' END AS member_inactive_flag_status,
    -- Treat NULL as "Has Open Accounts" (ELSE clause includes NULL values)
    CASE WHEN m.all_accounts_closed = 1 THEN 'All Closed' 
         ELSE 'Has Open Accounts' 
    END AS member_accounts_status,
    m.inactive_flag AS member_inactive_flag_code,
    m.all_accounts_closed AS member_all_accounts_closed_flag,
    
    e.address1,
    date_diff('year', CAST(e.dob AS date), current_date) AS age,
    CASE
        WHEN date_diff('year', CAST(e.dob AS date), current_date) BETWEEN 0  AND 17 THEN 'A. 0-17'
        WHEN date_diff('year', CAST(e.dob AS date), current_date) BETWEEN 18 AND 25 THEN 'B. 18-25'
        WHEN date_diff('year', CAST(e.dob AS date), current_date) BETWEEN 26 AND 35 THEN 'C. 26-35'
        WHEN date_diff('year', CAST(e.dob AS date), current_date) BETWEEN 36 AND 45 THEN 'D. 36-45'
        WHEN date_diff('year', CAST(e.dob AS date), current_date) BETWEEN 46 AND 55 THEN 'E. 46-55'
        WHEN date_diff('year', CAST(e.dob AS date), current_date) BETWEEN 56 AND 65 THEN 'F. 56-65'
        WHEN date_diff('year', CAST(e.dob AS date), current_date) BETWEEN 66 AND 75 THEN 'G. 66-75'
        WHEN date_diff('year', CAST(e.dob AS date), current_date) BETWEEN 76 AND 85 THEN 'H. 76-85'
        WHEN date_diff('year', CAST(e.dob AS date), current_date) > 85               THEN 'I. 85+'
        ELSE 'Unknown'
    END AS age_group,
    CASE
        WHEN e.name_first IS NULL OR e.name_first = '[NULL]'
            THEN CONCAT(UPPER(substr(e.name_last, 1, 1)), LOWER(substr(e.name_last, 2)))
        WHEN e.name_middle IS NOT NULL AND e.name_middle <> '[NULL]' AND e.name_middle <> ''
            THEN CONCAT(
                UPPER(substr(e.name_first, 1, 1)), LOWER(substr(e.name_first, 2)), ' ',
                UPPER(substr(e.name_middle, 1, 1)), LOWER(substr(e.name_middle, 2)), ' ',
                UPPER(substr(e.name_last, 1, 1)), LOWER(substr(e.name_last, 2))
            )
        ELSE CONCAT(
            UPPER(substr(e.name_first, 1, 1)), LOWER(substr(e.name_first, 2)), ' ',
            UPPER(substr(e.name_last, 1, 1)), LOWER(substr(e.name_last, 2))
        )
    END AS full_name,
    CAST(m.join_date AS date) AS join_date,
    CASE
        WHEN date_diff('day', m.join_date, current_date) < 183  THEN '1. Recent (0-6 months)'
        WHEN date_diff('day', m.join_date, current_date) < 365  THEN '2. New (6-12 months)'
        WHEN date_diff('day', m.join_date, current_date) < 1095 THEN '3. Established (1-3 years)'
        WHEN date_diff('day', m.join_date, current_date) < 1825 THEN '4. Mature (3-5 years)'
        ELSE '5. Veteran (5+ years)'
    END AS member_tenure_category,
    CASE
        WHEN TRIM(m.member_type) = 'P' THEN 'Personal'
        WHEN TRIM(m.member_type) = 'B' THEN 'Business'
        WHEN TRIM(m.member_type) = 'C' THEN 'Corporate Member'
        ELSE 'Unknown'
    END AS member_type,
    CASE
        WHEN m.home_bank_date IS NOT NULL THEN 'Active'
        ELSE 'Inactive'
    END AS online_banking_status
FROM "AwsDataCatalog"."silver-mvp-know"."account" a
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."member" m
  ON a.member_number = m.member_number
 AND a."credit_union" = m."credit_union"
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."entity" e
  ON m.member_entity_id = e.entity_id
 AND m."credit_union"   = e."credit_union"
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
  ON lower(trim(fi.prodigy_code)) = lower(trim(a."credit_union"))
WHERE
    a.account_id IS NOT NULL;
