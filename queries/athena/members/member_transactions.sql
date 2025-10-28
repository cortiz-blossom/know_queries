SELECT
    a."credit_union" AS "credit_union",
    fi.idfi AS idfi,
    a.member_number,
    COUNT(*) AS total_transactions_lifetime,
    ROUND(SUM(ABS(th.total_amount)), 2) AS total_transaction_amount_lifetime,
    ROUND(AVG(ABS(th.total_amount)), 2) AS avg_transaction_amount_lifetime,
    COUNT(CASE WHEN th.total_amount < 0 THEN 1 END) AS debit_transactions_lifetime,
    COUNT(CASE WHEN th.total_amount > 0 THEN 1 END) AS credit_transactions_lifetime,
    ROUND(SUM(CASE WHEN th.total_amount < 0 THEN ABS(th.total_amount) ELSE 0 END), 2) AS debit_amount_lifetime,
    ROUND(SUM(CASE WHEN th.total_amount > 0 THEN th.total_amount ELSE 0 END), 2) AS credit_amount_lifetime,

    COUNT(CASE WHEN year(th.date_effective) = year(current_date) AND month(th.date_effective) = month(current_date) THEN 1 END) AS total_transactions_mtd,
    ROUND(SUM(CASE WHEN year(th.date_effective) = year(current_date) AND month(th.date_effective) = month(current_date) THEN ABS(th.total_amount) ELSE 0 END), 2) AS total_transaction_amount_mtd,
    ROUND(AVG(CASE WHEN year(th.date_effective) = year(current_date) AND month(th.date_effective) = month(current_date) THEN ABS(th.total_amount) END), 2) AS avg_transaction_amount_mtd,
    COUNT(CASE WHEN year(th.date_effective) = year(current_date) AND month(th.date_effective) = month(current_date) AND th.total_amount < 0 THEN 1 END) AS debit_transactions_mtd,
    COUNT(CASE WHEN year(th.date_effective) = year(current_date) AND month(th.date_effective) = month(current_date) AND th.total_amount > 0 THEN 1 END) AS credit_transactions_mtd,
    ROUND(SUM(CASE WHEN year(th.date_effective) = year(current_date) AND month(th.date_effective) = month(current_date) AND th.total_amount < 0 THEN ABS(th.total_amount) ELSE 0 END), 2) AS debit_amount_mtd,
    ROUND(SUM(CASE WHEN year(th.date_effective) = year(current_date) AND month(th.date_effective) = month(current_date) AND th.total_amount > 0 THEN th.total_amount ELSE 0 END), 2) AS credit_amount_mtd,

    COUNT(CASE WHEN th.date_effective >= date_add('day', -30, current_date) THEN 1 END) AS total_transactions_30d,
    ROUND(SUM(CASE WHEN th.date_effective >= date_add('day', -30, current_date) THEN ABS(th.total_amount) ELSE 0 END), 2) AS total_transaction_amount_30d,
    ROUND(AVG(CASE WHEN th.date_effective >= date_add('day', -30, current_date) THEN ABS(th.total_amount) END), 2) AS avg_transaction_amount_30d,
    COUNT(CASE WHEN th.date_effective >= date_add('day', -30, current_date) AND th.total_amount < 0 THEN 1 END) AS debit_transactions_30d,
    COUNT(CASE WHEN th.date_effective >= date_add('day', -30, current_date) AND th.total_amount > 0 THEN 1 END) AS credit_transactions_30d,
    ROUND(SUM(CASE WHEN th.date_effective >= date_add('day', -30, current_date) AND th.total_amount < 0 THEN ABS(th.total_amount) ELSE 0 END), 2) AS debit_amount_30d,
    ROUND(SUM(CASE WHEN th.date_effective >= date_add('day', -30, current_date) AND th.total_amount > 0 THEN th.total_amount ELSE 0 END), 2) AS credit_amount_30d,

    COUNT(CASE WHEN th.date_effective >= date_add('day', -90, current_date) THEN 1 END) AS total_transactions_90d,
    ROUND(SUM(CASE WHEN th.date_effective >= date_add('day', -90, current_date) THEN ABS(th.total_amount) ELSE 0 END), 2) AS total_transaction_amount_90d,
    ROUND(AVG(CASE WHEN th.date_effective >= date_add('day', -90, current_date) THEN ABS(th.total_amount) END), 2) AS avg_transaction_amount_90d,
    COUNT(CASE WHEN th.date_effective >= date_add('day', -90, current_date) AND th.total_amount < 0 THEN 1 END) AS debit_transactions_90d,
    COUNT(CASE WHEN th.date_effective >= date_add('day', -90, current_date) AND th.total_amount > 0 THEN 1 END) AS credit_transactions_90d,
    ROUND(SUM(CASE WHEN th.date_effective >= date_add('day', -90, current_date) AND th.total_amount < 0 THEN ABS(th.total_amount) ELSE 0 END), 2) AS debit_amount_90d,
    ROUND(SUM(CASE WHEN th.date_effective >= date_add('day', -90, current_date) AND th.total_amount > 0 THEN th.total_amount ELSE 0 END), 2) AS credit_amount_90d,

    COUNT(CASE WHEN th.date_effective >= date_add('month', -12, current_date) THEN 1 END) AS total_transactions_12m,
    ROUND(SUM(CASE WHEN th.date_effective >= date_add('month', -12, current_date) THEN ABS(th.total_amount) ELSE 0 END), 2) AS total_transaction_amount_12m,
    ROUND(AVG(CASE WHEN th.date_effective >= date_add('month', -12, current_date) THEN ABS(th.total_amount) END), 2) AS avg_transaction_amount_12m,
    COUNT(CASE WHEN th.date_effective >= date_add('month', -12, current_date) AND COALESCE(TRY_CAST(at2.credit_card AS integer), 0) = 1 THEN 1 END) AS debit_transactions_12m,
    COUNT(CASE WHEN th.date_effective >= date_add('month', -12, current_date) AND th.total_amount > 0 THEN 1 END) AS credit_transactions_12m,
    ROUND(SUM(CASE WHEN th.date_effective >= date_add('month', -12, current_date) AND th.total_amount < 0 THEN ABS(th.total_amount) ELSE 0 END), 2) AS debit_amount_12m,
    ROUND(SUM(CASE WHEN th.date_effective >= date_add('month', -12, current_date) AND th.total_amount > 0 THEN th.total_amount ELSE 0 END), 2) AS credit_amount_12m,
    COUNT(CASE WHEN th.date_effective >= date_add('month', -12, current_date) AND COALESCE(TRY_CAST(at2.credit_card AS integer), 0) = 1 THEN 1 END) AS credit_card_transactions_12m,
    ROUND(SUM(CASE WHEN th.date_effective >= date_add('month', -12, current_date) AND COALESCE(TRY_CAST(at2.credit_card AS integer), 0) = 1 THEN ABS(th.total_amount) ELSE 0 END), 2) AS credit_card_amount_12m,

    CASE WHEN COUNT(CASE WHEN th.date_effective >= date_add('day', -30, current_date) THEN 1 END) > 0 THEN 'Active' ELSE 'Inactive' END AS transaction_activity_30d,
    CASE WHEN COUNT(CASE WHEN th.date_effective >= date_add('day', -90, current_date) THEN 1 END) > 0 THEN 'Active' ELSE 'Inactive' END AS transaction_activity_90d,
    CASE
        WHEN COUNT(CASE WHEN th.date_effective >= date_add('month', -12, current_date) THEN 1 END) = 0  THEN 'No Transactions'
        WHEN COUNT(CASE WHEN th.date_effective >= date_add('month', -12, current_date) THEN 1 END) <= 12  THEN 'Low Volume (≤12/year)'
        WHEN COUNT(CASE WHEN th.date_effective >= date_add('month', -12, current_date) THEN 1 END) <= 52  THEN 'Medium Volume (13-52/year)'
        WHEN COUNT(CASE WHEN th.date_effective >= date_add('month', -12, current_date) THEN 1 END) <= 156 THEN 'High Volume (53-156/year)'
        ELSE 'Very High Volume (>156/year)'
    END AS transaction_volume_category,

    CASE WHEN COUNT(CASE WHEN th.date_effective >= date_add('day', -30, current_date) THEN 1 END) > 0  THEN 20 ELSE 0 END AS transaction_score_30d,
    CASE WHEN COUNT(CASE WHEN th.date_effective >= date_add('day', -30, current_date) THEN 1 END) > 5  THEN 10 ELSE 0 END AS transaction_score_volume,
    CASE WHEN COUNT(CASE WHEN th.date_effective >= date_add('month', -12, current_date) THEN 1 END) > 52 THEN 20 ELSE 0 END AS transaction_score_annual,

    MIN(th.date_effective) AS first_transaction_date,
    MAX(th.date_effective) AS last_transaction_date,
    CASE
        WHEN MAX(th.date_effective) IS NOT NULL
            THEN date_diff('day', MAX(th.date_effective), current_date)
        ELSE NULL
    END AS days_since_last_transaction,
    current_date AS transaction_data_extract_date
FROM "AwsDataCatalog"."silver-mvp-know"."transaction_history" th
INNER JOIN "AwsDataCatalog"."silver-mvp-know"."account" a
  ON a.account_id   = th.account_id
 AND a."credit_union" = th."credit_union"
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."account_types" at2
  ON UPPER(TRIM(a.account_type)) = UPPER(TRIM(at2.account_type))
 AND at2."credit_union" = a."credit_union"
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
  ON lower(trim(fi.prodigy_code)) = lower(trim(a."credit_union"))
WHERE
    a.member_number IS NOT NULL
GROUP BY
    a."credit_union",
    fi.idfi,
    a.member_number
ORDER BY
    a."credit_union",
    a.member_number;
