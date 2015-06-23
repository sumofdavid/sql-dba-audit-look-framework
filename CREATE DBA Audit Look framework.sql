    SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET XACT_ABORT ON;

-- ##########################################################
-- Change version ##.##.## upon each and every change
-- ##########################################################
DECLARE @version nvarchar(100) = N'01.00.05',
        @ext_version nvarchar(100);

IF NOT EXISTS(SELECT 1 FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = N'audit version')
    BEGIN
        EXEC sys.sp_addextendedproperty @name = N'audit version', @value = @version;
    END
ELSE
    BEGIN
        SELECT @ext_version = CONVERT(nvarchar(100),value) FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = N'audit version';
        IF @ext_version <> @version
            BEGIN
                RAISERROR(N'You must run upgrade script or drop audit objects',20,1) WITH LOG;
            END
        ELSE
            BEGIN
                RAISERROR(N'You can''t rerun this script without dropping objects first',20,1) WITH LOG;
            END
    END
   
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

PRINT '--- creating schemas'
IF (NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dba')) 
    BEGIN
        PRINT 'create dba schema';
        EXEC ('CREATE SCHEMA [dba] AUTHORIZATION [dbo]')
    END

IF (NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'base')) 
    BEGIN
        PRINT 'create base schema';
        EXEC ('CREATE SCHEMA [base] AUTHORIZATION [dbo]')
    END

IF (NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'audit')) 
    BEGIN
        PRINT 'create audit schema';
        EXEC ('CREATE SCHEMA [audit] AUTHORIZATION [dbo]')
    END

PRINT '--- creating tables'

IF OBJECT_ID('audit.KVStore','U') IS NULL
    BEGIN
        CREATE TABLE [audit].[KVStore](
	        [KVStoreGID] [uniqueidentifier] NOT NULL,
	        [K] [varchar](100) NOT NULL,
	        [V] [sql_variant] NOT NULL,
	        [CreatedDate] [datetimeoffset](7) NOT NULL CONSTRAINT [df_audit_KVStore_CreatedDate]  DEFAULT (SYSDATETIMEOFFSET()),
            CONSTRAINT [pk_audit_KVStore] PRIMARY KEY CLUSTERED 
            (
	            [KVStoreGID] ASC,
	            [K] ASC
            )
        );
    END
    
-- removed because of new EventSink table
--IF OBJECT_ID('DBA.LogSQLError','U') IS NULL
--    BEGIN
--        PRINT 'creating DBA.LogSQLError table';
--        CREATE TABLE [DBA].[LogSQLError]
--        (
--            [SQLErrorProcedure] [nvarchar] (128) NULL,
--            [SQLErrorLineNumber] [int] NULL,
--            [SQLErrorNumber] [int] NULL,
--            [SQLErrorMessage] [nvarchar] (2048) NULL,
--            [SQLErrorSeverity] [int] NULL,
--            [SQLErrorState] [int] NULL,
--            [SQLErrorProcedureSection] [nvarchar] (128) NULL,
--            [SQLErrorSPID] [int] NULL,
--            [SQLErrorEventType] [nvarchar] (30) NULL,
--            [SQLErrorParameter] [int] NULL,
--            [SQLErrorEventInfo] [nvarchar] (4000) NULL,
--            [SQLErrorExtraInfo] [nvarchar] (4000) NULL,
--            [SQLErrorAnnounce] [int] NULL CONSTRAINT [df_DBA_LogSQLError_SQLErrorAnnounce] DEFAULT ((1)),
--            [CreatedDate] [datetimeoffset] NOT NULL CONSTRAINT [df_DBA_LogSQLError_CreatedDate] DEFAULT (sysdatetimeoffset()),
--            [CreatedBy] [nvarchar] (128) NOT NULL CONSTRAINT [df_DBA_LogSQLError_CreatedBy] DEFAULT (original_login()),
--            [CreatedByMachine] [nvarchar] (128) NULL
--        );

--        CREATE CLUSTERED INDEX [clx_DBA_LogSQLError] ON [DBA].[LogSQLError] ([CreatedDate]);
--        CREATE NONCLUSTERED INDEX [ix_DBA_LogSQLError_SQLErrorProcedure] ON [DBA].[LogSQLError] ([SQLErrorProcedure]);
--        CREATE NONCLUSTERED INDEX [ix_DBA_LogSQLError_CreatedDate] ON [DBA].[LogSQLError] ([CreatedDate]);
--    END

-- removed because of new EventSink table
--IF OBJECT_ID('DBA.LogProcExec','U') IS NULL
--    BEGIN
--        PRINT 'creating DBA.LogProcExec table';
--        CREATE TABLE [DBA].[LogProcExec]
--        (
--            [LogProcExecGID] [bigint] NOT NULL IDENTITY(1, 1) CONSTRAINT [pk_DBA_LogProcExec] PRIMARY KEY NONCLUSTERED,
--            [ProcExecVersion] [uniqueidentifier] NOT NULL CONSTRAINT [df_DBA_LogProcExec_ProcExecVersion] DEFAULT (newid()),
--            [ProcExecStartTime] [datetimeoffset] NOT NULL CONSTRAINT [df_DBA_LogProcExec_ProcExecStartTime] DEFAULT (sysdatetimeoffset()),
--            [ProcExecEndTime] [datetimeoffset] NULL,
--            [DatabaseID] [int] NOT NULL,
--            [ObjectID] [int] NOT NULL,
--            [ProcName] [varchar] (300) NOT NULL,
--            [ProcSection] [varchar] (300) NULL,
--            [ProcText] [nvarchar] (4000) NULL,
--            [RowsAffected] [int] NULL,
--            [ExtraInfo] [nvarchar] (2000) NULL,
--            [CreatedBy] [nvarchar] (128) NOT NULL CONSTRAINT [df_DBA_LogProcExec_CreatedBy] DEFAULT (original_login()),
--            [CreatedByMachine] [nvarchar] (128) NULL CONSTRAINT [df_DBA_LogProcExec_CreatedByMachine] DEFAULT (host_name())
--        );

--        CREATE CLUSTERED INDEX [clx_DBA_LogProcExec] ON [DBA].[LogProcExec] ([ProcExecStartTime]);
--        CREATE NONCLUSTERED INDEX [ix_DBA_LogProcExec_ProcName] ON [DBA].[LogProcExec] ([ProcName], [ProcSection]);

--    END

-- not implemented yet
--IF OBJECT_ID('DBA.TableLoadStatus','U') IS NULL
--    BEGIN
--        PRINT 'creating DBA.TableLoadStatus table';
--        CREATE TABLE DBA.TableLoadStatus
--        (
--            TableLoadStatusGID int NOT NULL IDENTITY(1,1) CONSTRAINT pk_DBA_TableLoadStatus PRIMARY KEY NONCLUSTERED,
--            TableName varchar(300) NOT NULL,
--            LoadTimestamp datetimeoffset NOT NULL CONSTRAINT df_DBA_TableLoadStatus_LoadTimestamp DEFAULT (SYSDATETIMEOFFSET()),
--            ModifiedBy nvarchar(128) NOT NULL CONSTRAINT df_DBA_TableLoadStatus_ModifiedBy DEFAULT (ORIGINAL_LOGIN())
--        );

--        CREATE UNIQUE CLUSTERED INDEX clx_DBA_TableLoadStatus ON DBA.TableLoadStatus (TableName,LoadTimestamp);
--    END

IF OBJECT_ID('base.LookType','U') IS NULL
    BEGIN
        PRINT 'creating base.LookType table';

        CREATE TABLE [base].[LookType]
        (
            [LookTypeGID] [smallint] NOT NULL IDENTITY(1, 1) CONSTRAINT [pk_base_LookType] PRIMARY KEY CLUSTERED,
            [LookTypeValue] [varchar] (500) NOT NULL,
            [LookTypeDescription] [varchar] (500) NOT NULL,
            [LookTypeConstant] [varchar] (100) NOT NULL,
            [LookTypeActive] [bit] NOT NULL CONSTRAINT [df_base_LookType_LookTypeActive] DEFAULT ((1)),
            [Timestamp] [rowversion] NOT NULL,
            [ModifiedBy] [nvarchar] (128) NOT NULL CONSTRAINT [df_base_LookType_ModifiedBy] DEFAULT (original_login())
        );

        CREATE NONCLUSTERED INDEX [ix_base_LookType_LookTypeGID] ON [base].[LookType] ([LookTypeGID]) 
            INCLUDE ([LookTypeActive], [LookTypeConstant], [LookTypeDescription], [LookTypeValue], [Timestamp]);
    END
GO

