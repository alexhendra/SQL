/******************************************************************
PURPOSE      		: Employee lookup server control.
PROJECT NAME		: Server control.
NOTES         		: -
SAMPLE        		: -
------------------------------------------------------------------
16 January 2008 - 0000893697 - Krisna Dharma 
Add initial revision history to comply with code review standard. 
Moving all framework related database objects from webdb to kamorodb.
------------------------------------------------------------------
8 May 2008 - 0000275624 - Yusuf Wibowo
Add dummy supplier_name.
------------------------------------------------------------------
10 June 2008 - 0000275624 - Yusuf Wibowo 
Point to GER.
------------------------------------------------------------------
18 July 2008 - 0000893697 - Krisna Dharma
Alter xml datatype from text to ntext.
------------------------------------------------------------------
10 September 2008 - 0000275624 - Yusuf Wibowo 
Remove variable @intFirstLast.
Enable to display terminated employees based on the parameter.
------------------------------------------------------------------
28 May 2009 - 0000275624 - Yusuf Wibowo
Exclude kamoro account 0000000000.
------------------------------------------------------------------
19 August 2009 - 0000275624 - Yusuf Wibowo
Include employee with future hire date.
------------------------------------------------------------------
11 September 2009 - 0000275624 - Yusuf Wibowo
Enable to search by computer login.
------------------------------------------------------------------
14 December 2009 - 0000275624 - Yusuf Wibowo
If display_name is numeric then search for employee id only.
------------------------------------------------------------------
2 March 2010 - 0000275624 - Yusuf Wibowo
Include employees with future hire date in the normal search criteria - do not tick terminated employees checkbox.
------------------------------------------------------------------
15 February 2011 - 0000275624 - Yusuf Wibowo
Id max_rows is not defined then return top 50 records.
Remove FOR XML RAW
------------------------------------------------------------------
27 April 2012 - 0000893697
Support mobile lookup employee, only return selected fields.
@PARAM for mobile only using the display_name attribute
splookup_lts00014 0, '<root><row display_name="krisna" /></root>', 1
splookup_lts00014 0, '<root><row display_name="893697" /></root>', 1
------------------------------------------------------------------
29 February 2013 - 0000893697 - Krisna Dharma
Added email_address for presence info
------------------------------------------------------------------
12 February 2014 - 0000893697 - Krisna Dharma
Added status field.
------------------------------------------------------------------
7 March 2014 - 0000275624 - Yusuf Wibowo
Added fields work_phone and mobile_phone to support fmmobile.
------------------------------------------------------------------
12 March 2014 - 0000275624 - Yusuf Wibowo
Add photo_url for mobile employee lookup.
------------------------------------------------------------------        
4 April 2014 - 0000275624 - Yusuf Wibowo
Return field TYPE_DESC.
------------------------------------------------------------------
20 Aug 2014 - 0000893697 - Krisna Dharma
Add job_title for mobile employee lookup.
------------------------------------------------------------------
--2018-01-26	wperada	SQL 2016 - Change the ORDER BY integer ordinal value with column name or column alias.
------------------------------------------------------------------
--2018-08-14	mrumonda SQL 2016 - change ntext to nvarchar(max)

-- 29-10-2018 apanjait PTFI_SQL_2016: Fixing ORDER BY specifies integer ordinal (this query from customappsdbna)
******************************************************************/
Use KamoroDB
GO

ALTER PROCEDURE [dbo].[splookup_lts00014]
	@LOG_NUMBER AS INT,
	@PARAM AS NVARCHAR(MAX),
	@SUPPORT_MOBILE_ONLY AS BIT = 0
AS

SET NOCOUNT ON

-- insert into ##data select @pstrXML
DECLARE @intFlag AS INT
DECLARE @strPrincipalLoc AS VARCHAR(1024)
DECLARE @strCompany AS VARCHAR(1024)
DECLARE @strDisplayName AS VARCHAR(1024)
DECLARE @strBunit AS VARCHAR(1024)
DECLARE @strDept AS VARCHAR(1024)
DECLARE @intMaxRows AS integer
DECLARE @strEmpType AS VARCHAR(1)
DECLARE @intDisplayTerminatedEmployees AS BIT             
DECLARE @NAME_PART_1 VARCHAR(30)                
DECLARE @NAME_PART_2 VARCHAR(30)                
DECLARE @SEARCH_TYPE INT    

EXEC SP_XML_PREPAREDOCUMENT @INTFLAG OUTPUT, @PARAM

