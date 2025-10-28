SELECT
  m.member_id,
  m.member_number,
  -- NEW: Filter columns for dashboard (same as product_overview.sql and query_prodigy.sql)
  CASE WHEN m.member_number > 0 THEN 'Valid' ELSE 'Invalid' END AS 'member_number_is_valid',
  CASE WHEN m.inactive_flag = 'I' THEN 'Inactive Flag' ELSE 'Active Flag' END AS 'member_inactive_flag_status',
  -- Treat NULL as "Has Open Accounts" (ELSE clause includes NULL values)
  CASE WHEN m.all_accounts_closed = 1 THEN 'All Closed' 
       ELSE 'Has Open Accounts' 
  END AS 'member_accounts_status',
  m.inactive_flag AS 'member_inactive_flag_code',
  m.all_accounts_closed AS 'member_all_accounts_closed_flag',
  
  CAST(m.join_date AS DATE) AS 'join_date',
  CASE WHEN m.all_accounts_closed = 1 THEN 'Yes' ELSE 'No' END AS 'Closed Membership',
  m.modified_timestamp,
  AVG(a.current_balance) AS 'average_balance',
  SUM(a.current_balance) AS 'total_balance',
  SUM(CASE 
    WHEN a.discriminator IN ('S', 'D', 'C') 
    THEN a.current_balance 
    ELSE 0 
  END) AS 'total_deposits_balance',
  SUM(CASE 
    WHEN a.discriminator = 'L' 
    THEN a.current_balance 
    ELSE 0 
  END) AS 'total_loans_balance'
FROM member m
LEFT JOIN account a ON m.member_number = a.member_number
GROUP BY 
  m.member_id, 
  m.member_number,
  m.inactive_flag,
  m.all_accounts_closed,
  m.join_date, 
  m.modified_timestamp