IF OBJECT_ID('base.Look','U') IS NULL
    BEGIN
        PRINT 'creating base.Look table';

        CREATE TABLE [base].[Look]
        (
            [LookGID] [smallint] NOT NULL IDENTITY(1, 1) CONSTRAINT [pk_base_Look] PRIMARY KEY CLUSTERED,
            [LookTypeFID] [smallint] NOT NULL CONSTRAINT [fk_base_Look_LookTypeFID] FOREIGN KEY REFERENCES [base].[LookType] ([LookTypeGID]),
            [LookValue] [varchar] (1000) NOT NULL,
            [LookDescription] [varchar] (300) NOT NULL,
            [LookConstant] [varchar] (100) NOT NULL CONSTRAINT [uq_base_Look_LookConstant] UNIQUE NONCLUSTERED,
            [LookActive] [bit] NOT NULL CONSTRAINT [df_base_Look_LookActive] DEFAULT ((1)),
            [LookOrder] [smallint] NOT NULL CONSTRAINT [df_base_Look_LookOrder] DEFAULT ((0)),
            [Timestamp] [rowversion] NOT NULL,
            [ModifiedBy] [nvarchar] (50) NOT NULL CONSTRAINT [df_base_Look_ModifiedBy] DEFAULT (original_login())
        );
        CREATE NONCLUSTERED INDEX [ix_base_Look_LookTypeFID] ON [base].[Look] ([LookTypeFID]) INCLUDE ([LookActive], [LookDescription], [LookOrder], [LookValue], [Timestamp]);
        CREATE NONCLUSTERED INDEX [ix_base_Look_LookConstant] ON [base].[Look] ([LookConstant]) INCLUDE ([LookActive], [LookDescription], [LookOrder], [LookValue], [Timestamp]);
    END

IF OBJECT_ID('audit.EventSink','U') IS NULL
    BEGIN
        PRINT 'creating audit.EventSink table';

        CREATE TABLE audit.EventSink
        (
            ID bigint NOT NULL IDENTITY(1,1) CONSTRAINT pk_audit_EventSink PRIMARY KEY CLUSTERED,
            EventMessage xml NOT NULL
        );
        CREATE PRIMARY XML INDEX px_audit_EventSink ON audit.EventSink (EventMessage);
        CREATE XML INDEX sxpy_audit_EventSink ON audit.EventSink(EventMessage) USING XML INDEX px_audit_EventSink FOR PROPERTY;
    END

IF OBJECT_ID('audit.Audit','U') IS NULL
    BEGIN
        PRINT 'creating audit.Audit table';
        
        CREATE TABLE [audit].[Audit]
        (
            [AuditID] [bigint] NOT NULL IDENTITY(1, 1) CONSTRAINT [pk_audit_Audit] PRIMARY KEY CLUSTERED,
            [AuditDateTime] [datetimeoffset] NOT NULL CONSTRAINT [df_audit_AuditDateTime] DEFAULT (SYSDATETIMEOFFSET()),
            [LoginName] [nvarchar] (128) NOT NULL,
            [AppName] [nvarchar] (128) NOT NULL,
            [SchemaName] [nvarchar] (128) NOT NULL,
            [TableName] [nvarchar] (128) NOT NULL,
            [AuditKey] [uniqueidentifier] NOT NULL,
            [AuditType] [char] (1) NOT NULL CONSTRAINT [ck_audit_AuditKey] CHECK (([AuditType]='U' OR [AuditType]='D' OR [AuditType]='I')),
            [ColumnName] [nvarchar] (128) NOT NULL,
            [RecordID] [bigint] NOT NULL,
            [OldValue] [nvarchar] (500) NULL,
            [NewValue] [nvarchar] (500) NULL,
            [OldValueMax] [nvarchar] (max) NULL,
            [NewValueMax] [nvarchar] (max) NULL
        );
    END

IF OBJECT_ID('audit.AuditConfig','U') IS NULL
    BEGIN
        PRINT 'creating audit.AuditConfig table';

        CREATE TABLE [audit].[AuditConfig]
        (
            [AuditConfigID] [int] NOT NULL IDENTITY(1, 1) CONSTRAINT [pk_audit_AuditConfig] PRIMARY KEY CLUSTERED,
            [SchemaName] [sys].[sysname] NOT NULL,
            [TableName] [sys].[sysname] NOT NULL,
            [ColumnName] [sys].[sysname] NOT NULL,
            [EnableAudit] [bit] NOT NULL CONSTRAINT [df_audit_AuditConfig_EnableAudit] DEFAULT ((1)),
            [Timestamp] [timestamp] NOT NULL,
            [CreatedDate] [datetimeoffset] NOT NULL CONSTRAINT [df_audit_AuditConfig_CreatedDate] DEFAULT (sysdatetimeoffset()),
            [CreatedBy] [nvarchar] (120) NOT NULL CONSTRAINT [df_audit_AuditConfig_CreatedBy] DEFAULT (original_login()),
            [UpdatedDate] [datetimeoffset] NOT NULL CONSTRAINT [df_audit_AuditConfig_UpdatedDate] DEFAULT (sysdatetimeoffset()),
            [UpdatedBy] [nvarchar] (120) NOT NULL CONSTRAINT [df_audit_AuditConfig_UpdatedBy] DEFAULT (original_login())
        );

        ALTER TABLE [audit].[AuditConfig] 
            ADD CONSTRAINT [uq_audit_AuditConfig_TableName_ColumnName] UNIQUE NONCLUSTERED  
            (
                [SchemaName], 
                [TableName], 
                [ColumnName]
            );
    END
GO



PRINT '--- creating views'

IF OBJECT_ID('audit.v_AuditKey','V') IS NOT NULL
    BEGIN
        DROP VIEW audit.v_AuditKey;
    END
GO
PRINT 'creating Audit.v_AuditKey view';
GO

CREATE VIEW [audit].[v_AuditKey] 
AS
SELECT NEWID() AS [AuditKey];
GO

IF OBJECT_ID('audit.v_EventSink','V') IS NOT NULL
    BEGIN
        DROP VIEW audit.v_EventSink;
    END
GO
PRINT 'creating audit.v_EventSink view';
GO

CREATE VIEW [audit].[v_EventSink] 
AS
SELECT
    ID,
    EventMessage.value('(/event/evt_type)[1]','varchar(100)') AS EventType,
    EventMessage.value('(/event/evt_status)[1]','varchar(100)') AS EventStatus,
    EventMessage.value('(/event/uid)[1]','uniqueidentifier') AS KeyID,
    EventMessage.value('(/event/bgn_dt)[1]','datetimeoffset') AS BeginDate,
    EventMessage.value('(/event/end_dt)[1]','datetimeoffset') AS EndDate,
    EventMessage.value('(/event/app_nm)[1]','varchar(128)') AS ApplicationName,
    EventMessage.value('(/event/srv_nm)[1]','varchar(128)') AS ServerName,
    EventMessage.value('(/event/db_nm)[1]','varchar(128)') AS DatabaseName,
    EventMessage.value('(/event/sch_nm)[1]','varchar(128)') AS SchemaName,
    EventMessage.value('(/event/obj_nm)[1]','varchar(128)') AS ObjectName,
    EventMessage.value('(/event/sec_nm)[1]','varchar(300)') AS SectionName,
    EventMessage.value('(/event/evt_txt)[1]','varchar(max)') AS EventText,
    EventMessage.value('(/event/evt_info)[1]','varchar(1000)') AS EventInfo,
    EventMessage.value('(/event/rows)[1]','int') AS RowsAffected,
    EventMessage.value('(/event/db_id)[1]','int') AS DatabaseID,
    EventMessage.value('(/event/obj_id)[1]','int') AS ObjectID,
    EventMessage.value('(/event/mach_nm)[1]','varchar(128)') AS MachineName,
    EventMessage.value('(/event/usr_nm)[1]','varchar(128)') AS UserName
FROM audit.EventSink;
GO

IF OBJECT_ID('dbo.v_Look','V') IS NOT NULL
    BEGIN
        DROP VIEW dbo.v_Look;
    END
GO
PRINT 'creating dbo.v_Look view';
GO

/*************************************************************************************************
	<historylog> 
		<log revision="1.0" date="05/01/2010" modifier="David Sumlin">Created</log> 
		<log revision="1.1" date="09/14/2010" modifier="David Sumlin">Changed LookTypeName to LookTypeValue for consistency</log> 
		<log revision="1.2" date="09/14/2010" modifier="David Sumlin">Added WITH (NOLOCK) to tables</log> 
		<log revision="1.3" date="03/07/2011" modifier="David Sumlin">Changed column names to use new naming convention and added updated by fields</log> 
		<log revision="1.4" date="09/13/2013" modifier="David Sumlin">Changed audit fields to only ModifiedBy and ModifiedDate</log> 
        <log revision="1.5" date="08/08/2014" modifier="David Sumlin">Removed audit date fields</log> 
        <log revision="1.6" date="06/12/2015" modifier="David Sumlin">Renamed to remove v_</log> 
        <log revision="1.7" date="06/12/2015" modifier="David Sumlin">Renamed to add v_</log> 
	</historylog>         
	
**************************************************************************************************/
CREATE VIEW [dbo].[v_Look]
WITH SCHEMABINDING
AS
SELECT
	[l].[LookGID],
	[l].[LookValue],
	[l].[LookDescription],
	[l].[LookConstant],
	[l].[LookActive],
	[l].[LookOrder],
	[l].[Timestamp] [LookTimestamp],
	[l].[ModifiedBy] [LookModifiedBy],
	[lt].[LookTypeGID],
	[lt].[LookTypeValue],
	[lt].[LookTypeDescription],
	[lt].[LookTypeConstant],
	[lt].[LookTypeActive],
	[lt].[Timestamp] [LookTypeTimestamp],
	[lt].[ModifiedBy] [LookTypeModifiedBy]