SELECT 
	@strPrincipalLoc  = CASE WHEN ISNULL(principal_location,'') = '' THEN '%' ELSE principal_location END,
	@strCompany = CASE WHEN ISNULL(company,'') = '' THEN '%' ELSE company END,
	@strDisplayName = ISNULL(pers_surname,''),
	@strBunit = CASE WHEN ISNULL(bunit,'') = '' THEN '%' ELSE bunit END,
	@strDept = CASE WHEN ISNULL(dept,'') = '' then '%' else dept END,
	@strEmpType = CASE WHEN ISNULL(emp_type,'') = '' THEN '%' ELSE emp_type END,
	@intMaxRows = ISNULL(max_rows,50),
	@intDisplayTerminatedEmployees = ISNULL(display_terminated_employees,0)
FROM OPENXML(@intFlag, '/root/row')
	WITH (principal_location VARCHAR(1024) '@principal_location',
	company VARCHAR(1024) '@company',
	pers_surname VARCHAR(1024) '@display_name',
	bunit VARCHAR(1024) '@bunit',
	dept VARCHAR(1024) '@dept',
	emp_type VARCHAR(1) '@emp_type',
	first_last VARCHAR(1) '@display_name_order',
	max_rows integer '@max_match_employees',
	display_terminated_employees bit '@display_terminated_employees')

EXEC SP_XML_REMOVEDOCUMENT @intFlag

IF (CHARINDEX( ' ', @strDisplayName ) > 0)          
BEGIN                
	SET @SEARCH_TYPE = 1                
	SET @NAME_PART_1 = SUBSTRING( @strDisplayName, 0, Charindex( ' ', @strDisplayName  ) )                
	SET @NAME_PART_2 =  SUBSTRING( @strDisplayName , Charindex( ' ', @strDisplayName  ) + 1, LEN( @strDisplayName  ) - Charindex( ' ', @strDisplayName  ) )                
END                
ELSE                
BEGIN                
	SET @SEARCH_TYPE = 2                
END                


SET ROWCOUNT @intMaxRows

