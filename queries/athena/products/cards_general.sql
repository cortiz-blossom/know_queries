WITH all_physical_cards AS (
    SELECT
        ecf.credit_union                                        AS credit_union,
        ecf.member_number                                       AS member_id,
        CAST(ecf.record_number AS varchar)                      AS card_id,
        CAST(
            substr(
                CAST(ecf.record_number AS varchar),
                greatest(length(CAST(ecf.record_number AS varchar)) - 3, 1),
                4
            ) AS varchar
        )                                                       AS last_4_digits,

        -- Card Type desde pd_xmaif (fuente oficial)
        CAST(
            CASE
                WHEN x.credit_card = 'Y' THEN CONCAT(x.description, ' Credit Card')
                WHEN x.debit_card  = 'Y' THEN x.description
                WHEN x.atm_card    = 'Y' THEN x.description
                ELSE COALESCE(x.description, 'Unknown Card')
            END AS varchar
        )                                                       AS card_type,

        -- Brand desde pd_xmaif
        CAST(COALESCE(x.card_issuer, 'Unknown') AS varchar)     AS card_brand,

        ecf.issue_date                                          AS creation_date,
        ecf.block_date                                          AS deleted_date,
        ecf.expire_date                                         AS expiration_date,

        -- Balance/límite (cero para físicas de crédito)
        CASE
            WHEN x.credit_card = 'Y' THEN CAST(0 AS decimal(15,2))
            ELSE COALESCE(ecf.share_acct_bal, ecf.draft_acct_bal, 0)
        END                                                     AS balance_or_credit_limit,

        -- Campos de crédito (NULL para débito/ATM, 0 para tarjetas físicas de crédito)
        CAST(CASE WHEN x.credit_card = 'Y' THEN 0 ELSE NULL END AS decimal(15,2)) AS credit_used,
        CAST(CASE WHEN x.credit_card = 'Y' THEN 0 ELSE NULL END AS decimal(15,2)) AS credit_used_percentage,

        -- Status (mismo criterio)
        CAST(
            CASE
                WHEN ecf.block_date IS NOT NULL THEN 'Blocked'
                WHEN TRIM(CAST(ecf.reject_code AS varchar)) IN ('34','43') THEN 'Fraud Block'
                WHEN TRIM(CAST(ecf.reject_code AS varchar)) IN ('36','41') THEN 'Lost/Stolen Block'
                WHEN TRIM(CAST(ecf.reject_code AS varchar)) =  '07'        THEN 'Special Handling'
                WHEN ecf.expire_date < current_date                        THEN 'Expired'
                WHEN ecf.last_pin_used_date IS NOT NULL                    THEN 'Active'
                WHEN ecf.issue_date IS NOT NULL                            THEN 'Issued Not Used'
                ELSE 'Unknown'
            END AS varchar
        )                                                       AS status,

        -- Delinquency no aplica a físicas
        CAST('N/A' AS varchar)                                  AS delinquency_bracket,

        -- Activación / flags
        ecf.last_pin_used_date                                  AS activation_date,
        CAST(CASE WHEN ecf.last_pin_used_date IS NOT NULL THEN 'True' ELSE 'False' END AS varchar) AS is_activated,
        CAST(
            CASE
                WHEN TRIM(CAST(ecf.reject_code AS varchar)) IN ('34','43') THEN 'True'
                WHEN TRIM(COALESCE(CAST(ecf.lost_or_stolen AS varchar), '')) <> '' THEN 'True'
                ELSE 'False'
            END AS varchar
        )                                                       AS fraud_incident,

        -- Actividad (para inactivity_flag)
        ecf.last_pin_used_date                                  AS last_activity_date,

        -- Fuente (alineada a Prodigy)
        CAST(
            CASE
                WHEN x.credit_card = 'Y' THEN 'Physical Credit'
                WHEN x.debit_card  = 'Y' THEN 'Physical Debit'
                WHEN x.atm_card    = 'Y' THEN 'Physical ATM'
                ELSE 'Physical Other'
            END AS varchar
        )                                                       AS card_source,

        -- Crudo de tipo
        ecf.card_type                                           AS raw_card_type

    FROM "AwsDataCatalog"."silver-mvp-know"."eft_card_file" ecf
    LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."pd_xmaif" x
        ON ecf.card_type = x.card_type
    WHERE x.inactive_flag = 0
),