FROM [base].[Look] l WITH (NOLOCK)
	RIGHT OUTER JOIN [base].[LookType] lt WITH (NOLOCK)
		ON [l].[LookTypeFID] = [lt].[LookTypeGID];
GO


IF OBJECT_ID('audit.v_Audit','V') IS NOT NULL
    BEGIN
        DROP VIEW Audit.v_Audit;
    END
GO
PRINT 'creating Audit.v_Audit view'
GO

CREATE VIEW [audit].[v_Audit]
AS
SELECT 	
	AuditID,
	AuditDateTime,
	LoginName,
	AppName,
	SchemaName,
	TableName,
	AuditKey,
	CASE
		WHEN AuditType = 'i' THEN 'INSERT'
		WHEN AuditType = 'u' THEN 'UPDATE'
		ELSE 'DELETE'
	END AS AuditType,
	ColumnName,
	RecordID,
	CASE
		WHEN OldValue IS NULL AND NewValue IS NULL THEN OldValueMax
		ELSE CAST(OldValue AS nvarchar(max))
	END OldValue,
	CASE
		WHEN OldValue IS NULL AND NewValue IS NULL THEN NewValueMax
		ELSE CAST(NewValue AS nvarchar(max))
	END NewValue
FROM audit.Audit;
GO

PRINT '--- creating functions'

IF OBJECT_ID('dbo.f_LookIDByConstant','FN') IS NOT NULL
    BEGIN
        DROP FUNCTION dbo.f_LookIDByConstant;
    END
GO
PRINT 'creating dbo.f_LookIDByConstant function';
GO

/*************************************************************************************************

	<historylog> 
		<log revision="1.0" date="07/21/2010" modifier="David Sumlin">Created</log> 
        <log revision="1.1" date="06/12/2015" modifier="David Sumlin">Changed reference to base schema</log> 
	</historylog>         

**************************************************************************************************/
CREATE FUNCTION [dbo].[f_LookIDByConstant]
(
	@constant varchar(100),
	@active bit = NULL
)
RETURNS smallint
WITH SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN

	DECLARE @id int
	
	SELECT @id = [LookGID] 
	FROM [base].[Look]
	WHERE [LookConstant] = @constant
	AND (@active IS NULL OR [LookActive] = @active)
	
	RETURN @id
	
END;
GO


IF OBJECT_ID('dbo.f_LookIDIsValid','FN') IS NOT NULL
    BEGIN
        DROP FUNCTION dbo.f_LookIDIsValid;
    END
GO
PRINT 'creating dbo.f_LookIDIsValid function';
GO

/*************************************************************************************************
	
	<historylog> 
		<log revision="1.0" date="05/01/2010" modifier="David Sumlin">Created</log> 
		<log revision="1.1" date="07/29/2010" modifier="David Sumlin">Added @allow_null parameter</log> 
		<log revision="1.2" date="09/13/2013" modifier="David Sumlin">Removed view dependency</log> 
        <log revision="1.3" date="06/12/2015" modifier="David Sumlin">Changed reference to base schema</log> 
	</historylog>         
	
**************************************************************************************************/
CREATE FUNCTION [dbo].[f_LookIDIsValid]
(
	@look_type_constant varchar(100),
	@id int,
	@allow_null bit = 1
)
RETURNS bit
WITH SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN
	DECLARE @valid bit = 1

	-- just in case a null is sent in
	SELECT @allow_null = ABS(ISNULL(@allow_null,0))
		
	-- exit if we are violating a null constraint
	SELECT	@valid = CASE WHEN @allow_null = 0 AND @id IS NULL THEN 0 ELSE 1 END

	-- now verify domain validity
	IF @valid = 1 AND @id IS NOT NULL
		SELECT	@valid = SIGN(COUNT(*)) 
		FROM base.Look l
			INNER JOIN base.LookType lt
				ON l.LookTypeFID = lt.LookTypeGID 
		WHERE lt.LookTypeConstant = @look_type_constant
		AND l.LookGID = @id

	RETURN @valid
END;
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
	@deleted_table_name varchar(100)
) 
RETURNS nvarchar(max)
AS
BEGIN
	DECLARE @audit_key nvarchar(100),
			@retval nvarchar(max) = N'',
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

	SELECT	@audit_key = CAST(AuditKey AS nvarchar(100)) FROM [audit].[v_AuditKey]

	IF NOT EXISTS (SELECT 0 FROM [audit].[AuditConfig] WHERE Tablename = @table_name AND EnableAudit = 1)
		RETURN @retval

	SET @retval =	N'
					INSERT INTO [Audit].[Audit] (AppName,AuditKey,SchemaName,TableName,AuditType,LoginName,ColumnName,RecordID,OldValue,NewValue,OldValueMax,NewValueMax) 
					SELECT ''' + APP_NAME() +  N''',''' + @audit_key + N''',''' + @schema_name + N''',''' + @table_name + N''',''' + LOWER(LEFT(@audit_type,1)) + N''', 
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

PRINT '--- creating procedures'
GO

IF OBJECT_ID('audit.s_AddSQLErrorLog','P') IS NOT NULL
    BEGIN
        DROP PROCEDURE audit.s_AddSQLErrorLog;
    END
GO
PRINT 'creating audit.s_AddSQLErrorLog procedure';
GO

/*************************************************************************************************
	<returns> 
			<return value="0" description="Success"/> 
	</returns>
	
	<samples> 
		<sample>
			<description>This procedure logs sql errors from scripts or procedures and puts them into the EventSink
			</description>
			<code>EXEC [audit].[s_AddSQLErrorLog] 'Sample section in code'</code> 
		</sample>
	</samples> 
	
	<historylog> 
		<log revision="1.0" date="05/01/2010" modifier="David Sumlin">Created</log> 
		<log revision="1.1" date="06/05/2010" modifier="David Sumlin">Added @extrainfo parameter</log> 
		<log revision="1.2" date="06/29/2010" modifier="David Sumlin">Added @announce parameter</log> 		
		<log revision="1.3" date="09/03/2010" modifier="David Sumlin">Added WITH EXECUTE AS OWNER.  This allows me to grant EXEC permissions on this proc without the table</log> 
		<log revision="1.4" date="11/30/2011" modifier="David Sumlin">Added @alt variable for flexibility.  Initially created to remove INSERT...EXEC functionality so proc can be used in other INSERT...EXEC scenarios</log> 
		<log revision="1.5" date="11/30/2012" modifier="David Sumlin">Changed to use DBA schema in local database</log> 
        <log revision="1.6" date="06/12/2015" modifier="David Sumlin">Changed to use Audit.EventSink and changed schema to Audit</log> 
        <log revision="1.7" date="06/16/2015" modifier="David Sumlin">Added err_dt to log event</log> 
        <log revision="1.8" date="06/22/2015" modifier="David Sumlin">Added feature info to log event</log> 
	</historylog>         
	
**************************************************************************************************/
CREATE PROCEDURE [audit].[s_AddSQLErrorLog]
(
	@section varchar(128) = NULL,
	@extrainfo nvarchar(4000) = NULL,
	@announce int = 1,
	@alt varchar(100) = NULL
)
WITH EXECUTE AS OWNER
AS
SET NOCOUNT ON
 
	DECLARE @cmd varchar(1000),
            @xml xml,
            @event_info nvarchar(4000),
            @event_type nvarchar(30);
	
	-- use this table to hold the info from DBCC INPUTBUFFER
	DECLARE @err_tbl table 
		(
			[EventType] nvarchar(30) NULL, 
			[Parameters] int NULL, 
			[EventInfo] nvarchar(4000) NULL
		)

	IF @alt = 'NO INSERT EXEC'
		BEGIN
			INSERT INTO @err_tbl (EventInfo) VALUES (@alt)
		END
	ELSE
		BEGIN	
			-- We're calling this to get the code that was originally executing
			SET @cmd = 'DBCC INPUTBUFFER( ' + CAST(@@spid as varchar) + ') WITH NO_INFOMSGS'

			INSERT INTO @err_tbl 
			EXEC(@cmd)
		END

    SELECT 
        @event_info = [EventInfo],
        @event_type = [EventType]
    FROM @err_tbl;

	SET @xml = 
    (
    SELECT
        'error' AS evt_type,
        'alert' AS evt_status,
        SYSUTCDATETIME() AS err_dt,
        COALESCE(@announce,'') AS err_announce,
        'deprecated: Procedure should not be used, use KV framework.' AS feature_info, 
        COALESCE(@@SPID,'')  AS err_spid,
        COALESCE(ERROR_PROCEDURE(),'') AS err_proc_nm,
        COALESCE(ERROR_LINE(),'') AS err_line,
        COALESCE(ERROR_NUMBER(),'') AS err_num,
        COALESCE(ERROR_MESSAGE(),'') AS err_msg,
        COALESCE(ERROR_SEVERITY(),'') AS err_lvl,
        COALESCE(ERROR_STATE(),'') AS err_state,
        COALESCE(@@SERVERNAME,'') AS srv_nm,
        COALESCE(DB_NAME(),'') AS db_nm,
		COALESCE(@section,'') AS sec_nm,
		COALESCE(@event_info,'') AS evt_txt,
		COALESCE(@event_type,'') AS evt_info,
        COALESCE(HOST_NAME(),'') AS mach_nm,
        COALESCE(ORIGINAL_LOGIN(),'') AS usr_nm
        FOR XML RAW ('event'), ELEMENTS
    );

    -- Log it
    INSERT INTO audit.EventSink (EventMessage) VALUES (@xml)

