WITH
th_base AS (
  SELECT
      th.transaction_history_id,
      th.batch_number,
      th.tran_code,
      th.date_effective,
      th.total_amount,
      th.member_id,
      th.account_id,
      th.gl_chart_of_account_id,
      th.branch_config_id,
      th.void_flag,
      th.user_id,
      th.description,
      th.created_timestamp,
      th.modified_timestamp
  FROM transaction_history th
  WHERE
      th.date_effective >= '2022-01-01'   -- ⬅️ desde inicio de 2022
      AND th.tran_code IN ('SHDV','CTDV')  -- sin accruals (GLDV va en otra query)
      AND th.void_flag = 0
      AND th.total_amount <> 0
),

/* 2) Dimensiones compactas (sin nombres ni DOB ni join_date) */
dim_member AS (
  SELECT
      m.member_id,
      m.member_number
  FROM member m
),
dim_account AS (
  SELECT
      a.account_id,
      a.account_number,
      a.account_type,
      a.discriminator,
      a.current_balance,
      a.status
  FROM account a
),
dim_branch AS (
  SELECT
      bc.branch_config_id,
      bc.branch_number,
      be_branch.name_last AS branch_name
  FROM branch_config bc
  LEFT JOIN entity be_branch ON bc.branch_entity_id = be_branch.entity_id
),
dim_coa AS (
  SELECT
      gcoa.record_number,
      gcoa.account_number,
      gcoa.description,
      gcoa.short_desc
  FROM gl_chart_of_accounts gcoa
)