credit_card_accounts AS (
    SELECT
        a.credit_union                                          AS credit_union,
        a.member_number                                         AS member_id,
        CAST(al.account_id AS varchar)                          AS card_id,
        CAST('****' AS varchar)                                 AS last_4_digits,
        CAST('Credit Account' AS varchar)                       AS card_type,
        CAST('Unknown' AS varchar)                              AS card_brand,
        COALESCE(al.funded_date, a.date_opened)                 AS creation_date,
        a.date_closed                                           AS deleted_date,
        al.credit_expiration                                    AS expiration_date,
        al.credit_limit                                         AS balance_or_credit_limit,
        a.current_balance                                       AS credit_used,
        CASE
            WHEN al.credit_limit > 0
                THEN ROUND((a.current_balance * 100.0) / al.credit_limit, 2)
            ELSE 0
        END                                                     AS credit_used_percentage,
        CAST(
            CASE
                WHEN a.date_closed IS NOT NULL THEN 'Closed'
                WHEN a.charge_off_date IS NOT NULL THEN 'Charged Off'
                WHEN al.next_payment_date IS NOT NULL
                     AND date_diff('day', al.next_payment_date, current_date) > 30 THEN 'Delinquent'
                WHEN a.current_balance > al.credit_limit THEN 'Over Limit'
                WHEN UPPER(TRIM(a.status)) = 'ACTIVE'  THEN 'Active'
                WHEN UPPER(TRIM(a.status)) = 'CLOSED'  THEN 'Closed'
                WHEN UPPER(TRIM(a.status)) = 'FROZEN'  THEN 'Frozen'
                ELSE 'Active'
            END AS varchar
        )                                                       AS status,
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
        )                                                       AS delinquency_bracket,
        COALESCE(al.funded_date, a.date_opened)                 AS activation_date,
        CAST(CASE WHEN COALESCE(al.funded_date, a.date_opened) IS NOT NULL THEN 'True' ELSE 'False' END AS varchar) AS is_activated,
        CAST(
            CASE
                WHEN a.charge_off_date IS NOT NULL         THEN 'True'
                WHEN UPPER(TRIM(a.status)) = 'FRAUD'       THEN 'True'
                ELSE 'False'
            END AS varchar
        )                                                       AS fraud_incident,
        al.last_payment_date                                    AS last_activity_date,
        CAST('Credit Account' AS varchar)                       AS card_source
    FROM "AwsDataCatalog"."silver-mvp-know"."account_loan" al
    INNER JOIN "AwsDataCatalog"."silver-mvp-know"."account" a
        ON al.account_id   = a.account_id
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
            WHEN COUNT(CASE WHEN card_source IN ('Physical Debit','Physical ATM') THEN 1 END) > 0
             AND COUNT(CASE WHEN card_source IN ('Physical Credit','Credit Account') THEN 1 END) > 0
                THEN 'Both'
            WHEN COUNT(CASE WHEN card_source IN ('Physical Debit','Physical ATM') THEN 1 END) > 0
                THEN 'Debit Only'
            WHEN COUNT(CASE WHEN card_source IN ('Physical Credit','Credit Account') THEN 1 END) > 0
                THEN 'Credit Only'
            ELSE 'Unknown'
        END AS member_card_portfolio
    FROM (
        SELECT credit_union, member_id, card_source FROM all_physical_cards
        UNION ALL
        SELECT credit_union, member_id, card_source FROM credit_card_accounts
    ) all_cards
    GROUP BY credit_union, member_id
)

SELECT
    uc.credit_union AS credit_union,
    fi.idfi         AS idfi,
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
    SELECT * FROM all_physical_cards
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