GO

IF OBJECT_ID('audit.s_AddProcExecLog','P') IS NOT NULL
    BEGIN
        DROP PROCEDURE audit.s_AddProcExecLog;
    END
GO
PRINT 'creating audit.s_AddProcExecLog procedure';
GO

/*************************************************************************************************
	<returns> 
			<return value="0" description="Success"/> 
	</returns>

	<samples> 
		<sample>
			<description>
			This would insert stored procedure execution values into the [Audit].[EventSink] table.
			</description>
			<code>EXEC [audit].[s_AddProcExecLog] DB_ID(), @@PROCID, @exec_start, @exec_end, NULL, NULL, NULL, NULL</code> 
		</sample>
	</samples> 

	<historylog> 
		<log revision="1.0" date="05/01/2010" modifier="David Sumlin">Created</log> 
		<log revision="1.1" date="05/26/2010" modifier="David Sumlin">Added @rows parameter to accomodate new columns in Log_ProcExec table</log> 		
		<log revision="1.2" date="05/26/2010" modifier="David Sumlin">Added @section and @version parameters to accomodate new columns in Log_ProcExec table</log> 		
		<log revision="1.3" date="05/26/2010" modifier="David Sumlin">Changed schema to Audit</log> 		
		<log revision="1.4" date="06/01/2010" modifier="David Sumlin">Added ISNULL check for @version variable</log> 				
		<log revision="1.5" date="06/05/2010" modifier="David Sumlin">Added @db_id variable to determine proc name from different databases</log> 				
		<log revision="1.6" date="06/08/2010" modifier="David Sumlin">Added ISNULL check for @object_id, @db_id variables</log> 						
		<log revision="1.7" date="07/29/2010" modifier="David Sumlin">Fixed @db_id variable insertion.  For some reason I was always inserting the id for the DBA database.</log> 								
		<log revision="1.8" date="09/03/2010" modifier="David Sumlin">Added WITH EXECUTE AS OWNER.  This allows me to grant EXEC permissions on this proc without the table</log> 
		<log revision="1.9" date="11/30/2011" modifier="David Sumlin">Added @alt variable for flexibility.  Initially created to remove INSERT...EXEC functionality so proc can be used in other INSERT...EXEC scenarios</log> 
		<log revision="2.0" date="11/30/2012" modifier="David Sumlin">Changed to DBA schema for local database</log>
		<log revision="2.1" date="06/12/2014" modifier="David Sumlin">Changed datetime2 to datetimeoffset</log> 
        <log revision="2.2" date="12/03/2014" modifier="David Sumlin">Added @object_nm for adhoc code that is not in a stored procedure</log> 
        <log revision="2.3" date="12/17/2014" modifier="David Sumlin">Added (7) to datetimeoffset input parameters</log> 
        <log revision="2.4" date="04/06/2015" modifier="David Sumlin">Change from inserting rows into Audit.ProcExecLog into inserting xml into Audit.EventSink.  Also added @app_nm parameter</log>
        <log revision="2.5" date="04/06/2015" modifier="David Sumlin">Removed WITH EXECUTE AS OWNER.  Was incorrect in my previous understanding.  Permission should be a schema level.</log>
        <log revision="2.6" date="06/12/2015" modifier="David Sumlin">Changed to audit schema</log>
        <log revision="2.7" date="06/22/2015" modifier="David Sumlin">Added deprecated feature</log>
	</historylog>         

**************************************************************************************************/
CREATE PROCEDURE [audit].[s_AddProcExecLog]
(
	@db_id int,
	@object_id int,
	@start datetimeoffset(7) = NULL,
	@end datetimeoffset(7) = NULL,
	@extra_info nvarchar(2000) = NULL,
	@rows int = NULL,
	@section varchar(300) = NULL,
	@version uniqueidentifier = NULL,
	@alt varchar(100) = NULL,
    @object_nm nvarchar(128) = NULL,
    @app_nm nvarchar(128) = NULL
)
AS
SET NOCOUNT ON

	DECLARE @cmd varchar(1000),
            @xml xml,
            @event_info nvarchar(4000);

	-- use this table to hold the info from DBCC INPUTBUFFER or anything else
	DECLARE @dbcc_tbl table 
		(
			[EventType] nvarchar(30) NULL, 
			[Parameters] int NULL, 
			[EventInfo] nvarchar(4000) NULL
		)

	IF @alt = 'NO INSERT EXEC'
		BEGIN
			INSERT INTO @dbcc_tbl (EventInfo) VALUES (@alt)
		END
	ELSE
		BEGIN	
			-- We're calling this to get the code that was originally executing
			SET @cmd = 'DBCC INPUTBUFFER( ' + CAST(@@spid as varchar) + ') WITH NO_INFOMSGS'

			INSERT INTO @dbcc_tbl 
			EXEC(@cmd)
		END
		
    SELECT 
        @event_info = [EventInfo] 
    FROM @dbcc_tbl;

	SET @xml = 
    (
    SELECT
        'proc exec' AS evt_type,
        'info' AS evt_status,
        COALESCE(@app_nm,'') AS app_nm,
        COALESCE(@@SERVERNAME,'') AS srv_nm,
        'deprecated: Procedure should not be used, use KV framework.' AS feature_info, 
        COALESCE(DB_NAME(@db_id),'') AS db_nm,
        COALESCE(OBJECT_SCHEMA_NAME(@object_id, @db_id),'') AS sch_nm,
		@start AS bgn_dt,
		@end AS end_dt,
		COALESCE(@db_id,0) AS [db_id],
		COALESCE(@version,NEWID()) AS [uid],
		COALESCE(@object_id,0) AS obj_id,
		COALESCE(OBJECT_NAME(@object_id, @db_id),COALESCE(@object_nm,'unknown')) AS obj_nm,
		COALESCE(@section,'') AS sec_nm,
		COALESCE(@event_info,'') AS evt_txt,
		COALESCE(@extra_info,'') AS evt_info,
		COALESCE(@rows,'') AS [rows],
        COALESCE(HOST_NAME(),'') AS mach_nm,
        COALESCE(ORIGINAL_LOGIN(),'') AS usr_nm
        FOR XML RAW ('event'), ELEMENTS
    );

    -- Log it
    INSERT INTO audit.EventSink (EventMessage) VALUES (@xml)

GO

IF OBJECT_ID('dba.s_DropObject','P') IS NOT NULL
    BEGIN
        DROP PROCEDURE dba.s_DropObject;
    END
GO
PRINT 'creating dba.s_DropObject procedure';
GO

