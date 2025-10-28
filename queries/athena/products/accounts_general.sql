WITH member_account_stats AS (
    SELECT
        credit_union,
        member_number,
        COUNT(*) AS total_accounts_per_member,
        COUNT(CASE WHEN date_closed IS NOT NULL THEN 1 END) AS deleted_accounts_per_member,
        COUNT(
            CASE
                WHEN last_activity < date_add('day', -90, current_date)
                  OR last_activity IS NULL
                THEN 1
            END
        ) AS inactive_accounts_per_member,
        CASE WHEN COUNT(*) > 1 THEN 'True' ELSE 'False' END AS has_multiple_accounts
    FROM "AwsDataCatalog"."silver-mvp-know"."account"
    WHERE
        member_number > 0
        AND UPPER(TRIM(discriminator)) IN ('S','D','C','U')
    GROUP BY credit_union, member_number
),

cu_info AS (
    SELECT DISTINCT
        credit_union,
        credit_union_name
    FROM "AwsDataCatalog"."silver-mvp-know"."credit_union_info"
),

th_recent AS (
    SELECT DISTINCT
        credit_union,
        account_id
    FROM "AwsDataCatalog"."silver-mvp-know"."transaction_history"
    WHERE
        date_actual >= date_add('day', -90, current_date)
        AND void_flag = 0
)

SELECT
    a.credit_union AS credit_union,
    fi.idfi AS idfi,
    a.member_number AS member_id,
    ci.credit_union_name AS cu_name,

    CASE
        WHEN ma.member_number IS NOT NULL THEN 'Online Application'
        WHEN TRIM(a.created_by_userid) IN ('88','87','92','95','XXZ') THEN 'Automated Process'
        WHEN regexp_like(TRIM(a.created_by_userid), '^[0-9]+$') THEN 'Staff-Assisted'
        WHEN TRIM(a.created_by_userid) = 'PCN' THEN 'Migration'
        ELSE 'Unknown'
    END AS estimated_channel,

    CASE
        WHEN UPPER(TRIM(a.discriminator)) = 'S' AND UPPER(TRIM(a.account_type)) = 'PSAV' THEN 'Savings'
        WHEN UPPER(TRIM(a.discriminator)) = 'S' AND UPPER(TRIM(a.account_type)) = 'SSAV' THEN 'Savings'
        WHEN UPPER(TRIM(a.discriminator)) = 'S' AND UPPER(TRIM(a.account_type)) = 'MMA' THEN 'Money Market'
        WHEN UPPER(TRIM(a.discriminator)) = 'S' AND UPPER(TRIM(a.account_type)) = 'CCO' THEN 'Share Certificate'
        WHEN UPPER(TRIM(a.discriminator)) = 'S' AND UPPER(TRIM(a.account_type)) = 'CLUB' THEN 'Club Savings'
        WHEN UPPER(TRIM(a.discriminator)) = 'S' AND UPPER(TRIM(a.account_type)) = 'HYS' THEN 'High Yield Savings'
        WHEN UPPER(TRIM(a.discriminator)) = 'S' AND UPPER(TRIM(a.account_type)) = 'YSAV' THEN 'Youth Savings'
        WHEN UPPER(TRIM(a.discriminator)) = 'S' AND UPPER(TRIM(a.account_type)) = 'SCO' THEN 'Share Certificate'
        WHEN UPPER(TRIM(a.discriminator)) = 'S' THEN 'Other Savings'
        WHEN UPPER(TRIM(a.discriminator)) = 'D' AND UPPER(TRIM(a.account_type)) = 'CHK' THEN 'Checking'
        WHEN UPPER(TRIM(a.discriminator)) = 'D' THEN 'Other Checking'
        WHEN UPPER(TRIM(a.discriminator)) = 'C' AND UPPER(TRIM(a.account_type)) = 'CERT' THEN 'Certificate'
        WHEN UPPER(TRIM(a.discriminator)) = 'C' AND UPPER(TRIM(a.account_type)) = 'TICD' THEN 'Term Certificate'
        WHEN UPPER(TRIM(a.discriminator)) = 'C' AND UPPER(TRIM(a.account_type)) = 'RICD' THEN 'IRA Certificate'
        WHEN UPPER(TRIM(a.discriminator)) = 'C' THEN 'Other Certificate'
        WHEN UPPER(TRIM(a.discriminator)) = 'U' THEN 'Special Account'
        ELSE concat(CAST(a.discriminator AS varchar), '-', CAST(a.account_type AS varchar))
    END AS account_type_description,

    CASE
        WHEN UPPER(TRIM(a.discriminator)) = 'S' THEN 'SAVINGS'
        WHEN UPPER(TRIM(a.discriminator)) = 'D' THEN 'CHECKING'
        WHEN UPPER(TRIM(a.discriminator)) = 'C' THEN 'CERTIFICATES'
        WHEN UPPER(TRIM(a.discriminator)) = 'U' THEN 'SPECIAL'
        ELSE 'OTHER'
    END AS main_account_category,

    a.date_opened AS created_date,
    a.date_closed AS deleted_date,

    CASE
        WHEN a.date_closed IS NOT NULL THEN 'Deleted'
        WHEN UPPER(TRIM(COALESCE(a.access_control, ''))) IN ('B','R') THEN 'Blocked'
        ELSE 'Enabled'
    END AS deleted_status,

    CASE
        WHEN th.account_id IS NOT NULL THEN 'Active'
        ELSE 'Inactive'
    END AS active_status_last_3_months,

    a.account_number,
    a.current_balance,
    mas.total_accounts_per_member AS number_of_accounts_per_member,
    mas.has_multiple_accounts,
    mas.deleted_accounts_per_member AS accounts_deleted_per_member,
    mas.inactive_accounts_per_member AS accounts_inactive_per_member

FROM "AwsDataCatalog"."silver-mvp-know"."account" a
LEFT JOIN cu_info ci
    ON ci.credit_union = a.credit_union
LEFT JOIN member_account_stats mas
    ON mas.credit_union = a.credit_union
   AND mas.member_number = a.member_number
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."member_application" ma
    ON ma.credit_union = a.credit_union
   AND ma.member_number = a.member_number
LEFT JOIN th_recent th
    ON th.credit_union = a.credit_union
   AND th.account_id = a.account_id
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
    ON fi.prodigy_code = a.credit_union
WHERE
    a.member_number > 0
    AND UPPER(TRIM(a.discriminator)) IN ('S','D','C','U')
ORDER BY
    a.member_number,
    CASE
        WHEN UPPER(TRIM(a.discriminator)) = 'S' THEN 1
        WHEN UPPER(TRIM(a.discriminator)) = 'D' THEN 2
        WHEN UPPER(TRIM(a.discriminator)) = 'C' THEN 3
        WHEN UPPER(TRIM(a.discriminator)) = 'U' THEN 4
        ELSE 5
    END,
    a.date_opened DESC;
