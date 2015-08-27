SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET XACT_ABORT ON;

DECLARE @new_version nvarchar(100) = N'01.01.00',
        @old_version nvarchar(100) = N'01.00',
        @script nvarchar(100) = N'audit version',
        @ext_version nvarchar(100);

IF NOT EXISTS(SELECT 1 FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = @script)
    BEGIN
        RAISERROR(N'This is an upgrade script.  Run framework install script first',20,1) WITH LOG;
    END
ELSE
    BEGIN
        SELECT @ext_version = CONVERT(nvarchar(100),value) FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = @script;
        IF LEFT(@ext_version,5) <> @old_version
            BEGIN
                RAISERROR(N'This is the wrong upgrade script.',20,1) WITH LOG;
            END
        ELSE
            BEGIN
                EXEC sys.sp_updateextendedproperty @name = @script, @value = @new_version;
            END
    END
   
PRINT 'Upgrading from version ' + @ext_version + ' to ' + @new_version;
GO
   
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- cleanup in case this still exists somewhere
IF OBJECT_ID('audit.s_LogAuditChanges','P') IS NOT NULL
    DROP PROCEDURE audit.s_LogAuditChanges;
GO

IF TYPE_ID('audit.AuditChanges') IS NOT NULL
    DROP TYPE audit.AuditChanges;
GO

IF OBJECT_ID('audit.AuditStore','U') IS NOT NULL
    DROP TABLE audit.AuditStore;
GO

PRINT '-- creating audit.AuditStore table';
GO

CREATE TABLE audit.AuditStore
(
    AuditStoreGID int NOT NULL IDENTITY(1,1) CONSTRAINT pk_audit_AuditStore PRIMARY KEY CLUSTERED,
	AuditDateTime [datetimeoffset](7) NOT NULL,
	LoginName [nvarchar](128) NOT NULL,
	AppName [nvarchar](128) NOT NULL,
	SchemaName [nvarchar](128) NOT NULL,
	TableName [nvarchar](128) NOT NULL,
	AuditKey [uniqueidentifier] NOT NULL,
	AuditType [char](1) NOT NULL,
	ColumnName [nvarchar](128) NOT NULL,
	RecordID [bigint] NOT NULL,
	OldValue [nvarchar](500) NULL,
	NewValue [nvarchar](500) NULL,
	OldValueMax [nvarchar](max) NULL,
	NewValueMax [nvarchar](max) NULL
);
GO

IF OBJECT_ID('audit.s_LogAuditChanges','P') IS NOT NULL
    DROP PROCEDURE audit.s_LogAuditChanges;
GO

PRINT '-- creating audit.s_LogAuditChanges procedure';
GO