/*************************************************************************************************

	<returns> 
			<return value="0" description="Success"/> 
	</returns>

	<samples> 
		<sample>
			<description>Drop a table named Table1</description>
			<code>EXEC [DBA].[s_DropObject] 'Table1'</code> 
		</sample>
		<sample>
			<description>Drop a temp table named #t</description>
			<code>EXEC [DBA].[s_DropObject] '#t','TEMP TABLE', 'dbo'</code> 
		</sample>
		<sample>
			<description>Drop a view named v_MyView in a schema named Reporting</description>
			<code>EXEC [DBA].[s_DropObject] 'v_MyView','VIEW', ,'Reporting'</code> 
		</sample>
		<sample>
			<description>Drop a stored procedure named s_MyProc without specifying the schema</description>
			<code>EXEC [DBA].[s_DropObject] 's_MyProc','PROCEDURE'</code> 
		</sample>
		<sample>
			<description>Drop a user defined function named f_MyFunction</description>
			<code>EXEC [DBA].[s_DropObject] 'f_MyFunction','FUNCTION'</code> 
		</sample>
		<sample>
			<description>Drop an index named ix_Index1 and Table1</description>
			<code>EXEC [DBA].[s_DropObject] 'ix_Index1','INDEX', 'dbo', 'database', 'Table1'</code> 
		</sample>
		<sample>
			<description>Drop a table named Table1 in a different database</description>
			<code>EXEC [DBA].[s_DropObject] 'Table1','TABLE', 'dbo', 'OtherDatabase', NULL</code> 
		</sample>
		<sample>
			<description>Drop a primary key on a table</description>
			<code>EXEC [DBA].[s_DropObject] 'PK_Table','CONSTRAINT', 'dbo', 'Database', 'Table', NULL</code> 
		</sample>

	</samples> 

	<historylog> 
		<log revision="1.0" date="06/18/2010" modifier="David Sumlin">Created</log> 
		<log revision="1.1" date="06/24/2010" modifier="David Sumlin">Corrected DROP VIEW section</log> 		
		<log revision="1.2" date="06/24/2010" modifier="David Sumlin">Corrected DROP PROCEDURE section</log> 				
		<log revision="1.3" date="06/29/2010" modifier="David Sumlin">Corrected DROP TRIGGER section</log>
		<log revision="1.4" date="07/01/2010" modifier="David Sumlin">Changed s_AddSQLErrorLog call to use named parameters</log>		
		<log revision="1.5" date="07/06/2010" modifier="David Sumlin">Added @debug parameter</log>
		<log revision="1.6" date="07/06/2010" modifier="David Sumlin">Forced declaraction of @db_name unless TEMP TABLE</log>
		<log revision="1.7" date="07/13/2010" modifier="David Sumlin">Corrected DROP FUNCTION section</log>
		<log revision="1.8" date="07/21/2010" modifier="David Sumlin">Expanded BEGIN TRY section and added ISNULL function to @params call</log>
		<log revision="1.9" date="09/27/2010" modifier="David Sumlin">Corrected DROP LOGIN functionality to allow NULL @db_name parameter</log>
		<log revision="2.0" date="10/04/2010" modifier="David Sumlin">Corrected DROP INDEX functionality to remove square brackets in EXISTS search</log>
		<log revision="2.1" date="10/04/2010" modifier="David Sumlin">Added ability to DROP SQL Agent Job</log>
		<log revision="2.2" date="03/02/2011" modifier="David Sumlin">Changed SET settings</log>
		<log revision="2.3" date="03/08/2011" modifier="David Sumlin">Added DROP CONSTRAINT section</log>
		<log revision="2.4" date="06/09/2011" modifier="David Sumlin">Fixed DROP CONSTRAINT section.  It wasnt looking for constraint name in check. Also added logging.</log>
		<log revision="2.5" date="06/20/2011" modifier="David Sumlin">Fixed DROP CONSTRAINT section.  It was looking for constraint name with square brackets.</log>
		<log revision="2.6" date="05/01/2012" modifier="David Sumlin">Fixed DROP INDEX section to handle duplicate index names</log>
		<log revision="2.7" date="08/14/2012" modifier="David Sumlin">Added @log_id parameter for logging purposes</log>
		<log revision="2.8" date="12/11/2012" modifier="David Sumlin">Fixed DROP TRIGGER section</log>
        <log revision="2.9" date="10/25/2014" modifier="David Sumlin">Removed custom error code and just put in text message</log>
        <log revision="3.0" date="04/06/2015" modifier="David Sumlin">Changed to use datetimeoffset for logging date/times, and added @app_nm parameter</log>
	</historylog>         

**************************************************************************************************/
CREATE PROCEDURE [dba].[s_DropObject]
(
	@object_name sysname,
	@object_type sysname = 'TABLE',
	@schema_name sysname = 'dbo',
	@db_name sysname = NULL,
	@qualifier_name sysname = NULL,
	@debug bit = 0,
	@log_id uniqueidentifier = NULL,
    @app_nm varchar(128) = NULL
)
AS
SET NOCOUNT ON
SET XACT_ABORT ON

	-- Auditing variables
	DECLARE @err_sec [varchar](128) = '',
			@exec_start datetimeoffset(7) = SYSDATETIMEOFFSET(),
			@exec_end datetimeoffset(7) = NULL,
			@params nvarchar(2000) = NULL,
			@rows int = 0,
			@db_id int = DB_ID()

	-- local variables
	DECLARE @sql nvarchar(4000) = '',
			@full_object_name nvarchar(1000),
			@schema_object_name nvarchar(1000),
			@schema_qualifier_name nvarchar(1000)

	SELECT @params = N'@object_name = ''' + ISNULL(@object_name,N'NULL') + ''' , ' + 
					N'@object_type = ''' + ISNULL(@object_type,N'NULL') + ''' , ' + 
					N'@schema_name = ''' + ISNULL(@schema_name,N'NULL') + ''' , ' +
					N'@db_name = ''' + ISNULL(@db_name,N'NULL') + ''' , ' +
					N'@qualifier_name = ''' + ISNULL(@qualifier_name,N'NULL') + ''' , ' +
					N'@debug = ' + ISNULL(CAST(@debug AS nvarchar(4)),N'NULL')

	BEGIN TRY

		SET @err_sec = 'Validate parameters'			

		-- Make sure that @debug is set
		IF @debug IS NULL
			SET @debug = 0
			
		-- Raise an error if @object_name is null or blank
		IF @object_name IS NULL OR @object_name = ''
			RAISERROR('@object_name parameter must be supplied',15,1)

		-- If object_type is NULL default it to TABLE
		IF @object_type IS NULL OR @object_type = ''
			SET @object_type = 'TABLE'
		
		-- If the @db_name is NULL, assume it is tempdb, otherwise raise an error
		IF (@db_name IS NULL OR @db_name = '') AND @object_type <> 'LOGIN'
			BEGIN
				IF @object_type = 'TEMP TABLE'
					SELECT @db_name = 'tempdb'
				ELSE
					RAISERROR('@db_name parameter must be supplied',15,1)
			END

		-- If the @schema is NULL, assume it is dbo
		IF @schema_name IS NULL OR @schema_name = ''
			SELECT @schema_name = 'dbo'

		-- If the @object_type is INDEX or CONSTRAINT, verify @qualifier_name is not null
		IF (@object_type = 'INDEX' OR @object_type = 'CONSTRAINT') AND @qualifier_name IS NULL
			RAISERROR('@qualifier_name parameter must be supplied',15,1)
			
		-- Create a full object name for easier code readability 
		SET @full_object_name = '[' + @db_name + '].[' + @schema_name + '].[' + @object_name + ']'
		
		-- Create a schema and object name for those commands where we cant specify database
		SET @schema_object_name = '[' + @schema_name + '].[' + @object_name + ']'

		-- Create a schema and qualifier name for those commands where needed
		SET @schema_qualifier_name = '[' + @schema_name + '].[' + @qualifier_name + ']'

		SET @err_sec = 'drop ' + @object_type

		-- TABLE
		IF @object_type = 'TABLE' OR @object_type = 'TEMP TABLE'
			BEGIN
				SET @err_sec = 'DROP TABLE'			
				
				SELECT @sql = N'IF OBJECT_ID(''' + @full_object_name + ''', ''U'') IS NOT NULL '
				SELECT @sql = @sql + N'DROP TABLE ' + @full_object_name
			END

		-- TABLE
		IF @object_type = 'TEMP TABLE'
			BEGIN
				SET @err_sec = 'DROP TEMP TABLE'			
				
				SELECT @sql = N'IF OBJECT_ID(''' + @full_object_name + ''', ''U'') IS NOT NULL '
				SELECT @sql = @sql + N'BEGIN USE tempdb DROP TABLE [' + @object_name + '] END'
			END

		-- VIEW
		IF @object_type = 'VIEW'
			BEGIN
				SET @err_sec = 'DROP VIEW'
							
				SELECT @sql = N'IF OBJECT_ID(''' + @full_object_name + ''', ''V'') IS NOT NULL '
				SELECT @sql = @sql + N'BEGIN USE ' + @db_name + ' DROP VIEW ' + @schema_object_name + ' END'
			END

		-- Stored Procedure (allow a little flexibility)
	    IF @object_type = 'PROC' OR @object_type = 'PROCEDURE' OR @object_type = 'STORED PROC' OR @object_type = 'STORED PROCEDURE'
			BEGIN
				SET @err_sec = 'DROP PROCEDURE'
				
				SELECT @sql = N'IF OBJECT_ID(''' + @full_object_name + ''', ''P'') IS NOT NULL '
				SELECT @sql = @sql + N'BEGIN USE ' + @db_name + ' DROP PROCEDURE ' + @schema_object_name + ' END'
			END
		
		
		-- User Defined Function
		IF @object_type = 'FUNCTION'
			BEGIN
				SET @err_sec = 'DROP FUNCTION'
							
				SELECT @sql = N'IF OBJECT_ID(''' + @full_object_name + ''', ''FN'') IS NOT NULL '
				SELECT @sql = @sql + N'OR OBJECT_ID(''' + @full_object_name + ''', ''IF'') IS NOT NULL '
				SELECT @sql = @sql + N'OR OBJECT_ID(''' + @full_object_name + ''', ''TF'') IS NOT NULL '				
				SELECT @sql = @sql + N'BEGIN USE ' + @db_name + ' DROP FUNCTION ' + @schema_object_name + ' END'
			END
			
		-- Trigger
		IF @object_type = 'TRIGGER'
			BEGIN
				SET @err_sec = 'DROP TRIGGER'
							
				SELECT @sql = N'IF EXISTS(SELECT [name] FROM [' + @db_name + '].sys.triggers where [name] = ''' + @object_name + ''') '
				SELECT @sql = @sql + N'BEGIN USE ' + @db_name + ' DROP TRIGGER ' + @schema_object_name + ' END'
			END
		
		-- Index
		IF @object_type = 'INDEX'
			BEGIN
				SET @err_sec = 'DROP INDEX'
							
				SELECT @sql = N'IF EXISTS(SELECT i.[name] FROM [' + @db_name + '].sys.indexes i INNER JOIN [' + @db_name + '].sys.objects o ON i.object_id = o.object_id WHERE o.[name] = ''' + @qualifier_name + ''' AND  i.[name] = ''' + @object_name + ''') '
				SELECT @sql = @sql + N'DROP INDEX ' + @object_name + ' ON [' + @db_name + '].[' + @schema_name + '].[' + @qualifier_name + '] '
			END

		-- Constraint
		IF @object_type = 'CONSTRAINT'
			BEGIN
				SET @err_sec = 'DROP CONSTRAINT'
							
				SELECT @sql = N'IF EXISTS(SELECT name FROM [' + @db_name + '].sys.objects WHERE [name] = ''' + @object_name + ''' AND parent_object_id = (OBJECT_ID(''' + @db_name + '.' + @schema_qualifier_name + ''')) AND type_desc IN (''UNIQUE_CONSTRAINT'',''PRIMARY_KEY_CONSTRAINT'',''FOREIGN_KEY_CONSTRAINT'',''CHECK_CONSTRAINT'',''DEFAULT_CONSTRAINT'')) '
				SELECT @sql = @sql + N'BEGIN USE ' + @db_name + ' ALTER TABLE ' + @schema_qualifier_name + ' DROP CONSTRAINT ' + @object_name + ' END '
			END
		
		-- Schema
		IF @object_type = 'SCHEMA'		
			BEGIN
				SET @err_sec = 'DROP SCHEMA'
							
				SELECT @sql = N'IF EXISTS(SELECT [name] FROM [' + @db_name + '].sys.schemas WHERE [name] = ''[' + @object_name + ']'') '
				SELECT @sql = @sql + N'DROP SCHEMA [' + @object_name + ']'
			END

		-- User
		IF @object_type = 'USER'		
			BEGIN
				SET @err_sec = 'DROP USER'
							
				SELECT @sql = N'IF EXISTS(SELECT [name] FROM [' + @db_name + '].sys.database_principals WHERE [type] IN (''U'',''S'',''G'',''C'',''K'') AND [name] = ''' + @object_name + ''' AND (CAST(CASE WHEN principal_id < 5 OR principal_id = 16382 OR principal_id = 16383 THEN 1 ELSE 0 END AS bit) = 0)) '
				SELECT @sql = @sql + N'BEGIN USE ' + @db_name + ' DROP USER [' + @object_name + '] END'
			END
		
		-- Role
		IF @object_type = 'ROLE'		
			BEGIN
				SET @err_sec = 'DROP ROLE'
							
				-- Just to control things a little tighter, we're not going to drop a role if it still has members attached to it
				-- Put in error handling here
				
				SELECT @sql = N'IF EXISTS(SELECT [name] FROM [' + @db_name + '] sys.database_principals WHERE [type] IN (''A'',''R'') AND [name] = ''' + @object_name + ''' AND is_fixed_role = 0 AND owning_principal_id <> 1) '
				SELECT @sql = @sql + N'DROP ROLE [' + @object_name + ']'
			END

		-- Login
		IF @object_type = 'LOGIN'		
			BEGIN
				SET @err_sec = 'DROP LOGIN'
							
				SELECT @sql = N'IF EXISTS(SELECT name FROM master.sys.server_principals WHERE name = ''' + @object_name + ''') '
				SELECT @sql = @sql + N'DROP LOGIN ' + @object_name + ''
			END

		-- Job
		IF @object_type = 'JOB'		
			BEGIN
				SET @err_sec = 'DROP JOB'
					
				SELECT @sql = N'IF EXISTS(SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N''' + @object_name + ''') '
				SELECT @sql = @sql + N'EXEC msdb.dbo.sp_deletejob @job_name = '''+ @object_name + ''', @delete_unused_schedule = 1 '
			END
		
		-- If we have a sql statement, let's execute it		
		IF @sql <> '' AND @err_sec <> ''
			BEGIN
				IF @debug = 1
					PRINT @sql
				ELSE
					EXEC sp_executesql @sql
			END
		ELSE
			BEGIN
				-- We'll assume they sent in a wrong @object_type
				RAISERROR(50013,15,1, '@object_type')
			END
		
		-- Audit action
		SET @exec_end = SYSDATETIMEOFFSET();
		EXEC [audit].[s_AddProcExecLog] @db_id = @db_id, @object_id = @@PROCID, @start = @exec_start, @end = @exec_end, @extra_info = @params, @rows = @rows, @section = @err_sec, @version = @log_id, @app_nm = @app_nm;

		RETURN (0)

	END TRY
	BEGIN CATCH

		-- Declare local variables so we can return them to the caller			
		DECLARE @err_msg varchar(1000),
				@err_severity int
		
		SELECT	@err_msg = ERROR_MESSAGE(),
				@err_severity = ERROR_SEVERITY()

		-- This will forcibly rollback a transaction that is marked as uncommitable
		IF (XACT_STATE()) = -1 AND @@TRANCOUNT > 0
			ROLLBACK TRANSACTION

		-- Log the error
		EXEC [audit].[s_AddSQLErrorLog] @section = @err_sec, @extrainfo = @params, @announce = 1

		-- Return error message to calling code via @@ERROR and error number via return code
		RAISERROR (@err_msg, @err_severity, 1)
		RETURN(ERROR_NUMBER())

	END CATCH
GO

IF OBJECT_ID('dbo.s_LookTypeUpsert','P') IS NOT NULL
    BEGIN
        DROP PROCEDURE dbo.s_LookTypeUpsert;
    END
GO
PRINT 'creating dbo.s_LookTypeUpsert procedure';
GO

/*************************************************************************************************
	
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
		<log revision="1.0" date="12/31/2011" modifier="David Sumlin">Created</log> 
		<log revision="1.1" date="09/14/2013" modifier="David Sumlin">Changed audit columns to ModifiedBy and ModifiedDate</log> 
        <log revision="1.2" date="06/12/2015" modifier="David Sumlin">Removed EXECUTE AS OWNER and changed to reference base schema objects</log> 
	</historylog>         

**************************************************************************************************/
CREATE PROCEDURE [dbo].[s_LookTypeUpsert]
(
	@id smallint = NULL,
	@value varchar(1000) = NULL,
	@description varchar(500) = NULL,
	@constant varchar(100) = NULL,
	@active bit = NULL,
	@timestamp binary(8) = NULL,
	@return_id smallint = NULL OUT
)
AS
SET NOCOUNT ON
SET XACT_ABORT ON

	BEGIN TRY
	
	-- Validate calling parameters here
	IF @id IS NULL 
		-- insert
		BEGIN
			-- no Look value
			IF @value IS NULL
				RAISERROR(N'LookTypeValue must not be NULL',15,1)

			IF @description IS NULL
				RAISERROR(N'LookTypeDescription must not be NULL',15,1)

			IF @constant IS NULL
				RAISERROR(N'LookTypeConstant must not be NULL',15,1)

			-- check to for duplicate value
			IF EXISTS(SELECT [LookTypeValue] FROM [base].[LookType] WITH (NOLOCK) WHERE [LookTypeValue] = @value)
				RAISERROR(N'LookTypeValue must be unique within table',15,1)
			
			-- check for duplicate constants
			IF EXISTS(SELECT [LookTypeConstant] FROM [base].[LookType] WITH (NOLOCK) WHERE [LookTypeConstant] = @constant)
				RAISERROR(N'LookTypeConstant must be unique within table',15,1)
				
		END
	ELSE
	-- updated
		BEGIN
			-- no Look value
			IF @value IS NULL AND @description IS NULL AND @constant IS NULL AND @active IS NULL
				RAISERROR(N'at least one field needs to have a value supplied',15,1)

			-- make sure that we are not going to update a value to be a duplicate value
			IF @value IS NOT NULL
				BEGIN
					IF EXISTS(SELECT [LookTypeValue] FROM [base].[LookType] WITH (NOLOCK) WHERE [LookTypeValue] = @value AND [LookTypeGID] <> @id)
						RAISERROR(N'LookTypeValue must be unique within table',15,1)
				END

			-- make sure that it is a valid id
			IF NOT EXISTS(SELECT [LookTypeGID] FROM [base].[LookType] WITH (NOLOCK) WHERE [LookTypeGID] = @id)
				RAISERROR(N'id does not exist',15,1)
				
			-- make sure that we are not going to update a constant to be a duplicate value
			IF @constant IS NOT NULL
				BEGIN
					IF EXISTS(SELECT [LookTypeConstant] FROM [base].[LookType] WITH (NOLOCK) WHERE [LookTypeConstant] = @constant AND [LookTypeGID] <> @id)
						RAISERROR(N'LookTypeConstant must be unique within table',15,1)
				END

		END
	
		-- insert or update
		
		IF @id IS NULL 
			-- insert
			BEGIN
				INSERT INTO [base].[LookType] 
				(
					[LookTypeValue],
					[LookTypeDescription],
					[LookTypeConstant],
					[LookTypeActive]
				)
				VALUES 
				(
					@value, 
					@description, 
					UPPER(@constant), 
					COALESCE(@active,1)
				)

				SELECT @return_id = SCOPE_IDENTITY()

			END
		ELSE
			-- update
			BEGIN
			
				UPDATE [base].[LookType]
				SET [LookTypeValue] = COALESCE(@value,[LookTypeValue]),
					[LookTypeDescription] = COALESCE(@description,[LookTypeDescription]),
					[LookTypeConstant] = COALESCE(UPPER(@constant),[LookTypeConstant]),
					[LookTypeActive] = COALESCE(@active,[LookTypeActive],1),
					[ModifiedBy] = ORIGINAL_LOGIN()
				WHERE [LookTypeGID] = @id
				AND [Timestamp] = COALESCE(@timestamp,[Timestamp])

				-- if @timestamp supplied, then we need to validate that the row hasnt changed since first retrieved				
				IF @@ROWCOUNT = 0 
					BEGIN
						IF @timestamp IS NOT NULL
							RAISERROR(N'row not updated. row has been updated since data retrieved. retrieve data and retry.',15,1)
						ELSE
							RAISERROR(N'row not updated. reason unknown',15,1)
					END

				-- on success we will just return the same id					
				SELECT @return_id = @id
			
			END

		RETURN 0
				
	END TRY
	BEGIN CATCH

		-- Declare local variables so we can return them to the caller			
		DECLARE @err_msg varchar(1000),
				@err_severity int
			
		SELECT	@err_msg = ERROR_MESSAGE(),
				@err_severity = ERROR_SEVERITY()

		-- This will forcibly rollback a transaction that is marked as uncommitable
		IF (XACT_STATE()) = -1 AND @@TRANCOUNT > 0
			ROLLBACK TRANSACTION

		-- Return error message to calling code via @@ERROR and error number via return code
		RAISERROR (@err_msg, @err_severity, 1)
		RETURN(ERROR_NUMBER())

	END CATCH
GO

IF OBJECT_ID('dbo.s_LookUpsert','P') IS NOT NULL
    BEGIN
        DROP PROCEDURE dbo.s_LookUpsert;
    END
GO
PRINT 'creating dbo.s_LookUpsert procedure';
GO

/*************************************************************************************************
	
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
		<log revision="1.0" date="00/00/2010" modifier="David Sumlin">Created</log> 
		<log revision="1.1" date="03/18/2013" modifier="David Sumlin">Added @ev parameter to allow for Entity Value (Name Value pairs) inserts into the Look table.  These have to be explicitly allowed since this is a architecturally different usage for Look</log> 
		<log revision="1.2" date="09/14/2013" modifier="David Sumlin">Changed audit columns to ModifiedBy and ModifiedDate</log> 
        <log revision="1.3" date="06/12/2015" modifier="David Sumlin">Removed EXECUTE AS OWNER and changed to reference base schema objects</log> 
	</historylog>         

**************************************************************************************************/
CREATE PROCEDURE [dbo].[s_LookUpsert]
(
	@look_id int = NULL,
	@look_type_id smallint = NULL,
	@look_type_constant varchar(100) = NULL,
	@value varchar(1000) = NULL,
	@description varchar(500) = NULL,
	@constant varchar(100) = NULL,
	@order smallint = NULL,
	@active bit = NULL,
	@timestamp binary(8) = NULL,
	@ev bit = 0,
	@return_id int = NULL OUT
)
AS
SET NOCOUNT ON
SET XACT_ABORT ON

	BEGIN TRY
	
	-- Validate calling parameters here
	IF @look_id IS NULL 
		-- insert
		BEGIN
			-- no look type id
			IF @look_type_id IS NULL AND @look_type_constant IS NULL
				RAISERROR(N'@look_type_id or @look_type_constant must not be NULL',15,1)

			-- no look value
			IF @value IS NULL
				RAISERROR(N'@look_value must not be NULL',15,1)

			-- no description
			IF @description IS NULL
				RAISERROR(N'@look_description must not be NULL',15,1)

			-- no constant
			IF @constant IS NULL
				RAISERROR(N'@look_constant must not be NULL',15,1)

			-- @ev has to be 0 or 1
			IF @ev IS NULL
				RAISERROR(N'@ev must not be NULL',15,1)

			-- check for valid look_type_id
			IF @look_type_id IS NOT NULL
				BEGIN
					IF NOT EXISTS(SELECT [LookTypeGID] FROM [base].[LookType] WITH (NOLOCK) WHERE [LookTypeGID] = @look_type_id)
						RAISERROR(N'@look_type_id is not a valid id',15,1)
				END
				
			-- check for valid look_type_constant
			IF @look_type_id IS NULL AND @look_type_constant IS NOT NULL
				BEGIN
					SELECT @look_type_id = [LookTypeGID] FROM [base].[LookType] WITH (NOLOCK) WHERE [LookTypeConstant] = @look_type_constant
					
					IF @look_type_id IS NULL
						RAISERROR(N'@look_type_constant is not a valid constant',15,1)
				END
				
			-- check for duplicate value with same look_type_id
			IF EXISTS(SELECT [LookValue] FROM [base].[Look] WITH (NOLOCK) WHERE [LookValue] = @value AND [LookTypeFID] = @look_type_id AND @ev = 0)
				RAISERROR(N'LookValue must be unique within same look_type_id',15,1)
			
			-- check for duplicate constant
			IF EXISTS(SELECT [LookConstant] FROM [base].[Look] WITH (NOLOCK) WHERE [LookConstant] = @constant)
				RAISERROR(N'LookConstant must be unique within table',15,1)
				
		END
	ELSE
	-- updated
		BEGIN
			-- no look value
			IF @look_type_constant IS NULL AND @look_type_id IS NULL AND @value IS NULL AND @description IS NULL AND @constant IS NULL AND @active IS NULL
				RAISERROR(N'at least one field needs to have a value supplied',15,1)

			-- get the look_type_id for validation
			IF @look_type_id IS NULL
				SELECT @look_type_id = [LookTypeFID] FROM [base].[Look] WITH (NOLOCK) WHERE [LookGID] = @look_id
			ELSE
				BEGIN
					-- check for valid look_type_id
					IF NOT EXISTS(SELECT [LookTypeGID] FROM [base].[LookType] WITH (NOLOCK) WHERE [LookTypeGID] = @look_type_id)
						RAISERROR(N'@look_type_id is not a valid id',15,1)
				END

			-- make sure that we are not going to update a value to be a duplicate value
			IF @value IS NOT NULL
				BEGIN
					IF EXISTS(SELECT [LookValue] FROM [base].[Look] WITH (NOLOCK) WHERE [LookValue] = @value AND [LookTypeFID] = @look_type_id AND [LookGID] <> @look_id AND @ev = 0)
						RAISERROR(N'@look_value must be unique within same look_type_id',15,1)
				END

			-- make sure that we are not going to update a constant to be a duplicate value
			IF @constant IS NOT NULL
				BEGIN
					IF EXISTS(SELECT [LookConstant] FROM [base].[Look] WITH (NOLOCK) WHERE [LookConstant] = @constant AND [LookGID] <> @look_id)
						RAISERROR(N'@look_constant must be unique within table',15,1)
				END

		END
	
		-- insert or update
		IF @look_id IS NULL 
			-- insert
			BEGIN
				INSERT INTO [base].[Look] 
				(
					[LookTypeFID],
					[LookValue],
					[LookDescription],
					[LookConstant],
					[LookActive],
					[LookOrder]
				)
				VALUES 
				(
					@look_type_id,
					@value, 
					@description, 
					UPPER(@constant), 
					COALESCE(@active,1),
					COALESCE(@order,0)
				)

				SELECT @return_id = SCOPE_IDENTITY()

			END
		ELSE
			-- update
			BEGIN
			
				UPDATE [base].[Look]
				SET [LookTypeFID] = COALESCE(@look_type_id,[LookTypeFID]),
					[LookValue] = COALESCE(@value,[LookValue]),
					[LookDescription] = COALESCE(@description,[LookDescription]),
					[LookConstant] = COALESCE(UPPER(@constant),[LookConstant]),
					[LookActive] = COALESCE(@active,[LookActive]),
					[LookOrder] = COALESCE(@order,[LookOrder]),
					[ModifiedBy] = ORIGINAL_LOGIN()
				WHERE [LookGID] = @look_id
				AND [Timestamp] = COALESCE(@timestamp,[Timestamp])

				-- if @timestamp supplied, then we need to validate that the row hasnt changed since first retrieved				
				IF @@ROWCOUNT = 0 
					BEGIN
						IF @timestamp IS NOT NULL
							RAISERROR(N'row not updated. row has been updated since data retrieved. retrieve data and retry.',15,1)
						ELSE
							RAISERROR(N'row not updated. reason unknown',15,1)
					END

				-- on success we will just return the same id					
				SELECT @return_id = @look_id
			
			END

		RETURN 0
				
	END TRY
	BEGIN CATCH

		-- Declare local variables so we can return them to the caller			
		DECLARE @err_msg varchar(1000),
				@err_severity int
			
		SELECT	@err_msg = ERROR_MESSAGE(),
				@err_severity = ERROR_SEVERITY()

		-- This will forcibly rollback a transaction that is marked as uncommitable
		IF (XACT_STATE()) = -1 AND @@TRANCOUNT > 0
			ROLLBACK TRANSACTION

		-- Return error message to calling code via @@ERROR and error number via return code
		RAISERROR (@err_msg, @err_severity, 1)
		RETURN(ERROR_NUMBER())

	END CATCH
GO


IF OBJECT_ID('audit.s_PopulateAuditConfig','P') IS NOT NULL
    BEGIN
        DROP PROCEDURE audit.s_PopulateAuditConfig;
    END
GO
PRINT 'creating audit.s_PopulateAuditConfig procedure';
GO

CREATE procedure [audit].[s_PopulateAuditConfig]
(
	@apply_to_schema sysname = NULL,
	@apply_to_table sysname = NULL,
	@repopulate bit = 0
)
AS
SET NOCOUNT ON

IF @repopulate  = 1 
	DELETE 
	FROM [audit].[AuditConfig]
	WHERE (@apply_to_schema IS NULL OR SchemaName = @apply_to_schema)
	AND (@apply_to_table IS NULL OR TableName = @apply_to_table)


INSERT  INTO [audit].[AuditConfig]
(
	SchemaName,
	TableName,
	ColumnName
)
SELECT
	s.[name],
    t.[name],
    c.[name]
FROM sys.tables t
	INNER JOIN sys.columns c
		ON t.object_id = c.object_id
	INNER JOIN sys.schemas s
		ON t.schema_id = s.SCHEMA_ID
	INNER JOIN	(
				SELECT 
					TABLE_SCHEMA,
					TABLE_NAME
				FROM INFORMATION_SCHEMA.COLUMNS
				WHERE COLUMNPROPERTY(OBJECT_ID('[' + TABLE_SCHEMA + '].[' + TABLE_NAME + ']'),COLUMN_NAME,'IsIdentity') = 1
				) i
		ON t.name = i.TABLE_NAME
		AND s.name = i.TABLE_SCHEMA
WHERE (@apply_to_schema IS NULL OR s.name = @apply_to_schema)
AND (@apply_to_table IS NULL OR t.name = @apply_to_table)
AND	c.name NOT IN ('ID','LU','FU','LastUpdate','FirstUpdate','LastUpdateDate','FirstUpdateDate','CreateDate','CreatedDate','CreateBy','CreatedBy','ModifiedBy','ModifiedDate','Timestamp','Rowversion')
AND t.name NOT IN ('ELMAH_Error','sysdiagrams')
AND COLUMNPROPERTY(OBJECT_ID('[' + s.name + '].[' + t.name + ']'),c.name,'IsIdentity') = 0 -- don't include identity values
AND NOT EXISTS	(SELECT 0 FROM [audit].[AuditConfig] ac WHERE ac.Tablename = t.[name] AND ac.ColumnName = c.[name] AND ac.SchemaName = s.[name])
AND c.user_type_id NOT IN (128,129,130,241) -- don't include hierarchy, geography, geometry, xml
AND EXISTS(	SELECT 0 FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMNPROPERTY(OBJECT_ID('[' + TABLE_SCHEMA + '].[' + TABLE_NAME + ']'),COLUMN_NAME,'IsIdentity') = 1 AND t.name = TABLE_NAME AND s.name = TABLE_SCHEMA); -- only tables with IDENTITY
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
			SET @sql = @sql + N'	DECLARE @sql nvarchar(max), @action nvarchar(10) = ''insert''; ' + @lf + @lf
			SET @sql = @sql + @lf
			SET @sql = @sql + N'	IF EXISTS(SELECT * FROM deleted) ' + @lf
			SET @sql = @sql + N'		BEGIN ' + @lf
			SET @sql = @sql + N'			SET @action = CASE WHEN EXISTS(SELECT * FROM inserted) THEN N''update'' ELSE N''delete'' END ' + @lf
			SET @sql = @sql + N'		END ' + @lf + @lf
			SET @sql = @sql + @lf
			SET @sql = @sql + N'	SELECT @sql = [Audit].[f_GetAuditSQL](''' + @schema_name + N''',''' + @table_name + N''','''' + @action + '''',''#tmp' + @table_name + N'_Inserted'',''#tmp' + @table_name + N'_Deleted''); ' + @lf + @lf
			SET @sql = @sql + @lf
			SET @sql = @sql + N'	IF ISNULL(@sql,'''') <> '''' EXEC sp_executesql @sql; ' + @lf + @lf
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


/*************************************************************************************************
	<scope>Utility</scope>

	<historylog> 
		<log revision="1.0" date="05/01/2010" modifier="David Sumlin">Created</log> 
		<log revision="1.1" date="06/06/2010" modifier="David Sumlin">Removed the outer single quotes in the return parameter</log> 
	</historylog>         

**************************************************************************************************/
CREATE FUNCTION [dbo].[f_QuoteString]
(
	@str nvarchar(4000)
) 
RETURNS nvarchar(4000) 
AS
BEGIN
   DECLARE @ret nvarchar(4000),
           @sq  char(1)

   SELECT @sq = ''''
   SELECT @ret = REPLACE(@str, @sq, @sq + @sq)

   RETURN(@ret)

