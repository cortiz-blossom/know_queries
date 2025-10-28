WITH debit_atm_cards AS (
    SELECT
        ecf.credit_union AS credit_union,
        ecf.member_number AS member_id,
        CAST(ecf.record_number AS varchar) AS card_id,
        CAST(substr(CAST(ecf.record_number AS varchar), greatest(length(CAST(ecf.record_number AS varchar)) - 3, 1), 4) AS varchar) AS last_4_digits,
        CAST(
            CASE
                WHEN UPPER(TRIM(ecf.card_type)) = 'D'  THEN 'Debit'
                WHEN UPPER(TRIM(ecf.card_type)) = 'DI' THEN 'Debit Instant'
                WHEN UPPER(TRIM(ecf.card_type)) = 'A'  THEN 'ATM'
                ELSE 'Other Debit'
            END AS varchar
        ) AS card_type,
        CAST(
            CASE
                WHEN UPPER(ecf.card_description) LIKE '%VISA%'      THEN 'VISA'
                WHEN UPPER(ecf.card_description) LIKE '%MASTER%'    THEN 'MASTERCARD'
                WHEN UPPER(ecf.card_description) LIKE '%DISCOVER%'  THEN 'DISCOVER'
                WHEN TRIM(CAST(ecf.vendor_number AS varchar)) = '1' THEN 'VISA'
                WHEN TRIM(CAST(ecf.vendor_number AS varchar)) = '2' THEN 'MASTERCARD'
                ELSE 'Unknown'
            END AS varchar
        ) AS card_brand,
        ecf.issue_date AS creation_date,
        ecf.block_date AS deleted_date,
        ecf.expire_date AS expiration_date,
        COALESCE(ecf.share_acct_bal, ecf.draft_acct_bal, 0) AS balance_or_credit_limit,
        CAST(NULL AS decimal(15,2)) AS credit_used,
        CAST(NULL AS decimal(15,2)) AS credit_used_percentage,
        CAST(
            CASE
                WHEN ecf.block_date IS NOT NULL THEN 'Blocked'
                WHEN TRIM(CAST(ecf.reject_code AS varchar)) IN ('34','43') THEN 'Fraud Block'
                WHEN TRIM(CAST(ecf.reject_code AS varchar)) IN ('36','41') THEN 'Lost/Stolen Block'
                WHEN TRIM(CAST(ecf.reject_code AS varchar)) = '07' THEN 'Special Handling'
                WHEN ecf.expire_date < current_date THEN 'Expired'
                WHEN ecf.last_pin_used_date IS NOT NULL THEN 'Active'
                WHEN ecf.issue_date IS NOT NULL THEN 'Issued Not Used'
                ELSE 'Unknown'
            END AS varchar
        ) AS status,
        CAST('N/A' AS varchar) AS delinquency_bracket,
        ecf.last_pin_used_date AS activation_date,
        CAST(CASE WHEN ecf.last_pin_used_date IS NOT NULL THEN 'True' ELSE 'False' END AS varchar) AS is_activated,
        CAST(
            CASE
                WHEN TRIM(CAST(ecf.reject_code AS varchar)) IN ('34','43') THEN 'True'
                WHEN TRIM(COALESCE(CAST(ecf.lost_or_stolen AS varchar), '')) <> '' THEN 'True'
                ELSE 'False'
            END AS varchar
        ) AS fraud_incident,
        ecf.last_pin_used_date AS last_activity_date,
        CAST('Physical Debit/ATM' AS varchar) AS card_source
    FROM "AwsDataCatalog"."silver-mvp-know"."eft_card_file" ecf
    WHERE UPPER(TRIM(ecf.card_type)) IN ('D','DI','A')
),