/*************************************************************************************************

	<returns> 
			<return value="0" description="Success"/> 
	</returns>

	<samples> 
		<sample>
			<description></description>
			<code></code> 
		</sample>
	</samples> 

	<historylog> 
		<log revision="1.0" date="07/14/2015" modifier="David Sumlin">Created</log> 
        <log revision="1.1" date="07/26/2015" modifier="David Sumlin">Changed to use new audit.AuditStore table</log> 
	</historylog>         

**************************************************************************************************/
CREATE PROCEDURE [audit].[s_LogAuditChanges]
(
	@key uniqueidentifier
)
AS
SET NOCOUNT ON
SET XACT_ABORT ON

	-- Auditing variables
	DECLARE @err_sec varchar(128) = NULL,
			@exec_start datetimeoffset(7) = SYSDATETIMEOFFSET(),
			@sec_exec_start datetimeoffset(7) = SYSDATETIMEOFFSET(),			
			@exec_end datetimeoffset(7) = SYSDATETIMEOFFSET(),
			@params nvarchar(max) = NULL,
			@rows int = 0,
			@db_id int = DB_ID(),
            @db_name sysname = DB_NAME(),
			@version uniqueidentifier = NEWID();

    -- Common variables
    DECLARE @ret_val int,
            @sql nvarchar(MAX) = N'',
		    @crlf nvarchar(1) = NCHAR(13),
		    @tab nvarchar(1) = NCHAR(9);
    
    DECLARE @aud_dttm datetimeoffset(7),
            @aud_login nvarchar(128),
            @aud_app nvarchar(128),
            @aud_schema nvarchar(128),
            @aud_table nvarchar(128),
            @aud_key uniqueidentifier,
            @aud_type char(1),
            @aud_column nvarchar(128),
            @aud_record bigint,
            @aud_old varchar(8000),
            @aud_new varchar(8000)
                    
    BEGIN TRY

		SET @err_sec = 'Validate parameters'			

        IF @key IS NULL
            RAISERROR('@key must be populated',16,1);

        IF NOT EXISTS(SELECT 1 FROM audit.AuditStore WHERE AuditKey = @key)
            RAISERROR('@key must be valid',16,1);

        DECLARE curs CURSOR LOCAL FORWARD_ONLY FOR
        	SELECT 
                AuditDateTime,
                LoginName,
                AppName,
                SchemaName,
                TableName,
                AuditKey,
                AuditType,
                ColumnName,
                RecordID,
	            CASE
		            WHEN OldValue IS NULL AND NewValue IS NULL THEN CAST(LEFT(OldValueMax,4000) AS varchar(4000))
		            ELSE CAST(OldValue AS varchar(4000))
	            END OldValue,
	            CASE
		            WHEN OldValue IS NULL AND NewValue IS NULL THEN CAST(LEFT(NewValueMax,4000) AS varchar(4000))
		            ELSE CAST(NewValue AS nvarchar(4000))
	            END NewValue
        	FROM audit.AuditStore
            WHERE AuditKey = @key
            ORDER BY AuditStoreGID;
        
        OPEN curs;
        
        FETCH NEXT FROM curs INTO @aud_dttm, @aud_login, @aud_app, @aud_schema, @aud_table, @aud_key, @aud_type, @aud_column, @aud_record, @aud_old, @aud_new;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
        	
        	EXEC audit.s_KVAdd @version, 'evt_type', 'data audit';
            EXEC audit.s_KVAdd @version, 'evt_status', 'info';
            EXEC audit.s_KVAdd @version, 'timestamp', @aud_dttm;
            EXEC audit.s_KVAdd @version, 'usr_nm', @aud_login;
            EXEC audit.s_KVAdd @version, 'app_nm', @aud_app;
            EXEC audit.s_KVAdd @version, 'sch_nm', @aud_schema;
            EXEC audit.s_KVAdd @version, 'tbl_nm', @aud_table;
            EXEC audit.s_KVAdd @version, 'uid', @aud_key;
            EXEC audit.s_KVAdd @version, 'aud_type', @aud_type;
            EXEC audit.s_KVAdd @version, 'col_nm', @aud_column;
            EXEC audit.s_KVAdd @version, 'rec_id', @aud_record;
            EXEC audit.s_KVAdd @version, 'old_val', @aud_old;
            EXEC audit.s_KVAdd @version, 'new_val', @aud_new;
            EXEC audit.s_KVLog @version, 1;
        
        	FETCH NEXT FROM curs INTO @aud_dttm, @aud_login, @aud_app, @aud_schema, @aud_table, @aud_key, @aud_type, @aud_column, @aud_record, @aud_old, @aud_new;
        END
        
        CLOSE curs;
        DEALLOCATE curs;

        DELETE 
        FROM Audit.AuditStore
        WHERE AuditKey = @key;

		RETURN (0)

	END TRY
	BEGIN CATCH

        DECLARE @err_dt datetime2(7) = SYSUTCDATETIME(),
                @err_proc_nm sysname = ERROR_PROCEDURE(),
                @err_line int = ERROR_LINE(),
                @err_num int = ERROR_NUMBER(),
                @err_msg nvarchar(4000) = ERROR_MESSAGE(),
                @err_lvl int = ERROR_SEVERITY(),
                @err_state int = ERROR_STATE(),
                @log_db_nm sysname = DB_NAME(),
                @cmd varchar(1000),
                @event_info nvarchar(4000);

	    -- use this table to hold the info from DBCC INPUTBUFFER
	    DECLARE @err_tbl table 
		    (
			    [EventType] nvarchar(30) NULL, 
			    [Parameters] int NULL, 
			    [EventInfo] nvarchar(4000) NULL
		    )

		-- We're calling this to get the code that was originally executing
		SET @cmd = 'DBCC INPUTBUFFER( ' + CAST(@@spid as varchar) + ') WITH NO_INFOMSGS'

		INSERT INTO @err_tbl 
		EXEC(@cmd)

        SELECT 
            @event_info = [EventInfo]
        FROM @err_tbl;

		-- This will forcibly rollback a transaction that is marked as uncommitable
		IF (XACT_STATE()) = -1 AND @@TRANCOUNT > 0
			ROLLBACK TRANSACTION

        -- log the error
        EXEC audit.s_KVAdd @version, 'evt_type', 'error';
        EXEC audit.s_KVAdd @version, 'evt_status', 'alert';
        EXEC audit.s_KVAdd @version, 'err_dt', @err_dt;
        EXEC audit.s_KVAdd @version, 'err_announce', 1;
        EXEC audit.s_KVAdd @version, 'err_spid', @@SPID;    
        EXEC audit.s_KVAdd @version, 'err_proc_nm', @err_proc_nm;    
        EXEC audit.s_KVAdd @version, 'err_line', @err_line;    
        EXEC audit.s_KVAdd @version, 'err_num', @err_num;    
        EXEC audit.s_KVAdd @version, 'err_msg', @err_msg;    
        EXEC audit.s_KVAdd @version, 'err_lvl', @err_lvl;    
        EXEC audit.s_KVAdd @version, 'err_state', @err_state;    
        EXEC audit.s_KVAdd @version, 'srv_nm', @@SERVERNAME;
        EXEC audit.s_KVAdd @version, 'db_nm', @db_name;
        EXEC audit.s_KVAdd @version, 'uid', @version;
        EXEC audit.s_KVAdd @version, 'sec_nm', @err_sec;
        EXEC audit.s_KVAdd @version, 'evt_txt', @event_info;
        EXEC audit.s_KVAdd @version, 'evt_info', @params;
        EXEC audit.s_KVLog @version, 0;

		-- Return error message to calling code via @@ERROR and error number via return code
		RAISERROR (@err_msg, @err_lvl, 1)
		RETURN(ERROR_NUMBER())

	END CATCH