END
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The original string.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'FUNCTION',@level1name=N'f_QuoteString', @level2type=N'PARAMETER',@level2name=N'@str'
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Takes a string and replaces single quotes with double single quotes.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'FUNCTION',@level1name=N'f_QuoteString'
GO

IF OBJECT_ID('audit.s_KVAdd','P') IS NOT NULL
    BEGIN
        DROP PROCEDURE audit.s_KVAdd;
    END
GO
PRINT 'creating audit.s_KVAdd procedure';
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
        <log revision="1.2" date="06/23/2015" modifier="David Sumlin">Added handling for invalid xml characters</log> 
	</historylog>         

**************************************************************************************************/
CREATE PROCEDURE [audit].[s_KVAdd]
(
	@session uniqueidentifier, 
	@k varchar(100),
    @v sql_variant
)
AS
SET NOCOUNT ON
SET XACT_ABORT ON

    DECLARE @tmp varchar(4000);

    IF @session IS NULL
        RAISERROR('@session can''t be NULL',16,1);

    IF @k IS NULL
        RAISERROR('@k can''t be NULL',16,1);

    SET @v = COALESCE(@v,'');

    -- this will clean up any characters which are invalid xml
    IF SQL_VARIANT_PROPERTY(@v,'BaseType') IN ('char','varchar','nchar','nvarchar')
        BEGIN
            SET @tmp = CAST(@v AS varchar(4000));
            SET @tmp = REPLACE(@tmp,'<','%lt;');
            SET @tmp = REPLACE(@tmp,'>','%gt;');
            SET @tmp = REPLACE(@tmp,'&','%amp;');
            SET @v = @tmp;
        END

	BEGIN TRY

        -- upsert
        IF EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                UPDATE audit.KVStore
                SET V = @v
                WHERE KVStoreGID = @session
                AND K = @k;
            END
        ELSE
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V)
                VALUES (@session,@k,@v);
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

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Add or Update value in KVStore table' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVAdd'
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Unique session ID to identify different KV groupings in KVStore' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVAdd', @level2type=N'PARAMETER',@level2name=N'@session'
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Key' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVAdd', @level2type=N'PARAMETER',@level2name=N'@k'
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Value' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVAdd', @level2type=N'PARAMETER',@level2name=N'@v'
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
	</historylog>         

