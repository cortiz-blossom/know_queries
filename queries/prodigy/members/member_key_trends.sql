SELECT
  m.member_id,
  CAST(m.join_date AS DATE) AS 'join_date',
  m.all_accounts_closed AS 'Closed Membership',
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
GROUP BY m.member_id, m.join_date, m.all_accounts_closed, m.modified_timestamp