IF (@strBunit = '%' AND @strDept = '%' AND @strCompany = '%' AND @strPrincipalLoc = '%' AND @strEmpType = '%')
BEGIN
	IF (@intDisplayTerminatedEmployees = 0)
	BEGIN
		-- user does not specify advanced parameter and do not display terminated employees
		IF (ISNUMERIC(@strDisplayName) = 1)
		BEGIN
			IF @SUPPORT_MOBILE_ONLY = 1
			BEGIN
			
				-- user enter numeric
				SELECT employee_id = employee_id,
					display_name = UPPER(first_last_name),
					bunit_desc = bunit_desc,
					work_phone,
					mobile_phone,
					photo_url,
					job_title
				FROM dbo.vw_employee_data_all
				WHERE employee_id = RIGHT('0000000000' + @strDisplayName,10)
					AND (status = 'A' OR hire_date >= GETDATE())
				ORDER BY display_name 
				--FOR XML RAW
			
			END
			ELSE
			BEGIN
			
				-- user enter numeric
				SELECT employee_id = employee_id,
					display_name = UPPER(first_last_name),
					bunit_desc = bunit_desc, 
					dept_desc = dept_desc,
					pos_title = job_title,
					dstrct_code = dstrct_code,
					dstrct_code_desc = dstrct_code_desc,
					bunit = bunit,
					dept = dept,
					supplier_name = RTRIM(supplier_name),
					approval_grade = employee_grade,
					supervisor_id,
					supervisor_name, 
					email_address,
					status,
					type_desc
				FROM dbo.vw_employee_data_all
				WHERE employee_id = RIGHT('0000000000' + @strDisplayName,10)
					AND (status = 'A' OR hire_date >= GETDATE())
				ORDER BY display_name 
				--FOR XML RAW
			
			END
			
		END
		ELSE
		BEGIN
			IF @SUPPORT_MOBILE_ONLY = 1
			BEGIN
				IF (@SEARCH_TYPE = 2)
				BEGIN
					-- user enter char
					SELECT employee_id = employee_id,
						display_name = UPPER(first_last_name),
						bunit_desc = bunit_desc,
						work_phone,
						mobile_phone,
						photo_url,
						job_title
					FROM dbo.vw_employee_data_all
					WHERE (first_last_name LIKE '%' + @strDisplayName + '%' 
						OR nick_name LIKE @strDisplayName + '%' 
						OR computer_login = @strDisplayName
						)
						AND employee_id <> '0000000000'
						AND (status = 'A' OR hire_date >= GETDATE())
					ORDER BY display_name 
					--FOR XML RAW
				END
				ELSE
				BEGIN
					-- user enter char
					-- split name
					SELECT employee_id = employee_id,
						display_name = UPPER(first_last_name),
						bunit_desc = bunit_desc,
						work_phone,
						mobile_phone,
						photo_url,
						job_title
					FROM dbo.vw_employee_data_all
					WHERE ((
						(first_name LIKE @NAME_PART_1 + '%' OR nick_name LIKE @NAME_PART_1 + '%')
						AND last_name LIKE @NAME_PART_2 + '%'
						)
						OR
						(
						(first_name LIKE @NAME_PART_2 + '%' OR nick_name LIKE @NAME_PART_2 + '%')
						AND last_name LIKE @NAME_PART_1 + '%'
						)
						OR
						first_name LIKE '%' + @strDisplayName + '%'
						OR
						last_name LIKE '%' + @strDisplayName + '%'
						) 
						AND employee_id <> '0000000000'
						AND (status = 'A' OR hire_date >= GETDATE())
					ORDER BY display_name 
					--FOR XML RAW
				END
			END
			ELSE
			BEGIN
				-- user enter char
				SELECT employee_id = employee_id,
					display_name = UPPER(first_last_name),
					bunit_desc = bunit_desc, 
					dept_desc = dept_desc,
					pos_title = job_title,
					dstrct_code = dstrct_code,
					dstrct_code_desc = dstrct_code_desc,
					bunit = bunit,
					dept = dept,
					supplier_name = RTRIM(supplier_name),
					approval_grade = employee_grade,
					supervisor_id,
					supervisor_name, 
					email_address,
					status,
					type_desc
				FROM dbo.vw_employee_data_all
				WHERE (first_last_name LIKE '%' + @strDisplayName + '%' 
					OR nick_name LIKE @strDisplayName + '%' 
					OR computer_login = @strDisplayName
					)
					AND employee_id <> '0000000000'
					AND (status = 'A' OR hire_date >= GETDATE())
				ORDER BY display_name 
				--FOR XML RAW
			END			
		END
	END
	ELSE
	BEGIN
		-- user does not specify advanced parameter and display terminated employees
		IF (ISNUMERIC(@strDisplayName) = 1)
		BEGIN
			-- user enter numeric
			SELECT 
				employee_id = employee_id,
				display_name = UPPER(first_last_name),
				bunit_desc = bunit_desc, 
				dept_desc = dept_desc,
				pos_title = job_title,
				dstrct_code = dstrct_code,
				dstrct_code_desc = dstrct_code_desc,
				bunit = bunit,
				dept = dept,
				supplier_name = RTRIM(supplier_name),
				approval_grade = employee_grade,
				supervisor_id,
				supervisor_name, 
				email_address,
				status,
				type_desc
			FROM dbo.vw_employee_data_all
			WHERE employee_id = RIGHT('0000000000' + @strDisplayName,10)
			ORDER BY display_name 
			--FOR XML RAW
		END
		ELSE
		BEGIN
			-- user enter char
			SELECT 
				employee_id = employee_id,
				display_name = UPPER(first_last_name),
				bunit_desc = bunit_desc, 
				dept_desc = dept_desc,
				pos_title = job_title,
				dstrct_code = dstrct_code,
				dstrct_code_desc = dstrct_code_desc,
				bunit = bunit,
				dept = dept,
				supplier_name = RTRIM(supplier_name),
				approval_grade = employee_grade,
				supervisor_id,
				supervisor_name, 
				email_address,
				status,
				type_desc
			FROM dbo.vw_employee_data_all
			WHERE (first_last_name LIKE '%' + @strDisplayName + '%' 
				OR nick_name LIKE @strDisplayName + '%' 
				OR computer_login = @strDisplayName
				)
				AND employee_id <> '0000000000'
			ORDER BY display_name 
			--FOR XML RAW
		END
	END