**************************************************************************************************/
CREATE PROCEDURE [audit].[s_KVDelete]
(
	@session uniqueidentifier, 
	@k varchar(100)
)
AS
SET NOCOUNT ON
SET XACT_ABORT ON

    -- validate input variables
    IF @session IS NULL
        RAISERROR('@session can''t be NULL',16,1);

    IF @k IS NULL
        RAISERROR('@k can''t be NULL',16,1);

	BEGIN TRY

        DELETE
        FROM audit.KVStore
        WHERE KVStoreGID = @session
        AND K = @k;

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

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Delete a value in KVStore table' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVDelete'
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Unique session ID to identify different KV groupings in KVStore' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVDelete', @level2type=N'PARAMETER',@level2name=N'@session'
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Key' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVDelete', @level2type=N'PARAMETER',@level2name=N'@k'
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
	</historylog>         

**************************************************************************************************/
CREATE PROCEDURE [audit].[s_KVLog]
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
                    '<' + LOWER(K) + '>' + 
                    CASE 
                        WHEN LEFT(CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(100)),4) = 'date' THEN CAST(CAST(V AS datetime2(7)) AS varchar(100))
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

			-- Log the error
            SET @output = LEFT(COALESCE(@output,''),4000);
			EXEC [audit].[s_AddSQLErrorLog] @section = @err_sec, @extrainfo = @output, @announce = 1;

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