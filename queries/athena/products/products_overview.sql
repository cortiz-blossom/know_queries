WITH member_product_counts AS (
    SELECT
        credit_union,
        member_number,
        COUNT(*) AS total_products_per_member
    FROM (
        SELECT
            a.credit_union,
            a.member_number
        FROM "AwsDataCatalog"."silver-mvp-know"."account" a
        WHERE
            a.member_number > 0
            AND UPPER(TRIM(a.discriminator)) IN ('S','D','C','U')
            AND a.date_closed IS NULL
            AND UPPER(TRIM(COALESCE(a.access_control, ''))) NOT IN ('B','R')

        UNION ALL

        SELECT
            a.credit_union,
            a.member_number
        FROM "AwsDataCatalog"."silver-mvp-know"."account" a
        JOIN "AwsDataCatalog"."silver-mvp-know"."account_loan" al
          ON a.account_id = al.account_id
         AND a.credit_union = al.credit_union
        WHERE
            a.member_number > 0
            AND UPPER(TRIM(a.discriminator)) = 'L'
            AND UPPER(TRIM(a.account_type)) NOT IN ('CC','PCO','PCCO')
            AND a.date_closed IS NULL
            AND a.charge_off_date IS NULL

        UNION ALL

        SELECT
            c.credit_union,
            c.member_number
        FROM "AwsDataCatalog"."silver-mvp-know"."eft_card_file" c
        WHERE
            c.member_number > 0
            AND UPPER(TRIM(c.card_type)) IN ('D','DI','A')
            AND c.block_date IS NULL
            AND c.expire_date >= current_date
            AND TRIM(CAST(c.reject_code AS varchar)) NOT IN ('34','36','41','43','07')
            AND TRIM(COALESCE(CAST(c.lost_or_stolen AS varchar), '')) = ''
            AND c.last_pin_used_date IS NOT NULL

        UNION ALL

        SELECT
            c.credit_union,
            c.member_number
        FROM "AwsDataCatalog"."silver-mvp-know"."eft_card_file" c
        WHERE
            c.member_number > 0
            AND UPPER(TRIM(c.card_type)) IN ('C','PC')
            AND c.block_date IS NULL
            AND c.expire_date >= current_date
            AND TRIM(CAST(c.reject_code AS varchar)) NOT IN ('34','36','41','43','07')
            AND TRIM(COALESCE(CAST(c.lost_or_stolen AS varchar), '')) = ''
            AND c.last_pin_used_date IS NOT NULL

        UNION ALL

        SELECT
            a.credit_union,
            a.member_number
        FROM "AwsDataCatalog"."silver-mvp-know"."account" a
        JOIN "AwsDataCatalog"."silver-mvp-know"."account_loan" al
          ON a.account_id = al.account_id
         AND a.credit_union = al.credit_union
        WHERE
            a.member_number > 0
            AND UPPER(TRIM(a.discriminator)) = 'L'
            AND al.credit_limit > 0
            AND a.date_closed IS NULL
            AND a.charge_off_date IS NULL
    ) all_products
    GROUP BY credit_union, member_number
),

cu_info AS (
    SELECT DISTINCT
        credit_union,
        credit_union_name
    FROM "AwsDataCatalog"."silver-mvp-know"."credit_union_info"
),

member_status AS (
    SELECT
         member_number,
        CASE 
            WHEN member_number IS NOT NULL 
             AND member_type IS NOT NULL 
             AND all_accounts_closed = 0 
            THEN 'Active'
            ELSE 'Inactive'
        END AS member_status,
        -- Filter columns for dashboard
        CASE WHEN member_number > 0 THEN 'Valid' ELSE 'Invalid' END AS member_number_is_valid,
        CASE WHEN inactive_flag = 'I' THEN 'Inactive Flag' ELSE 'Active Flag' END AS member_inactive_flag_status,
        -- Treat NULL as "Has Open Accounts" (ELSE clause includes NULL values)
        CASE WHEN all_accounts_closed = 1 THEN 'All Closed' 
             ELSE 'Has Open Accounts' 
        END AS member_accounts_status,
        inactive_flag AS member_inactive_flag_code,
        all_accounts_closed AS member_all_accounts_closed_flag
    FROM "AwsDataCatalog"."silver-mvp-know"."member" m
),

member_kind AS (
    SELECT
        m.credit_union,
        m.member_number,
        CASE
            WHEN m.member_type = 'B' THEN 'Business'
            WHEN m.member_type = 'C' THEN 'Corporate'
            WHEN m.member_type = 'P' THEN 'Member'
            ELSE 'Unknown'
        END AS member_category
    FROM "AwsDataCatalog"."silver-mvp-know"."member" m
    WHERE m.member_number > 0
),

recent_account_activity AS (
    SELECT DISTINCT
        th.credit_union,
        th.account_id
    FROM "AwsDataCatalog"."silver-mvp-know"."transaction_history" th
    WHERE
        th.date_actual >= date_add('day', -90, current_date)
        AND th.void_flag = 0
)

SELECT
    a.credit_union AS credit_union,
    fi.idfi AS idfi,
    a.member_number AS id_member,
    a.account_number AS id_product,
    'Accounts' AS main_category,
    CASE
        WHEN UPPER(TRIM(a.discriminator)) = 'S' THEN 'Savings Account'
        WHEN UPPER(TRIM(a.discriminator)) = 'D' THEN 'Checking Account'
        WHEN UPPER(TRIM(a.discriminator)) = 'C' THEN 'Certificate Account'
        WHEN UPPER(TRIM(a.discriminator)) = 'U' THEN 'Other Account'
    END AS category_product,
    ci.credit_union_name AS cu_name,
    a.account_number AS product_number,
    a.date_opened AS date_opened_product,
    a.date_closed AS date_closed_product,
    mpc.total_products_per_member AS number_of_products_for_member,
    CASE
        WHEN a.date_closed IS NULL
         AND UPPER(TRIM(COALESCE(a.access_control, ''))) NOT IN ('B','R')
            THEN 'Active'
        ELSE 'Inactive'
    END AS product_is_active,
    CASE
        WHEN ra.account_id IS NOT NULL THEN 'With Recent Activity'
        ELSE 'No Recent Activity'
    END AS recent_activity_status,
    ms.member_status AS member_status,
    'account' AS table_name_origin,
    mk.member_category
FROM "AwsDataCatalog"."silver-mvp-know"."account" a
JOIN cu_info ci
  ON ci.credit_union = a.credit_union
LEFT JOIN member_product_counts mpc
  ON mpc.credit_union  = a.credit_union
 AND mpc.member_number = a.member_number
LEFT JOIN member_status ms
  ON ms.credit_union   = a.credit_union
 AND ms.member_number  = a.member_number
LEFT JOIN member_kind mk
  ON mk.credit_union   = a.credit_union
 AND mk.member_number  = a.member_number
LEFT JOIN recent_account_activity ra
  ON ra.credit_union   = a.credit_union
 AND ra.account_id     = a.account_id
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
  ON fi.prodigy_code = a.credit_union
WHERE
    a.member_number > 0
    AND UPPER(TRIM(a.discriminator)) IN ('S','D','C','U')
ORDER BY
    id_member,
    main_category,
    category_product,
    product_is_active DESC;
