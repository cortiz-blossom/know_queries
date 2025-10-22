SELECT 
    -- Application Identification
    la.loan_application_id as application_id,
    la.member_number as member_id,
    
    -- Application Dates
    la.application_date,
    la.action_date as response_date,
    
    -- Application Status Information
    las.description as application_status,
    CASE 
        WHEN las.approved_flag = 1 THEN 'APPROVED'
        WHEN las.adverse_action_flag = 1 THEN 'DENIED'
        WHEN las.withdrawn_flag = 1 THEN 'WITHDRAWN'
        WHEN las.incomplete_flag = 1 THEN 'INCOMPLETE'
        ELSE 'PENDING'
    END as status_category,
    
    -- Status Reason (Denial Reasons)
    CASE 
        WHEN la.denial_reason1 IS NOT NULL THEN 
            CONCAT_WS('; ', 
                la.denial_reason1,
                NULLIF(la.denial_reason2, ''),
                NULLIF(la.denial_reason3, '')
            )
        WHEN la.loan_app_denial_other IS NOT NULL THEN la.loan_app_denial_other
        WHEN las.approved_flag = 1 THEN 'APPROVED'
        WHEN las.description = 'PENDING' THEN 'UNDER REVIEW'
        WHEN las.description = 'WITHDRAW' THEN 'MEMBER WITHDREW'
        ELSE 'NO REASON SPECIFIED'
    END as status_reason,
    
    -- Origination Channel (Based on created_by_userid patterns)
    CASE 
        WHEN la.created_by_userid IN ('102', '103', '104', '105', '106', '107', '108', '109') THEN 'ONLINE'
        WHEN la.created_by_userid = 'SYS' THEN 'SYSTEM/AUTOMATED'
        WHEN la.created_by_userid REGEXP '^[0-9]{1,2}$' THEN 'IN-BRANCH'
        WHEN la.created_by_userid IS NOT NULL THEN 'STAFF_ASSISTED'
        ELSE 'UNKNOWN'
    END as origination_channel,
    
    -- Account/Loan Information
    la.account_id as loan_id,  -- This will be populated if loan was approved and funded
    lt.description as loan_type,
    la.loan_amount as requested_amount,
    
    -- Application Outcome Flags
    la.funded_flag as is_funded,
    la.closed_flag as is_closed,
    la.auto_approved_flag as auto_approved,
    
    -- Processing Information
    la.loan_officer_userid as processing_officer,
    la.approving_loan_officer_userid as approving_officer,
    
    -- Additional Details
    DATEDIFF(COALESCE(la.action_date, CURRENT_DATE), la.application_date) as days_to_decision,
    la.created_timestamp as application_submitted_timestamp,
    la.created_by_userid as submitted_by_user

FROM loan_application la
LEFT JOIN loan_app_status las ON la.loan_app_status_id = las.loan_app_status_id
LEFT JOIN loan_type lt ON la.loan_type_id = lt.loan_type_id
ORDER BY la.application_date DESC, la.loan_application_id DESC