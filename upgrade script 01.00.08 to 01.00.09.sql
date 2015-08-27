SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET XACT_ABORT ON;

DECLARE @new_version nvarchar(100) = N'01.00.09',
        @old_version nvarchar(100) = N'01.00.08',
        @script nvarchar(100) = N'audit version',
        @ext_version nvarchar(100);

IF NOT EXISTS(SELECT 1 FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = @script)
    BEGIN
        RAISERROR(N'This is an upgrade script.  Run framework install script first',20,1) WITH LOG;
    END
ELSE
    BEGIN
        SELECT @ext_version = CONVERT(nvarchar(100),value) FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = @script;
        IF @ext_version <> @old_version
            BEGIN
                RAISERROR(N'This is the wrong upgrade script.',20,1) WITH LOG;
            END
        ELSE
            BEGIN
                EXEC sys.sp_updateextendedproperty @name = @script, @value = @new_version;
            END
    END
   
PRINT 'Upgrading from version ' + @old_version + ' to ' + @new_version;
GO
   
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
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
        <log revision="3.1" date="07/09/2015" modifier="David Sumlin">Changed to use KV for error handling and logging</log>
        <log revision="3.2" date="07/20/2015" modifier="David Sumlin">Changed @version to use different GUID for KV key</log>
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
	DECLARE @err_sec varchar(128) = NULL,
			@exec_start datetimeoffset(7) = SYSDATETIMEOFFSET(),
			@sec_exec_start datetimeoffset(7) = SYSDATETIMEOFFSET(),			
			@exec_end datetimeoffset(7) = SYSDATETIMEOFFSET(),
			@params nvarchar(2000) = NULL,
			@rows int = 0,
            @version uniqueidentifier = NEWID(),
			@db_id int = DB_ID();

    -- Common variables
    DECLARE @ret_val int,
            @sql nvarchar(MAX) = N'',
		    @crlf nvarchar(1) = NCHAR(13),
		    @tab nvarchar(1) = NCHAR(9);

	-- local variables
	DECLARE @full_object_name nvarchar(1000),
			@schema_object_name nvarchar(1000),
			@schema_qualifier_name nvarchar(1000)

    SET @err_sec = 'log parameters';
	SET @params =   N'@object_name = ' + COALESCE('''' + CAST(@object_name AS nvarchar(128)) + '''',N'NULL') + N' , ' +
                    N'@object_type = ' + COALESCE('''' + CAST(@object_type AS nvarchar(128)) + '''',N'NULL') + N' , ' +
					N'@schema_name = ' + COALESCE('''' + CAST(@schema_name AS nvarchar(128)) + '''',N'NULL') + N' , ' +
                    N'@db_name = ' + COALESCE('''' + CAST(@db_name AS nvarchar(128)) + '''',N'NULL') + N' , ' +
					N'@qualifier_name = ' + COALESCE('''' + CAST(@qualifier_name AS nvarchar(128)) + '''',N'NULL') + N' , ' +
                    N'@log_id = ' + COALESCE('''' + CAST(@log_id AS nvarchar(128)) + '''',N'NULL') + N' , ' +
                    N'@app_nm = ' + COALESCE('''' + CAST(@app_nm AS nvarchar(128)) + '''',N'NULL') + N' , ' +
					N'@debug = ' + COALESCE(CAST(@debug AS nvarchar(4)),N'NULL');

	BEGIN TRY

		SET @err_sec = 'Validate parameters'			

        SET @log_id = COALESCE(@log_id,NEWID());
        SET @debug = COALESCE(@debug,0);

        SET @err_sec = 'begin logging'
        EXEC audit.s_KVAdd @version, 'evt_type', 'proc exec';
        EXEC audit.s_KVAdd @version, 'evt_status', 'info';
        EXEC audit.s_KVAdd @version, 'uid', @log_id;
        EXEC audit.s_KVAdd @version, 'sec_nm', @err_sec;
        EXEC audit.s_KVAdd @version, 'bgn_dt', @exec_start;
        EXEC audit.s_KVAdd @version, 'end_dt', @exec_end;
        EXEC audit.s_KVAdd @version, 'evt_info', @params;
        EXEC audit.s_KVAdd @version, 'obj_id', @@PROCID;
        EXEC audit.s_KVAdd @version, 'db_id', @db_id;
        EXEC audit.s_KVAdd @version, 'app_nm', @app_nm;
        EXEC audit.s_KVLog @version, 0;
        SET @sec_exec_start = SYSDATETIMEOFFSET();
			
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
		
		SET @rows = @@ROWCOUNT;
		SET @err_sec = 'end logging';
		SET @exec_end = SYSDATETIMEOFFSET();
        EXEC audit.s_KVAdd @version, 'sec_nm', @err_sec;
        EXEC audit.s_KVAdd @version, 'rows', @rows;
        EXEC audit.s_KVAdd @version, 'bgn_dt', @exec_start;
        EXEC audit.s_KVAdd @version, 'end_dt', @exec_end;
        EXEC audit.s_KVAdd @version, 'app_nm', @app_nm;
        EXEC audit.s_KVLog @version, 1;

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
        EXEC audit.s_KVAdd @version, 'db_nm', @log_db_nm;
        EXEC audit.s_KVAdd @version, 'uid', @log_id;
        EXEC audit.s_KVAdd @version, 'sec_nm', @err_sec;
        EXEC audit.s_KVAdd @version, 'app_nm', @app_nm;
        EXEC audit.s_KVAdd @version, 'evt_txt', @event_info;
        EXEC audit.s_KVAdd @version, 'evt_info', @params;
        EXEC audit.s_KVLog @version, 1;

		-- Return error message to calling code via @@ERROR and error number via return code
		RAISERROR (@err_msg, @err_lvl, 1)
		RETURN(ERROR_NUMBER())

	END CATCH
GO