END
ELSE
	IF (@intDisplayTerminatedEmployees = 0)
	BEGIN
		-- When user specifies 
		-- advanced parameter such as bunit, dept, etc
		-- do not display terminated employees
		IF (ISNUMERIC(@strDisplayName) = 1)
		BEGIN
			-- user enter numeric
			SELECT 
				employee_id = employee_id,
				display_name = UPPER(first_last_name),
				bunit_desc = bunit_desc, 
				dept_desc = dept_desc,
				pos_title = job_title,
				dstrct_code = dstrct_code,
				dstrct_code_desc = dstrct_code_desc,
				bunit = bunit,
				dept = dept,
				supplier_name = RTRIM(supplier_name),
				approval_grade = employee_grade,
				supervisor_id,
				supervisor_name, 
				email_address,
				status,
				type_desc
			FROM dbo.vw_employee_data_all
			WHERE employee_id = RIGHT('0000000000' + @strDisplayName,10)
				AND bunit LIKE @strBunit
				AND dept LIKE @strDept
				AND company LIKE @strCompany
				AND principal_location LIKE @strPrincipalLoc
				AND emp_type LIKE @strEmpType			
				AND (status = 'A' OR hire_date >= GETDATE())
			ORDER BY display_name 
			--FOR XML RAW
		END
		ELSE
		BEGIN
			-- user enter char
			SELECT 
				employee_id = employee_id,
				display_name = UPPER(first_last_name),
				bunit_desc = bunit_desc, 
				dept_desc = dept_desc,
				pos_title = job_title,
				dstrct_code = dstrct_code,
				dstrct_code_desc = dstrct_code_desc,
				bunit = bunit,
				dept = dept,
				supplier_name = RTRIM(supplier_name),
				approval_grade = employee_grade,
				supervisor_id,
				supervisor_name, 
				email_address,
				status,
				type_desc
			FROM dbo.vw_employee_data_all
			WHERE bunit LIKE @strBunit
				AND dept LIKE @strDept
				AND company LIKE @strCompany
				AND principal_location LIKE @strPrincipalLoc
				AND emp_type LIKE @strEmpType
				AND (first_last_name LIKE '%' + @strDisplayName + '%' 
					OR nick_name LIKE @strDisplayName + '%'
					OR computer_login = @strDisplayName
				)
				AND employee_id <> '0000000000'
				AND (status = 'A' OR hire_date >= GETDATE())
			ORDER BY display_name 
			--FOR XML RAW
		END		
	END
	ELSE
	BEGIN
		-- When user specifies 
		-- advanced parameter such as bunit, dept, etc
		-- display terminated employees
		IF (ISNUMERIC(@strDisplayName) = 1)
		BEGIN
			-- user enter numeric
			SELECT 
				employee_id = employee_id,
				display_name = UPPER(first_last_name),
				bunit_desc = bunit_desc, 
				dept_desc = dept_desc,
				pos_title = job_title,
				dstrct_code = dstrct_code,
				dstrct_code_desc = dstrct_code_desc,
				bunit = bunit,
				dept = dept,
				supplier_name = RTRIM(supplier_name),
				approval_grade = employee_grade,
				supervisor_id,
				supervisor_name, 
				email_address,
				status,
				type_desc
			FROM dbo.vw_employee_data_all
			WHERE employee_id = RIGHT('0000000000' + @strDisplayName,10)
				AND bunit LIKE @strBunit
				AND dept LIKE @strDept
				AND company LIKE @strCompany
				AND principal_location LIKE @strPrincipalLoc
				AND emp_type LIKE @strEmpType
			ORDER BY display_name 
			--FOR XML RAW
		END
		ELSE
		BEGIN
			-- user enter char
			SELECT 
				employee_id = employee_id,
				display_name = UPPER(first_last_name),
				bunit_desc = bunit_desc, 
				dept_desc = dept_desc,
				pos_title = job_title,
				dstrct_code = dstrct_code,
				dstrct_code_desc = dstrct_code_desc,
				bunit = bunit,
				dept = dept,
				supplier_name = RTRIM(supplier_name),
				approval_grade = employee_grade,
				supervisor_id,
				supervisor_name, 
				email_address,
				status,
				type_desc
			FROM dbo.vw_employee_data_all
			WHERE bunit LIKE @strBunit
				AND dept LIKE @strDept
				AND company LIKE @strCompany
				AND principal_location LIKE @strPrincipalLoc
				AND emp_type LIKE @strEmpType
				AND (first_last_name LIKE '%' + @strDisplayName + '%'
					OR computer_login = @strDisplayName
					OR nick_name LIKE @strDisplayName + '%'
				)
				AND employee_id <> '0000000000'
			ORDER BY display_name 
			--FOR XML RAW
		END
	END

SET ROWCOUNT 0

SET NOCOUNT OFF