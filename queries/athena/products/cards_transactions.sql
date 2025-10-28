WITH filtered_th AS (
    SELECT
        th.credit_union,
        th.transaction_history_id,
        th.account_id,
        th.member_id,
        th.date_actual,
        th.total_amount,
        substr(upper(trim(th.tran_code)), 1, 4) AS tran_prefix,
        date_format(CAST(th.date_actual AS timestamp), '%Y-%m') AS period
    FROM "AwsDataCatalog"."silver-mvp-know"."transaction_history" th
    WHERE
        th.date_actual >= DATE '2025-01-01'
        AND (
            upper(trim(th.tran_code)) LIKE 'DRWD%'
            OR upper(trim(th.tran_code)) LIKE 'TLT%'
        )
),

member_card_types AS (
    SELECT
        ec.credit_union,
        ec.member_number,
        CASE
            WHEN count_if(upper(trim(ec.card_type)) = 'D')  > 0 THEN 'D'
            WHEN count_if(upper(trim(ec.card_type)) = 'DI') > 0 THEN 'DI'
            WHEN count_if(upper(trim(ec.card_type)) = 'A')  > 0 THEN 'A'
            ELSE NULL
        END AS debit_type,
        CASE
            WHEN count_if(upper(trim(ec.card_type)) = 'PC') > 0 THEN 'PC'
            WHEN count_if(upper(trim(ec.card_type)) = 'C')  > 0 THEN 'C'
            ELSE NULL
        END AS credit_type
    FROM "AwsDataCatalog"."silver-mvp-know"."eft_card_file" ec
    GROUP BY ec.credit_union, ec.member_number
)

SELECT
    f.credit_union AS credit_union,
    fi.idfi AS idfi,
    f.period,
    CASE
        WHEN f.tran_prefix = 'DRWD' THEN
            CASE mct.debit_type
                WHEN 'D'  THEN 'Debit'
                WHEN 'DI' THEN 'Debit Instant'
                WHEN 'A'  THEN 'ATM'
                ELSE 'Debit (No Card)'
            END
        WHEN f.tran_prefix = 'TLT' THEN
            CASE mct.credit_type
                WHEN 'PC' THEN 'Credit Platinum'
                WHEN 'C'  THEN 'Credit Gold'
                ELSE 'Credit (Unknown)'
            END
        ELSE 'Other'
    END AS specific_card_type,
    COUNT(DISTINCT f.member_id) AS unique_members,
    COUNT(
        DISTINCT CASE
            WHEN f.tran_prefix = 'DRWD'
                THEN concat('DEBIT_', CAST(f.account_id AS varchar), '_', CAST(f.member_id AS varchar))
            WHEN f.tran_prefix = 'TLT'
                THEN concat('CREDIT_', CAST(f.account_id AS varchar))
            ELSE
                concat('ACCOUNT_', CAST(f.account_id AS varchar))
        END
    ) AS unique_cards,
    COUNT(DISTINCT f.transaction_history_id) AS total_transactions,
    ROUND(AVG(ABS(f.total_amount)), 2) AS avg_transaction_amount,
    ROUND(SUM(ABS(f.total_amount)), 2) AS total_transaction_volume
FROM filtered_th f
JOIN "AwsDataCatalog"."silver-mvp-know"."account" a
  ON a.account_id   = f.account_id
 AND a.credit_union = f.credit_union
LEFT JOIN member_card_types mct
  ON mct.member_number = a.member_number
 AND mct.credit_union  = a.credit_union
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
  ON fi.prodigy_code = f.credit_union
GROUP BY 1, 2, 3, 4
ORDER BY 2 DESC, 3;
