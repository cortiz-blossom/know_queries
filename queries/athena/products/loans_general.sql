SELECT
    a.credit_union AS credit_union,
    fi.idfi AS idfi,
    a.member_number AS Member_ID,
    ci.credit_union_name AS CU_Name,
    a.account_id AS Loan_ID,

    -- Credit Bureau fields (fuente definitiva)
    at.cb_loan_type                                           AS Credit_Bureau_Code,
    CASE at.cb_loan_type
        WHEN '00' THEN 'Auto Loans'
        WHEN '01' THEN 'Unsecured/Personal Loans'
        WHEN '02' THEN 'Share/CD Secured Loans'
        WHEN '03' THEN 'Signature Secured Loans'
        WHEN '11' THEN 'Recreational Vehicle Loans'
        WHEN '15' THEN 'Overdraft Protection'
        WHEN '18' THEN 'Credit Card'
        WHEN '26' THEN 'Real Estate/Mortgage Loans'
        WHEN '89' THEN 'Home Equity Loans'
        ELSE 'Unclassified'
    END                                                       AS Loan_Main_Category,

    -- Subcategoría y código de tipo
    COALESCE(at.description, a.account_type)                  AS Loan_Sub_Category,
    a.account_type                                            AS Account_Type_Code,

    -- Financial info & terms
    ROUND(al.interest_rate, 3)                                AS Interest_Rate,
    al.number_of_payments                                     AS Number_of_Installments,

    -- Paid installments (estimado)
    CASE
        WHEN a.date_closed IS NOT NULL THEN al.number_of_payments
        WHEN al.number_of_payments IS NOT NULL
         AND al.number_of_payments > 0
         AND a.date_opened IS NOT NULL
        THEN GREATEST(
                 0,
                 LEAST(
                     al.number_of_payments,
                     CASE
                         WHEN al.payments_per_year > 0
                         THEN FLOOR(
                                  date_diff('day', a.date_opened, COALESCE(a.date_closed, CURRENT_DATE))
                                  * al.payments_per_year / 365.0
                              )
                         ELSE FLOOR(
                                  date_diff('day', a.date_opened, COALESCE(a.date_closed, CURRENT_DATE)) / 30.0
                              )
                     END
                 )
             )
        ELSE NULL
    END                                                       AS Number_of_Paid_Installments,

    -- Fechas clave
    a.date_opened                                             AS Creation_Date,
    al.next_payment_date                                      AS Next_Payment_Date,
    a.date_closed                                             AS Closure_Date,

    -- Crédito
    al.credit_score                                           AS Credit_Score,

    -- Estatus (incluye delinquency)
    CASE
        WHEN a.charge_off_date IS NOT NULL THEN 'CHARGED_OFF'
        WHEN a.date_closed IS NULL
         AND a.current_balance > 0
         AND al.next_payment_date IS NOT NULL
         AND al.next_payment_date < CURRENT_DATE              THEN 'DELINQUENT'
        WHEN a.current_balance = 0
         AND a.date_closed IS NOT NULL
         AND a.charge_off_date IS NULL
         AND al.credit_limit = 0
         AND al.credit_expiration < CURRENT_DATE              THEN 'PAID_OFF'
        WHEN a.date_closed IS NOT NULL                        THEN 'CLOSED'
        ELSE 'ACTIVE'
    END                                                       AS Status,

    -- Días de mora
    CASE
        WHEN al.next_payment_date IS NOT NULL
         AND al.next_payment_date < CURRENT_DATE
        THEN date_diff('day', al.next_payment_date, CURRENT_DATE)
        ELSE 0
    END                                                       AS Days_Past_Due,

    -- Bracket de morosidad
    CASE
        WHEN al.next_payment_date IS NULL
          OR al.next_payment_date >= CURRENT_DATE             THEN 'CURRENT'
        WHEN date_diff('day', al.next_payment_date, CURRENT_DATE) BETWEEN 1  AND 30  THEN '1-30 days'
        WHEN date_diff('day', al.next_payment_date, CURRENT_DATE) BETWEEN 31 AND 60  THEN '31-60 days'
        WHEN date_diff('day', al.next_payment_date, CURRENT_DATE) BETWEEN 61 AND 90  THEN '61-90 days'
        WHEN date_diff('day', al.next_payment_date, CURRENT_DATE) BETWEEN 91 AND 120 THEN '91-120 days'
        WHEN date_diff('day', al.next_payment_date, CURRENT_DATE) > 120             THEN 'Over 120 days'
        ELSE 'CURRENT'
    END                                                       AS Delinquency_Bracket,

    -- Delinquency counters
    COALESCE(al.delq_count_30,  0)
  + COALESCE(al.delq_count_60,  0)
  + COALESCE(al.delq_count_90,  0)
  + COALESCE(al.delq_count_120, 0)
  + COALESCE(al.delq_count_150, 0)
  + COALESCE(al.delq_count_180, 0)                            AS Total_Delinquency_Occurrences,

    -- Saldos
    ROUND(al.opening_balance, 2)                              AS Initial_Balance,
    ROUND(a.current_balance, 2)                               AS Current_Balance,

    -- Ingresos por intereses
    ROUND(COALESCE(al.interest_ytd,  0)
        + COALESCE(al.interest_lytd, 0), 2)                   AS Total_Interest_Earned,
    ROUND(al.interest_ytd,  2)                                AS Interest_Earned_YTD,
    ROUND(al.interest_lytd, 2)                                AS Interest_Earned_LYTD,

    -- Ingresos por mora
    ROUND(COALESCE(al.late_fees_ytd,  0)
        + COALESCE(al.late_fees_lytd, 0), 2)                  AS Total_Late_Fees_Earned,
    ROUND(al.late_fees_ytd,  2)                               AS Late_Fees_YTD,
    ROUND(al.late_fees_lytd, 2)                               AS Late_Fees_LYTD,

    -- Ingreso total
    ROUND(
        COALESCE(al.interest_ytd,   0)
      + COALESCE(al.interest_lytd,  0)
      + COALESCE(al.late_fees_ytd,  0)
      + COALESCE(al.late_fees_lytd, 0), 2
    )                                                         AS Total_Revenue_Earned,

    -- Ratios
    CASE
        WHEN al.opening_balance > 0
        THEN ROUND(
                 (COALESCE(al.interest_ytd, 0) + COALESCE(al.interest_lytd, 0))
                 / al.opening_balance * 100, 3
             )
        ELSE 0
    END                                                       AS Interest_Yield_Percentage,

    ROUND(al.interest_rate / 12, 6)                           AS Monthly_Interest_Rate,

    -- Interés esperado (simple) vs real
    CASE
        WHEN a.date_opened IS NOT NULL
         AND al.opening_balance > 0
         AND al.interest_rate > 0
        THEN ROUND(
                 al.opening_balance * (al.interest_rate / 100)
                 * date_diff('day', a.date_opened, COALESCE(a.date_closed, CURRENT_DATE)) / 365.0,
                 2
             )
        ELSE 0
    END                                                       AS Expected_Interest_Simple,

    CASE
        WHEN a.date_opened IS NOT NULL
         AND al.opening_balance > 0
         AND al.interest_rate > 0
        THEN ROUND(
                 (COALESCE(al.interest_ytd, 0) + COALESCE(al.interest_lytd, 0))
                 / NULLIF(
                     al.opening_balance * (al.interest_rate / 100)
                     * (date_diff('day', a.date_opened, COALESCE(a.date_closed, CURRENT_DATE)) / 365.0),
                     0
                 ) * 100,
                 2
             )
        ELSE NULL
    END                                                       AS Interest_Performance_Ratio

FROM "AwsDataCatalog"."silver-mvp-know"."account" a
INNER JOIN "AwsDataCatalog"."silver-mvp-know"."account_loan" al
    ON a.account_id   = al.account_id
   AND a.credit_union = al.credit_union
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."account_types" at
    ON UPPER(TRIM(a.account_type)) = UPPER(TRIM(at.account_type))
   AND a.credit_union              = at.credit_union
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
  ON lower(trim(fi.prodigy_code)) = lower(trim(a."credit_union"))
LEFT JOIN cu_info ci
    ON ci.credit_union = a.credit_union
WHERE
    UPPER(TRIM(a.discriminator)) = 'L'
    AND UPPER(TRIM(a.account_type)) NOT IN ('CC','PCO','PCCO')
ORDER BY
    a.member_number,
    a.account_id;