GO

IF OBJECT_ID('audit.f_GetAuditSQL','FN') IS NOT NULL
    BEGIN
        DROP FUNCTION audit.f_GetAuditSQL;
    END
GO
PRINT 'creating audit.f_GetAuditSQL function';
GO

CREATE FUNCTION [audit].[f_GetAuditSQL]
(
	@schema_name sysname = N'',
	@table_name sysname = N'',
	@audit_type nvarchar(10) = N'',
	@inserted_table_name varchar(100),
	@deleted_table_name varchar(100),
    @audit_key nvarchar(MAX)
) 
RETURNS nvarchar(max)
AS
BEGIN
	DECLARE @retval nvarchar(max) = N'',
			@key_col sysname = N'';

	DECLARE @pk_cols TABLE (TABLE_NAME sysname NOT NULL, COLUMN_NAME sysname NOT NULL, DATA_TYPE sysname NOT NULL)

	-- get the primary key columns for the specified table
	INSERT INTO @pk_cols ( TABLE_NAME , COLUMN_NAME , DATA_TYPE)
	SELECT 
		i.name AS index_name
		,c.name AS column_name
		,TYPE_NAME(c.user_type_id)AS column_type 
	FROM sys.indexes AS i
		INNER JOIN sys.index_columns AS ic 
			ON i.object_id = ic.object_id 
			AND i.index_id = ic.index_id
		INNER JOIN sys.columns AS c 
			ON ic.object_id = c.object_id 
			AND c.column_id = ic.column_id
	WHERE i.is_primary_key = 1 
	AND i.object_id = OBJECT_ID(@schema_name + '.' + @table_name);

	-- make sure there's only a single column and it is numeric
	IF (SELECT COUNT(*) FROM @pk_cols) <> 1 OR EXISTS(SELECT 0 FROM @pk_cols WHERE DATA_TYPE NOT IN ('tinyint','smallint','int','bigint'))
		BEGIN
			-- delete the invalid rows
			DELETE FROM @pk_cols;

			-- find an identity column, or unique constraint
			INSERT INTO @pk_cols ( TABLE_NAME , COLUMN_NAME , DATA_TYPE)
			SELECT 
				TABLE_NAME,
				COLUMN_NAME,
				DATA_TYPE
			FROM INFORMATION_SCHEMA.COLUMNS 
			WHERE TABLE_SCHEMA = @schema_name
			AND COLUMNPROPERTY(OBJECT_ID(@table_name), COLUMN_NAME,'IsIdentity') = 1 
			ORDER BY TABLE_NAME 

			-- this means there's no numeric primary key, or an identity attribute, so hopefully there is a numeric unique constraint
			IF NOT EXISTS(SELECT 1 FROM @pk_cols)
				INSERT INTO @pk_cols ( TABLE_NAME , COLUMN_NAME , DATA_TYPE)
				SELECT
					c.TABLE_NAME,
					c.COLUMN_NAME,
					c.DATA_TYPE
				FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE cu
					INNER JOIN INFORMATION_SCHEMA.COLUMNS c
						ON cu.TABLE_SCHEMA = c.TABLE_SCHEMA
						AND cu.TABLE_NAME = c.TABLE_NAME
						AND cu.COLUMN_NAME = c.COLUMN_NAME
					INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc 
						ON tc.CONSTRAINT_NAME = cu.CONSTRAINT_NAME
				WHERE c.TABLE_NAME = @table_name
				AND c.TABLE_SCHEMA = @schema_name
				AND tc.CONSTRAINT_TYPE = 'UNIQUE'
				AND c.DATA_TYPE IN ('int','bigint','smallint','tinyint')
				
			IF (SELECT COUNT(*) FROM @pk_cols) <> 1 OR EXISTS(SELECT 0 FROM @pk_cols WHERE DATA_TYPE NOT IN ('tinyint','smallint','int','bigint'))
				RETURN @retval 
		END

	-- get the primary key column name
	SELECT	@key_col = COLUMN_NAME FROM @pk_cols;

	IF NOT EXISTS (SELECT 0 FROM [audit].[AuditConfig] WHERE Tablename = @table_name AND EnableAudit = 1)
		RETURN @retval

	SET @retval =	N'
					INSERT INTO [audit].[AuditStore] (AuditDateTime,AppName,AuditKey,SchemaName,TableName,AuditType,LoginName,ColumnName,RecordId,OldValue,NewValue,OldValueMax,NewValueMax)
					SELECT ''' + CAST(SYSDATETIMEOFFSET() AS nvarchar(50)) + N''',''' + APP_NAME() +  N''',''' + @audit_key + N''',''' + @schema_name + N''',''' + @table_name + N''',''' + LOWER(LEFT(@audit_type,1)) + N''', 
					* 
					FROM 
					(
					'

	DECLARE @add_union bit = 0,
			@column_name nvarchar(100) = N'',
			@is_max bit = 0

	DECLARE curs CURSOR FOR 
		SELECT 
			ac.ColumnName,
			CASE
				WHEN c.DATA_TYPE IN ('nvarchar','varchar','varbinary','char','nchar') THEN CASE
																				WHEN c.CHARACTER_MAXIMUM_LENGTH > 500 OR c.CHARACTER_MAXIMUM_LENGTH = - 1 THEN 1
																				ELSE 0
																			END
				WHEN c.DATA_TYPE IN ('image','text','ntext') THEN 1
				ELSE 0
			END AS IsMax
		FROM audit.AuditConfig ac
			INNER JOIN INFORMATION_SCHEMA.COLUMNS c
				ON ac.ColumnName = c.COLUMN_NAME
				AND ac.TableName = c.TABLE_NAME
		WHERE ac.Tablename = @table_name 
		AND ac.EnableAudit = 1

	OPEN curs
	FETCH NEXT FROM curs INTO @column_name, @is_max
	WHILE @@FETCH_STATUS = 0 
	BEGIN

		IF @add_union = 1 
			SET @retval = @retval + N' UNION '

		IF @audit_type = N'insert'
			BEGIN
				SET @retval = @retval + N'
					SELECT RIGHT(ORIGINAL_LOGIN(),LEN(ISNULL(ORIGINAL_LOGIN(),''''))-CHARINDEX(''\'',ISNULL(ORIGINAL_LOGIN(),''''),1)) AS LoginName,''' + @column_name + N''' AS ColumnName, i.' + @key_col + N' AS RecordID, NULL AS OldValue, ' + 
					CASE 
						WHEN @is_max = 1 THEN N'NULL AS NewValue' 
						ELSE N'CONVERT(nvarchar(500),i.['+ @column_name + N']) AS NewValue' 
					END + N', NULL AS OldValueMax, ' + 
					CASE 
						WHEN @is_max = 1 THEN N'CONVERT(nvarchar(max),i.[' + @column_name + N']) AS NewValueMax' 
						ELSE N'NULL AS NewValueMax' 
					END + 
					N' FROM [' + @inserted_table_name + N'] i'
			END

		IF @audit_type = N'update'
			BEGIN
				SET @retval = @retval + N'
					SELECT RIGHT(ORIGINAL_LOGIN(),LEN(ISNULL(ORIGINAL_LOGIN(),''''))-CHARINDEX(''\'',ISNULL(ORIGINAL_LOGIN(),''''),1)) AS LoginName,''' + @column_name + N''' AS ColumnName, i.' + @key_col + N' AS RecordID, ' +
					CASE
						WHEN @is_max = 1 THEN N'NULL AS OldValue, NULL AS NewValue, CONVERT(nvarchar(max),d.['+ @column_name + N']) AS OldValueMax, CONVERT(nvarchar(max),i.['+ @column_name + N']) AS NewValueMax '
						ELSE N'CONVERT(nvarchar(500),d.['+ @column_name + N']) AS OldValue, CONVERT(nvarchar(500),i.['+ @column_name + N']) AS NewValue, NULL AS OldValueMax, NULL AS NewValueMax '
					END + N' FROM [' + @inserted_table_name + N'] i ' +
					N'INNER JOIN [' + @deleted_table_name + N'] d ON i.' + @key_col + N' = d.' + @key_col + N' AND (i.['+ @column_name + N'] <> d.['+ @column_name + N'] OR i.['+ @column_name + N'] IS NOT NULL AND d.['+ @column_name + N'] IS NULL OR i.[' + @column_name + N'] IS NULL AND d.[' + @column_name + N'] IS NOT NULL)'
			END

		IF @audit_type = N'delete'
			BEGIN
				SET @retval = @retval + N'
					SELECT RIGHT(ORIGINAL_LOGIN(),LEN(ISNULL(ORIGINAL_LOGIN(),''''))-CHARINDEX(''\'',ISNULL(ORIGINAL_LOGIN(),''''),1)) AS LoginName,''' + @column_name + N''' AS ColumnName, i.' + @key_col + N' AS RecordID, ' + 
					CASE
						WHEN @is_max = 1 THEN N'NULL OldValue, '
						ELSE N'CONVERT(nvarchar(500),i.[' + @column_name + N']) AS OldValue, '
					END + N'NULL AS NewValue, ' +
					CASE
						WHEN @is_max = 1 THEN N'CONVERT(nvarchar(max),i.[' + @column_name + N']) AS OldValueMax, '
						ELSE N'NULL AS OldValueMax, '
					END + N'NULL NewValueMax FROM [' + @deleted_table_name + N'] i'
			END
        
		SET @add_union = 1

		FETCH NEXT FROM curs INTO @column_name, @is_max
	END
    
	CLOSE curs
	DEALLOCATE curs

	SET @retval = @retval + N') d'

	RETURN @retval
END;
GO


IF OBJECT_ID('audit.s_RecreateTableTriggers','P') IS NOT NULL
    BEGIN
        DROP PROCEDURE audit.s_RecreateTableTriggers;
    END
GO
PRINT 'creating audit.s_RecreateTableTriggers procedure';
GO

CREATE PROCEDURE [audit].[s_RecreateTableTriggers]
(
	@apply_to_schema sysname = NULL,
	@apply_to_table sysname = NULL,
	@remove_triggers_only bit = 0,
	@actions smallint = NULL
)  
AS
SET NOCOUNT ON

DECLARE @schema_name sysname = N'',
		@table_name sysname = N'',
		@sql nvarchar(MAX) = N'',
		@sql_actions nvarchar(100) = N''

-- allow for dynamically determining the actions the trigger will apply to
-- @actions = 1 = INSERT, 2 = UPDATE, 4 = DELETE
SELECT @sql_actions = N''
SELECT @sql_actions = @sql_actions + CASE 
										WHEN (@actions & 1) = @actions THEN N'INSERT'
										WHEN (@actions & 2) = @actions THEN N'UPDATE'
										WHEN (@actions & 3) = @actions THEN N'INSERT, UPDATE'
										WHEN (@actions & 4) = @actions THEN N'DELETE'
										WHEN (@actions & 5) = @actions THEN N'INSERT, DELETE'
										WHEN (@actions & 6) = @actions THEN N'UPDATE, DELETE'
										WHEN (@actions & 7) = @actions THEN N'INSERT, UPDATE, DELETE'
										ELSE N''
									END;

IF @sql_actions = N''
	RAISERROR('@actions value was invalid',16,1);

SELECT @remove_triggers_only = ISNULL(@remove_triggers_only,0)

DECLARE curs CURSOR FOR 
	SELECT 
		s.name, 
		t.name 
	FROM sys.tables t 
		INNER JOIN (SELECT DISTINCT TableName FROM audit.AuditConfig) a
			ON t.name = a.TableName
		INNER JOIN sys.schemas s 
			ON t.schema_id = s.schema_id 
	WHERE (@apply_to_schema IS NULL OR s.name = @apply_to_schema)
	AND (@apply_to_table IS NULL OR t.name = @apply_to_table)

OPEN curs
FETCH NEXT FROM curs INTO @schema_name, @table_name

WHILE @@FETCH_STATUS = 0
BEGIN
	PRINT 'Processing table: ' + @table_name
	PRINT '...Dropping Trigger.'

	SET @sql = N'IF OBJECT_ID (''[' + @schema_name + N'].[tr_' + @table_name + N'_Audit]'',''TR'') IS NOT NULL BEGIN DROP TRIGGER [' + @schema_name + N'].[tr_' + @table_name + N'_Audit] END;'
	EXEC sp_executesql @sql

	IF @remove_triggers_only = 0
		BEGIN

			PRINT '...Creating Trigger.'

			DECLARE @lf nchar(1) = NCHAR(10)

			-- INSERT, UPDATE, DELETE Trigger
			SET @sql = N''
			SET @sql = @sql + N'CREATE TRIGGER [' + @schema_name + N'].[tr_' + @table_name + N'_audit] ON [' + @schema_name + N'].[' + @table_name + N'] ' + @lf + N'AFTER ' + @sql_actions + ' ' + @lf + N'AS ' + @lf
			SET @sql = @sql + N'SET NOCOUNT ON ' + @lf
			SET @sql = @sql + @lf
			SET @sql = @sql + N'BEGIN ' + @lf
			SET @sql = @sql + N'	SELECT * INTO #tmp' + @table_name + N'_Inserted FROM inserted; ' + @lf
			SET @sql = @sql + N'	SELECT * INTO #tmp' + @table_name + N'_Deleted FROM deleted; ' + @lf + @lf
			SET @sql = @sql + @lf
			SET @sql = @sql + N'	DECLARE @sql nvarchar(max), @key nvarchar(100), @action nvarchar(10) = ''insert''; ' + @lf + @lf
			SET @sql = @sql + @lf
			SET @sql = @sql + N'	IF EXISTS(SELECT * FROM deleted) ' + @lf
			SET @sql = @sql + N'		BEGIN ' + @lf
			SET @sql = @sql + N'			SET @action = CASE WHEN EXISTS(SELECT * FROM inserted) THEN N''update'' ELSE N''delete'' END ' + @lf
			SET @sql = @sql + N'		END ' + @lf + @lf
			SET @sql = @sql + @lf
            SET @sql = @sql + N'    SELECT	@key = AuditKey FROM [audit].[v_AuditKey] ' + @lf
            SET @sql = @sql + @lf
			SET @sql = @sql + N'	SELECT  @sql = [Audit].[f_GetAuditSQL](''' + @schema_name + N''',''' + @table_name + N''','''' + @action + '''',''#tmp' + @table_name + N'_Inserted'',''#tmp' + @table_name + N'_Deleted'','''' + CAST(@key AS nvarchar(100)) + N''''); ' + @lf
			SET @sql = @sql + @lf
			SET @sql = @sql + N'	IF ISNULL(@sql,'''') <> '''' EXEC sp_executesql @sql; ' + @lf
			SET @sql = @sql + @lf
            SET @sql = @sql + N'    EXEC audit.s_LogAuditChanges @key;' + @lf + @lf
            SET @sql = @sql + @lf
			SET @sql = @sql + N'	DROP TABLE #tmp' + @table_name + N'_Inserted; ' + @lf
			SET @sql = @sql + N'	DROP TABLE #tmp' + @table_name + N'_Deleted; ' + @lf
			SET @sql = @sql + N'END' + @lf

			EXEC sp_executesql @sql

			-- set the audit trigger to fire last
			IF (@actions & 1) = @actions 
				EXEC sp_settriggerorder @triggername = @sql, @order='Last', @stmttype = 'INSERT';
			IF (@actions & 2) = @actions 
				EXEC sp_settriggerorder @triggername = @sql, @order='Last', @stmttype = 'UPDATE';
			IF (@actions & 4) = @actions 	
				EXEC sp_settriggerorder @triggername = @sql, @order='Last', @stmttype = 'DELETE';

		END

	FETCH NEXT FROM curs INTO @schema_name, @table_name
END

CLOSE curs
DEALLOCATE curs;
GO

IF OBJECT_ID('audit.s_KVLog','P') IS NOT NULL
    BEGIN
        DROP PROCEDURE audit.s_KVLog;
    END
GO

PRINT 'creating audit.s_KVLog procedure';
GO

/*************************************************************************************************
	
	<scope>For logging</scope>
	
	<returns> 
		<return code="0"	message="Success"	type="Success" /> 
	</returns>
	
	<samples> 
		<sample>
		   <description></description>
		   <code></code> 
		</sample>
	</samples> 

	<historylog> 
		<log revision="1.0" date="05/22/2015" modifier="David Sumlin">Created</log> 
        <log revision="1.1" date="05/22/2015" modifier="David Sumlin">Added common parameters to add to KVStore</log> 
        <log revision="1.2" date="05/23/2015" modifier="David Sumlin">Added better error handling and changed dates to datetime2 instead of timeoffset</log> 
        <log revision="1.3" date="07/06/2015" modifier="David Sumlin">Added attributes to XML to add data type information, also add audit framework revision</log> 
        <log revision="1.4" date="07/09/2015" modifier="David Sumlin">Removed error logging, since it would create an endless cycle</log> 
        <log revision="1.5" date="07/26/2015" modifier="David Sumlin">Fixed handling of sch_nm if already exists in KVStore</log> 
	</historylog>         

**************************************************************************************************/
CREATE PROCEDURE [Audit].[s_KVLog]
(
	@session uniqueidentifier, 
	@clear bit = 0
)
AS
SET NOCOUNT ON
SET XACT_ABORT ON

	DECLARE @err_sec varchar(128) = NULL,
            @xml xml,
            @output varchar(max),
            @k varchar(100),
            @v sql_variant,
            @db_id sql_variant,
            @obj_id sql_variant;

    -- validate input variables
    IF @session IS NULL
        RAISERROR('@session can''t be NULL',16,1);

    IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session)
        RAISERROR('@session value does not exist',16,1);

    SET @clear = COALESCE(@clear,0);

	BEGIN TRY

        SET @err_sec = 'client application name';
        SET @k = 'client_nm';
        SET @v = APP_NAME();
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'server name';
        SET @k = 'srv_nm';
        SET @v = @@SERVERNAME;
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'machine name';
        SET @k = 'mach_nm';
        SET @v = HOST_NAME();
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'user name';
        SET @k = 'usr_nm';
        SET @v = ORIGINAL_LOGIN();
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO Audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'unique id';
        SET @k = 'uid';
        SELECT @v = @session;
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'object id';
        SET @k = 'obj_id';
        SELECT @v = 0;
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'database id';
        SET @k = 'db_id';
        SELECT @v = DB_ID()
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'audit framework revision';
        SET @k = 'audit_framework_rev';
        SELECT @V = CONVERT(nvarchar(100),value) FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = N'audit version';
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'intermediary ids';
        SET @k = 'obj_id';
        SELECT @obj_id = V
        FROM audit.KVStore
        WHERE KVStoreGID = @session
        AND K = @k;

        SET @k = 'db_id';
        SELECT @db_id = V
        FROM audit.KVStore
        WHERE KVStoreGID = @session
        AND K = @k;

        SET @err_sec = 'database name';
        SET @k = 'db_nm';
        SET @v = COALESCE(DB_NAME(CONVERT(int,@db_id)),'');
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END
        ELSE
            BEGIN
                UPDATE audit.KVStore
                SET V = @v
                WHERE KVStoreGID = @session
                AND K = @k;
            END

        SET @err_sec = 'schema name';
        SET @k = 'sch_nm';
        SET @v = COALESCE(OBJECT_SCHEMA_NAME(CONVERT(int,@obj_id),CONVERT(int,@db_id)),'');
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END
        ELSE
            BEGIN
                -- basically, if it already exists, and we didn't get a valid value from above calculation
                -- continue to use pre-existing schema name
                SELECT @v = COALESCE(NULLIF(@v,''),V) 
                FROM audit.KVStore
                WHERE KVStoreGID = @session
                AND K = @k;

                UPDATE audit.KVStore
                SET V = @v
                WHERE KVStoreGID = @session
                AND K = @k;
            END

        SET @err_sec = 'object name';
        SET @k = 'obj_nm';
        SET @v = COALESCE(OBJECT_NAME(CONVERT(int,@obj_id), CONVERT(int,@db_id)),'');
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END
        ELSE
            BEGIN
                UPDATE audit.KVStore
                SET V = @v
                WHERE KVStoreGID = @session
                AND K = @k;
            END

        SET @err_sec = 'convert to xml';
        SET @output = '<event>'

        SELECT  @output = @output + 
                    '<' + LOWER(K) + ' data_type="' + CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(128)) + '" precision="' + CAST(SQL_VARIANT_PROPERTY(V,'Precision') AS varchar(10)) + '" scale="' + CAST(SQL_VARIANT_PROPERTY(V,'Scale') AS varchar(10)) + '" MaxLength="' + CAST(SQL_VARIANT_PROPERTY(V,'MaxLength') AS varchar(10)) + '">' + 
                    CASE 
                        WHEN CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(100)) = 'datetimeoffset' THEN CONVERT(varchar(100),V,21)
                        WHEN CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(100)) = 'date' THEN CONVERT(varchar(100),V,21)
                        WHEN CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(100)) = 'datetime' THEN CONVERT(varchar(100),V,21)
                        WHEN CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(100)) = 'datetime2' THEN CONVERT(varchar(100),V,21)
                        WHEN CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(100)) = 'smalldatetime' THEN CONVERT(varchar(100),V,21)
                        WHEN CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(100)) = 'time' THEN CONVERT(varchar(100),V,21)
                        ELSE CAST(V AS varchar(MAX))
                    END + 
                    '</' + LOWER(K) + '>'
        FROM audit.KVStore
        WHERE KVStoreGID = @session;
        
        SET @output = @output + '</event>'
        
        SET @xml = TRY_CAST(@output AS xml);
        
        IF @xml IS NULL
            RAISERROR('@xml is not valid xml',16,1);

        SET @err_sec = 'log the event';
        -- ### TODO: call SB queue        
        INSERT INTO audit.EventSink (EventMessage) VALUES (@xml);

        SET @err_sec = 'delete from KVStore';
        IF @clear = 1
            BEGIN
                DELETE 
                FROM audit.KVStore
                WHERE KVStoreGID = @session;
            END

	    RETURN(0)
				
	END TRY
	BEGIN CATCH

	   BEGIN

			-- Declare local variables so we can return them to the caller			
			DECLARE @err_msg varchar(1000),
					@err_severity int;
			
			SELECT	@err_msg = ERROR_MESSAGE(),
					@err_severity = ERROR_SEVERITY();

			-- This will forcibly rollback a transaction that is marked as uncommitable
			IF (XACT_STATE()) = -1 AND @@TRANCOUNT > 0
				ROLLBACK TRANSACTION

		END

		-- Return error message to calling code via @@ERROR and error number via return code
		RAISERROR (@err_msg, @err_severity, 1)
		RETURN(ERROR_NUMBER())

	END CATCH
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Log the values in KVStore table to Audit Log' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVLog'
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Unique session ID to identify different KV groupings in KVStore' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVLog', @level2type=N'PARAMETER',@level2name=N'@session'
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Flag to determine whether or not to delete rows in KVStore matching @session after logging them' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVLog', @level2type=N'PARAMETER',@level2name=N'@clear'
GO

