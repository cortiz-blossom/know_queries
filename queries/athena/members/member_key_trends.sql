SELECT
    m."credit_union" AS "credit_union",
    fi.idfi AS idfi,
    m.member_id,
    m.member_number,
    -- NEW: Filter columns for dashboard (same as product_overview.sql and query_prodigy.sql)
    CASE WHEN m.member_number > 0 THEN 'Valid' ELSE 'Invalid' END AS 'member_number_is_valid',
    CASE WHEN m.inactive_flag = 'I' THEN 'Inactive Flag' ELSE 'Active Flag' END AS 'member_inactive_flag_status',
    -- UPDATED: Match user query logic - exclude NULL values
    CASE 
        WHEN m.all_accounts_closed = 1 THEN 'All Closed'
        WHEN m.all_accounts_closed = 0 THEN 'Has Open Accounts'
        ELSE 'Unknown/NULL'
    END AS member_accounts_status,
    CASE 
            WHEN m.member_number IS NOT NULL 
             AND m.all_accounts_closed = 0 
             AND m.inactive_flag <> 'I'
            THEN 'Active'
            ELSE 'Inactive'
        END AS member_status,
    m.inactive_flag AS 'member_inactive_flag_code',
    m.all_accounts_closed AS 'member_all_accounts_closed_flag',
    CAST(m.join_date AS DATE) AS join_date,
    m.all_accounts_closed AS closed_membership,
    m.modified_timestamp,
    AVG(a.current_balance) AS average_balance,
    SUM(a.current_balance) AS total_balance,
    SUM(CASE WHEN UPPER(TRIM(a.discriminator)) IN ('S','D','C') THEN a.current_balance ELSE 0 END) AS total_deposits_balance,
    SUM(CASE WHEN UPPER(TRIM(a.discriminator)) = 'L' THEN a.current_balance ELSE 0 END) AS total_loans_balance
FROM "AwsDataCatalog"."silver-mvp-know"."member" m
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."account" a
  ON m.member_id = a.member_number
 AND m."credit_union" = a."credit_union"
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
  ON lower(trim(fi.prodigy_code)) = lower(trim(m."credit_union"))
GROUP BY
    m."credit_union",
    fi.idfi,
    m.member_id,
    m.member_number,
    m.join_date,
    m.inactive_flag,
    m.all_accounts_closed,
    m.modified_timestamp;
