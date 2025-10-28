SELECT
    m."credit_union" AS "credit_union",
    fi.idfi AS idfi,
    m.member_number AS member_id,
    CASE
        WHEN e.name_first IS NULL OR e.name_first = '[NULL]' THEN NULL
        ELSE CONCAT(UPPER(substr(e.name_first, 1, 1)), LOWER(substr(e.name_first, 2)))
    END AS first_name,
    CASE
        WHEN e.name_middle IS NULL OR e.name_middle = '[NULL]' THEN NULL
        ELSE CONCAT(UPPER(substr(e.name_middle, 1, 1)), LOWER(substr(e.name_middle, 2)))
    END AS middle_name,
    CONCAT(UPPER(substr(e.name_last, 1, 1)), LOWER(substr(e.name_last, 2))) AS last_name,
    e.preferred_name AS preferred_name,
    CASE
        WHEN e.name_first IS NULL OR e.name_first = '[NULL]'
            THEN CONCAT(UPPER(substr(e.name_last, 1, 1)), LOWER(substr(e.name_last, 2)))
        WHEN e.name_middle IS NOT NULL AND e.name_middle != '[NULL]' AND e.name_middle != ''
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
    year(current_date) - year(e.dob) AS age,
    CASE WHEN m.inactive_flag = 'I' THEN 'Inactive' ELSE 'Active' END AS member_status,

    -- NEW: Filter columns for dashboard (same as product_overview.sql)
    CASE WHEN m.member_number > 0 THEN 'Valid' ELSE 'Invalid' END AS member_number_is_valid,
    CASE WHEN m.inactive_flag = 'I' THEN 'Inactive Flag' ELSE 'Active Flag' END AS member_inactive_flag_status,
    -- Treat NULL as "Has Open Accounts" (ELSE clause includes NULL values)
    CASE WHEN m.all_accounts_closed = 1 THEN 'All Closed' 
         ELSE 'Has Open Accounts' 
    END AS member_accounts_status,
    m.inactive_flag AS member_inactive_flag_code,
    m.all_accounts_closed AS member_all_accounts_closed_flag,

    CASE
        WHEN m.member_type = 'P' THEN 'Personal'
        WHEN m.member_type = 'B' THEN 'Business'
        WHEN m.member_type = 'C' THEN 'Corporate Member'
        ELSE 'Unknown'
    END AS member_type,
    DATE(m.join_date) AS join_date,
    year(m.join_date) AS join_year,
    quarter(m.join_date) AS join_quarter,
    month(m.join_date) AS join_month,
    date_diff('day', m.join_date, current_date) AS member_tenure_days,
    CASE
        WHEN date_diff('day', m.join_date, current_date) < 183  THEN '1. Recent (0-6 months)'
        WHEN date_diff('day', m.join_date, current_date) < 365  THEN '2. New (6-12 months)'
        WHEN date_diff('day', m.join_date, current_date) < 1095 THEN '3. Established (1-3 years)'
        WHEN date_diff('day', m.join_date, current_date) < 1825 THEN '4. Mature (3-5 years)'
        ELSE '5. Veteran (5+ years)'
    END AS member_tenure_category,
    CASE
        WHEN e.gender = 'F' THEN 'Female'
        WHEN e.gender = 'M' THEN 'Male'
        WHEN e.gender = 'N' THEN 'Non-Binary'
        WHEN e.gender = 'O' THEN 'Opt Out'
        ELSE 'Unknown'
    END AS gender,
    CASE
        WHEN year(current_date) - year(e.dob) BETWEEN 0  AND 17 THEN '0-17'
        WHEN year(current_date) - year(e.dob) BETWEEN 18 AND 25 THEN '18-25'
        WHEN year(current_date) - year(e.dob) BETWEEN 26 AND 35 THEN '26-35'
        WHEN year(current_date) - year(e.dob) BETWEEN 36 AND 45 THEN '36-45'
        WHEN year(current_date) - year(e.dob) BETWEEN 46 AND 55 THEN '46-55'
        WHEN year(current_date) - year(e.dob) BETWEEN 56 AND 65 THEN '56-65'
        WHEN year(current_date) - year(e.dob) BETWEEN 66 AND 75 THEN '66-75'
        WHEN year(current_date) - year(e.dob) BETWEEN 76 AND 85 THEN '76-85'
        WHEN year(current_date) - year(e.dob) > 85               THEN '85+'
        ELSE 'Unknown'
    END AS age_group,
    year(current_date) - year(e.dob) AS calculated_age,
    CASE WHEN e.foreign_address = 1 THEN UPPER(trim(e.physical_address1)) ELSE UPPER(trim(e.address1)) END AS address1,
    CASE WHEN e.foreign_address = 1 THEN UPPER(trim(e.physical_address2)) ELSE UPPER(trim(e.address2)) END AS address2,
    CASE WHEN e.foreign_address = 1 THEN COALESCE(UPPER(trim(e.physical_city)), 'Unknown') ELSE COALESCE(UPPER(trim(e.city)), 'Unknown') END AS city,
    CASE WHEN e.foreign_address = 1 THEN COALESCE(UPPER(trim(e.physical_state)), 'Unknown') ELSE COALESCE(UPPER(trim(e.state)), 'Unknown') END AS state,
    CASE WHEN e.foreign_address = 1 THEN COALESCE(UPPER(trim(e.physical_zip)), 'Unknown') ELSE COALESCE(UPPER(trim(e.zip)), 'Unknown') END AS zip_code,
    CASE WHEN e.foreign_address = 1 THEN COALESCE(UPPER(trim(e.physical_country)), 'Unknown') ELSE COALESCE(UPPER(trim(e.country)), 'Unknown') END AS country,
    CASE
        WHEN e.foreign_address = 1
            THEN CONCAT(COALESCE(UPPER(trim(e.physical_city)), 'Unknown'), ', ', COALESCE(UPPER(trim(e.physical_state)), 'Unknown'))
        ELSE CONCAT(COALESCE(UPPER(trim(e.city)), 'Unknown'), ', ', COALESCE(UPPER(trim(e.state)), 'Unknown'))
    END AS city_state,
    CASE WHEN e.foreign_address = 1 THEN 'Physical' ELSE 'Mailing' END AS address_type_used,
    m.branch_number AS branch,
    COALESCE(eg.description, 'Unknown') AS eligibility_group,
    CASE WHEN m.home_bank_date IS NOT NULL THEN 'Active' ELSE 'Inactive' END AS online_banking_status,
    CASE
        WHEN m.last_nondiv_activity >= date_add('day', -30, current_date) THEN 'Active'
        WHEN m.last_nondiv_activity IS NOT NULL                         THEN 'Inactive'
        ELSE 'Unknown'
    END AS activity_30_days,
    CASE
        WHEN m.last_nondiv_activity >= date_add('day', -90, current_date) THEN 'Active'
        WHEN m.last_nondiv_activity IS NOT NULL                          THEN 'Inactive'
        ELSE 'Unknown'
    END AS activity_90_days,
    COALESCE(account_summary.total_account_count, 0) AS total_account_count,
    COALESCE(account_summary.share_count, 0) AS savings_accounts_count,
    COALESCE(account_summary.draft_count, 0) AS checking_accounts_count,
    COALESCE(account_summary.loan_count, 0) AS loan_accounts_count,
    COALESCE(account_summary.cert_count, 0) AS certificate_accounts_count,
    CASE WHEN COALESCE(account_summary.share_count, 0) > 0 THEN 1 ELSE 0 END AS has_savings,
    CASE WHEN COALESCE(account_summary.draft_count, 0) > 0 THEN 1 ELSE 0 END AS has_checking,
    CASE WHEN COALESCE(account_summary.loan_count, 0) > 0 THEN 1 ELSE 0 END AS has_loans,
    CASE WHEN COALESCE(account_summary.cert_count, 0) > 0 THEN 1 ELSE 0 END AS has_certificates,
    (
        CASE WHEN COALESCE(account_summary.share_count, 0) > 0 THEN 1 ELSE 0 END +
        CASE WHEN COALESCE(account_summary.draft_count, 0) > 0 THEN 1 ELSE 0 END +
        CASE WHEN COALESCE(account_summary.loan_count, 0) > 0 THEN 1 ELSE 0 END +
        CASE WHEN COALESCE(account_summary.cert_count, 0) > 0 THEN 1 ELSE 0 END
    ) AS distinct_product_types_count,
    (
        COALESCE(account_summary.share_count, 0) +
        COALESCE(account_summary.draft_count, 0) +
        COALESCE(account_summary.loan_count, 0) +
        COALESCE(account_summary.cert_count, 0)
    ) AS total_products_by_type,
    CASE
        WHEN COALESCE(account_summary.total_account_count, 0) = 0 THEN 'No Products'
        WHEN (
            CASE WHEN COALESCE(account_summary.share_count, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(account_summary.draft_count, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(account_summary.loan_count, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(account_summary.cert_count, 0) > 0 THEN 1 ELSE 0 END
        ) = 1 THEN 'Single Product'
        WHEN (
            CASE WHEN COALESCE(account_summary.share_count, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(account_summary.draft_count, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(account_summary.loan_count, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(account_summary.cert_count, 0) > 0 THEN 1 ELSE 0 END
        ) = 4 THEN 'Full Relationship'
        WHEN (
            CASE WHEN COALESCE(account_summary.share_count, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(account_summary.draft_count, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(account_summary.loan_count, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(account_summary.cert_count, 0) > 0 THEN 1 ELSE 0 END
        ) BETWEEN 2 AND 3 THEN 'Multi Product'
        ELSE 'Unknown'
    END AS product_relationship_category,
    (
        CASE WHEN m.home_bank_date IS NOT NULL THEN 40 ELSE 0 END +
        CASE WHEN m.last_nondiv_activity >= date_add('day', -30, current_date) THEN 30 ELSE 0 END +
        CASE WHEN m.last_nondiv_activity >= date_add('day', -90, current_date) THEN 20 ELSE 0 END +
        CASE WHEN COALESCE(account_summary.total_account_count, 0) > 1 THEN 10 ELSE 0 END
    ) AS engagement_score,
    m.last_nondiv_activity AS last_activity_date,
    m.home_bank_date AS last_online_banking_date,
    CASE WHEN m.all_accounts_closed = 1 THEN 'Yes' ELSE 'No' END AS all_accounts_closed,
    attrition_data.latest_account_closure_date AS attrition_date,
    CASE
        WHEN m.all_accounts_closed = 1 AND attrition_data.latest_account_closure_date IS NOT NULL
            THEN date_diff('day', m.join_date, attrition_data.latest_account_closure_date)
        ELSE NULL
    END AS member_lifespan_days,
    CASE
        WHEN m.all_accounts_closed = 1 AND attrition_data.latest_account_closure_date IS NOT NULL THEN
            CASE
                WHEN date_diff('day', m.join_date, attrition_data.latest_account_closure_date) < 90   THEN 'Early (0-3 months)'
                WHEN date_diff('day', m.join_date, attrition_data.latest_account_closure_date) < 365  THEN 'Short (3-12 months)'
                WHEN date_diff('day', m.join_date, attrition_data.latest_account_closure_date) < 1095 THEN 'Medium (1-3 years)'
                WHEN date_diff('day', m.join_date, attrition_data.latest_account_closure_date) < 1825 THEN 'Long (3-5 years)'
                ELSE 'Very Long (5+ years)'
            END
        ELSE NULL
    END AS attrition_category,
    current_date AS data_extract_date
FROM "AwsDataCatalog"."silver-mvp-know"."member" m
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."entity" e
  ON m.member_entity_id = e.entity_id
 AND m."credit_union"  = e."credit_union"
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."eligibility_group" eg
  ON m.eligibility_group_id = eg.eligibility_group_id
 AND m."credit_union"       = eg."credit_union"
LEFT JOIN (
    SELECT
        "credit_union",
        member_number,
        COUNT(DISTINCT account_id) AS total_account_count,
        COUNT(DISTINCT CASE WHEN discriminator = 'S' THEN account_id END) AS share_count,
        COUNT(DISTINCT CASE WHEN discriminator = 'D' THEN account_id END) AS draft_count,
        COUNT(DISTINCT CASE WHEN discriminator = 'L' THEN account_id END) AS loan_count,
        COUNT(DISTINCT CASE WHEN discriminator = 'C' THEN account_id END) AS cert_count
    FROM "AwsDataCatalog"."silver-mvp-know"."account"
    WHERE date_closed IS NULL
    GROUP BY "credit_union", member_number
) account_summary
  ON m.member_number = account_summary.member_number
 AND m."credit_union" = account_summary."credit_union"
LEFT JOIN (
    SELECT
        a."credit_union",
        a.member_number,
        MAX(a.date_closed) AS latest_account_closure_date
    FROM "AwsDataCatalog"."silver-mvp-know"."account" a
    INNER JOIN "AwsDataCatalog"."silver-mvp-know"."member" m2
      ON a.member_number = m2.member_number
     AND a."credit_union" = m2."credit_union"
    WHERE a.date_closed IS NOT NULL
      AND m2.all_accounts_closed = 1
    GROUP BY a."credit_union", a.member_number
) attrition_data
  ON m.member_number  = attrition_data.member_number
 AND m."credit_union" = attrition_data."credit_union"
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
  ON lower(trim(fi.prodigy_code)) = lower(trim(m."credit_union"))
WHERE
    m.member_number IS NOT NULL
    AND m.member_type IS NOT NULL
ORDER BY
    m.member_number;