physical_credit_cards AS (
    SELECT
        ecf.credit_union AS credit_union,
        ecf.member_number AS member_id,
        CAST(ecf.record_number AS varchar) AS card_id,
        CAST(substr(CAST(ecf.record_number AS varchar), greatest(length(CAST(ecf.record_number AS varchar)) - 3, 1), 4) AS varchar) AS last_4_digits,
        CAST(
            CASE
                WHEN UPPER(TRIM(ecf.card_type)) = 'C'  THEN 'Credit Gold'
                WHEN UPPER(TRIM(ecf.card_type)) = 'PC' THEN 'Credit Platinum'
                ELSE 'Credit Card'
            END AS varchar
        ) AS card_type,
        CAST(
            CASE
                WHEN UPPER(ecf.card_description) LIKE '%VISA%'      THEN 'VISA'
                WHEN UPPER(ecf.card_description) LIKE '%MASTER%'    THEN 'MASTERCARD'
                WHEN UPPER(ecf.card_description) LIKE '%DISCOVER%'  THEN 'DISCOVER'
                WHEN TRIM(CAST(ecf.vendor_number AS varchar)) = '1' THEN 'VISA'
                WHEN TRIM(CAST(ecf.vendor_number AS varchar)) = '2' THEN 'MASTERCARD'
                ELSE 'Unknown'
            END AS varchar
        ) AS card_brand,
        ecf.issue_date AS creation_date,
        ecf.block_date AS deleted_date,
        ecf.expire_date AS expiration_date,
        CAST(0 AS decimal(15,2)) AS balance_or_credit_limit,
        CAST(0 AS decimal(15,2)) AS credit_used,
        CAST(0 AS decimal(15,2)) AS credit_used_percentage,
        CAST(
            CASE
                WHEN ecf.block_date IS NOT NULL THEN 'Blocked'
                WHEN TRIM(CAST(ecf.reject_code AS varchar)) IN ('34','43') THEN 'Fraud Block'
                WHEN TRIM(CAST(ecf.reject_code AS varchar)) IN ('36','41') THEN 'Lost/Stolen Block'
                WHEN TRIM(CAST(ecf.reject_code AS varchar)) = '07' THEN 'Special Handling'
                WHEN ecf.expire_date < current_date THEN 'Expired'
                WHEN ecf.last_pin_used_date IS NOT NULL THEN 'Active'
                WHEN ecf.issue_date IS NOT NULL THEN 'Issued Not Used'
                ELSE 'Unknown'
            END AS varchar
        ) AS status,
        CAST('N/A' AS varchar) AS delinquency_bracket,
        ecf.last_pin_used_date AS activation_date,
        CAST(CASE WHEN ecf.last_pin_used_date IS NOT NULL THEN 'True' ELSE 'False' END AS varchar) AS is_activated,
        CAST(
            CASE
                WHEN TRIM(CAST(ecf.reject_code AS varchar)) IN ('34','43') THEN 'True'
                WHEN TRIM(COALESCE(CAST(ecf.lost_or_stolen AS varchar), '')) <> '' THEN 'True'
                ELSE 'False'
            END AS varchar
        ) AS fraud_incident,
        ecf.last_pin_used_date AS last_activity_date,
        CAST('Physical Credit' AS varchar) AS card_source
    FROM "AwsDataCatalog"."silver-mvp-know"."eft_card_file" ecf
    WHERE UPPER(TRIM(ecf.card_type)) IN ('C','PC')
),