/* 3) Proyección final */
SELECT 
    -- ===== ID TRANSACCIÓN =====
    CONCAT('TXN_', th.tran_code, '_', th.transaction_history_id) AS ID_Dividend_Transaction,
    th.transaction_history_id AS Transaction_History_ID,
    th.batch_number AS Batch_Number,
    th.tran_code AS Transaction_Code,
    CASE 
        WHEN th.tran_code = 'SHDV' THEN 'SHARE_DIVIDEND_TO_MEMBER'
        WHEN th.tran_code = 'CTDV' THEN 'CERTIFICATE_DIVIDEND'
        ELSE CONCAT('OTHER_DIVIDEND_', th.tran_code)
    END AS Transaction_Type,

    -- ===== FECHAS =====
    th.date_effective AS Transaction_Date,
    YEAR(th.date_effective)      AS Transaction_Year,
    MONTH(th.date_effective)     AS Transaction_Month,
    QUARTER(th.date_effective)   AS Transaction_Quarter,
    DATE_FORMAT(th.date_effective, '%Y-%m') AS `year_month`,

    -- ===== MONTOS =====
    th.total_amount AS Amount,
    ABS(th.total_amount) AS Amount_Absolute,

    -- ===== MIEMBRO (sin nombres/DOB/join_date) =====
    th.member_id         AS Member_ID,
    dm.member_number     AS Member_Number,

    -- ===== CUENTA =====
    th.account_id        AS Account_ID,
    da.account_number    AS Account_Number,
    da.account_type      AS Account_Type,
    da.discriminator     AS Account_Discriminator,
    CASE 
        WHEN da.discriminator = 'S' THEN 'SAVINGS'
        WHEN da.discriminator = 'C' THEN 'CERTIFICATES'
        WHEN da.discriminator = 'D' THEN 'CHECKING'
        WHEN da.discriminator = 'L' THEN 'LOANS'
        WHEN da.discriminator = 'U' THEN 'SPECIAL'
        ELSE 'OTHER'
    END AS Account_Category,
    da.current_balance   AS Current_Account_Balance,
    da.status            AS Account_Status,

    -- ===== TIPO DE PRODUCTO =====
    CASE 
        WHEN da.discriminator = 'S' AND da.account_type = 'PSAV' THEN 'Primary Savings'
        WHEN da.discriminator = 'S' AND da.account_type = 'HYS'  THEN 'High Yield Savings'
        WHEN da.discriminator = 'S' AND da.account_type = 'MMA'  THEN 'Money Market'
        WHEN da.discriminator = 'S' AND da.account_type = 'SSAV' THEN 'Secondary Savings'
        WHEN da.discriminator = 'S' AND da.account_type = 'CLUB' THEN 'Club Account'
        WHEN da.discriminator = 'S' AND da.account_type = 'TISV' THEN 'Traditional IRA Savings'
        WHEN da.discriminator = 'S' AND da.account_type = 'RISV' THEN 'Roth IRA Savings'
        WHEN da.discriminator = 'S' AND da.account_type = 'YSAV' THEN 'Youth Savings'
        WHEN da.discriminator = 'S' AND da.account_type = 'SPIS' THEN 'SEP IRA Savings'
        WHEN da.discriminator = 'C' AND da.account_type = 'CERT' THEN 'Certificate of Deposit'
        WHEN da.discriminator = 'C' AND da.account_type = 'TICD' THEN 'Traditional IRA Certificate'
        WHEN da.discriminator = 'C' AND da.account_type = 'RICD' THEN 'Roth IRA Certificate'
        WHEN da.discriminator = 'C' AND da.account_type = 'EICD' THEN 'Education IRA Certificate'
        WHEN da.discriminator = 'D' AND da.account_type = 'CHK'  THEN 'Checking Account'
        WHEN da.discriminator = 'D' AND da.account_type = 'OTCK' THEN 'Overtime Checking'
        ELSE CONCAT(da.discriminator, ' - ', da.account_type)
    END AS Product_Type,

    -- ===== GL =====
    CAST(gl.account_number AS CHAR)      AS GL_Account_Number,
    gl.description         AS GL_Account_Description,
    gl.short_desc          AS GL_Account_Short_Desc,
    CASE 
        WHEN CAST(gl.account_number AS CHAR) LIKE '380.%' THEN 'DIVIDEND_EXPENSE'
        /* Eliminado 860.* porque accruals se manejan aparte */
        WHEN CAST(gl.account_number AS CHAR) LIKE '901.%' THEN 'MEMBER_DEPOSIT_ACCOUNT'
        WHEN CAST(gl.account_number AS CHAR) LIKE '903.%' THEN 'CERTIFICATE_ACCOUNT'
        WHEN CAST(gl.account_number AS CHAR) LIKE '383.%' THEN 'OTHER_DIVIDEND_EXPENSE'
        WHEN CAST(gl.account_number AS CHAR) LIKE '151.%' THEN 'CASH_ACCOUNT'
        ELSE 'OTHER_GL_ACCOUNT'
    END AS GL_Account_Category,

    -- ===== SUCURSAL =====
    th.branch_config_id   AS Branch_Config_ID,
    db.branch_number      AS Branch_Number,
    CASE 
        WHEN db.branch_name LIKE '%MINNEQUA WORKS CREDIT UNION%' THEN 'MINNEQUA WORKS CR'
        WHEN db.branch_name IS NULL THEN 'Unknown Branch'
        ELSE TRIM(db.branch_name)
    END AS Branch_Name,
    CASE 
        WHEN db.branch_number = '0' THEN 'HEADQUARTERS'
        WHEN db.branch_number = '1' THEN 'MAIN_BRANCH'
        WHEN db.branch_number = '2' THEN 'REGENCY'
        WHEN db.branch_number = '3' THEN 'PUEBLO_WEST'
        WHEN db.branch_number = '4' THEN 'EAGLERIDGE'
        WHEN db.branch_number = '5' THEN 'NEPCO'
        WHEN db.branch_number = '6' THEN 'REMOTE_SERVICES'
        ELSE 'OTHER_BRANCH'
    END AS Branch_Category,

    -- ===== CLASIFICACIÓN DE NEGOCIO (sin accruals) =====
    CASE 
        WHEN th.tran_code = 'SHDV' AND da.discriminator = 'S' THEN 'SAVINGS_DIVIDEND_PAYMENT'
        WHEN th.tran_code = 'CTDV' THEN 'CERTIFICATE_DIVIDEND_PAYMENT'
        ELSE 'OTHER_DIVIDEND_TRANSACTION'
    END AS Business_Category,

    -- ===== ESTIMACIÓN DE TASA (opcional, se mantiene) =====
    CASE 
        WHEN th.tran_code = 'SHDV' 
             AND da.current_balance > 100 
             AND th.total_amount < 0
        THEN ROUND((ABS(th.total_amount) / da.current_balance) * 100, 4)
        ELSE NULL
    END AS Estimated_Monthly_Rate_Percent,
    CASE 
        WHEN th.tran_code = 'SHDV' 
             AND da.current_balance > 100 
             AND th.total_amount < 0
        THEN ROUND((ABS(th.total_amount) / da.current_balance) * 1200, 4)
        ELSE NULL
    END AS Estimated_Annual_Rate_Percent,

    -- ===== PROCESO =====
    0 AS Is_Voided,               -- ya filtrado en th_base
    th.user_id            AS User_ID,
    th.description        AS Transaction_Description,
    th.created_timestamp  AS Created_Timestamp,
    th.modified_timestamp AS Modified_Timestamp

FROM th_base th
LEFT JOIN dim_member  dm ON th.member_id              = dm.member_id
LEFT JOIN dim_account da ON th.account_id             = da.account_id
LEFT JOIN dim_coa     gl ON th.gl_chart_of_account_id = gl.record_number
LEFT JOIN dim_branch  db ON th.branch_config_id       = db.branch_config_id