SELECT
    la.credit_union AS credit_union,
    fi.idfi AS idfi,
    la.loan_application_id AS application_id,
    la.member_number AS member_id,
    la.application_date,
    la.action_date AS response_date,
    las.description AS application_status,
    CASE
        WHEN COALESCE(TRY_CAST(las.approved_flag AS boolean), false)         THEN 'APPROVED'
        WHEN COALESCE(TRY_CAST(las.adverse_action_flag AS boolean), false)   THEN 'DENIED'
        WHEN COALESCE(TRY_CAST(las.withdrawn_flag AS boolean), false)        THEN 'WITHDRAWN'
        WHEN COALESCE(TRY_CAST(las.incomplete_flag AS boolean), false)       THEN 'INCOMPLETE'
        ELSE 'PENDING'
    END AS status_category,
    CASE
        WHEN la.denial_reason1 IS NOT NULL
            THEN concat_ws('; ', ARRAY[la.denial_reason1, NULLIF(la.denial_reason2, ''), NULLIF(la.denial_reason3, '')])
        WHEN la.loan_app_denial_other IS NOT NULL
            THEN la.loan_app_denial_other
        WHEN COALESCE(TRY_CAST(las.approved_flag AS boolean), false)
            THEN 'APPROVED'
        WHEN UPPER(TRIM(las.description)) = 'PENDING'
            THEN 'UNDER REVIEW'
        WHEN UPPER(TRIM(las.description)) = 'WITHDRAW'
            THEN 'MEMBER WITHDREW'
        ELSE 'NO REASON SPECIFIED'
    END AS status_reason,
    CASE
        WHEN TRIM(la.created_by_userid) IN ('102','103','104','105','106','107','108','109') THEN 'ONLINE'
        WHEN TRIM(la.created_by_userid) = 'SYS'                                            THEN 'SYSTEM/AUTOMATED'
        WHEN regexp_like(TRIM(la.created_by_userid), '^[0-9]{1,2}$')                       THEN 'IN-BRANCH'
        WHEN la.created_by_userid IS NOT NULL                                              THEN 'STAFF_ASSISTED'
        ELSE 'UNKNOWN'
    END AS origination_channel,
    la.account_id AS loan_id,
    lt.description AS loan_type,
    la.loan_amount AS requested_amount,
    COALESCE(TRY_CAST(la.funded_flag AS boolean), false) AS is_funded,
    COALESCE(TRY_CAST(la.closed_flag AS boolean), false) AS is_closed,
    COALESCE(TRY_CAST(la.auto_approved_flag AS boolean), false) AS auto_approved,
    la.loan_officer_userid AS processing_officer,
    la.approving_loan_officer_userid AS approving_officer,
    date_diff('day', la.application_date, COALESCE(la.action_date, current_date)) AS days_to_decision,
    la.created_timestamp AS application_submitted_timestamp,
    la.created_by_userid AS submitted_by_user
FROM "AwsDataCatalog"."silver-mvp-know"."loan_application" la
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."loan_app_status" las
  ON la.credit_union = las.credit_union
 AND la.loan_app_status_id = las.loan_app_status_id
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."loan_type" lt
  ON la.credit_union = lt.credit_union
 AND la.loan_type_id = lt.loan_type_id
LEFT JOIN "AwsDataCatalog"."silver-mvp-know"."blossomcompany_olb_map" fi
  ON fi.prodigy_code = la.credit_union
ORDER BY
    la.application_date DESC,
    la.loan_application_id DESC;