credit_card_accounts AS (
    SELECT
        a.credit_union AS credit_union,
        a.member_number AS member_id,
        CAST(al.account_id AS varchar) AS card_id,
        CAST('****' AS varchar) AS last_4_digits,
        CAST('Credit Account' AS varchar) AS card_type,
        CAST('Unknown' AS varchar) AS card_brand,
        COALESCE(al.funded_date, a.date_opened) AS creation_date,
        a.date_closed AS deleted_date,
        al.credit_expiration AS expiration_date,
        al.credit_limit AS balance_or_credit_limit,
        a.current_balance AS credit_used,
        CASE
            WHEN al.credit_limit > 0 THEN ROUND((a.current_balance * 100.0) / al.credit_limit, 2)
            ELSE 0
        END AS credit_used_percentage,
        CAST(
            CASE
                WHEN a.date_closed IS NOT NULL THEN 'Closed'
                WHEN a.charge_off_date IS NOT NULL THEN 'Charged Off'
                WHEN al.next_payment_date IS NOT NULL AND date_diff('day', al.next_payment_date, current_date) > 30 THEN 'Delinquent'
                WHEN a.current_balance > al.credit_limit THEN 'Over Limit'
                WHEN UPPER(TRIM(a.status)) = 'ACTIVE'  THEN 'Active'
                WHEN UPPER(TRIM(a.status)) = 'CLOSED'  THEN 'Closed'
                WHEN UPPER(TRIM(a.status)) = 'FROZEN'  THEN 'Frozen'
                ELSE 'Active'
            END AS varchar
        ) AS status,
        CAST(
            CASE
                WHEN al.next_payment_date IS NULL THEN 'Unknown'
                WHEN date_diff('day', al.next_payment_date, current_date) <= 0 THEN 'Current'
                WHEN date_diff('day', al.next_payment_date, current_date) BETWEEN 1  AND 30  THEN '1-30 Days'
                WHEN date_diff('day', al.next_payment_date, current_date) BETWEEN 31 AND 60  THEN '31-60 Days'
                WHEN date_diff('day', al.next_payment_date, current_date) BETWEEN 61 AND 90  THEN '61-90 Days'
                WHEN date_diff('day', al.next_payment_date, current_date) BETWEEN 91 AND 120 THEN '91-120 Days'
                WHEN date_diff('day', al.next_payment_date, current_date) > 120 THEN '120+ Days'
                ELSE 'Current'
            END AS varchar
        ) AS delinquency_bracket,
        COALESCE(al.funded_date, a.date_opened) AS activation_date,
        CAST(CASE WHEN COALESCE(al.funded_date, a.date_opened) IS NOT NULL THEN 'True' ELSE 'False' END AS varchar) AS is_activated,
        CAST(
            CASE
                WHEN a.charge_off_date IS NOT NULL         THEN 'True'
                WHEN UPPER(TRIM(a.status)) = 'FRAUD'       THEN 'True'
                ELSE 'False'
            END AS varchar
        ) AS fraud_incident,
        al.last_payment_date AS last_activity_date,
        CAST('Credit Account' AS varchar) AS card_source
    FROM "AwsDataCatalog"."silver-mvp-know"."account_loan" al
    INNER JOIN "AwsDataCatalog"."silver-mvp-know"."account" a
        ON al.account_id = a.account_id
       AND al.credit_union = a.credit_union
    WHERE
        al.credit_limit > 0
        AND UPPER(TRIM(a.discriminator)) = 'L'
        AND a.member_number > 0
),

member_card_types AS (
    SELECT
        credit_union,
        member_id,
        CASE
            WHEN COUNT(CASE WHEN card_source IN ('Physical Debit/ATM') THEN 1 END) > 0
             AND COUNT(CASE WHEN card_source IN ('Physical Credit','Credit Account') THEN 1 END) > 0
                THEN 'Both'
            WHEN COUNT(CASE WHEN card_source IN ('Physical Debit/ATM') THEN 1 END) > 0
                THEN 'Debit Only'
            WHEN COUNT(CASE WHEN card_source IN ('Physical Credit','Credit Account') THEN 1 END) > 0
                THEN 'Credit Only'
            ELSE 'Unknown'
        END AS member_card_portfolio
    FROM (
        SELECT credit_union, member_id, card_source FROM debit_atm_cards
        UNION ALL
        SELECT credit_union, member_id, card_source FROM physical_credit_cards
        UNION ALL
        SELECT credit_union, member_id, card_source FROM credit_card_accounts
    ) all_cards
    GROUP BY credit_union, member_id
)

SELECT
    uc.credit_union AS credit_union,
    fi.idfi AS idfi,
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
    CASE
        WHEN uc.last_activity_date IS NULL THEN 'True'
        WHEN date_diff('day', uc.last_activity_date, current_date) > 90 THEN 'True'
        ELSE 'False'
    END AS inactivity_flag,
    uc.fraud_incident,
    uc.card_source,
    mct.member_card_portfolio
FROM (
    SELECT * FROM debit_atm_cards
    UNION ALL
    SELECT * FROM physical_credit_cards
    UNION ALL
    SELECT * FROM credit_card_accounts
) uc
LEFT JOIN member_card_types mct
    ON uc.credit_union = mct.credit_union
   AND uc.member_id    = mct.member_id
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
    ON fi.prodigy_code = uc.credit_union
ORDER BY
    uc.credit_union,
    uc.member_id,
    uc.card_source,
    uc.card_type,
    uc.creation_date DESC;
